//
//  OpenSSLCertificateTests.m
//  MessagesKit
//
//  Created by Kevin Wooten on 12/13/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "OpenSSLCertificate.h"
#import "OpenSSLCertificateSet.h"
#import "OpenSSLCertificateValidator.h"
#import "NSData+Encoding.h"
#import "NSBundle+Utils.h"

@import openssl;
@import XCTest;


@interface OpenSSLCertificateTests : XCTestCase

@property(nonatomic, strong) OpenSSLCertificate *cert;
@property(nonatomic, strong) OpenSSLCertificateSet *chain;

@end


@implementation OpenSSLCertificateTests

-(void) setUp {
  [super setUp];

  NSError *error;

  NSURL *testURL = [[NSBundle bundleForClass:self.class] URLForResource:@"testclient" withExtension:@"pem"];
  XCTAssertNotNil(testURL, @"Unable to load certificate");
  
  _cert = [[OpenSSLCertificate alloc] initWithPEMEncodedData:[NSData dataWithContentsOfURL:testURL] error:&error];
  XCTAssertNotNil(_cert, @"Error loading certificate: %@", error);
  
  NSURL *testChainURL = [[NSBundle bundleForClass:self.class] URLForResource:@"multitest" withExtension:@"pem"];
  XCTAssertNotNil(testChainURL, @"Unable to load certificate chain");
  
  _chain = [[OpenSSLCertificateSet alloc] initWithPEMEncodedData:[NSData dataWithContentsOfURL:testChainURL] error:&error];
  XCTAssertNotNil(_chain, @"Error loading certificates chain: %@", error);
}

-(void) tearDown {
  [super tearDown];
}

-(void) testCertificateRefCount
{
  OpenSSLCertificate *cert;
  @autoreleasepool {
    cert = _cert;
    _cert = nil;
  }
  XCTAssertEqual(cert.pointer->references, 1);
}

-(void) testChainCertificateRefCount
{
  OpenSSLCertificate *cert;
  @autoreleasepool {
    cert = _chain[0];
    _chain = nil;
  }
  XCTAssertEqual(cert.pointer->references, 1);
}

-(void) testCertificatesData
{
  {
    OpenSSLCertificate *cert = _chain[0];
    XCTAssertEqualObjects(cert.subjectName, @"C=US,OU=reTXT Certificate Authority,O=reTXT,CN=reTXT Root CA");
    XCTAssertEqualObjects(cert.issuerName, @"C=US,OU=reTXT Certificate Authority,O=reTXT,CN=reTXT Root CA");
    XCTAssertEqualObjects(cert.fingerprint.hexEncodedString.uppercaseString, @"B01487500E7ECFFF0A1874B2D7B577F0355F526E");
    XCTAssertTrue([cert.publicKey.encoded.hexEncodedString.uppercaseString hasPrefix:@"3082010D0201000282010100B54BFCC49D06FD94"]);
    XCTAssertTrue(cert.isSelfSigned);
  }
  {
    OpenSSLCertificate *cert = _chain[1];
    XCTAssertEqualObjects(cert.subjectName, @"C=US,OU=reTXT Certificate Authority,O=reTXT,CN=reTXT Worldwide Client Certificate Authority");
    XCTAssertEqualObjects(cert.issuerName, @"C=US,OU=reTXT Certificate Authority,O=reTXT,CN=reTXT Root CA");
    XCTAssertEqualObjects(cert.fingerprint.hexEncodedString.uppercaseString, @"BCC64B3E63CA46A7FC4C26BEDEE99AD994FA04A8");
    XCTAssertTrue([cert.publicKey.encoded.hexEncodedString.uppercaseString hasPrefix:@"3082010D0201000282010100D61308D81DD23AB2"]);
    XCTAssertFalse(cert.isSelfSigned);
  }
}

