//
//  NSString.swift
//  ReTxt
//
//  Created by Kevin Wooten on 3/25/16.
//  Copyright © 2016 reTXT Labs, LLC. All rights reserved.
//

import Foundation


/* Random */
extension String {
  
  init(randomStringOfLength length: Int, fromCharactersSet charSet: String) {
    
    var val = ""
    let chars = charSet.characters
    
    for _ in 0 ..< length {
      let pos = Int(arc4random_uniform(UInt32(chars.count)))
      val.append(chars[chars.startIndex.advancedBy(pos)])
    }
    
    self.init(val)
  }
  
  init(randomDigitsOfLength length: Int) {
    
    self.init(randomStringOfLength: length, fromCharactersSet: digits)
  }
  
  init(randomAlphaOfLength length: Int) {
    
    self.init(randomStringOfLength: length, fromCharactersSet: alpha)
  }
  
  init(randomAlphaNumericOfLength length: Int) {
    
    self.init(randomStringOfLength: length, fromCharactersSet: alphaNum)
  }
  
}


/* Paths */
extension String {
  
  var lastPathComponent: String {
    
    get {
      return (self as NSString).lastPathComponent
    }
  }
  
  var pathExtension: String {
    
    get {
      
      return (self as NSString).pathExtension
    }
  }
  
  var stringByDeletingLastPathComponent: String {
    
    get {
      
      return (self as NSString).stringByDeletingLastPathComponent
    }
  }
  
  var stringByDeletingPathExtension: String {
    
    get {
      
      return (self as NSString).stringByDeletingPathExtension
    }
  }
  
  var pathComponents: [String] {
    
    get {
      
      return (self as NSString).pathComponents
    }
  }
  
  func stringByAppendingPathComponent(path: String) -> String {
    
    let nsSt = self as NSString
    
    return nsSt.stringByAppendingPathComponent(path)
  }
  
  func stringByAppendingPathExtension(ext: String) -> String? {
    
    let nsSt = self as NSString
    
    return nsSt.stringByAppendingPathExtension(ext)
  }
  
}
