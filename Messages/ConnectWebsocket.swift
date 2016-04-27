//
//  ConnectWebsocket.swift
//  Messages
//
//  Created by Kevin Wooten on 4/23/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation
import Operations
import CocoaLumberjack


public class ConnectWebSocket: Operation {
  
  let api : MessageAPI
  
  public init(api: MessageAPI) {
    
    self.api = api
    
    super.init()
    
    addCondition(RequireAccessToken(api: api))
    addCondition(ReachabilityCondition(host: MessageAPI.target.userConnectURL))
  }
  
  public override func execute() {
    
    DDLogDebug("Connecting web socket")

    api.webSocket.connect()
    
    finish()
  }
  
}
