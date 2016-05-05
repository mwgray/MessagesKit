//
//  MessageAPI.swift
//  ReTxt
//
//  Created by Kevin Wooten on 8/20/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import PSOperations
import CocoaLumberjack
import DeviceKit


// Notification types & dictionary keys
//
public let MessageAPIUserMessageReceivedNotification = "UserMessageReceived"
public let MessageAPIUserMessageReceivedNotification_MessageKey = "message"

public let MessageAPIDirectMessageReceivedNotification = "DirectMessageReceivedNotification"
public let MessageAPIDirectMessageReceivedNotification_MsgIdKey = "msgId"
public let MessageAPIDirectMessageReceivedNotification_MsgTypeKey = "msgType"
public let MessageAPIDirectMessageReceivedNotification_MsgDataKey = "msgData"
public let MessageAPIDirectMessageReceivedNotification_SenderKey = "sender"
public let MessageAPIDirectMessageReceivedNotification_SenderDeviceIdKey = "senderDeviceId"

public let MessageAPIDirectMessageMsgTypeKeySet = "keySet"

public let MessageAPIUserStatusDidChangeNotification = "UserStatusDidChange"
public let MessageAPIUserStatusDidChangeNotification_InfoKey = "info"

public let MessageAPISignedInNotification = "MessageAPISignedInNotification"
public let MessageAPISignedOutNotification = "MessageAPISignedOutNotification"

public let MessageAPIAccessTokenRefreshed = "MessageAPIAccessTokenRefreshed"


// Constants
//
private let kUserCacheTTL = NSTimeInterval(86400 * 7)

// User defaults keys
//
private let UnreadMessageCountKey = "io.retxt.UnreadMessageCount"
// Debugging
private let ClearDataDebugKey = "io.retxt.debug.ClearData"
private let UniqueDeviceIdDebugKey = "io.retxt.debug.UniqueDeviceId"



@objc public class MessageAPI : NSObject {
  
  internal static var target : ServerTarget!
  
  private static var _publicAPI : RTPublicAPIAsync!
  private static var _publicAPIInit = dispatch_once_t()

  public static var publicAPI = MessageAPI.makePublicAPI()
  
  public let credentials : RTCredentials
  
  private(set) var accessToken : String?

  private(set) var active = false
  private var activeChatId : RTId?
  private var suspendedChatId : RTId?
  
  internal var publicAPI : RTPublicAPIAsync { return MessageAPI.publicAPI }
  internal var userAPI : RTUserAPIAsync!

  internal var dbManager : RTDBManager!
  internal var chatDAO : RTChatDAO!
  internal var messageDAO : RTMessageDAO!
  internal var notificationDAO : RTNotificationDAO!
  
  private var userInfoCache : PersistentCache<String, RTUserInfo>!
  internal var webSocket : RTWebSocket!
  
  internal var backgroundURLSession : NSURLSession!
  
  private var signedOut = false
  
  private let queue = OperationQueue()
  private var observers : [AnyObject]!
  
  private(set) var networkAvailable = true
  
  internal let certificateTrust : RTOpenSSLCertificateTrust

  
  public class func initialize(target target: ServerTarget) {
    assert(self.target == nil, "MessageAPI target already initialized")
    self.target = target
  }
  

  public init(credentials: RTCredentials, documentDirectoryURL docsDirURL: NSURL) throws {
    
    assert(MessageAPI.target != nil, "MessageAPI target not initialized, call MessageAPI.initialize first")
    
    self.queue.name = "MessageAPI Processing Queue"
    
    self.certificateTrust = try MessageAPI.makeCertificateTrust()
    
    self.credentials = credentials
    self.accessToken = nil
    
    super.init()
    
    assert(docsDirURL.fileURL)
    
    let dbName = credentials.userId.UUIDString() + ".sqlite"
    let dbURL = docsDirURL.URLByAppendingPathComponent(dbName)
    
    let clearData = NSUserDefaults.standardUserDefaults().boolForKey(ClearDataDebugKey)
    
    if clearData {
      let _ = try? NSFileManager.defaultManager().removeItemAtURL(dbURL)
    }
    
    guard let dbPath = dbURL.filePathURL?.path else {
      throw MessageAPIError.InvalidDocumentDirectoryURL
    }
    
    self.dbManager = try RTDBManager(path: dbPath, kind: "Message", daoClasses: [RTChatDAO.self, RTMessageDAO.self, RTNotificationDAO.self])
    
    self.chatDAO = self.dbManager["Chat"] as! RTChatDAO
    self.messageDAO = self.dbManager["Message"] as! RTMessageDAO
    self.notificationDAO = self.dbManager["Notification"] as! RTNotificationDAO
    
    self.userInfoCache = try PersistentCache(name: "UserInfo", clear: clearData) { key in
      
      let wait = dispatch_semaphore_create(0)
      var userInfo : RTUserInfo?
      var error : NSError?

      self.publicAPI.findUserWithAlias(key,
                                       response: { userInfo = $0; dispatch_semaphore_signal(wait) },
                                       failure: { error = $0; dispatch_semaphore_signal(wait) })
      
      if dispatch_semaphore_wait(wait, dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC) * 3)) != 0 {
        error = NSError(code: MessageAPIError.UnknownError, userInfo: nil)
      }
      
      if let error = error {
        throw error
      }
      
      if let userInfo = userInfo {
        return (userInfo, NSDate(timeIntervalSinceNow: kUserCacheTTL))
      }
      
