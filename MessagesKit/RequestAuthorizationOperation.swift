//
//  RequestAuthorizationOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 7/30/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import PSOperations


class RequestAuthorizationOperation: MessageAPIOperation {

  
  let alias : String
  
  let deviceId : RTId
  
  let deviceName : String
  
  let cipher : RTMsgCipher
  let signer : RTMsgSigner
  
  
  init(alias: String, deviceId: RTId, deviceName: String, api: MessageAPI) {

    self.alias = alias
    self.deviceId = deviceId
    self.deviceName = deviceName
    
    self.cipher = RTMsgCipher.defaultCipher()
    self.signer = RTMsgSigner.defaultSignerWithKeyPair(api.credentials.signingIdentity.keyPair)

    super.init(api: api)
    
    addCondition(NoFailedDependencies())
    addCondition(ReachabilityCondition(host: MessageAPI.target.userURL))
    
    addObserver(NetworkObserver())
  }
  
  override func execute() {
    
    do {

      // Request up-to-date user information for ourself
      
      api.invalidateUserInfoWithAlias(alias);
      
      guard let userInfo = try api.resolveUserInfoWithAlias(alias) else {
        throw MessageAPIError.RequiredUserUnknown
      }
      
      // Build authorization request
      
      let request = RTAuthorizeRequest(
        deviceId: deviceId,
        deviceName: deviceName,
        deviceEncryptionCert: api.credentials.encryptionIdentity.certificate.encoded,
        deviceSigningCert: api.credentials.signingIdentity.certificate.encoded,
        requestor: ""
      )
      
      // Serialize and encrypt request
      
      let requestData = try TBaseUtils.serializeToData(request)

      let key = try cipher.randomKey()
      let encryptedRequestData = try cipher.encryptData(requestData, withKey: key)
      
      let id = RTId.generate()
      
      let userEncryptionCert = try RTOpenSSLCertificate(DEREncodedData: userInfo.encryptionCert, validatedWithTrust: api.certificateTrust)
      
      let encryptedKey = try userEncryptionCert.publicKey.encryptData(key)
      
      let signature = try signer.signWithId(id, type: .Authorize, sender: api.credentials.preferredAlias, recipient: api.credentials.preferredAlias, chatId: nil, msgKey: encryptedKey)
      
      // Assemble & send message
      
      let msg = RTMsgPack(
        id: id,
        type: .Authorize,
        sender: api.credentials.preferredAlias,
        envelopes: [RTEnvelope(recipient: api.credentials.preferredAlias, key: encryptedKey, signature: signature, fingerprint: nil)],
        chat: nil,
        metaData: nil,
        data: encryptedRequestData)
      
      api.userAPI.send(msg, response: { sent in
        
        self.finish()
        
        }, failure: { error in
          
          self.finishWithError(error)
          
      })
      
    }
    catch let error as NSError {
      finishWithError(error)
      return;
    }
    
  }
  
}
