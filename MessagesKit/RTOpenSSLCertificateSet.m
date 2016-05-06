//
//  RTOpenSSLCertificateSet.m
//  MessagesKit
//
//  Created by Kevin Wooten on 12/13/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTOpenSSLCertificateSet.h"

#import "RTOpenSSL.h"

@import openssl;


@interface RTOpenSSLCertificateSet ()

@property(nonatomic, assign) STACK_OF(X509) *pointer;

@end


@implementation RTOpenSSLCertificateSet

+(void)initialize
{
  [RTOpenSSL go];
}

-(instancetype) initWithPEMEncodedData:(NSData *)pemData error:(NSError **)error
{
  self = [super init];
  if (self) {
    
    BIO *pemBIO = BIO_new_mem_buf((void *)pemData.bytes, (int)pemData.length);
    
    STACK_OF(X509_INFO) *certInfoStack = PEM_X509_INFO_read_bio(pemBIO, NULL, NULL, NULL);
    if (!certInfoStack) {
      BIO_free_all(pemBIO);
      RT_RETURN_OPENSSL_ERROR(CertificateStoreInvalid, nil);
    }
    
    _pointer = sk_X509_new_null();
    for (int certIdx=0; certIdx < sk_X509_INFO_num(certInfoStack); ++certIdx) {
      
      X509_INFO *certInfo = sk_X509_INFO_value(certInfoStack, certIdx);
      
      sk_X509_insert(_pointer, certInfo->x509, -1);
      CRYPTO_add(&certInfo->x509->references, 1, CRYPTO_LOCK_X509);
    }

    sk_X509_INFO_pop_free(certInfoStack, X509_INFO_free);
    BIO_free_all(pemBIO);
  }
  return self;
}

-(void)dealloc
{
  sk_X509_pop_free(_pointer, X509_free);
}

-(NSUInteger)count
{
  return sk_X509_num(_pointer);
}

-(RTOpenSSLCertificate *)objectAtIndexedSubscript:(NSUInteger)idx
{
  X509 *cert = sk_X509_value(_pointer, (int)idx);
  return [[RTOpenSSLCertificate alloc] initWithCertPointer:cert];
}

-(NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id  _Nonnull *)buffer count:(NSUInteger)len
{
  long localIdx, totalIdx;
  for (localIdx=0, totalIdx=state->state; localIdx < len && totalIdx < sk_X509_num(_pointer); localIdx++, totalIdx++) {
    // XXX needed to ensure temp objects live until autorelease pool dumped
    RTOpenSSLCertificate *__autoreleasing cert =
      [[RTOpenSSLCertificate alloc] initWithCertPointer:sk_X509_value(_pointer, (int)totalIdx)];
    buffer[localIdx] = cert;
  }
  
  state->state = totalIdx;
  state->mutationsPtr = (unsigned long *)_pointer;
  state->itemsPtr = buffer;
  
  return localIdx;
}

@end
