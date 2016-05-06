//
//  PersistentCacheTests.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 4/16/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import XCTest
@testable import MessagesKit


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

    let avatar = RTImage(mimeType: "image/png", data: NSData())
    let userInfo = RTUserInfo(id: RTId.generate(), aliases: Set(["1", "2"]), encryptionCert: NSData(), signingCert: NSData(), avatar: avatar)
    
    let cache = try PersistentCache<String, RTUserInfo>(name: "test", clear: true) { key in
      return (userInfo, NSDate(timeIntervalSinceNow: 0.25))
    }
    
    try cache.valueForKey("test")
    try cache.valueForKey("test")

    let found = try cache.valueForKey("test")!
    
    XCTAssertEqual(found, userInfo)
  }
  
  func testExpiration() throws {

    var fetched  = false
    
    let cache = try PersistentCache<String, String>(name: "test", clear: true) { key in
      fetched = true
      return (key, NSDate(timeIntervalSinceNow:0.25))
    }
    
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
    
    cache
  }
  
  func testAvailable() throws {
    
    var fetched = false
    
    let cache = try PersistentCache<String, String>(name: "test", clear: true) { key in
      fetched = true
      return (key, NSDate(timeIntervalSinceNow: 0.25))
    }

    do {
      fetched = false
      let value = try cache.availableValueForKey("123")
      XCTAssertEqual(fetched, false)
      XCTAssertNil(value)
    }
    
    do {
      fetched = false
      let value = try cache.valueForKey("123")
      XCTAssertTrue(fetched)
      XCTAssertEqual(value, "123")
    }
    
    do {
      let value = try cache.availableValueForKey("123")
      XCTAssertEqual(value?.value, "123")
    }
    
  }
  
  func testCompaction() throws {
    
    var fetched = false
    
    let cache = try PersistentCache<String, String>(name: "test", clear: true) { key in
      fetched = true
      return (key, NSDate(timeIntervalSinceNow: 0.25))
    }
    
    do {
      fetched = false
      let value = try cache.valueForKey("123")
      XCTAssertEqual(fetched, true)
      XCTAssertEqual(value, "123")
    }
    
    do {
      fetched = false
      let value = try cache.valueForKey("123")
      XCTAssertFalse(fetched)
      XCTAssertEqual(value, "123")
    }
    
    usleep(300000);
    
    cache.compact()
    
    do {
      fetched = false
      let value = try cache.availableValueForKey("123")
      XCTAssertFalse(fetched)
      XCTAssertNil(value?.value)
    }
    
  }
  
  func testAutoCompaction() throws {
    
    var fetched = false
    
    let cache = try PersistentCache<String, String>(name: "test", clear: true) { key in
      fetched = true
      return (key, NSDate(timeIntervalSinceNow: 0.25))
    }
    
    do {
      fetched = false
      let value = try cache.valueForKey("123")
      XCTAssertEqual(fetched, true)
      XCTAssertEqual(value, "123")
    }
    
    do {
      fetched = false
      let value = try cache.valueForKey("123")
      XCTAssertFalse(fetched)
      XCTAssertEqual(value, "123")
    }
    
    usleep(300000);
    
    for _ in 0..<100 {
      XCTAssertEqual(try cache.valueForKey("456"), "456")
    }
    
    usleep(1000000);
    
    do {
      fetched = false
      let value = try cache.availableValueForKey("123")
      XCTAssertFalse(fetched)
      XCTAssertNil(value?.value)
    }
    
  }

  func testInvalidation() throws {
    
    var fetched = false
    
    let cache = try PersistentCache<String, String>(name: "test", clear: true) { key in
      fetched = true
      return (key, NSDate(timeIntervalSinceNow: 100000))
    }
    
    do {
      fetched = false
      let value = try cache.valueForKey("123")
      XCTAssertEqual(fetched, true)
      XCTAssertEqual(value, "123")
    }
    
    do {
      fetched = false
      let value = try cache.valueForKey("123")
      XCTAssertFalse(fetched)
      XCTAssertEqual(value, "123")
    }

    try cache.invalidateValueForKey("123")

    do {
      fetched = true
      let value = try cache.valueForKey("123")
      XCTAssertEqual(fetched, true)
      XCTAssertEqual(value, "123")
    }
    
  }
  
  func testCacheNullRow() throws {
    
    let cache = try PersistentCache<String, String>(name: "test", clear: true) { key in
      return nil
    }
    
    try cache.valueForKey("123")
    
    XCTAssertNil(try cache.valueForKey("123"))
  }
  
  func testCacheNullValue() throws {
    
    let cache = try PersistentCache<String, String>(name: "test", clear: true) { key in
      return (nil, NSDate(timeIntervalSinceNow: 5))
    }
    
    try cache.valueForKey("123")
    
    XCTAssertNil(try cache.valueForKey("123"))
  }
  
  func testCacheNullValueExplicit() throws {
    
    let cache = try PersistentCache<String, String>(name: "test", clear: true) { key in
      return (nil, NSDate(timeIntervalSinceNow: 5))
    }
    
    try cache.cacheValue(nil, forKey: "123", expires: NSDate(timeIntervalSinceNow: 100))
    
    XCTAssertNil(try cache.valueForKey("123"))
  }
  
}
