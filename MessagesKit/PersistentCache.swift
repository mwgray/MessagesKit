//
//  PersistentCache.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 11/27/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import FMDB


public enum PersistentCacheError : ErrorType {
  case NoCacheDirectory
  case ErrorOpeningDB
}


private let autoCompactAccesses = 50


public protocol Persistable {
  
  static func valueToData(value: Self) throws -> NSData
  
  static func dataToValue(data: NSData) throws -> AnyObject
  
}



public class PersistentCache<KeyType, ValueType where KeyType : Equatable, ValueType : Persistable> {
  
  public typealias Loader = (key: KeyType) throws -> (value: ValueType?, expires: NSDate)?
  
  
  private var pool : FMDatabaseReadWritePool!
  
  private var accessCount : Int
  private var lastCompactAccessCount : Int
  
  private let loader : Loader
  
  public init(name: String, clear: Bool = false, loader: Loader) throws {
    self.loader = loader
    self.accessCount = 0
    self.lastCompactAccessCount = 0
    
    guard let cacheDirURL = NSFileManager.defaultManager().URLsForDirectory(.CachesDirectory, inDomains: .UserDomainMask).last else {
      throw PersistentCacheError.NoCacheDirectory
    }
    
    let cacheURL = cacheDirURL.URLByAppendingPathComponent(name).URLByAppendingPathExtension("cache.sqlite")
    
    if clear {
      do {
        try NSFileManager.defaultManager().removeItemAtURL(cacheURL)
      }
      catch let error as NSCocoaError {
        if error != NSCocoaError.FileNoSuchFileError {
          throw error
        }
      }
    }
    
    pool = try FMDatabaseReadWritePool(path: cacheURL.path!)
    try pool.inWritableDatabase { db in
      try db.executeStatements("CREATE TABLE IF NOT EXISTS cache(key PRIMARY KEY, value, expires REAL)")
    }
    
  }
  
  deinit {
    if let pool = pool {
      pool.close()
    }
  }
  
  public func availableValueForKey(key: KeyType) throws -> (value: ValueType?, expires: NSDate)? {
    
    return try pool.inReadableDatabase { db in
      
      guard let (value, expires) = try self.loadValueForKey(key, fromDatabase: db) else {
        return nil
      }
    
      return (value, expires)
    }
    
  }
  
  public func valueForKey(key: KeyType) throws -> ValueType? {
    
    return try pool.inTransaction { db in
      
      self.accessCount += 1
      if self.accessCount - self.lastCompactAccessCount > autoCompactAccesses {
        GCD.backgroundQueue.async(self.compact)
      }
      
      if let found = try self.loadValueForKey(key, fromDatabase: db) where found.1.compare(NSDate()) == .OrderedDescending {
        return found.0
      }
      
      guard let (value, expires) = try self.loader(key: key) else {
        return nil
      }
      
      try self.cacheValue(value, forKey: key, expires: expires, inDatabase: db)
      
      return value
    }
    
  }
  
  private func loadValueForKey(key: KeyType, fromDatabase db: FMDatabase) throws -> (ValueType?, NSDate)? {
    
    guard let row = db.arrayForQuery("SELECT value, expires FROM cache WHERE key = ?", key as! AnyObject) else {
      return nil
    }
    
    let valueData = row[0] as? NSData
    let value = valueData != nil ? try ValueType.dataToValue(valueData!) as? ValueType : nil
    
    let expires = row[1] as! Double
    
    return (value: value, expires: NSDate(timeIntervalSince1970: expires))
  }
  
  private func cacheValue(value: ValueType?, forKey key: KeyType, expires: NSDate, inDatabase db: FMDatabase) throws {
    
    let valueData = value != nil ? try ValueType.valueToData(value!) : NSNull()
    
    try db.executeUpdate("INSERT OR REPLACE INTO cache(key, value, expires) VALUES (?, ?, ?)", key as! AnyObject, valueData, expires)
  }
  
  public func cacheValue(value: ValueType?, forKey key: KeyType, expires: NSDate) throws {
    
    try pool.inTransaction { db in
      try self.cacheValue(value, forKey: key, expires: expires, inDatabase: db)
    }
    
  }
  
  public func invalidateValueForKey(key: KeyType) throws {
    
    try pool.inWritableDatabase { db in
      try db.executeUpdate("DELETE FROM cache WHERE key = ?", key as! AnyObject)
    }
    
  }
  
  public func compact() {
    
    lastCompactAccessCount = accessCount
    
    let _ = try? pool.inWritableDatabase { db in
      try db.executeUpdate("DELETE FROM cache WHERE expires < ?", NSDate())
    }
    
  }
  
}
