//
//  MessageTransmitAPIOperation.swift
//  ReTxt
//
//  Created by Kevin Wooten on 7/23/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import Operations


/*
  Transmits the message via the standard UserAPI
*/
class MessageTransmitAPIOperation: Operation {
  
  
  var context: MessageTransmitContext
  
  var userAPI: RTUserAPIAsync

  
  init(context: MessageTransmitContext, userAPI: RTUserAPIAsync) {
    
    self.context = context
    self.userAPI = userAPI
    
    super.init()
    
    addCondition(NoFailedDependencies())
    addCondition(ReachabilityCondition(host: MessageAPI.target.userURL))

    addObserver(NetworkObserver())
  }
  
  override func execute() {
    
    if context.encryptedData != nil {
      
      do {
        context.msgPack!.data = try DataReferences.readAllDataFromReference(context.encryptedData!)
      }
      catch let error as NSError {
        finishWithError(error)
        return
      }
      
    }
    
    userAPI.send(context.msgPack, response: { sentAt in
      
      self.context.sentAt = sentAt as RTTimeStamp
      
      self.finish()
      
      }, failure: { error in
        
        self.finishWithError(error)
    })
    
  }
  
  override var description : String {
    return "Send: Transmit (API)"
  }
  
}
