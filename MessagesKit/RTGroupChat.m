//
//  RTGroupChat.m
//  MessagesKit
//
//  Created by Kevin Wooten on 2/6/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTGroupChat.h"

#import "RTChatDAO.h"
#import "RTMessages+Exts.h"
#import "NSObject+Utils.h"
#import "NSMutableDictionary+Utils.h"

@import YOLOKit;


@interface RTGroupChat () {
}

@end


@implementation RTGroupChat

-(BOOL) load:(FMResultSet *)resultSet dao:(RTChatDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }

  self.customTitle = [resultSet stringForColumnIndex:dao.customTitleFieldIdx];
  self.activeMembers = [NSSet setWithArray:[[resultSet stringForColumnIndex:dao.activeMembersFieldIdx] componentsSeparatedByString:@","]];
  self.members = [NSSet setWithArray:[[resultSet stringForColumnIndex:dao.membersFieldIdx] componentsSeparatedByString:@","]];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(RTDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super save:values dao:dao error:error]) {
    return NO;
  }

  [values setNillableObject:self.customTitle forKey:@"customTitle"];
  [values setNillableObject:[self.activeMembers.allObjects componentsJoinedByString:@","] forKey:@"activeMembers"];
  [values setNillableObject:[self.members.allObjects componentsJoinedByString:@","] forKey:@"members"];
  
  return YES;
}

-(RTId *) aliasId
{
  return [RTId idWithString:self.alias];
}

-(void) setAliasId:(RTId *)aliasId
{
  self.alias = aliasId.UUIDString;
}

-(void) setLastMessage:(RTMessage *)lastMessage
{
  [super setLastMessage:lastMessage];

  [self invalidateCachedData];
}

-(NSSet *) allRecipients
{
  return _members.without(self.localAlias);
}

-(NSSet *) activeRecipients
{
  return _activeMembers.without(self.localAlias);
}

-(BOOL) includesMe
{
  return [self.activeMembers containsObject:self.localAlias];
}

-(id) copy
{
  RTGroupChat *copy = [super copy];
  copy.customTitle = self.customTitle;
  copy.members = self.members;
  return copy;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:[RTGroupChat class]]) {
    return NO;
  }

  return [self isEquivalentToGroupChat:object];
}

-(BOOL) isEquivalentToGroupChat:(RTGroupChat *)chat
{
  return [super isEquivalentToChat:chat] &&
         isEqual(self.customTitle, chat.customTitle) &&
         isEqual(self.members, chat.members);
}

-(BOOL) includesUser:(NSString *)alias
{
  return [self.members containsObject:alias];
}

-(void) setCustomTitle:(NSString *)customTitle
{
  _customTitle = customTitle;
  [self invalidateCachedData];
}

-(void) setMembers:(NSSet *)members
{
  _members = members;
  [self invalidateCachedData];
}

-(BOOL) containsAlias:(NSString *)alias
{
  return [self.members containsObject:alias];
}

-(BOOL) containsAnyAlias:(NSArray *)aliases
{
  for (NSString *alias in aliases) {
    if ([self containsAlias:alias]) {
      return YES;
    }
  }

  return NO;
}

-(BOOL) isGroup
{
  return YES;
}

@end
