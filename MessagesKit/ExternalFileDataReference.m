//
//  ExternalFileDataReference.m
//  MessagesKit
//
//  Created by Kevin Wooten on 5/20/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "ExternalFileDataReference.h"

#import "URLDataReference.h"
#import "DataReferences.h"
#import "NSURL+Utils.h"


@interface ExternalFileDataReference ()

@property(strong, nonatomic) DBManager *dbManager;
@property(copy, nonatomic) NSString *fileName;

@end


@implementation ExternalFileDataReference

-(instancetype)initWithDBManager:(DBManager *)dbManager fileName:(NSString *)fileName
{
  self = [super init];
  if (self) {
    self.dbManager = dbManager;
    self.fileName = fileName;
  }
  return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
  return [self initWithDBManager:(id)NSNull.null
                        fileName:[aDecoder decodeObjectOfClass:NSString.class forKey:@"fileName"]];
}

-(void)encodeWithCoder:(NSCoder *)aCoder
{
  [aCoder encodeObject:self.fileName forKey:@"fileName"];
}

-(id) copyWithZone:(NSZone *)zone
{
  ExternalFileDataReference *copy = [ExternalFileDataReference new];
  copy.dbManager = self.dbManager;
  copy.fileName = self.fileName;
  return copy;
}

-(NSURL *)URL
{
  return [NSURL URLWithString:self.fileName relativeToURL:self.dbManager.URL];
}

-(NSString *) MIMEType
{
  return self.URL.MIMEType;
}

-(NSNumber *)dataSizeAndReturnError:(NSError * _Nullable __autoreleasing *)error
{
  NSDictionary *fileAttrs = [NSFileManager.defaultManager attributesOfItemAtPath:self.URL.path error:error];
  if (!fileAttrs) {
    return nil;
  }
  
  return fileAttrs[NSFileSize];
}

-(id<DataInputStream>)openInputStreamAndReturnError:(NSError * _Nullable __autoreleasing *)error
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

-(id<DataReference>) temporaryDuplicateFilteredBy:(DataReferenceFilter)filter withMIMEType:(NSString *)MIMEType error:(NSError **)error
{
  NSString *tempExt = [NSURL extensionForMimeType:MIMEType] ?: self.MIMEType;
  NSURL *tempURL = [NSURL.URLForTemporaryFile.URLByDeletingPathExtension URLByAppendingPathExtension:tempExt];
  
  if (filter == nil) {
    
    // When not changing data then just add another link to the file
    
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
  int ret = link(self.URL.fileSystemRepresentation, url.fileSystemRepresentation);
  if (ret != 0) {
    if (error) {
      *error = [NSError errorWithDomain:NSPOSIXErrorDomain
                                   code:ret
                               userInfo:@{NSLocalizedDescriptionKey: @"Unable to link file"}];
    }
    return NO;
  }
  return YES;
}

@end
