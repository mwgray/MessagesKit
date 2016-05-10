//
//  AsymmetricKeyPairGenerator.m
//  MessagesKit
//
//  Created by Kevin Wooten on 11/25/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "AsymmetricKeyPairGenerator.h"

#import "OpenSSLCertificate.h"
#import "OpenSSL.h"
#import "X509Utils.h"

#import "NSDate+Utils.h"

@import openssl;


NSString *translateUsage(AsymmetricKeyPairUsage usage)
{
  NSMutableArray *usageArray = [NSMutableArray new];
  if (usage & AsymmetricKeyPairUsageKeyEncipherment) {
    [usageArray addObject:@"keyEncipherment"];
  }
  else if (usage & AsymmetricKeyPairUsageDigitalSignature) {
    [usageArray addObject:@"digitalSignature"];
  }
  else if (usage & AsymmetricKeyPairUsageNonRepudiation) {
    [usageArray addObject:@"nonRepudiation"];
  }
  
  return [usageArray componentsJoinedByString:@", "];
}


@implementation AsymmetricKeyPairGenerator

+(void) initialize
{
  [OpenSSL go];
}

+(EVP_PKEY *) generateRSAKeyPairWithKeySize:(NSUInteger)keySize error:(NSError **)error
{
  EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_RSA, NULL);
  if (ctx == NULL) {
    _RETURN_OPENSSL_ERROR(ContextAllocFailed, NULL);
  }
  
  EVP_PKEY *keyPair = ^EVP_PKEY *{

    if (EVP_PKEY_keygen_init(ctx) <= 0) {
      _RETURN_OPENSSL_ERROR(KeyGenInitFailed, NULL);
    }
    
    if (EVP_PKEY_CTX_set_rsa_keygen_bits(ctx, (int)keySize) <= 0) {
      _RETURN_OPENSSL_ERROR(KeyGenBitsFailed, NULL);
    }
    
    EVP_PKEY *keyPair = NULL;
    if (EVP_PKEY_keygen(ctx, &keyPair) <= 0) {
      _RETURN_OPENSSL_ERROR(KeyGenFailed, NULL);
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
    _RETURN_OPENSSL_ERROR(ContextAllocFailed, NULL);
  }
  
  EVP_PKEY *keyPair = ^EVP_PKEY *{
    
    if (EVP_PKEY_keygen_init(ctx) <= 0) {
      _RETURN_OPENSSL_ERROR(KeyGenInitFailed, NULL);
    }
    
    EVP_PKEY *keyPair = NULL;
    if (EVP_PKEY_keygen(ctx, &keyPair) <= 0) {
      _RETURN_OPENSSL_ERROR(KeyGenFailed, NULL);
    }
    
    return keyPair;
    
  }();
  
  EVP_PKEY_CTX_free(ctx);
  
  return keyPair;
}

+(AsymmetricIdentityRequest *) generateIdentityRequestNamed:(NSString *)name
                                                  withKeySize:(NSUInteger)keySize
                                                        usage:(AsymmetricKeyPairUsage)usage
                                                        error:(NSError **)error
{
  AsymmetricIdentityRequest *ident = [AsymmetricIdentityRequest new];
  
  // Generate & encode private key
  
  EVP_PKEY *keyPair = [self generateRSAKeyPairWithKeySize:keySize error:error];
  if (!keyPair) {
    return nil;
  }
  
  ident.privateKey = [[OpenSSLPrivateKey alloc] initWithKeyPointer:keyPair];
  
  // Generate CSR
  
  X509_REQ *req = X509_REQ_new();
  if (!req) {
    _RETURN_OPENSSL_ERROR(CertificateRequestEncodeFailed, nil);
  }

  // Add subject name
  X509_NAME *subjectName = [X509Utils nameWithDictionary:@{@"CN":name}];
  if (!subjectName) {
    _RETURN_OPENSSL_ERROR(CertificateRequestEncodeFailed, nil);
  }

  if (!X509_REQ_set_subject_name(req, subjectName)) {
    _RETURN_OPENSSL_ERROR(CertificateRequestEncodeFailed, nil);
  }
  
  X509_NAME_free(subjectName);
  
  // Add public key
  if (!X509_REQ_set_pubkey(req, keyPair)) {
    _RETURN_OPENSSL_ERROR(CertificateRequestEncodeFailed, nil);
  }
  
  // Add key usage extension
  if (![X509Utils addExtenstionNamed:SN_key_usage
                        withValue:translateUsage(usage)
                        toRequest:req]) {
    _RETURN_OPENSSL_ERROR(CertificateRequestEncodeFailed, nil);
  }
  
  // Sign request
  if (!X509_REQ_sign(req, keyPair, EVP_sha1())) {
    _RETURN_OPENSSL_ERROR(CertificateRequestEncodeFailed, nil);
  }
  
  ident.certificateSigningRequest = [[OpenSSLCertificationRequest alloc] initWithRequestPointer:req];
  
  // Cleanup
  EVP_PKEY_free(keyPair);
  
  return ident;
}

