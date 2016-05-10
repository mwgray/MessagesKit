//
//  BlobDataReference.m
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "BlobDataReference.h"

#import "DataReferences.h"
#import "FileDataReference.h"


@interface BlobDataReference ()

@property(copy, nonatomic) NSString *dbName;
@property(copy, nonatomic) NSString *tableName;
@property(assign, nonatomic) SInt64 blobId;

@end


@interface BlobStream : NSObject

@property(retain, nonatomic) FMBlob *blob;
@property(assign, nonatomic) NSUInteger offset;
@property(readonly, nonatomic) NSUInteger availableBytes;

-(instancetype) initWithBlob:(FMBlob *)blob;

@end

@interface BlobInputStream : BlobStream <DataInputStream>

@end

@interface BlobOutputStream : BlobStream <DataOutputStream>

@end


@implementation BlobDataReference

static NSString *refsColumnName = @"refs";
static NSString *dataColumnName = @"data";
static NSString *typeColumnName = @"type";

+(BOOL)supportsSecureCoding
{
  return YES;
}

-(instancetype) initWithDB:(DBManager *)db owner:(NSString *)owner dbName:(NSString *)dbName tableName:(NSString *)tableName blobId:(SInt64)blobId
{
  self = [self init];
  if (self) {
    self.db = db;
    self.owner = owner;
    self.dbName = dbName;
    self.tableName = tableName;
    self.blobId = blobId;
  }
  return self;
}

-(instancetype) initWithCoder:(NSCoder *)aDecoder
{
  self = [self init];
  if (self) {
    self.dbName = [aDecoder decodeObjectOfClass:NSString.class forKey:@"dbName"];
    self.tableName = [aDecoder decodeObjectOfClass:NSString.class forKey:@"tableName"];
    self.blobId = [aDecoder decodeInt64ForKey:@"blobId"];
  }
  return self;
}

-(void) encodeWithCoder:(NSCoder *)aCoder
{
  [aCoder encodeObject:self.dbName forKey:@"dbName"];
  [aCoder encodeObject:self.tableName forKey:@"tableName"];
  [aCoder encodeInt64:self.blobId forKey:@"blobId"];
}

-(nullable NSNumber *) dataSizeAndReturnError:(NSError **)error
{
  __block NSNumber * size = nil;
  
  [_db.pool inReadableDatabase:^(FMDatabase * _Nonnull db) {
    
    FMResultSet *rs = [db executeQuery:@"SELECT length(\(BlobDataReference.dataColumnName)) FROM \(self.tableName) WHERE rowid = ?"
                           valuesArray:@[@(_blobId)]
                                 error:error];
    if (!rs) {
      return;
    }
    
    BOOL valid = NO;
    if (![rs nextReturning:&valid error:error]) {
      return;
    }
    
    size = @([rs longForColumnIndex:0]);
    
    [rs close];
  }];

  return size;
}

-(BOOL) isSameLocationInDatabase:(NSString *)dbName andTable:(NSString *)tableName
{
  return [_dbName isEqualToString:dbName] && [_tableName isEqualToString:tableName];
}

-(BOOL) incrementRefsAndReturnError:(NSError **)error
{
  __block BOOL res = NO;
  [_db.pool inWritableDatabase:^(FMDatabase * _Nonnull db) {
    res = [db executeUpdate:[NSString stringWithFormat:@"UPDATE %@ SET %@ = %@ + 1 WHERE rowid = ?", _tableName, refsColumnName, refsColumnName]
                valuesArray:@[@(_blobId)]
                      error:error];
  }];
  return res;
}

-(BOOL) decrementRefsAndReturnError:(NSError **)error
{
  __block BOOL res = NO;
  [_db.pool inTransaction:^(FMDatabase * _Nonnull db, BOOL *rollback) {
    
    res = [db executeUpdate:[NSString stringWithFormat:@"UPDATE %@ SET %@ = %@ - 1 WHERE rowid = ?", _tableName, refsColumnName, refsColumnName]
                valuesArray:@[@(_blobId)]
                      error:error];
    if (!res) {
      *rollback = YES;
      return;
    }
    
    res = [db executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ < 1", _tableName, refsColumnName]
                valuesArray:@[]
                      error:error];
    if (!res) {
      *rollback = YES;
      return;
    }
    
  }];
  
  return res;
}

