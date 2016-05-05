//
//  RTOpenSSLKeyPairTests.m
//  ReTxt
//
//  Created by Kevin Wooten on 4/1/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RTOpenSSLKeyPair.h"
#import "NSData+Random.h"
#import "NSString+Utils.h"

@import openssl;


@interface RTOpenSSLKeyPairTests : XCTestCase

@property(nonatomic, strong) RTOpenSSLKeyPair *keyPair;

@end


@implementation RTOpenSSLKeyPairTests

-(void) setUp
{
  [super setUp];
  
  _keyPair = [RTOpenSSLKeyPair generateKeyPairWithKeySize:2048 error:nil];
}

-(void) tearDown
{
  [super tearDown];
}

-(void) testPublicKeyRefCount
{
  RTOpenSSLPublicKey *key;
  @autoreleasepool {
    key = [RTOpenSSLKeyPair generateKeyPairWithKeySize:2048 error:nil].publicKey;
  }  
  XCTAssertEqual(key.pointer->references, 1);
}

-(void) testPrivateKeyRefCount
{
  RTOpenSSLPrivateKey *key;
  @autoreleasepool {
    key = [RTOpenSSLKeyPair generateKeyPairWithKeySize:2048 error:nil].privateKey;
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
  
  NSData *sig = [_keyPair.privateKey signData:orig withPadding:RTDigitalSignaturePaddingPSS32 error:nil];
  XCTAssertNotNil(sig);
  
  BOOL result = NO;
  XCTAssertTrue([_keyPair.publicKey verifyData:orig againstSignature:sig withPadding:RTDigitalSignaturePaddingPSS32 result:&result error:nil]);
  XCTAssertTrue(result);
}

-(void) testSignatureRoundTripPKCS1
{
  NSData *orig = [NSData dataWithRandomBytesOfLength:50];
  
  NSData *sig = [_keyPair.privateKey signData:orig withPadding:RTDigitalSignaturePaddingPKCS1 error:nil];
  XCTAssertNotNil(sig);
  
  BOOL result = NO;
  XCTAssertTrue([_keyPair.publicKey verifyData:orig againstSignature:sig withPadding:RTDigitalSignaturePaddingPKCS1 result:&result error:nil]);
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
