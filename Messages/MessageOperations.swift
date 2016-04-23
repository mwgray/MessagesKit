//
//  MessageOperations.swift
//  ReTxt
//
//  Created by Kevin Wooten on 7/28/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import Operations
import PromiseKit


public typealias Resolver = (AnyObject?) -> Void

public class MessageAPIOperation: Operation {
  
  
  let api : RTMessageAPI
  
  public var resolver : Resolver?
  
  public var resolveResult : AnyObject? {
    return nil
  }
  
  public init(api: RTMessageAPI) {
    self.api = api
    
    super.init()
    
    addCondition(NoFailedDependencies())
    addCondition(RequireAccessToken(api: api))
  }
  
  override public func finished(errors: [NSError]) {
    
    for error in errors {
      
      let transError = RTAPIErrorFactory.translateError(error)
      
      if transError.checkAPIError(.AuthenticationError) {
        
        api.signOut()
        
      }
      
    }
    
    if let resolver = resolver {
      if let error = errors.first {
        resolver(error)
      }
      else {
        resolver(resolveResult)
      }
    }
    
  }

  
}


public class MessageAPIGroupOperation: GroupOperation {
  
  
  let api : RTMessageAPI
  
  public var resolver : Resolver?
  
  public var resolveResult : AnyObject? {
    return nil
  }
  
  public init(api: RTMessageAPI) {
    self.api = api
    
    super.init(operations: [])
    
    addCondition(NoFailedDependencies())
    addCondition(RequireAccessToken(api: api))
  }
  
  override public func finished(errors: [NSError]) {
    
    for error in errors {
      
      let transError = RTAPIErrorFactory.translateError(error)
      
      if transError.checkAPIError(.AuthenticationError) {
        
        api.signOut()
        
      }
      
    }
    
    if let resolver = resolver {
      if let error = errors.first {
        resolver(error)
      }
      else {
        resolver(resolveResult)
      }
    }
    
  }
  
}
