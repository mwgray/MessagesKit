//
//  RTOpenSSLKeyPair.h
//  ReTxt
//
//  Created by Kevin Wooten on 1/6/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "RTOpenSSL.h"


NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM(NSInteger, RTDigitalSignaturePadding) {
  RTDigitalSignaturePaddingPKCS1,
  RTDigitalSignaturePaddingPSS32,
};


@interface RTOpenSSLPublicKey : NSObject <NSCoding>

@property (nonatomic, readonly) EVP_PKEY *pointer;

@property (nonatomic, readonly) NSData *encoded;
@property (nonatomic, readonly) NSData *fingerprint;

-(instancetype) initWithKeyPointer:(EVP_PKEY *)pointer;

-(nullable NSData *) encryptData:(NSData *)clearText error:(NSError **)error;
-(BOOL) verifyData:(NSData *)data againstSignature:(NSData *)signature withPadding:(RTDigitalSignaturePadding)padding result:(BOOL *)result error:(NSError **)error NS_REFINED_FOR_SWIFT;

@end


@interface RTOpenSSLPrivateKey : NSObject <NSCoding>

@property (nonatomic, readonly) EVP_PKEY *pointer;

@property (nonatomic, readonly) NSData *encoded;

-(instancetype) initWithKeyPointer:(EVP_PKEY *)pointer;

-(nullable NSData *) decryptData:(NSData *)cipherText error:(NSError **)error;
-(nullable NSData *) signData:(NSData *)data withPadding:(RTDigitalSignaturePadding)padding error:(NSError **)error;

@end


@interface RTOpenSSLKeyPair : NSObject <NSCoding>

@property (nonatomic, readonly) RTOpenSSLPublicKey *publicKey;
@property (nonatomic, readonly) RTOpenSSLPrivateKey *privateKey;

+(nullable instancetype) generateKeyPairWithKeySize:(int)keySize error:(NSError **)error;
+(nullable instancetype) importPKCS12:(NSData *)pkcs12Data withPassphrase:(NSString *)passphrase error:(NSError **)error;

-(instancetype) initWithKeyPointer:(EVP_PKEY *)keyPointer;

@end


NS_ASSUME_NONNULL_END
