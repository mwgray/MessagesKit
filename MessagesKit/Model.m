//
//  Model.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Model.h"

#import "DAO.h"
#import "Messages+Exts.h"
#import "NSObject+Utils.h"
#import "NSMutableDictionary+Utils.h"


@implementation Model

@dynamic dbId;

-(id) id
{
  return nil;
}

-(BOOL) isEqual:(id)object
{
  if ([object isKindOfClass:[Model class]]) {
    Model *other = object;
    return isEqual(self.dbId, other.dbId);
  }
  return NO;
}

-(NSUInteger) hash
{
  NSUInteger result = 1;
  result = 31 * result + [self.id hash];
  return result;
}

-(NSComparisonResult) compare:(Model *)other
{
  NSComparisonResult res;
  if ([other isKindOfClass:[Model class]]) {
    res = [self.id compare:[other id]];
  }
  else {
    res = NSOrderedDescending;
  }
  return res;
}

-(BOOL)load:(FMResultSet *)resultSet dao:(DAO *)dao error:(NSError *__autoreleasing *)error
{
  self.dbId = [resultSet objectForColumnIndex:dao.tableInfo.idFieldIndex.intValue];
  return YES;
}

-(BOOL)save:(NSMutableDictionary *)values dao:(DAO *)dao error:(NSError *__autoreleasing *)error
{
  [values setNillableObject:self.dbId forKey:@"id"];
  return YES;
}

-(BOOL) deleteWithDAO:(DAO *)dao error:(NSError *__autoreleasing *)error
{
  return YES;
}

-(void) invalidateCachedData
{
  
}

@end
