//
//  RTCache.h
//  ReTxt
//
//  Created by Kevin Wooten on 11/14/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;


@interface RTCache : NSCache

-(id) objectForKey:(id)key;
-(void) setObject:(id)obj forKey:(id)key; // 0 cost
-(void) setObject:(id)obj forKey:(id)key cost:(NSUInteger)g;

@end
