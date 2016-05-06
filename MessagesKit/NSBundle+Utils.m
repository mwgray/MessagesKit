//
//  NSBundle+Utils.m
//  MessagesKit
//
//  Created by Kevin Wooten on 4/23/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "NSBundle+Utils.h"


@implementation NSBundle (Utils)

+(instancetype)frameworkBundle
{
  return [NSBundle bundleWithIdentifier:@"com.retxt.MessagesKit"];
}

@end
