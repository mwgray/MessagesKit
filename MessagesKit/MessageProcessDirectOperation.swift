//
//  MessageProcessOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 7/26/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import CocoaLumberjack


public class MessageProcessDirectOperation: MessageAPIOperation {
  
  let msg : RTDirectMsg
  
  
  public init(msg: RTDirectMsg, api: MessageAPI) {
    
    self.msg = msg
    
    super.init(api: api)
  }
  
  public override func execute() {
    
    do {
      
      try processMsg()
      
    }
    catch let error as NSError {
      cancelWithError(error)
    }
    
  }
  
  func processMsg() throws {
    
    do {

      if try verifyMsg() == false {
        return
      }
    
      let key = try api.credentials.encryptionIdentity.privateKey.decryptData(msg.key)

      let data = try RTMsgCipher(forKey: key).decryptData(msg.data, withKey: key)
      
      let userInfo = [
        MessageAPIDirectMessageReceivedNotification_MsgIdKey: msg.id,
        MessageAPIDirectMessageReceivedNotification_MsgTypeKey: msg.type,
        MessageAPIDirectMessageReceivedNotification_MsgDataKey: data,
        MessageAPIDirectMessageReceivedNotification_SenderKey: msg.sender,
        MessageAPIDirectMessageReceivedNotification_SenderDeviceIdKey: msg.senderDevice
      ]
      
      dispatch_async(dispatch_get_main_queue()) {
        NSNotificationCenter.defaultCenter()
          .postNotificationName(MessageAPIDirectMessageReceivedNotification, object:self, userInfo:userInfo);
      }
        
    }
    catch let error as NSError {
      finishWithError(error)
    }
    
  }


  func verifyMsg() throws -> Bool {
    
    if let signingCertData = try api.resolveUserInfoWithAlias(msg.sender)?.signingCert {
      
      let signingKey = try RTOpenSSLCertificate(DEREncodedData: signingCertData, validatedWithTrust: api.certificateTrust).publicKey
        
      let signer = RTMsgSigner(publicKey: signingKey, signature: msg.signature)
      
      if try signer.verifyDirectMsg(msg, forDevice: api.credentials.deviceId) {
        return true
      }
      
      api.invalidateUserInfoWithAlias(msg.sender)
      
      if let refreshedSigningCertData = try api.resolveUserInfoWithAlias(msg.sender)?.signingCert {
        
        let signingKey = try RTOpenSSLCertificate(DEREncodedData: refreshedSigningCertData, validatedWithTrust: api.certificateTrust).publicKey
        
        let signer = RTMsgSigner(publicKey: signingKey, signature: msg.signature)
        
        return try signer.verifyDirectMsg(msg, forDevice: api.credentials.deviceId)
        
      }
      
    }
    
    return false
  }
  
}