      return nil
    }
    
    self.userAPI = makeUserAPI()
    self.webSocket = makeWebSocket()
    
    // Initialize background URLSession
    //
    
    // Build session as required
    let backgroundURLSessionConfig = NSURLSessionConfiguration.backgroundSessionConfigurationWithUserId(credentials.userId)
    let backgroundSessionOperations = BackgroundSessionOperations(trustedCertificates: RTServerAPI.pinnedCerts(),
                                                                  api: self,
                                                                  dao: messageDAO,
                                                                  queue: queue)
    
    self.backgroundURLSession = NSURLSession(configuration: backgroundURLSessionConfig,
                                             delegate: backgroundSessionOperations,
                                             delegateQueue: queue)
    
    // Ensure transfers currently in progress are linked and handled correctly...
    backgroundSessionOperations.resurrectOperationsForSession(backgroundURLSession) { transferringMessageIds in
      
      if !transferringMessageIds.isEmpty {
        
        // Kill any that are failing, and are not in the background,
        self.messageDAO.failAllSendingMessagesExcluding(transferringMessageIds)
        
        // Restart any transfers that were just killed
        self.queue.addOperation(ResendUnsentMessages(api: self))
      }
      
    }
    
    // Initialize application state change notifications
    //
    
    let nc = NSNotificationCenter.defaultCenter()
    self.observers = [
      
      // Network - Available
      nc.addObserverForName(RTNetworkConnectivityAvailableNotification, object: nil, queue: queue) { not in
        if !self.networkAvailable {
          self.queue.addOperation(ResendUnsentMessages(api: self))
        }
        self.networkAvailable = true
      },
      
      // Network - Unavailable
      nc.addObserverForName(RTNetworkConnectivityUnavailableNotification, object: nil, queue: queue) { not in
        self.networkAvailable = false
      },
      
      // Application - Did Become Active
      nc.addObserverForName(UIApplicationDidBecomeActiveNotification, object: nil, queue: queue) { not in
        self.activate()
      },

      // Application - Will Resign Active
      nc.addObserverForName(UIApplicationDidBecomeActiveNotification, object: nil, queue: queue) { not in
        self.deactivate()
      }
    ]
    
    if UIApplication.sharedApplication().applicationState == .Active {
      self.activate()
    }
    
  }
  
  deinit {
    self.observers.forEach(NSNotificationCenter.defaultCenter().removeObserver)
  }
  
  public func isChatActive(chat: RTChat) -> Bool {
    return activeChatId == chat.id
  }
  
  public func isOtherChatActive(chat: RTChat) -> Bool {
    return activeChatId != nil && !isChatActive(chat)
  }
  
  public func activate() {
  
    if active { return }
    
    active = true
    
    if credentials.authorized {
      queue.addOperation(ConnectWebSocket(api: self))
      queue.addOperation(FetchWaitingOperation(api: self))
      queue.addOperation(ResendUnsentMessages(api: self))
    }
    
    if let suspendedChatId = suspendedChatId {

      if let chat = try! chatDAO.fetchChatWithId(suspendedChatId) {
        activateChat(chat)
      }

      self.suspendedChatId = nil
    }
  }
  
  public func activateChat(chat: RTChat) {
    
    if activeChatId == chat.id { return }

    activeChatId = chat.id
    suspendedChatId = nil
    
    activate()

    queue.addOperationWithBlock {
      
      self.chatDAO.resetUnreadCountsForChat(chat)
      
      let unreadCount = Int(try! self.messageDAO.readAllMessagesForChat(chat))
      self.adjustUnreadMessageCountWithDelta(-unreadCount)
      
      if let error = try? self.hideNotificationsForChat(chat) {
        DDLogError("Error hiding notifications for chat: \(chat.alias): \(error)")
      }
      
      self.queue.addOperation(SendChatReceiptOperation(chat: chat, api: self))
    }
    
  }
  
  public func deactivateChat() {
    
    activeChatId = nil
  }
  
  public func deactivate() {
    
    suspendedChatId = activeChatId
    
    deactivateChat()
    
    webSocket.disconnect()
    
    active = false
  }
  
  internal func updateAccessToken(accessToken: String) {

    self.accessToken = accessToken
    
    NSNotificationCenter.defaultCenter()
      .postNotificationName(MessageAPIAccessTokenRefreshed, object: self)
  }
  
  internal func adjustUnreadMessageCountWithDelta(delta: Int) {
    
    let defs = NSUserDefaults.standardUserDefaults()
    
    let unread = max(defs.integerForKey(UnreadMessageCountKey) + delta, 0)
    defs.setInteger(unread, forKey: UnreadMessageCountKey)
    
    UIApplication.sharedApplication().applicationIconBadgeNumber = unread
  }
  
  private func updateUnreadMessageCount() -> UInt {
    
    let count = Int(messageDAO.countOfUnreadMessages())
    
    NSUserDefaults.standardUserDefaults().setInteger(count, forKey: UnreadMessageCountKey)
    
    UIApplication.sharedApplication().applicationIconBadgeNumber = count
    
    return UInt(count)
  }
  
  private func clearUnreadMessageCount() {
    
    NSUserDefaults.standardUserDefaults().setInteger(0, forKey: UnreadMessageCountKey)
    
    UIApplication.sharedApplication().applicationIconBadgeNumber = 0
  }
  
  
  @nonobjc public func findMessageWithId(id: RTId) -> Promise<RTMessage?> {
    return dispatch_promise {
      return try self.messageDAO.fetchMessageWithId(id)
    }
  }
  
  @objc public func findMesageWithId(id: RTId) -> AnyPromise {
    
    let block : @convention(block) () -> AnyObject = {
      do {
        return try self.messageDAO.fetchMessageWithId(id)!
      }
      catch let error {
        return error as NSError
      }
    }
    
    return dispatch_promise(block as! AnyObject)
  }
  
  @nonobjc public func findMessagesMatchingPredicate(predicate: NSPredicate, offset: UInt, limit: UInt, sortedBy sorts: [NSSortDescriptor]) throws -> Promise<[RTMessage]> {
    
    return dispatch_promise {
      
      return try self.messageDAO.fetchAllMessagesMatching(predicate, offset: offset, limit: limit, sortedBy: sorts)
      
    }
    
  }
  
  @objc public func findMessagesMatchingPredicate(predicate: NSPredicate, offset: UInt, limit: UInt, sortedBy sorts: [NSSortDescriptor]) throws -> AnyPromise {
    
    let block : @convention(block) () -> AnyObject = {
      do {
        return try self.messageDAO.fetchAllMessagesMatching(predicate, offset: offset, limit: limit, sortedBy: sorts)
      }
      catch let error {
        return error as NSError
      }
    }
    
    return dispatch_promise(block as! AnyObject)
  }
  
  @objc public func fetchMessagesMatchingPredicate(predicate: NSPredicate, offset: UInt, limit: UInt, sortedBy sorts: [NSSortDescriptor]) -> RTFetchedResultsController {
    
    let request = RTFetchRequest()
    request.resultClass = RTMessage.self
    request.predicate = predicate
    request.includeSubentities = true
    request.sortDescriptors = sorts
    request.fetchOffset = offset
    request.fetchLimit = limit
    request.fetchBatchSize = 0
    
    return RTFetchedResultsController(DBManager: dbManager, request: request)
  }
  
  @nonobjc public func saveMessage(message: RTMessage) throws -> Promise<Void> {
    
    return firstly {
      
      // Ensure certain fields are not set
      if message.sender != nil || message.sent != nil || message.statusTimestamp != nil {
        throw MessageAPIError.InvalidMessageState
      }
      
      // Update fields for new message
      message.sender = message.chat.localAlias
      message.sent = NSDate()
      message.status = .Sending
      message.statusTimestamp = NSDate()
      message.flags = []
      
      try self.dbManager.pool.inTransaction { db in
        try self.messageDAO.insertMessage(message)
        try self.chatDAO.updateChat(message.chat, withLastSentMessage: message)
      }

      let send = MessageSendOperation(message: message, api: self)
      self.queue.addOperation(send)
      
      return send.promise().asVoid()
    }
    
  }
  
  @objc public func updateMessageLocally(message: RTMessage) throws {
    
    try self.messageDAO.updateMessage(message)
  }
  
  @nonobjc public func updateMessage(message: RTMessage) throws -> Promise<Void> {

    return firstly {

      // Ensure all required fields are already set
      if message.sender == nil || message.sent == nil {
        throw MessageAPIError.InvalidMessageState
      }
      
      // Ensure we are only updating messages we sent
      if !message.sentByMe {
        throw MessageAPIError.InvalidMessageState
      }
    
      // Update status for resend
      message.status = .Unsent
      message.statusTimestamp = NSDate()
      message.updated = NSDate()
      message.flags = []
    
      try updateMessageLocally(message)
      
      // Send the update!
      let update = MessageSendOperation(message: message, api: self)
      queue.addOperation(update)
      
      return update.promise().asVoid()
    }
  }

  @nonobjc public func clarifyMessage(message: RTMessage) throws -> Promise<Void> {

    return firstly {
    
      try self.messageDAO.updateMessage(message, withFlags: message.flags.union(.Clarify).rawValue)

      let clarify = MessageSendSystemOperation(msgType: .Clarify,
                                               chat: message.chat,
                                               metaData: [RTMetaDataKey_TargetMessageId: message.id.UUIDString()],
                                               target: .Standard,
                                               api: self)
      self.queue.addOperation(clarify)
    
      return clarify.promise().asVoid()
    }
  }
  
  @objc public func deleteMessageLocally(message: RTMessage) throws {
    
    try self.messageDAO.deleteMessage(message)
    
    if message == message.chat.lastMessage {
      
      let newLastMessage = self.messageDAO.fetchLastMessageForChat(message.chat)
      
      try self.chatDAO.updateChat(message.chat, withLastMessage: newLastMessage)
    }
    
    try hideNotificationForMessage(message)
  }

  @nonobjc public func deleteMessage(message: RTMessage) throws -> Promise<Void> {
    
    return firstly {
    
      try deleteMessageLocally(message)

      let delete = MessageSendSystemOperation(msgType: .Delete,
                                              chat: message.chat,
                                              metaData: [RTMetaDataKey_TargetMessageId: message.id.UUIDString(),
                                                         "type": "message"],
                                              target: .Standard,
                                              api: self)
      queue.addOperation(delete)
    
      return delete.promise().asVoid()
    }
  }
  
  @objc public func sendUserStatus(status: RTUserStatus, withSender sender: String, toRecipient recipient: String) {
   
    self.userAPI.sendUserStatus(sender, recipient: recipient, status: status)
    
  }

  @objc public func sendUserStatus(status: RTUserStatus, withSender sender: String, toMembers members: Set<String>,  inChat chat: RTId) {

    let group = RTGroup(chat: chat, members: members)
  
    self.userAPI.sendGroupStatus(sender, group: group, status: status)
  }
  
  
  @objc public func loadUserChatForAlias(alias: String, localAlias: String) throws -> RTUserChat {
    
    if let chat = try chatDAO.fetchChatForAlias(alias, localAlias: localAlias) as? RTUserChat {
      return chat
    }
    
    let chat = RTUserChat()
    chat.id = RTId.generate()
    chat.alias = alias
    chat.localAlias = localAlias
    chat.startedDate = NSDate()
    
    try chatDAO.insertChat(chat)
    
    return chat
  }
  
  @objc public func loadGroupChatForId(chatId: RTId, members: Set<String>, localAlias: String) throws -> RTGroupChat {
    
    if let chat = try chatDAO.fetchChatForAlias(chatId.UUIDString(), localAlias: localAlias) as? RTGroupChat {
      return chat
    }
    
    let chat = RTGroupChat()
    chat.id = chatId
    chat.alias = chatId.UUIDString()
    chat.localAlias = localAlias
    chat.members = members
    chat.activeMembers = members
    chat.startedDate = NSDate()
    
    try chatDAO.insertChat(chat)
    
    return chat
  }
  
  @objc public func enterChat(chat: RTGroupChat) throws {
    
    if chat.includesMe {
      return
    }
    
    try chatDAO.updateChat(chat, addGroupMember: chat.localAlias)
    
    let enter = MessageSendSystemOperation(msgType: .Enter,
                                           chat: chat,
                                           metaData: ["member": chat.localAlias],
                                           target: .Everybody,
                                           api: self)
    queue.addOperation(enter)
  }
  
  @objc public func exitChat(chat: RTGroupChat) throws {
    
    if !chat.includesMe {
      return
    }
    
    try chatDAO.updateChat(chat, addGroupMember: chat.localAlias)
    
    let enter = MessageSendSystemOperation(msgType: .Exit,
                                           chat: chat,
                                           metaData: ["member": chat.localAlias],
                                           target: .Everybody,
                                           api: self)
    queue.addOperation(enter)
  }
  
  @nonobjc public func findChatsMatchingPredicate(predicate: NSPredicate, offset: UInt, limit: UInt, sortedBy sorts: [NSSortDescriptor]) -> Promise<[RTChat]> {
    return dispatch_promise {
      return try self.chatDAO.fetchAllChatsMatching(predicate, offset: offset, limit: limit, sortedBy: sorts)
    }
  }
  
  @objc public func findChatsMatchingPredicate(predicate: NSPredicate, offset: UInt, limit: UInt, sortedBy sorts: [NSSortDescriptor]) -> AnyPromise {
    
    let block : @convention(block) () -> AnyObject = {
      
      do {
        return try self.chatDAO.fetchAllChatsMatching(predicate, offset: offset, limit: limit, sortedBy: sorts)
      }
      catch let error {
        return error as NSError
      }
    }
    
    return dispatch_promise(block as! AnyObject)
  }
  
  @objc public func fetchChatsMatchingPredicate(predicate: NSPredicate, offset: UInt, limit: UInt, sortedBy sorts: [NSSortDescriptor]) -> RTFetchedResultsController {
    
    let request = RTFetchRequest()
    request.resultClass = RTChat.self
    request.predicate = predicate
    request.includeSubentities = true
    request.sortDescriptors = sorts
    request.fetchOffset = offset
    request.fetchLimit = limit
    request.fetchBatchSize = 0

    return RTFetchedResultsController(DBManager: dbManager, request: request)
  }

  @objc public func updateChatLocally(chat: RTChat) throws {
    
    try chatDAO.updateChat(chat)
    
  }
  
  @objc public func deleteChatLocally(chat: RTChat) throws {
    
    try chatDAO.deleteChat(chat)
  
    try hideNotificationsForChat(chat)
  }

  @objc public func deleteChat(chat: RTChat) throws {
    
    try deleteChatLocally(chat)
    
    let delete = MessageSendSystemOperation(msgType: .Delete,
                                            chat: chat,
                                            metaData: ["type": "chat"],
                                            target: .CC,
                                            api: self)
    queue.addOperation(delete)
  }
  
  internal func showNotificationForMessage(message: RTMessage) throws {

    DDLogDebug("SHOWING NOTIFICATION: \(message.id)")
    
    //FIXME title & body should be generatable by end user
    
    let title = message.chat.activeRecipients.joinWithSeparator(", ")
    
    let body : String
    
    if (RTSettings.sharedSettings().privacyShowPreviews) {
      
      if (message.clarifyFlag) {
        
        body = "\(title) doesn't understand your message"

      }
      else {
        
        body = "\(title) \(message.alertText())"
      }
      
    }
    else {
      
      body = "\(title) New Message"
      
    }
    
    //FIXME allow user provided sounds
    
    //let sound = message.clarifyFlag ? RTSound_Message_Clarify : (message.updated ? RTSound_Message_Update : RTSound_Message_Receive)
    let sound = UILocalNotificationDefaultSoundName
    
    let localNotification = UILocalNotification()
    localNotification.category = "message"
    localNotification.alertBody = body
    localNotification.soundName = sound
    localNotification.userInfo = ["msgId" : message.id.description]
    localNotification.fireDate = NSDate(timeIntervalSinceNow:0.25)
    localNotification.applicationIconBadgeNumber = NSUserDefaults.standardUserDefaults().integerForKey(UnreadMessageCountKey)
    
    try saveAndScheduleLocalNotification(localNotification, forMessage: message)
  }
  
  internal func showFailNotificationForMessage(message: RTMessage) throws {

    DDLogDebug("SHOWING FAIL NOTIFICATION: \(message.id)")
    
    //FIXME title & body should be generatable by end user

    let title = message.chat.activeRecipients.joinWithSeparator(", ");
    
    let body = "Failed to send message to: \(title)"
    
    let localNotification = UILocalNotification()
    localNotification.alertBody = body
    localNotification.soundName = UILocalNotificationDefaultSoundName
    localNotification.userInfo = ["msgId" : message.id.description]
    
    try saveAndScheduleLocalNotification(localNotification, forMessage: message)
  }

  internal func saveAndScheduleLocalNotification(localNotification: UILocalNotification, forMessage message: RTMessage) throws {
    
    UIApplication.sharedApplication().scheduleLocalNotification(localNotification)
    
    var notification = try notificationDAO.fetchNotificationWithId(message.id)
    
    if let notification = notification {
      try deleteAndCancelNotification(notification, ifOnOrBefore: NSDate())
    }
    else {
      notification = RTNotification()
      notification!.msgId = message.id
      notification!.chatId = message.chat.id
    }
    
    notification!.data = NSKeyedArchiver.archivedDataWithRootObject(localNotification)
    
    try notificationDAO.upsertNotification(notification!)
  }
  
  internal func hideNotificationsForChat(chat: RTChat) throws {
    
    DDLogDebug("HIDING NOTIFICATIONS FOR CHAT: \(chat.id)")

    for notification in try notificationDAO.fetchAllNotificationsForChat(chat) {
      try deleteAndCancelNotification(notification, ifOnOrBefore:NSDate())
    }
    
  }
  
  internal func hideNotificationForMessage(message: RTMessage) throws {
    
    DDLogDebug("HIDING NOTIFICATION FOR MESSAGE: \(message.id)")
    
    for notification in try notificationDAO.fetchAllNotificationsMatching("chatId = ?", parameters: [message.chat.id]) {
      try deleteAndCancelNotification(notification, ifOnOrBefore:message.statusTimestamp ?? NSDate())
    }
    
  }
  
  internal func deleteAndCancelNotification(notification: RTNotification, ifOnOrBefore sent: NSDate) throws {
    
    if let localNotification = NSKeyedUnarchiver.unarchiveObjectWithData(notification.data) as? UILocalNotification {
      
      if let fireDate = localNotification.fireDate
        where fireDate.compare(sent).rawValue <= NSComparisonResult.OrderedSame.rawValue {
        
        UIApplication.sharedApplication().cancelLocalNotification(localNotification)

        try notificationDAO.deleteNotification(notification)
      }
      
    }
    
  }
  
  @objc public func signOut() {
    
    if (signedOut) {
      return;
    }
    
    signedOut = true;
    
    deactivate()

    webSocket.disconnect()
    webSocket = nil

    queue.suspended = true
    queue.cancelAllOperations()

    GCD.mainQueue.async {
      NSNotificationCenter.defaultCenter().postNotificationName(MessageAPISignedOutNotification, object: self)
    }

    GCD.userInitiatedQueue.async {
      self.clearUnreadMessageCount()
    }
  }
  
  @nonobjc public class func findUserIdWithAlias(alias: String) -> Promise<RTId?> {
    return self.publicAPI.findUserWithAlias(alias).then(on: zalgo) { val -> RTId? in
        let userInfo = val as! RTUserInfo
        return userInfo.id
      }
      .recover { error -> RTId? in
        let error = error as NSError
        if error.domain == TApplicationErrorDomain && Int32(error.code) == TApplicationError.MissingResult.rawValue {
          return nil
        }
        throw error
      }
  }
  
  @objc public class func findUserIdWithAlias(alias: String) -> AnyPromise {
    return self.publicAPI.findUserWithAlias(alias)
  }
  
  func resolveUserInfoWithAlias(alias: String) throws -> RTUserInfo? {
    return try self.userInfoCache.valueForKey(alias)
  }
  
  func invalidateUserInfoWithAlias(alias: String) {
    let _ = try? userInfoCache.invalidateValueForKey(alias)
  }
  
  
  public func reportDirectMessage(msg: RTDirectMsg) -> Promise<Void> {
    
    return Promise<Void>() { fulfill, reject in
      
      let op = MessageProcessDirectOperation(msg: msg, api: self)
      op.resolver = { obj in
        if let error = obj as? NSError {
          reject(error)
        }
        else {
          fulfill(Void())
        }
      }
      
      queue.addOperation(op)
    }
  }
  
  public func reportWaitingMessage(msgId: RTId, type: RTMsgType, dataLength: Int32) -> Promise<Void> {
    
    if !credentials.authorized {
      return Promise<Void>(Void())
    }
    
    let msgHdr = RTMsgHdr(id: msgId, type: type, dataLength: dataLength)
    
    return Promise<Void>() { fulfill, reject in
      
      let op = MessageRecvOperation(msgHdr: msgHdr, api: self)
      op.resolver = { obj in
        if let error = obj as? NSError {
          reject(error)
        }
        else {
          fulfill(Void())
        }
      }
      
      queue.addOperation(op)
    }
  }

  @nonobjc public func changePasswordWithOldPassword(oldPassword: String, newPassword: String) -> Promise<Bool> {
    //TODO
    return Promise<Bool>(false)
  }
  
}

