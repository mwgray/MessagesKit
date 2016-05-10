//
//  APIError.m
//  MessagesKit
//
//  Created by Francisco Rimoldi on 29/04/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "APIError.h"

#import "NSError+Utils.h"

@import Thrift;


@implementation APIErrorFactory

+(NSError *) generalError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Unknown error"};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorGeneral userInfo:userInfo];

  return error;
}

+(NSError *) invalidResponseErrorWithStatusCode:(NSInteger)statusCode
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Invalid status code", @"status-code":@(statusCode)};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorInvalidResponseStatusCode userInfo:userInfo];

  return error;
}

+(NSError *) unableToParseResponseError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Unable to parse response"};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorUnableToParseResponse userInfo:userInfo];

  return error;
}

+(NSError *) userNotFoundError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"User not found"};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorUserNotFound userInfo:userInfo];

  return error;
}

+(NSError *) aliasAlreadyInvitedErrorForAlias:(NSString *)alias
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Alias already invited"};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorAliasAlreadyInvited userInfo:userInfo];

  return error;
}

+(NSError *) aliasNotAuthenticatedForAlias:(NSString *)alias
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Alias not authenticated", @"alias": alias};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorAliasNotAuthenticated userInfo:userInfo];

  return error;
}

+(NSError *) aliasInUseErrorForAlias:(NSString *)alias
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Alias in use", @"alias": alias};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorAliasInUse userInfo:userInfo];

  return error;
}

+(NSError *) aliasPinInvalidErrorForAlias:(NSString *)alias
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Alias pin invalid", @"alias": alias};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorAliasPinInvalid userInfo:userInfo];

  return error;
}

+(NSError *) deviceInUseError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Device in use"};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorDeviceInUse userInfo:userInfo];

  return error;
}

+(NSError *) invalidDeviceError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Invalid device error"};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorInvalidDevice userInfo:userInfo];

  return error;
}

+(NSError *) unableToAuthenticateError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Unable to authenticate"};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorUnableToAuthenticate userInfo:userInfo];

  return error;
}

+(NSError *) invalidAliasAuthenticationErrorForAlias:(NSString *)alias
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Invalid alias authentication", @"alias":alias};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorInvalidAliasAuhtentication userInfo:userInfo];

  return error;
}

+(NSError *) invalidAliasErrorWithAlias:(NSString *)alias
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Invalid alias", @"alias":alias};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorInvalidAlias userInfo:userInfo];

  return error;
}

+(NSError *) invalidSenderErrorWithSender:(NSString *)sender
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Invalid sender authentication", @"sender":sender};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorInvalidSender userInfo:userInfo];

  return error;
}

+(NSError *) invalidRecipientErrorWithRecipient:(NSString *)recipient
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Invalid recipient authentication", @"recipient":recipient};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorInvalidRecipient userInfo:userInfo];

  return error;
}

+(NSError *) invalidCredentialsErrorWithRecipient:(NSString *)recipient
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Invalid signature", @"recipient":recipient};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorInvalidCredentials userInfo:userInfo];

  return error;
}

+(NSError *) authenticationError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Invalid authentication credentials"};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorAuthenticationError userInfo:userInfo];

  return error;
}

+(NSError *) unknownChatTypeError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Unknown chat type"};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorUnknownChatType userInfo:userInfo];

  return error;
}

+(NSError *) deviceNotReadyError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Device not ready"};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorDeviceNotReady userInfo:userInfo];

  return error;
}

+(NSError *) unknownMessageError
{
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey : @"Unknown message"};
  NSError *error = [[NSError alloc] initWithDomain:APIErrorDomain code:APIErrorUnknownMessage userInfo:userInfo];

  return error;
}

+(NSError *) translateError:(NSError *)error
{
  if ([error checkDomain:TTransportErrorDomain]) {
    switch (error.code) {
    case TTransportErrorUnknown:
      if ([error.userInfo[TTransportErrorHttpErrorKey] intValue] == THttpTransportErrorAuthentication) {
        return [NSError errorWithDomain:APIErrorDomain
                                   code:APIErrorAuthenticationError
                               userInfo:@{NSLocalizedDescriptionKey:@"Invalid Authentication Credentials",
                                          NSUnderlyingErrorKey: error}];
      }

    default:
      return [NSError errorWithDomain:APIErrorDomain
                                 code:APIErrorNetworkError
                             userInfo:@{NSLocalizedDescriptionKey:@"Error communicating with server",
                                        NSUnderlyingErrorKey: error}];

    }
  }

  if ([error checkDomain:NSURLErrorDomain code:NSURLErrorUserAuthenticationRequired]) {
    return [NSError errorWithDomain:APIErrorDomain
                               code:APIErrorAuthenticationError
                           userInfo:@{NSLocalizedDescriptionKey:@"Invalid Authentication Credentials",
                                      NSUnderlyingErrorKey: error}];
  }

  if ([error checkDomain:APIErrorDomain]) {
    return error;
  }

  return [NSError errorWithDomain:APIErrorDomain
                             code:APIErrorGeneral
                         userInfo:@{NSUnderlyingErrorKey: error}];
}

@end


@implementation NSError (APIError)

-(BOOL) checkAPIError:(APIError)error
{
  return [self checkDomain:APIErrorDomain code:error];
}

@end
