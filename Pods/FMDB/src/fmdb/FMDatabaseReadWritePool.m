//
//  FMDatabaseReadWritePool.m
//  fmdb
//
//  Created by Kevin Wooten on 6/18/14.
//  Copyright 2014 reTXT, Inc. All rights reserved.
//

#if FMDB_SQLITE_STANDALONE
#import <sqlite3/sqlite3.h>
#else
#import <sqlite3.h>
#endif

#import "FMDatabaseReadWritePool.h"
#import "FMDatabase.h"


@interface FMDatabaseReadWritePool()

- (FMDatabase*)acquireReadableDB;
- (void)releaseReadableDB:(FMDatabase*)db;

- (FMDatabase*)acquireWritableDB;

@end


static NSString *const FMDatabaseReadWritePoolDefaultVFS = @"unix";
static const int FMDatabaseReadWritePoolDefaultOpenFlags = SQLITE_OPEN_NOMUTEX;


/*
 * A key used to associate the FMDatabaseReadWritePool object with the dispatch_queue_t it uses.
 * This in turn is used to allow reentrency in writable requests.
 */
static const void * const kDispatchPoolSpecificKey = &kDispatchPoolSpecificKey;


@implementation FMDatabaseReadWritePool
@synthesize path=_path;
@synthesize delegate=_delegate;
@synthesize maximumNumberOfDatabasesToCreate=_maximumNumberOfDatabasesToCreate;
@synthesize readerOpenFlags=_readerOpenFlags;
@synthesize writerOpenFlags=_writerOpenFlags;
@synthesize vfsName=_vfsName;
@synthesize cacheConnections=_cacheConnections;


+ (instancetype)databasePoolWithPath:(NSString*)aPath  {
    return FMDBReturnAutoreleased([[self alloc] initWithPath:aPath error:nil]);
}

+ (instancetype)databasePoolWithPath:(NSString*)aPath error:(NSError **)error  {
    return FMDBReturnAutoreleased([[self alloc] initWithPath:aPath error:error]);
}

+ (instancetype)databasePoolWithPath:(NSString*)aPath flags:(int)openFlags {
    return FMDBReturnAutoreleased([[self alloc] initWithPath:aPath flags:openFlags error:nil]);
}

+ (instancetype)databasePoolWithPath:(NSString*)aPath flags:(int)openFlags error:(NSError **)error {
    return FMDBReturnAutoreleased([[self alloc] initWithPath:aPath flags:openFlags error:error]);
}

+ (instancetype)databasePoolWithPath:(NSString*)aPath flags:(int)openFlags vfs:(NSString *)vfsName {
    return FMDBReturnAutoreleased([[self alloc] initWithPath:aPath flags:openFlags vfs:vfsName error:nil]);
}

+ (instancetype)databasePoolWithPath:(NSString*)aPath flags:(int)openFlags vfs:(NSString *)vfsName error:(NSError **)error {
    return FMDBReturnAutoreleased([[self alloc] initWithPath:aPath flags:openFlags vfs:vfsName error:error]);
}

- (instancetype)initWithPath:(NSString*)aPath flags:(int)openFlags vfs:(NSString *)vfsName error:(NSError **)error {
    
    openFlags &= ~(SQLITE_OPEN_CREATE | SQLITE_OPEN_READONLY | SQLITE_OPEN_READWRITE);
    
    self = [super init];
    
    if (self != nil) {
        _path                   = [aPath copy];
        _writeQueue             = dispatch_queue_create([[NSString stringWithFormat:@"fmdb.pool.write.%@", self] UTF8String], DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_writeQueue, kDispatchPoolSpecificKey, (__bridge void *)self, NULL);
        _lockQueue              = dispatch_queue_create([[NSString stringWithFormat:@"fmdb.pool.lock.%@", self] UTF8String], DISPATCH_QUEUE_SERIAL);
        _writerDatabase         = FMDBReturnRetained([FMDatabase databaseWithPath:aPath]);
        _readerDatabaseInPool   = FMDBReturnRetained([NSMutableArray array]);
        _readerDatabaseOutPool  = FMDBReturnRetained([NSMutableArray array]);
        _readerOpenFlags        = openFlags | FMDatabaseReadWritePoolDefaultOpenFlags | SQLITE_OPEN_READONLY | SQLITE_OPEN_WAL;
        _writerOpenFlags        = openFlags | FMDatabaseReadWritePoolDefaultOpenFlags | SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_WAL;
        _vfsName                = [vfsName copy];
        _cacheConnections       = YES;
      
        __block BOOL valid = NO;
        [self inWritableDatabase:^(FMDatabase * _Nonnull db) {
            valid = [db executeStatements:@"PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL;"
                                    error:error];
        }];
      
        if (!valid) {
            return nil;
        }
    }
    
    return self;
}

