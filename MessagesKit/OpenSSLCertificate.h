//
//  OpenSSLCertificate.h
//  MessagesKit
//
//  Created by Kevin Wooten on 12/13/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "OpenSSLKeyPair.h"


@class OpenSSLCertificateTrust;


NS_ASSUME_NONNULL_BEGIN


@interface OpenSSLCertificate : NSObject <NSCoding>

@property (nonatomic, readonly) X509 *pointer;

@property (nonatomic, readonly) NSData *encoded;

@property (nonatomic, readonly) NSString *subjectName;
@property (nonatomic, readonly) NSString *issuerName;
@property (nonatomic, readonly) OpenSSLPublicKey *publicKey;

@property (nonatomic, readonly) NSData *fingerprint;

@property (nonatomic, readonly) BOOL isSelfSigned;

-(nullable instancetype) initWithPEMEncodedData:(NSData *)pemData error:(NSError **)error;
-(nullable instancetype) initWithDEREncodedData:(NSData *)derData error:(NSError **)error;
-(instancetype) initWithCertPointer:(X509 *)cert;

+(nullable instancetype) certificateWithDEREncodedData:(NSData *)derData validatedWithTrust:(OpenSSLCertificateTrust *)trust error:(NSError **)error;
+(nullable instancetype) certificateWithDEREncodedData:(NSData *)derData error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
