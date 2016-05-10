//
//  Cache.m
//  MessagesKit
//
//  Created by Kevin Wooten on 11/14/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Cache.h"


@interface Cache () {
  NSMapTable *_liveObjects;
}

@end

@implementation Cache

-(instancetype) init
{
  self = [super init];
  if (self) {
    _liveObjects = [NSMapTable weakToWeakObjectsMapTable];
  }
  return self;
}

-(id) objectForKey:(id)key
{
  id obj = [super objectForKey:key];
  if (obj) {
    return obj;
  }

  return [_liveObjects objectForKey:key];
}

-(void) setObject:(id)obj forKey:(id)key
{
  [super setObject:obj forKey:key];

  [_liveObjects setObject:obj forKey:key];
}

-(void) setObject:(id)obj forKey:(id)key cost:(NSUInteger)g
{
  [super setObject:obj forKey:key cost:g];

  [_liveObjects setObject:obj forKey:key];
}

-(void) removeObjectForKey:(id)key
{
  [super removeObjectForKey:key];

  [_liveObjects removeObjectForKey:key];
}

-(void) removeAllObjects
{
  [super removeAllObjects];

  [_liveObjects removeAllObjects];
}

@end
