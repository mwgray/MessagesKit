//
//  NSMutableArray+Utils.m
//  ReTxt
//
//  Created by Kevin Wooten on 7/22/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "NSMutableArray+Utils.h"


@implementation NSMutableArray (WeakReferences)

+(id) mutableArrayUsingWeakReferences
{
  return [self mutableArrayUsingWeakReferencesWithCapacity:0];
}

+(id) mutableArrayUsingWeakReferencesWithCapacity:(NSUInteger)capacity
{
  CFArrayCallBacks callbacks = {0, NULL, NULL, CFCopyDescription, CFEqual};
  // We create a weak reference array
  return (__bridge_transfer id)(CFArrayCreateMutable(0, capacity, &callbacks));
}

@end