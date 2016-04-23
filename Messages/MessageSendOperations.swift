//
//  MessageSenderOperation.swift
//  ReTxt
//
//  Created by Kevin Wooten on 7/24/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import Operations
import Thrift

/*
  Message send meta-operation

  Group operation that handles all different stages of sending messages.
*/
@objc public class MessageSendBaseOperation: MessageAPIGroupOperation, MessageContext, MessageResolveContext, MessageTransmitContext {
  
  let message : RTMessage
  var recipientInformation : [String: RTUserInfo]?
  var encryptedData : DataReference?
  var msgPack : RTMsgPack?
  var sentAt : RTTimeStamp?
  
  var recipients : Set<String> {
    return message.chat.activeRecipients
  }
  
  init(message: RTMessage, api: RTMessageAPI) {
    
    self.message = message
    
    super.init(api: api)

    addObserver(
      BlockObserver(
        startHandler: { op in
          
          if (message.status != .Sending) {
            api.messageDAO.updateMessage(message, withStatus: .Sending)
          }
          
        },
        produceHandler: nil,
        finishHandler: { op, errors in
          
          if !errors.isEmpty {
            
            api.messageDAO.updateMessage(message, withStatus: api.networkUnavailable ? .Unsent : .Failed)
            
          }
          
        }
      )
    )
  }
  
  public override func childOperation(operation: NSOperation, didFinishWithErrors errors: [NSError]) {
    
    if errors.isEmpty {
      return
    }
    
    finishWithErrors(errors)
    
  }
  
}


/*
  Complete message send operation

  Encrypts, resolves recipients, transmits & completes
  the send of a message. Includes retrying the operations
  that require network access.
*/
@objc public class MessageSendOperation: MessageSendBaseOperation, MessageBuildContext {
  
  
  var metaData : NSDictionary?
  var key : NSData?
  
  
  public required override init(message: RTMessage, api: RTMessageAPI) {
    
    super.init(message: message, api: api)
    
    addCondition(RequireAuthorization(api: api))

    let failures : [String: Int?] = [
      RTAPIErrorDomain: Int(RTAPIError.AuthenticationError.rawValue)
    ]
    
    // Resolve operation
    
    let resolve = RetryOperation(maxAttempts: 3, failureErrors: failures, generator:{
      return MessageRecipientResolveOperation(context: self, api: api)
    })
    
    // Encrypt operation
    
    let encrypt = MessageEncryptOperation(context: self)
    
    // Build operation
    
    let build = MessageBuildOperation(buildContext: self, transmitContext: self, api: api)
    build.addDependencies([resolve, encrypt])
    
    // Build transmit (API or HTTP)

    let transmit : Operation
    
    switch message.payloadType {
      
    case .Image, .Audio, .Video:
      
      // Transmit via HTTP upload
      
      transmit = MessageTransmitHTTPOperation(context: self, api: api)
      
    default:
      
      // Transmit via API send
      
      transmit = RetryOperation(maxAttempts: 3, failureErrors:failures, generator: {
        return MessageTransmitAPIOperation(context: self, userAPI: api.userAPI)
      })
      
    }
    
    transmit.addDependency(build)
    
    // Finish operation
    
    let finish = MessageFinishOperation(messageContext: self, transmitContext: self, dao: api.messageDAO)
    finish.addDependency(transmit)
    
    addOperations([resolve, encrypt, build, transmit, finish])
  }
  
}


/*
  Handles resurrection of send operations that have been handed
  off to the background transfer service and need to be recreated
  because of app shutdown during transfer
*/
@objc public class MessageSendResurrectedOperation: MessageSendBaseOperation {
  
  required public init(msgPack: RTMsgPack, task: NSURLSessionUploadTask, api: RTMessageAPI) throws {
    
    super.init(message: try api.messageDAO.fetchMessageWithId(msgPack.id)!, api: api)
    
    self.msgPack = msgPack
    
    let transmit = MessageTransmitHTTPOperation(task: task, context: self, api: api)
    
    let finish = MessageFinishOperation(messageContext: self, transmitContext: self, dao: api.messageDAO)
    finish.addDependency(transmit)
    
    addOperations([transmit, finish])
    
  }
  
}
