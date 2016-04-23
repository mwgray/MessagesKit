//
//  RTPersistentCache.m
//  ReTxt
//
//  Created by Kevin Wooten on 5/24/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTPersistentCache.h"

#import "NSDate+Utils.h"

@import FMDB;
@import sqlite3;


@interface RTPersistentCache<Key: id<NSCopying>, Value: id<NSCoding>> ()

@property (strong, nonatomic) Value (^loader)(Key key, NSDate **expires, NSError **error);
@property (strong, nonatomic) FMDatabaseReadWritePool *pool;

@property (assign, nonatomic) NSInteger accessCount;
@property (assign, nonatomic) NSInteger lastCompactAccessCount;

@end


static const NSInteger kRTPersistenceCacheAutoCompactAccesses = 50;


@implementation RTPersistentCache

-(instancetype) initWithName:(NSString *)name loader:(id<NSCoding> (^)(id<NSCopying> key, NSDate **expires, NSError **error))loader
{
  return [self initWithName:name loader:loader clear:NO];
}

-(instancetype) initWithName:(NSString *)name loader:(id<NSCoding> (^)(id<NSCopying> key, NSDate **expires, NSError **error))loader clear:(BOOL)clear
{
  self = [super init];
  if (self) {

    name = [name stringByAppendingString:@".cache.sqlite"];

    NSURL *cacheDirURL = [[NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *cacheURL = [cacheDirURL URLByAppendingPathComponent:name];

    if (clear) {
      [NSFileManager.defaultManager removeItemAtURL:cacheURL error:nil];
    }

    _pool = [FMDatabaseReadWritePool databasePoolWithPath:cacheURL.path];
    if (!_pool) {
      return nil;
    }

    _pool.delegate = self;

    [_pool inWritableDatabase:^(FMDatabase *db) {
      [db executeStatements:@"CREATE TABLE IF NOT EXISTS cache(key PRIMARY KEY, value, expires REAL)"];
      db.shouldCacheStatements = YES;
    }];

    _loader = loader;
  }
  return self;
}

-(void) dealloc
{
  [_pool close];
}


-(void) databasePool:(FMDatabasePool *)pool didAddReaderDatabase:(FMDatabase *)database
{
  database.shouldCacheStatements = YES;
}

-(id<NSCoding>) availableObjectForKey:(id<NSCopying>)key
{
  return [self availableObjectForKey:key expires:nil];
}

-(id<NSCoding>) availableObjectForKey:(id<NSCopying>)key expires:(NSDate **)expires
{
  __block id value;
  [_pool inReadableDatabase:^(FMDatabase *db) {

    FMResultSet *res = [db executeQuery:@"SELECT value, expires FROM cache WHERE key = ?", key];
    if ([res next]) {

      value = [res dataForColumnIndex:0];
      if (expires) {
        *expires = [res dateForColumnIndex:1];
      }

    }

    [res close];
  }];

  if (value) {
    value = [NSKeyedUnarchiver unarchiveObjectWithData:value];
  }

  return value;
}

-(id<NSCoding>) objectForKey:(id<NSCopying>)key error:(NSError *__autoreleasing *)error
{
  @synchronized(self) {

    _accessCount++;
    if (_accessCount - _lastCompactAccessCount > kRTPersistenceCacheAutoCompactAccesses) {
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self compact];
      });
    }

    NSDate *expires;
    id value = [self availableObjectForKey:key expires:&expires];

    if (value && [expires compare:NSDate.date] == NSOrderedDescending) {
      return value;
    }

    NSError *loadError;
    value = _loader(key, &expires, &loadError);
    if (loadError) {

      if (error) {
        *error = loadError;
      }

      return nil;
    }

    if (value) {
      [self _cacheValue:value forKey:key expiring:expires];
    }

    return value;
  }
}

-(void) _cacheValue:(id<NSCoding>)value forKey:(id<NSCopying>)key expiring:(NSDate *)expires
{
  value = [NSKeyedArchiver archivedDataWithRootObject:value];

  [_pool inWritableDatabase:^(FMDatabase *db) {
    [db executeUpdate:@"INSERT OR REPLACE INTO cache(key, value, expires) VALUES (?, ?, ?)", key, value, expires];
  }];
}

-(void) cacheValue:(id<NSCoding>)value forKey:(id<NSCopying>)key expiring:(NSDate *)expires
{
  @synchronized(key) {
    [self _cacheValue:value forKey:key expiring:expires];
  }
}

-(void) invalidateObjectForKey:(id<NSCopying>)key
{
  [_pool inWritableDatabase:^(FMDatabase *db) {
    [db executeUpdate:@"DELETE FROM cache WHERE key = ?", key];
  }];
}

-(void) compact
{
  _lastCompactAccessCount = _accessCount;

  [_pool inWritableDatabase:^(FMDatabase *db) {
    [db executeUpdate:@"DELETE FROM cache WHERE expires < ?", NSDate.date];
  }];
}

@end
