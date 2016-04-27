//
//  PersistentCacheTests.swift
//  Messages
//
//  Created by Kevin Wooten on 4/16/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import XCTest
@testable import Messages


extension String : Persistable {
  
  public static func dataToValue(data: NSData) throws -> AnyObject {
    return NSString(bytes: data.bytes, length: data.length, encoding: NSUTF8StringEncoding)!
  }
  
  public static func valueToData(value: String) throws -> NSData {
    return (value as NSString).dataUsingEncoding(NSUTF8StringEncoding)!
  }
  
}


class PersistentCacheTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
  }
  
  override func tearDown() {
    super.tearDown()
  }
  
  func testPersistence() throws {
    
    let userInfo = RTUserInfo(id: RTId.generate(), aliases: Set(["1", "2"]), encryptionCert: NSData(), signingCert: NSData(), avatar: nil)
    
    let cache = try PersistentCache<String, RTUserInfo>(name: "test", clear: true, loader: { key in
      return (userInfo, NSDate(timeIntervalSinceNow: 0.25))
    })
    
    try cache.valueForKey("test")
    try cache.valueForKey("test")
    
    XCTAssertEqual(try cache.valueForKey("test"), userInfo)
  }
  
  func testExpiration() throws {

    var fetched  = false
    
    let cache = try PersistentCache<String, String>(name: "test", clear: true, loader: { key in
      fetched = true
      return (key, NSDate(timeIntervalSinceNow:0.25))
    })
    
    do {
      fetched = false
      let value = try cache.valueForKey("123")
      XCTAssertTrue(fetched)
      XCTAssertEqual(value, "123")
    }
    
    do {
      fetched = false
      let value = try cache.valueForKey("123")
      XCTAssertFalse(fetched)
      XCTAssertEqual(value, "123")
    }
    
    usleep(UInt32(0.3*1000000));
    
    do {
      fetched = false
      let value = try cache.valueForKey("123")
      XCTAssertTrue(fetched)
      XCTAssertEqual(value, "123")
    }
    
  }
  
}
