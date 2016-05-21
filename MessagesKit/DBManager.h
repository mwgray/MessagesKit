//
//  DBManager.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/9/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;
@import FMDB;

@class Model;
@class DAO;


NS_ASSUME_NONNULL_BEGIN


@protocol DBManagerDelegate;


@interface DBManager : NSObject

@property (readonly, nonatomic) NSURL *URL;

@property (readonly, nonatomic) FMDatabaseReadWritePool *pool;
@property (readonly, nonatomic) NSDictionary<NSString *, NSString *> *classTableNames;

-(nullable instancetype) initWithPath:(NSString *)dbPath kind:(NSString *)kind daoClasses:(NSArray *)daoClasses error:(NSError **)error;

-(__kindof DAO *) daoForClass:(Class)modelClass;

-(__kindof DAO *) objectForKeyedSubscript:(NSString *)daoName;

-(NSUInteger) countOfDelegates;
-(void) addDelegatesObject:(id<DBManagerDelegate>)delegate;
-(void) removeDelegatesObject:(nullable id<DBManagerDelegate>)delegate;

-(void) shutdown;

@end



@protocol DBManagerDelegate <NSObject>

@optional
-(void) modelObjectsWillChangeInDAO:(DAO *)dao;
-(void) modelObject:(Model *)model insertedInDAO:(DAO *)dao;
-(void) modelObject:(Model *)model updatedInDAO:(DAO *)dao;
-(void) modelObject:(Model *)model deletedInDAO:(DAO *)dao;
-(void) modelObjectsDidChangeInDAO:(DAO *)dao;

@end



@interface DBTableInfo : NSObject

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

+(DBTableInfo *) loadTableInfo:(FMDatabase *)db tableName:(NSString *)tableName;

-(int) findField:(NSString *)fieldName;

@end


NS_ASSUME_NONNULL_END
