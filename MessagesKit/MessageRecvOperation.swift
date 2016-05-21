//
//  MessageRecvOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 7/26/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import PSOperations


/*
  Fetch message via API
*/

class MessageRecvOperation: MessageAPIGroupOperation, MessageFetchContext {
  
  
  var msgHdr : MsgHdr?
  
  var msg : Msg?
  
  var encryptedData : DataReference?
  
  
  init(msgHdr: MsgHdr, api: MessageAPI) {
    
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
    
    
    [fetch, save].forEach { addOperation($0) }
  }
  
  init(msg: Msg, api: MessageAPI) {
    
    self.encryptedData = msg.data != nil ? MemoryDataReference(data: msg.data, ofMIMEType: "application/octet-stream") : nil
    
    self.msg = msg
    
    super.init(api: api)
    
    let save = MessageProcessOperation(context: self, api: api)
    
    addOperation(save)
  }
  
}
