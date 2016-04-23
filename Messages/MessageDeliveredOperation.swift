//
//  MessageDeliveredOperation.swift
//  ReTxt
//
//  Created by Kevin Wooten on 7/28/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation


@objc public class MessageDeliveredOperation: MessageAPIOperation {
  
  
  let msgId : RTId
  
  
  public init(msgId: RTId, api: RTMessageAPI) {
    
    self.msgId = msgId
  
    super.init(api: api)
  }
  
  public override func execute() {
    
    do {
      
      if let deliveredMessage = try api.messageDAO.fetchMessageWithId(msgId) {
      
        if (deliveredMessage.status.rawValue > RTMessageStatus.Delivered.rawValue) {
          return;
        }
      
        api.messageDAO.updateMessage(deliveredMessage, withStatus: .Delivered)
      }
      
    }
    catch _ {
      //TODO log error
    }
    
  }
  
}
