//
//  NSMutableURLRequest+Utils.h
//  ReTxt
//
//  Created by Kevin Wooten on 7/12/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableURLRequest (Utils)

-(void) addHTTPBasicAuthorizationForUser:(NSString *)user password:(NSString *)password;

-(void) addHTTPBearerAuthorizationWithToken:(NSString *)token;

-(void) addBuildNumber;

@end
