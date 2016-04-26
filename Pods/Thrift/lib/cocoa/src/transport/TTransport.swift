//
//  TTransport.swift
//  Pods
//
//  Created by Kevin Wooten on 11/27/15.
//
//

import Foundation


extension TTransport {
  
  public func readAvail(buf: UnsafeMutablePointer<UInt8>, offset: UInt32, maxLength length: UInt32) throws -> UInt32 {
    var read = length
    try __readAvail(buf, offset: offset, length: &read)
    return read
  }
  
}
