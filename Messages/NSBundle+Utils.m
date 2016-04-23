//
//  NSBundle+Utils.m
//  Messages
//
//  Created by Kevin Wooten on 4/23/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "NSBundle+Utils.h"

#import "RTMessageAPI.h"


@implementation NSBundle (Utils)

+(instancetype)frameworkBundle
{
  return [NSBundle bundleForClass:RTMessageAPI.class];
}

@end
