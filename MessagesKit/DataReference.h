//
//  DataReference.h
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

@import Foundation;
@import ImageIO;


NS_ASSUME_NONNULL_BEGIN


@protocol DataInputStream <NSObject>

@property(readonly, nonatomic) NSUInteger availableBytes;

-(BOOL) readBytesOfMaxLength:(NSUInteger)maxLength intoBuffer:(UInt8 *)buffer bytesRead:(NSUInteger *)bytesRead error:(NSError **)error;

-(void) close;

@end



@protocol DataOutputStream <NSObject>

-(BOOL) writeBytesFromBuffer:(const UInt8 *)buffer length:(NSUInteger)length error:(NSError **)error;

-(void) close;

@end



typedef BOOL (^DataReferenceFilter)(id<DataInputStream>, id<DataOutputStream>, NSError **);



@protocol DataReference <NSObject, NSCopying, NSCoding>

@property(readonly, nonatomic) NSString *MIMEType;

-(nullable NSNumber *) dataSizeAndReturnError:(NSError **)error;

-(nullable id<DataInputStream>) openInputStreamAndReturnError:(NSError **)error;
-(nullable CGImageSourceRef) createImageSourceAndReturnError:(NSError **)error;

-(nullable id<DataReference>) temporaryDuplicateFilteredBy:(nullable DataReferenceFilter)filter withMIMEType:(nullable NSString *)MIMEType error:(NSError **)error NS_REFINED_FOR_SWIFT;

-(BOOL) writeToURL:(NSURL *)url error:(NSError **)error;

@end


extern NSString * const DataReferenceErrorDomain;


@interface NSInputStream (DataReference) <DataInputStream>

@end



@interface NSOutputStream (DataReference) <DataOutputStream>

@end



NS_ASSUME_NONNULL_END
