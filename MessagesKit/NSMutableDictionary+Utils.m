//
//  NSMutableDictionary+Utils.m
//  MessagesKit
//
//  Created by Kevin Wooten on 4/20/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "NSMutableDictionary+Utils.h"


@implementation NSMutableDictionary (Model)

-(void) setNillableObject:(id)obj forKey:(id<NSCopying>)key;
{
  [self setObject:obj ? obj:[NSNull null] forKey:key];
}

@end
