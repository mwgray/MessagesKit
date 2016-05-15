//
//  ServerAPI.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/13/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Messages.h"
#import "Module.h"


NS_ASSUME_NONNULL_BEGIN


MESSAGES_KIT_INTERNAL extern NSString *UserAgent;
MESSAGES_KIT_INTERNAL extern int ServerTimeout;


// Common HTTP header names & values
MESSAGES_KIT_INTERNAL extern NSString *ContentTypeHTTPHeader;
MESSAGES_KIT_INTERNAL extern NSString *ContentLengthHTTPHeader;
MESSAGES_KIT_INTERNAL extern NSString *AcceptHTTPHeader;
MESSAGES_KIT_INTERNAL extern NSString *AuthorizationHTTPHeader;
MESSAGES_KIT_INTERNAL extern NSString *BearerAuthorizationHTTPHeaderValue;
MESSAGES_KIT_INTERNAL extern NSString *BasicAuthorizationHTTPHeaderValue;
MESSAGES_KIT_INTERNAL extern NSString *UserAgentHTTPHeader;
MESSAGES_KIT_INTERNAL extern NSString *BearerRefreshHTTPHeader;
MESSAGES_KIT_INTERNAL extern NSString *VersionHTTPHeader;
MESSAGES_KIT_INTERNAL extern NSString *BuildHTTPHeader;

MESSAGES_KIT_INTERNAL extern NSString *ThriftContentType;
MESSAGES_KIT_INTERNAL extern NSString *JSONContentType;
MESSAGES_KIT_INTERNAL extern NSString *OctetStreamContentType;

// API Header & Param names
MESSAGES_KIT_INTERNAL extern NSString *UserAPIFetchMsgIdParam;

MESSAGES_KIT_INTERNAL extern NSString *MsgInfoHTTPHeader;



MESSAGES_KIT_INTERNAL
@interface ServerAPI : NSObject

+(NSArray *) pinnedCerts;

+(NSString *) HTTPAuthorizationHeaderWithBearer:(NSString *)token;

@end


NS_ASSUME_NONNULL_END
