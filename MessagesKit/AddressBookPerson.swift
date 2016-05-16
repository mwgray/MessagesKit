//
//  AddressBookPerson.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/15/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import AddressBook


// ABPerson type of type ABRecord

@objc public class AddressBookPerson : AddressBookRecord {

	public class func create() -> AddressBookPerson {
		return AddressBookPerson(record: ABPersonCreate().takeRetainedValue())
	}

	public class func createInSource(source : AddressBookSource) -> AddressBookPerson {
		return AddressBookPerson(record: ABPersonCreateInSource(source.internalRecord).takeRetainedValue())
	}

	public class func createInSourceWithVCard(source : AddressBookSource, vCard : String) -> [AddressBookPerson]? {
		let data : NSData? = vCard.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
		let abPersons : NSArray? = ABPersonCreatePeopleInSourceWithVCardRepresentation(source.internalRecord, data).takeRetainedValue()
		var persons = [AddressBookPerson]()
		if let abPersons = abPersons {
			for abPerson : ABRecord in abPersons {
        persons.append(AddressBookPerson(record: abPerson))
			}
		}
		if persons.count != 0 {
			return persons
		}
		else {
			return nil
		}
	}

	public class func createVCard(people : [AddressBookPerson]) -> String {
		let peopleArray : NSArray = people.map{$0.internalRecord}
		let data : NSData = ABPersonCreateVCardRepresentationWithPeople(peopleArray).takeRetainedValue()
		return NSString(data: data, encoding: NSUTF8StringEncoding)! as String
	}

	public class func ordering() -> AddressBookPersonSortOrdering {
		return AddressBookPersonSortOrdering(rawValue: ABPersonGetSortOrdering())!
	}

	public class func comparePeopleByName(person1 : AddressBookPerson, person2 : AddressBookPerson, ordering : AddressBookPersonSortOrdering) -> CFComparisonResult {
		return ABPersonComparePeopleByName(person1.internalRecord, person2.internalRecord, ordering.rawValue)
	}


	//MARK: Personal Information

	public func setImage(image : UIImage?) throws {
		guard let image = image else { return try removeImage() }
		let imageData : NSData = UIImagePNGRepresentation(image) ?? NSData()
		try throwIfNoSuccess { ABPersonSetImageData(self.internalRecord,  CFDataCreate(nil, UnsafePointer(imageData.bytes), imageData.length), $0) }
	}

	public var image : UIImage? {
		guard ABPersonHasImageData(internalRecord) else { return nil }
		guard let data = ABPersonCopyImageData(internalRecord)?.takeRetainedValue() else { return nil }
		return UIImage(data: data)
	}

	public func imageDataWithFormat(format : AddressBookPersonImageFormat) -> UIImage? {
		guard let data = ABPersonCopyImageDataWithFormat(internalRecord, ABPersonImageFormat(rawValue: format.rawValue))?.takeRetainedValue() else {
			return nil
		}
		return UIImage(data: data)
	}

	public func hasImageData() -> Bool {
		return ABPersonHasImageData(internalRecord)
	}

	public func removeImage() throws {
		try throwIfNoSuccess { ABPersonRemoveImageData(self.internalRecord, $0) }
	}

	public var allLinkedPeople : Array<AddressBookPerson>? {
		return convertRecordsToPersons(ABPersonCopyArrayOfAllLinkedPeople(internalRecord).takeRetainedValue())
	}

	public var source : AddressBookSource {
		return AddressBookSource(record: ABPersonCopySource(internalRecord).takeRetainedValue())
	}

	public var compositeNameDelimiterForRecord : String {
		return ABPersonCopyCompositeNameDelimiterForRecord(internalRecord).takeRetainedValue() as String
	}

	public var compositeNameFormat : AddressBookPersonCompositeNameFormat {
		return AddressBookPersonCompositeNameFormat(rawValue: ABPersonGetCompositeNameFormatForRecord(internalRecord))!
	}

	public var compositeName : String? {
		let compositeName = ABRecordCopyCompositeName(internalRecord)?.takeRetainedValue() as NSString?
		return compositeName as? String
	}

	public var firstName : String? {
		get {
			return extractProperty(kABPersonFirstNameProperty)
		}
		set {
			setSingleValueProperty(kABPersonFirstNameProperty,  newValue as NSString?)
		}
	}

