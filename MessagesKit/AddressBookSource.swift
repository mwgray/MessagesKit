//
//  AddressBookSource.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/15/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import AddressBook


// ABSource type of ABARecord

@objc public class AddressBookSource : AddressBookRecord {
  
  public var sourceType : AddressBookSourceType {
    get {
      return AddressBookSourceType(rawValue: internalSourceType)!
    }
  }
  
  public var searchable : Bool {
    get {
      return (UInt32(kABSourceTypeSearchableMask) & internalSourceType) != 0
    }
  }
  
  private var internalSourceType : UInt32 {
    get {
      let sourceType = ABRecordCopyValue(internalRecord, kABSourceTypeProperty)?.takeRetainedValue() as! NSNumber
      return sourceType.unsignedIntValue
    }
  }
  
  public var sourceName : String? {
    get {
      return ABRecordCopyValue(internalRecord, kABSourceNameProperty)?.takeRetainedValue() as? String
    }
  }
  
}
