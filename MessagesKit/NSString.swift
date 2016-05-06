//
//  NSString.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 3/25/16.
//  Copyright © 2016 reTXT Labs, LLC. All rights reserved.
//

import Foundation

let digits = "0123456789"
let alpha = "abcdefghijklmnopqrstuvwxyz"
let alphaNum = alpha + digits

extension NSString {
  
  convenience init(randomStringOfLength length: Int, fromCharactersSet charSet: NSString) {
    
    let val = NSMutableString()
    
    for _ in 0 ..< length {
      let pos = Int(arc4random_uniform(UInt32(charSet.length)))
      val.appendString(charSet.substringWithRange(NSMakeRange(pos, 1)))
    }
    
    self.init(string: val)
  }
  
  convenience init(randomDigitsOfLength length: Int) {
    
    self.init(randomStringOfLength: length, fromCharactersSet: digits)
  }
  
  convenience init(randomAlphaOfLength length: Int) {
    
    self.init(randomStringOfLength: length, fromCharactersSet: alpha)
  }
  
  convenience init(randomAlphaNumericOfLength length: Int) {
    
    self.init(randomStringOfLength: length, fromCharactersSet: alphaNum)
  }
  
}
