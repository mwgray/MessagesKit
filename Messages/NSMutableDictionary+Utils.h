//
//  NSMutableDictionary+Utils.h
//  Messages
//
//  Created by Kevin Wooten on 4/20/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

@import Foundation;


@interface NSMutableDictionary (Model)

-(void) setNillableObject:(id)obj forKey:(id<NSCopying>)key;

@end
