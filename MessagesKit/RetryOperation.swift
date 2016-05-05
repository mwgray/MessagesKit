//
//  RetryOperation.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import PSOperations


/**
  Retries an operation
*/
public class RetryOperation: Operation {
  
  
  private let maxAttempts: UInt
  
  private let failureErrors: [String: Int?]
  
  private let generator: () -> Operation
  
  private var attempt = UInt(1)

  private let internalQueue = OperationQueue()
  
  private var currentOperation : Operation?
  
  
  public required init(maxAttempts: UInt, failureErrors: [String: Int?], generator: () -> Operation) {
    
    self.maxAttempts = maxAttempts
    self.failureErrors = failureErrors
    self.generator = generator
    
    super.init()
    
    internalQueue.delegate = self
  }
  
  public convenience init(maxAttempts: UInt, generator: () -> Operation) {
    self.init(maxAttempts: maxAttempts, failureErrors: [String: Int?](), generator: generator)
  }
  
  public convenience init(maxAttempts: UInt, retryBlock block: (Void -> Void) -> Void) {
    self.init(maxAttempts: maxAttempts, failureErrors: [String: Int?](), generator: {
      return BlockOperation(block: { completion in
        block(completion)
      })
    })
  }
  
  override public func cancel() {
    internalQueue.cancelAllOperations()
    super.cancel()
  }
  
  override public func execute() {
    currentOperation = generator()
    internalQueue.addOperation(currentOperation!)
  }
  
  private func shouldRetry(error: NSError) -> Bool {
    
    for (domain, code) in failureErrors {
      if error.domain == domain && error.code == code {
        return false
      }
    }
    
    return true
  }
  
  private func shouldRetry(errors: [NSError]) -> Bool {
    for error in errors {
      if shouldRetry(error) {
        return true
      }
    }
    return false
  }
  
  override public var description : String {
    return "Retry<" + (currentOperation?.description ?? "None") + ">"
  }
  
}

extension RetryOperation: OperationQueueDelegate {
  
  final public func operationQueue(operationQueue: OperationQueue, operationDidFinish operation: NSOperation, withErrors errors: [NSError]) {

    if errors.isEmpty {
      
      finish()
      
    }
    else {

      if !operation.cancelled && shouldRetry(errors) {
        
        if attempt < maxAttempts {
          
          attempt += 1
          
          currentOperation = generator()
          internalQueue.addOperation(currentOperation!)
          
          return;
          
        }
        
      }
      
      finish(errors)
      
    }
    
  }
  
}
