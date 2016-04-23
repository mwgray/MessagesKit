//
//  RTChatDAO.m
//  ReTxt
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTChatDAO.h"

#import "RTMessageDAO.h"
#import "RTDAO+Internal.h"
#import "NSObject+Utils.h"

@import ObjectiveC;
@import YOLOKit;


@implementation RTChatDAO

+(void) initialize
{
  class_duplicateMethod(self, @selector(fetchChatWithId:), @selector(fetchObjectWithId:));
  class_duplicateMethod(self, @selector(fetchChatWithId:returning:error:), @selector(fetchObjectWithId:returning:error:));
  class_duplicateMethod(self, @selector(fetchAllChatsMatching:error:), @selector(fetchAllObjectsMatching:error:));
  class_duplicateMethod(self, @selector(fetchAllChatsMatching:parameters:error:), @selector(fetchAllObjectsMatching:parameters:error:));
  class_duplicateMethod(self, @selector(fetchAllChatsMatching:parametersNamed:error:), @selector(fetchAllObjectsMatching:parametersNamed:error:));
  class_duplicateMethod(self, @selector(fetchAllChatsMatching:offset:limit:sortedBy:error:), @selector(fetchAllObjectsMatching:offset:limit:sortedBy:error:));
  class_duplicateMethod(self, @selector(insertChat:error:), @selector(insertObject:error:));
  class_duplicateMethod(self, @selector(updateChat:error:), @selector(updateObject:error:));
  class_duplicateMethod(self, @selector(upsertChat:error:), @selector(upsertObject:error:));
  class_duplicateMethod(self, @selector(deleteChat:error:), @selector(deleteObject:error:));
  class_duplicateMethod(self, @selector(deleteAllChatsInArray:error:), @selector(deleteAllObjectsInArray:error:));
  class_duplicateMethod(self, @selector(deleteAllChatsAndReturnError:), @selector(deleteAllObjectsAndReturnError:));
  class_duplicateMethod(self, @selector(deleteAllChatsMatching:error:), @selector(deleteAllObjectsMatching:error:));
  class_duplicateMethod(self, @selector(deleteAllChatsMatching:parameters:error:), @selector(deleteAllObjectsMatching:parameters:error:));
  class_duplicateMethod(self, @selector(deleteAllChatsMatching:parametersNamed:error:), @selector(deleteAllObjectsMatching:parametersNamed:error:));
}

