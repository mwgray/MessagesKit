//
//  DataReferences.m
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "DataReferences.h"

#import "NSURL+Utils.h"


@implementation DataReferences

+(DataReferenceFilter) copyFilter
{
  return ^BOOL (id<DataInputStream> inStream, id<DataOutputStream> outStream, NSError **error) {
    
    UInt8 buffer[64 * 1024] = {0};
    
    for(;;) {

      NSUInteger bytesRead = 0;
      if (![inStream readBytesOfMaxLength:sizeof(buffer) intoBuffer:buffer bytesRead:&bytesRead error:error]) {
        return NO;
      }
      
      if (!bytesRead) {
        return YES;
      }
      
      if (![outStream writeBytesFromBuffer:buffer length:bytesRead error:error]) {
        return NO;
      }
      
    }
    
  };
}

+(nullable NSData *) filterReference:(id<DataReference>)source intoMemoryUsingFilter:(nullable DataReferenceFilter)filter error:(NSError **)error
{
  id<DataInputStream> inStream = [source openInputStreamAndReturnError:error];
  if (!inStream) {
    return nil;
  }
  
  NSOutputStream *outStream = [NSOutputStream outputStreamToMemory];
  if (!outStream) {
    return nil;
  }
  [outStream open];
  
  BOOL res = [self filterStreamsWithInput:inStream output:outStream usingFilter:filter error:error];
  [outStream close];
  
  if (!res) {
    return nil;
  }

  return [outStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
}

+(BOOL) filterStreamsWithInput:(id<DataInputStream>)inputStream output:(id<DataOutputStream>)outputStream usingFilter:(nullable DataReferenceFilter)filter error:(NSError **)error
{
  filter = filter ?: self.copyFilter;
  
  if (!filter(inputStream, outputStream, error)) {
    return NO;
  }
  
  return YES;
}

+(nullable NSData *) readAllDataFromReference:(nullable id<DataReference>)source error:(NSError **)error
{
  if (!source) {
    return [NSData data];
  }
  
  return [self filterReference:source intoMemoryUsingFilter:self.copyFilter error:error];
}

+(NSURL *) saveDataReferenceToTemporaryURL:(id<DataReference>)source error:(NSError **)error
{
  NSURL *tempURL = [NSURL URLForTemporaryFileWithExtension:[NSURL extensionForMimeType:source.MIMEType]];
  if (![source writeToURL:tempURL error:error]) {
    return nil;
  }
  return tempURL;
}

+(BOOL) isDataReference:(id<DataReference>)aref equivalentToDataReference:(id<DataReference>)bref
{
  NSData *aData = [DataReferences readAllDataFromReference:aref error:nil];
  NSData *bData = [DataReferences readAllDataFromReference:bref error:nil];
  return [aData isEqualToData:bData];
}

@end