	public var lastName : String? {
		get {
			return extractProperty(kABPersonLastNameProperty)
		}
		set {
			setSingleValueProperty(kABPersonLastNameProperty,  newValue as NSString?)
		}
	}

	public var middleName : String? {
		get {
			return extractProperty(kABPersonMiddleNameProperty)
		}
		set {
			setSingleValueProperty(kABPersonMiddleNameProperty,  newValue as NSString?)
		}
	}

	public var prefix : String? {
		get {
			return extractProperty(kABPersonPrefixProperty)
		}
		set {
			setSingleValueProperty(kABPersonPrefixProperty,  newValue as NSString?)
		}
	}

	public var suffix : String? {
		get {
			return extractProperty(kABPersonSuffixProperty)
		}
		set {
			setSingleValueProperty(kABPersonSuffixProperty,  newValue as NSString?)
		}
	}

	public var nickname : String? {
		get {
			return extractProperty(kABPersonNicknameProperty)
		}
		set {
			setSingleValueProperty(kABPersonNicknameProperty,  newValue as NSString?)
		}
	}

	public var firstNamePhonetic : String? {
		get {
			return extractProperty(kABPersonFirstNamePhoneticProperty)
		}
		set {
			setSingleValueProperty(kABPersonFirstNamePhoneticProperty,  newValue as NSString?)
		}
	}

	public var lastNamePhonetic : String? {
		get {
			return extractProperty(kABPersonLastNamePhoneticProperty)
		}
		set {
			setSingleValueProperty(kABPersonLastNamePhoneticProperty,  newValue as NSString?)
		}
	}

	public var middleNamePhonetic : String? {
		get {
			return extractProperty(kABPersonMiddleNamePhoneticProperty)
		}
		set {
			setSingleValueProperty(kABPersonMiddleNamePhoneticProperty,  newValue as NSString?)
		}
	}

	public var organization : String? {
		get {
			return extractProperty(kABPersonOrganizationProperty)
		}
		set {
			setSingleValueProperty(kABPersonOrganizationProperty,  newValue as NSString?)
		}
	}

	public var jobTitle : String? {
		get {
			return extractProperty(kABPersonJobTitleProperty)
		}
		set {
			setSingleValueProperty(kABPersonJobTitleProperty,  newValue as NSString?)
		}
	}

	public var department : String? {
		get {
			return extractProperty(kABPersonDepartmentProperty)
		}
		set {
			setSingleValueProperty(kABPersonDepartmentProperty,  newValue as NSString?)
		}
	}

	public var emails : Array<AddressBookMultivalueEntry>? {
		get {
			return extractMultivalueProperty(kABPersonEmailProperty)
		}
		set {
			try! setMultivalueProperty(kABPersonEmailProperty, newValue)
		}
	}

	public var birthday : NSDate? {
		get {
			return extractProperty(kABPersonBirthdayProperty)
		}
		set {
			setSingleValueProperty(kABPersonBirthdayProperty, newValue)
		}
	}

	public var note : String? {
		get {
			return extractProperty(kABPersonNoteProperty)
		}
		set {
			setSingleValueProperty(kABPersonNoteProperty,  newValue as NSString?)
		}
	}

	public var creationDate : NSDate? {
		get {
			return extractProperty(kABPersonCreationDateProperty)
		}
		set {
			setSingleValueProperty(kABPersonCreationDateProperty, newValue)
		}
	}

	public var modificationDate : NSDate? {
		get {
			return extractProperty(kABPersonModificationDateProperty)
		}
		set {
			setSingleValueProperty(kABPersonModificationDateProperty, newValue)
		}
	}

	public var addresses : Array<AddressBookMultivalueEntry>? {
		get {
			return extractMultivalueProperty(kABPersonAddressProperty)
		}
		set {
			try! setMultivalueProperty(kABPersonAddressProperty, newValue)
		}
	}

	public var dates : Array<AddressBookMultivalueEntry>? {
		get {
			return extractMultivalueProperty(kABPersonDateProperty)
		}
		set {
			try! setMultivalueProperty(kABPersonDateProperty, newValue)
		}
	}

	public var type : CFNumber? {
		get {
			return extractProperty(kABPersonKindProperty)
		}
		set {
			setSingleValueProperty(kABPersonKindProperty, newValue)
		}
	}

