//
//  AddressBook.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/15/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import AddressBook


//MARK: Address Book

public class AddressBook : NSObject {
  
  public var targetAddressBook : ABAddressBook!
  
  public override init() {
    
    super.init()
    
    try! throwIfNoSuccess { err in
      guard let res = ABAddressBookCreateWithOptions(nil, err) else {
        return false
      }
      self.targetAddressBook = res.takeRetainedValue()
      return true
    }
  }
  
  deinit {
    unregisterExternalChangeCallback()
  }
  
  public class func authorizationStatus() -> ABAuthorizationStatus {
    return ABAddressBookGetAuthorizationStatus()
  }
  
  public class func requestAccessWithCompletion( completion : (Bool, CFError?) -> Void ) {
    ABAddressBookRequestAccessWithCompletion(nil) {(let b : Bool, c : CFError!) -> Void in completion(b,c)}
  }
  
  public func hasUnsavedChanges() -> Bool {
    return ABAddressBookHasUnsavedChanges(targetAddressBook)
  }
  
  public func save() throws {
    try throwIfNoSuccess { ABAddressBookSave(self.targetAddressBook, $0)}
  }
  
  public func revert() {
    ABAddressBookRevert(targetAddressBook)
  }
  
  public func addRecord(record : AddressBookRecord) throws {
    try throwIfNoSuccess { ABAddressBookAddRecord(self.targetAddressBook, record.internalRecord, $0) }
  }
  
  public func removeRecord(record : AddressBookRecord) throws {
    try throwIfNoSuccess { ABAddressBookRemoveRecord(self.targetAddressBook, record.internalRecord, $0) }
  }
  
  //MARK: Person records
  
  public var personCount : Int {
    return ABAddressBookGetPersonCount(targetAddressBook)
  }
  
  public func personWithRecordId(recordId : Int32) -> AddressBookPerson? {
    return AddressBookPerson(record: ABAddressBookGetPersonWithRecordID(targetAddressBook, recordId)?.takeUnretainedValue())
  }
  
  public var allPeople : [AddressBookPerson]? {
    return convertRecordsToPersons(ABAddressBookCopyArrayOfAllPeople(targetAddressBook).takeRetainedValue())
  }
  
  typealias ChangeBlock = @convention(block) () -> Void
  
  private var changeCallback : ChangeBlock!
  
  public func registerExternalChangeCallback(callback: @convention(block) () -> Void) {
    
    changeCallback = callback // Manage it's lifetime
    
    ABAddressBookRegisterExternalChangeCallback(targetAddressBook, { (addressBook, options, context) -> Void in
      let callback = unsafeBitCast(Unmanaged.fromOpaque(COpaquePointer(context)) as Unmanaged<AnyObject>, ChangeBlock.self)
      callback()
    }, UnsafeMutablePointer(Unmanaged.passUnretained(unsafeBitCast(changeCallback, AnyObject.self)).toOpaque()))
  }
  
  public func unregisterExternalChangeCallback() {
    ABAddressBookRegisterExternalChangeCallback(targetAddressBook, nil, nil)
    changeCallback = nil
  }
  
  
  
  public var allPeopleExcludingLinkedContacts : [AddressBookPerson]? {
    if let all = allPeople {
      let filtered : NSMutableArray = NSMutableArray(array: all)
      for person in all {
        if !(NSArray(array: filtered) as! [AddressBookPerson]).contains({
          (p : AddressBookPerson) -> Bool in
          return p.recordID == person.recordID
        }) {
          //already filtered out this contact
          continue
        }
        
        //throw out duplicates
        let allFiltered : [AddressBookPerson] = NSArray(array: filtered) as! [AddressBookPerson]
        for possibleDuplicate in allFiltered {
          if let linked = person.allLinkedPeople {
            if possibleDuplicate.recordID != person.recordID
              && linked.contains({
                (p : AddressBookPerson) -> Bool in
                return p.recordID == possibleDuplicate.recordID
              }) {
              (filtered as NSMutableArray).removeObject(possibleDuplicate)
            }
          }
        }
      }
      return NSArray(array: filtered) as? [AddressBookPerson]
    }
    return nil
  }
  
  public func allPeopleInSource(source : AddressBookSource) -> [AddressBookPerson]? {
    return convertRecordsToPersons(ABAddressBookCopyArrayOfAllPeopleInSource(targetAddressBook, source.internalRecord).takeRetainedValue())
  }
  
  public func allPeopleInSourceWithSortOrdering(source : AddressBookSource, ordering : AddressBookPersonSortOrdering) -> [AddressBookPerson]? {
    return convertRecordsToPersons(ABAddressBookCopyArrayOfAllPeopleInSourceWithSortOrdering(targetAddressBook, source.internalRecord, ordering.rawValue).takeRetainedValue())
  }
  
  public func peopleWithName(name : String) -> [AddressBookPerson]? {
    return convertRecordsToPersons(ABAddressBookCopyPeopleWithName(targetAddressBook, name).takeRetainedValue())
  }
  
  
  //MARK: group records
  
  public func groupWithRecordId(recordId : Int32) -> AddressBookGroup? {
    return AddressBookGroup(record: ABAddressBookGetGroupWithRecordID(targetAddressBook, recordId)?.takeUnretainedValue())
  }
  
  public var groupCount : Int {
    return ABAddressBookGetGroupCount(targetAddressBook)
  }
  
  public var arrayOfAllGroups : [AddressBookGroup]? {
    return convertRecordsToGroups(ABAddressBookCopyArrayOfAllGroups(targetAddressBook).takeRetainedValue())
  }
  
  public func allGroupsInSource(source : AddressBookSource) -> [AddressBookGroup]? {
    return convertRecordsToGroups(ABAddressBookCopyArrayOfAllGroupsInSource(targetAddressBook, source.internalRecord).takeRetainedValue())
  }
  
  
  //MARK: sources
  
  public var defaultSource : AddressBookSource? {
    return AddressBookSource(record: ABAddressBookCopyDefaultSource(targetAddressBook)?.takeRetainedValue())
  }
  
  public func sourceWithRecordId(sourceId : Int32) -> AddressBookSource? {
    return AddressBookSource(record: ABAddressBookGetSourceWithRecordID(targetAddressBook, sourceId)?.takeUnretainedValue())
  }
  
  public var allSources : [AddressBookSource]? {
    return convertRecordsToSources(ABAddressBookCopyArrayOfAllSources(targetAddressBook).takeRetainedValue())
  }
}
