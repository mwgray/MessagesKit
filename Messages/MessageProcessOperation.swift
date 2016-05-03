//
//  MessageProcessOperation.swift
//  ReTxt
//
//  Created by Kevin Wooten on 7/26/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import Operations
import CocoaLumberjack


class MessageProcessOperation: Operation {
  
  let context : MessageFetchContext
  
  let api : MessageAPI
  
  
  init(context: MessageFetchContext, api: MessageAPI) {
    
    self.context = context

    self.api = api
    
    super.init()
    
    addCondition(NoFailedDependencies())
    addCondition(ReachabilityCondition(host: MessageAPI.target.userURL))
  }
  
  override func execute() {
    
    do {
      
      try processMsg()
      
      api.userAPI.ack(context.msg!.id, sent: context.msg!.sent)
      
    }
    catch let error {
      DDLogError("Error processing message: \(error)")
    }
    
  }
  
  func lookupChatWithMsg(msg: RTMsg) throws -> RTChat? {
    
    let chatAlias : String, chatLocalAlias : String
    
    // Sender/Recipient swapped in CC messages
    let isCC = (msg.flags & RTMsgFlagCC) == RTMsgFlagCC    
    if isCC {

      // CC only messages have the same sender & recipients
      if msg.recipient == msg.sender {

        // Extract original recipient
        if let originalRecipient = msg.metaData["recipient"] as? String {
          chatAlias = originalRecipient
        }
        else {
          DDLogError("Invalid CC message: missing original recipient")
          return nil
        }
      }
      else {
        
        chatAlias = msg.recipient
      }
      
      chatLocalAlias = msg.sender
    }
    else {
      
      chatAlias = msg.sender
      chatLocalAlias = msg.recipient
    }
    
    
    if !msg.groupIsSet {
      
      return try api.loadUserChatForAlias(chatAlias, localAlias: chatLocalAlias)
      
    }
    else {

      return try api.loadGroupChatForId(msg.group.chat, members: msg.group.members as NSSet as! Set<String>, localAlias: chatLocalAlias)
      
    }
    
  }
  
  func messageClassForMsgType(msgType: RTMsgType) -> RTMessage.Type? {
    
    switch msgType {
    case .Text:
      return RTTextMessage.self
      
    case .Image:
      return RTImageMessage.self
      
    case .Audio:
      return RTAudioMessage.self
      
    case .Video:
      return RTVideoMessage.self
      
    case .Location:
      return RTLocationMessage.self
      
    case .Contact:
      return RTContactMessage.self
      
    case .Enter:
      return RTEnterMessage.self
      
    case .Exit:
      return RTExitMessage.self
      
    case .Conference:
      return RTConferenceMessage.self
      
    default:
      DDLogError("MessageProcessOperation: Unknow RTMsgType, cannot provide class")
      return nil
    }
    
  }
  
  func parseMsg(msg: RTMsg, forChat chat: RTChat, decryptedData: DataReference?) throws -> RTMessage? {
    
    if let messageClass = messageClassForMsgType(msg.type) {

      let prevMessage = try api.messageDAO.fetchMessageWithId(msg.id)
        
      var message : RTMessage
      
      if prevMessage?.isKindOfClass(messageClass) ?? false {
        message = prevMessage!
      }
      else {
        message = messageClass.init()
        message.id = msg.id
        message.sender = msg.sender
        message.sent = NSDate(millisecondsSince1970:msg.sent)
        message.status = .Delivered
        message.statusTimestamp = NSDate()
        message.chat = chat
      }
      
      if prevMessage != nil {
        message.updated = NSDate()
      }
      
      try message.importPayloadFromData(decryptedData, withMetaData: msg.metaData as NSDictionary as! [NSObject: AnyObject])

      return message
    }
    
    return nil
  }
  
