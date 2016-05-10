//
//  DAO.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 4/22/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation


extension DAO {

  public func fetchObjectWithId(id: Id) throws -> Model? {
    var obj : Model?
    try fetchObjectWithId(id, returning: &obj)
    return obj
  }
  
}


extension MessageDAO {
  
  public func fetchMessageWithId(id: Id) throws -> Message? {
    var obj : Message?
    try fetchMessageWithId(id, returning: &obj)
    return obj
  }
  
}


extension ChatDAO {
  
  public func fetchChatWithId(id: Id) throws -> Chat? {
    var obj : Chat?
    try fetchChatWithId(id, returning: &obj)
    return obj
  }
  
  public func fetchChatForAlias(alias: String, localAlias: String) throws -> Chat? {
    var obj : Chat?
    try fetchChatForAlias(alias, localAlias: localAlias, returning: &obj)
    return obj
  }
  
}


extension NotificationDAO {
  
  public func fetchNotificationWithId(id: Id) throws -> Notification? {
    var obj : Notification?
    try fetchNotificationWithId(id, returning: &obj)
    return obj
  }
  
}
