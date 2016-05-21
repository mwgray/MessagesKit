//
//  DBManager.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/9/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "DBManager.h"

#import "WeakReference.h"
#import "DAO+Internal.h"
#import "NSMutableArray+Utils.h"
#import "NSString+Utils.h"
#import "Log.h"

#import <sqlite3.h>

@import Darwin;
@import libkern;
@import YOLOKit;
@import FMDBMigrationManager;


MK_DECLARE_LOG_LEVEL()


static NSString *DBManagerMigrationsFolder = @"Migrations";


@interface DAO (Derived)

-(instancetype) initWithDBManager:(DBManager *)dbManager;

@end



@interface DBTableInfo ()

@property (copy, nonatomic, readwrite) NSString *name;

@property (copy, nonatomic, readwrite) NSArray *fieldNames;
@property (copy, nonatomic, readwrite) NSArray *insertFieldNames;
@property (copy, nonatomic, readwrite) NSArray *updateFieldNames;

@property (copy, nonatomic, readwrite) NSNumber *idFieldIndex;
@property (copy, nonatomic, readwrite) NSNumber *typeFieldIndex;

@property (copy, nonatomic, readwrite) NSString *fetchSQL;
@property (copy, nonatomic, readwrite) NSString *fetchAllSQL;
@property (copy, nonatomic, readwrite) NSString *insertSQL;
@property (copy, nonatomic, readwrite) NSString *updateSQL;
@property (copy, nonatomic, readwrite) NSString *deleteSQL;
@property (copy, nonatomic, readwrite) NSString *deleteAllSQL;

@end




@interface DBManager () {
  NSMutableDictionary *_daos;
  NSMutableSet<WeakReference<id<DBManagerDelegate>> *> *_delegates;
  OSSpinLock _delegatesLock;
  NSMutableDictionary *_classTableNames;
}

@end


@implementation DBManager

-(instancetype) initWithPath:(NSString *)dbPath kind:(NSString *)kind daoClasses:(NSArray *)daoClasses error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
  if ((self = [super init])) {

    _daos = [NSMutableDictionary dictionary];
    _delegates = [NSMutableSet set];
    _classTableNames = [NSMutableDictionary dictionary];

    _pool = [FMDatabaseReadWritePool.alloc initWithPath:dbPath error:error];
    if (!_pool) {
      return nil;
    }

    _pool.delegate = self;

    __block BOOL initialized = NO;
    [_pool inWritableDatabase:^(FMDatabase *db) {

      db.shouldCacheStatements = YES;

      [self installFunctionsIntoDB:db];

      NSString *migrationsPath = [DBManagerMigrationsFolder stringByAppendingPathComponent:kind];

      FMDBMigrationManager *migrationManager = [FMDBMigrationManager managerWithDatabase:db
                                                                        migrationsBundle:[NSBundle bundleForClass:self.class]
                                                                              bundlePath:migrationsPath];
      if (!migrationManager.hasMigrationsTable) {

        if (![migrationManager createMigrationsTable:error]) {
          error && (*error = [NSError errorWithDomain:@"DBManagerErrorDomain" code:0 userInfo:@{NSLocalizedDescriptionKey: @"Error creating migration table"}]);
          return;
        }

      }

      if ([migrationManager.pendingVersions count] > 0) {

        DDLogInfo(@"%@ database has %lu pending migrations", kind, (unsigned long)migrationManager.pendingVersions.count);

        BOOL migrated = [migrationManager migrateDatabaseToVersion:UINT64_MAX progress:^(NSProgress *progress) {
          DDLogInfo(@"%@ database migration %lld/%lld", kind, progress.completedUnitCount, progress.totalUnitCount);
        } error:error];

        if (!migrated) {
          error && (*error = [NSError errorWithDomain:@"DBManagerErrorDomain" code:0 userInfo:@{NSLocalizedDescriptionKey: @"Database migration failed",
                                                                                                  NSUnderlyingErrorKey: *error}]);
          return;
        }

        DDLogInfo(@"%@ database migration complete", kind);
      }
      else {

        DDLogInfo(@"%@ database up-to-date", kind);
      }

      initialized = YES;
    }];
    
    if (!initialized) {
      return nil;
    }

    for (Class daoClass in daoClasses) {

      DAO *dao = [[daoClass alloc] initWithDBManager:self];

      _daos[dao.name] = dao;

      [_classTableNames addEntriesFromDictionary:dao.classTableNames];
    }
    
  }
  
  return self;
}

