//
//  ReachabilityCondition.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import SystemConfiguration


/**
  This is a condition that performs a very high-level reachability check.
  It does *not* perform a long-running reachability check, nor does it respond to changes in reachability.
  Reachability is evaluated once when the operation to which this is attached is asked about its readiness.
*/
public struct ReachabilityCondition: OperationCondition {
  
  static let hostKey = "Host"
  
  public static let name = "Reachability"
  
  public static let isMutuallyExclusive = false
  
  let host: NSURL
  
  
  public init(host: NSURL) {
    self.host = host
  }
  
  public func dependencyForOperation(operation: Operation) -> NSOperation? {
    return nil
  }
  
  public func evaluateForOperation(operation: Operation, completion: OperationConditionResult -> Void) {
  
    ReachabilityController.requestReachability(host) { reachable in
      
      if reachable {
        completion(.Satisfied)
      }
      else {
        
        let error = NSError(
          failedConditionName: self.dynamicType.name,
          extraInfo:[
            ReachabilityCondition.hostKey: self.host
          ])
        
        completion(.Failed(error))
      }
      
    }
    
  }
  
}

/// A private singleton that maintains a basic cache of `SCNetworkReachability` objects.
private class ReachabilityController {
  
  static var reachabilityRefs = [String: SCNetworkReachability]()
  
  static let reachabilityQueue = dispatch_queue_create("Operations.Reachability", DISPATCH_QUEUE_SERIAL)
  
  static func requestReachability(url: NSURL, completionHandler: (Bool) -> Void) {
    
    if let host = url.host {
      
      dispatch_async(reachabilityQueue) {
        
        let ref : SCNetworkReachability
        
        if let current = self.reachabilityRefs[host] {
          
          ref = current
          
        }
        else {
          
          let hostString = host as NSString
          if let new = SCNetworkReachabilityCreateWithName(nil, hostString.UTF8String) {
            
            self.reachabilityRefs[host] = new
            ref = new
            
          }
          else {
            
            completionHandler(false)
            return
            
          }
          
        }
      
        var reachable = false
        var flags = SCNetworkReachabilityFlags()
        
        if SCNetworkReachabilityGetFlags(ref, &flags) {
          
          /*
            Note that this is a very basic "is reachable" check.
            Your app may choose to allow for other considerations,
            such as whether or not the connection would require
            VPN, a cellular connection, etc.
          */
          
          reachable = flags.contains(.Reachable)
          
        }
        
        completionHandler(reachable)

      }
      
    }
    else {
      completionHandler(false)
    }
    
  }
}