- (instancetype)initWithPath:(NSString*)aPath flags:(int)openFlags error:(NSError **)error {
    return [self initWithPath:aPath flags:openFlags vfs:nil error:error];
}

- (instancetype)initWithPath:(NSString*)aPath error:(NSError **)error
{
    // default flags for sqlite3_open
    return [self initWithPath:aPath flags:0 error:error];
}

- (instancetype)init {
    return [self initWithPath:nil error:nil];
}

+ (Class)databaseClass {
    return [FMDatabase class];
}

- (void)dealloc {
  
    [self close];
  
    self->_delegate = 0x00;
    FMDBRelease(self->_path);
    FMDBRelease(self->_writerDatabase);
    FMDBRelease(self->_readerDatabaseInPool);
    FMDBRelease(self->_readerDatabaseOutPool);
  
    if (_writeQueue) {
        FMDBDispatchQueueRelease(_writeQueue);
        _writeQueue = 0x00;
    }
    if (_lockQueue) {
        FMDBDispatchQueueRelease(_lockQueue);
        _lockQueue = 0x00;
    }
#if ! __has_feature(objc_arc)
    [super dealloc];
#endif
}

-(void) close
{
    if (_closed) {
      return;
    }
  
    _closed = YES;
  
    [self releaseAllDatabases];
  
    dispatch_barrier_sync(_writeQueue, ^{
      
        [_writerDatabase close];
      
    });
}

/** Acquires a readable database from the pool
 *
 * Ensurese synchronized access to pool structures
 * using a serial queue.
 */
- (FMDatabase*)acquireWritableDB {

    if (_closed) {
        return nil;
    }
  
    if (![_writerDatabase openWithFlags:self->_writerOpenFlags vfs:self->_vfsName]) {
        NSLog(@"Could not open up the writable database at path %@", self->_path);
        return nil;
    }
  
    return _writerDatabase;
}

/** Acquires a readable database from the pool
 *
 * Ensurese synchronized access to pool structures
 * using a serial queue.
 */
- (FMDatabase*)acquireReadableDB {
    
    if (_closed) {
        return nil;
    }
    
    __block FMDatabase *db;
  
    dispatch_sync(_lockQueue, ^{
      
        db = [self->_readerDatabaseInPool lastObject];
        
        if (!db) {
            
            if (self->_maximumNumberOfDatabasesToCreate) {
                NSUInteger currentCount = [self->_readerDatabaseOutPool count] + [self->_readerDatabaseInPool count];
                
                if (currentCount >= self->_maximumNumberOfDatabasesToCreate) {
                    NSLog(@"Maximum number of databases (%ld) has already been reached!", (long)currentCount);
                    return;
                }
            }
            
            db = [[[self class] databaseClass] databaseWithPath:self->_path];
        }

        __block BOOL success;
        
        dispatch_sync(_writeQueue, ^{
            //This ensures that the db is opened before returning
#if SQLITE_VERSION_NUMBER >= 3005000
            success = [db openWithFlags:self->_readerOpenFlags vfs:self->_vfsName];
#else
            success = [db open];
#endif
        });
        
        if (success) {
            
            BOOL newDB = ![self->_readerDatabaseInPool containsObject:db];
            
            BOOL allowed = YES;
            if (newDB && [self->_delegate respondsToSelector:@selector(databasePool:shouldAddReaderDatabase:)]) {
                allowed = [self->_delegate databasePool:self shouldAddReaderDatabase:db];
            }

            if (!allowed) {
                
                [db close];
                db = 0x00;
                
            }
            else {
                
                [self->_readerDatabaseOutPool addObject:db];
                [self->_readerDatabaseInPool removeLastObject];
                
                if (newDB && [self->_delegate respondsToSelector:@selector(databasePool:didAddReaderDatabase:)]) {
                    [self->_delegate databasePool:self didAddReaderDatabase:db];
                }
                
            }
        }
        else {
            NSLog(@"Could not open up a readable database at path %@", self->_path);
            db = 0x00;
        }
        
    });
    
    return db;
}

- (void)releaseReadableDB:(FMDatabase *)db {
  
    if (!db) { // db can be null if we set an upper bound on the # of databases to create.
        return;
    }
  
    dispatch_sync(_lockQueue, ^{
        
        if (!_cacheConnections) {
            dispatch_sync(_writeQueue, ^{
                [db close];
            });
            [self->_readerDatabaseOutPool removeObject:db];
            return;
        }
    
        if ([self->_readerDatabaseInPool containsObject:db]) {
            [[NSException exceptionWithName:@"Database already in pool" reason:@"The FMDatabase being put back into the pool is already present in the pool" userInfo:nil] raise];
        }
    
        [self->_readerDatabaseInPool addObject:db];
        [self->_readerDatabaseOutPool removeObject:db];
    
    });
}

