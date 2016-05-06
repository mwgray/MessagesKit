//
//  RTUserStatusInfo.m
//  MessagesKit
//
//  Created by Kevin Wooten on 1/29/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTUserStatusInfo.h"

@implementation RTUserStatusInfo

-(instancetype) initWithStatus:(enum RTUserStatus)status forUser:(NSString *)userAlias inChat:(RTChat *)chat;
{
  if ((self = [super init])) {
    _chat = chat;
    _userAlias = userAlias;
    _status = status;
  }

  return self;
}

+(instancetype) userStatus:(enum RTUserStatus)status forUser:(NSString *)userAlias inChat:(RTChat *)chat;
{
  return [[RTUserStatusInfo alloc] initWithStatus:status forUser:userAlias inChat:chat];
}

-(BOOL) isEqual:(id)object
{
  if (![object isKindOfClass:[RTUserStatusInfo class]]) {
    return NO;
  }

  RTUserStatusInfo *other = object;

  return [self.chat isEqual:other.chat] && [self.userAlias isEqualToString:other.userAlias];
}

-(NSString *) statusString
{
  switch (self.status) {
  case RTUserStatusTyping:
    return @"Typing...";

  case RTUserStatusLocating:
    return @"Locating...";

  case RTUserStatusPhotographing:
    return @"Photographing...";

  case RTUserStatusRecordingAudio:
    return @"Recording audio...";

  case RTUserStatusRecordingVideo:
    return @"Recording video...";

  case RTUserStatusSelectingContact:
    return @"Selecting contact...";

  default:
    return @"";
    break;
  }
}

@end
