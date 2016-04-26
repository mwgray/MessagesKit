//
//  GroupOperation.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation

/**
  A subclass of `Operation` that executes zero or more operations as part of its
  own execution. This class of operation is very useful for abstracting several
  smaller operations into a larger operation.
*/
public class GroupOperation: Operation {
  
  
  private let internalQueue = OperationQueue()
  
  private let finishingOperation = NSBlockOperation(block: {})
  
  private var aggregatedErrors = [NSError]()
  
  
  public convenience init(operations: NSOperation...) {
    self.init(operations: operations)
  }
  
  public init(operations: [NSOperation]) {
    super.init()
    
    internalQueue.suspended = true
    
    internalQueue.delegate = self

    addOperations(operations)
  }
  
  override public func cancel() {
    internalQueue.cancelAllOperations()
    super.cancel()
  }
  
  override public func execute() {
    internalQueue.suspended = false
    internalQueue.addOperation(finishingOperation)
  }
  
  public func addOperation(operation: NSOperation) {
    internalQueue.addOperation(operation)
  }
  
  public func addOperations(operations: [NSOperation]) {
    for operation in operations {
      internalQueue.addOperation(operation)
    }
  }
  
  /**
    Note that some part of execution has produced an error.
    Errors aggregated through this method will be included in the final array
    of errors reported to observers and to the `finished(_:)` method.
  */
  final func aggregateError(error: NSError) {
    aggregatedErrors.append(error)
  }
  
  public func childOperation(operationWillAdd: NSOperation) {
    // For use by subclassers.
  }
  
  public func childOperation(operation: NSOperation, didFinishWithErrors errors: [NSError]) {
    // For use by subclassers.
  }
  
}

extension GroupOperation: OperationQueueDelegate {
  
  final public func operationQueue(operationQueue: OperationQueue, willAddOperation operation: NSOperation) {
    assert(!finishingOperation.finished && !finishingOperation.executing, "cannot add new operations to a group after the group has completed")
    
    /*
      Some operation in this group has produced a new operation to execute.
      We want to allow that operation to execute before the group completes,
      so we'll make the finishing operation dependent on this newly-produced operation.
    */
    if operation !== finishingOperation {
      finishingOperation.addDependency(operation)
    }
    
    childOperation(operation)
  }
  
  final public func operationQueue(operationQueue: OperationQueue, operationDidFinish operation: NSOperation, withErrors errors: [NSError]) {
    
    aggregatedErrors.appendContentsOf(errors)
    
    if operation === finishingOperation {
      
      internalQueue.suspended = true
      
      finishWithErrors(aggregatedErrors)
      
    }
    else {
      
      childOperation(operation, didFinishWithErrors: errors)
      
    }
    
  }
  
}
