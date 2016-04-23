//
//  RTMsgCipherTests.m
//  ReTxt
//
//  Created by Kevin Wooten on 4/2/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RTMsgCipher.h"


@interface RTMsgCipherTests : XCTestCase

@end


@implementation RTMsgCipherTests

-(void) setUp
{
  [super setUp];
}

-(void) tearDown
{
  [super tearDown];
}

-(void) testRoundTrip_AES256_CBC
{
  
  RTMsgCipher *cipher = [RTMsgCipher cipherForEncryptionType:RTEncryptionTypeVer1_AES256_CBC];
  
  NSData *key = [cipher randomKeyWithError:nil];
  
  NSString *src = @"Hello World!";
  
  NSError *error;
  NSData *cipherText = [cipher encryptData:[src dataUsingEncoding:NSUTF8StringEncoding] withKey:key error:&error];
  XCTAssertNotNil(cipherText, @"Error: %@", error);
  
  NSString *dst = [[NSString alloc] initWithData:[cipher decryptData:cipherText withKey:key error:&error] encoding:NSUTF8StringEncoding];
  
  XCTAssertEqualObjects(src, dst, @"Round Trip Failed");
}

@end
