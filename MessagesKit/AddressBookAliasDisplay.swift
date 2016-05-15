//
//  AddressBookAliasDisplay.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/13/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation
import CocoaLumberjack



private class PersonAliasDisplay : NSObject, AliasDisplay {
  
  let person : AddressBookPerson
  
  private init(person: AddressBookPerson) {
    self.person = person
  }
  
  @objc private var fullName : String {
    return person.compositeName ?? ""
  }
  
  @objc private var familiarName : String {
    return person.nickname ?? person.firstName ?? person.lastName ?? ""
  }
  
  @objc private var avatar : UIImage? {
    return person.image
  }
  
  @objc private var updateHandler: AliasDisplayUpdateHandler?
  
}


public class AddressBookAliasDisplayProxy : NSObject, AliasDisplay {
  
  private var targetAlias : String
  public var current : AliasDisplay
  
  public init(targetAlias:String, current: AliasDisplay) {
    self.targetAlias = targetAlias
    self.current = current
  }
  
  public var fullName : String {
    return current.fullName
  }
  
  public var familiarName : String {
    return current.familiarName
  }
  
  public var avatar : UIImage? {
    return current.avatar
  }
  
  public var updateHandler: AliasDisplayUpdateHandler?

  @objc private func updated(provider: AddressBookAliasDisplayProvider) {
    current = provider.displayForAlias(targetAlias)
    updateHandler?()
  }

  @objc private func deleted(provider: AddressBookAliasDisplayProvider) {
    current = AliasDisplayManager.defaultDisplayForAlias(targetAlias)
    updateHandler?()
  }

}


public class AddressBookAliasDisplayProvider : NSObject, AliasDisplayProvider {
  
  private let index : AddressBookIndex
  private let cache = NSMapTable.strongToWeakObjectsMapTable()
  private var observer : AnyObject!
  
  public init(index: AddressBookIndex) {
    self.index = index
    
    super.init()
    
    self.observer = NSNotificationCenter.defaultCenter().addObserverForName(AddressBookIndexUpdateNotification, object: index, queue: nil, usingBlock: { not in
      
      if let updatedIds = not.userInfo?[AddressBookIndexUpdateNotificationUpdatedKey] as? [NSNumber] {
        for updatedId in updatedIds {
          if let cached = self.cache.objectForKey(updatedId) as? AddressBookAliasDisplayProxy {
            cached.updated(self)
          }
        }
      }
      
      if let deletedIds = not.userInfo?[AddressBookIndexUpdateNotificationDeletedKey] as? [NSNumber] {
        for deletedId in deletedIds {
          if let cached = self.cache.objectForKey(deletedId) as? AddressBookAliasDisplayProxy {
            cached.deleted(self)
          }
        }
      }
      
      
    })
  }
  
  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(observer)
  }
 
  public func displayForAlias(alias: String) -> AliasDisplay {
    return index.lookupPeopleWithAliases([alias]).map { PersonAliasDisplay(person: $0) }.first ?? AliasDisplayManager.defaultDisplayForAlias(alias)
  }
  
}