+(AsymmetricIdentity *) generateSelfSignedIdentityNamed:(NSDictionary *)certName
                                              withKeySize:(NSUInteger)keySize
                                                    usage:(AsymmetricKeyPairUsage)usage
                                                    error:(NSError **)error
{
  // Generate the key pair
  
  EVP_PKEY *keyPair = [self generateRSAKeyPairWithKeySize:keySize error:error];
  if (!keyPair) {
    _RETURN_OPENSSL_ERROR(PrivateKeyEncodeFailed, nil);
  }

  // Generate self signed certificate
  
  X509 *cert = [X509Utils generateSelfSignedCertificateNamed:certName
                                                    forKeyPair:keyPair
                                                      keyUsage:translateUsage(usage)
                                                         error:error];
  if (!cert) {
    EVP_PKEY_free(keyPair);
    _RETURN_OPENSSL_ERROR(CertificateEncodeFailed, nil);
  }
  
  
  // Build the identity
  
  AsymmetricIdentity *ident = [[AsymmetricIdentity alloc] initWithCertificate:[[OpenSSLCertificate alloc] initWithCertPointer:cert]
                                                                       privateKey:[[OpenSSLPrivateKey alloc] initWithKeyPointer:keyPair]];
  
  // Clean up
  X509_free(cert);
  EVP_PKEY_free(keyPair);

  return ident;
}

@end



@implementation AsymmetricIdentityRequest

-(AsymmetricIdentity *)buildIdentityWithCertificate:(OpenSSLCertificate *)certificate
{
  AsymmetricIdentity *identity = [AsymmetricIdentity new];
  identity.certificate = certificate;
  identity.privateKey = self.privateKey;
  return identity;
}

@end



@implementation AsymmetricIdentity

-(instancetype) initWithCertificate:(OpenSSLCertificate *)certificate privateKey:(OpenSSLPrivateKey *)privateKey
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
    
    _certificate = [aDecoder decodeObjectOfClass:OpenSSLCertificate.class forKey:@"certificate"];
    _privateKey = [aDecoder decodeObjectOfClass:OpenSSLPrivateKey.class forKey:@"privateKey"];
    
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
  return [X509Utils exportCertificate:_certificate.pointer andPrivateKey:_privateKey.pointer
                   inPKCS12PackageNamed:@"default" withPassphrase:passphrase error:error];
}

+(instancetype) importPKCS12:(NSData *)pkcs12Data withPassphrase:(NSString *)passphrase error:(NSError **)error
{
  const unsigned char *pkcs12Bytes = pkcs12Data.bytes;
  
  PKCS12 *pkcs12 = d2i_PKCS12(NULL, &pkcs12Bytes, pkcs12Data.length);
  if (pkcs12 == NULL) {
    _RETURN_OPENSSL_ERROR(PKCS12ImportFailed, FALSE);
  }
  
  EVP_PKEY *privateKey = NULL;
  X509 *cert = NULL;
  if (PKCS12_parse(pkcs12, passphrase.UTF8String, &privateKey, &cert, NULL) <= 0) {
    PKCS12_free(pkcs12);
    _RETURN_OPENSSL_ERROR(PKCS12ImportFailed, FALSE);
  }
  
  AsymmetricIdentity *ident = [[AsymmetricIdentity alloc] initWithCertificate:[[OpenSSLCertificate alloc] initWithCertPointer:cert]
                                                                       privateKey:[[OpenSSLPrivateKey alloc] initWithKeyPointer:privateKey]];
  
  X509_free(cert);
  EVP_PKEY_free(privateKey);
  PKCS12_free(pkcs12);
  
  return ident;
}

-(BOOL) privateKeyMatchesCertificate:(OpenSSLCertificate *)certificate
{
  return EVP_PKEY_cmp(certificate.publicKey.pointer, _privateKey.pointer);
}

-(OpenSSLPublicKey *)publicKey
{
  return _certificate.publicKey;
}

-(OpenSSLKeyPair *)keyPair
{
  return [[OpenSSLKeyPair alloc] initWithKeyPointer:_privateKey.pointer];
}

@end