-(void) dealloc
{
  [self shutdown];
}

-(void) databasePool:(FMDatabaseReadWritePool *)pool didAddReaderDatabase:(FMDatabase *)database
{
  database.shouldCacheStatements = YES;

  [self installFunctionsIntoDB:database];
}

-(void) shutdown
{
  [_pool close];
  _pool = nil;
}

-(NSURL *) URL
{
  return [NSURL fileURLWithPath:_pool.path];
}

-(NSDictionary *) classTableNames
{
  return _classTableNames;
}

-(void) installFunctionsIntoDB:(FMDatabase *)db
{
  [db makeCollationNamed:@"NOCASE" encoding:NSUTF8StringEncoding withBlock:^NSComparisonResult (NSString *a, NSString *b) {
    
    // Sort NULLS last
    if (a == nil || b == nil) {
      return a ? -1 : (b ? 1 : 0);
    }

    return [a compare:b options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch];
  }];

  [db makeFunctionNamed:@"CONTAINS"
       maximumArguments:4
              withBlock:^(void *context, int argc, void **argv) {

    const char *a = (const char *)sqlite3_value_text(argv[0]);
    const char *b = (const char *)sqlite3_value_text(argv[1]);
    BOOL caseInsensitive = argc > 2 ? sqlite3_value_int(argv[2]) : NO;
    BOOL diaInsensitive = argc > 3 ? sqlite3_value_int(argv[3]) : NO;

    if (a == NULL || b == NULL) {
      sqlite3_result_int(context, a == b);
      return;
    }

    size_t alen = strlen(a);
    size_t blen = strlen(b);

    NSString *as = [[NSString alloc] initWithBytesNoCopy:(void *)a length:alen encoding:NSUTF8StringEncoding freeWhenDone:NO];
    NSString *bs = [[NSString alloc] initWithBytesNoCopy:(void *)b length:blen encoding:NSUTF8StringEncoding freeWhenDone:NO];

    NSStringCompareOptions options =
      (caseInsensitive ? NSCaseInsensitiveSearch : 0) |
      (diaInsensitive ? NSDiacriticInsensitiveSearch : 0);

    NSRange res = [as rangeOfString:bs
                            options:options
                              range:NSMakeRange(0, as.length)
                             locale:[NSLocale currentLocale]];

    sqlite3_result_int(context, res.location != NSNotFound);
  }];

  [db makeFunctionNamed:@"BEGINSWITH"
       maximumArguments:4
              withBlock:^(void *context, int argc, void **argv) {

    const char *a = (const char *)sqlite3_value_text(argv[0]);
    const char *b = (const char *)sqlite3_value_text(argv[1]);
    BOOL caseInsensitive = argc > 2 ? sqlite3_value_int(argv[2]) : NO;
    BOOL diaInsensitive = argc > 3 ? sqlite3_value_int(argv[3]) : NO;

    if (a == NULL || b == NULL) {
      sqlite3_result_int(context, a == b);
      return;
    }
    size_t alen = strlen(a);
    size_t blen = strlen(b);

    NSString *as = [[NSString alloc] initWithBytesNoCopy:(void *)a length:alen encoding:NSUTF8StringEncoding freeWhenDone:NO];
    NSString *bs = [[NSString alloc] initWithBytesNoCopy:(void *)b length:blen encoding:NSUTF8StringEncoding freeWhenDone:NO];

    NSStringCompareOptions options =
      (caseInsensitive ? NSCaseInsensitiveSearch : 0) |
      (diaInsensitive ? NSDiacriticInsensitiveSearch : 0);

    BOOL result = [as compare:bs
                      options:options
                        range:NSMakeRange(0, bs.length)
                       locale:[NSLocale currentLocale]] == NSOrderedSame;

    sqlite3_result_int(context, result);
  }];

  [db makeFunctionNamed:@"ENDSWITH"
       maximumArguments:4
              withBlock:^(void *context, int argc, void **argv) {

    const char *a = (const char *)sqlite3_value_text(argv[0]);
    const char *b = (const char *)sqlite3_value_text(argv[1]);
    BOOL caseInsensitive = argc > 2 ? sqlite3_value_int(argv[2]) : NO;
    BOOL diaInsensitive = argc > 3 ? sqlite3_value_int(argv[3]) : NO;

    if (a == NULL || b == NULL) {
      sqlite3_result_int(context, a == b);
      return;
    }

    size_t alen = strlen(a);
    size_t blen = strlen(b);

    NSString *as = [[NSString alloc] initWithBytesNoCopy:(void *)a length:alen encoding:NSUTF8StringEncoding freeWhenDone:NO];
    NSString *bs = [[NSString alloc] initWithBytesNoCopy:(void *)b length:blen encoding:NSUTF8StringEncoding freeWhenDone:NO];

    NSStringCompareOptions options =
      (caseInsensitive ? NSCaseInsensitiveSearch : 0) |
      (diaInsensitive ? NSDiacriticInsensitiveSearch : 0);

    BOOL result = [as compare:bs
                      options:options
                        range:NSMakeRange(as.length-bs.length, bs.length)
                       locale:[NSLocale currentLocale]] == NSOrderedSame;

    sqlite3_result_int(context, result);
  }];

}

