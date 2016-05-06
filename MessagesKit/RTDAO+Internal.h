//
//  RTDAO.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTDAO.h"

#import "RTDBManager.h"


NS_ASSUME_NONNULL_BEGIN


@interface RTDAO (Internal)

-(instancetype) initWithDBManager:(RTDBManager *)database
                        tableInfo:(RTDBTableInfo *)tableInfo
                        rootClass:(Class)rootClass
                   derivedClasses:(NSArray<Class> *)derivedClasses;

-(instancetype) initWithDBManager:(RTDBManager *)database;

@property (readonly, nonatomic) NSCache *objectCache;

-(nullable id) loadFrom:(FMResultSet *)resultSet withId:(id)objId error:(NSError **)error;
-(nullable id) load:(FMResultSet *)resultSet error:(NSError **)error;
-(NSArray<__kindof RTModel *> *) loadAll:(FMResultSet *)resultSet error:(NSError **)error;

-(void) inserted:(RTModel *)model;
-(void) updated:(RTModel *)model;
-(void) updatedAll:(NSArray *)models;
-(void) deleted:(RTModel *)model;
-(void) deletedAll:(NSArray *)models;

@end



@interface RTDBManager (Internal)

-(void) modelObjectsWillChangeInDAO:(RTDAO *)dao;
-(void) modelObject:(RTModel *)model insertedInDAO:(RTDAO *)dao;
-(void) modelObject:(RTModel *)model updatedInDAO:(RTDAO *)dao;
-(void) modelObject:(RTModel *)model deletedInDAO:(RTDAO *)dao;
-(void) modelObjectsDidChangeInDAO:(RTDAO *)dao;

@end


NS_ASSUME_NONNULL_END
