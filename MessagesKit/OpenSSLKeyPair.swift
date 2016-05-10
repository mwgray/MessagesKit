//
//  OpenSSLKeyPair.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 11/30/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation


extension OpenSSLPublicKey {
  
  public func verifyData(data: NSData, againstSignature signature: NSData, withPadding padding: DigitalSignaturePadding) throws -> Bool {
    var result : ObjCBool = false
    try __verifyData(data, againstSignature: signature, withPadding: padding, result: &result)
    return Bool(result)
  }
  
}