-(DAO *) daoForClass:(Class)modelClass
{
  for (DAO *dao in _daos.allValues) {

    if ([dao managesClass:modelClass]) {
      return dao;
    }
  }

  return nil;
}

-(id) objectForKeyedSubscript:(NSString *)daoName
{
  return _daos[daoName];
}

-(NSUInteger) countOfDelegates
{
  return _delegates.count;
}

-(void) addDelegatesObject:(id<DBManagerDelegate>)delegate
{
  WeakReference *weakDelegate = [WeakReference weakReferenceWithValue:delegate];

  OSSpinLockLock(&_delegatesLock);
  [_delegates addObject:weakDelegate];
  OSSpinLockUnlock(&_delegatesLock);
}

-(void) removeDelegatesObject:(id<DBManagerDelegate>)delegate
{
  WeakReference *weakDelegate = [[WeakReference alloc] initWithValue:delegate track:NO];

  OSSpinLockLock(&_delegatesLock);
  [_delegates removeObject:weakDelegate];
  OSSpinLockUnlock(&_delegatesLock);
}

-(void) enumerateDelegatesWithBlock:(void (^)(id<DBManagerDelegate> delegate))block
{
  OSSpinLockLock(&_delegatesLock);
  NSSet<WeakReference<id<DBManagerDelegate>> *> *delegates = _delegates.copy;
  OSSpinLockUnlock(&_delegatesLock);

  for (WeakReference<id<DBManagerDelegate>> *delegateRef in delegates) {
    id<DBManagerDelegate> delegate = delegateRef.currentReference;
    if (delegate) {
      block(delegate);
    }
    else {
      OSSpinLockLock(&_delegatesLock);
      [_delegates removeObject:delegateRef];
      OSSpinLockUnlock(&_delegatesLock);
    }
  }
}

-(void) modelObjectsWillChangeInDAO:(DAO *)dao
{
  [self enumerateDelegatesWithBlock:^(id<DBManagerDelegate> delegate) {
    if ([delegate respondsToSelector:@selector(modelObjectsWillChangeInDAO:)]) {
      [delegate modelObjectsWillChangeInDAO:dao];
    }
  }];
}

-(void) modelObject:(Model *)model insertedInDAO:(DAO *)dao
{
  [self enumerateDelegatesWithBlock:^(id<DBManagerDelegate> delegate) {
    if ([delegate respondsToSelector:@selector(modelObject:insertedInDAO:)]) {
      [delegate modelObject:model insertedInDAO:dao];
    }
  }];
}

-(void) modelObject:(Model *)model updatedInDAO:(DAO *)dao
{
  [self enumerateDelegatesWithBlock:^(id<DBManagerDelegate> delegate) {
    if ([delegate respondsToSelector:@selector(modelObject:updatedInDAO:)]) {
      [delegate modelObject:model updatedInDAO:dao];
    }
  }];
}

-(void) modelObject:(Model *)model deletedInDAO:(DAO *)dao
{
  [self enumerateDelegatesWithBlock:^(id<DBManagerDelegate> delegate) {
    if ([delegate respondsToSelector:@selector(modelObject:deletedInDAO:)]) {
      [delegate modelObject:model deletedInDAO:dao];
    }
  }];
}

-(void) modelObjectsDidChangeInDAO:(DAO *)dao
{
  [self enumerateDelegatesWithBlock:^(id<DBManagerDelegate> delegate) {
    if ([delegate respondsToSelector:@selector(modelObjectsDidChangeInDAO:)]) {
      [delegate modelObjectsDidChangeInDAO:dao];
    }
  }];
}

@end




@implementation DBTableInfo

-(instancetype) init
{

  if ((self = [super init])) {

    _fieldNames = [NSMutableArray new];
    _insertFieldNames = [NSMutableArray new];
    _updateFieldNames = [NSMutableArray new];

  }

  return self;
}

