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

@property(retain, nonatomic) NSData *data;

@end


@implementation MemoryDataReference

+(BOOL) supportsSecureCoding
{
  return YES;
}

-(instancetype) initWithData:(NSData *)data
{
  self = [self init];
  if (self) {
    self.data = data;
  }
  return self;
}

-(instancetype) initWithCoder:(NSCoder *)aDecoder
{
  self = [self init];
  if (self) {
    _data = [aDecoder decodeObjectOfClass:NSString.class forKey:@"data"];
  }
  return self;
}

-(void) encodeWithCoder:(NSCoder *)aCoder
{
  [aCoder encodeObject:_data forKey:@"data"];
}

-(NSNumber *)dataSizeAndReturnError:(NSError **)error
{
  return @(_data.length);
}

+(nullable instancetype) copyFrom:(id<DataReference>)source filteredBy:(nullable DataReferenceFilter)filter error:(NSError **)error
{
  
  // Detect simple duplication and share the immutable data
  if ([source isKindOfClass:MemoryDataReference.class] && filter == nil) {
    MemoryDataReference *sourceMem = (id)source;
    return [MemoryDataReference.alloc initWithData:sourceMem.data.copy];
  }
  
  NSData *data = [DataReferences filterReference:source intoMemoryUsingFilter:filter error:error];
  if (!data) {
    return nil;
  }
  
  return [MemoryDataReference.alloc initWithData:data];
}

-(id<DataInputStream>) openInputStreamAndReturnError:(NSError * _Nullable __autoreleasing *)error
{
  NSInputStream *ins = [NSInputStream inputStreamWithData:_data];
  [ins open];
  return ins;
}

-(BOOL) deleteAndReturnError:(NSError * _Nullable __autoreleasing *)error
{
  return YES;
}

-(id<DataReference>)temporaryDuplicateFilteredBy:(DataReferenceFilter)filter error:(NSError * _Nullable __autoreleasing *)error
{
  return [MemoryDataReference copyFrom:self filteredBy:filter error:error];
}

@end
