//
//  RTDAO.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTDAO+Internal.h"

#import "RTSQLBuilder.h"
#import "RTCache.h"
#import "RTMessages+Exts.h"
#import "RTLog.h"


RT_LUMBERJACK_DECLARE_LOG_LEVEL()


@interface RTDAO () {
  RTDBTableInfo *_tableInfo;
  Class _rootClass;
  NSArray *_derivedClasses;
  NSCache *_objectCache;

  NSMutableDictionary *_loadCache;
  NSMutableDictionary *_classTableNames;
}

@end


@implementation RTDAO

@dynamic name;

-(instancetype) initWithDBManager:(RTDBManager *)dbManager
                        tableInfo:(RTDBTableInfo *)tableInfo
                        rootClass:(Class)rootClass
                   derivedClasses:(NSArray *)derivedClasses
{

  if ((self = [super init])) {

    _dbManager = dbManager;
    _tableInfo = tableInfo;
    _rootClass = rootClass;
    _derivedClasses = derivedClasses;
    _objectCache = [RTCache new];
    _objectCache.countLimit = 512;
    _loadCache = [NSMutableDictionary new];

    _classTableNames = [NSMutableDictionary dictionary];
    _classTableNames[NSStringFromClass(rootClass)] = tableInfo.name;
    for (Class derivedClass in derivedClasses) {
      _classTableNames[NSStringFromClass(derivedClass)] = tableInfo.name;
    }
  }

  return self;
}

-(BOOL) managesClass:(Class)modelClass
{
  if (modelClass == _rootClass) {
    return YES;
  }

  return [_derivedClasses containsObject:modelClass];
}

-(NSDictionary *) classTableNames
{
  return _classTableNames;
}

-(NSCache *) objectCache
{
  return _objectCache;
}

-(RTModel *) loadFrom:(FMResultSet *)resultSet withId:(id)objId error:(NSError **)error
{
  Class derivedClass;

  if (!_tableInfo.typeFieldIndex) {
    derivedClass = _rootClass;
  }
  else {
    int derivedType = [resultSet intForColumnIndex:_tableInfo.typeFieldIndex.intValue];
    derivedClass = _derivedClasses[derivedType];
  }

  RTModel *obj = [derivedClass new];

  [_loadCache setObject:obj forKey:objId];

  if (![obj load:resultSet dao:self error:error]) {
    return nil;
  }

  [_loadCache removeObjectForKey:obj];

  [_objectCache setObject:obj forKey:objId];

  return obj;
}

-(RTModel *) load:(FMResultSet *)resultSet error:(NSError **)error
{
  id objId = [resultSet objectForColumnIndex:_tableInfo.idFieldIndex.intValue];

  // 1st - check cache
  //
  id obj = [_objectCache objectForKey:objId];
  if (obj) {
    return obj;
  }

  // 2nd - check load cache (never purged automatically)
  //
  obj = [_loadCache objectForKey:objId];
  if (obj) {
    return obj;
  }

  return [self loadFrom:resultSet withId:objId error:error];
}

-(NSArray *) loadAll:(FMResultSet *)resultSet error:(NSError **)error
{
  NSMutableArray *results = [NSMutableArray array];

  while ([resultSet next]) {
    
    RTModel *model = [self load:resultSet error:error];
    if (!model) {
      return nil;
    }
    
    [results addObject:model];
  }

  return results;
}

-(NSMutableDictionary *) save:(RTModel *)model error:(NSError **)error
{
  NSMutableDictionary *values = [NSMutableDictionary dictionaryWithCapacity:_tableInfo.fieldNames.count];
  for (NSString *fieldName in _tableInfo.fieldNames) {
    values[fieldName] = NSNull.null;
  }

  if(![model save:values dao:self error:error]) {
    return nil;
  }

  if (_derivedClasses.count > 0) {
    NSUInteger derivedClassIdx = [_derivedClasses indexOfObject:[model class]];
    [values setObject:@(derivedClassIdx) forKey:_tableInfo.fieldNames[_tableInfo.typeFieldIndex.intValue]];
  }

  return values;
}

