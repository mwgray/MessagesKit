//
//  MessageBuildSystemOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 7/23/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import PSOperations


/*
  Builds the deliverable message.
*/
class MessageBuildSystemOperation: Operation {
  
  
  let msgType : MsgType
  
  let chat : Chat
  
  let metaData : [String: String]

  let target : SystemMsgTarget
  
  var transmitContext : MessageTransmitContext
  
  let api : MessageAPI
  
  
  init(msgType: MsgType, chat: Chat, metaData: [String: String], target: SystemMsgTarget, transmitContext: MessageTransmitContext, api: MessageAPI) {
    
    self.msgType = msgType
    self.chat = chat
    self.metaData = metaData
    self.target = target
    
    self.transmitContext = transmitContext
    self.api = api
    
    super.init()
    
    addCondition(NoFailedDependencies())
  }
  
  override func execute() {
    
    do {
      
      let msgPack = MsgPack()
      msgPack.id = Id.generate()
      msgPack.type = msgType
      msgPack.sender = chat.localAlias
      msgPack.metaData = (metaData as NSDictionary).mutableCopy() as! NSMutableDictionary
      
      if let groupChat = chat as? GroupChat {
        msgPack.chat = Id(string: groupChat.alias)
      }
      
      // Add recipient envelopes
      
      let signer = MsgSigner.defaultSignerWithKeyPair(api.credentials.signingIdentity.keyPair)

      msgPack.envelopes = []
      
      // Determine which regular recipients (if any)
      var recipients : Set<String>?
      if target.contains(.ActiveRecipients) && target.contains(.InactiveRecipients) {
        recipients = chat.allRecipients
      }
      else if target.contains(.ActiveRecipients) {
        recipients = chat.activeRecipients
      }
      
      if let recipients = recipients {
        
        // Add recipient envelopes
        for recipient in recipients {
          
          // Skip sender (added at end)
          if recipient == chat.localAlias {
            continue
          }
          
          let envelope = Envelope(
            recipient:recipient,
            key:nil,
            signature: try signer.signWithId(msgPack.id, type: msgType, sender: chat.localAlias, recipient: recipient, chatId: msgPack.chat, msgKey: nil),
            fingerprint: nil)
          
          msgPack.envelopes.addObject(envelope)
        }
        
      }
      
      if target.contains(.CC) {
        
        // Add sender envelope (for CC)
        
        let ccEnvelope = Envelope(
          recipient: chat.localAlias,
          key: nil,
          signature: try signer.signWithId(msgPack.id, type: msgType, sender: chat.localAlias, recipient: chat.localAlias, chatId: msgPack.chat, msgKey: nil),
          fingerprint: nil)
        
        
        msgPack.envelopes.addObject(ccEnvelope)
        
      }
      
      if target == .CC {
        msgPack.metaData!["recipient"] = chat.alias
      }

      transmitContext.msgPack = msgPack
      transmitContext.encryptedData = nil
      
      finish()
      
    }
    catch let error as NSError {
      finishWithError(error)
    }
    
  }
  
  override var description : String {
    return "Send: Build"
  }
  
}
