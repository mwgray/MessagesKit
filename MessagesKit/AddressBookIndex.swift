//
//  AddressBookIndex.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/15/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation
import AddressBook
import CocoaLumberjack


public let AddressBookIndexUpdateNotification = "AddressBookIndexUpdate"
public let AddressBookIndexUpdateNotificationAddedKey = "added"
public let AddressBookIndexUpdateNotificationUpdatedKey = "updated"
public let AddressBookIndexUpdateNotificationDeletedKey = "deleted"



public class AddressBookIndex : NSObject {
  
  
  private struct IndexEntry : Equatable {
    
    let systemId : ABRecordID
    let names : Set<String>
    let aliases : Set<String>
    let data : String
    
    init(systemId: ABRecordID, names: Set<String>, aliases: Set<String>) {
      self.systemId = systemId
      self.names = names
      self.aliases = aliases
      self.data = names.union(aliases).joinWithSeparator(" ")
    }
    
  }
  
  
  private let addressBook : AddressBook
  private let addressBookQueue = dispatch_queue_create("AddressBookIndex Access", DISPATCH_QUEUE_SERIAL)
  private var entries = [ABRecordID:IndexEntry]()
  private let lockQueue = dispatch_queue_create("AddressBookIndex Lock", DISPATCH_QUEUE_SERIAL)
  
  
  public init(ready: (() -> Void)?) {
    
    self.addressBook = AddressBook()
    
    super.init()
    
    self.addressBook.registerExternalChangeCallback {
      GCD.userInitiatedQueue.async { self.rebuildIndex() }
    }
    
    GCD.backgroundQueue.async {
      self.rebuildIndex()
      ready?()
    }
  }
  
  deinit {
  }
  
  public func lookupPeopleWithAliases(aliases: [String]) -> [AddressBookPerson] {
    
    return lockQueue.sync {
      let matches = self.entries.values.filter { !$0.aliases.intersect(aliases).isEmpty }
      return self.addressBookQueue.sync {
        let mapped = matches.map { self.addressBook.personWithRecordId($0.systemId) }
        let filtered = mapped.filter { $0 != nil }
        return filtered.map { (person:AddressBookPerson?) -> AddressBookPerson in return person! }
      }
    }
  }
  
  public func searchPeopleWithQuery(query: String) -> [AddressBookPerson] {
    
    return lockQueue.sync {
      let matches = self.entries.values.filter { $0.data.localizedCaseInsensitiveContainsString(query) }
      return self.addressBookQueue.sync {
        let mapped = matches.map { self.addressBook.personWithRecordId($0.systemId) }
        let filtered = mapped.filter { $0 != nil }
        return filtered.map { (person:AddressBookPerson?) -> AddressBookPerson in return person! }
      }
    }
  }
  
  func rebuildIndex() {
    
    DDLogInfo("Rebuilding index")
    
    let startTime = CFAbsoluteTimeGetCurrent()
    
    let people = addressBookQueue.sync {
      return self.addressBook.allPeople ?? []
    }
    
    let mapped = people.map { person -> IndexEntry in
      
      let names = Set([
        (person.firstName ?? ""),
        (person.middleName ?? ""),
        (person.lastName ?? ""),
        (person.nickname ?? ""),
        (person.organization ?? ""),
        (person.department ?? ""),
        (person.jobTitle ?? "")
        ])
      
      let phones = person.phoneNumbers?.map { $0.value as! String } ?? []
      let emails = person.emails?.map { $0.value as! String } ?? []
      
      let aliases = Set(phones + emails)
      
      return IndexEntry(systemId: ABRecordID(person.recordID), names: names, aliases: aliases)
      
    }
    
    let builtTime = CFAbsoluteTimeGetCurrent()
    DDLogVerbose("Indexing built: \(builtTime - startTime) secs")
    
    var entries = [ABRecordID:IndexEntry]()
    for entry in mapped {
      entries[entry.systemId] = entry
    }
    
    let updateTime = CFAbsoluteTimeGetCurrent()
    DDLogVerbose("Indexing update: \(updateTime - builtTime) secs")

    var oldEntries : [ABRecordID:IndexEntry]!
    lockQueue.sync {
      oldEntries = self.entries
      self.entries = entries
    }
    
    var added = [NSNumber]()
    var updated = [NSNumber]()
    
    for entry in mapped {
      if let oldEntry = oldEntries.removeValueForKey(entry.systemId) {
        if entry != oldEntry {
          updated.append(NSNumber(int: entry.systemId))
        }
      }
      else {
        added.append(NSNumber(int: entry.systemId))
      }
    }
    
    let deleted = Array(oldEntries.keys.map { NSNumber(int: $0) })
    
    NSNotificationCenter.defaultCenter().postNotificationName(AddressBookIndexUpdateNotification,
                                                              object: self,
                                                              userInfo: [
                                                                AddressBookIndexUpdateNotificationAddedKey: added,
                                                                AddressBookIndexUpdateNotificationUpdatedKey: updated,
                                                                AddressBookIndexUpdateNotificationDeletedKey: deleted])
    
    let finishTime = CFAbsoluteTimeGetCurrent()
    DDLogInfo("Indexing finished: \(finishTime - startTime) secs")
  }
  
}




private func ==(lhs: AddressBookIndex.IndexEntry, rhs: AddressBookIndex.IndexEntry) -> Bool {
  return
    lhs.systemId == rhs.systemId &&
      lhs.names == rhs.names &&
      lhs.aliases == rhs.names &&
      lhs.data == rhs.data
}
