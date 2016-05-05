//
//  RTOpenSSLCertificationRequest.m
//  ReTxt
//
//  Created by Kevin Wooten on 12/13/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTOpenSSLCertificationRequest.h"

#import "RTOpenSSL.h"

@import openssl;


@implementation RTOpenSSLCertificationRequest

+(void) initialize
{
  [RTOpenSSL go];
}

-(instancetype) initWithRequestPointer:(X509_REQ *)pointer
{
  self = [super init];
  if (self) {
    
    _pointer = X509_REQ_dup(pointer);
    
  }
  return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
  self = [super init];
  if (self) {
    NSData *encoded = [aDecoder decodeObjectOfClass:NSData.class forKey:@"der"];
    const unsigned char *encodedBytes = encoded.bytes;
    if (d2i_X509_REQ(&_pointer, &encodedBytes, encoded.length) <= 0) {
      return nil;
    }
  }
  return self;
}

-(void) encodeWithCoder:(NSCoder *)aCoder
{
  [aCoder encodeObject:self.encoded forKey:@"der"];
}

-(void) dealloc
{
  X509_REQ_free(_pointer);
}

-(NSData *)encoded
{
  // Encode request
  unsigned char *reqBytes = NULL;
  int reqBytesLen = i2d_X509_REQ(_pointer, &reqBytes);
  if (reqBytesLen <= 0) {
    return nil;
  }

  return [NSData dataWithBytesNoCopy:reqBytes length:reqBytesLen];
}

@end
