//
//  PersistentCache.swift
//  ReTxt
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


public class PersistentCache<KeyType, ValueType where KeyType : Equatable> {
  
  public typealias Loader = (key: KeyType) throws -> (value: ValueType, expires: NSDate)?
  
  
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
    
    let cacheURL = cacheDirURL.URLByAppendingPathComponent(".cache.sqlite")
    
    if clear {
      try NSFileManager.defaultManager().removeItemAtURL(cacheURL)
    }
    
    pool = try FMDatabaseReadWritePool(path: cacheURL.path!)
    try pool.inWritableDatabase { db in
      try db.executeStatements("CREATE TABLE IF NOT EXISTS cache(key PRIMARY KEY, value, expires REAL)")
    }
    
  }
  
  public func availableValueForKey(key: KeyType) throws -> (value: ValueType, expires: NSDate)? {
    
    return try pool.inReadableDatabase { db in
      
      guard let (value, expires) = try self.loadValueForKey(key, fromDatabase: db) else {
        return nil
      }
    
      return (value, expires)
    }
    
  }
  
  public func valueForKey(key: KeyType) throws -> ValueType? {
    
    var success : ValueType!
    
    try pool.inTransaction { db in
      
      self.accessCount += 1
      if self.accessCount - self.lastCompactAccessCount > autoCompactAccesses {
        GCD.backgroundQueue.async(self.compact)
      }
      
      if let (value, expires) = try self.loadValueForKey(key, fromDatabase: db) where expires.compare(NSDate()) == .OrderedDescending {
        success = value
        return
      }
      
      guard let (value, expires) = try self.loader(key: key) else {
        success = nil
        return
      }
      
      try self.cacheValue(value, forKey: key, expires: expires, inDatabase: db)
      
      success = value
      
      return
    }
    
    return success
  }
  
  private func loadValueForKey(key: KeyType, fromDatabase db: FMDatabase) throws -> (ValueType, NSDate)? {
    
    guard let row = db.arrayForQuery("SELECT value, expires FROM cache WHERE key = ?", key as! AnyObject) else {
      return nil
    }
    
    return (value: row[0] as! ValueType, expires: NSDate(timeIntervalSince1970: row[1] as! Double))
  }
  
  private func cacheValue(value: ValueType, forKey key: KeyType, expires: NSDate, inDatabase db: FMDatabase) throws {
    try db.executeUpdate("INSERT OR REPLACE INTO cache(key, value, expires) VALUES (?, ?, ?)", key as! AnyObject, value as! AnyObject, expires)
  }
  
  public func cacheValue(value: ValueType, forKey key: KeyType, expires: NSDate) throws {
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
