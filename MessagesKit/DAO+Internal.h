//
//  DAO.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "DAO.h"

#import "DBManager.h"


NS_ASSUME_NONNULL_BEGIN


@interface DAO (Internal)

-(instancetype) initWithDBManager:(DBManager *)database
                        tableInfo:(DBTableInfo *)tableInfo
                        rootClass:(Class)rootClass
                   derivedClasses:(NSArray<Class> *)derivedClasses;

-(instancetype) initWithDBManager:(DBManager *)database;

@property (readonly, nonatomic) NSCache *objectCache;

-(nullable id) loadFrom:(FMResultSet *)resultSet withId:(id)objId error:(NSError **)error;
-(nullable id) load:(FMResultSet *)resultSet error:(NSError **)error;
-(NSArray<__kindof Model *> *) loadAll:(FMResultSet *)resultSet error:(NSError **)error;

-(void) inserted:(Model *)model;
-(void) updated:(Model *)model;
-(void) updatedAll:(NSArray *)models;
-(void) deleted:(Model *)model;
-(void) deletedAll:(NSArray *)models;

@end



@interface DBManager (Internal)

-(void) modelObjectsWillChangeInDAO:(DAO *)dao;
-(void) modelObject:(Model *)model insertedInDAO:(DAO *)dao;
-(void) modelObject:(Model *)model updatedInDAO:(DAO *)dao;
-(void) modelObject:(Model *)model deletedInDAO:(DAO *)dao;
-(void) modelObjectsDidChangeInDAO:(DAO *)dao;

@end


NS_ASSUME_NONNULL_END
