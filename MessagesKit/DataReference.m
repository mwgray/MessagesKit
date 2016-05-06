//
//  DataReference.m
//  MessagesKit
//
//  Created by Kevin Wooten on 4/25/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "DataReference.h"


@implementation NSInputStream (DataReference)

-(NSUInteger) availableBytes
{
  return self.hasBytesAvailable ? 1 : 0;
}

-(BOOL) readBytesOfMaxLength:(NSUInteger)maxLength intoBuffer:(UInt8 *)buffer bytesRead:(NSUInteger *)bytesRead error:(NSError **)error
{
  NSInteger res = [self read:buffer maxLength:maxLength];
  if (res < 0) {
    if (error) {
      *error = self.streamError ? self.streamError : [NSError errorWithDomain:@"NSStreamErrorDomain"
                                                                         code:0
                                                                     userInfo:@{NSLocalizedDescriptionKey:@"Read failed"}];
    }
    return NO;
  }
  *bytesRead = res;
  return YES;
}

@end



@implementation NSOutputStream (DataReference)

-(BOOL) writeBytesFromBuffer:(const UInt8 *)buffer length:(NSUInteger)length error:(NSError * _Nullable __autoreleasing *)error
{
  NSUInteger written = [self write:buffer maxLength:length];
  if (written != length) {
    if (error) {
      *error = self.streamError ? self.streamError : [NSError errorWithDomain:@"NSStreamErrorDomain"
                                                                         code:0
                                                                     userInfo:@{NSLocalizedDescriptionKey:@"Write failed"}];
    }
    return NO;
  }
  return YES;
}

@end