+(nullable instancetype) copyFrom:(id<DataReference>)source toOwner:(NSString *)owner forTable:(NSString *)tableName inDatabase:(NSString *)dbName using:(DBManager *)db filteredBy:(nullable DataReferenceFilter)filter error:(NSError **)error
{
  if ([source isKindOfClass:BlobDataReference.class] && [(id)source isSameLocationInDatabase:dbName andTable:tableName] && filter == nil) {
    
    BlobDataReference *blobSource = (id)source;
    
    if ([blobSource.owner isEqualToString:owner]) {
      return blobSource;
    }
    
    if (![blobSource incrementRefsAndReturnError:error]) {
      return nil;
    }
    
    return [BlobDataReference.alloc initWithDB:db owner:owner dbName:dbName tableName:tableName blobId:blobSource.blobId];
  }

  NSData *data = [DataReferences filterReference:source intoMemoryUsingFilter:filter error:error];
  if (!data) {
    return nil;
  }
  
  __block BOOL valid = NO;
  __block SInt64 blobId = 0;
  [db.pool inWritableDatabase:^(FMDatabase * _Nonnull db) {
    
    if (![db executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@(%@, %@) VALUES (?, 1)", tableName, dataColumnName, refsColumnName]
               valuesArray:@[data]
                     error:error]) {
      return;
    }
    
    blobId = db.lastInsertRowId;
    valid = YES;
  }];
  
  if (!valid) {
    return nil;
  }
  
  return [BlobDataReference.alloc initWithDB:db owner:owner dbName:dbName tableName:tableName blobId:blobId];
}

-(nullable id<DataInputStream>) openInputStreamAndReturnError:(NSError * _Nullable __autoreleasing *)error
{
  __block FMBlob *blob = nil;
  [_db.pool inReadableDatabase:^(FMDatabase * _Nonnull db) {
    blob = [FMBlob.alloc initWithDatabase:db dbName:_dbName tableName:_tableName columnName:dataColumnName rowId:_blobId mode:FMBlobOpenModeRead error:error];
  }];
  
  if (!blob) {
    return nil;
  }
  
  return [BlobInputStream.alloc initWithBlob:blob];
}

-(BOOL) deleteAndReturnError:(NSError * _Nullable __autoreleasing *)error
{
  return [self decrementRefsAndReturnError:error];
}

-(nullable FileDataReference *) temporaryDuplicateFilteredBy:(nullable DataReferenceFilter)filter error:(NSError **)error
{
  NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.new UUIDString]];
  return [FileDataReference copyFrom:self toPath:tempPath filteredBy:filter error:error];
}

@end



@implementation BlobStream

-(instancetype)initWithBlob:(FMBlob *)blob
{
  self = [self init];
  if (self) {
    _blob = blob;
    _offset = 0;
  }
  return self;
}

-(NSUInteger) availableBytes
{
  return self.blob.size - self.offset;
}

@end


@implementation BlobInputStream

-(BOOL) readBytesOfMaxLength:(NSUInteger)maxLength intoBuffer:(UInt8 *)buffer bytesRead:(NSUInteger *)bytesRead error:(NSError * _Nullable __autoreleasing *)error
{
  NSUInteger avail = MIN(self.availableBytes, maxLength);
  if(![self.blob readIntoBuffer:buffer length:avail atOffset:self.offset error:error]) {
    return NO;
  }
  *bytesRead = avail;
  self.offset += avail;
  return YES;
}

@end


@implementation BlobOutputStream

-(BOOL)writeBytesFromBuffer:(const UInt8 *)buffer length:(NSUInteger)length error:(NSError * _Nullable __autoreleasing *)error
{
  if (![self.blob writeFromBuffer:buffer length:length atOffset:self.offset error:error]) {
    return NO;
  }
  return YES;
}

@end
