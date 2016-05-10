//
//  PromiseKit+Utils.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 4/22/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation



public enum PromiseError : ErrorType {
  case WaitTimeExpired
  case ConversionCastingError
  case ConversionUnwrappingError
}

extension Promise where T : AnyObject {

  func wait(time: dispatch_time_t = DISPATCH_TIME_FOREVER) throws -> T? {
    let sema = dispatch_semaphore_create(0)
    always {
      dispatch_semaphore_signal(sema)
    }
    
    if dispatch_semaphore_wait(sema, time) != 0 {
      throw PromiseError.WaitTimeExpired
    }
    
    if let error = error {
      throw error
    }
    
    return self.value
  }
  
  func to<U>() -> Promise<U> {
    
    return self.then(on: zalgo) { value -> U in
      
      if let value = value as? U {
        return value
      }
      
      throw PromiseError.ConversionCastingError
    }
  }
  
}


protocol OptionalEquivalent {
  associatedtype WrappedValueType
  func toOptional() -> WrappedValueType?
}

extension Optional: OptionalEquivalent {
  
  typealias WrappedValueType = Wrapped
  
  // just to cast `Optional<Wrapped>` to `Wrapped?`
  func toOptional() -> WrappedValueType? {
    return self
  }
  
}

extension Promise where T : OptionalEquivalent {
  
  func to<U>() -> Promise<U?> {
    
    return self.then(on: zalgo) { value -> U? in
      
      guard let value = value.toOptional() else {
        return nil
      }
      
      if let value = value as? U {
        return value
      }
      
      throw PromiseError.ConversionCastingError
    }
  }
  
  func to<U>() -> Promise<U> {
    
    return self.then(on: zalgo) { value -> U in
      
      guard let value = value.toOptional() else {
        throw PromiseError.ConversionUnwrappingError
      }
      
      if let value = value as? U {
        return value
      }
      
      throw PromiseError.ConversionCastingError
    }
  }
  
}


extension AnyPromise {
  
  func toPromise<T>(type: T.Type) -> Promise<T> {
    
    return self.then(on: zalgo) { (value: AnyObject?) -> T in
      
      if let value = value as? T {
        return value
      }
      
      throw PromiseError.ConversionCastingError
    }
  }
  
  
  convenience public init<T: AnyObject>(bound: Promise<Set<T>>) {
    self.init(bound: bound.then(on: zalgo) { $0 as NSSet })
  }
  
  convenience public init(bound: Promise<Set<String>>) {
    self.init(bound: bound.then(on: zalgo) { $0 as NSSet })
  }

}
