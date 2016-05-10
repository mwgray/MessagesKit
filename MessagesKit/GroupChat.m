//
//  GroupChat.m
//  MessagesKit
//
//  Created by Kevin Wooten on 2/6/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "GroupChat.h"

#import "ChatDAO.h"
#import "Messages+Exts.h"
#import "NSObject+Utils.h"
#import "NSMutableDictionary+Utils.h"

@import YOLOKit;


@interface GroupChat () {
}

@end


@implementation GroupChat

-(BOOL) load:(FMResultSet *)resultSet dao:(ChatDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }

  self.customTitle = [resultSet stringForColumnIndex:dao.customTitleFieldIdx];
  self.activeMembers = [NSSet setWithArray:[[resultSet stringForColumnIndex:dao.activeMembersFieldIdx] componentsSeparatedByString:@","]];
  self.members = [NSSet setWithArray:[[resultSet stringForColumnIndex:dao.membersFieldIdx] componentsSeparatedByString:@","]];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(DAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super save:values dao:dao error:error]) {
    return NO;
  }

  [values setNillableObject:self.customTitle forKey:@"customTitle"];
  [values setNillableObject:[self.activeMembers.allObjects componentsJoinedByString:@","] forKey:@"activeMembers"];
  [values setNillableObject:[self.members.allObjects componentsJoinedByString:@","] forKey:@"members"];
  
  return YES;
}

-(Id *) aliasId
{
  return [Id idWithString:self.alias];
}

-(void) setAliasId:(Id *)aliasId
{
  self.alias = aliasId.UUIDString;
}

-(void) setLastMessage:(Message *)lastMessage
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
  GroupChat *copy = [super copy];
  copy.customTitle = self.customTitle;
  copy.members = self.members;
  return copy;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:[GroupChat class]]) {
    return NO;
  }

  return [self isEquivalentToGroupChat:object];
}

-(BOOL) isEquivalentToGroupChat:(GroupChat *)chat
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
