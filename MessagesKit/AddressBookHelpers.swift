//
//  AddressBookHelpers.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/15/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import AddressBook


func throwIfNoSuccess(call : (UnsafeMutablePointer<Unmanaged<CFError>?>) -> Bool) throws {
  var error : Unmanaged<CFError>? = nil
  if !call(&error) && error != nil {
    throw error!.takeRetainedValue()
  }
}

func convertRecordsToSources(records : CFArray?) -> [AddressBookSource]? {
  let records = (records as NSArray? as? [ABRecord])?.map {(record : ABRecord) -> AddressBookSource in
    return AddressBookSource(record: record)
  }
  return records
}

func convertRecordsToGroups(records : CFArray?) -> [AddressBookGroup]? {
  let records = (records as NSArray? as? [ABRecord])?.map {(record : ABRecord) -> AddressBookGroup in
    return AddressBookGroup(record: record)
  }
  return records
}

func convertRecordsToPersons(records : CFArray?) -> [AddressBookPerson]? {
  let records = (records as NSArray? as? [ABRecord])?.map {(record : ABRecord) -> AddressBookPerson in
    return AddressBookPerson(record: record)
  }
  return records
}
