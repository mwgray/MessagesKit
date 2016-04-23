//
//  DataReference.swift
//  Messages
//
//  Created by Kevin Wooten on 4/21/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation
import FMDB
import Darwin
import MobileCoreServices
 

@objc public protocol DataReference : NSSecureCoding {

  func dataSize() throws -> NSNumber
  
  func openInputStream() throws -> DataInputStream
  
  func delete() throws
  
  @objc(temporaryDuplicateFilteredBy:error:)
  func __temporaryDuplicate(filteredBy filter: DataReferenceFilter?) throws -> DataReference
  
}


extension DataReference {
  
  func temporaryDuplicate(filteredBy filter: (DataInputStream, DataOutputStream) throws -> Void) throws -> DataReference {
    return try self.__temporaryDuplicate(filteredBy: { ins, outs, error in
      do {
        try filter(ins, outs)
        return true
      }
      catch let caughtError {
        error.memory = caughtError as NSError
        return false
      }
    })
  }
  
}


@objc public protocol DataInputStream {
  
  var availableBytes : UInt { get }
  
  func readBytesOfMaxLength(maxLength: UInt, intoBuffer buffer: UnsafeMutablePointer<UInt8>, bytesRead: UnsafeMutablePointer<UInt>) throws
  
}


@objc public protocol DataOutputStream {
  
  func writeBytesFromBuffer(buffer: UnsafePointer<UInt8>, length: UInt) throws
  
}


public typealias DataReferenceFilter = @convention(block) (DataInputStream, DataOutputStream, NSErrorPointer) -> Bool


@objc public class DataReferences : NSObject {
  
  public static let copyFilter : DataReferenceFilter = { (inStream, outStream, error) -> Bool in
    
    do {
      
      var buffer = [UInt8](count: 64 * 1024, repeatedValue: 0)
      
        try buffer.withUnsafeMutableBufferPointer { ptr in
          
        while true {
          
          var bytesRead : UInt = 0
          try inStream.readBytesOfMaxLength(UInt(ptr.count), intoBuffer: ptr.baseAddress, bytesRead: &bytesRead)
        
          if bytesRead == 0 {
            break
          }
        
          try outStream.writeBytesFromBuffer(ptr.baseAddress, length: UInt(ptr.count))
        }
        
      }
      
      return true
    }
    catch let caught {
      error.memory = caught as NSError
      return false
    }
    
  }
  
  public static func filterStreams(input ins: DataInputStream, output outs: DataOutputStream, using filter: DataReferenceFilter?) throws {
    
    let filter = filter != nil ? filter! : DataReferences.copyFilter
    
    var error: NSError?
    if !filter(ins, outs, &error) {
      throw error ?? NSError(domain: "DataReference", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unkown Error"])
    }
    
  }
  
  public static func filterReference(source: DataReference, intoMemoryUsing filter: DataReferenceFilter?) throws -> NSData {
    
    let ins = try source.openInputStream()
    
    let outs = NSOutputStream.outputStreamToMemory()
    outs.open()
    
    try filterStreams(input: ins, output: outs, using: filter)
    
    outs.close()
    return outs.propertyForKey(NSStreamDataWrittenToMemoryStreamKey) as! NSData
  }
  
  public static func readAllDataFromReference(source: DataReference) throws -> NSData {
    return try filterReference(source, intoMemoryUsing: copyFilter)
  }
  
}



extension NSInputStream : DataInputStream {
  
  public var availableBytes : UInt {
    return 1
  }
  
  public func readBytesOfMaxLength(maxLength: UInt, intoBuffer buffer: UnsafeMutablePointer<UInt8>, bytesRead: UnsafeMutablePointer<UInt>) throws {
    bytesRead.memory = UInt(self.read(buffer, maxLength: Int(maxLength)))
  }
  
}


extension NSOutputStream : DataOutputStream {
  
  public func writeBytesFromBuffer(buffer: UnsafePointer<UInt8>, length: UInt) throws {
    self.write(buffer, maxLength: Int(length))
  }
  
}


/*
 * MemoryDataReference
 *
 * Reference to data stored in memory
 */
@objc public class MemoryDataReference : NSObject, DataReference {
  
  private let data : NSData
  
  public static func supportsSecureCoding() -> Bool { return true }
  
  public init(data: NSData) {
    self.data = data
  }
  
  public required init?(coder aDecoder: NSCoder) {
    self.data = aDecoder.decodeObjectOfClass(NSData.self, forKey: "data")!
  }
  
  public func encodeWithCoder(aCoder: NSCoder) {
    aCoder.encodeObject(data, forKey: "data")
  }
  
  public func dataSize() throws -> NSNumber {
    return data.length
  }
  
  @objc(copyFrom:filteredBy:error:)
  public static func copyFrom(source: DataReference, filteredBy filter: DataReferenceFilter? = nil) throws -> MemoryDataReference {
    
    // Detect simple duplication and shared immutable data
    if let source = source as? MemoryDataReference where filter == nil {
      return MemoryDataReference(data: source.data)
    }
    
    let data = try DataReferences.filterReference(source, intoMemoryUsing: filter)
    
    return MemoryDataReference(data: data)
  }
  
