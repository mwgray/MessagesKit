//
//  RTAsymmetricKeyPairGenerator.m
//  ReTxt
//
//  Created by Kevin Wooten on 11/25/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTAsymmetricKeyPairGenerator.h"

#import "RTOpenSSLCertificate.h"
#import "RTOpenSSL.h"
#import "RTX509Utils.h"

#import "NSDate+Utils.h"

@import openssl;


NSString *translateUsage(RTAsymmetricKeyPairUsage usage)
{
  NSMutableArray *usageArray = [NSMutableArray new];
  if (usage & RTAsymmetricKeyPairUsageKeyEncipherment) {
    [usageArray addObject:@"keyEncipherment"];
  }
  else if (usage & RTAsymmetricKeyPairUsageDigitalSignature) {
    [usageArray addObject:@"digitalSignature"];
  }
  else if (usage & RTAsymmetricKeyPairUsageNonRepudiation) {
    [usageArray addObject:@"nonRepudiation"];
  }
  
  return [usageArray componentsJoinedByString:@", "];
}


@implementation RTAsymmetricKeyPairGenerator

+(void) initialize
{
  [RTOpenSSL go];
}

+(EVP_PKEY *) generateRSAKeyPairWithKeySize:(NSUInteger)keySize error:(NSError **)error
{
  EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, NULL);
  if (ctx == NULL) {
    RT_RETURN_OPENSSL_ERROR(ContextAllocFailed, NULL);
  }
  
  EVP_PKEY *keyPair = ^EVP_PKEY *{

    if (EVP_PKEY_keygen_init(ctx) <= 0) {
      RT_RETURN_OPENSSL_ERROR(KeyGenInitFailed, NULL);
    }
    
    if (EVP_PKEY_CTX_set_rsa_keygen_bits(ctx, keySize) <= 0) {
      RT_RETURN_OPENSSL_ERROR(KeyGenBitsFailed, NULL);
    }
    
    EVP_PKEY *keyPair = NULL;
    if (EVP_PKEY_keygen(ctx, &keyPair) <= 0) {
      RT_RETURN_OPENSSL_ERROR(KeyGenFailed, NULL);
    }
    
    return keyPair;
    
  }();
  
  EVP_PKEY_CTX_free(ctx);
  
  return keyPair;
}

+(EVP_PKEY *) generateECKeyPairWithKeySize:(NSUInteger)keySize error:(NSError **)error
{
  EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_EC, NULL);
  if (ctx == NULL) {
    RT_RETURN_OPENSSL_ERROR(ContextAllocFailed, NULL);
  }
  
  EVP_PKEY *keyPair = ^EVP_PKEY *{
    
    if (EVP_PKEY_keygen_init(ctx) <= 0) {
      RT_RETURN_OPENSSL_ERROR(KeyGenInitFailed, NULL);
    }
    
    EVP_PKEY *keyPair = NULL;
    if (EVP_PKEY_keygen(ctx, &keyPair) <= 0) {
      RT_RETURN_OPENSSL_ERROR(KeyGenFailed, NULL);
    }
    
    return keyPair;
    
  }();
  
  EVP_PKEY_CTX_free(ctx);
  
  return keyPair;
}

+(RTAsymmetricIdentityRequest *) generateIdentityRequestNamed:(NSString *)name
                                                  withKeySize:(NSUInteger)keySize
                                                        usage:(RTAsymmetricKeyPairUsage)usage
                                                        error:(NSError **)error
{
  RTAsymmetricIdentityRequest *ident = [RTAsymmetricIdentityRequest new];
  
  // Generate & encode private key
  
  EVP_PKEY *keyPair = [self generateRSAKeyPairWithKeySize:keySize error:error];
  if (!keyPair) {
    return nil;
  }
  
  ident.privateKey = [[RTOpenSSLPrivateKey alloc] initWithKeyPointer:keyPair];
  
  // Generate CSR
  
  X509_REQ *req = X509_REQ_new();
  if (!req) {
    RT_RETURN_OPENSSL_ERROR(CertificateRequestEncodeFailed, nil);
  }

  // Add subject name
  X509_NAME *subjectName = [RTX509Utils nameWithDictionary:@{@"CN":name}];
  if (!subjectName) {
    RT_RETURN_OPENSSL_ERROR(CertificateRequestEncodeFailed, nil);
  }

  if (!X509_REQ_set_subject_name(req, subjectName)) {
    RT_RETURN_OPENSSL_ERROR(CertificateRequestEncodeFailed, nil);
  }
  
  X509_NAME_free(subjectName);
  
  // Add public key
  if (!X509_REQ_set_pubkey(req, keyPair)) {
    RT_RETURN_OPENSSL_ERROR(CertificateRequestEncodeFailed, nil);
  }
  
  // Add key usage extension
  if (![RTX509Utils addExtenstionNamed:SN_key_usage
                        withValue:translateUsage(usage)
                        toRequest:req]) {
    RT_RETURN_OPENSSL_ERROR(CertificateRequestEncodeFailed, nil);
  }
  
  // Sign request
  if (!X509_REQ_sign(req, keyPair, EVP_sha1())) {
    RT_RETURN_OPENSSL_ERROR(CertificateRequestEncodeFailed, nil);
  }
  
  ident.certificateSigningRequest = [[RTOpenSSLCertificationRequest alloc] initWithRequestPointer:req];
  
  // Cleanup
  EVP_PKEY_free(keyPair);
  
  return ident;
}

