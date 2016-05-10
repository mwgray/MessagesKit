//
//  OpenSSLKeyPair.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/6/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "OpenSSL.h"


NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM(NSInteger, DigitalSignaturePadding) {
  DigitalSignaturePaddingPKCS1,
  DigitalSignaturePaddingPSS32,
};


@interface OpenSSLPublicKey : NSObject <NSCoding>

@property (nonatomic, readonly) EVP_PKEY *pointer;

@property (nonatomic, readonly) NSData *encoded;
@property (nonatomic, readonly) NSData *fingerprint;

-(instancetype) initWithKeyPointer:(EVP_PKEY *)pointer;

-(nullable NSData *) encryptData:(NSData *)clearText error:(NSError **)error;
-(BOOL) verifyData:(NSData *)data againstSignature:(NSData *)signature withPadding:(DigitalSignaturePadding)padding result:(BOOL *)result error:(NSError **)error NS_REFINED_FOR_SWIFT;

@end


@interface OpenSSLPrivateKey : NSObject <NSCoding>

@property (nonatomic, readonly) EVP_PKEY *pointer;

@property (nonatomic, readonly) NSData *encoded;

-(instancetype) initWithKeyPointer:(EVP_PKEY *)pointer;

-(nullable NSData *) decryptData:(NSData *)cipherText error:(NSError **)error;
-(nullable NSData *) signData:(NSData *)data withPadding:(DigitalSignaturePadding)padding error:(NSError **)error;

@end


@interface OpenSSLKeyPair : NSObject <NSCoding>

@property (nonatomic, readonly) OpenSSLPublicKey *publicKey;
@property (nonatomic, readonly) OpenSSLPrivateKey *privateKey;

+(nullable instancetype) generateKeyPairWithKeySize:(int)keySize error:(NSError **)error;
+(nullable instancetype) importPKCS12:(NSData *)pkcs12Data withPassphrase:(NSString *)passphrase error:(NSError **)error;

-(instancetype) initWithKeyPointer:(EVP_PKEY *)keyPointer;

@end


NS_ASSUME_NONNULL_END