	public var phoneNumbers : Array<AddressBookMultivalueEntry>? {
		get {
			return extractMultivalueProperty(kABPersonPhoneProperty)
		}
		set {
			try! setMultivalueProperty(kABPersonPhoneProperty, newValue)
		}
	}

	public var relatedNames : Array<AddressBookMultivalueEntry>? {
		get {
			return extractMultivalueProperty(kABPersonRelatedNamesProperty)
		}
		set {
			try! setMultivalueProperty(kABPersonRelatedNamesProperty, newValue)
		}
	}

	public var alternateBirthday : Dictionary<String, AnyObject>? {
		get {
			return extractProperty(kABPersonAlternateBirthdayProperty)
		}
		set {
			let dict : NSDictionary? = newValue
			setSingleValueProperty(kABPersonAlternateBirthdayProperty, dict)
		}
	}


	//MARK: generic methods to set and get person properties

	private func extractProperty<T>(propertyName : ABPropertyID) -> T? {
		//the following is two-lines of code for a reason. Do not combine (compiler optimization problems)
		let value: AnyObject? = ABRecordCopyValue(self.internalRecord, propertyName)?.takeRetainedValue()
		return value as? T
	}

	private func setSingleValueProperty<T : AnyObject>(key : ABPropertyID,_ value : T?) {
		ABRecordSetValue(self.internalRecord, key, value, nil)
	}

	private func extractMultivalueProperty(propertyName : ABPropertyID) -> Array<AddressBookMultivalueEntry>? {
		var array = Array<AddressBookMultivalueEntry>()
		let multivalue : ABMultiValue? = extractProperty(propertyName)
		for i : Int in 0..<(ABMultiValueGetCount(multivalue)) {
			let value = ABMultiValueCopyValueAtIndex(multivalue, i).takeRetainedValue()
      let id : Int = Int(ABMultiValueGetIdentifierAtIndex(multivalue, i))
      let optionalLabel = ABMultiValueCopyLabelAtIndex(multivalue, i)?.takeRetainedValue()
      array.append(AddressBookMultivalueEntry(value: value,
                                              label: optionalLabel == nil ? nil : optionalLabel! as String,
                                              id: id))
		}
		return !array.isEmpty ? array : nil
	}

	private func setMultivalueProperty(key : ABPropertyID,_ multivalue : Array<AddressBookMultivalueEntry>?) throws {
		if(multivalue == nil) {
			let emptyMultivalue: ABMutableMultiValue = ABMultiValueCreateMutable(ABPersonGetTypeOfProperty(key)).takeRetainedValue()
			//TODO: handle possible error
			try throwIfNoSuccess { ABRecordSetValue(self.internalRecord, key, emptyMultivalue, $0) }
		}

		var abmv : ABMutableMultiValue? = nil

		/* make mutable copy to be able to update multivalue */
		if let oldValue : ABMultiValue = extractProperty(key) {
			abmv = ABMultiValueCreateMutableCopy(oldValue)?.takeRetainedValue()
		}

		var abmv2 : ABMutableMultiValue? = abmv

		/* initialize abmv for sure */
		if abmv2 == nil {
			abmv2 = ABMultiValueCreateMutable(ABPersonGetTypeOfProperty(key)).takeRetainedValue()
		}

		let abMultivalue: ABMutableMultiValue = abmv2!

		var identifiers = Array<Int>()

		for i : Int in 0..<(ABMultiValueGetCount(abMultivalue)) {
			identifiers.append(Int(ABMultiValueGetIdentifierAtIndex(abMultivalue, i)))
		}

		for m : AddressBookMultivalueEntry in multivalue! {
			if identifiers.contains(m.id) {
				let index = ABMultiValueGetIndexForIdentifier(abMultivalue, Int32(m.id))
				ABMultiValueReplaceValueAtIndex(abMultivalue, m.value, index)
				ABMultiValueReplaceLabelAtIndex(abMultivalue, m.label, index)
				identifiers.removeAtIndex(identifiers.indexOf(m.id)!)
			}
			else {
				ABMultiValueAddValueAndLabel(abMultivalue, m.value, m.label, nil)
			}
		}

		for i in identifiers {
			ABMultiValueRemoveValueAndLabelAtIndex(abMultivalue, ABMultiValueGetIndexForIdentifier(abMultivalue,Int32(i)))
		}

		ABRecordSetValue(internalRecord, key, abMultivalue, nil)
	}

}
