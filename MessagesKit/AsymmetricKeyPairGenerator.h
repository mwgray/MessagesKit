//
//  AsymmetricKeyPairGenerator.h
//  MessagesKit
//
//  Created by Kevin Wooten on 11/25/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "OpenSSLKeyPair.h"
#import "OpenSSLCertificate.h"
#import "OpenSSLCertificationRequest.h"


NS_ASSUME_NONNULL_BEGIN


typedef NS_OPTIONS(NSInteger, AsymmetricKeyPairUsage) {
  AsymmetricKeyPairUsageKeyEncipherment   = 1 << 0,
  AsymmetricKeyPairUsageDigitalSignature  = 1 << 1,
  AsymmetricKeyPairUsageNonRepudiation    = 1 << 2,
};


@interface AsymmetricIdentity : NSObject <NSCoding>

@property (nonatomic, retain) OpenSSLCertificate *certificate;
@property (nonatomic, retain) OpenSSLPrivateKey *privateKey;

@property (nonatomic, readonly) OpenSSLPublicKey *publicKey;
@property (nonatomic, readonly) OpenSSLKeyPair *keyPair;

-(instancetype) initWithCertificate:(OpenSSLCertificate *)certificate privateKey:(OpenSSLPrivateKey *)privateKey;

-(nullable NSData *) exportPKCS12WithPassphrase:(NSString *)passphrase error:(NSError **)error;
+(nullable instancetype) importPKCS12:(NSData *)pkcs12 withPassphrase:(NSString *)passphrase error:(NSError **)error;

-(BOOL) privateKeyMatchesCertificate:(OpenSSLCertificate *)certificate;

@end


@interface AsymmetricIdentityRequest : NSObject

@property (nonatomic, retain) OpenSSLCertificationRequest *certificateSigningRequest;
@property (nonatomic, retain) OpenSSLPrivateKey *privateKey;

-(AsymmetricIdentity *) buildIdentityWithCertificate:(OpenSSLCertificate *)certificate;

@end


@interface AsymmetricKeyPairGenerator : NSObject

+(nullable EVP_PKEY *) generateRSAKeyPairWithKeySize:(NSUInteger)keySize error:(NSError **)error;

+(nullable AsymmetricIdentityRequest *) generateIdentityRequestNamed:(NSString *)name
                                                           withKeySize:(NSUInteger)keySize
                                                                 usage:(AsymmetricKeyPairUsage)usage
                                                                 error:(NSError **)error;

+(nullable AsymmetricIdentity *) generateSelfSignedIdentityNamed:(NSDictionary<NSString *, NSString *> *)certName
                                                       withKeySize:(NSUInteger)keySize
                                                             usage:(AsymmetricKeyPairUsage)usage
                                                             error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
