//
//  FMBlob.h
//  fmdb
//
//  Created by Kevin Wooten on 4/21/16.
//
//

#import <Foundation/Foundation.h>
#import "FMDatabase.h"


NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM(int, FMBlobOpenMode) {
    FMBlobOpenModeRead          = 0,
    FMBlobOpenModeReadWrite     = 1
};


@interface FMBlob : NSObject

@property(nonatomic, readonly) NSUInteger size;

-(nullable instancetype) initWithDatabase:(FMDatabase *)db dbName:(NSString *)dbName tableName:(NSString *)tableName columnName:(NSString *)columnName rowId:(SInt64)rowId mode:(FMBlobOpenMode)mode error:(NSError **)error;

-(BOOL) readIntoBuffer:(UInt8 *)buffer length:(NSUInteger)length atOffset:(NSUInteger)offset error:(NSError **)error;
-(BOOL) writeFromBuffer:(const UInt8 *)buffer length:(NSUInteger)length atOffset:(NSUInteger)offset error:(NSError **)error;

-(void) close;

@end


NS_ASSUME_NONNULL_END
