//
//  MessageBuildOperation.swift
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
class MessageBuildOperation: Operation {
  
  
  var buildContext : MessageBuildContext
  
  var transmitContext : MessageTransmitContext
  
  let api : MessageAPI
  
  
  init(buildContext: MessageBuildContext,  transmitContext: MessageTransmitContext, api: MessageAPI) {
    
    self.buildContext = buildContext
    self.transmitContext = transmitContext
    
    self.api = api
    
    super.init()
    
    addCondition(NoFailedDependencies())
  }
  
  override func execute() {
    
    do {
      
      let message = buildContext.message
      
      let msgType = message.payloadType;
      let chatId = message.chat.isGroup ? Id(string: message.chat.alias) : nil
      
      var envelopes = [Envelope]()
      
      let signer = MsgSigner.defaultSignerWithKeyPair(api.credentials.signingIdentity.keyPair)

      if let key = buildContext.key {
        
        // Generate envelopes for the message
        
        for (recipientAlias, recipientInfo) in buildContext.recipientInformation! {
          
          let recipientKey : OpenSSLPublicKey
          do {
            recipientKey = try OpenSSLCertificate(DEREncodedData: recipientInfo.encryptionCert, validatedWithTrust: api.certificateTrust).publicKey
          }
          catch {
            throw NSError(code: .InvalidRecipientCertificate, userInfo: ["alias":recipientAlias])
          }
          
          let encryptedKey = try recipientKey.encryptData(key)
          let signature = try signer.signWithId(message.id, type: msgType, sender: message.sender!, recipient: recipientAlias, chatId: chatId, msgKey: encryptedKey)
          
          envelopes.append(
            Envelope(recipient: recipientAlias, key: encryptedKey, signature: signature, fingerprint: recipientInfo.fingerprint)
          )
          
        }
        
        // Generate a CC envelope
        
        let encryptedCCKey = try api.credentials.encryptionIdentity.publicKey.encryptData(key)
        let ccSignature = try signer.signWithId(message.id, type: msgType, sender: message.sender!, recipient: message.chat.localAlias, chatId: chatId, msgKey: encryptedCCKey)
        
        envelopes.append(
          Envelope(recipient: message.chat.localAlias, key: encryptedCCKey, signature: ccSignature, fingerprint: nil)
        )
        
      }

      // Fill out context

      transmitContext.msgPack =
        MsgPack(
          id: message.id,
          type: msgType,
          sender: message.sender,
          envelopes: envelopes,
          chat: chatId,
          metaData: buildContext.metaData as! [String: String],
          data: nil)
      
      transmitContext.encryptedData = buildContext.encryptedData
      
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
