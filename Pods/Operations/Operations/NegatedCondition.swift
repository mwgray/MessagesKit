//
//  NegatedCondition.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation

/**
  A simple condition that negates the evaluation of another condition.
  This is useful (for example) if you want to only execute an operation if the
  network is NOT reachable.
*/
public struct NegatedCondition<T: OperationCondition>: OperationCondition {
  
  public static var name: String {
    return "Not<\(T.name)>"
  }
  
  static var negatedConditionKey: String {
    return "NegatedCondition"
  }
  
  public static var isMutuallyExclusive : Bool {
    return T.isMutuallyExclusive
  }
  
  let condition: T
  
  init(condition: T) {
    self.condition = condition
  }
  
  public func dependencyForOperation(operation: Operation) -> NSOperation? {
    return condition.dependencyForOperation(operation)
  }
  
  public func evaluateForOperation(operation: Operation, completion: OperationConditionResult -> Void) {
    condition.evaluateForOperation(operation) { result in
      if result.error == nil {
        // If the composed condition failed, then this one succeeded.
        completion(.Satisfied)
      }
      else {
        // If the composed condition succeeded, then this one failed.
        let error = NSError(
          failedConditionName: self.dynamicType.name,
          extraInfo: [
            self.dynamicType.negatedConditionKey: self.condition.dynamicType.name
          ])
        
        completion(.Failed(error))
      }
    }
  }
}
