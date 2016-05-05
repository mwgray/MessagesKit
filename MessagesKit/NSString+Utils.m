//
//  NSString+Utils.m
//  ReTxt
//
//  Created by Kevin Wooten on 6/11/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "NSString+Utils.h"


@implementation NSString (Utils)

+(NSString *) stringWithData:(NSData *)data encoding:(NSStringEncoding)encoding
{

  return [[NSString alloc] initWithData:data encoding:encoding];
}

-(BOOL) isEqualToStringCI:(NSString *)other
{
  return [self caseInsensitiveCompare:other] == NSOrderedSame;
}

-(NSUInteger) unsignedIntegerValue
{
  return (NSUInteger)[self integerValue];
}

@end
