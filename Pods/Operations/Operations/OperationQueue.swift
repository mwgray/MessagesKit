//
//  OperationQueue.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation


/**
  The delegate of an `OperationQueue` can respond to `Operation` lifecycle
  events by implementing these methods.
*/
@objc public protocol OperationQueueDelegate: NSObjectProtocol {
  
  optional func operationQueue(operationQueue: OperationQueue, willAddOperation operation: NSOperation)
  
  optional func operationQueue(operationQueue: OperationQueue, operationDidFinish operation: NSOperation, withErrors errors: [NSError])
}


/**
  `OperationQueue` is an `NSOperationQueue` subclass that implements a large
  number of "extra features" related to the `Operation` class:

  - Notifying a delegate of all operation completion
  - Extracting generated dependencies from operation conditions
  - Setting up dependencies to enforce mutual exclusivity
*/
public class OperationQueue: NSOperationQueue {
  
  weak var delegate: OperationQueueDelegate?
  
  override public func addOperation(operation: NSOperation) {
    
    if let op = operation as? Operation {
      
      // Add an observer to invoke delegate & management methods
      
      let queueDelegateExecutionObserver = BlockObserver(
        startHandler: nil,
        produceHandler: { [weak self] in
          self?.addOperation($1)
        },
        finishHandler: { [weak self] in
          if let q = self {
            q.delegate?.operationQueue?(q, operationDidFinish: $0, withErrors: $1)
          }
        }
      )
      op.addObserver(queueDelegateExecutionObserver)
      
      // Extract dependencies needed by the operation
      
      let dependencies = op.conditions
        .map { $0.dependencyForOperation(op) }
        .filter { $0 != nil }
        .map { $0! }
      
      // Wire up dependencies
      
      for dependency in dependencies {
        
        op.addDependency(dependency)
        
        self.addOperation(dependency)
      }
      
      // Enforce mutual-exclusivity for operations that need it
      
      let concurrencyCategories: [String] = op.conditions.flatMap { condition in
        if !condition.dynamicType.isMutuallyExclusive {
          return nil
        }
        return "\(condition.dynamicType)"
      }
      
      if !concurrencyCategories.isEmpty {
        
        // Set up the mutual exclusivity dependencies.
        
        let exclusivityController = ExclusivityController.sharedExclusivityController
        
        exclusivityController.addOperation(op, categories: concurrencyCategories)
        
        op.addObserver(BlockObserver { operation, _ in
          
          exclusivityController.removeOperation(operation, categories: concurrencyCategories)
          
        })
      }
      
      // Notify operation we're done with setup

      op.willEnqueue()
      
    }
    else {
      
      // Add completion block to call delegate
      
      operation.addCompletionBlock { [weak self, weak operation] in
        
        if let queue = self, let operation = operation {
            queue.delegate?.operationQueue?(queue, operationDidFinish: operation, withErrors: [])
        }
        
      }
      
    }
    
    delegate?.operationQueue?(self, willAddOperation: operation)
    
    super.addOperation(operation)
  }
  
  public func addOperations(operations: [NSOperation]) {
    
    for operation in operations {
      addOperation(operation)
    }
    
  }
  
  /**
    Override to ensure addOperation is called explicitly
  */
  override public func addOperations(operations: [NSOperation], waitUntilFinished wait: Bool) {
    
    for operation in operations {
      addOperation(operation as NSOperation)
    }
    
    if wait {
      for operation in operations {
        operation.waitUntilFinished()
      }
    }
    
  }
  
  func chainOperations(operations: [NSOperation]) {
    var last : NSOperation?
    
    for operation in operations {
      if let last = last {
        operation.addDependency(last)
      }
      addOperation(operation)
      last = operation
    }
    
  }
  
}