-(id) dbIdForId:(id)modelId
{
  return modelId;
}

-(__kindof RTModel * _Nullable)fetchObjectWithId:(id)id {
  
  NSError *error = nil;
  RTModel *model = nil;
  
  if (![self fetchObjectWithId:id returning:&model error:&error]) {
    DDLogError(@"Error fetching object with id %@", id);
    return nil;
  }
  
  return model;
}

-(BOOL)fetchObjectWithId:(RTId *)modelId returning:(RTModel * _Nullable __autoreleasing *)model error:(NSError * _Nullable __autoreleasing *)error
{
  if (!modelId || modelId.isNull || [modelId isKindOfClass:NSNull.class]) {
    if (error) {
      *error = [NSError errorWithDomain:@"RTDAOError" code:0 userInfo:@{NSLocalizedDescriptionKey: @"Attempt to load object for null or nil id"}];
    }
    return NO;
  }
  
  id dbId = [self dbIdForId:modelId];

  id cached = [_objectCache objectForKey:dbId];
  if (cached) {
    *model = cached;
    return YES;
  }

  __block BOOL res = NO;
  *model = nil;

  [_dbManager.pool inReadableDatabase:^(FMDatabase *db) {

    FMResultSet *resultSet = [db executeQuery:_tableInfo.fetchSQL valuesArray:@[dbId] error:error];
    if (!resultSet) {
      return;
    }

    BOOL found = NO;
    if (!(res = [resultSet nextReturning:&found error:error])) {
      return;
    }
    
    if (found) {
      RTModel *loaded = [self load:resultSet error:error];
      res = loaded ? YES : NO;
      *model = loaded;
    }

    [resultSet close];
  }];
  
  return res;
}

-(NSArray *) fetchAllObjectsMatching:(NSString *)where error:(NSError **)error
{
  return [self fetchAllObjectsMatching:where parameters:@[] error:error];
}

-(NSArray *) fetchAllObjectsMatching:(NSString *)where parameters:(NSArray *)parameters error:(NSError **)error
{
  NSString *sql = _tableInfo.fetchAllSQL;
  if (where) {
    sql = [sql stringByAppendingFormat:@" WHERE %@", where];
  }

  __block NSArray *res;

  [_dbManager.pool inReadableDatabase:^(FMDatabase *db) {

    FMResultSet *resultSet = [db executeQuery:sql withArgumentsInArray:parameters];

    res = [self loadAll:resultSet error:error];

    [resultSet close];
  }];

  return res;
}

-(NSArray *) fetchAllObjectsMatching:(NSString *)where parametersNamed:(NSDictionary *)parameters error:(NSError **)error
{
  NSString *sql = _tableInfo.fetchAllSQL;
  if (where) {
    sql = [sql stringByAppendingFormat:@" WHERE %@", where];
  }

  __block NSArray *res;

  [_dbManager.pool inReadableDatabase:^(FMDatabase *db) {

    FMResultSet *resultSet = [db executeQuery:sql withParameterDictionary:parameters];

    res = [self loadAll:resultSet error:error];

    [resultSet close];
  }];

  return res;
}

-(NSArray *) fetchAllObjectsMatching:(NSPredicate *)predicate offset:(NSUInteger)offset limit:(NSUInteger)limit sortedBy:(NSArray *)sortDescriptors error:(NSError **)error
{
  RTSQLBuilder *sqlBuilder = [[RTSQLBuilder alloc] initWithRootClass:NSStringFromClass(_rootClass)
                                                          tableNames:_dbManager.classTableNames];

  sqlBuilder.selectFields = @"*";

  NSString *sql = [sqlBuilder processPredicate:predicate
                                      sortedBy:sortDescriptors
                                        offset:offset
                                         limit:limit];

  __block NSArray *res;

  [_dbManager.pool inReadableDatabase:^(FMDatabase *db) {

    FMResultSet *resultSet = [db executeQuery:sql withParameterDictionary:sqlBuilder.parameters];

    res = [self loadAll:resultSet error:error];

    [resultSet close];
  }];

  return res;
}

