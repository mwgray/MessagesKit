//
//  RTMsgCipher.m
//  ReTxt
//
//  Created by Kevin Wooten on 4/2/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMsgCipher.h"

#import "NSData+Random.h"
#import "RTOpenSSL.h"

#import <CommonCrypto/CommonCrypto.h>
#import <CommonCrypto/CommonRandom.h>

@import openssl;


#define BUFFER_SIZE 4096


NSString *const RTMsgCipherErrorDomain = @"RTMsgCipherErrorDomain";


@interface  RTMsgCipher () {
  RTEncryptionType _type;
  const EVP_CIPHER *_cipher;
  uint _tagSize;
}

@end



@implementation RTMsgCipher

static RTMsgCipher *_s_ciphers[1];

+(void) initialize
{
  [RTOpenSSL go];

  _s_ciphers[RTEncryptionTypeVer1_AES256_CBC] = [[RTMsgCipher alloc] initWithEncryptionType:RTEncryptionTypeVer1_AES256_CBC];
}

+(instancetype) defaultCipher
{
  return [self cipherForEncryptionType:RTEncryptionTypeVer1_AES256_CBC];
}

+(instancetype) cipherForKey:(NSData *)key
{
  return [self cipherForEncryptionType:RTEncryptionTypeVer1_AES256_CBC];
}

+(instancetype) cipherForEncryptionType:(RTEncryptionType)encryptionType
{
  if ((int)encryptionType >= (sizeof(_s_ciphers)/sizeof(RTMsgCipher *))) {
    return nil;
  }

  return _s_ciphers[encryptionType];
}

-(instancetype) init
{
  return [self initWithEncryptionType:RTEncryptionTypeVer1_AES256_CBC];
}

-(instancetype) initWithEncryptionType:(RTEncryptionType)encryptionType
{

  if ((self = [super init])) {

    _type = encryptionType;

    switch (_type) {
    case RTEncryptionTypeVer1_AES256_CBC:
      _cipher = EVP_aes_256_cbc();
      _tagSize = 0;
      break;
        
    default:
      return nil;
    }

  }

  return self;
}

-(RTEncryptionType) type
{
  return _type;
}

-(nullable NSData *) randomKeyWithError:(NSError **)error
{
  NSMutableData *data = [NSMutableData dataWithLength:48];
  
  CCRNGStatus status = CCRandomGenerateBytes(data.mutableBytes, data.length);
  if (status != kCCSuccess) {
    if (error ) {
      *error = [NSError errorWithDomain:RTMsgCipherErrorDomain
                                   code:RTMsgCipherErrorRandomGeneratorFailed
                               userInfo:@{@"status":@(status)}];
    }
    return nil;
  }
  
  return data;
}

-(NSData *) encryptData:(NSData *)data withKey:(NSData *)key error:(NSError **)error
{

  NSInputStream *inStream = [NSInputStream inputStreamWithData:data];
  [inStream open];
  NSOutputStream *outStream = [NSOutputStream outputStreamToMemory];
  [outStream open];

  BOOL result = [self encryptFromStream:inStream toStream:outStream withKey:key error:error];

  [outStream close];
  [inStream close];

  if (!result) {
    return nil;
  }

  return [outStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
}

-(BOOL) encryptFromStream:(id<DataInputStream>)inStream toStream:(id<DataOutputStream>)outStream withKey:(NSData *)fullKey error:(NSError **)error
{
  EVP_CIPHER_CTX ctx;
  EVP_CIPHER_CTX_init(&ctx);

  BOOL result = ^(EVP_CIPHER_CTX *ctx) {

    unsigned char key[32], iv[16];
    [fullKey getBytes:key range:NSMakeRange(0, 32)];
    [fullKey getBytes:iv range:NSMakeRange(32, 16)];

    if (EVP_EncryptInit_ex(ctx, _cipher, NULL, key, iv) <= 0) {
      RT_RETURN_OPENSSL_ERROR(EncryptInitFailed, NO);
    }

    uint8_t inBuffer[BUFFER_SIZE] = {0};
    uint8_t outBuffer[BUFFER_SIZE] = {0};
    NSUInteger bytesRead = 0;

    for(;;) {
      
      if (![inStream readBytesOfMaxLength:BUFFER_SIZE intoBuffer:inBuffer bytesRead:&bytesRead error:error]) {
        return NO;
      }
      
      if (bytesRead <= 0) {
        break;
      }

      int bytesProcessed;
      if (EVP_EncryptUpdate(ctx, outBuffer, &bytesProcessed, inBuffer, (int)bytesRead) <= 0) {
        RT_RETURN_OPENSSL_ERROR(EncryptFailed, NO);
      }

      if (bytesProcessed) {

        if (![outStream writeBytesFromBuffer:outBuffer length:bytesProcessed error:error]) {
          return NO;
        }

      }

    }

    int finalLen = 0;
    if (EVP_EncryptFinal_ex(ctx, outBuffer, &finalLen) <= 0) {
      RT_RETURN_OPENSSL_ERROR(EncryptFailed, NO);
    }

    if (finalLen) {
      if (![outStream writeBytesFromBuffer:outBuffer length:finalLen error:error]) {
        return NO;
      }
    }

    if (_tagSize) {

      if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, _tagSize, outBuffer) <= 0) {
        RT_RETURN_OPENSSL_ERROR(EncryptFailed, NO);
      }

      if (![outStream writeBytesFromBuffer:outBuffer length:_tagSize error:error]) {
        return NO;
      }

    }

    return YES;

  } (&ctx);

  EVP_CIPHER_CTX_cleanup(&ctx);

  return result;
}

