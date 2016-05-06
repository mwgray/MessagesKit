//
//  NSMutableArray+Utils.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/22/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;


@interface NSMutableArray (WeakReferences)

+(id) mutableArrayUsingWeakReferences;
+(id) mutableArrayUsingWeakReferencesWithCapacity:(NSUInteger)capacity;

@end
