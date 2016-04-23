//
//  MessageSendEncryptOperation.swift
//  ReTxt
//
//  Created by Kevin Wooten on 7/23/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import Operations


/*
  Encrypts message data
*/
class MessageEncryptOperation: Operation {
  
  
  var context : MessageBuildContext
  
  let cipher = RTMsgCipher.defaultCipher()
  
  
  init(context: MessageBuildContext) {
    
    self.context = context
    
    super.init()
    
    addCondition(NoFailedDependencies())
  }
  
  override func execute() {
    
    do {
      
      var data : DataReference?
      
      try context.message.exportPayloadIntoData(&data, withMetaData: &context.metaData)
      
      // Encrypt message data with random key
      
      if let data = data {
        
        context.key = try cipher.randomKey()
        
        context.encryptedData = try data.temporaryDuplicate { ins, outs in
          try self.cipher.encryptFromStream(ins, toStream: outs, withKey: self.context.key!)
        }
        
      }
      
      finish()
      
    }
    catch let error as NSError {
      finishWithError(error)
    }
    
  }
  
  override var description : String {
    return "Send: Encrypt"
  }
  
}
