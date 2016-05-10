//
//  MessageDeliveredOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 7/28/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation


class MessageDeliveredOperation: MessageAPIOperation {
  
  
  let msgId : Id
  
  
  init(msgId: Id, api: MessageAPI) {
    
    self.msgId = msgId
  
    super.init(api: api)
  }
  
  override func execute() {
    
    do {
      
      if let deliveredMessage = try api.messageDAO.fetchMessageWithId(msgId) {
      
        if (deliveredMessage.status.rawValue > MessageStatus.Delivered.rawValue) {
          return;
        }
      
        try api.messageDAO.updateMessage(deliveredMessage, withStatus: .Delivered)
      }
      
    }
    catch _ {
      //TODO log error
    }
    
  }
  
}
