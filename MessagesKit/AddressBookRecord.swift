//
//  AddressBookRecord.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/15/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import AddressBook


// Generic ABRecord

@objc public class AddressBookRecord : NSObject {

	public var internalRecord : ABRecord!

	public init(record : ABRecord) {
		self.internalRecord = record
    super.init()
	}

	public var recordID: Int {
		return Int(ABRecordGetRecordID(self.internalRecord))
	}

	public var recordType: AddressBookRecordType {
    return AddressBookRecordType(rawValue: ABRecordGetRecordType(self.internalRecord))!
	}
}


public func == (lhs: AddressBookRecord, rhs: AddressBookRecord) -> Bool {
	return lhs.recordID == rhs.recordID
}