- (NSUInteger)countOfCheckedInReadableDatabases {
  
    __block NSUInteger count;
  
    dispatch_sync(_lockQueue, ^{
        count = [self->_readerDatabaseInPool count];
    });
  
    return count;
}

- (NSUInteger)countOfCheckedOutReadableDatabases {
  
    __block NSUInteger count;
    
    dispatch_sync(_lockQueue, ^{
        count = [self->_readerDatabaseOutPool count];
    });
    
    return count;
}

- (NSUInteger)countOfOpenDatabases {
  
    __block NSUInteger count;
    
    dispatch_sync(_lockQueue, ^{
        count = [self->_readerDatabaseOutPool count] + [self->_readerDatabaseInPool count] + 1;
    });
    
    return count;
}

- (void)releaseAllDatabases {
  
    dispatch_sync(_lockQueue, ^{
        [self->_readerDatabaseOutPool enumerateObjectsUsingBlock:^(FMDatabase *db, NSUInteger idx, BOOL *stop) {
            [db close];
        }];
        [self->_readerDatabaseOutPool removeAllObjects];
        
        [self->_readerDatabaseInPool enumerateObjectsUsingBlock:^(FMDatabase *db, NSUInteger idx, BOOL *stop) {
            [db close];
        }];
        [self->_readerDatabaseInPool removeAllObjects];
    });
}

- (void)inReadableDatabase:(void (^)(FMDatabase *db))block {
  
    FMDatabase *db = [self acquireReadableDB];
    if (!db) {
        return;
    }
  
    block(db);
  
    [self releaseReadableDB:db];

}

- (void)inWritableDatabase:(void (^)(FMDatabase *db))block {
  
    FMDatabase *db = [self acquireWritableDB];
    if (!db) {
        return;
    }
  
    FMDatabaseReadWritePool *currentPool = (__bridge id)dispatch_get_specific(kDispatchPoolSpecificKey);
    if (currentPool == self) {
      
        block(db);
      
        return;
    }
  
    FMDBRetain(self);
  
    dispatch_sync(_writeQueue, ^{
      
        block(db);
    
    });
  
    FMDBRelease(self);  
}

- (void)beginTransaction:(BOOL)useDeferred withBlock:(void (^)(FMDatabase *db, BOOL *rollback))block {
  
  FMDatabaseReadWritePool *currentPool = (__bridge id)dispatch_get_specific(kDispatchPoolSpecificKey);
#if SQLITE_VERSION_NUMBER >= 3007000
    if (currentPool == self) {
      
        [self inSavePointImmediate:block];
     
        return;
    }
#else
    /* Check current pool against self to make sure we're not about to deadlock. */
    assert(currentPool != self && "beginTransaction: was called reentrantly on the same queue, which would lead to a deadlock; need save points for this to work");
#endif

    FMDBRetain(self);
  
    FMDatabase *db = [self acquireWritableDB];
    if (!db) {
        return;
    }
  
    dispatch_sync(_writeQueue, ^{
      
        BOOL shouldRollback = NO;
      
        if (useDeferred) {
            [db beginDeferredTransaction];
        }
        else {
            [db beginTransaction];
        }
        
        
        block(db, &shouldRollback);
        
        if (shouldRollback) {
            [db rollback];
        }
        else {
            [db commit];
        }
      
    });
  
  FMDBRelease(self);
}

- (void)inDeferredTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block {
    [self beginTransaction:YES withBlock:block];
}

- (void)inTransaction:(void (^)(FMDatabase *db, BOOL *rollback))block {
    [self beginTransaction:NO withBlock:block];
}

- (NSError*)inSavePointImmediate:(void (^)(FMDatabase *db, BOOL *rollback))block {

    FMDatabase *db = [self acquireWritableDB];
    if (!db) {
        return nil;
    }
    
    NSError *error =[db inSavePoint:^(BOOL *shouldRollbackSavePoint){
        
        block(db, shouldRollbackSavePoint);
        
    }];
    
    return error;
}

- (NSError*)inSavePoint:(void (^)(FMDatabase *db, BOOL *rollback))block {
#if SQLITE_VERSION_NUMBER >= 3007000
    
    __block NSError *err = 0x00;

    FMDatabaseReadWritePool *currentPool = (__bridge id)dispatch_get_specific(kDispatchPoolSpecificKey);
    if (currentPool == self) {
      
        return [self inSavePointImmediate:block];
      
    }
  
    dispatch_sync(_writeQueue, ^{
        
        err = [self inSavePointImmediate:block];
      
    });
  
    return err;
#else
    NSString *errorMessage = NSLocalizedString(@"Save point functions require SQLite 3.7", nil);
    if (self.logsErrors) NSLog(@"%@", errorMessage);
    return [NSError errorWithDomain:@"FMDatabase" code:0 userInfo:@{NSLocalizedDescriptionKey : errorMessage}];
#endif
}

@end