//
// SignIn & Registration methods
//
extension MessageAPI {
  
  @nonobjc public class func findProfileWithAlias(alias: String, password: String) -> Promise<RTUserProfile> {
    return MessageAPI.publicAPI.findProfileWithAlias(alias, password: password).then(on: zalgo) { val in
      return val as! RTUserProfile
    }
  }
  
  @objc public class func findProfileWithAlias(alias: String, password: String) -> AnyPromise {
    return MessageAPI.publicAPI.findProfileWithAlias(alias, password: password)
  }
  
  @nonobjc public class func findProfileWithId(id: RTId, password: String) -> Promise<RTUserProfile> {
    return MessageAPI.publicAPI.findProfileWithId(id, password: password).then(on: zalgo) { val in
      return val as! RTUserProfile
    }
  }
  
  @objc public class func findProfileWithId(id: RTId, password: String) -> AnyPromise {
    return MessageAPI.publicAPI.findProfileWithId(id, password: password)
  }
  
  @nonobjc public class func checkCurrentDeviceRegistered(profile: RTUserProfile) -> Promise<Bool> {
    
    return discoverDeviceId().then { currentDeviceId in
      return profile.devices.filter { $0.id == currentDeviceId }.isEmpty
    }
  }
  
  @nonobjc public class func signInWithProfile(profile: RTUserProfile, password: String) -> Promise<RTCredentials> {
    
