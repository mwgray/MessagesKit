//
//  NSError+Utils.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "NSError+Utils.h"

#import <Thrift/TTransportError.h>


@implementation NSError (Utils)

-(BOOL) checkDomain:(NSString *)domain code:(NSInteger)code
{
  return [self.domain isEqualToString:domain] && self.code == code;
}

-(BOOL) checkDomain:(NSString *)domain
{
  return [self.domain isEqualToString:domain];
}

@end
