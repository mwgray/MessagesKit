//
//  NSValue+Utils.m
//  MessagesKit
//
//  Created by Kevin Wooten on 8/20/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "NSValue+Utils.h"

@implementation NSValue (Utils)

-(NSData *) bytesOfValue
{
  NSUInteger size;
  const char *encoding = [self objCType];
  NSGetSizeAndAlignment(encoding, &size, NULL);

  void *ptr = malloc(size);
  [self getValue:ptr];
  
  return [NSData dataWithBytesNoCopy:ptr length:size freeWhenDone:YES];
}

@end
