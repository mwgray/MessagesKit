//
//  MessageFinishOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 7/23/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import PSOperations


/*
  Finalizes the sending of the message
*/
class MessageFinishOperation: Operation {
  
  
  let messageContext: MessageContext
  
  let transmitContext : MessageTransmitContext
  
  let dao: MessageDAO
  
  
  init(messageContext: MessageContext, transmitContext: MessageTransmitContext, dao: MessageDAO) {
    
    self.messageContext = messageContext
    self.transmitContext = transmitContext
    self.dao = dao
    
    super.init()
    
    addCondition(NoFailedDependencies())
  }
  
  override func execute() {
    
    MessageSoundType.Sent.play()
    
    // Update sent only if the message has never been sent before
    if messageContext.message.updated == nil {
      try! dao.updateMessage(messageContext.message, withSent:NSDate(millisecondsSince1970: transmitContext.sentAt!))
    }
    
    // Ensure we don't overwrite "Delivered" or "Viewed"
    // statuses if they were sent very fast
    if messageContext.message.status.rawValue <= MessageStatus.Sent.rawValue {
      try! dao.updateMessage(messageContext.message, withStatus:.Sent);
    }
    
    finish()
  }
  
  override var description : String {
    return "Send: Finish"
  }
  
}
