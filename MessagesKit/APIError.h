//
//  APIError.h
//  MessagesKit
//
//  Created by Francisco Rimoldi on 29/04/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "Module.h"

static NSString *APIErrorDomain    = @"io.retxt.message-api";


// PublicAPI errors

typedef NS_ENUM (int, APIError) {
  APIErrorGeneral                       = 1,
  APIErrorUserNotFound                  = 2,
  APIErrorAliasInUse                    = 3,
  APIErrorDeviceInUse                   = 4,
  APIErrorUnableToAuthenticate          = 5,
  APIErrorInvalidAliasAuhtentication    = 6,
  APIErrorInvalidSender                 = 7,
  APIErrorInvalidRecipient              = 8,
  APIErrorAuthenticationError           = 9,
  APIErrorUnknownChatType               = 10,
  APIErrorServerError                   = 11,
  APIErrorAliasPinInvalid               = 12,
  APIErrorAliasNotAuthenticated         = 13,
  APIErrorDeviceNotReady                = 14,
  APIErrorInvalidDevice                 = 15,
  APIErrorUnknownMessage                = 16,
  APIErrorInvalidResponseStatusCode     = 17,
  APIErrorUnableToParseResponse         = 18,
  APIErrorInvalidCredentials            = 19,
  APIErrorInvalidAlias                  = 20,
  APIErrorAliasAlreadyInvited           = 21,
  APIErrorNetworkError                  = 22,
};



MESSAGES_KIT_INTERNAL
@interface APIErrorFactory : NSObject

+(NSError *) generalError;

+(NSError *) invalidResponseErrorWithStatusCode:(NSInteger)statusCode;
+(NSError *) unableToParseResponseError;

+(NSError *) userNotFoundError;
+(NSError *) authenticationError;
+(NSError *) unableToAuthenticateError;

+(NSError *) aliasNotAuthenticatedForAlias:(NSString *)alias;
+(NSError *) aliasInUseErrorForAlias:(NSString *)alias;
+(NSError *) aliasPinInvalidErrorForAlias:(NSString *)alias;
+(NSError *) aliasAlreadyInvitedErrorForAlias:(NSString *)alias;

+(NSError *) deviceInUseError;
+(NSError *) invalidDeviceError;

+(NSError *) invalidAliasAuthenticationErrorForAlias:(NSString *)alias;
+(NSError *) invalidAliasErrorWithAlias:(NSString *)alias;
+(NSError *) invalidSenderErrorWithSender:(NSString *)sender;
+(NSError *) invalidRecipientErrorWithRecipient:(NSString *)recipient;
+(NSError *) invalidCredentialsErrorWithRecipient:(NSString *)recipient;
+(NSError *) unknownChatTypeError;

+(NSError *) deviceNotReadyError;

+(NSError *) unknownMessageError;

+(NSError *) translateError:(NSError *)error;

@end


@interface NSError (APIError)

-(BOOL) checkAPIError:(APIError)error;

@end
