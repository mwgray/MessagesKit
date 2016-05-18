//
//  OpenSSLKeyPair.m
//  MessagesKit
//
//  Created by Kevin Wooten on 1/6/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "OpenSSLKeyPair.h"

#import "AsymmetricKeyPairGenerator.h"

#import "OpenSSL.h"
#import "X509Utils.h"

#import "NSArray+Utils.h"
#import "NSData+CommonDigest.h"

@import openssl;


@interface OpenSSLPrivateKey ()

@property (nonatomic, assign) EVP_PKEY *pointer;

@end


@implementation OpenSSLPrivateKey

+(void) initialize
{
  [OpenSSL go];
}

-(instancetype) initWithKeyPointer:(EVP_PKEY *)pointer
{
  self = [super init];
  if (self) {
    _pointer = pointer;
    CRYPTO_add(&_pointer->references, 1, CRYPTO_LOCK_EVP_PKEY);
  }
  return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
  self = [super init];
  if (self) {
    NSData *encoded = [aDecoder decodeObjectOfClass:NSData.class forKey:@"der"];
    const unsigned char *encodedBytes = encoded.bytes;
    if (d2i_AutoPrivateKey(&_pointer, &encodedBytes, encoded.length) < 0) {
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
  EVP_PKEY_free(_pointer);
  _pointer = NULL;
}

-(EVP_PKEY *) pointer
{
  return _pointer;
}

-(NSData *)encoded
{
  unsigned char *keyBytes = NULL;
  int keyBytesLen = i2d_PrivateKey(_pointer, &keyBytes);
  if (keyBytesLen <= 0) {
    return nil;
  }
  
  return [NSData dataWithBytesNoCopy:keyBytes
                              length:keyBytesLen
                        freeWhenDone:YES];
}

-(NSData *) decryptData:(NSData *)cipherText error:(NSError **)error
{
  
  EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(_pointer, NULL);
  if (!ctx) {
    MK_RETURN_OPENSSL_ERROR(ContextAllocFailed, nil);
  }
  
  NSData *result = ^NSData *{
    
    if (EVP_PKEY_decrypt_init(ctx) <= 0) {
      MK_RETURN_OPENSSL_ERROR(DecryptInitFailed, nil);
    }
    
    if (EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_OAEP_PADDING) <= 0) {
      MK_RETURN_OPENSSL_ERROR(DecryptPaddingFailed, nil);
    }
    
    size_t clearTextLen = 0;
    if (EVP_PKEY_decrypt(ctx, NULL, &clearTextLen, cipherText.bytes, cipherText.length) <= 0) {
      MK_RETURN_OPENSSL_ERROR(DecryptFailed, nil);
    }
    
    NSMutableData *clearText = [NSMutableData dataWithLength:clearTextLen];
    if (EVP_PKEY_decrypt(ctx, clearText.mutableBytes, &clearTextLen, cipherText.bytes, cipherText.length) <= 0) {
      MK_RETURN_OPENSSL_ERROR(DecryptFailed, nil);
    }
    
    return [clearText subdataWithRange:NSMakeRange(0, clearTextLen)];
    
  } ();
  
  EVP_PKEY_CTX_free(ctx);
  
  return result;
}

-(NSData *) signData:(NSData *)data withPadding:(DigitalSignaturePadding)padding error:(NSError **)error
{
  NSData *digest = [data sha256];
  
  EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(_pointer, NULL);
  if (!ctx) {
    MK_RETURN_OPENSSL_ERROR(ContextAllocFailed, nil);
  }
  
  NSData *sig = ^NSData *{
    
    if (EVP_PKEY_sign_init(ctx) <= 0) {
      MK_RETURN_OPENSSL_ERROR(SignInitFailed, nil);
    }
    
    switch (padding) {
      case DigitalSignaturePaddingPKCS1:
        if (EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_PADDING) <= 0) {
          MK_RETURN_OPENSSL_ERROR(PaddingFailed, nil);
        }
        break;
        
      case DigitalSignaturePaddingPSS32:
        if (EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_PSS_PADDING) <= 0) {
          MK_RETURN_OPENSSL_ERROR(PaddingFailed, nil);
        }
        
        if (EVP_PKEY_CTX_set_rsa_pss_saltlen(ctx, 32) <= 0) {
          MK_RETURN_OPENSSL_ERROR(SaltLengthFailed, nil);
        }
        break;
    }
    
    if (EVP_PKEY_CTX_set_signature_md(ctx, EVP_sha256()) <= 0) {
      MK_RETURN_OPENSSL_ERROR(SignatureFailed, nil);
    }
    
    size_t sigLen = 0;
    if (EVP_PKEY_sign(ctx, NULL, &sigLen, digest.bytes, digest.length) <= 0) {
      MK_RETURN_OPENSSL_ERROR(SignFailed, nil);
    }
    
    NSMutableData *sig = [NSMutableData dataWithLength:sigLen];
    if (EVP_PKEY_sign(ctx, sig.mutableBytes, &sigLen, digest.bytes, digest.length) <= 0) {
      MK_RETURN_OPENSSL_ERROR(SignFailed, nil);
    }
    
    return sig;
    
  } ();
  
  EVP_PKEY_CTX_free(ctx);
  
  return sig;
}