-(void) testCertificateAccessors
{
  OpenSSLCertificate *cert = _chain[0];
  [cert subjectName]; [cert subjectName]; [cert subjectName];
  XCTAssertEqualObjects(cert.subjectName, @"C=US,OU=reTXT Certificate Authority,O=reTXT,CN=reTXT Root CA");
  [cert issuerName]; [cert issuerName]; [cert issuerName];
  XCTAssertEqualObjects(cert.issuerName, @"C=US,OU=reTXT Certificate Authority,O=reTXT,CN=reTXT Root CA");
  [cert fingerprint]; [cert fingerprint]; [cert fingerprint];
  XCTAssertEqualObjects(cert.fingerprint.hexEncodedString.uppercaseString, @"B01487500E7ECFFF0A1874B2D7B577F0355F526E");
  @autoreleasepool {
    [cert publicKey]; [cert publicKey]; [cert publicKey];
  }
  XCTAssertTrue(cert.publicKey.pointer->references=2);
}

-(void) testCertificateChainEnumeration
{
  NSURL *testURL = [[NSBundle bundleForClass:self.class] URLForResource:@"multitestlarge" withExtension:@"pem"];
  XCTAssertNotNil(testURL, @"Unable to load test certificates file");
  
  NSError *error;
  OpenSSLCertificateSet *chain = [[OpenSSLCertificateSet alloc] initWithPEMEncodedData:[NSData dataWithContentsOfURL:testURL] error:&error];
  XCTAssertNotNil(_chain, @"Error loading certificates file: %@", error);

  int idx=0;
  for (OpenSSLCertificate *cert in chain) {
    XCTAssertEqualObjects(cert.fingerprint, chain[idx++].fingerprint);
  }
  XCTAssertEqual(idx, 20);
}

-(void) testValidationValid
{
  NSURL *rootsURL = [NSBundle.mk_frameworkBundle URLForResource:@"roots" withExtension:@"pem" subdirectory:@"Certificates"];
  XCTAssertNotNil(rootsURL, @"Unable to locate root certificates");
  
  NSError *error;
  
  OpenSSLCertificateValidator *validator = [[OpenSSLCertificateValidator alloc] initWithRootCertificatesInFile:rootsURL.path error:&error];
  XCTAssertNotNil(validator, @"Error initializing validator: %@", error);
  
  NSURL *intersURL = [NSBundle.mk_frameworkBundle URLForResource:@"inters" withExtension:@"pem" subdirectory:@"Certificates"];
  XCTAssertNotNil(intersURL, @"Unable to locate intermediate certificate authorities");
  
  OpenSSLCertificateSet *inters = [[OpenSSLCertificateSet alloc] initWithPEMEncodedData:[NSData dataWithContentsOfURL:intersURL] error:&error];
  XCTAssertNotNil(inters, @"Unable to load intermediate certificate authorities: %@", error);
  
  BOOL valid = [validator validate:_cert chain:inters error:&error];
  XCTAssertTrue(valid, @"Error validating certificate: %@", error);
  
  XCTAssertTrue(valid, @"Certificate not valid");
}

-(void) testValidationInvalid
{
  NSURL *rootsURL = [NSBundle.mk_frameworkBundle URLForResource:@"roots" withExtension:@"pem" subdirectory:@"Certificates"];
  XCTAssertNotNil(rootsURL, @"Unable to locate root certificates");
  
  NSError *error;
  
  OpenSSLCertificateValidator *validator = [[OpenSSLCertificateValidator alloc] initWithRootCertificatesInFile:rootsURL.path error:&error];
  XCTAssertNotNil(validator, @"Error initializing validator: %@", error);
  
  NSURL *intersURL = [[NSBundle bundleForClass:self.class] URLForResource:@"empty" withExtension:@"pem"];
  XCTAssertNotNil(intersURL, @"Unable to locate intermediate certificate authorities");
  
  OpenSSLCertificateSet *inters = [[OpenSSLCertificateSet alloc] initWithPEMEncodedData:[NSData dataWithContentsOfURL:intersURL] error:&error];
  XCTAssertNotNil(inters, @"Unable to load intermediate certificate authorities: %@", error);
  
  BOOL valid = [validator validate:_cert chain:inters error:&error];  
  XCTAssertFalse(valid, @"Certificate should not be valid");
}

@end
