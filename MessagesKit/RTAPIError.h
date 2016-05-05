//
//  RTAPIError.h
//  ReTxt
//
//  Created by Francisco Rimoldi on 29/04/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;


static NSString *RTAPIErrorDomain    = @"io.retxt.message-api";


// PublicAPI errors
typedef NS_ENUM (int, RTAPIError) {
  RTAPIErrorGeneral                       = 1,
  RTAPIErrorUserNotFound                  = 2,
  RTAPIErrorAliasInUse                    = 3,
  RTAPIErrorDeviceInUse                   = 4,
  RTAPIErrorUnableToAuthenticate          = 5,
  RTAPIErrorInvalidAliasAuhtentication    = 6,
  RTAPIErrorInvalidSender                 = 7,
  RTAPIErrorInvalidRecipient              = 8,
  RTAPIErrorAuthenticationError           = 9,
  RTAPIErrorUnknownChatType               = 10,
  RTAPIErrorServerError                   = 11,
  RTAPIErrorAliasPinInvalid               = 12,
  RTAPIErrorAliasNotAuthenticated         = 13,
  RTAPIErrorDeviceNotReady                = 14,
  RTAPIErrorInvalidDevice                 = 15,
  RTAPIErrorUnknownMessage                = 16,
  RTAPIErrorInvalidResponseStatusCode     = 17,
  RTAPIErrorUnableToParseResponse         = 18,
  RTAPIErrorInvalidCredentials            = 19,
  RTAPIErrorInvalidAlias                  = 20,
  RTAPIErrorAliasAlreadyInvited           = 21,
  RTAPIErrorNetworkError                  = 22,
};


@interface RTAPIErrorFactory : NSObject

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


@interface NSError (RTAPIError)

-(BOOL) checkAPIError:(RTAPIError)error;

@end
