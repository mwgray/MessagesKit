//
//  NoCancelledDependencies.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation

/**
  A condition that specifies that every dependency must have not been cancelled.
  If any dependency was cancelled, the target operation will be cancelled as
  well.
*/
public struct NoCancelledDependencies: OperationCondition {
  
  public static let name = "NoCancelledDependencies"
  
  static let cancelledDependenciesKey = "CancelledDependencies"
  
  public static let isMutuallyExclusive = false
  
  public init() {
  }
  
  public func dependencyForOperation(operation: Operation) -> NSOperation? {
    return nil
  }
  
  public func evaluateForOperation(operation: Operation, completion: OperationConditionResult -> Void) {
    
    // Verify that all of the dependencies executed.
    let cancelled = operation.dependencies.filter { $0.cancelled }
    
    if !cancelled.isEmpty {
      
      // At least one dependency was cancelled; the condition was not satisfied.
      let error = NSError(
        failedConditionName: self.dynamicType.name,
        extraInfo: [
          NoCancelledDependencies.cancelledDependenciesKey: cancelled
        ])
      
      completion(.Failed(error))
    }
    else {
      completion(.Satisfied)
    }
  }
  
}
