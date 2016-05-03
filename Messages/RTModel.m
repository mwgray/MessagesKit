//
//  RTModel.m
//  ReTxt
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTModel.h"

#import "RTDAO.h"
#import "RTMessages+Exts.h"
#import "NSObject+Utils.h"
#import "NSMutableDictionary+Utils.h"


@implementation RTModel

@dynamic dbId;

-(id) id
{
  return nil;
}

-(BOOL) isEqual:(id)object
{
  if ([object isKindOfClass:[RTModel class]]) {
    RTModel *other = object;
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

-(NSComparisonResult) compare:(RTModel *)other
{
  NSComparisonResult res;
  if ([other isKindOfClass:[RTModel class]]) {
    res = [self.id compare:[other id]];
  }
  else {
    res = NSOrderedDescending;
  }
  return res;
}

-(BOOL)load:(FMResultSet *)resultSet dao:(RTDAO *)dao error:(NSError *__autoreleasing *)error
{
  self.dbId = [resultSet objectForColumnIndex:dao.tableInfo.idFieldIndex.intValue];
  return YES;
}

-(BOOL)save:(NSMutableDictionary *)values dao:(RTDAO *)dao error:(NSError *__autoreleasing *)error
{
  [values setNillableObject:self.dbId forKey:@"id"];
  return YES;
}

-(BOOL) deleteWithDAO:(RTDAO *)dao error:(NSError *__autoreleasing *)error
{
  return YES;
}

-(void) invalidateCachedData
{
  
}

@end
