//
//  MessageSendDirectOperation.swift
//  ReTxt
//
//  Created by Kevin Wooten on 7/28/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import Operations


/*
  Send direct message
*/
@objc public class MessageSendDirectOperation : MessageAPIOperation {
  
  
  let sender : String
  
  let recipientDevices : [String: RTId]
  
  let msgId : RTId
  
  let msgType : String
  
  let msgData : NSData?
  
  
  public required init(sender: String, recipientDevices: [String: RTId], msgId: RTId?, msgType: String, msgData: NSData?, api: MessageAPI) {
    self.sender = sender
    self.recipientDevices = recipientDevices
    self.msgId = msgId ?? RTId()
    self.msgType = msgType
    self.msgData = msgData
    
    super.init(api: api)
    
    addCondition(ReachabilityCondition(host: MessageAPI.target.userURL))
    
    addObserver(NetworkObserver())
  }
  
  public override func execute() {
    
    do {
      
      // Encrypt data (if present)
      
      let cipher = RTMsgCipher.defaultCipher()
      
      var key : NSData?
      var encryptedData : NSData?
      
      if let msgData = msgData {
        
        key = try cipher.randomKey()
        
        encryptedData = try cipher.encryptData(msgData, withKey: key!)
        
      }

      // Make envelope for each recipient
      
      var envelopes = [RTDirectEnvelope]()
      
      for (recipientAlias, recipientDeviceId) in recipientDevices {
        
        guard let recipientInfo = try api.resolveUserInfoWithAlias(recipientAlias) else {
          throw NSError(code: .InvalidRecipientAlias, userInfo: ["alias":recipientAlias])
        }

        var encryptedKey : NSData?
        
        let signer = RTMsgSigner.defaultSignerWithKeyPair(api.credentials.signingIdentity.keyPair)
        
        if let key = key {
          
          let recipientKey : RTOpenSSLPublicKey
          do {
            recipientKey = try RTOpenSSLCertificate(DEREncodedData: recipientInfo.encryptionCert, validatedWithTrust: api.certificateTrust).publicKey
          }
          catch {
            throw NSError(code: .InvalidRecipientCertificate, userInfo: ["alias":recipientAlias])
          }
          
          encryptedKey = try recipientKey.encryptData(key)
        }
        
        let envelope = RTDirectEnvelope(
          recipient: recipientAlias,
          device: recipientDeviceId,
          key: encryptedKey,
          signature: try signer.signWithId(msgId, type: msgType, sender: sender, recipientDevice: recipientDeviceId, msgKey: encryptedKey),
          fingerprint: recipientInfo.fingerprint)
        
        envelopes.append(envelope)
        
      }

      api.userAPI.sendDirect(msgId, msgType: msgType, msgData: encryptedData, sender: sender, envelopes: envelopes,
        response: {
          self.finish()
        },
        failure: { error in
          self.finishWithError(error)
        })
      
    }
    catch let error as NSError {
      finishWithError(error)
    }
    
  }
  
}
