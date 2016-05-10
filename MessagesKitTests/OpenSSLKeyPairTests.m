//
//  OpenSSLKeyPairTests.m
//  MessagesKit
//
//  Created by Kevin Wooten on 4/1/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "OpenSSLKeyPair.h"
#import "NSData+Random.h"
#import "NSString+Utils.h"

@import openssl;


@interface OpenSSLKeyPairTests : XCTestCase

@property(nonatomic, strong) OpenSSLKeyPair *keyPair;

@end


@implementation OpenSSLKeyPairTests

-(void) setUp
{
  [super setUp];
  
  _keyPair = [OpenSSLKeyPair generateKeyPairWithKeySize:2048 error:nil];
}

-(void) tearDown
{
  [super tearDown];
}

-(void) testPublicKeyRefCount
{
  OpenSSLPublicKey *key;
  @autoreleasepool {
    key = [OpenSSLKeyPair generateKeyPairWithKeySize:2048 error:nil].publicKey;
  }  
  XCTAssertEqual(key.pointer->references, 1);
}

-(void) testPrivateKeyRefCount
{
  OpenSSLPrivateKey *key;
  @autoreleasepool {
    key = [OpenSSLKeyPair generateKeyPairWithKeySize:2048 error:nil].privateKey;
  }
  XCTAssertEqual(key.pointer->references, 1);
}

-(void) testEncryptionRoundTrip
{
  NSString *src = @"Some real data";
  
  NSData *cipherText = [_keyPair.publicKey encryptData:[src dataUsingEncoding:NSUTF8StringEncoding] error:nil];
  XCTAssertNotNil(cipherText);
  
  NSData *plainText = [_keyPair.privateKey decryptData:cipherText error:nil];
  XCTAssertNotNil(plainText);
  
  XCTAssertEqualObjects(src, [NSString stringWithData:plainText encoding:NSUTF8StringEncoding]);
}

-(void) testSignatureRoundTripPSS32
{
  NSData *orig = [NSData dataWithRandomBytesOfLength:50];
  
  NSData *sig = [_keyPair.privateKey signData:orig withPadding:DigitalSignaturePaddingPSS32 error:nil];
  XCTAssertNotNil(sig);
  
  BOOL result = NO;
  XCTAssertTrue([_keyPair.publicKey verifyData:orig againstSignature:sig withPadding:DigitalSignaturePaddingPSS32 result:&result error:nil]);
  XCTAssertTrue(result);
}

-(void) testSignatureRoundTripPKCS1
{
  NSData *orig = [NSData dataWithRandomBytesOfLength:50];
  
  NSData *sig = [_keyPair.privateKey signData:orig withPadding:DigitalSignaturePaddingPKCS1 error:nil];
  XCTAssertNotNil(sig);
  
  BOOL result = NO;
  XCTAssertTrue([_keyPair.publicKey verifyData:orig againstSignature:sig withPadding:DigitalSignaturePaddingPKCS1 result:&result error:nil]);
  XCTAssertTrue(result);
}

-(void) testLoop
{
  NSString *src = @"Some Data";
  
  for (int c=0; c < 100; ++c) {
    
    NSData *ed = [_keyPair.publicKey encryptData:[src dataUsingEncoding:NSUTF8StringEncoding] error:nil];
    NSString *s = [[NSString alloc] initWithData:[_keyPair.privateKey decryptData:ed error:nil] encoding:NSUTF8StringEncoding];
    
    XCTAssertEqualObjects(s, src);
  }
}

@end
