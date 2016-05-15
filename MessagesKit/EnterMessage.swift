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
    
    let aliasDisplay = AliasDisplayManager.sharedProvider.displayForAlias(self.alias)
    
    return "\(aliasDisplay.fullName) has joined"
  }
  
  public override func summaryText() -> String {
    
    return "Joined the chat"
  }
  
}
