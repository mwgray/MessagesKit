//
//  NetworkObserver.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import UIKit
import PSOperations


/**
  NetworkObserver

  Shows the network activity indicator to appear as long
  as the operation to which it is attached is executing.
*/
struct NetworkObserver: OperationObserver {
  
  // MARK: Initilization
  
  init() { }
  
  func operationDidStart(operation: Operation) {
    dispatch_async(dispatch_get_main_queue()) {
      NetworkIndicatorController.sharedIndicatorController.incrementUsage()
    }
  }
  
  func operationDidCancel(operation: Operation) {
  }
  
  func operation(operation: Operation, didProduceOperation newOperation: NSOperation) {
  }
  
  func operationDidFinish(operation: Operation, errors: [NSError]) {
    dispatch_async(dispatch_get_main_queue()) {
      NetworkIndicatorController.sharedIndicatorController.decrementUsage()
    }
  }
  
}

/**
  Manages a "reference count" on the network activity indicator. Shows
  the indicator when reference count > 0
*/
private class NetworkIndicatorController {
  
  // MARK: Properties
  
  static let sharedIndicatorController = NetworkIndicatorController()
  
  private var activityCount = 0
  
  private var visibilityTimer: Timer?
  
  // MARK: Methods
  
  func incrementUsage() {
    assert(NSThread.isMainThread(), "Altering network activity indicator state can only be done on the main thread.")
    
    activityCount += 1
    
    updateIndicatorVisibility()
  }
  
  func decrementUsage() {
    assert(NSThread.isMainThread(), "Altering network activity indicator state can only be done on the main thread.")
    
    activityCount -= 1
    
    updateIndicatorVisibility()
  }
  
  private func updateIndicatorVisibility() {
    if activityCount > 0 {
      showIndicator()
    }
    else {
      /*
        To prevent the indicator from flickering on and off, we delay the
        hiding of the indicator by half a second. This provides the chance
        to come in and invalidate the timer before it fires.
      */
      visibilityTimer = Timer(interval: 0.3) {
        self.hideIndicator()
      }
    }
  }
  
  private func showIndicator() {
    visibilityTimer?.cancel()
    visibilityTimer = nil
    UIApplication.sharedApplication().networkActivityIndicatorVisible = true
  }
  
  private func hideIndicator() {
    visibilityTimer?.cancel()
    visibilityTimer = nil
    UIApplication.sharedApplication().networkActivityIndicatorVisible = false
  }
  
}

/// Essentially a cancellable `dispatch_after`.

class Timer {
 
  // MARK: Properties
  
  private var isCancelled = false
  
  // MARK: Initialization
  
  init(interval: NSTimeInterval, handler: dispatch_block_t) {
    let when = dispatch_time(DISPATCH_TIME_NOW, Int64(interval * Double(NSEC_PER_SEC)))
    
    dispatch_after(when, dispatch_get_main_queue()) { [weak self] in
      if self?.isCancelled ?? false == false {
        handler()
      }
    }
  }
  
  func cancel() {
    isCancelled = true
  }
}
