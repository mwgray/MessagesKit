//
//  ChatTitle.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/12/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation


public let ChatTitleUpdateNotification = "ChatTitleUpdate"


@objc public protocol ChatTitle {
  
  func full() -> String
  func full(leadingMember leadingMember: String) -> String

  func familiar() -> String
  func familiar(leadingMember leadingMember: String) -> String
  
}


public class SimpleTitle : NSObject, ChatTitle {
  
  let title : String
  
  public init(title: String) {
    self.title = title
  }
  
  public func full() -> String { return title }
  public func full(leadingMember leadingMember: String) -> String { return title }
  
  public func familiar() -> String { return title }
  public func familiar(leadingMember leadingMember: String) -> String { return title }
 
}


public class AliasDisplayTitle : NSObject, ChatTitle {

  struct Member {
    let alias : String
    let aliasDisplay : AliasDisplay
  }
  
  private let members : [Member]
  private let separator : String
  
  public init(memberAliases: [String], aliasDisplayProvider: AliasDisplayProvider, separator: String = ", ") {
    self.members = memberAliases.map {
      Member(alias: $0, aliasDisplay: aliasDisplayProvider.displayForAlias($0))
    }
    self.separator = separator
    
    super.init()
    
    self.members.forEach {
      $0.aliasDisplay.updateHandler = {
        NSNotificationCenter.defaultCenter().postNotificationName(ChatTitleUpdateNotification, object: self)
      }
    }
  }
  
  public func full() -> String {
    return members.map { $0.aliasDisplay.fullName }.joinWithSeparator(separator)
  }
  
  public func full(leadingMember leadingMember: String) -> String {
    return orderedMembers(leadingMemberAlias: leadingMember).map { $0.aliasDisplay.fullName }.joinWithSeparator(separator)
  }
  
  public func familiar() -> String {
    return members.map { $0.aliasDisplay.familiarName }.joinWithSeparator(separator)
  }
  
  public func familiar(leadingMember leadingMember: String) -> String {
    return orderedMembers(leadingMemberAlias: leadingMember).map { $0.aliasDisplay.familiarName }.joinWithSeparator(separator)
  }
  
  private func orderedMembers(leadingMemberAlias leadingMemberAlias: String) -> [Member] {
    
    var members = self.members
    
    if let leadingMemberIdx = members.indexOf({ $0.alias == leadingMemberAlias }) {
      let leadingMember = members.removeAtIndex(leadingMemberIdx)
      members.insert(leadingMember, atIndex: 0)
    }
    
    return members
  }
  
}



public func generateTitleForChat(chat: Chat) -> ChatTitle {
  
  if let groupChat = chat as? GroupChat, customTitle = groupChat.customTitle {
    return SimpleTitle(title: customTitle)
  }
  
  return AliasDisplayTitle(memberAliases: Array(chat.activeRecipients), aliasDisplayProvider: AliasDisplayManager.sharedProvider)
}
