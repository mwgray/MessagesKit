//
//  Bytes.swift
//  ReTxt
//
//  Created by Kevin Wooten on 11/27/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation


public typealias Bytes = [UInt8]


func bytesFromData(data: NSData?) -> Bytes {
  guard let data = data else {
    return []
  }
  return Array(UnsafeBufferPointer(start: UnsafePointer(data.bytes), count: data.length))
}

func dataFromBytes(bytes: Bytes?) -> NSData {
  guard let bytes = bytes else {
    return NSData()
  }
  return bytes.withUnsafeBufferPointer { ptr in
    return NSData(bytes: ptr.baseAddress, length: ptr.count)
  }
}
