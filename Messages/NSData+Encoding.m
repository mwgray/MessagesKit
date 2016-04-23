//
//  NSData+Encoding.m
//  ReTxt
//
//  Created by Kevin Wooten on 4/11/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "NSData+Encoding.h"

@implementation NSData (Encoding)

-(NSString *) hexEncodedString
{

  /* Returns hexadecimal string of NSData. Empty string if data is empty.   */

  const unsigned char *dataBuffer = (const unsigned char *)[self bytes];

  if (!dataBuffer) {
    return [NSString string];
  }

  NSUInteger dataLength  = [self length];
  NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];

  for (int i = 0; i < dataLength; ++i) {
    [hexString appendFormat:@"%02x", (unsigned int)dataBuffer[i]];
  }

  return [NSString stringWithString:hexString];
}

@end
