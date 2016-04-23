//
//  RTPersistentCache.h
//  ReTxt
//
//  Created by Kevin Wooten on 5/24/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;


NS_ASSUME_NONNULL_BEGIN


@interface RTPersistentCache<Key: id<NSCopying>, Value: id<NSCoding>> : NSObject

-(instancetype) initWithName:(NSString *)name loader:(nullable Value (^)(Key key, NSDate *__nullable *__nullable expires, NSError **error))loader;
-(instancetype) initWithName:(NSString *)name loader:(nullable Value (^)(Key key, NSDate *__nullable *__nullable expires, NSError **error))loader clear:(BOOL)clear;

-(nullable Value) availableObjectForKey:(Key)key;
-(nullable Value) availableObjectForKey:(Key)key expires:(NSDate *__nullable *__nullable)expires;
-(nullable Value) objectForKey:(Key)key error:(NSError **)error;

-(void) cacheValue:(Value)value forKey:(Key)key expiring:(NSDate *)expires;

-(void) invalidateObjectForKey:(Key)key;

-(void) compact;

@end


NS_ASSUME_NONNULL_END
