//
//  RegisterNotificationTokenOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/6/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation
import PSOperations
import CocoaLumberjack


class RegisterNotificationTokenOperation: Operation {
  
  let api : MessageAPI
  let type : RTNotificationType
  let token : NSData
  
  
  init(token: NSData, type: RTNotificationType, api: MessageAPI) {
    
    self.api = api
    self.type = type
    self.token = token
    
    super.init()
    
    addCondition(RequireAuthorization(api: api))
    addCondition(RequireAccessToken(api: api))
    addCondition(ReachabilityCondition(host: MessageAPI.target.publicURL))
  }
  
  override func execute() {
    
    api.userAPI.registerNotifications(type, platform: "Apple", token: token).toPromise(Void)
      .error { error in
        DDLogError("Error registering \(self.type) notification token: \(error)")
      }
  }

}