-(NSData *) decryptData:(NSData *)data withKey:(NSData *)key error:(NSError **)error
{

  NSInputStream *inStream = [NSInputStream inputStreamWithData:data];
  [inStream open];
  NSOutputStream *outStream = [NSOutputStream outputStreamToMemory];
  [outStream open];

  BOOL result = [self decryptFromStream:inStream toStream:outStream withKey:key error:error];

  [outStream close];
  [inStream close];

  if (!result) {
    return nil;
  }

  return [outStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
}

-(BOOL) decryptFromStream:(id<DataInputStream>)inStream toStream:(id<DataOutputStream>)outStream withKey:(NSData *)fullKey error:(NSError **)error
{
  EVP_CIPHER_CTX ctx;
  EVP_CIPHER_CTX_init(&ctx);

  BOOL result = ^(EVP_CIPHER_CTX *ctx) {

    unsigned char key[32], iv[16];
    [fullKey getBytes:key range:NSMakeRange(0, 32)];
    [fullKey getBytes:iv range:NSMakeRange(32, 16)];

    if (EVP_DecryptInit_ex(ctx, _cipher, NULL, key, iv) <= 0) {
      RT_RETURN_OPENSSL_ERROR(DecryptInitFailed, NO);
    }

    uint8_t inBuffer[BUFFER_SIZE+_tagSize];
    uint8_t outBuffer[BUFFER_SIZE+_tagSize];
    NSUInteger bytesRead =0, leftOver =0;

    // The read loop ensures that the tag (if any) is left
    // in the inBuffer once the stream data is exhausted

    for(;;) {

      if (![inStream readBytesOfMaxLength:BUFFER_SIZE+(_tagSize-leftOver) intoBuffer:inBuffer+leftOver bytesRead:&bytesRead error:error]) {
        return NO;
      }
      
      if (bytesRead <= 0) {
        break;
      }

      bytesRead -= (_tagSize - leftOver);
      leftOver = _tagSize;

      int bytesProcessed;
      if (EVP_DecryptUpdate(ctx, outBuffer, &bytesProcessed, inBuffer, (int)bytesRead) <= 0) {
        RT_RETURN_OPENSSL_ERROR(DecryptFailed, NO);
      }

      if (bytesProcessed) {

        if (![outStream writeBytesFromBuffer:outBuffer length:bytesProcessed error:error]) {
          return NO;
        }

      }

      // Move leftover data to the front of the buffer
      if (leftOver) {
        memmove(inBuffer, inBuffer+bytesRead, leftOver);
      }

    }

    if (_tagSize) {

      if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, _tagSize, inBuffer) <= 0) {
        RT_RETURN_OPENSSL_ERROR(DecryptFailed, NO);
      }

    }

    int finalLen = 0;
    if (EVP_DecryptFinal_ex(ctx, outBuffer, &finalLen) <= 0) {
      RT_RETURN_OPENSSL_ERROR(DecryptFailed, NO);
    }

    if (![outStream writeBytesFromBuffer:outBuffer length:finalLen error:error]) {
      return NO;
    }

    return YES;

  } (&ctx);

  EVP_CIPHER_CTX_cleanup(&ctx);

  return result;
}

@end
