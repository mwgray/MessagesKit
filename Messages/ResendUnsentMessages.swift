//
//  ResendUnsentMessages.swift
//  Messages
//
//  Created by Kevin Wooten on 4/23/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation
import Operations
import CocoaLumberjack


class ResendUnsentMessages: Operation {
  
  let api : MessageAPI
  
  init(api: MessageAPI) {
    
    self.api = api
    
    super.init()
    
    addCondition(RequireAccessToken(api: api))
    addCondition(ReachabilityCondition(host: MessageAPI.target.publicURL))
  }
  
  override func execute() {

    do {
      
      for message in try api.messageDAO.fetchUnsentMessages() {
      
        produceOperation(MessageSendOperation(message: message, api: api))
      
      }
      
      finish()
    }
    catch let error {
      finishWithError(error as NSError)
    }
    
  }
  
}
