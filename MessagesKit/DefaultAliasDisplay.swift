//
//  DefaultAliasDisplay.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/13/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation


public class DefaultAliasDisplay : NSObject, AliasDisplay {
  
  public let alias : String
  
  public var fullName : String { return alias }
  
  public var familiarName : String { return alias }
  
  public var initials: String? { return nil }
  
  public var avatar : UIImage? { return nil }
  
  public var updateHandler: AliasDisplayUpdateHandler?
  
  public init(alias: String) {
    self.alias = alias
  }
  
}


public class DefaultAliasDisplayProvider : NSObject, AliasDisplayProvider {
  
  public func displayForAlias(alias: String) -> AliasDisplay {
    return DefaultAliasDisplay(alias: alias)
  }
  
}
