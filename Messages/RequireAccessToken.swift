//
//  RequireAccessToken.swift
//  ReTxt
//
//  Created by Kevin Wooten on 3/12/16.
//  Copyright © 2016 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import Operations


public struct RequireAccessToken: OperationCondition {
  
  public static let name = "RequireAccessToken"
  
  public static let isMutuallyExclusive = true
  
  let api : RTMessageAPI
  
  init(api: RTMessageAPI) {
    self.api = api
  }
  
  public func dependencyForOperation(operation: Operation) -> NSOperation? {
    
    if api.accessToken != nil {
      // No need for update
      return nil
    }
    
    return UpdateAccessToken(api: api)
  }
  
  public func evaluateForOperation(operation: Operation, completion: OperationConditionResult -> Void) {

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