+(DBTableInfo *) loadTableInfo:(FMDatabase *)db tableName:(NSString *)tableName
{
  __block NSMutableArray *fieldNames = [NSMutableArray new];
  __block NSMutableArray *insertFieldNames = [NSMutableArray new];
  __block NSMutableArray *updateFieldNames = [NSMutableArray new];

  __block BOOL foundId = false;
  __block int columnIndex =0;
  __block NSNumber *idFieldIndex;
  __block NSNumber *typeFieldIndex;

  NSMutableArray *pkFieldTypes = [NSMutableArray array];

  FMResultSet *tableSchema = [db getTableSchema:tableName];
  while (tableSchema.next) {

    NSString *fieldName = [tableSchema stringForColumn:@"name"];
    NSString *fieldType = [tableSchema stringForColumn:@"type"];
    int fieldPk = [tableSchema intForColumn:@"pk"];

    [fieldNames addObject:fieldName];

    if ([fieldName caseInsensitiveCompare:@"id"] == NSOrderedSame) {
      foundId = true;
      idFieldIndex = @(columnIndex);
      [insertFieldNames addObject:fieldName];
    }
    else if ([fieldName isEqualToStringCI:@"_type"] && [fieldType isEqualToStringCI:@"INTEGER"]) {
      typeFieldIndex = @(columnIndex);
      [insertFieldNames addObject:fieldName];
    }
    else {
      [updateFieldNames addObject:fieldName];
      [insertFieldNames addObject:fieldName];
    }

    if (fieldPk != 0) {
      [pkFieldTypes addObject:fieldType];
    }

    ++columnIndex;
  }

  DBTableInfo *tableInfo = [DBTableInfo new];

  tableInfo.name = tableName;

  tableInfo.fieldNames = fieldNames;
  tableInfo.insertFieldNames = insertFieldNames;
  tableInfo.updateFieldNames = updateFieldNames;

  tableInfo.idFieldIndex = idFieldIndex;
  tableInfo.typeFieldIndex = typeFieldIndex;

  // Check if the table has an explicit ID field
  if (foundId && pkFieldTypes.count == 1) {
    NSString *pkFieldType = pkFieldTypes[0];
    tableInfo.generatedId = [pkFieldType isEqualToStringCI:@"INTEGER"];
  }

  // If no explicit ID was found, raise alarm
  if (!foundId) {
    [[NSException exceptionWithName:@"DBManagerException" reason:@"ID field must be declared" userInfo:@{@"table": tableName}] raise];
  }

  if (tableInfo.generatedId) {
    [insertFieldNames removeObject:@"id"];
  }

  NSArray *insertParams = insertFieldNames.map(^id (NSString *fieldName) {
    return [@":" stringByAppendingString:fieldName];
  });

  NSArray *updateParams = updateFieldNames.map(^id (NSString *fieldName) {
    return [NSString stringWithFormat:@"%@ = :%@", fieldName, fieldName];
  });

  NSArray *fetchFieldNames = fieldNames.map(^id (NSString *fieldName) {
    return [[tableName stringByAppendingString:@"."] stringByAppendingString:fieldName];
  });

  tableInfo.fetchAllSQL = [NSString stringWithFormat:@"SELECT %@ FROM %@", [fetchFieldNames componentsJoinedByString:@", "], tableName];
  tableInfo.fetchSQL = [tableInfo.fetchAllSQL stringByAppendingString:@" WHERE id = :id"];

  tableInfo.insertSQL =
    [NSString stringWithFormat:@"INSERT INTO %@(%@) VALUES(%@)",
     tableName,
     [insertFieldNames componentsJoinedByString:@", "],
     [insertParams componentsJoinedByString:@", "]];

  tableInfo.updateSQL =
    [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE id = :id",
     tableName,
     [updateParams componentsJoinedByString:@", "]];

  tableInfo.deleteAllSQL =
    [NSString stringWithFormat:@"DELETE FROM %@", tableName];
  tableInfo.deleteSQL = [tableInfo.deleteAllSQL stringByAppendingString:@" WHERE id = ?"];

  return tableInfo;
}

-(int) findField:(NSString *)fieldName
{
  NSUInteger idx = [_fieldNames indexOfObject:fieldName];
  if (idx == NSNotFound) {
    [NSException raise:@"DBManagerException" format:@"Unable to find field named: %@", fieldName];
  }
  return (int)idx;
}

@end