-(NSData *) exportPKCS12Named:(NSString *)name withPassphrase:(NSString *)passphrase error:(NSError **)error
{
  PKCS12 *pkcs12 = PKCS12_create((char *)[passphrase UTF8String], (char *)name.UTF8String,
                                 _pointer, NULL, NULL, 0, 0, PKCS12_DEFAULT_ITER, PKCS12_DEFAULT_ITER, 0);
  if (pkcs12 == NULL) {
    MK_RETURN_OPENSSL_ERROR(PKCS12ExportFailed, nil);
  }
  
  BIO *pkcs12Out = BIO_new(BIO_s_mem());
  
  NSData *pkcs12Data = ^NSData *{
    
    if (i2d_PKCS12_bio(pkcs12Out, pkcs12) <= 0) {
      MK_RETURN_OPENSSL_ERROR(PKCS12ExportFailed, nil);
    }
    
    char *bufMem;
    size_t bufLen = BIO_get_mem_data(pkcs12Out, &bufMem);
    
    return [NSData dataWithBytes:bufMem length:bufLen];
    
  } ();
  
  BIO_free_all(pkcs12Out);
  PKCS12_free(pkcs12);
  
  return pkcs12Data;
}

@end




@interface OpenSSLPublicKey ()

@property (nonatomic, assign) EVP_PKEY *pointer;

@end


@implementation OpenSSLPublicKey

+(void) initialize
{
  [OpenSSL go];
}

-(instancetype) initWithKeyPointer:(EVP_PKEY *)pointer
{
  self = [super init];
  if (self) {
    _pointer = pointer;
    CRYPTO_add(&_pointer->references, 1, CRYPTO_LOCK_EVP_PKEY);
  }
  return self;
}

-(instancetype)initWithCoder:(NSCoder *)aDecoder
{
  self = [super init];
  if (self) {
    NSData *encoded = [aDecoder decodeObjectOfClass:NSData.class forKey:@"der"];
    const unsigned char *encodedBytes = encoded.bytes;
    if (d2i_PublicKey(EVP_PKEY_RSA, &_pointer, &encodedBytes, encoded.length) < 0) {
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
  EVP_PKEY_free(_pointer);
  _pointer = NULL;
}

-(EVP_PKEY *) pointer
{
  return _pointer;
}

-(NSData *)encoded
{
  unsigned char *keyBytes = NULL;
  int keyBytesLen = i2d_PrivateKey(_pointer, &keyBytes);
  if (keyBytesLen <= 0) {
    return nil;
  }
  
  return [NSData dataWithBytesNoCopy:keyBytes
                              length:keyBytesLen
                        freeWhenDone:YES];
}

-(NSData *)fingerprint
{
  return [self.encoded sha1];
}

-(NSData *) encryptData:(NSData *)clearText error:(NSError **)error
{
  
  EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(_pointer, NULL);
  if (!ctx) {
    MK_RETURN_OPENSSL_ERROR(ContextAllocFailed, nil);
  }
  
  NSData *result = ^NSData *{
    
    if (EVP_PKEY_encrypt_init(ctx) <= 0) {
      MK_RETURN_OPENSSL_ERROR(EncryptInitFailed, nil);
    }
    
    if (EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_OAEP_PADDING) <= 0) {
      MK_RETURN_OPENSSL_ERROR(EncryptPaddingFailed, nil);
    }
    
    size_t cipherTextLen = 0;
    if (EVP_PKEY_encrypt(ctx, NULL, &cipherTextLen, clearText.bytes, clearText.length) <= 0) {
      MK_RETURN_OPENSSL_ERROR(EncryptFailed, nil);
    }
    
    NSMutableData *cipherText = [NSMutableData dataWithLength:cipherTextLen];
    if (EVP_PKEY_encrypt(ctx, cipherText.mutableBytes, &cipherTextLen, clearText.bytes, clearText.length) <= 0) {
      MK_RETURN_OPENSSL_ERROR(EncryptFailed, nil);
    }
    
    return [cipherText subdataWithRange:NSMakeRange(0, cipherTextLen)];
    
  } ();
  
  EVP_PKEY_CTX_free(ctx);
  
  return result;
}

-(BOOL) verifyData:(NSData *)data againstSignature:(NSData *)signature withPadding:(DigitalSignaturePadding)padding result:(BOOL *)result error:(NSError **)error
{
  NSData *digest = [data sha256];
  
  EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(_pointer, NULL);
  if (!ctx) {
    MK_RETURN_OPENSSL_ERROR(ContextAllocFailed, NO);
  }
  
  BOOL ret = ^BOOL {
    
    if (EVP_PKEY_verify_init(ctx) <= 0) {
      MK_RETURN_OPENSSL_ERROR(VerifyInitFailed, NO);
    }
    
    switch (padding) {
      case DigitalSignaturePaddingPKCS1:
        if (EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_PADDING) <= 0) {
          MK_RETURN_OPENSSL_ERROR(PaddingFailed, NO);
        }
        break;
        
      case DigitalSignaturePaddingPSS32:
        if (EVP_PKEY_CTX_set_rsa_padding(ctx, RSA_PKCS1_PSS_PADDING) <= 0) {
          MK_RETURN_OPENSSL_ERROR(PaddingFailed, NO);
        }
        
        if (EVP_PKEY_CTX_set_rsa_pss_saltlen(ctx, 32) <= 0) {
          MK_RETURN_OPENSSL_ERROR(SaltLengthFailed, NO);
        }
        break;
    }
    
    if (EVP_PKEY_CTX_set_signature_md(ctx, EVP_sha256()) <= 0) {
      MK_RETURN_OPENSSL_ERROR(SignatureFailed, NO);
    }
    
    int ret = EVP_PKEY_verify(ctx, signature.bytes, signature.length, digest.bytes, digest.length);
    
    *result = ret == 1 ? YES : NO;
    
    return YES;
    
  } ();
  
  EVP_PKEY_CTX_free(ctx);
  
  return ret;
}

