//
//  RTDAO.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 4/22/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation


extension RTDAO {

  public func fetchObjectWithId(id: RTId) throws -> RTModel? {
    var obj : RTModel?
    try fetchObjectWithId(id, returning: &obj)
    return obj
  }
  
}


extension RTMessageDAO {
  
  public func fetchMessageWithId(id: RTId) throws -> RTMessage? {
    var obj : RTMessage?
    try fetchMessageWithId(id, returning: &obj)
    return obj
  }
  
}


extension RTChatDAO {
  
  public func fetchChatWithId(id: RTId) throws -> RTChat? {
    var obj : RTChat?
    try fetchChatWithId(id, returning: &obj)
    return obj
  }
  
  public func fetchChatForAlias(alias: String, localAlias: String) throws -> RTChat? {
    var obj : RTChat?
    try fetchChatForAlias(alias, localAlias: localAlias, returning: &obj)
    return obj
  }
  
}


extension RTNotificationDAO {
  
  public func fetchNotificationWithId(id: RTId) throws -> RTNotification? {
    var obj : RTNotification?
    try fetchNotificationWithId(id, returning: &obj)
    return obj
  }
  
}
