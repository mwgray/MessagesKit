//
//  RTModel.h
//  ReTxt
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "RTMessages.h"
#import "RTDBManager.h"


@interface RTModel : NSObject

@property (strong, nonatomic) id dbId;

@property (readonly, nonatomic) id id;

-(BOOL) load:(FMResultSet *)resultSet dao:(RTDAO *)dao error:(NSError **)error;
-(BOOL) save:(NSMutableDictionary *)values dao:(RTDAO *)dao error:(NSError **)error;
-(BOOL) deleteWithDAO:(RTDAO *)dao error:(NSError **)error;

-(void) invalidateCachedData;

@end