+(RTAsymmetricIdentity *) generateSelfSignedIdentityNamed:(NSDictionary *)certName
                                              withKeySize:(NSUInteger)keySize
                                                    usage:(RTAsymmetricKeyPairUsage)usage
                                                    error:(NSError **)error
{
  // Generate the key pair
  
  EVP_PKEY *keyPair = [self generateRSAKeyPairWithKeySize:keySize error:error];
  if (!keyPair) {
    RT_RETURN_OPENSSL_ERROR(PrivateKeyEncodeFailed, nil);
  }

  // Generate self signed certificate
  
  X509 *cert = [RTX509Utils generateSelfSignedCertificateNamed:certName
                                                    forKeyPair:keyPair
                                                      keyUsage:translateUsage(usage)
                                                         error:error];
  if (!cert) {
    EVP_PKEY_free(keyPair);
    RT_RETURN_OPENSSL_ERROR(CertificateEncodeFailed, nil);
  }
  
  
  // Build the identity
  
  RTAsymmetricIdentity *ident = [[RTAsymmetricIdentity alloc] initWithCertificate:[[RTOpenSSLCertificate alloc] initWithCertPointer:cert]
                                                                       privateKey:[[RTOpenSSLPrivateKey alloc] initWithKeyPointer:keyPair]];
  
  // Clean up
  X509_free(cert);
  EVP_PKEY_free(keyPair);

  return ident;
}

@end



@implementation RTAsymmetricIdentityRequest

-(RTAsymmetricIdentity *)buildIdentityWithCertificate:(RTOpenSSLCertificate *)certificate
{
  RTAsymmetricIdentity *identity = [RTAsymmetricIdentity new];
  identity.certificate = certificate;
  identity.privateKey = self.privateKey;
  return identity;
}

@end



@implementation RTAsymmetricIdentity

-(instancetype) initWithCertificate:(RTOpenSSLCertificate *)certificate privateKey:(RTOpenSSLPrivateKey *)privateKey
{
  self = [super init];
  if (self) {
    
    _certificate = certificate;
    _privateKey = privateKey;
    
  }
  return self;
}

-(instancetype) initWithCoder:(NSCoder *)aDecoder
{
  self = [super init];
  if (self) {
    
    _certificate = [aDecoder decodeObjectOfClass:RTOpenSSLCertificate.class forKey:@"certificate"];
    _privateKey = [aDecoder decodeObjectOfClass:RTOpenSSLPrivateKey.class forKey:@"privateKey"];
    
  }
  return self;
}

-(void) encodeWithCoder:(NSCoder *)aCoder
{
  [aCoder encodeObject:_certificate forKey:@"certificate"];
  [aCoder encodeObject:_privateKey forKey:@"privateKey"];
}

-(NSData *) exportPKCS12WithPassphrase:(NSString *)passphrase error:(NSError **)error
{
  return [RTX509Utils exportCertificate:_certificate.pointer andPrivateKey:_privateKey.pointer
                   inPKCS12PackageNamed:@"default" withPassphrase:passphrase error:error];
}

+(instancetype) importPKCS12:(NSData *)pkcs12Data withPassphrase:(NSString *)passphrase error:(NSError **)error
{
  const unsigned char *pkcs12Bytes = pkcs12Data.bytes;
  
  PKCS12 *pkcs12 = d2i_PKCS12(NULL, &pkcs12Bytes, pkcs12Data.length);
  if (pkcs12 == NULL) {
    RT_RETURN_OPENSSL_ERROR(PKCS12ImportFailed, FALSE);
  }
  
  EVP_PKEY *privateKey = NULL;
  X509 *cert = NULL;
  if (PKCS12_parse(pkcs12, passphrase.UTF8String, &privateKey, &cert, NULL) <= 0) {
    PKCS12_free(pkcs12);
    RT_RETURN_OPENSSL_ERROR(PKCS12ImportFailed, FALSE);
  }
  
  RTAsymmetricIdentity *ident = [[RTAsymmetricIdentity alloc] initWithCertificate:[[RTOpenSSLCertificate alloc] initWithCertPointer:cert]
                                                                       privateKey:[[RTOpenSSLPrivateKey alloc] initWithKeyPointer:privateKey]];
  
  X509_free(cert);
  EVP_PKEY_free(privateKey);
  PKCS12_free(pkcs12);
  
  return ident;
}

-(BOOL) privateKeyMatchesCertificate:(RTOpenSSLCertificate *)certificate
{
  return EVP_PKEY_cmp(certificate.publicKey.pointer, _privateKey.pointer);
}

-(RTOpenSSLPublicKey *)publicKey
{
  return _certificate.publicKey;
}

-(RTOpenSSLKeyPair *)keyPair
{
  return [[RTOpenSSLKeyPair alloc] initWithKeyPointer:_privateKey.pointer];
}

@end
