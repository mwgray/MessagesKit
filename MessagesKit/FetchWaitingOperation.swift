//
//  FetchWaitingOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 7/28/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation


public class FetchWaitingOperation: MessageAPIOperation {
  
  
  public var total = 0
  
  public override init(api: MessageAPI) {
    
    super.init(api: api)
    
    addCondition(RequireAuthorization(api: api))
  }
  
  public override var resolveResult : AnyObject {
    return total
  }
  
  public override func execute() {
    
    api.userAPI.fetchWaiting({ msgHdrs in
      
      self.total = msgHdrs.count
      
      for msgHdr in msgHdrs {
        
        self.produceOperation(MessageRecvOperation(msgHdr: msgHdr, api: self.api))
        
      }
      
      self.finish()
      
    }, failure: { error in
      
      self.finishWithError(error)
      
    })
    
  }
  
}
