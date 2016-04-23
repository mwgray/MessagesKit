//
//  FMResultSet+Utils.h
//  Messages
//
//  Created by Kevin Wooten on 4/20/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

@import FMDB;

#import "RTMessages.h"


NS_ASSUME_NONNULL_BEGIN


@class RTDBManager;
@protocol DataReference;


@interface FMResultSet (Model)

-(RTId *) idForColumn:(NSString *)columnName;
-(RTId *) idForColumnIndex:(int)columnIdx;

-(NSURL *) URLForColumn:(NSString *)columnName;
-(NSURL *) URLForColumnIndex:(int)columnIdx;

-(CGSize) sizeForColumn:(NSString *)columnName;
-(CGSize) sizeForColumnIndex:(int)columnIdx;

-(id<DataReference>) dataReferenceForColumn:(NSString *)columnName forOwner:(NSString *)owner usingDB:(RTDBManager *)db;
-(id<DataReference>) dataReferenceForColumnIndex:(int)columnIdx forOwner:(NSString *)owner usingDB:(RTDBManager *)db;

-(id) nillableObjectForColumnIndex:(int)columnIndex;

@end


NS_ASSUME_NONNULL_END
