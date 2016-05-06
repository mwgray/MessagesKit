//
//  DataReference.h
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

@import Foundation;


NS_ASSUME_NONNULL_BEGIN


@protocol DataInputStream <NSObject>

@property(readonly, nonatomic) NSUInteger availableBytes;

-(BOOL) readBytesOfMaxLength:(NSUInteger)maxLength intoBuffer:(UInt8 *)buffer bytesRead:(NSUInteger *)bytesRead error:(NSError **)error;

@end


@protocol DataOutputStream <NSObject>

-(BOOL) writeBytesFromBuffer:(const UInt8 *)buffer length:(NSUInteger)length error:(NSError **)error;

@end


typedef BOOL (^DataReferenceFilter)(id<DataInputStream>, id<DataOutputStream>, NSError **);


@protocol DataReference <NSObject, NSSecureCoding>

-(nullable NSNumber *) dataSizeAndReturnError:(NSError **)error;

-(nullable id<DataInputStream>) openInputStreamAndReturnError:(NSError **)error;

-(BOOL) deleteAndReturnError:(NSError **)error;

-(nullable id<DataReference>) temporaryDuplicateFilteredBy:(nullable DataReferenceFilter)filter error:(NSError **)error NS_REFINED_FOR_SWIFT;

@end




@interface NSInputStream (DataReference) <DataInputStream>

@end



@interface NSOutputStream (DataReference) <DataOutputStream>

@end



NS_ASSUME_NONNULL_END
