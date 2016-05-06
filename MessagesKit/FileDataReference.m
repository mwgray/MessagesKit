//
//  FileDataReference.m
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "FileDataReference.h"

#import "DataReferences.h"


@interface FileDataReference ()

@end


@implementation FileDataReference

@dynamic URL;

+(BOOL)supportsSecureCoding
{
  return YES;
}

-(instancetype) initWithPath:(NSString *)path
{
  self = [self init];
  if (self) {
    self.path = path;
  }
  return self;
}

-(instancetype) initWithCoder:(NSCoder *)aDecoder
{
  self = [self init];
  if (self) {
    self.path = [aDecoder decodeObjectOfClass:NSString.class forKey:@"path"];
  }
  return self;
}

-(void) encodeWithCoder:(NSCoder *)aCoder
{
  [aCoder encodeObject:self.path forKey:@"path"];
}

-(NSURL *) URL
{
  return [NSURL fileURLWithPath:_path];
}

-(void) setURL:(NSURL *)URL
{
  self.path = URL.filePathURL.path;
}

-(NSNumber *) dataSizeAndReturnError:(NSError * _Nullable __autoreleasing *)error
{
  NSDictionary *attrs = [NSFileManager.defaultManager attributesOfItemAtPath:_path error:error];
  if (!attrs) {
    return nil;
  }
  return attrs[NSFileSize];
}

+(nullable instancetype) copyFrom:(id<DataReference>)source toPath:(NSString *)path filteredBy:(nullable DataReferenceFilter)filter error:(NSError **)error
{
  
  // Detect simple duplication and just increment the reference count
  if ([source isKindOfClass:FileDataReference.class] && filter == nil) {
    
    FileDataReference *fileSource = (id)source;
    
    int ret = link(fileSource.path.fileSystemRepresentation, path.fileSystemRepresentation);
    if (ret != 0) {
      if (error) {
        *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ret userInfo:@{NSLocalizedDescriptionKey: @"Unable to link file"}];
      }
      return nil;
    }
    
  }
  else {
    
    id<DataInputStream> ins = [source openInputStreamAndReturnError:error];
    if (!ins) {
      return nil;
    }
    
    NSOutputStream *outs = [NSOutputStream outputStreamToFileAtPath:path append:NO];
    if (!outs) {
      if (error) {
        *error = [NSError errorWithDomain:@"FileDataReferenceErrorDomain" code:0 userInfo:@{NSLocalizedDescriptionKey: @"Unable to open output stream"}];
      }
      return nil;
    }
    [outs open];
    
    if (![DataReferences filterStreamsWithInput:ins output:outs usingFilter:filter error:error]) {
      return nil;
    }
    
  }
  
  return [FileDataReference.alloc initWithPath:path];
}

-(id<DataInputStream>) openInputStreamAndReturnError:(NSError * _Nullable __autoreleasing *)error
{
  NSInputStream *ins = [NSInputStream inputStreamWithFileAtPath:_path];
  if (!ins) {
    if (error) {
      *error = [NSError errorWithDomain:@"FileDataReferenceErrorDomain" code:0 userInfo:@{NSLocalizedDescriptionKey: @"Unable to open input stream"}];
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

-(BOOL) deleteAndReturnError:(NSError * _Nullable __autoreleasing *)error
{
  int ret = unlink(_path.fileSystemRepresentation);
  if (ret != 0) {
    if (error) {
      *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"Unable to unlink file"}];
    }
    return NO;
  }
  return YES;
}

-(nullable instancetype) temporaryDuplicateFilteredBy:(nullable DataReferenceFilter)filter error:(NSError * _Nullable __autoreleasing *)error
{
  NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.new UUIDString]];
  return [FileDataReference copyFrom:self toPath:tempPath filteredBy:filter error:error];
}

@end
