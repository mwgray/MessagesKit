//
//  NSBundle+Utils.m
//  MessagesKit
//
//  Created by Kevin Wooten on 4/23/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "NSBundle+Utils.h"

#import "Message.h"


@implementation NSBundle (Utils)

+(instancetype) mk_frameworkBundle
{
  return [NSBundle bundleForClass:Message.class];
}

@end
