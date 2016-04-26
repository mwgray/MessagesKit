/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements. See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership. The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

import Foundation



public struct TBinary : MutableCollectionType, Hashable, ArrayLiteralConvertible, TSerializable {
  
  public static var thriftType : TType { return .STRING }
  
  public typealias Element = UInt8
  
  public typealias Index = Storage.Index
  
  public typealias Storage = [UInt8]
  
  public var storage = Storage()
  
  public var startIndex : Index {
    return storage.startIndex
  }
  
  public var endIndex : Index {
    return storage.endIndex
  }
  
  public subscript (position: Index) -> Element {
    get {
      return storage[position]
    }
    set {
      storage[position] = newValue
    }
  }
  
  public var hashValue : Int {
    let prime = 31
    var result = 1
    for element in storage {
      result = prime * result + element.hashValue
    }
    return result
  }
  
  public init() {
    self.storage = Storage()
  }
  
  public init(arrayLiteral elements: Element...) {
    self.storage = Storage(storage)
  }

  public init(_ data: Storage) {
    self.storage = data
  }
  
  public init(_ data: UnsafeBufferPointer<UInt8>) {
    self.storage = Storage(data)
  }
  
  public init(_ data: NSData) {
    self.storage = Storage(UnsafeBufferPointer(start: UnsafePointer(data.bytes), count: data.length))
  }
  
  public mutating func append(newElement: Element) {
    self.storage.append(newElement)
  }
  
  public mutating func appendContentsOf<C : CollectionType where C.Generator.Element == Element>(newstorage: C) {
    self.storage.appendContentsOf(newstorage)
  }
  
  public mutating func insert(newElement: Element, atIndex index: Int) {
    self.storage.insert(newElement, atIndex: index)
  }
  
  public mutating func insertContentsOf<C : CollectionType where C.Generator.Element == Element>(newElements: C, at index: Int) {
    self.storage.insertContentsOf(newElements, at: index)
  }
  
  public mutating func removeAll(keepCapacity keepCapacity: Bool = true) {
    self.storage.removeAll(keepCapacity: keepCapacity)
  }
  
  public mutating func removeAtIndex(index: Index) {
    self.storage.removeAtIndex(index)
  }
  
  public mutating func removeFirst(n: Int = 0) {
    self.storage.removeFirst(n)
  }
  
  public mutating func removeLast() -> Element {
    return self.storage.removeLast()
  }
  
  public mutating func removeRange(subRange: Range<Index>) {
    self.storage.removeRange(subRange)
  }
  
  public mutating func reserveCapacity(minimumCapacity: Int) {
    self.storage.reserveCapacity(minimumCapacity)
  }
  
  public static func readValueFromProtocol(proto: TProtocol) throws -> TBinary {
    var data : NSData?
    try proto.readBinary(&data)
    guard let validData = data else {
      throw TProtocolError.InvalidData
    }
    return TBinary(UnsafeBufferPointer(start: UnsafePointer(validData.bytes), count: validData.length))
  }
  
  public static func writeValue(value: TBinary, toProtocol proto: TProtocol) throws {
    try proto.writeBinary(NSData(bytes: value.storage, length: value.storage.count))
  }
  
}

extension TBinary : CustomStringConvertible, CustomDebugStringConvertible {
  
  public var description : String {
    return storage.description
  }
  
  public var debugDescription : String {
    return storage.debugDescription
  }
  
}

public func ==(lhs: TBinary, rhs: TBinary) -> Bool {
  return lhs.storage == rhs.storage
}
