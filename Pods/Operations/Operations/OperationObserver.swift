//
//  OperationObserver.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation


/**
  The protocol that types may implement if they wish to be 
  notified of significant operation lifecycle events.
*/
public protocol OperationObserver {
  
  /// Invoked prior to the operation being executed.
  func operationDidStart(operation: Operation)
  
  /// Invoked when operation produces another operation.
  func operation(operation: Operation, didProduceOperation newOperation: NSOperation)
  
  /// Invoked when operation finishes.
  func operationDidFinish(operation: Operation, errors: [NSError])
  
}
