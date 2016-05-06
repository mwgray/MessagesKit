//
//  RTServerAPI.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/13/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessages.h"


NS_ASSUME_NONNULL_BEGIN


extern NSString *RTUserAgent;
extern int RTServerTimeout;


// Common HTTP header names & values
extern NSString *RTContentTypeHTTPHeader;
extern NSString *RTContentLengthHTTPHeader;
extern NSString *RTAcceptHTTPHeader;
extern NSString *RTAuthorizationHTTPHeader;
extern NSString *RTBearerAuthorizationHTTPHeaderValue;
extern NSString *RTBasicAuthorizationHTTPHeaderValue;
extern NSString *RTUserAgentHTTPHeader;
extern NSString *RTBearerRefreshHTTPHeader;
extern NSString *RTVersionHTTPHeader;
extern NSString *RTBuildHTTPHeader;

extern NSString *RTThriftContentType;
extern NSString *RTJSONContentType;
extern NSString *RTOctetStreamContentType;

// API Header & Param names
extern NSString *RTUserAPIFetchMsgIdParam;

extern NSString *RTMsgInfoHTTPHeader;



@interface RTServerAPI : NSObject

+(NSArray *) pinnedCerts;

+(NSString *) HTTPAuthorizationHeaderWithBearer:(NSString *)token;

@end


NS_ASSUME_NONNULL_END
