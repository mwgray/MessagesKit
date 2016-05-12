//
//  TitleGenerator.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/11/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation


struct ChatTitleGenerator {
  
  
  private static var titleCache = [String: String]()
  private static let titleCacheLockQueue =
    dispatch_queue_create("ChatTitleGenerator TitleCache Lock",
                          dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0))
  
  
  static func generateForChat(chat: Chat) -> String {
    
    var recipients = Array(chat.activeRecipients)
    
    // Ensure most recent sender is at beginning of list
    if let lastMessage = chat.lastMessage, sender = lastMessage.sender, senderIndex = recipients.indexOf(sender) {
      recipients.removeAtIndex(senderIndex)
      recipients.insert(sender, atIndex: 0)
    }
    
    let titleCacheKey = recipients.joinWithSeparator("|")
    
    if let foundTitle = titleCacheLockQueue.sync({ return titleCache[titleCacheKey] }) {
      return foundTitle
    }
    
    let title : String
    
    if let customTitle = (chat as? GroupChat)?.customTitle {
      
      title = customTitle
    }
    else {
      
      let contactDirectory = ContactDirectoryManager.sharedInstance
      
      title = recipients
        .map { contactDirectory.lookupContactWithAlias($0) }
        .map { $0.familiarName }
        .joinWithSeparator(", ")
    }
    
    titleCacheLockQueue.sync({ titleCache[titleCacheKey] = title })
    
    return title
  }
  
}
