//
//  UnboundedBlockingQueue.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 3/12/16.
//  Copyright © 2016 reTXT Labs, LLC. All rights reserved.
//

import Foundation

private class Node<T> {
  
  let value : T
  var next : Node?
  
  init(value: T, next: Node?) {
    self.value = value
    self.next = next
  }
  
}

public class UnboundedBlockingQueue<T> {
  
  private var lock = pthread_mutex_t()
  private var empty = pthread_cond_t()
  
  private var first : Node<T>?
  private var last : Node<T>?
  
  public init() {
    pthread_mutex_init(&lock, nil)
    pthread_cond_init(&empty, nil)
  }
  
  deinit {
    pthread_mutex_destroy(&lock)
    pthread_cond_destroy(&empty)
  }
  
  public func put(item: T) {
    pthread_mutex_lock(&lock)
    
    let node = Node(value: item, next: nil)
    
    if let last = last {
      last.next = node
    }
    if (first == nil) {
      first = node
    }
  
    last = node
  
    pthread_cond_signal(&empty)
    pthread_mutex_unlock(&lock)
  }
  
  public func take(timeout: Int) -> T? {
    pthread_mutex_lock(&lock)
  
    var now = timeval()
    gettimeofday(&now, nil)
  
    var ts = timespec()
    ts.tv_sec = now.tv_sec + (timeout / 1000)
    ts.tv_nsec = Int((timeout % 1000) * Int(NSEC_PER_MSEC)) + Int(now.tv_usec * Int32(NSEC_PER_USEC))
  
    while (first == nil) {
      if pthread_cond_timedwait(&empty, &lock, &ts) == ETIMEDOUT {
        pthread_mutex_unlock(&lock)
        return nil
      }
    }
  
    let item = first!.value
    first = first?.next
    
    if first == nil {
      last = nil //Empty queue
    }
  
    pthread_mutex_unlock(&lock)
  
    return item
  }
  
  public func clear() {
    pthread_mutex_lock(&lock)
    
    first = nil
    last = nil

    pthread_mutex_unlock(&lock);
  }

}