  public func openInputStream() throws -> DataInputStream {
    return NSInputStream(data: data)
  }
  
  public func delete() throws {
  }
  
  @objc(temporaryDuplicateFilteredBy:error:)
  public func __temporaryDuplicate(filteredBy filter: DataReferenceFilter? = nil) throws -> DataReference {
    return try MemoryDataReference.copyFrom(self, filteredBy: filter)
  }
  
}




/*
 * BlobDataReference
 *
 * Reference to data stored in database blob table
 */
@objc public class BlobDataReference : NSObject, DataReference {
  
  private static let refsColumnName = "refs"
  private static let dataColumnName = "data"
  private static let typeColumnName = "type"
  
  // Populated before save and after load
  public var db : RTDBManager!
  public var owner : String!

  private let dbName : String
  private let tableName : String
  private let blobId : Int64
  
  public static func supportsSecureCoding() -> Bool { return true }
  
  public init(db: RTDBManager, owner: String, dbName: String, tableName: String, blobId: Int64) {
    self.db = db
    self.owner = owner
    self.dbName = dbName
    self.tableName = tableName
    self.blobId = blobId
  }
  
  public required init?(coder aDecoder: NSCoder) {
    self.dbName = aDecoder.decodeObjectOfClass(NSString.self, forKey: "dbName") as! String
    self.tableName = aDecoder.decodeObjectOfClass(NSString.self, forKey: "tableName") as! String
    self.blobId = aDecoder.decodeInt64ForKey("blobId")
  }
  
  public func encodeWithCoder(aCoder: NSCoder) {
    aCoder.encodeObject(dbName as NSString, forKey: "dbName")
    aCoder.encodeObject(tableName as NSString, forKey: "tableName")
    aCoder.encodeInt64(blobId, forKey: "blobId")
  }
  
  public func dataSize() throws -> NSNumber {
    
    return try db.pool.inReadableDatabase { db in
      
      guard let res = db.longForQuery("SELECT length(\(BlobDataReference.dataColumnName)) FROM \(self.tableName) WHERE rowid = ?", NSNumber(longLong: self.blobId)) else {
        throw BlobDataReferenceError.Missing
      }
      
      return NSNumber(integer: res)
    }
  }
  
  @objc(copyFrom:toOwner:forTable:inDatabase:using:filteredBy:error:)
  public static func copyFrom(source: DataReference, toOwner owner: String, forTable tableName: String, inDatabase dbName: String, using db: RTDBManager, filteredBy filter: DataReferenceFilter? = nil) throws -> BlobDataReference {
    
    // Detect simple duplication
    if let source = source as? BlobDataReference where source.isSameLocationInDatabase(dbName, andTable: tableName) && filter == nil {
      
      // Can we simply pass it through?
      if source.owner == owner {
        return source
      }
      
      // Duplicate by manipulating reference count
      try source.incrementRefs()
      return BlobDataReference(db: source.db, owner: owner, dbName: dbName, tableName: tableName, blobId: source.blobId)
    }
    
    let data = try DataReferences.filterReference(source, intoMemoryUsing: filter)

    let blobId = try db.pool.inTransaction { db -> Int64 in
      try db.executeUpdate("INSERT INTO \(tableName)(\(self.dataColumnName), \(self.refsColumnName)) VALUES (?, 1)", data)
      return db.lastInsertRowId()
    }

    return BlobDataReference(db: db, owner: owner, dbName: dbName, tableName: tableName, blobId: blobId)
  }
  
  public func openInputStream() throws -> DataInputStream {
    let blob = try db.pool.inReadableDatabase { db in
      return try FMBlob(database: db, dbName: self.dbName, tableName: self.tableName, columnName: BlobDataReference.dataColumnName, rowId: self.blobId, mode: .Read)
    }
    return BlobInputStream(blob: blob)
  }
  
  public func isSameLocationInDatabase(dbName: String, andTable tableName: String) -> Bool {
    return self.dbName == dbName && self.tableName == tableName
  }
  
  private func incrementRefs() throws {
    try db.pool.inWritableDatabase { db in
      try db.executeUpdate("UPDATE \(self.tableName) SET \(BlobDataReference.refsColumnName) = \(BlobDataReference.refsColumnName) + 1 WHERE rowid = ?", NSNumber(longLong: self.blobId))
    }
  }
  
  private func decrementRefs() throws {
    try db.pool.inTransaction { db in
      try db.executeUpdate("UPDATE \(self.tableName) SET \(BlobDataReference.refsColumnName) = \(BlobDataReference.refsColumnName) - 1 WHERE rowid = ?", NSNumber(longLong: self.blobId))
      try db.executeUpdate("DELETE FROM \(self.tableName) WHERE \(BlobDataReference.refsColumnName) < 1")
    }
  }
  
