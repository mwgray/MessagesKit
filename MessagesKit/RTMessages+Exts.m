//
//  RTMessages+Exts.m
//  MessagesKit
//
//  Created by Kevin Wooten on 12/13/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessages+Exts.h"

#import "NSData+CommonDigest.h"



@implementation RTId (Exts)

static RTId *null;

+(void) initialize
{
  NSMutableData *data = [NSMutableData dataWithLength:16];
  uuid_clear([data mutableBytes]);
  null = [RTId idWithData:data];
}

-(id) initWithString:(NSString *)str
{
  if (!str.length) {
    return null;
  }
  NSMutableData *data = [NSMutableData dataWithLength:16];
  int res = uuid_parse([str UTF8String], [data mutableBytes]);
  if (res) {
    return null;
  }
  return [self initWithData:data];
}

-(id) initWithUUID:(NSUUID *)uuid
{
  NSMutableData *data = [NSMutableData dataWithLength:16];
  [uuid getUUIDBytes:[data mutableBytes]];
  return [self initWithData:data];
}

+(RTId *) idWithString:(NSString *)value
{
  return [[RTId alloc] initWithString:value];
}

+(RTId *) idWithUUID:(NSUUID *)value; {
  return [[RTId alloc] initWithUUID:value];
}

+(RTId *) idWithData:(NSData *)data
{
  if (data.length != 16) {
    return null;
  }
  
  return [[RTId alloc] initWithData:data];
}

+(RTId *) null
{
  return null;
}

+(RTId *) generate
{
  NSMutableData *data = [NSMutableData dataWithLength:16];
  uuid_generate_time([data mutableBytes]);
  return [RTId idWithData:data];
}

-(NSString *) UUIDString
{
  uuid_string_t str;
  uuid_unparse([self.data bytes], str);
  return [NSString stringWithUTF8String:str];
}

-(NSString *) description
{
  return [self UUIDString];
}

-(BOOL) isNull
{
  return uuid_is_null([self.data bytes]);
}

-(NSComparisonResult) compare:(RTId *)other
{
  int res = uuid_compare([self.data bytes], [other.data bytes]);
  return res < 0 ? (NSOrderedAscending) : (res > 0 ? NSOrderedDescending : NSOrderedSame);
}

@end



@implementation RTUserInfo (Exts)

-(NSData *)fingerprint
{
  NSData *encFP = [self.encryptionCert sha1];
  NSData *sigFP = [self.signingCert sha1];
  NSMutableData *fp = [NSMutableData data];
  [fp appendData:encFP];
  [fp appendData:sigFP];
  return [fp copy];
}

@end
