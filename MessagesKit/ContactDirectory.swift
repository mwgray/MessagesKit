//
//  ContactDirectory.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/11/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import PromiseKit


@objc public protocol Contact {
  
  var alias : String { get }
  
  var fullName : String { get }
  
  var familiarName : String { get }
  
  var avatar : UIImage? { get }
  
}


@objc public protocol ContactDirectory {
  
  func lookupContactWithAlias(alias: String) -> Contact

}


@objc public class ContactDirectoryManager : NSObject {
  
  private static var _sharedInstance : ContactDirectory = DefaultContactDirectory()
  
  public static func initialize(sharedInstance: ContactDirectory) {
    _sharedInstance = sharedInstance
  }
  
  public static var sharedInstance : ContactDirectory {
    return _sharedInstance
  }
  
}



public class DefaultContact : NSObject, Contact {
  
  public let alias : String
  
  public var fullName : String { return alias }
  
  public var familiarName : String { return alias }
  
  public var avatar : UIImage? { return nil }
  
  public init(alias: String) {
    self.alias = alias
  }
  
}


public class DefaultContactDirectory : NSObject, ContactDirectory {

  public func lookupContactWithAlias(alias: String) -> Contact {
    return DefaultContact(alias: alias)
  }
  
}
