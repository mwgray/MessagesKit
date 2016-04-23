//
//  NSData+Random.m
//  ReTxt
//
//  Created by Kevin Wooten on 3/31/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "NSData+Random.h"

#import <CommonCrypto/CommonCrypto.h>
#import <CommonCrypto/CommonRandom.h>


@implementation NSData (Random)

+(instancetype) dataWithRandomBytesOfLength:(NSUInteger)length
{
  NSMutableData *data = [NSMutableData dataWithLength:length];
  
  CCStatus status = CCRandomGenerateBytes(data.mutableBytes, length);
  NSAssert(status == kCCSuccess, @"Random generation failed");

  return data;
}

@end
