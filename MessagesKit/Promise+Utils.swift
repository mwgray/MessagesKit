//
//  PromiseKit+Utils.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 4/22/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation



public enum WaitError : ErrorType {
  case TimeExpired
}

extension Promise where T : AnyObject {
  
  public func wait(time: dispatch_time_t = DISPATCH_TIME_FOREVER) throws -> T? {
    let sema = dispatch_semaphore_create(0)
    always {
      dispatch_semaphore_signal(sema)
    }
    
    if dispatch_semaphore_wait(sema, time) != 0 {
      throw WaitError.TimeExpired
    }
    
    if let error = error {
      throw error
    }
    
    return self.value
  }
  
}
