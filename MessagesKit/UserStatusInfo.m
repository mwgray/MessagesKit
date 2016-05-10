//
//  UserStatusInfo.m
//  MessagesKit
//
//  Created by Kevin Wooten on 1/29/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "UserStatusInfo.h"

@implementation UserStatusInfo

-(instancetype) initWithStatus:(enum UserStatus)status forUser:(NSString *)userAlias inChat:(Chat *)chat;
{
  if ((self = [super init])) {
    _chat = chat;
    _userAlias = userAlias;
    _status = status;
  }

  return self;
}

+(instancetype) userStatus:(enum UserStatus)status forUser:(NSString *)userAlias inChat:(Chat *)chat;
{
  return [[UserStatusInfo alloc] initWithStatus:status forUser:userAlias inChat:chat];
}

-(BOOL) isEqual:(id)object
{
  if (![object isKindOfClass:[UserStatusInfo class]]) {
    return NO;
  }

  UserStatusInfo *other = object;

  return [self.chat isEqual:other.chat] && [self.userAlias isEqualToString:other.userAlias];
}

-(NSString *) statusString
{
  switch (self.status) {
  case UserStatusTyping:
    return @"Typing...";

  case UserStatusLocating:
    return @"Locating...";

  case UserStatusPhotographing:
    return @"Photographing...";

  case UserStatusRecordingAudio:
    return @"Recording audio...";

  case UserStatusRecordingVideo:
    return @"Recording video...";

  case UserStatusSelectingContact:
    return @"Selecting contact...";

  default:
    return @"";
    break;
  }
}

@end
