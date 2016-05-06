//
//  RTAPIError.m
//  MessagesKit
//
//  Created by Francisco Rimoldi on 29/04/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTAPIError.h"

#import "NSError+Utils.h"

@import Thrift;


@implementation RTAPIErrorFactory

+(NSError *) generalError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Unknown error"};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorGeneral userInfo:userInfo];

  return error;
}

+(NSError *) invalidResponseErrorWithStatusCode:(NSInteger)statusCode
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Invalid status code", @"status-code":@(statusCode)};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorInvalidResponseStatusCode userInfo:userInfo];

  return error;
}

+(NSError *) unableToParseResponseError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Unable to parse response"};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorUnableToParseResponse userInfo:userInfo];

  return error;
}

+(NSError *) userNotFoundError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"User not found"};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorUserNotFound userInfo:userInfo];

  return error;
}

+(NSError *) aliasAlreadyInvitedErrorForAlias:(NSString *)alias
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Alias already invited"};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorAliasAlreadyInvited userInfo:userInfo];

  return error;
}

+(NSError *) aliasNotAuthenticatedForAlias:(NSString *)alias
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Alias not authenticated", @"alias": alias};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorAliasNotAuthenticated userInfo:userInfo];

  return error;
}

+(NSError *) aliasInUseErrorForAlias:(NSString *)alias
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Alias in use", @"alias": alias};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorAliasInUse userInfo:userInfo];

  return error;
}

+(NSError *) aliasPinInvalidErrorForAlias:(NSString *)alias
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Alias pin invalid", @"alias": alias};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorAliasPinInvalid userInfo:userInfo];

  return error;
}

+(NSError *) deviceInUseError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Device in use"};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorDeviceInUse userInfo:userInfo];

  return error;
}

+(NSError *) invalidDeviceError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Invalid device error"};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorInvalidDevice userInfo:userInfo];

  return error;
}

+(NSError *) unableToAuthenticateError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Unable to authenticate"};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorUnableToAuthenticate userInfo:userInfo];

  return error;
}

+(NSError *) invalidAliasAuthenticationErrorForAlias:(NSString *)alias
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Invalid alias authentication", @"alias":alias};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorInvalidAliasAuhtentication userInfo:userInfo];

  return error;
}

+(NSError *) invalidAliasErrorWithAlias:(NSString *)alias
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Invalid alias", @"alias":alias};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorInvalidAlias userInfo:userInfo];

  return error;
}

+(NSError *) invalidSenderErrorWithSender:(NSString *)sender
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Invalid sender authentication", @"sender":sender};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorInvalidSender userInfo:userInfo];

  return error;
}

+(NSError *) invalidRecipientErrorWithRecipient:(NSString *)recipient
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Invalid recipient authentication", @"recipient":recipient};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorInvalidRecipient userInfo:userInfo];

  return error;
}

+(NSError *) invalidCredentialsErrorWithRecipient:(NSString *)recipient
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Invalid signature", @"recipient":recipient};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorInvalidCredentials userInfo:userInfo];

  return error;
}

+(NSError *) authenticationError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Invalid authentication credentials"};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorAuthenticationError userInfo:userInfo];

  return error;
}

+(NSError *) unknownChatTypeError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Unknown chat type"};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorUnknownChatType userInfo:userInfo];

  return error;
}

+(NSError *) deviceNotReadyError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Device not ready"};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorDeviceNotReady userInfo:userInfo];

  return error;
}

+(NSError *) unknownMessageError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Unknown message"};
  NSError *error = [[NSError alloc] initWithDomain:RTAPIErrorDomain code:RTAPIErrorUnknownMessage userInfo:userInfo];

  return error;
}

+(NSError *) translateError:(NSError *)error
{
  if ([error checkDomain:TTransportErrorDomain]) {
    switch (error.code) {
    case TTransportErrorUnknown:
      if ([error.userInfo[TTransportErrorHttpErrorKey] intValue] == THttpTransportErrorAuthentication) {
        return [NSError errorWithDomain:RTAPIErrorDomain
                                   code:RTAPIErrorAuthenticationError
                               userInfo:@{NSLocalizedDescriptionKey:@"Invalid Authentication Credentials",
                                          NSUnderlyingErrorKey: error}];
      }

    default:
      return [NSError errorWithDomain:RTAPIErrorDomain
                                 code:RTAPIErrorNetworkError
                             userInfo:@{NSLocalizedDescriptionKey:@"Error communicating with server",
                                        NSUnderlyingErrorKey: error}];

    }
  }

  if ([error checkDomain:NSURLErrorDomain code:NSURLErrorUserAuthenticationRequired]) {
    return [NSError errorWithDomain:RTAPIErrorDomain
                               code:RTAPIErrorAuthenticationError
                           userInfo:@{NSLocalizedDescriptionKey:@"Invalid Authentication Credentials",
                                      NSUnderlyingErrorKey: error}];
  }

  if ([error checkDomain:RTAPIErrorDomain]) {
    return error;
  }

  return [NSError errorWithDomain:RTAPIErrorDomain
                             code:RTAPIErrorGeneral
                         userInfo:@{NSUnderlyingErrorKey: error}];
}

@end


@implementation NSError (RTAPIError)

-(BOOL) checkAPIError:(RTAPIError)error
{
  return [self checkDomain:RTAPIErrorDomain code:error];
}

@end
