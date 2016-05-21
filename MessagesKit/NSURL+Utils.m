//
//  NSURL+Utils.m
//  MessagesKit
//
//  Created by Kevin Wooten on 6/12/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "NSURL+Utils.h"

@import MobileCoreServices;
@import YOLOKit;


@implementation NSURL (Utils)

+(NSURL *) URLForTemporaryFile
{
  return [self URLForTemporaryFileWithExtension:@"tmp"];
}

+(NSURL *) URLForTemporaryFileWithExtension:(NSString *)extension
{
  NSString *fileName = [[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:extension];
  NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
  return [NSURL fileURLWithPath:filePath];
}

-(NSString *) UTI
{
  if ([self.scheme isEqualToString:@"data"]) {
    
    return CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)self.MIMEType, NULL));
  }
  else {
  
    NSString *extension = self.pathExtension;
    if (!extension) {
      return nil;
    }

    return CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)extension, NULL));
  }
}

-(NSString *) MIMEType
{
  if ([self.scheme isEqualToString:@"data"]) {
    NSString *params = self.path.split(@",").firstObject;
    return params
    .split(@";").reject(^(NSString *param){
      return [param caseInsensitiveCompare:@"base64"] == NSOrderedSame;
    })
    .join(@";");
  }
  else {
    NSURL *fileURL = self.filePathURL;
    if (fileURL) {
      return CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)self.UTI, kUTTagClassMIMEType));
    }
  }
  return nil;
}

-(NSDictionary *) queryValues
{
  NSMutableDictionary *values = [NSMutableDictionary new];
  
  [[NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:NO].queryItems enumerateObjectsUsingBlock:^(NSURLQueryItem *obj, NSUInteger idx, BOOL *stop) {
    values[obj.name] = obj.value;
  }];

  return values;
}

-(NSURL *) URLByAppendingQueryParameters:(NSDictionary *)parameters
{
  NSURLComponents *components = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:NO];
  
  NSMutableArray<NSURLQueryItem *> *queryItems = [NSMutableArray.alloc init];
  
  [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
    NSString *name = [key description];
    NSString *value = [obj isKindOfClass:NSNull.class] ? key : [obj description];
    [queryItems addObject:[NSURLQueryItem queryItemWithName:name value:value]];
  }];

  components.queryItems = [components.queryItems arrayByAddingObjectsFromArray:queryItems];
  
  if (self.baseURL) {
    return [components URLRelativeToURL:self.baseURL];
  }
  
  return [components URL];
}

-(NSURL *) relativeFileURLWithBaseURL:(NSURL *)baseURL
{
  if ((self.scheme.length != 0 && !self.isFileURL) || !baseURL.isFileURL) {
    return self;
  }
  
  NSArray<NSString *> *baseURLPathComponents = baseURL.absoluteURL.pathComponents;
  NSArray<NSString *> *pathComponents = self.absoluteURL.pathComponents;
  
  NSUInteger idx;
  for (idx=0; idx < baseURLPathComponents.count && idx < pathComponents.count; ++idx) {
    if (![baseURLPathComponents[idx] isEqualToString:pathComponents[idx]]) {
      break;
    }
  }
  
  pathComponents = [pathComponents subarrayWithRange:NSMakeRange(idx, pathComponents.count - idx)];
  if (pathComponents.count == 0) {
    return self;
  }
  
  NSURLComponents *components = [NSURLComponents componentsWithURL:self resolvingAgainstBaseURL:NO];
  components.path = [NSURL fileURLWithPathComponents:pathComponents].relativePath;
  return components.URL;
}

+(NSString *) extensionForMimeType:(NSString *)mimeType
{
  NSString *UTI = CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)mimeType, NULL));
  return CFBridgingRelease(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassFilenameExtension));
}

@end
