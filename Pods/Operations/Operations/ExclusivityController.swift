//
//  ExclusivityController.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation

/**
  ExclusivityController - is a singleton to keep track of all the in-flight
  Operation instances that have declared themselves as requiring mutual exclusivity.
  We use a singleton because mutual exclusivity must be enforced across the entire
  app, regardless of the `OperationQueue` on which an `Operation` was executed.
*/
class ExclusivityController {
  
  static let sharedExclusivityController = ExclusivityController()
  
  private let serialQueue = dispatch_queue_create("Operations.ExclusivityController", DISPATCH_QUEUE_SERIAL)
  private var operations: [String: [Operation]] = [:]
  
  private init() {
    // Prevent creation
  }
  
  /// Registers an operation as being mutually exclusive
  
  func addOperation(operation: Operation, categories: [String]) {

    // Use queue to synchronize access
    dispatch_sync(serialQueue) {
      
      for category in categories {
        self._addOperation(operation, category: category)
      }
      
    }    
  }
  
  /// Unregisters an operation from being mutually exclusive.
  
  func removeOperation(operation: Operation, categories: [String]) {
    
    // Use queue to synchronize access
    dispatch_async(serialQueue) {
      
      for category in categories {
        self._removeOperation(operation, category: category)
      }
      
    }
  }
  
  // MARK: Operation Management
  
  private func _addOperation(operation: Operation, category: String) {

    // This provides the mutual exclusivity. We make the previously added operation a
    // dependency of the newly added operation. This creates a chain of dependencies
    // between all operations of the same categories.
    //
    // Note that the list inside the map keeps the operations in insertion order, which 
    // is required for proper dependency chaining
    
    var operationsInCategory = operations[category] ?? []
    
    if let last = operationsInCategory.last {
      operation.addDependency(last)
    }
    
    operationsInCategory.append(operation)
    
    operations[category] = operationsInCategory
  }
  
  private func _removeOperation(operation: Operation, category: String) {
    
    let operationsInCategory = operations[category]
    
    if var operationsInCategory = operationsInCategory,
      let index = operationsInCategory.indexOf(operation) {
        
        operationsInCategory.removeAtIndex(index)
        operations[category] = operationsInCategory
    }
  }
  
}
