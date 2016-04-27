//
//  MessageRecvOperation.swift
//  ReTxt
//
//  Created by Kevin Wooten on 7/26/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import Operations


/*
  Fetch message via API
*/

@objc public class MessageRecvOperation: MessageAPIGroupOperation, MessageFetchContext {
  
  
  var msgHdr : RTMsgHdr?
  
  var msg : RTMsg?
  
  var encryptedData : DataReference?
  
  
  public init(msgHdr: RTMsgHdr, api: MessageAPI) {
    
    self.msgHdr = msgHdr
    
    super.init(api: api)
    
    addCondition(RequireAuthorization(api: api))
    
    let fetch : Operation
    
    switch msgHdr.type {

    case .Image, .Audio, .Video:
      
      fetch = MessageFetchHTTPOperation(context: self, api: api)
      
    default:
      
      fetch = MessageFetchAPIOperation(context: self, api: api.userAPI)
      
    }
    
    let save = MessageProcessOperation(context: self, api: api)
    save.addDependency(fetch)
    
    
    addOperations([fetch, save])
  }
  
  public init(msg: RTMsg, api: MessageAPI) {
    
    self.encryptedData = msg.data != nil ? MemoryDataReference(data: msg.data) : nil
    
    self.msg = msg
    
    super.init(api: api)
    
    let save = MessageProcessOperation(context: self, api: api)
    
    addOperations([save])
  }
  
}
