//
//  TBase+Utils.m
//  MessagesKit
//
//  Created by Kevin Wooten on 5/14/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "TBase+Utils.h"

#import <Thrift/TMemoryBuffer.h>
#import <Thrift/TBinaryProtocol.h>


@implementation TBaseUtils

+(NSData *) serializeToData:(id<TBase>)obj error:(NSError *__autoreleasing *)error
{
  TMemoryBuffer *buffer = [TMemoryBuffer new];
  TBinaryProtocol *protocol = [[TBinaryProtocolFactory sharedFactory] newProtocolOnTransport:buffer];
  [obj write:protocol error:error];
  return buffer.buffer;
}

+(id) deserialize:(id<TBase>)obj fromData:(NSData *)data error:(NSError *__autoreleasing *)error
{

  TMemoryBuffer *buffer = [[TMemoryBuffer alloc] initWithData:data];
  TBinaryProtocol *protocol = [[TBinaryProtocolFactory sharedFactory] newProtocolOnTransport:buffer];
  [obj read:protocol error:error];
  return obj;
}

+(NSString *) serializeToBase64String:(id<TBase>)obj error:(NSError *__autoreleasing *)error
{
  return [[self serializeToData:obj error:error] base64EncodedStringWithOptions:0];
}

+(id) deserialize:(id<TBase>)obj fromBase64String:(NSString *)data error:(NSError *__autoreleasing *)error
{
  return [self deserialize:obj fromData:[[NSData alloc] initWithBase64EncodedString:data options:0] error:error];
}

@end
