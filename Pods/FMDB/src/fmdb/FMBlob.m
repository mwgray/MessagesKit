//
//  FMBlob.m
//  fmdb
//
//  Created by Kevin Wooten on 4/21/16.
//
//

#import "FMBlob.h"

#if FMDB_SQLITE_STANDALONE
#import <sqlite3/sqlite3.h>
#else
#import <sqlite3.h>
#endif


@interface FMBlob ()

@property(nonatomic, assign) sqlite3_blob *blob;

@end

@implementation FMBlob

-(instancetype) initWithDatabase:(FMDatabase *)db dbName:(NSString *)dbName tableName:(NSString *)tableName columnName:(NSString *)columnName rowId:(SInt64)rowId mode:(FMBlobOpenMode)mode error:(NSError **)error
{
    self = [super init];
    if (self) {
        int ret = sqlite3_blob_open(db.sqliteHandle, dbName.UTF8String, tableName.UTF8String, columnName.UTF8String, rowId, mode, (sqlite3_blob**)&_blob);
        if (ret != SQLITE_OK) {
            if (error) {
                *error = [NSError errorWithDomain:@"FMDatabase" code:ret userInfo:@{NSLocalizedDescriptionKey: @"Unable to open blob"}];
            }
            return nil;
        }
    }
    return self;
}

-(void) dealloc
{
    [self close];
}

-(NSUInteger) size
{
    return sqlite3_blob_bytes(_blob);
}

-(BOOL) readIntoBuffer:(UInt8 *)buffer length:(NSUInteger)length atOffset:(NSUInteger)offset error:(NSError * _Nullable __autoreleasing *)error
{
    int ret = sqlite3_blob_read(_blob, buffer, (UInt32)length, (UInt32)offset);
    if (ret != SQLITE_OK) {
        if (error) {
            *error = [NSError errorWithDomain:@"FMDatabase" code:ret userInfo:@{NSLocalizedDescriptionKey: @"Unable to read from blob"}];
        }
        return NO;
    }
    return YES;
}

-(BOOL) writeFromBuffer:(const UInt8 *)buffer length:(NSUInteger)length atOffset:(NSUInteger)offset error:(NSError * _Nullable __autoreleasing *)error
{
    int ret = sqlite3_blob_write(_blob, buffer, (UInt32)length, (UInt32)offset);
    if (ret != SQLITE_OK) {
        if (error) {
            *error = [NSError errorWithDomain:@"FMDatabase" code:ret userInfo:@{NSLocalizedDescriptionKey: @"Unable to write to blob"}];
        }
        return NO;
    }
    return YES;
}

-(void) close
{
    if (_blob) {
        sqlite3_blob_close(_blob);
    }
    _blob = NULL;
}

@end
