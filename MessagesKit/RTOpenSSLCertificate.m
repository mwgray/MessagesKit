//
//  RTOpenSSLCertificate.m
//  ReTxt
//
//  Created by Kevin Wooten on 12/13/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTOpenSSLCertificate.h"

#import "RTOpenSSLCertificateSet.h"
#import "RTOpenSSLCertificateValidator.h"
#import "RTOpenSSL.h"
#import "RTX509Utils.h"
#import "NSArray+Utils.h"
#import "NSData+CommonDigest.h"
#import "NSString+Utils.h"

@import openssl;


static NSCache *certificateCache;


@interface RTOpenSSLCertificate ()

@property (nonatomic, assign) X509 *pointer;

@end


@implementation RTOpenSSLCertificate

+(void) initialize
{
  [RTOpenSSL go];
  certificateCache = [NSCache new];
}

+(instancetype) certificateWithDEREncodedData:(NSData *)derData error:(NSError **)error
{
  RTOpenSSLCertificate *cert = [certificateCache objectForKey:derData];
  if (!cert) {
    cert = [[RTOpenSSLCertificate alloc] initWithDEREncodedData:derData error:error];
    [certificateCache setObject:cert forKey:derData cost:derData.length];
  }
  return cert;
}

+(instancetype) certificateWithDEREncodedData:(NSData *)derData validatedWithTrust:(RTOpenSSLCertificateTrust *)trust error:(NSError **)error;
{
  RTOpenSSLCertificate *certificate = [RTOpenSSLCertificate certificateWithDEREncodedData:derData
                                                                                    error:error];
  if (!certificate) {
    return nil;
  }
  
  RTOpenSSLCertificateValidator *validator = [[RTOpenSSLCertificateValidator alloc] initWithRootCertificates:trust.roots
                                                                                                       error:error];
  if (!validator) {
    return nil;
  }
  
  BOOL valid = NO;
  if (![validator validate:certificate chain:trust.intermediates result:&valid error:error]) {
    return nil;
  }
  
  return valid ? certificate : nil;
}

-(instancetype) initWithCertPointer:(X509 *)cert
{
  self = [super init];
  if (self) {
    
    _pointer = cert;
    CRYPTO_add(&_pointer->references, 1, CRYPTO_LOCK_X509);
    
  }
  return self;
}

-(instancetype) initWithPEMEncodedData:(NSData *)pemData error:(NSError **)error
{
  self = [super init];
  if (self) {

    BIO *pemBIO = BIO_new_mem_buf((void *)pemData.bytes, (int)pemData.length);
    
    _pointer = PEM_read_bio_X509(pemBIO, NULL, NULL, NULL);
    if (_pointer == NULL) {
      BIO_free_all(pemBIO);
      RT_RETURN_OPENSSL_ERROR(CertificateInvalid, nil);
    }
    
    BIO_free_all(pemBIO);
  }
  return self;
}

-(instancetype) initWithDEREncodedData:(NSData *)derData error:(NSError **)error
{
  self = [super init];
  if (self) {
    
    const unsigned char *derDataBytes = derData.bytes;
    if (d2i_X509(&_pointer, &derDataBytes, derData.length) <= 0) {
      RT_RETURN_OPENSSL_ERROR(CertificateInvalid, nil);
    }
    
  }
  return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
  self = [super init];
  if (self) {
    NSData *encoded = [aDecoder decodeObjectOfClass:NSData.class forKey:@"der"];
    const unsigned char *encodedBytes = encoded.bytes;
    if (d2i_X509(&_pointer, &encodedBytes, encoded.length) <= 0) {
      return nil;
    }
  }
  return self;
}

-(void) encodeWithCoder:(NSCoder *)aCoder
{
  [aCoder encodeObject:self.encoded forKey:@"der"];
}

-(void) dealloc
{
  X509_free(_pointer);
  _pointer = NULL;
}

-(X509 *) pointer
{
  return _pointer;
}

-(NSData *)encoded
{
  unsigned char *certBytes = NULL;
  int certBytesLen = i2d_X509(_pointer, &certBytes);
  if (certBytesLen <= 0) {
    return nil;
  }
  
  return [NSData dataWithBytesNoCopy:certBytes
                              length:certBytesLen
                        freeWhenDone:YES];
}

-(NSString *)subjectName
{
  X509_NAME *subjectNameInternal = X509_get_subject_name(_pointer);
  
  BIO *subjectNameBio = BIO_new(BIO_s_mem());
  if (X509_NAME_print_ex(subjectNameBio, subjectNameInternal, 0, XN_FLAG_RFC2253) <= 0) {
    return nil;
  }
  
  char *subjectNameData = NULL;
  long subjectNameLength = BIO_get_mem_data(subjectNameBio, &subjectNameData);
  
  NSString * subjectName = [NSString stringWithData:[NSData dataWithBytes:subjectNameData length:subjectNameLength]
                                           encoding:NSUTF8StringEncoding];
  
  BIO_free_all(subjectNameBio);
  
  return subjectName;
}

-(NSString *)issuerName
{
  X509_NAME *issuerNameInternal = X509_get_issuer_name(_pointer);
  
  BIO *issuerNameBio = BIO_new(BIO_s_mem());
  if (X509_NAME_print_ex(issuerNameBio, issuerNameInternal, 0, XN_FLAG_RFC2253) <= 0) {
    return nil;
  }
  
  char *issuerNameData = NULL;
  long issuerNameLength = BIO_get_mem_data(issuerNameBio, &issuerNameData);
  
  NSString * issuerName = [NSString stringWithData:[NSData dataWithBytes:issuerNameData length:issuerNameLength]
                                           encoding:NSUTF8StringEncoding];
  
  BIO_free_all(issuerNameBio);
  
  return issuerName;
}

-(RTOpenSSLPublicKey *)publicKey
{
  EVP_PKEY *pubkey = X509_get_pubkey(_pointer);
  
  RTOpenSSLPublicKey *publicKey = [[RTOpenSSLPublicKey alloc] initWithKeyPointer:pubkey];
  
  EVP_PKEY_free(pubkey);
  
  return publicKey;
}

-(NSData *) fingerprint
{
  unsigned int fpLen = EVP_MD_block_size(EVP_sha1());
  unsigned char fpBytes[fpLen];
  if (X509_digest(_pointer, EVP_sha1(), fpBytes, &fpLen) <= 0) {
    return nil;
  }
  return [NSData dataWithBytes:fpBytes length:fpLen];
}

-(BOOL)isSelfSigned
{
  EVP_PKEY *pubkey = X509_get_pubkey(_pointer);
  
  int res = X509_verify(_pointer, pubkey);
  
  EVP_PKEY_free(pubkey);
  
  return res == 1;
}

@end
