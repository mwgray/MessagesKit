//
//  MessageDAO.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/11/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation


extension MessageDAO {
  
  public func fetchLatestUnviewedMessageForChat(chat: Chat) throws -> Message? {
    var message : Message?
    try __fetchLatestUnviewedMessage(&message, forChat: chat)
    return message
  }

  public func fetchLastMessageForChat(chat: Chat) throws -> Message? {
    var message : Message?
    try __fetchLastMessage(&message, forChat: chat)
    return message
  }
  
}
