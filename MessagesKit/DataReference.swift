//
//  DataReference.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 4/21/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation
import FMDB
import Darwin
import MobileCoreServices
 

public typealias DataReferenceFilter = (DataInputStream, DataOutputStream) throws -> Void

extension DataReference {
  
  public func temporaryDuplicate(MIMEType: String? = nil, filteredBy filter: DataReferenceFilter? = nil) throws -> DataReference {
    
    guard let filter = filter else {
      return try self.__temporaryDuplicateFilteredBy(nil, withMIMEType: MIMEType)
    }
    
    return try self.__temporaryDuplicateFilteredBy({ ins, outs, error in
      do {
        try filter(ins, outs)
        return true
      }
      catch let caughtError {
        error.memory = caughtError as NSError
        return false
      }
    }, withMIMEType: MIMEType)
  }

  public func readAllData() throws -> NSData {
    return try DataReferences.readAllDataFromReference(self)
  }
  
  public func saveToTemporaryURL() throws -> NSURL {
    return try DataReferences.saveDataReferenceToTemporaryURL(self)
  }
  
}
