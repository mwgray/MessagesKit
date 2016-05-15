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

static NSString *PinnedCertName = @"master.retxt.io";
static NSArray *PinnedCerts;

NSString *UserAgent = @"reTXT (iOS)";

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
  NSString *PinnedCertPath = [NSBundle.mk_frameworkBundle pathForResource:PinnedCertName ofType:@"crt" inDirectory:@"Certificates"];
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
