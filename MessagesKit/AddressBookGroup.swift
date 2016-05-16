//
//  AddressBookGroup.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/15/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import AddressBook


// ABGroup type of ABRecord

@objc public class AddressBookGroup : AddressBookRecord {
  
  public var name : String? {
    get {
      return ABRecordCopyValue(internalRecord, kABGroupNameProperty)?.takeRetainedValue() as? String
    }
    set {
      ABRecordSetValue(internalRecord, kABGroupNameProperty, newValue, nil)
    }
  }
  
  public class func create() -> AddressBookGroup {
    return AddressBookGroup(record: ABGroupCreate().takeRetainedValue())
  }
  
  public class func createInSource(source : AddressBookSource) -> AddressBookGroup {
    return AddressBookGroup(record: ABGroupCreateInSource(source.internalRecord).takeRetainedValue())
  }
  
  public var allMembers : [AddressBookPerson]? {
    get {
      return convertRecordsToPersons(ABGroupCopyArrayOfAllMembers(internalRecord)?.takeRetainedValue())
    }
  }
  
  public func allMembersWithSortOrdering(ordering : AddressBookPersonSortOrdering) -> [AddressBookPerson]? {
    return convertRecordsToPersons(ABGroupCopyArrayOfAllMembersWithSortOrdering(internalRecord, ordering.rawValue).takeRetainedValue())
  }
  
  public func addMember(person : AddressBookPerson) throws {
    try throwIfNoSuccess { ABGroupAddMember(self.internalRecord, person.internalRecord, $0) }
  }
  
  public func removeMember(person : AddressBookPerson) throws {
    try throwIfNoSuccess { ABGroupRemoveMember(self.internalRecord, person.internalRecord, $0) }
  }
  
  public var source : AddressBookSource {
    get {
      return AddressBookSource(record: ABGroupCopySource(internalRecord).takeRetainedValue())
    }
  }
}