    return discoverDeviceId().then { currentDeviceId in
      return signInWithProfile(profile, deviceId: currentDeviceId, password: password)
    }
  }
  
  @nonobjc public class func signInWithProfile(profile: RTUserProfile, deviceId: RTId, password: String) -> Promise<RTCredentials> {
    
    let savedCredentials = RTCredentials.loadFromKeychain(profile.id)
    
    return self.publicAPI.signIn(profile.id,
                                 password: password,
                                 deviceId: deviceId)
      .then(on: GCD.backgroundQueue) { refreshToken -> RTCredentials in
        
        let refreshToken = refreshToken as! NSData
        
        var encryptionIdentity : RTAsymmetricIdentity!
        var signingIdentity : RTAsymmetricIdentity!
        let authorized : Bool
        
        if let savedCredentials = savedCredentials {

          //
          // Attempt to use saved credentials if the keys & certs are matching
          //
          
          let encryptionCert = try RTOpenSSLCertificate(DEREncodedData: profile.encryptionCert)
          let signingCert = try RTOpenSSLCertificate(DEREncodedData: profile.signingCert)
          
          authorized =
            savedCredentials.encryptionIdentity.privateKeyMatchesCertificate(encryptionCert) &&
            savedCredentials.signingIdentity.privateKeyMatchesCertificate(signingCert)
          
          if authorized {
            encryptionIdentity = savedCredentials.encryptionIdentity
            signingIdentity = savedCredentials.signingIdentity
          }
        }
        else {
          authorized = false
        }
        
        if !authorized {

          //
          // Generate temporary keys for authorization
          //
          
          encryptionIdentity = try RTAsymmetricKeyPairGenerator
            .generateSelfSignedIdentityNamed(["UID":profile.id.UUIDString(),"CN":"reTXT Encryption"],
              withKeySize: 2048,
              usage: [.KeyEncipherment,.NonRepudiation])
          
          signingIdentity = try RTAsymmetricKeyPairGenerator
            .generateSelfSignedIdentityNamed(["UID":profile.id.UUIDString(),"CN":"reTXT Signing"],
              withKeySize: 2048,
              usage: [.DigitalSignature, .NonRepudiation])
          
        }
        
        let aliases = (profile.aliases! as NSSet).allObjects as! [String]
        
        return RTCredentials(refreshToken: refreshToken,
          userId: profile.id,
          deviceId: deviceId,
          allAliases: aliases,
          preferredAlias: selectPreferredAlias(aliases),
          encryptionIdentity: encryptionIdentity,
          signingIdentity: signingIdentity,
          authorized: authorized)
      }
      .recover { error -> RTCredentials in
        throw translateError(error as NSError)
      }
  }
  
