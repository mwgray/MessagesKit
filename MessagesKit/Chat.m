//
//  Chat.m
//  MessagesKit
//
//  Created by Kevin Wooten on 1/26/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Chat.h"

#import "ChatDAO.h"
#import "MessageDAO.h"
#import "Messages+Exts.h"
#import "NSObject+Utils.h"
#import "NSDate+Utils.h"
#import "FMResultSet+Utils.h"
#import "NSMutableDictionary+Utils.h"


@interface Chat ()
@end


@implementation Chat

@synthesize id=_id;

-(id) dbId
{
  return self.id.data;
}

-(void) setDbId:(id)dbId
{
  self.id = [Id idWithData:dbId];
}

-(BOOL) load:(FMResultSet *)resultSet dao:(ChatDAO *)dao error:(NSError *__autoreleasing *)error
{
  if(![super load:resultSet dao:dao error:error]) {
    return NO;
  }

  MessageDAO *messageDAO = dao.dbManager[@"Message"];

  self.alias = [resultSet stringForColumnIndex:dao.aliasFieldIdx];
  self.localAlias = [resultSet stringForColumnIndex:dao.localAliasFieldIdx];
  
  Message *lastMessage = nil;

  Id *lastMessageId = [resultSet idForColumnIndex:dao.lastMessageFieldIdx];
  if (lastMessageId) {
    if (![messageDAO fetchMessageWithId:lastMessageId
                              returning:&lastMessage
                                  error:error]) {
      return NO;
    }
  }
  
  self.lastMessage = lastMessage;
  self.clarifiedCount = [resultSet intForColumnIndex:dao.clarifiedCountFieldIdx];
  self.updatedCount = [resultSet intForColumnIndex:dao.updatedCountFieldIdx];
  self.startedDate = [resultSet dateForColumnIndex:dao.startedDateFieldIdx];
  self.totalMessages = [resultSet intForColumnIndex:dao.totalMessagesFieldIdx];
  self.totalSent = [resultSet intForColumnIndex:dao.totalSentFieldIdx];
  self.draft = [resultSet nillableObjectForColumnIndex:dao.draftFieldIdx];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(DAO *)dao error:(NSError *__autoreleasing *)error
{
  if(![super save:values dao:dao error:error]) {
    return NO;
  }

  [values setNillableObject:self.alias forKey:@"alias"];
  [values setNillableObject:self.localAlias forKey:@"localAlias"];
  [values setNillableObject:self.lastMessage.dbId forKey:@"lastMessage"];
  [values setNillableObject:@(self.clarifiedCount) forKey:@"clarifiedCount"];
  [values setNillableObject:@(self.updatedCount) forKey:@"updatedCount"];
  [values setNillableObject:self.startedDate forKey:@"startedDate"];
  [values setNillableObject:@(self.totalMessages) forKey:@"totalMessages"];
  [values setNillableObject:@(self.totalSent) forKey:@"totalSent"];
  [values setNillableObject:self.draft forKey:@"draft"];
  
  return YES;
}

-(id) copy
{
  Chat *copy = [[self class] new];
  copy.id = self.id;
  copy.alias = self.alias;
  copy.localAlias = self.localAlias;
  copy.lastMessage = self.lastMessage;
  copy.clarifiedCount = self.clarifiedCount;
  copy.updatedCount = self.updatedCount;
  copy.startedDate = self.startedDate;
  copy.totalMessages = self.totalMessages;
  copy.totalSent = self.totalSent;
  copy.draft = self.draft;
  return copy;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:[Chat class]]) {
    return NO;
  }

  return [self isEquivalentToChat:object];
}

-(BOOL) isEquivalentToChat:(Chat *)chat
{
  return isEqual(self.id, chat.id) &&
         isEqual(self.alias, chat.alias) &&
         isEqual(self.localAlias, chat.localAlias) &&
         isEqual(self.lastMessage, chat.lastMessage) &&
         (self.clarifiedCount == chat.clarifiedCount) &&
         (self.updatedCount == chat.updatedCount) &&
         isEqual(self.startedDate, chat.startedDate) &&
         (self.totalMessages == chat.totalMessages) &&
         (self.totalSent == chat.totalSent) &&
         isEqual(self.draft, chat.draft);
}

-(NSSet *) activeRecipients
{
  return [NSSet setWithObject:self.alias];
}

-(NSSet *) allRecipients
{
  return [NSSet setWithObject:self.alias];
}

-(NSString *) description
{
  return [NSString stringWithFormat:@"%@-%@", self.localAlias, self.alias];
}

-(BOOL) isGroup
{
  return NO;
}

@end
