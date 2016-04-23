//
//  MessageAPITest.swift
//  ReTxt
//
//  Created by Kevin Wooten on 3/13/16.
//  Copyright © 2016 reTXT Labs, LLC. All rights reserved.
//

import XCTest
@testable import Messages


class MessageAPITest: XCTestCase {
  
  static let documentDirectoryURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).last!
  
  let testClientA = try! TestClient(baseURL: RTServerAPI.baseURL())
  let testClientB = try! TestClient(baseURL: RTServerAPI.baseURL())
  
  var api : RTMessageAPI!

  override func setUp() {
    super.setUp()
    
    testClientB.devices.forEach { $0.openWebSocket() }
    
    api = try! firstly {
      return RTMessageAPI.profileWithId(testClientA.userId, password: testClientA.password)
    }
    .then { profile in
      return RTMessageAPI.signInWithProfile(profile as! RTUserProfile, password: self.testClientA.password)
    }
    .then { creds -> RTMessageAPI in
      let creds = creds!.updateDeviceId(self.testClientA.devices[0].deviceInfo.id)
      return try RTMessageAPI(credentials: creds, documentDirectoryURL: MessageAPITest.documentDirectoryURL)
    }
    .wait()
    
  }
  
  override func tearDown() {
    
    testClientA.devices.forEach { $0.clearHistory() }
    testClientB.devices.forEach { $0.clearHistory() }
    
    super.tearDown()
  }

  func testReceiveUserStatus() {
    
    let queue = UnboundedBlockingQueue<(String, RTUserStatus)>();
    NSNotificationCenter.defaultCenter()
      .addObserverForName(RTMessageAPIUserStatusDidChangeNotification, object: api, queue: nil, usingBlock: { not in
        if let info = not.object as? RTUserStatusInfo {
          queue.put((info.userAlias, info.status))
        }
      })
    
    try! testClientB.sendUserStatus(.Typing, from: testClientB.devices[0].preferredAlias, to: testClientA.devices[0].preferredAlias)
    
  }

}
