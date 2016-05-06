//
//  RTServerAPI.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/13/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTServerAPI.h"

#import "NSData+CommonDigest.h"
#import "NSData+Encoding.h"

#import "NSBundle+Utils.h"
#import "NSObject+Properties.h"
#import "NSMutableURLRequest+Utils.h"
#import "TBase+Utils.h"

@import Thrift;

#if defined(PUBLIC_BUILD)
# define RETXT_PROD
#elif defined(QA_BUILD)
# define RETXT_STAGE
#else
#define RETXT_LOCAL
#endif

#if defined(RETXT_PROD)
# define RT_SERVER_DOMAIN_ENV "prd"
#elif defined(RETXT_STAGE)
# define RT_SERVER_DOMAIN_ENV "stg"
#elif defined(RETXT_DEV)
# define RT_SERVER_DOMAIN_ENV "dev"
#elif defined(RETXT_LOCAL)
# define RT_SERVER_DOMAIN_ENV "lcl"
#else
# error NO RETXT SERVER TARGET DEFINED
#endif


NSString *RTServerEnvironmentName =
#if defined(RETXT_PROD)
  @"Production"
#elif defined(RETXT_STAGE)
  @"Staging"
#elif defined(RETXT_DEV)
  @"Development"
#elif defined(RETXT_LOCAL)
  @"Local"
#endif
;


#if defined(RETXT_LOCAL)
NSString *RTServerScheme = @"http";
NSString *RTServerHost = @"192.168.100.10";
NSInteger RTServerPort = 8080;
#else
NSString *RTServerScheme = @"https";
NSString *RTServerHost = @"master." RT_SERVER_DOMAIN_ENV ".retxt.io";
NSInteger RTServerPort = 0;
#endif


static NSString *RTPinnedCertName = @"master.retxt.io";
static NSArray *RTPinnedCerts;


NSURL *RTBaseURL;
NSString *RTUserAgent = @"reTXT (iOS)";
int RTServerTimeout = 15;

NSString *RTUserAPIFetchMsgIdParam = @"msgId";

NSString *RTMsgInfoHTTPHeader = @"X-Msg-Info";
NSString *RTBearerRefreshHTTPHeader = @"X-Bearer-Refresh";

// Common HTTP header names & values
NSString *RTContentTypeHTTPHeader = @"Content-Type";
NSString *RTContentLengthHTTPHeader = @"Content-Length";
NSString *RTAcceptHTTPHeader = @"Accept";
NSString *RTAuthorizationHTTPHeader = @"Authorization";
NSString *RTBearerAuthorizationHTTPHeaderValue = @"Bearer";
NSString *RTBasicAuthorizationHTTPHeaderValue = @"Basic";
NSString *RTUserAgentHTTPHeader = @"User-Agent";
NSString *RTVersionHTTPHeader = @"X-Version";
NSString *RTBuildHTTPHeader = @"X-Build";

NSString *RTThriftContentType = @"application/x-thrift";
NSString *RTJSONContentType = @"application/json";
NSString *RTOctetStreamContentType = @"application/octet-stream";
NSString *RTTextContentTypePrefix = @"text/";


@implementation RTServerAPI

+(void) initialize
{
  NSURLComponents *baseURLComponents = [NSURLComponents new];
  baseURLComponents.scheme = RTServerScheme;
  baseURLComponents.host = RTServerHost;
  baseURLComponents.port = RTServerPort ? @(RTServerPort) : nil;

  RTBaseURL = baseURLComponents.URL;

  NSString *RTPinnedCertPath = [NSBundle.frameworkBundle pathForResource:RTPinnedCertName ofType:@"crt" inDirectory:@"Certificates"];
  NSData *RTPinnedCertData = [NSData dataWithContentsOfFile:RTPinnedCertPath];
  SecCertificateRef certificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)RTPinnedCertData);
  RTPinnedCerts = @[CFBridgingRelease(certificate)];
}

+(NSArray *) pinnedCerts
{
  return RTPinnedCerts;
}

+(NSString *) HTTPAuthorizationHeaderWithBearer:(NSString *)token
{
  return [@"Bearer " stringByAppendingString:token];
}

@end
