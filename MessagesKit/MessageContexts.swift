//
//  MessageContexts.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 7/23/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation


protocol MessageResolveContext {
  
  var recipients : Set<String> { get }

  var recipientInformation : [String: UserInfo]? { get set }
  
}


protocol MessageContext {
  
  var message : Message { get }
  
}


protocol MessageBuildContext : MessageContext {
  
  var recipientInformation : [String: UserInfo]? { get set }
  
  var metaData : NSDictionary? { get set }
  
  var key : NSData? { get set }
  
  var encryptedData : DataReference? { get set }
  
}


protocol MessageTransmitContext {
  
  var msgPack : MsgPack? { get set }
  
  var encryptedData : DataReference? { get set }
  
  var sentAt : TimeStamp? { get set }
  
}


protocol MessageSaveContext {
    
  var msg : Msg? { get set }
  
  var encryptedData : DataReference? { get set }
  
}

protocol MessageFetchContext : MessageSaveContext {
  
  var msgHdr : MsgHdr? { get }
  
}
