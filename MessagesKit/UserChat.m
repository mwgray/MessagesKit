//
//  UserChat.m
//  MessagesKit
//
//  Created by Kevin Wooten on 1/26/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "UserChat.h"


@implementation UserChat

-(id) copy
{
  UserChat *copy = [super copy];
  return copy;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:[UserChat class]]) {
    return NO;
  }

  return [self isEquivalentToUserChat:object];
}

-(BOOL) isEquivalentToUserChat:(UserChat *)chat
{
  return [super isEquivalentToChat:chat];
}

@end
