//
//  MessageSendSystemOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 7/28/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import PSOperations
import Thrift


/*
  Send system message
*/
@objc public class MessageSendSystemOperation: MessageAPIGroupOperation, MessageResolveContext, MessageTransmitContext {
  
  
  var recipients : Set<String>
  
  var recipientInformation : [String: RTUserInfo]?
  
  var msgPack : RTMsgPack?
  
  var encryptedData : DataReference?
  
  var sentAt : RTTimeStamp?
  
  
  public init(msgType: RTMsgType, chat: RTChat, metaData: [String: String], target: SystemMsgTarget, api: MessageAPI) {
    
    var recipients : Set<String>
    
    if target.contains(.ActiveRecipients) && target.contains(.InactiveRecipients) {
      recipients = chat.allRecipients
    }
    else if target.contains(.ActiveRecipients) {
      recipients = chat.activeRecipients
    }
    else {
      recipients = []
    }
    
    if target.contains(.CC) {
      recipients = recipients.union(Set(api.credentials.allAliases))
    }
    
    self.recipients = recipients
    
    super.init(api: api)

    let failures : [String: Int?] = [
      TTransportErrorDomain: Int(THttpTransportError.Authentication.rawValue),  // TODO: FIX THIS
      NSURLErrorDomain: NSURLErrorUserAuthenticationRequired
    ]
    
    // Resolve operation
    
    let resolve = RetryOperation(maxAttempts: 3, failureErrors:failures, generator:{
      return MessageRecipientResolveOperation(context: self, api: api)
    })
    
    // Build operation
    
    let build = MessageBuildSystemOperation(msgType: msgType, chat: chat, metaData: metaData, target: target, transmitContext: self, api: api)
    
    build.addDependency(resolve)
    
    // Transmit operation
    
    let transmit = RetryOperation(maxAttempts: 3, failureErrors:failures, generator: {
      return MessageTransmitAPIOperation(context: self, userAPI: api.userAPI)
    })
    
    transmit.addDependency(build)
    
    [resolve, build, transmit].forEach { addOperation($0) }
  }
  
}
