//
//  RTURLSessionSSLValidator.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/7/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTURLSessionSSLValidator.h"

#import "RTLog.h"


RT_LUMBERJACK_DECLARE_LOG_LEVEL();


@interface RTURLSessionSSLValidator ()

@property (strong, atomic) NSArray *trustedCertificates;

@end


@implementation RTURLSessionSSLValidator

-(instancetype) initWithTrustedCertificates:(NSArray *)trustedCertificates
{
  self = [super init];
  if (self) {
    self.trustedCertificates = trustedCertificates;
  }
  return self;
}

-(void)  URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
  completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler;
{
  NSURLSessionAuthChallengeDisposition disposition = [self processChallenge:challenge];

  completionHandler(disposition, nil);
}

-(NSURLSessionAuthChallengeDisposition) processChallenge:(NSURLAuthenticationChallenge *)challenge
{
  if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {

    SecTrustRef trust = challenge.protectionSpace.serverTrust;
    if (!trust) {
      DDLogError(@"No server trust object found");
      return NSURLSessionAuthChallengeRejectProtectionSpace;
    }

    SecTrustSetAnchorCertificates(trust, (__bridge CFArrayRef)self.trustedCertificates);
    SecTrustSetAnchorCertificatesOnly(trust, true);

    SecTrustResultType result = kSecTrustResultInvalid;
    OSStatus status = SecTrustEvaluate(trust, &result);
    if (status == errSecSuccess &&
        (result == kSecTrustResultUnspecified || result == kSecTrustResultProceed))
    {
      return NSURLSessionAuthChallengePerformDefaultHandling;
    }

    DDLogError(@"Unexpected error evaluating trust %d, %d", (int)status, (int)result);
  }

  return NSURLSessionAuthChallengeCancelAuthenticationChallenge;
}

@end