-(BOOL) insertObject:(RTModel *)model error:(NSError **)error
{
  NSMutableDictionary *values = [self save:model error:error];
  if (!values) {
    return NO;
  }
  
  if (self.tableInfo.generatedId) {
    [values removeObjectForKey:@"id"];
  }

  __block BOOL inserted = NO;

  [_dbManager.pool inWritableDatabase:^(FMDatabase *db) {

    if ([db executeUpdate:_tableInfo.insertSQL withParameterDictionary:values]) {

      if ((inserted = db.changes > 0)) {

        if (_tableInfo.generatedId) {
          model.dbId = @(db.lastInsertRowId);
        }
        else {
          inserted = model.dbId != nil;
        }

      }

    }
  }];

  if (inserted) {

    [_objectCache setObject:model forKey:model.dbId];

    [self inserted:model];
  }

  return inserted;
}

-(BOOL) updateObject:(RTModel *)model error:(NSError **)error
{
  NSMutableDictionary *values = [self save:model error:error];
  if (!values) {
    return NO;
  }
  
  [values removeObjectForKey:@"_type"];

  __block BOOL updated = NO;

  [_dbManager.pool inWritableDatabase:^(FMDatabase *db) {

    if ([db executeUpdate:_tableInfo.updateSQL withParameterDictionary:values]) {

      updated = db.changes > 0;
    }

  }];

  if (updated) {

    [_objectCache setObject:model forKey:model.dbId];

    [self updated:model];
  }

  return updated;
}

-(BOOL) upsertObject:(RTModel *)model error:(NSError **)error
{
  NSMutableDictionary *allValues = [self save:model error:error];
  if (!allValues) {
    return NO;
  }

  __block BOOL updated = NO, inserted = NO;

  [_dbManager.pool inTransaction:^(FMDatabase *db, BOOL *rollback) {

    NSMutableDictionary *updateValues = [allValues mutableCopy];
    [updateValues removeObjectForKey:@"_type"];

    if (![db executeUpdate:_tableInfo.updateSQL withParameterDictionary:updateValues] || db.changes == 0) {
      
      if (_tableInfo.generatedId) {
        [allValues removeObjectForKey:@"id"];
      }
      
      if ([db executeUpdate:_tableInfo.insertSQL withParameterDictionary:allValues]) {

        if ((inserted = db.changes > 0)) {

          if (_tableInfo.generatedId) {
            model.dbId = @(db.lastInsertRowId);
          }
          else {
            inserted = model.dbId != nil;
          }
        }
      }

    }
    else {

      updated = YES;
    }

  }];

  if (updated || inserted) {

    [_objectCache setObject:model forKey:model.dbId];
  }

  if (updated) {
    [self updated:model];
  }
  if (inserted) {
    [self inserted:model];
  }

  return updated || inserted;
}

-(BOOL) deleteObject:(RTModel *)model error:(NSError **)error
{
  __block BOOL deleted = NO;

  [_dbManager.pool inWritableDatabase:^(FMDatabase *db) {

    if ([db executeUpdate:_tableInfo.deleteSQL, model.dbId]) {

      if (![model deleteWithDAO:self error:error]) {
        return;
      }

      deleted = db.changes > 0;
    }

  }];

  if (deleted) {

    [_objectCache removeObjectForKey:model.dbId];

    [self deleted:model];
  }

  return deleted;
}

-(BOOL) deleteAllObjectsInArray:(NSArray *)models error:(NSError **)error
{

  __block int count =0;

  [_dbManager.pool inTransaction:^(FMDatabase *db, BOOL *rollback) {

    for (RTModel *model in models) {

      if (![self deleteObject:model error:error]) {
        *rollback = YES;
        count = 0;
        return;
      }
      
      ++count;
    }

  }];

  return count != 0;
}

-(BOOL) deleteAllObjectsAndReturnError:(NSError **)error
{

  __block int count=0;

  [_dbManager.pool inWritableDatabase:^(FMDatabase *db) {

    if (![db executeUpdate:_tableInfo.deleteAllSQL valuesArray:nil error:error]) {
      return;
    }

    count = db.changes;

  }];

  [_objectCache removeAllObjects];

  return count;
}

