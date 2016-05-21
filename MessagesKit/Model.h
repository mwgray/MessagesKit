//
//  Model.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "Messages.h"
#import "DBManager.h"


NS_ASSUME_NONNULL_BEGIN


@interface Model : NSObject

@property (strong, nonatomic) id dbId;

@property (readonly, nonatomic) id id;

-(BOOL) load:(FMResultSet *)resultSet dao:(DAO *)dao error:(NSError **)error;
-(BOOL) save:(NSMutableDictionary *)values dao:(DAO *)dao error:(NSError **)error;

-(BOOL) willInsertIntoDAO:(DAO *)dao error:(NSError **)error;
-(BOOL) willUpdateInDAO:(DAO *)dao error:(NSError **)error;
-(BOOL) didDeleteFromDAO:(DAO *)dao error:(NSError **)error;

-(void) invalidateCachedData;

@end


NS_ASSUME_NONNULL_END
