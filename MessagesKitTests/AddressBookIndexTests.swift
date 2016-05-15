//
//  AddressBookIndexTests.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/14/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

@testable import MessagesKit
import XCTest
import SwiftAddressBook
import JPSimulatorHacks
import PopulateKit


class AddressBookIndexTests : XCTestCase {
  
  static let groupId = NSUUID().UUIDString
  
  override class func setUp() {
    
    JPSimulatorHacks.grantAccessToAddressBook()
    
    let created = dispatch_semaphore_create(0)
    
    let males = ACPersonSet(firstNameSet: ACNameSet.commonMaleNameSet(), lastNameSet: ACNameSet.commonSurnameSet(), imageSet: ACImageSet.maleFaceImageSet())
    let females = ACPersonSet(firstNameSet: ACNameSet.commonMaleNameSet(), lastNameSet: ACNameSet.commonSurnameSet(), imageSet: ACImageSet.maleFaceImageSet())
    
    ACPopulate.populateGroupWithName(groupId, withCountOfPersons: 1000, fromSets: [males, females]) {
      dispatch_semaphore_signal(created)
    }
    dispatch_semaphore_wait(created, DISPATCH_TIME_FOREVER)
  }
  
  override class func tearDown() {
    let destroyed = dispatch_semaphore_create(0)
    ACPopulate.depopulateGroupWithName(groupId) {
      dispatch_semaphore_signal(destroyed)
    }
    dispatch_semaphore_wait(destroyed, DISPATCH_TIME_FOREVER)
  }
  
  var index : AddressBookIndex!
  
  override func setUp() {
    let ready = dispatch_semaphore_create(0)
    index = AddressBookIndex(ready: { 
      dispatch_semaphore_signal(ready)
    })
    dispatch_semaphore_wait(ready, DISPATCH_TIME_FOREVER)
  }
  
  func testIndexSearch() {
    
    measureBlock {
      self.index.searchPeopleWithQuery("Emm")
    }
    
    XCTAssertTrue(self.index.searchPeopleWithQuery("emm").count > 0)
    XCTAssertTrue(self.index.searchPeopleWithQuery("55").count > 0)
    XCTAssertTrue(self.index.searchPeopleWithQuery("ac").count > 0)
    XCTAssertTrue(self.index.searchPeopleWithQuery("xxx").count == 0)
  }
  
  func testIndexPerformance() {
    
    measureBlock {
      self.index.rebuildIndex()
    }
    
  }
  
  
}