//
//  DataReferences.m
//  Messages
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "DataReferences.h"


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

+(nullable NSData *) readAllDataFromReference:(id<DataReference>)source error:(NSError **)error
{
  return [self filterReference:source intoMemoryUsingFilter:self.copyFilter error:error];
}

+(FileDataReference *)duplicateDataReferenceToTemporaryFile:(id<DataReference>)source withExtension:(NSString *)extension error:(NSError * _Nullable __autoreleasing *)error
{
  NSString *tempPath = [[NSTemporaryDirectory() stringByAppendingString:NSUUID.UUID.UUIDString] stringByAppendingPathExtension:extension];
  return [FileDataReference copyFrom:source toPath:tempPath filteredBy:nil error:error];
}

+(BOOL) isDataReference:(id<DataReference>)aref equivalentToDataReference:(id<DataReference>)bref
{
  NSData *aData = [DataReferences readAllDataFromReference:aref error:nil];
  NSData *bData = [DataReferences readAllDataFromReference:bref error:nil];
  return [aData isEqualToData:bData];
}

@end
