//
//  SwiftAddressBookHelperMethods.swift
//  Pods
//
//  Created by Socialbit - Tassilo Karge on 09.03.15.
//
//

import Foundation
import AddressBook

import Foundation
import AddressBook

extension NSString {

	convenience init?(optionalString : String?) {
		if optionalString == nil {
			self.init()
			return nil
		}
		self.init(string: optionalString!)
	}
}

func errorIfNoSuccess(call : (UnsafeMutablePointer<Unmanaged<CFError>?>) -> Bool) -> CFError? {
	var err : Unmanaged<CFError>? = nil
	let success : Bool = call(&err)
	if success {
		return nil
	}
	else {
		return err?.takeRetainedValue()
	}
}


//MARK: methods to convert arrays of ABRecords

func convertRecordsToSources(records : CFArray?) -> [SwiftAddressBookSource]? {
	let swiftRecords = (records as NSArray? as? [ABRecord])?.map {(record : ABRecord) -> SwiftAddressBookSource in
		return SwiftAddressBookSource(record: record)
	}
	return swiftRecords
}

func convertRecordsToGroups(records : CFArray?) -> [SwiftAddressBookGroup]? {
	let swiftRecords = (records as NSArray? as? [ABRecord])?.map {(record : ABRecord) -> SwiftAddressBookGroup in
		return SwiftAddressBookGroup(record: record)
	}
	return swiftRecords
}

func convertRecordsToPersons(records : CFArray?) -> [SwiftAddressBookPerson]? {
	let swiftRecords = (records as NSArray? as? [ABRecord])?.map {(record : ABRecord) -> SwiftAddressBookPerson in
		return SwiftAddressBookPerson(record: record)
	}
	return swiftRecords
}
