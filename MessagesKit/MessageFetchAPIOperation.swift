//
//  MessageFetchAPIOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 7/26/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import PSOperations


class MessageFetchAPIOperation: Operation {
  
  
  var context : MessageFetchContext
  
  let api : UserAPIAsync
 
  
  init(context: MessageFetchContext, api: UserAPIAsync) {
    
    self.context = context
    self.api = api
    
    super.init()
    
    addCondition(NoFailedDependencies())
    addCondition(ReachabilityCondition(host: MessageAPI.target.userURL))
    
    addObserver(NetworkObserver())
  }
  
  override func execute() {
    
    api.fetch(context.msgHdr!.id,
      response: { msg in
        
        self.context.msg = msg
        self.context.encryptedData = msg.dataIsSet ? MemoryDataReference(data: msg.data) : nil
        
        self.finish()
      },
      failure: { error in
        
        self.finishWithError(error)
        
    })
    
  }
  
  override var description : String {
    return "Recv: Transmit (API)"
  }
  
}
