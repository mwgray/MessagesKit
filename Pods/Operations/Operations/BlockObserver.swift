//
//  BlockObserver.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation

/**
  The `BlockObserver` is a way to attach arbitrary blocks to significant events
  in an `Operation`'s lifecycle.
*/
public struct BlockObserver: OperationObserver {

  // MARK: Properties
  
  private let startHandler: (Operation -> Void)?
  private let produceHandler: ((Operation, NSOperation) -> Void)?
  private let finishHandler: ((Operation, [NSError]) -> Void)?
  
  public init(startHandler: (Operation -> Void)? = nil, produceHandler: ((Operation, NSOperation) -> Void)? = nil, finishHandler: ((Operation, [NSError]) -> Void)? = nil) {
    self.startHandler = startHandler
    self.produceHandler = produceHandler
    self.finishHandler = finishHandler
  }
  
  // MARK: OperationObserver
  
  public func operationDidStart(operation: Operation) {
    startHandler?(operation)
  }
  
  public func operation(operation: Operation, didProduceOperation newOperation: NSOperation) {
    produceHandler?(operation, newOperation)
  }
  
  public func operationDidFinish(operation: Operation, errors: [NSError]) {
    finishHandler?(operation, errors)
  }
  
}
