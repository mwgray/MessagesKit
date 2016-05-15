//
//  AddressBookRecord.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/15/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import AddressBook


// Generic ABRecord

public class AddressBookRecord {

	public var internalRecord : ABRecord!

	public convenience init?(record : ABRecord?) {
		if let rec = record {
			self.init(record: rec)
		}
		else {
			return nil
		}
	}

	public init(record : ABRecord) {
		self.internalRecord = record
	}

	public var recordID: Int {
		return Int(ABRecordGetRecordID(self.internalRecord))
	}

	public var recordType: AddressBookRecordType {
    return AddressBookRecordType(rawValue: ABRecordGetRecordType(self.internalRecord))!
	}
}

extension AddressBookRecord: Hashable {

	public var hashValue: Int {
		return recordID.hashValue
	}

}

public func == (lhs: AddressBookRecord, rhs: AddressBookRecord) -> Bool {
	return lhs.recordID == rhs.recordID
}
