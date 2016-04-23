//
//  NSArray+Utils.h
//  ReTxt
//
//  Created by Kevin Wooten on 7/11/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


@interface NSArray (Utils)

+(NSArray *) arrayByRepeatingObject:(id)object count:(NSUInteger)count;

-(NSUInteger) lastIndex;

-(NSArray *) arrayByRemovingObject:(id)object;
-(NSArray *) arrayByRemovingObjectsFromArray:(NSArray *)array;

-(NSData *) componentsJoinedAsBinaryData;
-(NSData *) componentsJoinedAsBinaryDataWithSeparator:(NSData *)sep;


@end


NS_ASSUME_NONNULL_END