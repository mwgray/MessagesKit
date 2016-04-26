//
//  NoFailedDependencies.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation

/**
 A condition that specifies that every dependency must have finished without 
 errors. If any dependency has errors, either by finishing or cancelling, the 
 target operation will be cancelled as well.
 */
public struct NoFailedDependencies: OperationCondition {
  
  public static let name = "NoFailedDependencies"
  
  static let failedDependenciesKey = "FailedDependencies"
  
  public static let isMutuallyExclusive = false
  
  public init() {
  }
  
  public func dependencyForOperation(operation: Operation) -> NSOperation? {
    return nil
  }
  
  public func evaluateForOperation(operation: Operation, completion: OperationConditionResult -> Void) {
    
    // Verify that all of the dependencies executed.
    let failed = operation.dependencies.filter { ($0 as? Operation)?.failed ?? false }
    
    if !failed.isEmpty {
      
      // At least one dependency was cancelled; the condition was not satisfied.
      let error = NSError(
        failedConditionName: self.dynamicType.name,
        extraInfo: [
          NoFailedDependencies.failedDependenciesKey: failed
        ])
      
      completion(.Failed(error))
    }
    else {
      completion(.Satisfied)
    }
  }
  
}
