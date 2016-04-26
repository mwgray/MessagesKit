//
//  URLSessionTaskOperation.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import KVOController

/**
  `URLSessionTaskOperation` is an `Operation` that translates
  an `NSURLSessionTask` into an operation.
*/
public class URLSessionTaskOperation: Operation {

  let task: NSURLSessionTask
  
  public init(task: NSURLSessionTask) {
    assert(task.state == .Suspended, "Tasks must be suspended.")

    self.task = task
    
    super.init()
  }
  
  override public func execute() {
    assert(task.state == .Suspended, "Task was resumed by something other than \(self).")

    KVOController.observe(task, keyPath: "state", options: [.New]) { [weak self] (observer, object, change) -> Void in

      guard let sself = self, task = object as? NSURLSessionTask else {
        return
      }
      
      if task.state == .Completed {
        sself.finish();
      }
      
    }
    
    task.resume()
  }
  
  override public func cancel() {
    task.cancel()
    super.cancel()
  }
  
}
