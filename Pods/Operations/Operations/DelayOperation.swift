//
//  DelayOperation.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation

/**
  `DelayOperation` is an `Operation` that will simply wait for a given time
  interval, or until a specific `NSDate`.

  It is important to note that this operation does **not** use the `sleep()`
  function, since that is inefficient and blocks the thread on which it is called.
  Instead, this operation uses `dispatch_after` to know when the appropriate amount
  of time has passed.

  If the interval is negative, or the `NSDate` is in the past, then this operation
  immediately finishes.
*/
public class DelayOperation: Operation {
  
  // MARK: Types
  
  private enum Delay {
    case Interval(NSTimeInterval)
    case Date(NSDate)
  }
  
  // MARK: Properties
  
  private let delay: Delay
  
  // MARK: Initialization
  
  init(interval: NSTimeInterval) {
    delay = .Interval(interval)
    super.init()
  }
  
  init(until date: NSDate) {
    delay = .Date(date)
    super.init()
  }
  
  override public func execute() {
  
    let interval: NSTimeInterval
    
    // Figure out how long we should wait for.
    switch delay {
    case .Interval(let theInterval):
      interval = theInterval
      
    case .Date(let date):
      interval = date.timeIntervalSinceNow
    }
    
    if interval < 0 {
      finish()
      return;
    }
    
    let when = dispatch_time(DISPATCH_TIME_NOW, Int64(interval * Double(NSEC_PER_SEC)))
    
    dispatch_after(when, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0)) {
      // If we were cancelled, then finish() has already been called.
      if !self.cancelled {
        self.finish()
      }
    }
    
  }
  
}