  @nonobjc public class func requestAuthenticationForAlias(alias: String) -> Promise<Void> {
    
    return publicAPI.requestAliasAuthentication(alias)
      .then(on: zalgo) { val in
        return val
      }
      .recover { error -> Void in
        throw translateError(error as NSError)
    }
  }
  
  @nonobjc public class func checkAuthenticationForAlias(alias: String, pin: String) -> Promise<Bool> {
    
    return publicAPI.checkAliasAuthentication(alias, pin: pin)
      .then(on: zalgo) { val in
        return (val as? NSNumber as? Bool) ?? false
      }
      .recover { error -> Bool in
        throw translateError(error as NSError)
      }
  }
  
  @nonobjc public class func registerUserWithAliases(aliasesAndPins: [String: String], password: String) -> Promise<RTCredentials> {
    
    let aliases = Array(aliasesAndPins.keys)
    let authenticatedAliases = aliasesAndPins.map { RTAuthenticatedAlias(name: $0, pin: $1)! }
    
    return discoverDeviceInfoWithAliases(aliases).thenInBackground { deviceInfo in
      
      let encryptionIdentityRequest =
        try RTAsymmetricKeyPairGenerator.generateIdentityRequestNamed("reTXT Encryption",
                                                                      withKeySize: 2048,
                                                                      usage: [.KeyEncipherment, .NonRepudiation])

      let signingIdentityRequest =
        try RTAsymmetricKeyPairGenerator.generateIdentityRequestNamed("reTXT Signing",
                                                                      withKeySize: 2048,
                                                                      usage: [.DigitalSignature, .NonRepudiation])

      // Register user
      
      return self.publicAPI.registerUser(password,
                                         encryptionCSR: encryptionIdentityRequest.certificateSigningRequest.encoded,
                                         signingCSR: signingIdentityRequest.certificateSigningRequest.encoded,
                                         authenticatedAliases: authenticatedAliases,
                                         deviceInfo:deviceInfo)
        .then(on: GCD.backgroundQueue) { userProfile in
          
          let userProfile = userProfile!
          
          // Sign in new user
          
          return self.publicAPI.signIn(userProfile.id,
                                       password: password,
                                      deviceId: deviceInfo.id)
            .then(on: GCD.backgroundQueue) { refreshToken in
              
              let refreshToken = refreshToken as! NSData
              
              let certificateTrust = try makeCertificateTrust()
              
              let encryptionCert = try RTOpenSSLCertificate(DEREncodedData: userProfile.encryptionCert, validatedWithTrust: certificateTrust)
              let encryptionIdent = encryptionIdentityRequest.buildIdentityWithCertificate(encryptionCert)
              
              let signingCert = try RTOpenSSLCertificate(DEREncodedData: userProfile.signingCert, validatedWithTrust: certificateTrust)
              let signingIdent = signingIdentityRequest.buildIdentityWithCertificate(signingCert)
              
              
              return RTCredentials(refreshToken: refreshToken,
                                   userId: userProfile.id,
                                   deviceId: deviceInfo.id,
                                   allAliases: aliases,
                                   preferredAlias: selectPreferredAlias(aliases),
                                   encryptionIdentity: encryptionIdent,
                                   signingIdentity: signingIdent,
                                   authorized: true)
            }
        }
    }
  }
  
