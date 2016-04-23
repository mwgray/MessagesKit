//
//  MessageAPI.swift
//  ReTxt
//
//  Created by Kevin Wooten on 8/20/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import Operations


public typealias UserStatusInfo = RTUserStatusInfo

public typealias WebSocket = RTWebSocket
public typealias WebSocketDelegate = RTWebSocketDelegate

public typealias Credentials = RTCredentials

public class MessageAPI {
  
  public let credentials : Credentials
  
  private var accessToken : String?

  private var active = false
  private var activeChatId : Id?
  private var suspendedChatId : Id?
  
  private let publicAPIClient : PublicAPIAsyncClient
  private let userAPIClient : UserAPIAsyncClient

  private let dbManager : DBManager
  private let chatDAO : ChatDAO
  private let messageDAO : MessageDAO
  private let notificationDAO : NotificationDAO
  
  private let userInfoCache : PersistentCache<String, UserInfo>
  private let webSocket : WebSocket
  
  private var signedOut = false
  
  private let queue = OperationQueue()

  public init(credentials: Credentials, documentsDirectoryURL docsDirURL: NSURL) throws {
    
    credentials = credentials
    accessToken = nil
    
    let dbName = credentials.userId.UUIDString() + ".sqlite"
    let dbURL = docsDirURL.URLByAppendingPathComponent(dbName)
    
    if NSUserDefaults.standardUserDefaults().boolForKey("io.retxt.debug.ClearData") {
      NSFileManager.defaultManager.removeItemAtURL(dbURL)
    }
    
    
  }

  func findUserWithAlias(alias: String) -> Promise<Id?> {
    return __findUserWithAlias(alias).then(on: zalgo) { result in
      return result as? Id
    }
  }
  
  func resolveUserWithAlias(alias: String) throws -> UserInfo? {
    return try userInfoCache.objectForKey(alias) as? UserInfo
  }
  
  func invalidateUserWithAlias(alias: String) {
    userInfoCache.invalidateObjectForKey(alias)
  }
  
  public class func profileWithAlias(alias: String, password: String) -> Promise<UserProfile> {
    return Promise(resolvers: {fulfill, reject in
      MessageAPI.publicAPI()
        .profileWithAlias(alias, password: password,
          response: { fulfill($0) }, failure: { reject($0) })
    })
  }
  
  public class func profileWithId(userId: Id, password: String) -> Promise<UserProfile> {
    return Promise(resolvers: {fulfill, reject in
      MessageAPI.publicAPI()
        .profileWithId(userId, password: password,
          response: { fulfill($0) }, failure: { reject($0) })
    })
  }
  
}
