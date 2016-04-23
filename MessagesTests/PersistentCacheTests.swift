//
//  PersistentCacheTests.swift
//  Messages
//
//  Created by Kevin Wooten on 4/16/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import XCTest
@testable import Messages


class PersistentCacheTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
  }
  
  override func tearDown() {
    super.tearDown()
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
