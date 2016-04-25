//
//  FMResultSet+Utils.swift
//  Messages
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation


extension FMResultSet {

  @objc public func dataReferenceForColumn(columnName: String, forOwner owner: String, usingDB db: RTDBManager) -> DataReference? {
    
    guard let data = dataForColumn(columnName) else {
      return nil
    }
    
    return dataReferenceFromData(data, owner: owner, db: db)
  }
  
  @objc public func dataReferenceForColumnIndex(columnIndex: Int32, forOwner owner: String, usingDB db: RTDBManager) -> DataReference? {
    
    guard let data = dataForColumnIndex(columnIndex) else {
      return nil
    }
    
    return dataReferenceFromData(data, owner: owner, db: db)
  }
  
  private func dataReferenceFromData(data: NSData, owner: String, db: RTDBManager) -> DataReference? {
    
    let ua = NSKeyedUnarchiver(forReadingWithData: data)
    
    let uaDelegate = DataReferenceInflater(db: db, owner: owner)
    ua.delegate = uaDelegate
    
    return ua.decodeObjectForKey(NSKeyedArchiveRootObjectKey) as? DataReference
  }
  
}


class DataReferenceDeflater: NSObject, NSKeyedUnarchiverDelegate {
  
  private let db: RTDBManager
  private let owner: String
  
  init(db: RTDBManager, owner: String) {
    self.db = db
    self.owner = owner
  }
  
  
}

class DataReferenceInflater: NSObject, NSKeyedUnarchiverDelegate {
  
  private let db: RTDBManager
  private let owner: String
  
  init(db: RTDBManager, owner: String) {
    self.db = db
    self.owner = owner
  }
  
  func unarchiver(unarchiver: NSKeyedUnarchiver, didDecodeObject object: AnyObject?) -> AnyObject? {
    
    if let blobRef = object as? BlobDataReference {
      blobRef.db = db
    }
    
    return object
  }
  
}
