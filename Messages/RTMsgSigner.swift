//
//  RTMsgSigner.swift
//  ReTxt
//
//  Created by Kevin Wooten on 11/30/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation


extension RTMsgSigner {
  
  public func verifyMsg(msg: RTMsg) throws -> Bool {
    var result : ObjCBool = false
    try __verifyMsg(msg, result: &result)
    return Bool(result)
  }
  
  public func verifyDirectMsg(msg: RTDirectMsg, forDevice deviceId: RTId) throws -> Bool {
    var result : ObjCBool = false
    try __verifyDirectMsg(msg, forDevice: deviceId, result: &result)
    return Bool(result)
  }
  
}
