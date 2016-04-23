//
//  NSMutableURLRequest+Utils.m
//  ReTxt
//
//  Created by Kevin Wooten on 7/12/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "NSMutableURLRequest+Utils.h"

#import "RTServerAPI.h"

@implementation NSMutableURLRequest (Utils)

-(void) addHTTPBasicAuthorizationForUser:(NSString *)user password:(NSString *)password
{
  // Build/Add Basic Authentication Header
  NSString *userPassEncoded = [[[NSString stringWithFormat:@"%@:%@", user, password] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];

  [self setValue:[NSString stringWithFormat:@"%@ %@", RTBasicAuthorizationHTTPHeaderValue, userPassEncoded] forHTTPHeaderField:RTAuthorizationHTTPHeader];
}

-(void) addHTTPBearerAuthorizationWithToken:(NSString *)token
{
  // Build/Add Bearere Authentication Header
  [self setValue:[NSString stringWithFormat:@"%@ %@", RTBearerAuthorizationHTTPHeaderValue, token] forHTTPHeaderField:RTAuthorizationHTTPHeader];
}

-(void) addBuildNumber
{
  NSDictionary *infoDict = [[NSBundle bundleForClass:NSClassFromString(@"RTMessageAPI")] infoDictionary];
  [self setValue:[infoDict objectForKey:@"CFBundleVersion"] forHTTPHeaderField:RTBuildHTTPHeader];
}

@end