  @nonobjc public class func updateKeysForUserId(id: RTId, password: String, encryptionCSR: NSData, signingCSR: NSData) -> Promise<AnyObject> {
    //TODO
    return Promise<AnyObject>(NSNumber(bool: false))
  }
  
  @nonobjc public class func requestTemporaryPasswordForUser(alias: String) {
    //TODO
  }
  
  @nonobjc public class func checkTemporaryPasswordForUser(alias: String, temporaryPassword: String) -> Promise<Bool> {
    //TODO
    return Promise<Bool>(false)
  }
  
  @nonobjc public class func resetPasswordForUser(alias: String, temporaryPassword: String, password: String) -> Promise<Bool> {
    //TODO
    return Promise<Bool>(false)
  }
  
  @objc public class func selectPreferredAlias(aliases: [String], withSuggestedAlias suggested: String) -> String {
    
    if aliases.contains(suggested) {
      return suggested
    }
    
    return selectPreferredAlias(aliases)
  }
  
  @objc public class func selectPreferredAlias(aliases: [String]) -> String {
    //FIXME prefer phone numbers over anything else
    return aliases.first ?? ""
  }
  
  private class func discoverDeviceInfoWithAliases(aliases: [String]) -> Promise<RTDeviceInfo> {
    
    return discoverDeviceId().thenInBackground { deviceId -> RTDeviceInfo in
      
      let deviceVersion : String
      
      switch Device() {
      case .iPad2:        deviceVersion = "2"
      case .iPad3:        deviceVersion = "3"
      case .iPad4:        deviceVersion = "4"
      case .iPadAir:      deviceVersion = "Air"
      case .iPadAir2:     deviceVersion = "Air 2"
      case .iPadPro:      deviceVersion = "Pro"
      case .iPadMini:     deviceVersion = "Mini"
      case .iPadMini2:    deviceVersion = "Mini 2"
      case .iPadMini3:    deviceVersion = "Mini 3"
      case .iPadMini4:    deviceVersion = "Mini 4"
      case .iPhone4:      deviceVersion = "4"
      case .iPhone4s:     deviceVersion = "4s"
      case .iPhone5:      deviceVersion = "5"
      case .iPhone5c:     deviceVersion = "5c"
      case .iPhone5s:     deviceVersion = "5s"
      case .iPhone6:      deviceVersion = "6"
      case .iPhone6s:     deviceVersion = "6s"
      case .iPhone6Plus:  deviceVersion = "6 Plus"
      case .iPhone6sPlus: deviceVersion = "6s Plus"
      case .iPhoneSE:     deviceVersion = "SE"
      case .iPodTouch5:   deviceVersion = "5"
      case .iPodTouch6:   deviceVersion = "6"
      default:            deviceVersion = ""
      }
      
      let device = UIDevice.currentDevice()
      
      return RTDeviceInfo(
        id: deviceId,
        name: device.name,
        manufacturer: "Apple",
        model: device.model,
        version: deviceVersion,
        osVersion: device.systemVersion,
        activeAliases: Set(aliases))!
    }
  }

