//
//  NSURL+Utils.m
//  MessagesKit
//
//  Created by Kevin Wooten on 6/12/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "NSURL+Utils.h"

@import MobileCoreServices;


@implementation NSURL (Utils)

+(NSURL *) URLForTemporaryFile
{

  NSString *fileName = [[[NSUUID UUID] UUIDString] stringByAppendingString:@".tmp"];
  NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];

  return [NSURL fileURLWithPath:filePath];
}

-(NSString *) UTI
{
  NSString *extension = self.pathExtension;
  if (!extension) {
    return nil;
  }

  return CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)extension, NULL));
}

-(NSString *) MIMEType
{
  return CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)self.UTI, kUTTagClassMIMEType));
}

-(NSDictionary *) queryValues
{
  NSMutableDictionary *values = [NSMutableDictionary new];

  for (NSString *pair in [self.query componentsSeparatedByString:@"&"]) {
    NSArray *parts = [pair componentsSeparatedByString:@"="];
    if (parts.count == 2) {
      values[parts[0]] = parts[1];
    }
    else {
      values[parts[0]] = NSNull.null;
    }
  }

  return values;
}

-(NSURL *) URLByAppendingQueryParameters:(NSDictionary *)parameters
{
  NSMutableArray *parameterEntries = [NSMutableArray array];

  [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    key = [[key description] stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    if (obj == NSNull.null) {
      [parameterEntries addObject:key];
    }
    else {
      obj = [[obj description] stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
      [parameterEntries addObject:[NSString stringWithFormat:@"%@=%@", key, obj]];
    }
  }];

  NSString *query = [@"?" stringByAppendingString:[parameterEntries componentsJoinedByString:@"&"]];

  return [NSURL URLWithString:query relativeToURL:self];
}

@end
