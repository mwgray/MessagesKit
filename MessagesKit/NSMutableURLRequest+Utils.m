//
//  NSMutableURLRequest+Utils.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/12/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "NSMutableURLRequest+Utils.h"

#import "ServerAPI.h"

@implementation NSMutableURLRequest (Utils)

-(void) addHTTPBasicAuthorizationForUser:(NSString *)user password:(NSString *)password
{
  // Build/Add Basic Authentication Header
  NSString *userPassEncoded = [[[NSString stringWithFormat:@"%@:%@", user, password] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];

  [self setValue:[NSString stringWithFormat:@"%@ %@", BasicAuthorizationHTTPHeaderValue, userPassEncoded] forHTTPHeaderField:AuthorizationHTTPHeader];
}

-(void) addHTTPBearerAuthorizationWithToken:(NSString *)token
{
  // Build/Add Bearere Authentication Header
  [self setValue:[NSString stringWithFormat:@"%@ %@", BearerAuthorizationHTTPHeaderValue, token] forHTTPHeaderField:AuthorizationHTTPHeader];
}

-(void) addBuildNumber
{
  NSDictionary *infoDict = [[NSBundle bundleForClass:NSClassFromString(@"MessageAPI")] infoDictionary];
  [self setValue:[infoDict objectForKey:@"CFBundleVersion"] forHTTPHeaderField:BuildHTTPHeader];
}

@end
