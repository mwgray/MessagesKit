//
//  UpdateAccessToken.swift
//  ReTxt
//
//  Created by Kevin Wooten on 3/12/16.
//  Copyright © 2016 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import Operations


class UpdateAccessToken: Operation {
  
  let api : RTMessageAPI
  
  init(api: RTMessageAPI) {

    self.api = api
    
    super.init()
    
    addCondition(ReachabilityCondition(host: RTServerAPI.publicURL()))
  }
  
  override func execute() {
  
    api.publicAPI.generateAccessToken(api.credentials.userId, deviceId: api.credentials.deviceId, refreshToken: api.credentials.refreshToken,
      response: { accessToken in
        self.api.updateAccessToken(accessToken)
        self.finish()
      },
      failure: { error in
        self.finishWithError(error)
      })
  }
  
}
