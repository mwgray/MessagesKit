//
//  RTOpenSSL.h
//  ReTxt
//
//  Created by Kevin Wooten on 11/1/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;


// Forward declarations
typedef struct evp_pkey_st EVP_PKEY;
typedef struct x509_st X509;
typedef struct stack_st_X509 X509_STACK;
typedef struct X509_req_st X509_REQ;
typedef struct x509_store_st X509_STORE;
typedef struct X509_name_st X509_NAME;
typedef struct X509_extension_st X509_EXTENSION;


@interface RTOpenSSL : NSObject

+(void) go;

@end


extern NSString *RTOpenSSLErrorDomain;


typedef NS_ENUM (int, RTOpenSSLError) {
  RTOpenSSLErrorContextAllocFailed,
  RTOpenSSLErrorPaddingFailed,
  RTOpenSSLErrorSaltLengthFailed,
  RTOpenSSLErrorSignatureFailed,
  RTOpenSSLErrorKeyGenInitFailed,
  RTOpenSSLErrorKeyGenBitsFailed,
  RTOpenSSLErrorKeyGenFailed,
  RTOpenSSLErrorEncryptInitFailed,
  RTOpenSSLErrorEncryptPaddingFailed,
  RTOpenSSLErrorEncryptFailed,
  RTOpenSSLErrorDecryptInitFailed,
  RTOpenSSLErrorDecryptPaddingFailed,
  RTOpenSSLErrorDecryptFailed,
  RTOpenSSLErrorSignInitFailed,
  RTOpenSSLErrorSignFailed,
  RTOpenSSLErrorVerifyInitFailed,
  RTOpenSSLErrorVerifyFailed,
  RTOpenSSLErrorPrivateKeyInvalid,
  RTOpenSSLErrorPublicKeyInvalid,
  RTOpenSSLErrorCertificateInvalid,
  RTOpenSSLErrorCertBuildFailed,
  RTOpenSSLErrorBlockIOInitFailed,
  RTOpenSSLErrorPKCS12ExportFailed,
  RTOpenSSLErrorPKCS12ImportFailed,
  RTOpenSSLErrorPrivateKeyEncodeFailed,
  RTOpenSSLErrorCertificateEncodeFailed,
  RTOpenSSLErrorCertificateRequestEncodeFailed,
  RTOpenSSLErrorCertificateStoreInvalid,
};


#define RT_RETURN_OPENSSL_ERROR(errorenum, value) \
  if (error) { \
    char msg[256]; \
    ERR_error_string_n(ERR_get_error(), msg, 256); \
    *error = [NSError errorWithDomain:RTOpenSSLErrorDomain \
                                 code:RTOpenSSLError ## errorenum \
                             userInfo:@{@"OpenSSLError":[NSString stringWithUTF8String:msg]}]; \
  } \
  return value
