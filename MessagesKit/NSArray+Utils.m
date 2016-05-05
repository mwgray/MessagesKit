//
//  NSArray+Utils.m
//  ReTxt
//
//  Created by Kevin Wooten on 7/11/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "NSArray+Utils.h"

#import "NSValue+Utils.h"

@import YOLOKit;


@implementation NSArray (Utils)

-(NSUInteger) lastIndex
{
  return self.count - 1;
}

-(NSArray *) arrayByRemovingObject:(id)object
{
  return self.reject(^BOOL (id item) {
    return [item isEqual:object];
  });
}

-(NSArray *) arrayByRemovingObjectsFromArray:(NSArray *)array
{
  return self.reject(^BOOL (id obj) {
    return [array containsObject:obj];
  });
}

-(NSData *) componentsJoinedAsBinaryData
{
  NSMutableData *data = [NSMutableData data];
  
  for (id value in self) {
    
    if ([value isKindOfClass:[NSData class]]) {
      
      [data appendData:value];
      
    }
    else if ([value isKindOfClass:[NSString class]]) {
      
      [data appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];
      
    }
    else if ([value isKindOfClass:[NSValue class]]) {
      
      [data appendData:[value bytesOfValue]];
    }
    
  }
  
  return data;
}

-(NSData *) componentsJoinedAsBinaryDataWithSeparator:(NSData *)separator
{
  NSMutableData *data = [NSMutableData data];
  
  for (id value in self) {
    
    if ([value isKindOfClass:[NSData class]]) {
      
      [data appendData:value];
      
    }
    else if ([value isKindOfClass:[NSString class]]) {
      
      [data appendData:[value dataUsingEncoding:NSUTF8StringEncoding]];
      
    }
    else if ([value isKindOfClass:[NSValue class]]) {
      
      [data appendData:[value bytesOfValue]];
    }
    
    [data appendData:separator];
    
  }
  
  return data;
}

+(NSArray *) arrayByRepeatingObject:(id)object count:(NSUInteger)count
{
  NSMutableArray *array = [NSMutableArray array];

  for (NSUInteger c=0; c < count; ++c) {
    [array addObject:object];
  }

  return array;
}

@end
