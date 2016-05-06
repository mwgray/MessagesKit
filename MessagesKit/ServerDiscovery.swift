//
//  ServerDiscovery.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 4/26/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation



public class ServerDiscovery : NSObject, NSNetServiceBrowserDelegate, NSNetServiceDelegate {
  
  var thread : NSThread!
  var browser : NSNetServiceBrowser!
  var services = [NSNetService]()
  let queue = dispatch_queue_create("Server Discovery", DISPATCH_QUEUE_SERIAL)
  let waitSema = dispatch_semaphore_create(0)
  let resolveSema = dispatch_semaphore_create(0)
  
  public override init() {
    super.init()
    
    browser = NSNetServiceBrowser()
    browser.delegate = self
    browser.searchForServicesOfType("_retxt._tcp.", inDomain: "local.")
    
    thread = NSThread(target: self, selector: #selector(ServerDiscovery.run), object: nil)
    thread.start()
  }
  
  public func waitForService(serviceName: String?) -> NSNetService {
    
    defer {
      thread.cancel()
    }
    
    while true {
      
      var found : NSNetService?
      dispatch_sync(queue) {
        if let index = self.services.indexOf({ $0.name == (serviceName ?? $0.name) }) {
          found = self.services[index]
        }
      }
      
      if let found = found {
        
        found.delegate = self
        found.resolveWithTimeout(5)
        
        dispatch_semaphore_wait(resolveSema, DISPATCH_TIME_FOREVER)
        
        return found
      }
      
      dispatch_semaphore_wait(waitSema, DISPATCH_TIME_FOREVER)
    }
    
  }
  
  
  func run() {
    browser.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
    NSRunLoop.currentRunLoop().run()
  }
 
  public func netServiceBrowser(browser: NSNetServiceBrowser, didFindService service: NSNetService, moreComing: Bool) {
    dispatch_sync(queue) {
      print("####################################\nFound Server: \(service.name)\n####################################")
      self.services.append(service)
      dispatch_semaphore_signal(self.waitSema)
    }
  }
  
  public func netServiceBrowser(browser: NSNetServiceBrowser, didRemoveService service: NSNetService, moreComing: Bool) {
    dispatch_sync(queue) {
      if let found = self.services.indexOf(service) {
        self.services.removeAtIndex(found)
      }
    }
  }
  
  public func netServiceDidResolveAddress(sender: NSNetService) {
    print("#### \(sender.name) @ \(sender.hostName!)")
    dispatch_semaphore_signal(resolveSema)
  }
  
  public func netService(sender: NSNetService, didNotResolve errorDict: [String : NSNumber]) {
    dispatch_semaphore_signal(resolveSema)
  }
  
}