  #if !RELEASE
  @nonobjc static var __fakeUniqueDeviceId = RTId.generate()
  #endif
  
  private class func discoverDeviceId() -> Promise<RTId> {
    
    return dispatch_promise {
      
      #if !RELEASE
        if NSUserDefaults.standardUserDefaults().boolForKey(UniqueDeviceIdDebugKey) {
          return __fakeUniqueDeviceId
        }
      #endif
      
      let device = UIDevice.currentDevice()
      
      guard let vendorDeviceId = device.identifierForVendor else {
        throw MessageAPIError.DeviceNotReady
      }
      
      return RTId(UUID: vendorDeviceId)
    }
  }
  
}



//
// WebSocket delegate methods
//
extension MessageAPI : RTWebSocketDelegate {
  
  //
  // Adds build # and Bearer token to websocket connection requests
  //
  public func webSocket(webSocket: RTWebSocket, willConnect request: NSMutableURLRequest) {
    
    request.addBuildNumber()
    
    if let accessToken = self.accessToken {
      request.addHTTPBearerAuthorizationWithToken(accessToken)
    }
    
  }
  
  public func webSocket(webSocket: RTWebSocket, didReceiveUserStatus sender: String, recipient: String, status: RTUserStatus) {

    DDLogDebug("USER STATUS: \(sender), \(recipient), \(status)");
    
    guard let chat = try? chatDAO.fetchChatForAlias(sender, localAlias: recipient) else {
      return
    }
    
    let info = RTUserStatusInfo(status: status, forUser: sender, inChat: chat)
    
    GCD.mainQueue.async {
      NSNotificationCenter.defaultCenter()
        .postNotificationName(MessageAPIUserStatusDidChangeNotification,
          object: self,
          userInfo: [MessageAPIUserStatusDidChangeNotification_InfoKey:info])
    }
  }
  
