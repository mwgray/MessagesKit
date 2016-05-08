//
//  UpdateAccessTokenOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 3/12/16.
//  Copyright © 2016 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import PSOperations
import CocoaLumberjack


class UpdateAccessTokenOperation: Operation {
  
  let api : MessageAPI
  
  init(api: MessageAPI) {

    self.api = api
    
    super.init()

    addCondition(MutuallyExclusive<UpdateAccessTokenOperation>())
    addCondition(ReachabilityCondition(host: MessageAPI.target.publicURL))
  }
  
  override func execute() {
    
    // No need to regenerate...
    if api.accessToken != nil {
      finish()
      return
    }

    DDLogDebug("Updating access token")
  
    api.publicAPI.generateAccessToken(api.credentials.userId, deviceId: api.credentials.deviceId, refreshToken: api.credentials.refreshToken,
      response: { accessToken in

        self.api.updateAccessToken(accessToken)
        
        DDLogDebug("Access token updated")
        
        self.finish()
      },
      failure: { error in
        self.finishWithError(error)
      })
  }
  
}