  public func delete() throws {
    try decrementRefs()
  }
  
  @objc(temporaryDuplicateFilteredBy:error:)
  public func __temporaryDuplicate(filteredBy filter: DataReferenceFilter? = nil) throws -> DataReference {
    let tempPath = NSTemporaryDirectory().stringByAppendingPathComponent(NSUUID().UUIDString)
    return try FileDataReference.copyFrom(self, toPath: tempPath, filteredBy: filter)
  }
  
}


// Errors for BlobDataReference
@objc public enum BlobDataReferenceError : Int32, ErrorType {
  case Missing
}

// Input stream for BlobDataReference
@objc public class BlobInputStream : NSObject, DataInputStream {
  
  private let blob : FMBlob
  private var offset : UInt
  
  public init(blob: FMBlob) {
    self.blob = blob
    self.offset = 0
  }
  
  deinit {
    let _ = try? close()
  }
  
  public var availableBytes : UInt {
    return blob.size - offset
  }
  
  public func readBytesOfMaxLength(maxLength: UInt, intoBuffer buffer: UnsafeMutablePointer<UInt8>, bytesRead: UnsafeMutablePointer<UInt>) throws {
    let avail = min(availableBytes, maxLength)
    try blob.readIntoBuffer(buffer, length: UInt(avail), atOffset: UInt(offset))
    offset += avail
  }
  
  public func close() throws {
    blob.close()
  }
  
}

// Output stream for BlobDataReference
@objc public class BlobOutputStream : NSObject, DataOutputStream {
  
  private let blob : FMBlob
  private var offset : UInt
  
  public init(blob: FMBlob) {
    self.blob = blob
    self.offset = 0
  }
  
  deinit {
    let _ = try? close()
  }
  
  public var availableBytes : UInt {
    return blob.size - offset
  }
  
  public func writeBytesFromBuffer(buffer: UnsafePointer<UInt8>, length: UInt) throws {
    try blob.writeFromBuffer(buffer, length: length, atOffset: offset)
    offset += length
  }
  
  public func close() throws {
    blob.close()
  }
  
}



/*
 * FileDataReference
 *
 * Reference to data stored in file
 */
@objc public class FileDataReference : NSObject, DataReference {
  
  public let path : String
  
  public var URL : NSURL {
    return NSURL(fileURLWithPath: path)
  }
  
  public static func supportsSecureCoding() -> Bool { return true }
  
  public init(path: String) {
    self.path = path
  }
  
  public required init?(coder aDecoder: NSCoder) {
    self.path = aDecoder.decodeObjectOfClass(NSString.self, forKey: "path")! as String
  }
  
  public func encodeWithCoder(aCoder: NSCoder) {
    aCoder.encodeObject(path as NSString, forKey: "path")
  }
  
  public func dataSize() throws -> NSNumber {
    return try NSFileManager.defaultManager().attributesOfItemAtPath(path)[NSFileSize] as! NSNumber
  }
  
  @objc(copyFrom:toPath:filteredBy:error:)
  public static func copyFrom(source: DataReference, toPath path: String, filteredBy filter: DataReferenceFilter? = nil) throws -> FileDataReference {
    
    // Detect simple duplication and just increment the reference count
    if let source = source as? FileDataReference where filter == nil {
      
      let ret = link(source.path, path)
      if ret != 0 {
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(ret), userInfo: [NSLocalizedDescriptionKey: "Unable to link file"])
      }
    }
    else {
      
      guard let outs = NSOutputStream(toFileAtPath: path, append: false) else {
        throw FileDataReferenceError.UnableToOpenOutputStream
      }
      
      outs.open()
      
      try DataReferences.filterStreams(input: try source.openInputStream(), output: outs, using: filter)
    }
    
    return FileDataReference(path: path)
  }
  
  public func openInputStream() throws -> DataInputStream {
    guard let ins = NSInputStream(fileAtPath: path) else {
      throw FileDataReferenceError.UnableToOpenInputStream
    }
    ins.open()
    return ins
  }
  
  public func delete() throws {
    
    let ret = unlink(path)
    if ret != 0 {
      throw NSError(domain: NSPOSIXErrorDomain, code: Int(ret), userInfo: [NSLocalizedDescriptionKey: "Unable to unlink file"])
    }
  }
  
  @objc(temporaryDuplicateFilteredBy:error:)
  public func __temporaryDuplicate(filteredBy filter: DataReferenceFilter?) throws -> DataReference {
    let tempPath = NSTemporaryDirectory().stringByAppendingPathExtension(NSUUID().UUIDString)!
    return try FileDataReference.copyFrom(self, toPath: tempPath, filteredBy: filter)
  }
  
}

// Errors for FileDataReferenceError
@objc public enum FileDataReferenceError : Int32, ErrorType {
  case UnableToOpenInputStream
  case UnableToOpenOutputStream
}
