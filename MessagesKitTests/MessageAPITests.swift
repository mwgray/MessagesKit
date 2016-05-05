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
  
  var testClientA : TestClient!
  var testClientB : TestClient!
  
  var api : MessageAPI!
  
  override class func setUp() {
    super.setUp()
    
    MessageAPI.initialize(target: ServerTarget(scheme: .HTTPS, hostName: "master.dev.retxt.io"))
  }

  override func setUp() {
    super.setUp()
    
    testClientA = try! TestClient(baseURL: MessageAPI.target.baseURL)
    testClientB = try! TestClient(baseURL: MessageAPI.target.baseURL)
    
    let x = expectationWithDescription("signIn")
    
    firstly {
      return MessageAPI.findProfileWithId(testClientA.userId, password: testClientA.password)
    }
    .then { profile in
      return MessageAPI.signInWithProfile(profile as! RTUserProfile, deviceId: self.testClientA.devices[0].deviceInfo.id, password: self.testClientA.password)
    }
    .then { creds -> Void in
      let creds = creds.authorizeWithEncryptionIdentity(self.testClientA.encryptionIdentity, signingIdentity: self.testClientA.signingIdentity)
      self.api = try MessageAPI(credentials: creds, documentDirectoryURL: MessageAPITest.documentDirectoryURL)
    }
    .always {
      x.fulfill()
    }
    .error { caught in
      fatalError("Error signing in: \(caught)")
    }
   
    waitForExpectationsWithTimeout(5, handler: { error in
      if let error = error {
        fatalError("Sign in timed out: \(error)")
      }
    })
    
  }
  
  override func tearDown() {
    
    testClientA.devices.forEach { $0.clearHistory() }
    testClientB.devices.forEach { $0.clearHistory() }
    
    super.tearDown()
  }
  
  func testReceiveMessage() throws {
    
    let x = expectationWithDescription("Receive")
    
    sleep(2)
    
    try testClientB.devices[0].sendText("hello world", to: testClientA.devices[0].preferredAlias)
    
    NSNotificationCenter.defaultCenter().addObserverForName(MessageAPIUserMessageReceivedNotification, object: nil, queue: nil) { not in
      x.fulfill()
    }
    
    waitForExpectationsWithTimeout(5, handler: nil)
  }
  
  func testSendMessage() throws {
    
    let x = expectationWithDescription("Send")
    
    let chat = try api.loadUserChatForAlias(testClientB.devices[0].preferredAlias, localAlias: testClientA.devices[0].preferredAlias)

    let msg = RTTextMessage(chat: chat)
    msg.text = "Hello World"
    
    try api.saveMessage(msg).then { x.fulfill() }
    
    waitForExpectationsWithTimeout(5, handler: nil)
  }
  
  func testInvalidSendMessage() throws {
    
    let x = expectationWithDescription("Invalid Send")
    
    let chat = try api.loadUserChatForAlias(testClientB.devices[0].preferredAlias, localAlias: testClientA.devices[0].preferredAlias)
    
    let msg = RTTextMessage(chat: chat)
    msg.sender = "asender"
    
    try api.saveMessage(msg)
      .always { x.fulfill() }
      .then { XCTFail("Send should have failed") }
    
    waitForExpectationsWithTimeout(5, handler: nil)
  }
  
  func testUpdateMessage() throws {
    
    let x = expectationWithDescription("Update")
    
    let chat = try api.loadUserChatForAlias(testClientB.devices[0].preferredAlias, localAlias: testClientA.devices[0].preferredAlias)
    
    let msg = RTTextMessage(chat: chat)
    msg.text = "Hello World"
    
    firstly {
      return try self.api.saveMessage(msg)
    }
    .then {
      return try self.api.updateMessage(msg)
    }
    .always {
      x.fulfill()
    }
    .error { error -> Void in
      XCTFail("Update failed: \(error)")
    }
    
    waitForExpectationsWithTimeout(5, handler: nil)
  }
  
  func testInvalidUpdateMessage() throws {
    
    let x = expectationWithDescription("Invalid Update")
    
    let chat = try api.loadUserChatForAlias(testClientB.devices[0].preferredAlias, localAlias: testClientA.devices[0].preferredAlias)
    
    let msg = RTTextMessage(chat: chat)
    msg.text = "Hello World"
    
    try api.updateMessage(msg)
      .always { x.fulfill() }
      .then { XCTFail("Should have produced an error") }
    
    waitForExpectationsWithTimeout(5, handler: nil)
  }
  
  func testReceiveUserStatus() throws {

    let x = expectationWithDescription("Receiving user status")
    
    let _ = try api.loadUserChatForAlias(testClientB.devices[0].preferredAlias, localAlias: testClientA.devices[0].preferredAlias)
    
    NSNotificationCenter.defaultCenter()
      .addObserverForName(MessageAPIUserStatusDidChangeNotification, object: api, queue: nil, usingBlock: { not in
        if not.userInfo?[MessageAPIUserStatusDidChangeNotification_InfoKey] is RTUserStatusInfo {
          x.fulfill()
        }
      })
    
    sleep(2); // Wait for access token generation and websocket connect
    
    try! testClientB.sendUserStatus(.Typing, from: testClientB.devices[0].preferredAlias, to: testClientA.devices[0].preferredAlias)
    
    waitForExpectationsWithTimeout(15, handler: nil)
  }

}
