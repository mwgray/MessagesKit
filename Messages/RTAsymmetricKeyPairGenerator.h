//
//  RTAsymmetricKeyPairGenerator.h
//  ReTxt
//
//  Created by Kevin Wooten on 11/25/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTOpenSSLKeyPair.h"
#import "RTOpenSSLCertificate.h"
#import "RTOpenSSLCertificationRequest.h"


NS_ASSUME_NONNULL_BEGIN


typedef NS_OPTIONS(NSInteger, RTAsymmetricKeyPairUsage) {
  RTAsymmetricKeyPairUsageKeyEncipherment   = 1 << 0,
  RTAsymmetricKeyPairUsageDigitalSignature  = 1 << 1,
  RTAsymmetricKeyPairUsageNonRepudiation    = 1 << 2,
};


@interface RTAsymmetricIdentity : NSObject <NSCoding>

@property (nonatomic, retain) RTOpenSSLCertificate *certificate;
@property (nonatomic, retain) RTOpenSSLPrivateKey *privateKey;

@property (nonatomic, readonly) RTOpenSSLPublicKey *publicKey;
@property (nonatomic, readonly) RTOpenSSLKeyPair *keyPair;

-(instancetype) initWithCertificate:(RTOpenSSLCertificate *)certificate privateKey:(RTOpenSSLPrivateKey *)privateKey;

-(nullable NSData *) exportPKCS12WithPassphrase:(NSString *)passphrase error:(NSError **)error;
+(nullable instancetype) importPKCS12:(NSData *)pkcs12 withPassphrase:(NSString *)passphrase error:(NSError **)error;

-(BOOL) privateKeyMatchesCertificate:(RTOpenSSLCertificate *)certificate;

@end


@interface RTAsymmetricIdentityRequest : NSObject

@property (nonatomic, retain) RTOpenSSLCertificationRequest *certificateSigningRequest;
@property (nonatomic, retain) RTOpenSSLPrivateKey *privateKey;

-(RTAsymmetricIdentity *) buildIdentityWithCertificate:(RTOpenSSLCertificate *)certificate;

@end


@interface RTAsymmetricKeyPairGenerator : NSObject

+(nullable EVP_PKEY *) generateRSAKeyPairWithKeySize:(NSUInteger)keySize error:(NSError **)error;

+(nullable RTAsymmetricIdentityRequest *) generateIdentityRequestNamed:(NSString *)name
                                                           withKeySize:(NSUInteger)keySize
                                                                 usage:(RTAsymmetricKeyPairUsage)usage
                                                                 error:(NSError **)error;

+(nullable RTAsymmetricIdentity *) generateSelfSignedIdentityNamed:(NSDictionary<NSString *, NSString *> *)certName
                                                       withKeySize:(NSUInteger)keySize
                                                             usage:(RTAsymmetricKeyPairUsage)usage
                                                             error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