  func processMsg() throws {

    let msg = context.msg!
    
    switch msg.type {
    
    //
    // Delete Messages
    //
      
    case .Delete:
      
      // Verify Messages
      
      if try verifyMsg(msg) == false {
        DDLogError("MessageProcessOperation: Ignoring message \(msg.id) due to invalid signature")
        return
      }
      
      guard let type = msg.metaData["type"] as? String else {
        DDLogError("MessageProcessOperation: Delete: missing type")
        break
      }
      
      switch type {
      
      case "message":
        
        guard
          let msgIdVal = msg.metaData["msgId"] as? String,
          let msgId = RTId(string: msgIdVal)
        else {
          DDLogError("MessageProcessOperation: Delete: missing or invalid msgId")
          break
        }
        
        DDLogError("MessageProcessOperation: Deleting message: \(msgId.UUIDString())")
        
        api.messageDAO.markMessageDeletedWithId(msgId)
        
        if let deletedMessage = try api.messageDAO.fetchMessageWithId(msgId) {

         try api.deleteMessageLocally(deletedMessage)
          
        }
        
      case "chat":
        
        if let chat = try lookupChatWithMsg(msg) {
          
          try api.deleteChatLocally(chat)
          
        }
        
      default:
        break
      }
      

    //
    // Clarify messages
    //
    
    case .Clarify:

      // Verify Messages
      
      if try verifyMsg(msg) == false {
        DDLogError("MessageProcessOperation: Ignoring message \(msg.id) due to invalid signature")
        return
      }
      
      guard
        let msgIdVal = msg.metaData["msgId"] as? String,
        let msgId = RTId(string: msgIdVal)
      else {
        DDLogError("MessageProcessOperation: Clarify: missing or invalid msgId")
        break
      }

      guard let message = try api.messageDAO.fetchMessageWithId(msgId) else {
        break
      }

      let chat = message.chat

      // Mark unread if the chat for this message is not active

      let previouslyUnread = message.unreadFlag
      
      var flags : RTMessageFlags = .Clarify
      
      if !api.isChatActive(chat) {
        flags.insert(.Unread)
      }

      try api.messageDAO.updateMessage(message, withFlags: message.flags.intersect(flags).rawValue)

      if message.unreadFlag {

        api.chatDAO.updateChat(message.chat, withClarifiedCount:chat.clarifiedCount+1)

      }

      try signalMessage(message, wasPreviouslyUnread:previouslyUnread)
      

    //
    // View Receipt Messages
    //

    case .View:

      // Verify Messages
      
      if try verifyMsg(msg) == false {
        DDLogError("MessageProcessOperation: Ignoring message \(msg.id) due to invalid signature")
        return
      }
      
      guard
        let msgIdVal = msg.metaData["msgId"] as? String,
        let msgId = RTId(string: msgIdVal)
      else {
        DDLogError("MessageProcessOperation: View: missing or invalid msgId")
        break
      }
      
      guard let message = try api.messageDAO.fetchMessageWithId(msgId) else {
        break
      }
      
      try api.messageDAO.updateMessage(message, withStatus: .Viewed, timestamp:NSDate(millisecondsSince1970: msg.sent))

      let isCC = (msg.flags & RTMsgFlagCC) == RTMsgFlagCC
      if isCC {
        try api.hideNotificationForMessage(message)
      }
      
      
    //
    // Device authorization messages
    //
    
    case .Authorize:
      
      guard
        let encryptedKey = msg.key,
        let encryptedData = context.encryptedData
      else {
          DDLogError("MessageProcessOperation: Authorize: missing or invalid key/data")
          break
      }
      
      // Decrypt request data
      
      let key = try api.credentials.encryptionIdentity.privateKey.decryptData(encryptedKey)
      
      let cipher = RTMsgCipher(forKey: key)
      
      let data = try encryptedData.temporaryDuplicate { inStream, outStream in
        try cipher.decryptFromStream(inStream, toStream: outStream, withKey: key)
      }
      
      defer {
        let _ = try? data.delete()
      }
      
      // Deserialize request data
      guard let request = try TBaseUtils.deserialize(RTAuthorizeRequest(), fromData: try DataReferences.readAllDataFromReference(data)) as? RTAuthorizeRequest else {
        DDLogError("MessageProcessOperation: Authorize: unable to deserialize request")
        break
      }
      
      // Verify signature
      
      let deviceSigningKey : RTOpenSSLPublicKey
      do {
        deviceSigningKey = try RTOpenSSLCertificate(DEREncodedData: request.deviceSigningCert, validatedWithTrust: api.certificateTrust).publicKey
      }
      catch {
        throw NSError(code: .InvalidRecipientCertificate, userInfo: ["alias":msg.sender])
      }

      let signer = RTMsgSigner(publicKey: deviceSigningKey, signature: msg.signature)
      
      if try signer.verifyMsg(msg) == false {
        DDLogError("MessageProcessOperation: Authorize: invalid signature")
        return
      }
      
      produceOperation(AuthorizeDeviceOperation(request: request, api: api))


    //
    // Standard messages
    //
      
    default:
      
      // Verify Messages
      
      if try verifyMsg(msg) == false {
        DDLogError("MessageProcessOperation: Ignoring message \(msg.id) due to invalid signature")
        return
      }
      
      // Decrypt data (if present)
      //
      
      let key : NSData?
      let data : DataReference?
      
      if let encryptedKey = msg.key {
        
        guard let encryptedData = context.encryptedData else {
          DDLogError("MessageProcessOperation: Key present, no data")
          break
        }
        
        key = try api.credentials.encryptionIdentity.privateKey.decryptData(encryptedKey)
        
        let cipher = RTMsgCipher(forKey: key!)
        
        data = try encryptedData.temporaryDuplicate { inStream, outStream in
          try cipher.decryptFromStream(inStream, toStream: outStream, withKey: key!)
        }
        
      }
      else {
        key = nil
        data = nil
      }
      
      defer {
        let _ = try? data?.delete()
      }
    
      guard let chat = try lookupChatWithMsg(msg) else {
        DDLogError("MessageProcessOperation: Unable to find chat for message")
        break
      }
      
      // If message was previously deleted, ignore it now
      if api.messageDAO.isMessageDeletedWithId(msg.id) {
        DDLogError("MessageProcessOperation: Ignoring deleted message \(msg.id.UUIDString())")
        break
      }
      
      guard let message = try parseMsg(msg, forChat:chat, decryptedData: data) else {
        DDLogError("MessageProcessOperation: Unable to parse message")
        break
      }
      
      
      // Reset important stuff (in case this is an update)
      
      message.clarifyFlag = false
      
      // Mark unread if the chat for this message is not active
      
      let previosulyUnread = message.unreadFlag
      
      if !message.sentByMe && !api.isChatActive(message.chat) {
        
        message.unreadFlag = true
      }
      
      // Save the message
      
      try api.messageDAO.upsertMessage(message)
      
      if message.updated != nil {
        
        if message.unreadFlag {
          
          api.chatDAO.updateChat(chat, withUpdatedCount: chat.updatedCount+1)
          
        }
        
      }
      else {
        
        try api.chatDAO.updateChat(chat, withLastReceivedMessage:message)
        
      }
    
      // Handle enter/exit for group chats
      
      if msg.type == .Enter || msg.type == .Exit {
        
        if let groupChat = chat as? RTGroupChat, let memberAlias = msg.metaData["member"] as? String {
          
          if msg.type == .Enter {
            try api.chatDAO.updateChat(groupChat, addGroupMember: memberAlias)
          }
          else if msg.type == .Exit {
            try api.chatDAO.updateChat(groupChat, removeGroupMember: memberAlias)
          }
          
        }
        
      }
        
      if !message.sentByMe {
        
        // Play alerts, show notifications, etc.
        
        try signalMessage(message, wasPreviouslyUnread:previosulyUnread)
        
        
        // Send receipts for messages already read
        if !message.unreadFlag {
          
          produceOperation(SendMessageReceiptOperation(message: message, api: api))
          
        }
        
        dispatch_async(dispatch_get_main_queue()) {
          
          NSNotificationCenter.defaultCenter().postNotificationName(
            MessageAPIUserMessageReceivedNotification,
            object: self,
            userInfo: [MessageAPIUserMessageReceivedNotification_MessageKey:message])
        
        }
        
      }
      
    }
      
  }
  
