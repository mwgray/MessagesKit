//
//  NSURLSessionConfiguration+RTMessageAPI.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/6/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

#import "NSURLSessionConfiguration+RTMessageAPI.h"

#import "RTServerAPI.h"
#import "RTMessages+Exts.h"
#import "NSBundle+Utils.h"

@import Thrift;
@import YOLOKit;


@implementation NSURLSessionConfiguration (RTMessageAPI)

+(instancetype) clientSessionCofigurationWithProtcolFactory:(id<TProtocolFactory>)protocolFactory
{
  NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];

  [THTTPSessionTransportFactory setupDefaultsForSessionConfiguration:sessionConfig
                                                    withProtocolName:protocolFactory.protocolName];

  sessionConfig.networkServiceType = NSURLNetworkServiceTypeDefault;
  sessionConfig.timeoutIntervalForRequest = 15.0;
  sessionConfig.discretionary = NO;
  sessionConfig.TLSMinimumSupportedProtocol = kTLSProtocol11;
  sessionConfig.HTTPAdditionalHeaders =
    sessionConfig.HTTPAdditionalHeaders.extend(@{RTVersionHTTPHeader: NSBundle.frameworkBundle.infoDictionary[@"CFBundleShortVersionString"],
                                                 RTBuildHTTPHeader: NSBundle.frameworkBundle.infoDictionary[@"CFBundleVersion"]});

  return sessionConfig;
}

+(instancetype) backgroundSessionConfigurationWithUserId:(RTId *)userId
{
  NSString *backgroundSessionIdentifier = [NSString stringWithFormat:@"com.retxt.session.backgroud:%@", userId.UUIDString];
  
  NSURLSessionConfiguration *backgroundSessionConfiguration =
    [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:backgroundSessionIdentifier];
  
  backgroundSessionConfiguration.discretionary = NO;
  backgroundSessionConfiguration.allowsCellularAccess = YES;
  backgroundSessionConfiguration.networkServiceType = NSURLNetworkServiceTypeDefault;
  backgroundSessionConfiguration.timeoutIntervalForRequest = 20;
  backgroundSessionConfiguration.timeoutIntervalForResource = 60 * 15;
  backgroundSessionConfiguration.URLCredentialStorage = nil;
  backgroundSessionConfiguration.HTTPShouldSetCookies = NO;
  backgroundSessionConfiguration.HTTPCookieAcceptPolicy = NSHTTPCookieAcceptPolicyNever;
  backgroundSessionConfiguration.HTTPShouldUsePipelining = NO;
  backgroundSessionConfiguration.HTTPAdditionalHeaders = @{RTUserAgentHTTPHeader: RTUserAgent};
  
  return backgroundSessionConfiguration;
}

@end
