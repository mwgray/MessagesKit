//
//  ConnectWebsocketOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 4/23/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation
import PSOperations
import CocoaLumberjack


class ConnectWebSocketOperation: Operation {
  
  let api : MessageAPI
  
  init(api: MessageAPI) {
    
    self.api = api
    
    super.init()
    
    addCondition(RequireAccessToken(api: api))
    addCondition(ReachabilityCondition(host: MessageAPI.target.userConnectURL))
  }
  
  override func execute() {
    
    DDLogDebug("Connecting web socket")

    api.webSocket.connect()
    
    finish()
  }
  
}
