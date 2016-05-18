//
//  OpenSSL.h
//  MessagesKit
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


@interface OpenSSL : NSObject

+(void) go;

@end


extern NSString *OpenSSLErrorDomain;


typedef NS_ENUM (int, OpenSSLError) {
  OpenSSLErrorContextAllocFailed,
  OpenSSLErrorPaddingFailed,
  OpenSSLErrorSaltLengthFailed,
  OpenSSLErrorSignatureFailed,
  OpenSSLErrorKeyGenInitFailed,
  OpenSSLErrorKeyGenBitsFailed,
  OpenSSLErrorKeyGenFailed,
  OpenSSLErrorEncryptInitFailed,
  OpenSSLErrorEncryptPaddingFailed,
  OpenSSLErrorEncryptFailed,
  OpenSSLErrorDecryptInitFailed,
  OpenSSLErrorDecryptPaddingFailed,
  OpenSSLErrorDecryptFailed,
  OpenSSLErrorSignInitFailed,
  OpenSSLErrorSignFailed,
  OpenSSLErrorVerifyInitFailed,
  OpenSSLErrorVerifyFailed,
  OpenSSLErrorPrivateKeyInvalid,
  OpenSSLErrorPublicKeyInvalid,
  OpenSSLErrorCertificateInvalid,
  OpenSSLErrorCertBuildFailed,
  OpenSSLErrorBlockIOInitFailed,
  OpenSSLErrorPKCS12ExportFailed,
  OpenSSLErrorPKCS12ImportFailed,
  OpenSSLErrorPrivateKeyEncodeFailed,
  OpenSSLErrorCertificateEncodeFailed,
  OpenSSLErrorCertificateRequestEncodeFailed,
  OpenSSLErrorCertificateStoreInvalid,
};


#define MK_RETURN_OPENSSL_ERROR(errorenum, value) \
  if (error) { \
    char msg[256]; \
    ERR_error_string_n(ERR_get_error(), msg, 256); \
    *error = [NSError errorWithDomain:OpenSSLErrorDomain \
                                 code:OpenSSLError ## errorenum \
                             userInfo:@{@"OpenSSLError":[NSString stringWithUTF8String:msg]}]; \
  } \
  return value
