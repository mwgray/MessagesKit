//
//  FMResultSet+Utils.h
//  MessagesKit
//
//  Created by Kevin Wooten on 4/20/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

@import FMDB;

#import "Messages.h"


NS_ASSUME_NONNULL_BEGIN


@class DBManager;
@protocol DataReference;


@interface FMResultSet (Model)

-(Id *) idForColumn:(NSString *)columnName;
-(Id *) idForColumnIndex:(int)columnIdx;

-(NSURL *) URLForColumn:(NSString *)columnName;
-(NSURL *) URLForColumnIndex:(int)columnIdx;

-(CGSize) sizeForColumn:(NSString *)columnName;
-(CGSize) sizeForColumnIndex:(int)columnIdx;

-(id<DataReference>) dataReferenceForColumn:(NSString *)columnName usingDBManager:(DBManager *)db;
-(id<DataReference>) dataReferenceForColumnIndex:(int)columnIdx usingDBManager:(DBManager *)db;

-(id) nillableObjectForColumnIndex:(int)columnIndex;

@end


NS_ASSUME_NONNULL_END
