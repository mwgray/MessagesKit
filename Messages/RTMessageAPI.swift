//
//  RTMessageAPI.swift
//  Messages
//
//  Created by Kevin Wooten on 4/16/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation


extension RTMessageAPI {
  
  public func findUserWithAlias(alias: String) -> Promise<RTId?> {
    return __findUserWithAlias(alias).then(on: zalgo) { result in
      return result as? RTId
    }
  }
  
  public func resolveUserWithAlias(alias: String) throws -> RTUserInfo? {
    return try userInfoCache.objectForKey(alias) as? RTUserInfo
  }
  
  public func invalidateUserWithAlias(alias: String) {
    userInfoCache.invalidateObjectForKey(alias)
  }
  
  public class func profileWithAlias(alias: String, password: String) -> Promise<RTUserProfile> {
    return Promise(resolvers: {fulfill, reject in
      RTMessageAPI.publicAPI()
        .profileWithAlias(alias, password: password,
          response: { fulfill($0) }, failure: { reject($0) })
    })
  }
  
  public class func profileWithId(userId: RTId, password: String) -> Promise<RTUserProfile> {
    return Promise(resolvers: {fulfill, reject in
      RTMessageAPI.publicAPI()
        .profileWithId(userId, password: password,
          response: { fulfill($0) }, failure: { reject($0) })
    })
  }
  
}
