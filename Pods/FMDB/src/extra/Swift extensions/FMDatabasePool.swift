//
//  FMDatabasePool.swift
//  fmdb
//
//  Created by Kevin Wooten on 4/20/16.
//
//

import Foundation

extension FMDatabasePool {
    
    public func inReadableDatabase<T>(block: (FMDatabase) throws -> T) rethrows -> T {
        
        var success : T!
        var failure : ErrorType?
        
        inReadableDatabase { db in
            do {
                success = try block(db)
            }
            catch let inner {
                failure = inner
            }
        }
        
        if let failure = failure {
            try { throw failure }()
        }
        
        return success!
    }
    
    public func inWritableDatabase<T>(block: (FMDatabase) throws -> T) rethrows -> T {
        
        var success : T!
        var failure : ErrorType?
        
        inWritableDatabase { db in
            do {
                success = try block(db)
            }
            catch let inner {
                failure = inner
            }
        }
        
        if let failure = failure {
            try { throw failure }()
        }
        
        return success!
    }
    
    public func inTransaction<T>(deferred: Bool = false, block: (FMDatabase) throws -> T) rethrows -> T {
        
        var success : T!
        var failure : ErrorType?
        
        let box : (FMDatabase, UnsafeMutablePointer<ObjCBool>) -> Void = { db, rollback in
            do {
                success = try block(db)
                rollback.memory = false
            }
            catch let inner {
                failure = inner
                rollback.memory = true
            }
        }
        
        if deferred {
            inDeferredTransaction(box)
        }
        else {
            inTransaction(box)
        }
        
        if let failure = failure {
            try { throw failure }()
        }
        
        return success!
    }
    
}
