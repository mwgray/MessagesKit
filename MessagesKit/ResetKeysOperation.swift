//
//  ResetKeysOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/15/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation
import PSOperations


/*
 * Generates new encryption keys & updates the account certificates
 */
class ResetKeysOperation : MessageAPIOperation {

  override init(api: MessageAPI) {
    super.init(api: api)
    
    addCondition(NoFailedDependencies())
    addCondition(ReachabilityCondition(host: MessageAPI.target.userURL))
    addCondition(RequireAccessToken(api: api))
    
    addObserver(NetworkObserver())
  }
  
  override var resolveResult : Any? {
    return api.credentials
  }
  
  override func execute() {
    
    do {
      
      let encryptionIdentityRequest =
        try AsymmetricKeyPairGenerator.generateIdentityRequestNamed("reTXT Encryption",
                                                                    withKeySize: 2048,
                                                                    usage: [.KeyEncipherment, .NonRepudiation])
      
      let signingIdentityRequest =
        try AsymmetricKeyPairGenerator.generateIdentityRequestNamed("reTXT Signing",
                                                                    withKeySize: 2048,
                                                                    usage: [.DigitalSignature, .NonRepudiation])
      
      api.userAPI.updateCertificates(encryptionIdentityRequest.certificateSigningRequest.encoded, signingCSR: signingIdentityRequest.certificateSigningRequest.encoded)
        .then { certs -> Void in
          
          guard let certs = certs as? CertificateSet else {
            throw MessageAPIError.UnknownError
          }
          
          let encryptionCert = try OpenSSLCertificate(DEREncodedData: certs.encryptionCert, validatedWithTrust: self.api.certificateTrust)
          let encryptionIdent = encryptionIdentityRequest.buildIdentityWithCertificate(encryptionCert)
          
          let signingCert = try OpenSSLCertificate(DEREncodedData: certs.signingCert, validatedWithTrust: self.api.certificateTrust)
          let signingIdent = signingIdentityRequest.buildIdentityWithCertificate(signingCert)
          
          self.api.credentials = self.api.credentials.authorizeWithEncryptionIdentity(encryptionIdent, signingIdentity: signingIdent)
          
          self.finish()
        }
 
    }
    catch let error {
      finishWithError(error as NSError)
    }
    
  }
  
}