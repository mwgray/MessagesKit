//
//  OpenSSLCertificateValidator.m
//  MessagesKit
//
//  Created by Kevin Wooten on 12/13/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "OpenSSLCertificateValidator.h"

#import "OpenSSL.h"
#import "OpenSSLCertificate.h"

@import openssl;


@implementation OpenSSLCertificateTrust

-(instancetype) initWithRoots:(OpenSSLCertificateSet *)roots intermediates:(OpenSSLCertificateSet *)intermediates
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
  OpenSSLCertificateSet *roots = [[OpenSSLCertificateSet alloc] initWithPEMEncodedData:rootsData error:error];
  if (!roots) {
    return nil;
  }
  
  OpenSSLCertificateSet *intermediates = [[OpenSSLCertificateSet alloc] initWithPEMEncodedData:intermediatesData error:error];
  if (!intermediates) {
    return nil;
  }
  
  return [self initWithRoots:roots intermediates:intermediates];
}

@end




@interface OpenSSLCertificateValidator ()

@property (nonatomic, assign) X509_STORE *pointer;

@end


@implementation OpenSSLCertificateValidator

+(void)initialize
{
  [OpenSSL go];
}

-(instancetype) initWithRootCertificatesInFile:(NSString *)rootCertsFile error:(NSError **)error
{
  self = [super init];
  if (self) {
    _pointer = X509_STORE_new();
    if (X509_STORE_load_locations(_pointer, rootCertsFile.UTF8String, NULL) <= 0) {
      MK_RETURN_OPENSSL_ERROR(CertificateStoreInvalid, nil);
    }
  }
  return self;
}

-(nullable instancetype) initWithRootCertificates:(OpenSSLCertificateSet *)rootCerts error:(NSError **)error
{
  self = [super init];
  if (self) {
    _pointer = X509_STORE_new();
    for (OpenSSLCertificate *cert in rootCerts) {
      if (X509_STORE_add_cert(_pointer, cert.pointer) <= 0) {
        MK_RETURN_OPENSSL_ERROR(CertificateStoreInvalid, nil);
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

-(BOOL)validate:(OpenSSLCertificate *)certificate chain:(OpenSSLCertificateSet *)chain error:(NSError **)error
{
  X509_STORE_CTX *ctx = X509_STORE_CTX_new();
  X509_STORE_CTX_init(ctx, _pointer, certificate.pointer, chain.pointer);
  
  BOOL valid = X509_verify_cert(ctx) == 1;
  
  if (!valid) {
    if (error) {
      int errorCode = X509_STORE_CTX_get_error(ctx);
      *error = [NSError errorWithDomain:OpenSSLErrorDomain
                                   code:OpenSSLErrorCertificateInvalid
                               userInfo:@{@"OpenSSLErrorCode": @(errorCode),
                                          @"OpenSSLError":[NSString stringWithCString:X509_verify_cert_error_string(errorCode)
                                                                             encoding:NSUTF8StringEncoding]}];
    }
  }

  X509_STORE_CTX_free(ctx);
  
  return valid;
}

@end
