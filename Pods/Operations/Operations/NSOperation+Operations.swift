//
//  NSOperation+Operations.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation

extension NSOperation {

  /**
    Add a completion block to be executed after the `NSOperation` enters the
    "finished" state.
  */
  public func addCompletionBlock(block: Void -> Void) {
  
    if let existing = completionBlock {
      
      /*
        If we already have a completion block, we construct a new one by
        chaining them together.
      */
      completionBlock = {
        existing()
        block()
      }
      
    }
    else {
      completionBlock = block
    }
    
  }
  
  /// Add multiple depdendencies to the operation.
  public func addDependencies(dependencies: [NSOperation]) {
    
    for dependency in dependencies {
      addDependency(dependency)
    }
    
  }
  
}
