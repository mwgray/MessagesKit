//
//  RTUserChat.m
//  MessagesKit
//
//  Created by Kevin Wooten on 1/26/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTUserChat.h"


@implementation RTUserChat

-(id) copy
{
  RTUserChat *copy = [super copy];
  return copy;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:[RTUserChat class]]) {
    return NO;
  }

  return [self isEquivalentToUserChat:object];
}

-(BOOL) isEquivalentToUserChat:(RTUserChat *)chat
{
  return [super isEquivalentToChat:chat];
}

@end
