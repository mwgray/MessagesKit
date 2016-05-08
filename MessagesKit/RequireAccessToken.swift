//
//  RequireAccessToken.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 3/12/16.
//  Copyright © 2016 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import PSOperations


struct RequireAccessToken: OperationCondition {
  
  static let name = "RequireAccessToken"
  
  static let isMutuallyExclusive = false
  
  let api : MessageAPI
  
  init(api: MessageAPI) {
    self.api = api
  }
  
  func dependencyForOperation(operation: Operation) -> NSOperation? {
    
    if api.accessToken != nil {
      // No need for update
      return nil
    }
    
    return UpdateAccessTokenOperation(api: api)
  }
  
  func evaluateForOperation(operation: Operation, completion: OperationConditionResult -> Void) {

    if api.accessToken != nil {
      completion(.Satisfied)
    }
    else {
      
      let error = NSError(
        code: .ConditionFailed,
        userInfo: [
          OperationConditionKey: RequireAccessToken.name
        ])
      
      completion(.Failed(error))
    }
    
  }
  
}
