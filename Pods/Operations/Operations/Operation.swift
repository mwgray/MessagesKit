//
//  Operation.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation

/**
  Operation
*/
public class Operation: NSOperation {
  
  // MARK: state Property
  
  private enum State: Int, Comparable, CustomStringConvertible {
    
    case Initialized
    
    case Pending
    
    case EvaluatingConditions
    
    case Ready
    
    case Executing
    
    case Finishing
    
    case Finished
    
    var description : String {
      switch self {
      case .Initialized:
        return "Initialized"
      case .Pending:
        return "Pending"
      case .EvaluatingConditions:
        return "EvaluatingConditions"
      case .Ready:
        return "Ready"
      case .Executing:
        return "Executing"
      case .Finishing:
        return "Finishing"
      case .Finished:
        return "Finished"
      }
    }
  }
  
  /// "state" KVO setup
  
  class func keyPathsForValuesAffectingIsReady() -> Set<NSObject> {
    return ["state"]
  }
  
  class func keyPathsForValuesAffectingIsExecuting() -> Set<NSObject> {
    return ["state"]
  }
  
  class func keyPathsForValuesAffectingIsFinished() -> Set<NSObject> {
    return ["state"]
  }
  
  var debug = false
  
  /// "state" Private Storage
  
  private var _state = State.Initialized
  private var _cancelled = false
  
  /// "state" Property Implementation
  
  private var state: State {
    
    get {
      return _state
    }
    
    set(newState) {
      
      if debug {
        NSLog("%@: %@", self.description, newState.description)
      }
      
      assert(newState > _state, "Invalid state transition")
      
      willChangeValueForKey("state")

      _state = newState
      
      didChangeValueForKey("state")
      
    }
    
  }
  
  /**
    External properties
  */

  override public var ready: Bool {
    
    switch state {
    
    case .Pending:
      if super.ready {
        evaluateConditions()
      }
      return false
      
    case .Ready:
      return super.ready
      
    default:
      return false
    }
    
  }
  
  override public var executing: Bool {
    return state == .Executing
  }
  
  override public var finished: Bool {
    return state == .Finished
  }
  
  override public var cancelled: Bool {
    return _cancelled
  }
  
  public var succeeded: Bool {
    return errors.isEmpty && !cancelled
  }
  
  public var failed: Bool {
    return !errors.isEmpty || cancelled
  }

  public var userInitiated: Bool {
    get {
      return qualityOfService == .UserInitiated
    }
    
    set {
      assert(state < .Executing, "Cannot modify userInitiated after execution has begun.")
      
      qualityOfService = newValue ? .UserInitiated : .Default
    }
  }

  func willEnqueue() {
    state = .Pending
  }
  
  private func evaluateConditions() {
    assert(state == .Pending, "evaluateConditions() was called out-of-order")
    
    state = .EvaluatingConditions
    
    OperationConditionEvaluator.evaluate(conditions, operation: self) { failures in
      if !failures.isEmpty {
        self.cancelWithErrors(failures)
      }
      self.state = .Ready
    }
  }
  
  // MARK: Observers and Conditions
  
  private(set) var conditions = [OperationCondition]()
  
  public func addCondition(condition: OperationCondition) {
    assert(state < .EvaluatingConditions, "Cannot modify conditions after evaluation has begun.")
    
    conditions.append(condition)
  }
  
  private(set) var observers = [OperationObserver]()
  
  public func addObserver(observer: OperationObserver) {
    assert(state < .Executing, "Cannot modify observers after execution has begun.")
    
    observers.append(observer)
  }
  
  override public func addDependency(operation: NSOperation) {
    assert(state < .Executing, "Cannot modify dependencies after execution has begun.")
    
    super.addDependency(operation)
  }
  
  // MARK: Execution and Cancellation
  
  override public func start() {
    
    if _cancelled {
      
      finish()
      
    }
    else {
    
      assert(state == .Ready, "This operation must be performed on an operation queue.")
      
      state = .Executing
      
      for observer in observers {
        observer.operationDidStart(self)
      }
      
      execute()
      
    }
    
  }
  
  /**
    Entry point of execution for all subclasses.
  
    At some point, your `Operation` subclass must call one of the "finish"
    methods defined below; this is how you indicate that your operation has
    finished its execution, and operations dependent on yours can re-evaluate
    their readiness state.
  */
  public func execute() {
    
    finish()
  }
  
  private var _errors = [NSError]()
  
  public var errors : [NSError] {
    return _errors
  }
  
  /// Cancel with no error
  override public func cancel() {
    cancelWithErrors([])
  }
  
  /// Cancel with provided error
  public func cancelWithError(error: NSError?) {
    
    if let error = error {
      
      cancelWithErrors([error])
      
      return
    }

    cancelWithErrors([])
  }
  
  /// Cancel with errors
  public func cancelWithErrors(errors: [NSError]) {

    _errors.appendContentsOf(errors)
    
    willChangeValueForKey("isCancelled")
    
    _cancelled = true
    
    didChangeValueForKey("isCancelled")
    
    if state == .Executing {
      finish()
    }
  }
  
  /// Produce operation while executing
  public final func produceOperation(operation: NSOperation) {
    
    for observer in observers {
      observer.operation(self, didProduceOperation: operation)
    }
    
  }
  
  // MARK: Finishing
  
  public final func finish() {
    
    finishWithErrors([])
  }
  
  public final func finishWithError(error: NSError?) {
    
    if let error = error {
      finishWithErrors([error])
    }
    else {
      finishWithErrors([])
    }
    
  }
  
  public final func finishWithErrors(errors: [NSError]) {
    
    if state < .Finishing {
      
      state = .Finishing
      
      _errors.appendContentsOf(errors)
      
      finished(_errors)
      
      for observer in observers {
        observer.operationDidFinish(self, errors: _errors)
      }
      
      state = .Finished
    }
    
  }
  
  /**
    Subclasses may override `finished(_:)` if they wish to react to the operation
    finishing with errors.
  */
  public func finished(errors: [NSError]) {
    // No op.
  }
  
}

// Simple operator functions to simplify the assertions used above.
private func >(lhs: Operation.State, rhs: Operation.State) -> Bool {
  return lhs.rawValue > rhs.rawValue
}

private func <(lhs: Operation.State, rhs: Operation.State) -> Bool {
  return lhs.rawValue < rhs.rawValue
}

private func ==(lhs: Operation.State, rhs: Operation.State) -> Bool {
  return lhs.rawValue == rhs.rawValue
}