@end



@implementation OpenSSLKeyPair

+(void) initialize
{
  [OpenSSL go];
}

+(instancetype) generateKeyPairWithKeySize:(int)keySize error:(NSError **)error
{
  EVP_PKEY *key = [AsymmetricKeyPairGenerator generateRSAKeyPairWithKeySize:keySize error:error];
  if (!key) {
    return nil;
  }

  OpenSSLKeyPair* pair = [[OpenSSLKeyPair alloc] initWithKeyPointer:key];
  
  EVP_PKEY_free(key);
  
  return pair;
}

+(instancetype) importPKCS12:(NSData *)pkcs12Data withPassphrase:(NSString *)passphrase error:(NSError **)error
{
  const unsigned char *pkcs12Bytes = pkcs12Data.bytes;
  
  PKCS12 *pkcs12 = d2i_PKCS12(NULL, &pkcs12Bytes, pkcs12Data.length);
  if (pkcs12 == NULL) {
    MK_RETURN_OPENSSL_ERROR(PKCS12ImportFailed, FALSE);
  }
  
  EVP_PKEY *privateKey = NULL;
  X509 *cert = NULL;
  if (PKCS12_parse(pkcs12, passphrase.UTF8String, &privateKey, &cert, NULL) <= 0) {
    PKCS12_free(pkcs12);
    MK_RETURN_OPENSSL_ERROR(PKCS12ImportFailed, FALSE);
  }
  
  X509_free(cert);
  PKCS12_free(pkcs12);
  
  OpenSSLKeyPair *pair = [[self alloc] initWithKeyPointer:privateKey];
  
  EVP_PKEY_free(privateKey);
  
  return pair;
}

-(instancetype) initWithKeyPointer:(EVP_PKEY *)pointer
{
  self = [super init];
  if (self) {

    _privateKey = [[OpenSSLPrivateKey alloc] initWithKeyPointer:pointer];
    _publicKey = [[OpenSSLPublicKey alloc] initWithKeyPointer:pointer];

  }
  return self;
}

-(instancetype) initWithCoder:(NSCoder *)aDecoder
{
  self = [super init];
  if (self) {
    _privateKey = [aDecoder decodeObjectOfClass:OpenSSLPrivateKey.class forKey:@"privateKey"];
    _publicKey = [[OpenSSLPublicKey alloc] initWithKeyPointer:_privateKey.pointer];
  }
  return self;
}

-(void) encodeWithCoder:(NSCoder *)aCoder
{
  [aCoder encodeObject:_privateKey forKey:@"privateKey"];
}

@end
