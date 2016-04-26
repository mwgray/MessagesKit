//
//  TByteArrayBuffer.swift
//  Pods
//
//  Created by Kevin Wooten on 11/27/15.
//
//

import Foundation



public class TByteArrayBuffer : NSObject, TTransport {

  
  private var _buffer : [UInt8]
  
  public var bytes : [UInt8] {
    return _buffer
  }
  
  
  public init(bytes: [UInt8] = [UInt8]()) {
    self._buffer = bytes
  }
  
  public func readAll(buf: UnsafeMutablePointer<UInt8>, offset: UInt32, length: UInt32) throws {
    if try readAvail(buf, offset: offset, maxLength: length) != length {
      throw TTransportError.EndOfFile
    }
  }
  
  @objc(readAvail:offset:length:error:)
  public func __readAvail(buf: UnsafeMutablePointer<UInt8>, offset: UInt32, length: UnsafeMutablePointer<UInt32>) throws {
    if _buffer.count == 0 {
      length.memory = 0
      return
    }
    
    let amt = min(_buffer.count, Int(length.memory))
    
    _buffer.withUnsafeBufferPointer { ptr in
      memcpy(buf, ptr.baseAddress, amt)
    }
    _buffer = Array(_buffer.dropFirst(amt))
    
    length.memory = UInt32(amt)
  }
  
  public func write(data: UnsafePointer<UInt8>, offset: UInt32, length: UInt32) throws {
    _buffer.appendContentsOf(UnsafeBufferPointer(start: data.advancedBy(Int(offset)), count: Int(length)))
  }
  
  @objc(flush:)
  public func flush() throws {
  }
  
}
