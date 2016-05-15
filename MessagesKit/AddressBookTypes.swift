//
//  AddressBookTypes.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/15/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import AddressBook


@objc public enum AddressBookPersonSortOrdering : UInt32 {
  
  case LastName   = 0 // kABPersonSortByFirstName,
  case FirstName  = 1 // kABPersonSortByLastName

}


@objc public enum AddressBookPersonCompositeNameFormat : UInt32 {
  case FirstNameFirst = 0 // kABPersonCompositeNameFormatFirstNameFirst
  case LastNameFirst  = 1 // kABPersonCompositeNameFormatLastNameFirst
}


@objc public enum AddressBookRecordType : UInt32 {
  case Person   = 0 // kABPersonType
  case Group    = 1 // kABGroupType
  case Source   = 2 // kABSourceType
}


@objc public enum AddressBookPersonImageFormat : UInt32 {
  case Thumbnail    = 0 // kABPersonImageFormatThumbnail
  case OriginalSize = 2 // kABPersonImageFormatOriginalSize
}


public let AddressBookSourceTypeSearchable : UInt32 = 0x01000000


@objc public enum AddressBookSourceType : UInt32 {
  case Local          = 0
  case Exchange       = 1
  case ExchangeGAL    = 0x01000001
  case MobileMe       = 2
  case LDAP           = 0x01000003
  case CardDAV        = 4
  case CardDAVSearch  = 0x01000004
}


@objc public class AddressBookAddressProperty : NSObject {
  public let Street       = kABPersonAddressStreetKey as String
  public let City         = kABPersonAddressCityKey as String
  public let State        = kABPersonAddressStateKey as String
  public let Zip          = kABPersonAddressZIPKey as String
  public let Country      = kABPersonAddressCountryKey as String
  public let CountryCode  = kABPersonAddressCountryCodeKey as String
}


@objc public class AddressBookMultivalueEntry : NSObject {
  public let id : Int
  public let label : String?
  public let value : AnyObject
  
  public init(value: AnyObject, label: String?, id: Int) {
    self.value = value
    self.label = label
    self.id = id
  }
  
}
