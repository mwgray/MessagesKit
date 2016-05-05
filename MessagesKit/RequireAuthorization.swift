//
//  RequireAuthorization.swift
//  ReTxt
//
//  Created by Kevin Wooten on 9/15/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import PSOperations


public struct RequireAuthorization: OperationCondition {
  
  public static let name = "RequireAuthorization"
  
  public static let isMutuallyExclusive = false
  
  let api : MessageAPI
  
  init(api: MessageAPI) {
    self.api = api
  }
  
  public func dependencyForOperation(operation: Operation) -> NSOperation? {
    return nil
  }
  
  public func evaluateForOperation(operation: Operation, completion: OperationConditionResult -> Void) {

    if api.credentials.authorized {
      completion(.Satisfied)
    }
    else {
      let error = NSError(
        code: .ConditionFailed,
        userInfo: [
          OperationConditionKey: RequireAuthorization.name
        ])
      
      completion(.Failed(error))
    }
    
  }
  
}
