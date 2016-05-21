//
//  URLDataReference.m
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "URLDataReference.h"

#import "DataReferences.h"
#import "NSURL+Utils.h"
#import "Log.h"


MK_DECLARE_LOG_LEVEL()


@interface URLDataReference ()

@property(copy, nonatomic) NSURL *URL;

@end


@implementation URLDataReference

-(instancetype) initWithURL:(NSURL *)url
{
  self = [super init];
  if (self) {
    self.URL = url;
  }
  return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
  return [self initWithURL:[aDecoder decodeObjectOfClass:NSURL.class forKey:@"URL"]];
}

-(void) dealloc
{
  NSError *error;
  if (![self removeAndReturnError:&error]) {
    DDLogError(@"Error removing URL data @ %@:\n%@", self.URL, error);
  }
}

-(void)encodeWithCoder:(NSCoder *)aCoder
{
  [aCoder encodeObject:self.URL forKey:@"URL"];
}

-(instancetype)copyWithZone:(NSZone *)zone
{
  NSError *error;
  URLDataReference *copy = [self temporaryDuplicateFilteredBy:nil withMIMEType:self.MIMEType error:&error];
  if (!copy) {
    DDLogError(@"Error copying URL data @ %@:\n%@", self.URL, error);
  }
  return copy;
}

-(NSString *) MIMEType
{
  return self.URL.MIMEType;
}

-(NSNumber *) dataSizeAndReturnError:(NSError * _Nullable __autoreleasing *)error
{
  NSDictionary *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:self.URL.path error:error];
  if (!attrs) {
    return nil;
  }
  return attrs[NSFileSize];
}

-(NSInputStream *) openInputStreamAndReturnError:(NSError * _Nullable __autoreleasing *)error
{
  NSInputStream *ins = [NSInputStream inputStreamWithURL:self.URL];
  if (!ins) {
    if (error) {
      *error = [NSError errorWithDomain:DataReferenceErrorDomain
                                   code:0
                               userInfo:@{NSLocalizedDescriptionKey: @"Unable to open input stream"}];
    }
    return nil;
  }
  
  [ins open];
  if (ins.streamError) {
    if (error) {
      *error = ins.streamError;
    }
    return nil;
  }
  
  return ins;
}

-(CGImageSourceRef) createImageSourceAndReturnError:(NSError **)error
{
  return CGImageSourceCreateWithURL((__bridge CFURLRef)self.URL, NULL);
}

-(instancetype) temporaryDuplicateFilteredBy:(DataReferenceFilter)filter withMIMEType:(NSString *)MIMEType error:(NSError **)error
{
  NSString *tempExt = [NSURL extensionForMimeType:MIMEType] ?: self.MIMEType;
  NSURL *tempURL = [NSURL.URLForTemporaryFile.URLByDeletingPathExtension URLByAppendingPathExtension:tempExt];

  // If this is not changing data then just add another link to the file
  if (filter == nil) {
    
    if (![self writeToURL:tempURL error:error]) {
      return nil;
    }
    
  }
  else {
  
    NSInputStream *inStream = [self openInputStreamAndReturnError:error];
    if (!inStream) {
      return nil;
    }
    
    NSOutputStream *outStream = [NSOutputStream outputStreamWithURL:tempURL append:NO];
    if (!outStream) {
      return nil;
    }
    [outStream open];
    if (outStream.streamError) {
      if (error) {
        *error = outStream.streamError;
      }
      return nil;
    }
    
    BOOL res = [DataReferences filterStreamsWithInput:inStream output:outStream usingFilter:filter error:error];
    [inStream close];
    [outStream close];

    if (!res) {
      return nil;
    }
    
  }
  
  return [URLDataReference.alloc initWithURL:tempURL];
}

-(BOOL)writeToURL:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error
{
  return [NSFileManager.defaultManager linkItemAtURL:self.URL toURL:url error:error];
}

-(BOOL) removeAndReturnError:(NSError * _Nullable __autoreleasing *)error
{
  return [NSFileManager.defaultManager removeItemAtURL:self.URL error:error];
}

@end
