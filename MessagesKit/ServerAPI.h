//
//  ServerAPI.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/13/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Messages.h"


NS_ASSUME_NONNULL_BEGIN


extern NSString *UserAgent;
extern int ServerTimeout;


// Common HTTP header names & values
extern NSString *ContentTypeHTTPHeader;
extern NSString *ContentLengthHTTPHeader;
extern NSString *AcceptHTTPHeader;
extern NSString *AuthorizationHTTPHeader;
extern NSString *BearerAuthorizationHTTPHeaderValue;
extern NSString *BasicAuthorizationHTTPHeaderValue;
extern NSString *UserAgentHTTPHeader;
extern NSString *BearerRefreshHTTPHeader;
extern NSString *VersionHTTPHeader;
extern NSString *BuildHTTPHeader;

extern NSString *ThriftContentType;
extern NSString *JSONContentType;
extern NSString *OctetStreamContentType;

// API Header & Param names
extern NSString *UserAPIFetchMsgIdParam;

extern NSString *MsgInfoHTTPHeader;



@interface ServerAPI : NSObject

+(NSArray *) pinnedCerts;

+(NSString *) HTTPAuthorizationHeaderWithBearer:(NSString *)token;

@end


NS_ASSUME_NONNULL_END
