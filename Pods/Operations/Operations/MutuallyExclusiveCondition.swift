//
//  MutuallyExclusiveCondition.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation

/// A generic condition for describing kinds of operations that may not execute concurrently.
public struct MutuallyExclusiveCondition<T>: OperationCondition {
  
  public static var name: String {
    return "MutuallyExclusive<\(T.self)>"
  }
  
  public static var isMutuallyExclusive : Bool { return true }
  
  public init() { }
  
  public func dependencyForOperation(operation: Operation) -> NSOperation? {
    return nil
  }
  
  public func evaluateForOperation(operation: Operation, completion: OperationConditionResult -> Void) {
    completion(.Satisfied)
  }
  
}


enum Modal {}
typealias ModalCondition = MutuallyExclusiveCondition<Modal>

typealias ViewHierarchyCondition = MutuallyExclusiveCondition<UIViewController>