-(instancetype) initWithDBManager:(RTDBManager *)dbManager
{
  __block RTDBTableInfo *tableInfo;
  [dbManager.pool inReadableDatabase:^void(FMDatabase *db) {
    tableInfo = [RTDBTableInfo loadTableInfo:db tableName:@"chat"];
  }];
  
  self = [super initWithDBManager:dbManager
                        tableInfo:tableInfo
                        rootClass:[RTChat class]
                   derivedClasses:@[[RTUserChat class], [RTGroupChat class]]];
  if (self) {

    _aliasFieldIdx = [tableInfo findField:@"alias"];
    _localAliasFieldIdx = [tableInfo findField:@"localAlias"];
    _lastMessageFieldIdx = [tableInfo findField:@"lastMessage"];
    _clarifiedCountFieldIdx = [tableInfo findField:@"clarifiedCount"];
    _updatedCountFieldIdx = [tableInfo findField:@"updatedCount"];
    _startedDateFieldIdx = [tableInfo findField:@"startedDate"];
    _totalMessagesFieldIdx = [tableInfo findField:@"totalMessages"];
    _totalSentFieldIdx = [tableInfo findField:@"totalSent"];
    _customTitleFieldIdx = [tableInfo findField:@"customTitle"];
    _membersFieldIdx = [tableInfo findField:@"members"];
    _draftFieldIdx = [tableInfo findField:@"draft"];

    //FIXME
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(contactDidUpdate:)
//                                                 name:RTAddressBookContactUpdated
//                                               object:nil];

  }

  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(NSString *) name
{
  return @"Chat";
}

-(id) dbIdForId:(id)id
{
  return [id data];
}

-(RTChat *) fetchChatForAlias:(NSString *)alias localAlias:(NSString *)localAlias
{
  __block id res;

  [self.dbManager.pool inReadableDatabase:^(FMDatabase *db) {

    FMResultSet *resultSet = [db executeQuery:@"SELECT * FROM chat WHERE lower(alias) = ? AND lower(localAlias) = ?",
                              alias.lowercaseString, localAlias.lowercaseString];
    if ([resultSet next]) {
      res = [self load:resultSet error:nil]; //FIXME error handling
    }

    [resultSet close];
  }];

  return res;
}

-(BOOL) updateChat:(RTChat *)chat withLastMessage:(RTMessage *)message
{
  __block BOOL updated;

  [self.dbManager.pool inWritableDatabase:^(FMDatabase *db) {

    chat.lastMessage = message;

    if ([db executeUpdate:@"UPDATE chat SET lastMessage = ?, totalMessages = ?, totalSent = ?  WHERE id = ?",
         message.dbId, @(chat.totalMessages), @(chat.totalSent), chat.dbId])
    {
      updated = db.changes > 0;
    }

  }];

  if (updated) {

    [self updated:chat];
  }

  return updated;
}

-(BOOL) updateChat:(RTChat *)chat withLastSentMessage:(RTMessage *)message
{
  chat.totalSent += 1;
  chat.totalMessages += 1;

  return [self updateChat:chat withLastMessage:message];
}

-(BOOL) updateChat:(RTChat *)chat withLastReceivedMessage:(RTMessage *)message
{
  chat.totalMessages += 1;

  return [self updateChat:chat withLastMessage:message];
}

-(BOOL) updateChat:(RTGroupChat *)chat addGroupMember:(NSString *)alias
{
  if ([chat.members containsObject:alias]) {
    return NO;
  }

  return [self updateChat:chat
              withMembers:[chat.members setByAddingObject:alias]
            activeMembers:[chat.activeMembers setByAddingObject:alias]];
}

-(BOOL) updateChat:(RTGroupChat *)chat removeGroupMember:(NSString *)alias
{
  if (![chat.members containsObject:alias]) {
    return NO;
  }

  return [self updateChat:chat
              withMembers:chat.members
            activeMembers:chat.activeMembers.without(alias)];
}

-(BOOL) updateChat:(RTGroupChat *)chat withMembers:(NSSet *)members activeMembers:(NSSet *)activeMembers
{
  __block BOOL updated;

  [self.dbManager.pool inWritableDatabase:^(FMDatabase *db) {

    chat.members = members;
    chat.activeMembers = activeMembers;

    if ([db executeUpdate:@"UPDATE chat SET members = ?, activeMembers = ? WHERE id = ?",
         members.join(@","), activeMembers.join(@","), chat.dbId])
    {
      updated = db.changes > 0;
    }

  }];

  if (updated) {

    [self updated:chat];
  }

  return updated;
}

-(BOOL) deleteObject:(RTModel *)model error:(NSError * _Nullable __autoreleasing * _Nullable)error
{
  __block BOOL deleted;

  [self.dbManager.pool inTransaction:^(FMDatabase *db, BOOL *rollback) {

    deleted = [super deleteObject:model error:error];

    if (deleted) {

      RTMessageDAO *dao = self.dbManager[@"Message"];

      if (![dao deleteAllMessagesForChat:(id)model error:error]) {
        deleted = NO;
        return;
      }
    }

  }];

  return deleted;
}

-(BOOL) updateChat:(RTChat *)chat withClarifiedCount:(int)clarifiedCount
{
  __block BOOL updated;

  [self.dbManager.pool inWritableDatabase:^(FMDatabase *db) {

    chat.clarifiedCount = clarifiedCount;

    if ([db executeUpdate:@"UPDATE chat SET clarifiedCount = ? WHERE id = ?",
         @(clarifiedCount), chat.dbId])
    {
      updated = db.changes > 0;
    }

  }];

  if (updated) {

    [self updated:chat];
  }

  return updated;
}

-(BOOL) updateChat:(RTChat *)chat withUpdatedCount:(int)updatedCount
{
  __block BOOL updated;

  [self.dbManager.pool inWritableDatabase:^(FMDatabase *db) {

    chat.updatedCount = updatedCount;

    if ([db executeUpdate:@"UPDATE chat SET updatedCount = ? WHERE id = ?",
         @(updatedCount), chat.dbId])
    {
      updated = db.changes > 0;
    }

  }];

  if (updated) {

    [self updated:chat];
  }

  return updated;
}

-(BOOL) resetUnreadCountsForChat:(RTChat *)chat
{
  __block BOOL updated;

  [self.dbManager.pool inWritableDatabase:^(FMDatabase *db) {

    chat.updatedCount = 0;
    chat.clarifiedCount = 0;

    if ([db executeUpdate:@"UPDATE chat SET updatedCount = ?, clarifiedCount = ? WHERE id = ?", @(chat.updatedCount),
         @(chat.clarifiedCount), chat.dbId])
    {
      updated = db.changes > 0;
    }

  }];

  if (updated) {

    [self updated:chat];
  }

  return updated;
}

//FIXME - Replace
//#pragma mark - Contact updates
//
//-(void) contactDidUpdate:(NSNotification *)notification
//{
//  RTContact *contact = notification.userInfo[@"contact"];
//
//  for (RTContactAlias *alias in contact.aliases) {
//
//    NSArray *chats = [self fetchAllObjectsMatching:@"lower(alias) = :id OR lower(localAlias) = :id OR CONTAINS(members, :id, 1, 1)"
//                                   parametersNamed:@{@"id":alias.value.lowercaseString}];
//
//    for (RTChat *chat in chats) {
//
//      [chat invalidateCachedData];
//
//      [self updated:chat];
//    }
//
//  }
//}
//
@end


@implementation RTUserChat (DAO)

+(RTChatType) typeCode
{
  return RTChatTypeUser;
}

@end

@implementation RTGroupChat (DAO)

+(RTChatType) typeCode
{
  return RTChatTypeGroup;
}

@end
