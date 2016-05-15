//
//  ExitMessage.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/11/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation


extension ExitMessage {
  
  public override func alertText() -> String {
    
    let aliasDisplay = AliasDisplayManager.sharedProvider.displayForAlias(self.alias)
    
    return "\(aliasDisplay.fullName) has left"
  }
  
  public override func summaryText() -> String {
    return "Left the chat"
  }
  
}
