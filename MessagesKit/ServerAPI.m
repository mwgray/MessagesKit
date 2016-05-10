//
//  ServerAPI.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/13/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "ServerAPI.h"

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
# define _SERVER_DOMAIN_ENV "prd"
#elif defined(RETXT_STAGE)
# define _SERVER_DOMAIN_ENV "stg"
#elif defined(RETXT_DEV)
# define _SERVER_DOMAIN_ENV "dev"
#elif defined(RETXT_LOCAL)
# define _SERVER_DOMAIN_ENV "lcl"
#else
# error NO RETXT SERVER TARGET DEFINED
#endif


NSString *ServerEnvironmentName =
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
NSString *ServerScheme = @"http";
NSString *ServerHost = @"192.168.100.10";
NSInteger ServerPort = 8080;
#else
NSString *ServerScheme = @"https";
NSString *ServerHost = @"master." _SERVER_DOMAIN_ENV ".retxt.io";
NSInteger ServerPort = 0;
#endif


static NSString *PinnedCertName = @"master.retxt.io";
static NSArray *PinnedCerts;


NSURL *BaseURL;
NSString *UserAgent = @"reTXT (iOS)";
int ServerTimeout = 15;

NSString *UserAPIFetchMsgIdParam = @"msgId";

NSString *MsgInfoHTTPHeader = @"X-Msg-Info";
NSString *BearerRefreshHTTPHeader = @"X-Bearer-Refresh";

// Common HTTP header names & values
NSString *ContentTypeHTTPHeader = @"Content-Type";
NSString *ContentLengthHTTPHeader = @"Content-Length";
NSString *AcceptHTTPHeader = @"Accept";
NSString *AuthorizationHTTPHeader = @"Authorization";
NSString *BearerAuthorizationHTTPHeaderValue = @"Bearer";
NSString *BasicAuthorizationHTTPHeaderValue = @"Basic";
NSString *UserAgentHTTPHeader = @"User-Agent";
NSString *VersionHTTPHeader = @"X-Version";
NSString *BuildHTTPHeader = @"X-Build";

NSString *ThriftContentType = @"application/x-thrift";
NSString *JSONContentType = @"application/json";
NSString *OctetStreamContentType = @"application/octet-stream";
NSString *TextContentTypePrefix = @"text/";


@implementation ServerAPI

+(void) initialize
{
  NSURLComponents *baseURLComponents = [NSURLComponents new];
  baseURLComponents.scheme = ServerScheme;
  baseURLComponents.host = ServerHost;
  baseURLComponents.port = ServerPort ? @(ServerPort) : nil;

  BaseURL = baseURLComponents.URL;

  NSString *PinnedCertPath = [NSBundle.frameworkBundle pathForResource:PinnedCertName ofType:@"crt" inDirectory:@"Certificates"];
  NSData *PinnedCertData = [NSData dataWithContentsOfFile:PinnedCertPath];
  SecCertificateRef certificate = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)PinnedCertData);
  PinnedCerts = @[CFBridgingRelease(certificate)];
}

+(NSArray *) pinnedCerts
{
  return PinnedCerts;
}

+(NSString *) HTTPAuthorizationHeaderWithBearer:(NSString *)token
{
  return [@"Bearer " stringByAppendingString:token];
}

@end
