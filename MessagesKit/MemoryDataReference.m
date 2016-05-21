//
//  MemoryDataReference.m
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "MemoryDataReference.h"

#import "DataReferences.h"


@interface MemoryDataReference ()

@property(copy, nonatomic) NSData *data;
@property(copy, nonatomic) NSString *MIMEType;

@end


@implementation MemoryDataReference

-(instancetype) initWithData:(NSData *)data ofMIMEType:(NSString *)MIMEType
{
  self = [super init];
  if (self) {
    self.data = data;
    self.MIMEType = MIMEType;
  }
  return self;
}

-(instancetype) initWithCoder:(NSCoder *)aDecoder
{
  return [self initWithData:[aDecoder decodeObjectOfClass:NSData.class forKey:@"data"]
                 ofMIMEType:[aDecoder decodeObjectOfClass:NSString.class forKey:@"MIMEType"]];
}

-(void)encodeWithCoder:(NSCoder *)aCoder
{
  [aCoder encodeObject:self.data forKey:@"data"];
  [aCoder encodeObject:self.MIMEType forKey:@"MIMEType"];
}

-(id) copyWithZone:(NSZone *)zone
{
  MemoryDataReference *copy = [MemoryDataReference new];
  copy.data = self.data;
  return copy;
}

-(NSNumber *)dataSizeAndReturnError:(NSError **)error
{
  return @(_data.length);
}

-(id<DataInputStream>) openInputStreamAndReturnError:(NSError **)error
{
  NSInputStream *ins = [NSInputStream inputStreamWithData:_data];
  [ins open];
  return ins;
}

-(CGImageSourceRef) createImageSourceAndReturnError:(NSError **)error
{
  return CGImageSourceCreateWithData((__bridge CFDataRef)self.data, NULL);
}

-(id<DataReference>)temporaryDuplicateFilteredBy:(DataReferenceFilter)filter withMIMEType:(NSString *)MIMEType error:(NSError **)error
{
  if (filter == nil) {
    return [MemoryDataReference.alloc initWithData:self.data ofMIMEType:MIMEType ?: self.MIMEType];
  }
  
  id<DataInputStream> inStream = [self openInputStreamAndReturnError:error];
  if (!inStream) {
    return nil;
  }
  
  NSOutputStream *outStream = [NSOutputStream outputStreamToMemory];
  if (!outStream) {
    return nil;
  }
  [outStream open];
  
  BOOL res = [DataReferences filterStreamsWithInput:inStream output:outStream usingFilter:filter error:error];
  [outStream close];
  
  if (!res) {
    return nil;
  }
  
  NSData *filteredData = [outStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];

  return [MemoryDataReference.alloc initWithData:filteredData ofMIMEType:MIMEType ?: self.MIMEType];
}

-(BOOL)writeToURL:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error
{
  return [_data writeToURL:url options:0 error:error];
}

@end
