//
//  RTOpenSSL.m
//  MessagesKit
//
//  Created by Kevin Wooten on 11/1/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTOpenSSL.h"

@import openssl;


NSString *RTOpenSSLErrorDomain = @"RTOpenSSLErrorDomain";


static NSLock *sslLocks[CRYPTO_NUM_LOCKS];

void sslLock(int mode, int lockIdx, const char *file, int line)
{
  if (mode & CRYPTO_LOCK) {
    [sslLocks[lockIdx] lock];
  }
  else {
    [sslLocks[lockIdx] unlock];
  }
}

struct CRYPTO_dynlock_value {};

struct CRYPTO_dynlock_value *sslLockCreateDyn(const char *file, int line)
{
  return (__bridge_retained struct CRYPTO_dynlock_value *)[NSLock new];
}

void sslLockDestroyDyn(struct CRYPTO_dynlock_value *value, const char *file, int line)
{
  NSLock *lock = (__bridge_transfer NSLock *)(value);
  lock = nil;
}

void sslLockDyn(int mode, struct CRYPTO_dynlock_value *value, const char *file, int line)
{
  NSLock *lock = (__bridge NSLock *)value;

  if (mode & CRYPTO_LOCK) {
    [lock lock];
  }
  else {
    [lock unlock];
  }
}


@implementation RTOpenSSL

+(void) initialize
{
  for (int c=0; c < CRYPTO_NUM_LOCKS; ++c) {
    sslLocks[c] = [NSLock new];
  }
  CRYPTO_set_locking_callback(sslLock);

  CRYPTO_set_dynlock_create_callback(sslLockCreateDyn);
  CRYPTO_set_dynlock_destroy_callback(sslLockDestroyDyn);
  CRYPTO_set_dynlock_lock_callback(sslLockDyn);

  OpenSSL_add_all_algorithms();
  OpenSSL_add_all_ciphers();
  OpenSSL_add_all_digests();
#if DEBUG
  ERR_load_crypto_strings();
#endif
}


+(void) go
{
}

@end
