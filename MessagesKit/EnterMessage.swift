//
//  EnterMessage.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/11/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation


extension EnterMessage {
  
  public override func alertText() -> String {
    
    let contact = ContactDirectoryManager.sharedInstance.lookupContactWithAlias(self.alias)
    
    return "\(contact.fullName) has joined" //TODO:
  }
  
  public override func summaryText() -> String {
    return alertText()
  }
  
}
