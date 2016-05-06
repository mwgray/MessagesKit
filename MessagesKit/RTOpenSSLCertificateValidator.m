//
//  RTOpenSSLCertificateValidator.m
//  MessagesKit
//
//  Created by Kevin Wooten on 12/13/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTOpenSSLCertificateValidator.h"

#import "RTOpenSSL.h"
#import "RTOpenSSLCertificate.h"

@import openssl;


@implementation RTOpenSSLCertificateTrust

-(instancetype) initWithRoots:(RTOpenSSLCertificateSet *)roots intermediates:(RTOpenSSLCertificateSet *)intermediates
{
  self = [super init];
  if (self) {
    _roots = roots;
    _intermediates = intermediates;
  }
  return self;
}

-(nullable instancetype) initWithPEMEncodedRoots:(NSData *)rootsData intermediates:(NSData *)intermediatesData error:(NSError **)error
{
  RTOpenSSLCertificateSet *roots = [[RTOpenSSLCertificateSet alloc] initWithPEMEncodedData:rootsData error:error];
  if (!roots) {
    return nil;
  }
  
  RTOpenSSLCertificateSet *intermediates = [[RTOpenSSLCertificateSet alloc] initWithPEMEncodedData:intermediatesData error:error];
  if (!intermediates) {
    return nil;
  }
  
  return [self initWithRoots:roots intermediates:intermediates];
}

@end




@interface RTOpenSSLCertificateValidator ()

@property (nonatomic, assign) X509_STORE *pointer;

@end


@implementation RTOpenSSLCertificateValidator

+(void)initialize
{
  [RTOpenSSL go];
}

-(instancetype) initWithRootCertificatesInFile:(NSString *)rootCertsFile error:(NSError **)error
{
  self = [super init];
  if (self) {
    _pointer = X509_STORE_new();
    if (X509_STORE_load_locations(_pointer, rootCertsFile.UTF8String, NULL) <= 0) {
      RT_RETURN_OPENSSL_ERROR(CertificateStoreInvalid, nil);
    }
  }
  return self;
}

-(nullable instancetype) initWithRootCertificates:(RTOpenSSLCertificateSet *)rootCerts error:(NSError **)error
{
  self = [super init];
  if (self) {
    _pointer = X509_STORE_new();
    for (RTOpenSSLCertificate *cert in rootCerts) {
      if (X509_STORE_add_cert(_pointer, cert.pointer) <= 0) {
        RT_RETURN_OPENSSL_ERROR(CertificateStoreInvalid, nil);
      }
    }
  }
  return self;
}

-(void)dealloc
{
  X509_STORE_free(_pointer);
  _pointer = NULL;
}

-(BOOL)validate:(RTOpenSSLCertificate *)certificate chain:(RTOpenSSLCertificateSet *)chain result:(BOOL *)result error:(NSError **)error
{
  X509_STORE_CTX *ctx = X509_STORE_CTX_new();
  X509_STORE_CTX_init(ctx, _pointer, certificate.pointer, chain.pointer);
  
  *result = X509_verify_cert(ctx) == 1;

  X509_STORE_CTX_free(ctx);
  
  return YES;
}

@end
