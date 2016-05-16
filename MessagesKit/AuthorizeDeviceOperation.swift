//
//  AuthorizeDeviceOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 7/29/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import PSOperations


/*
 * Authorizes a device
 */
class AuthorizeDeviceOperation: MessageAPIOperation {
  
  let signer : MsgSigner
  let cipher : MsgCipher

  let request : AuthorizeRequest
  
  let pin = String(randomDigitsOfLength: 4)
  
  required init(request: AuthorizeRequest, api: MessageAPI) {
    
    self.signer = MsgSigner.defaultSignerWithKeyPair(api.credentials.signingIdentity.keyPair)
    self.cipher = MsgCipher.defaultCipher()

    self.request = request
    
    super.init(api: api)
    
    addCondition(DeviceAuthorizationCondition(deviceName: request.deviceName, pin: pin))
    addCondition(NoFailedDependencies())
    addCondition(ReachabilityCondition(host: MessageAPI.target.userURL))
    
    addObserver(NetworkObserver())
  }
  
  override func execute() {
    
    do {
      
      // Build keyset
      
      let keySet = KeySet(
        encryptionKeyPair: try api.credentials.encryptionIdentity.exportPKCS12WithPassphrase(pin),
        signingKeyPair: try api.credentials.signingIdentity.exportPKCS12WithPassphrase(pin)
      )
      
      // Serialize and encrypt keyset
      
      let keySetData = try TBaseUtils.serializeToData(keySet)
      
      let key = try cipher.randomKey()
      let encryptedKeySetData = try cipher.encryptData(keySetData, withKey: key)

      // Generate message signature
      
      let id = Id.generate()
      
      let deviceEncryptionKey : OpenSSLPublicKey
      do {
        deviceEncryptionKey = try OpenSSLCertificate(DEREncodedData: request.deviceEncryptionCert, validatedWithTrust: api.certificateTrust).publicKey
      }
      catch {
        throw MessageAPIError.InvalidRecipientCertificate
      }
      
      let encryptedKey = try deviceEncryptionKey.encryptData(key)
      
      let signature = try signer.signWithId(id, type: MessageAPIDirectMessageMsgTypeKeySet, sender: api.credentials.preferredAlias, recipientDevice: request.deviceId, msgKey: encryptedKey)
      
      // Send message
      
      let envelope = DirectEnvelope(recipient: api.credentials.preferredAlias, device: request.deviceId, key: encryptedKey, signature: signature, fingerprint: nil)
      
      api.userAPI.sendDirect(id, msgType: MessageAPIDirectMessageMsgTypeKeySet, msgData: encryptedKeySetData, sender: api.credentials.preferredAlias, envelopes: [envelope], response: {
        
        self.finish()
        
      }, failure: { error in
        
        self.finishWithError(error)
        
      })
      
    }
    catch let error as NSError {
      
      finishWithError(error);

    }
    
    
    
  }
  
  
}



private class DeviceAuthorizationCondition: OperationCondition {
  
  enum Error : ErrorType {
    case Unauthorized
  }
  
  static let name = "DeviceAuthorization"
  
  static let isMutuallyExclusive = false
  
  var authorized = false
  
  let deviceName : String
  
  let pin : String
  
  
  init(deviceName: String, pin: String) {
    self.deviceName = deviceName
    self.pin = pin
  }
  
  func dependencyForOperation(operation: Operation) -> NSOperation? {
    
    let authOp = AlertOperation()
    authOp.title = "Authorize Device"
    authOp.message = "A user wants to add the device '\(deviceName)' to this account account. Would you like to allow this device access to your account?"
    authOp.addAction("Cancel", style: UIAlertActionStyle.Cancel) { op in
      self.authorized = false
    }
    authOp.addAction("Ok", style: .Default) { op in
      self.authorized = true
      
      let pinAlert = UIAlertController(
        title: "Authorization Code",
        message: "Enter the pin code\n \(self.pin)\non the requesting device to authorize it for use",
        preferredStyle: .Alert)
      pinAlert.addAction(UIAlertAction(title: "Ok", style: .Default, handler: nil))
      
      UIApplication.sharedApplication().keyWindow?.rootViewController?
        .presentViewController(pinAlert, animated: true, completion: nil)
    }
    
    return authOp
  }
  
  func evaluateForOperation(operation: Operation, completion: OperationConditionResult -> Void) {
    completion(authorized ? .Satisfied : .Failed(Error.Unauthorized as NSError))
  }
  
}