  func signalMessage(message: RTMessage, wasPreviouslyUnread previouslyUnread: Bool) throws {
    
    // Play alert if the message's chat is currently active or no chat is active
    
    if api.active && (api.isChatActive(message.chat) || !api.isOtherChatActive(message.chat)) {
      
      playReceivedAlertForMessage(message)
    }
    
    // Handle unread messages
    
    if message.unreadFlag {
      
      // We only adjust the unread count if the message was already unread
      if !previouslyUnread {
        
        api.adjustUnreadMessageCountWithDelta(1)
        
      }
      
      if !api.active || api.isOtherChatActive(message.chat) {
        
        try api.showNotificationForMessage(message)
        
      }
    }
    
  }
  
  
  func verifyMsg(msg: RTMsg) throws -> Bool {
    
    if let signingCertData = try api.resolveUserInfoWithAlias(msg.sender)?.signingCert {
      
      let signingKey = try RTOpenSSLCertificate(DEREncodedData: signingCertData, validatedWithTrust: api.certificateTrust).publicKey
      
      if try RTMsgSigner(publicKey: signingKey, signature: msg.signature).verifyMsg(msg) {
        return true
      }
      
      api.invalidateUserInfoWithAlias(msg.sender)
        
      if let refreshedSigningCertData = try api.resolveUserInfoWithAlias(msg.sender)?.signingCert {

        let signingKey = try RTOpenSSLCertificate(DEREncodedData: refreshedSigningCertData, validatedWithTrust: api.certificateTrust).publicKey
        
        return try RTMsgSigner(publicKey: signingKey, signature: msg.signature).verifyMsg(msg)
        
      }
      
    }
    
    return false
  }

  func playReceivedAlertForMessage(message: RTMessage) {
    
    if message.soundAlert == .None {
      return
    }

    //FIXME
//    let sound = message.clarifyFlag ? RTSound_Message_Clarify : (message.updated != nil ? RTSound_Message_Update : RTSound_Message_Receive)
//    RTAppDelegate.playSound(sound, alert: true)
    
  }
  
}
