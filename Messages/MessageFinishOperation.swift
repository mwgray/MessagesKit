//
//  MessageFinishOperation.swift
//  ReTxt
//
//  Created by Kevin Wooten on 7/23/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import Operations


/*
  Finalizes the sending of the message
*/
class MessageFinishOperation: Operation {
  
  
  let messageContext: MessageContext
  
  let transmitContext : MessageTransmitContext
  
  let dao: RTMessageDAO
  
  
  init(messageContext: MessageContext, transmitContext: MessageTransmitContext, dao: RTMessageDAO) {
    
    self.messageContext = messageContext
    self.transmitContext = transmitContext
    self.dao = dao
    
    super.init()
    
    addCondition(NoFailedDependencies())
  }
  
  override func execute() {
    
    //FIXME
    //RTAppDelegate.playSound(RTSound_Message_Send, alert: false);
    
    // Update sent only if the message has never been sent before
    if (messageContext.message.updated == nil) {
      try! dao.updateMessage(messageContext.message, withSent:NSDate(millisecondsSince1970: transmitContext.sentAt!))
    }
    
    // Ensure we don't overwrite "Delivered" or "Viewed"
    // statuses if they were sent very fast
    if (messageContext.message.status.rawValue <= RTMessageStatus.Sent.rawValue) {
      try! dao.updateMessage(messageContext.message, withStatus:.Sent);
    }
    
    let _ = try? transmitContext.encryptedData?.delete()
    
    finish()
  }
  
  override var description : String {
    return "Send: Finish"
  }
  
}