-(BOOL) deleteAllObjectsMatching:(NSString *)where error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
  return [self deleteAllObjectsMatching:where parameters:nil error:error];
}

-(BOOL) deleteAllObjectsMatching:(NSString *)where parameters:(NSArray *)parameters error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
  __block int count = 0;
  __block NSArray *deleted;

  [_dbManager.pool inTransaction:^(FMDatabase *db, BOOL *rollback) {

    NSString *fetchSQL = _tableInfo.fetchAllSQL;
    if (where) {
      fetchSQL = [fetchSQL stringByAppendingFormat:@" WHERE %@", where];
    }

    FMResultSet *resultSet = [db executeQuery:fetchSQL valuesArray:parameters error:error];
    if (!resultSet) {
      return;
    }

    deleted = [self loadAll:resultSet error:error];

    [resultSet close];

    NSString *deleteSql = _tableInfo.deleteAllSQL;
    if (where) {
      deleteSql = [deleteSql stringByAppendingFormat:@" WHERE %@", where];
    }

    if ([db executeUpdate:deleteSql withArgumentsInArray:parameters]) {
      count = db.changes;
    }

    for (id del in deleted) {
      
      [del deleteWithDAO:self error:nil];
      
    }
    
  }];

  for (id del in deleted) {

    [_objectCache removeObjectForKey:[del dbId]];

  }

  if (count) {
    [self deletedAll:deleted];
  }

  return count > 0;
}

-(BOOL) deleteAllObjectsMatching:(NSString *)where parametersNamed:(NSDictionary *)parameters error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
  __block int count = 0;
  __block NSArray *deleted;

  [_dbManager.pool inTransaction:^(FMDatabase *db, BOOL *rollback) {

    NSString *fetchSQL = _tableInfo.fetchAllSQL;
    if (where) {
      fetchSQL = [fetchSQL stringByAppendingFormat:@" WHERE %@", where];
    }

    FMResultSet *resultSet = [db executeQuery:fetchSQL valuesArray:nil error:error];
    if (!resultSet) {
      return;
    }

    deleted = [self loadAll:resultSet error:error];

    [resultSet close];

    NSString *deleteSql = _tableInfo.deleteAllSQL;
    if (where) {
      deleteSql = [deleteSql stringByAppendingFormat:@" WHERE %@", where];
    }

    if ([db executeUpdate:deleteSql withParameterDictionary:parameters]) {
      count = db.changes;
    }

  }];

  for (id del in deleted) {
    
    [_objectCache removeObjectForKey:[del dbId]];
    
  }
  
  if (count) {
    [self deletedAll:deleted];
  }

  return count;
}

-(void) clearCache
{
  [_objectCache removeAllObjects];
}

-(void) willChange
{
  [_dbManager modelObjectsWillChangeInDAO:self];
}

-(void) didChange
{
  [_dbManager modelObjectsDidChangeInDAO:self];
}

-(void) inserted:(RTModel *)model
{
  @synchronized(_dbManager) {

    [self willChange];

    [_dbManager modelObject:model insertedInDAO:self];

    [self didChange];

  }
}

-(void) updated:(RTModel *)model
{
  @synchronized(_dbManager) {

    [self willChange];

    [_dbManager modelObject:model updatedInDAO:self];

    [self didChange];

  }
}

-(void) updatedAll:(NSArray *)models
{
  @synchronized(_dbManager) {

    [self willChange];

    for (RTModel *model in models) {
      [_dbManager modelObject:model updatedInDAO:self];
    }

    [self didChange];

  }
}

-(void) deleted:(RTModel *)model
{
  @synchronized(_dbManager) {

    [self willChange];

    [_dbManager modelObject:model deletedInDAO:self];

    [self didChange];

  }
}

-(void) deletedAll:(NSArray *)models
{
  @synchronized(_dbManager) {

    [self willChange];

    for (RTModel *model in models) {
      [_dbManager modelObject:model deletedInDAO:self];
    }

    [self didChange];

  }
}

@end