  public func webSocket(webSocket: RTWebSocket, didReceiveGroupStatus sender: String, chatId: RTId, status: RTUserStatus) {

    DDLogDebug("GROUP STATUS: \(sender), \(chatId), \(status)");
    
    guard let chat = try? chatDAO.fetchChatWithId(chatId) else {
      return
    }
    
    let info = RTUserStatusInfo(status: status, forUser: sender, inChat: chat)
    
    GCD.mainQueue.async {
      NSNotificationCenter.defaultCenter()
        .postNotificationName(MessageAPIUserStatusDidChangeNotification,
          object: self,
          userInfo: [MessageAPIUserStatusDidChangeNotification_InfoKey:info])
    }
  }
  
  public func webSocket(webSocket: RTWebSocket, didReceiveMsgReady msgHdr: RTMsgHdr) {
    
    DDLogDebug("MESSAGE READY: \(msgHdr)")
    
    queue.addOperation(MessageRecvOperation(msgHdr: msgHdr, api: self))
  }
  
  public func webSocket(webSocket: RTWebSocket, didReceiveMsgDelivery msg: RTMsg) {

    DDLogDebug("MESSAGE DELIVERY: \(msg.id) \(msg.type) \(msg.sent)")
    
    queue.addOperation(MessageRecvOperation(msg: msg, api: self))
  }
  
  public func webSocket(webSocket: RTWebSocket, didReceiveMsgDirect msg: RTDirectMsg) {

    DDLogDebug("MESSAGE DIRECT: \(msg.id) \(msg.type) \(msg.sender) \(msg.senderDevice)")
    
    reportDirectMessage(msg)
  }
  
  public func webSocket(webSocket: RTWebSocket, didReceiveMsgDelivered msgId: RTId, recipient: String) {
    
    queue.addOperation(MessageDeliveredOperation(msgId: msgId, api: self))
  }
  
}


//
// Factory methods
//
extension MessageAPI {
  
  private class func makePublicAPI() -> RTPublicAPIAsync {
    
    // Build an SSL validator
    
    let validator = RTURLSessionSSLValidator(trustedCertificates: RTServerAPI.pinnedCerts())
    
    // Build a session configured for PublicAPI usage
    
    let protocolFactory = TCompactProtocolFactory.sharedFactory()
    let queue = NSOperationQueue()
    
    let sessionConfig = NSURLSessionConfiguration.clientSessionCofigurationWithProtcolFactory(protocolFactory)
    let session = NSURLSession(configuration: sessionConfig, delegate: validator, delegateQueue: queue)
    
    // Build a client for the new session
    
    let transportFactory = THTTPSessionTransportFactory(session: session, URL: target.publicURL)
    
    return RTPublicAPIClientAsync(protocolFactory: protocolFactory,
                                  transportFactory: transportFactory)
  }
  
  private func makeUserAPI() -> RTUserAPIAsync {
    
    // Build an SSL validator
    
    let validator = RTURLSessionSSLValidator(trustedCertificates: RTServerAPI.pinnedCerts())
    
    // Build a session configured for UserAPI usage
    
    let protocolFactory = TCompactProtocolFactory.sharedFactory()
    
    let sessionConfig = NSURLSessionConfiguration.clientSessionCofigurationWithProtcolFactory(protocolFactory)
    let session = NSURLSession(configuration: sessionConfig, delegate: validator, delegateQueue: queue)
    
    // Build a client for the new session
    //
    
    let transportFactory = RTHTTPSessionTransportFactory(session: session, URL: MessageAPI.target.userURL)
    
    // Add interceptor to add bearer authorization token
    transportFactory.requestInterceptor = { request -> NSError? in
      
      if let accessToken = self.accessToken {
        request.addHTTPBearerAuthorizationWithToken(accessToken)
      }
      
      return nil
    }
    
    // Add interceptor to inspect for refreshed bearer tokens
    transportFactory.responseValidate = { (response, data) -> NSError? in
      
      if let updatedAccessToken = response.allHeaderFields[RTBearerRefreshHTTPHeader] as? String {
        self.updateAccessToken(updatedAccessToken)
      }
      
      return nil
    }
    
    return RTUserAPIClientAsync(protocolFactory: protocolFactory,
                                transportFactory:transportFactory)
  }
  
  private func makeWebSocket() -> RTWebSocket {
    
    let connectURLRequest = NSMutableURLRequest(URL: MessageAPI.target.userConnectURL)
    connectURLRequest.addBuildNumber()
    
    let webSocket = RTWebSocket(URLRequest: connectURLRequest)
    
    // MessageAPI is a websocket delegate and it authorized the connection (by
    // adding a Bearer header) as well as responds to events from the socket
    webSocket.delegate = self
    
    return webSocket
  }
  
  private class func makeCertificateTrust() throws -> RTOpenSSLCertificateTrust {
    
    let bundle = NSBundle(forClass: self)
    let rootsURL = bundle.URLForResource("roots", withExtension:"pem", subdirectory:"Certificates")!
    let intermediatesURL = bundle.URLForResource("inters", withExtension:"pem", subdirectory:"Certificates")!

    return try RTOpenSSLCertificateTrust(PEMEncodedRoots: NSData(contentsOfURL:rootsURL)!,
                                         intermediates: NSData(contentsOfURL:intermediatesURL)!)
  }
  
}



extension RTUserInfo : Persistable {
  
  public static func valueToData(value: RTUserInfo) throws -> NSData {
    return try TBaseUtils.serializeToData(value)
  }
  
  public static func dataToValue(data: NSData) throws -> AnyObject {
    return try TBaseUtils.deserialize(RTUserInfo(), fromData: data) as! RTUserInfo
  }
  
}
