//
//  RTDBManager.h
//  ReTxt
//
//  Created by Kevin Wooten on 7/9/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;
@import FMDB;

@class RTModel;
@class RTDAO;


NS_ASSUME_NONNULL_BEGIN


@protocol RTDBManagerDelegate;


@interface RTDBManager : NSObject

@property (readonly, nonatomic) FMDatabaseReadWritePool *pool;
@property (readonly, nonatomic) NSDictionary<NSString *, NSString *> *classTableNames;

-(nullable instancetype) initWithPath:(NSString *)dbPath kind:(NSString *)kind daoClasses:(NSArray *)daoClasses error:(NSError **)error;

-(__kindof RTDAO *) daoForClass:(Class)modelClass;

-(__kindof RTDAO *) objectForKeyedSubscript:(NSString *)daoName;

-(NSUInteger) countOfDelegates;
-(void) addDelegatesObject:(id<RTDBManagerDelegate>)delegate;
-(void) removeDelegatesObject:(nullable id<RTDBManagerDelegate>)delegate;

-(void) shutdown;

@end



@protocol RTDBManagerDelegate <NSObject>

@optional
-(void) modelObjectsWillChangeInDAO:(RTDAO *)dao;
-(void) modelObject:(RTModel *)model insertedInDAO:(RTDAO *)dao;
-(void) modelObject:(RTModel *)model updatedInDAO:(RTDAO *)dao;
-(void) modelObject:(RTModel *)model deletedInDAO:(RTDAO *)dao;
-(void) modelObjectsDidChangeInDAO:(RTDAO *)dao;

@end



@interface RTDBTableInfo : NSObject

@property (copy, nonatomic, readonly) NSString *name;

@property (copy, nonatomic, readonly) NSArray *fieldNames;
@property (copy, nonatomic, readonly) NSArray *insertFieldNames;
@property (copy, nonatomic, readonly) NSArray *updateFieldNames;

@property (copy, nonatomic, readonly) NSNumber *idFieldIndex;
@property (copy, nonatomic, readonly, nullable) NSNumber *typeFieldIndex;
@property (assign, nonatomic) BOOL generatedId;

@property (copy, nonatomic, readonly) NSString *fetchSQL;
@property (copy, nonatomic, readonly) NSString *fetchAllSQL;
@property (copy, nonatomic, readonly) NSString *insertSQL;
@property (copy, nonatomic, readonly) NSString *updateSQL;
@property (copy, nonatomic, readonly) NSString *deleteSQL;
@property (copy, nonatomic, readonly) NSString *deleteAllSQL;

+(RTDBTableInfo *) loadTableInfo:(FMDatabase *)db tableName:(NSString *)tableName;

-(int) findField:(NSString *)fieldName;

@end


NS_ASSUME_NONNULL_END
