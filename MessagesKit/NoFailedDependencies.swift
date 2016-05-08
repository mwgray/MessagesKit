//
//  NoFailedDependencies.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import PSOperations

/**
 A condition that specifies that every dependency must have finished without 
 errors. If any dependency has errors, either by finishing or cancelling, the 
 target operation will be cancelled as well.
 */
struct NoFailedDependencies: OperationCondition {
  
  static let name = "NoFailedDependencies"
  
  static let failedDependenciesKey = "FailedDependencies"
  
  static let isMutuallyExclusive = false
  
  init() {
  }
  
  func dependencyForOperation(operation: Operation) -> NSOperation? {
    return nil
  }
  
  func evaluateForOperation(operation: Operation, completion: OperationConditionResult -> Void) {
    
    // Verify that all of the dependencies executed.
    let failed = operation.dependencies.filter {
      if let op = $0 as? Operation {
        return !op.errors.isEmpty || op.cancelled
      }
      else {
        return $0.cancelled
      }
    }
    
    if !failed.isEmpty {
      
      // At least one dependency was cancelled; the condition was not satisfied.
      let error = NSError(
        code: .ConditionFailed,
        userInfo: [
          OperationConditionKey: self.dynamicType.name,
          NoFailedDependencies.failedDependenciesKey: failed
        ])
      
      completion(.Failed(error))
    }
    else {
      completion(.Satisfied)
    }
  }
  
}
