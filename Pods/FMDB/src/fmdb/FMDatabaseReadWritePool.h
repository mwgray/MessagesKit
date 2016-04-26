//
//  FMDatabaseReadWritePool.h
//  fmdb
//
//  Created by Kevin Wooten on 6/18/14.
//  Copyright 2014 reTXT, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FMDatabase;


NS_ASSUME_NONNULL_BEGIN


/** Reader/Writer pool of `<FMDatabase>` objects.
 
 Uses SQLite's WAL mode to allow multiple readers, single writer access to a single database.

 */

@interface FMDatabaseReadWritePool : NSObject {
    NSString                *_path;

    dispatch_queue_t        _writeQueue;
    dispatch_queue_t        _lockQueue;
  
    FMDatabase              *_writerDatabase;
    NSMutableArray          *_readerDatabaseInPool;
    NSMutableArray          *_readerDatabaseOutPool;
    
    __unsafe_unretained id  _delegate;
    
    NSUInteger              _maximumNumberOfDatabasesToCreate;
    int                     _readerOpenFlags;
    int                     _writerOpenFlags;
    NSString                *_vfsName;
  
    BOOL                    _closed;
    BOOL                    _cacheConnections;
}

/** Database path */

@property (atomic, retain, nullable) NSString *path;

/** Delegate object */

@property (atomic, assign, nullable) id delegate;

/** Maximum number of databases to create */

@property (atomic, assign) NSUInteger maximumNumberOfDatabasesToCreate;

/** Open flags (for reader databases) */

@property (atomic, readonly) int readerOpenFlags;

/** Open flags (for writer database) */

@property (atomic, readonly) int writerOpenFlags;

/**  Custom virtual file system name */

@property (atomic, copy, nullable) NSString *vfsName;

/** Enabled/disable connection caching */

@property (atomic, assign) BOOL cacheConnections;

///---------------------
/// @name Initialization
///---------------------

/** Create pool using path.

 @param aPath The file path of the database.

 @return The `FMDatabaseReadWritePool` object. `nil` on error.
 */

+ (nullable instancetype)databasePoolWithPath:(nullable NSString*)aPath;
+ (nullable instancetype)databasePoolWithPath:(nullable NSString*)aPath error:(NSError **)error;

/** Create pool using path and specified flags
 
 @param aPath The file path of the database.
 @param openFlags Flags passed to the openWithFlags method of the database
 
 @return The `FMDatabaseReadWritePool` object. `nil` on error.
 */

+ (nullable instancetype)databasePoolWithPath:(nullable NSString*)aPath flags:(int)openFlags;
+ (nullable instancetype)databasePoolWithPath:(nullable NSString*)aPath flags:(int)openFlags error:(NSError **)error;

/** Create pool using path and specified flags
 
 @param aPath The file path of the database.
 @param openFlags Flags passed to the openWithFlags method of the database
 @param vfsName The name of a custom virtual file system
 
 @return The `FMDatabaseReadWritePool` object. `nil` on error.
 */

+ (nullable instancetype)databasePoolWithPath:(nullable NSString*)aPath flags:(int)openFlags vfs:(nullable NSString *)vfsName;
+ (nullable instancetype)databasePoolWithPath:(nullable NSString*)aPath flags:(int)openFlags vfs:(nullable NSString *)vfsName error:(NSError **)error;

/** Create pool using path.

 @param aPath The file path of the database.

 @return The `FMDatabaseReadWritePool` object. `nil` on error.
 */

- (nullable instancetype)initWithPath:(nullable NSString*)aPath error:(NSError **)error;

/** Create pool using path and specified flags.

 @param aPath The file path of the database.
 @param openFlags Flags passed to the openWithFlags method of the database

 @return The `FMDatabaseReadWritePool` object. `nil` on error.
 */

- (nullable instancetype)initWithPath:(nullable NSString*)aPath flags:(int)openFlags error:(NSError **)error;

/** Create pool using path and specified flags.

 @param aPath The file path of the database.
 @param openFlags Flags passed to the openWithFlags method of the database
 @param vfsName The name of a custom virtual file system

 @return The `FMDatabaseReadWritePool` object. `nil` on error.
 */

- (nullable instancetype)initWithPath:(nullable NSString*)aPath flags:(int)openFlags vfs:(nullable NSString *)vfsName error:(NSError **)error;

/** Returns the Class of 'FMDatabase' subclass, that will be used to instantiate database object.

 Subclasses can override this method to return specified Class of 'FMDatabase' subclass.

 @return The Class of 'FMDatabase' subclass, that will be used to instantiate database object.
 */

+ (Class)databaseClass;

///------------------------------------------------
/// @name Keeping track of checked in/out databases
///------------------------------------------------

/** Number of checked-in databases in pool
 
 @returns Number of databases
 */

- (NSUInteger)countOfCheckedInReadableDatabases;

/** Number of checked-out databases in pool

 @returns Number of databases
 */

- (NSUInteger)countOfCheckedOutReadableDatabases;

/** Total number of databases in pool

 @returns Number of databases
 */

- (NSUInteger)countOfOpenDatabases;

/** Release all databases in pool */

- (void)releaseAllDatabases;

///------------------------------------------
/// @name Perform database operations in pool
///------------------------------------------

/** Synchronously perform readable database operations in pool.
 
 @param block The code to be run on the `FMDatabaseReadWritePool` pool.
 */

- (void)inReadableDatabase:(void (^)(FMDatabase *db))block;

/** Synchronously perform writable database operations in pool.
 
 @param block The code to be run on the `FMDatabaseReadWritePool` pool.
 */

- (void)inWritableDatabase:(void (^)(FMDatabase *db))block;

/** Synchronously perform database operations in pool using transaction.

 @param block The code to be run on the `FMDatabaseReadWritePool` pool.
 */

- (void)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block;

/** Synchronously perform database operations in pool using deferred transaction.

 @param block The code to be run on the `FMDatabaseReadWritePool` pool.
 */

- (void)inDeferredTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block;

/** Synchronously perform database operations in pool using save point.

 @param block The code to be run on the `FMDatabaseReadWritePool` pool.
 
 @return `NSError` object if error; `nil` if successful.

 @warning You can not nest these, since calling it will pull another database out of the pool and you'll get a deadlock. If you need to nest, use `<[FMDatabase startSavePointWithName:error:]>` instead.
*/

- (NSError*)inSavePoint:(void (^)(FMDatabase *db, BOOL *rollback))block;


- (void) close;

@end


/** FMDatabaseReadWritePool delegate category
 
 This is a category that defines the protocol for the FMDatabaseReadWritePool delegate
 */

@interface NSObject (FMDatabaseReadWritePoolDelegate)

/** Asks the delegate whether database should be added to the pool. 
 
 @param pool     The `FMDatabaseReadWritePool` object.
 @param database The `FMDatabase` object.
 
 @return `YES` if it should add database to pool; `NO` if not.
 
 */

- (BOOL)databasePool:(FMDatabaseReadWritePool*)pool shouldAddReaderDatabase:(FMDatabase*)database;

/** Tells the delegate that database was added to the pool.
 
 @param pool     The `FMDatabaseReadWritePool` object.
 @param database The `FMDatabase` object.

 */

- (void)databasePool:(FMDatabaseReadWritePool*)pool didAddReaderDatabase:(FMDatabase*)database;

@end


NS_ASSUME_NONNULL_END
