//
//  RTMessageDAO.m
//  ReTxt
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessageDAO.h"

#import "RTDAO+Internal.h"
#import "NSObject+Utils.h"

#import "RTChat.h"
#import "RTTextMessage.h"
#import "RTImageMessage.h"
#import "RTAudioMessage.h"
#import "RTVideoMessage.h"
#import "RTContactMessage.h"
#import "RTLocationMessage.h"
#import "RTEnterMessage.h"
#import "RTExitMessage.h"
#import "RTConferenceMessage.h"

@import ObjectiveC;


@implementation RTMessageDAO

+(void) initialize
{
  class_duplicateMethod(self, @selector(fetchMessageWithId:), @selector(fetchObjectWithId:));
  class_duplicateMethod(self, @selector(fetchMessageWithId:returning:error:), @selector(fetchObjectWithId:returning:error:));
  class_duplicateMethod(self, @selector(fetchAllMessagesMatching:error:), @selector(fetchAllObjectsMatching:error:));
  class_duplicateMethod(self, @selector(fetchAllMessagesMatching:parameters:error:), @selector(fetchAllObjectsMatching:parameters:error:));
  class_duplicateMethod(self, @selector(fetchAllMessagesMatching:parametersNamed:error:), @selector(fetchAllObjectsMatching:parametersNamed:error:));
  class_duplicateMethod(self, @selector(fetchAllMessagesMatching:offset:limit:sortedBy:error:), @selector(fetchAllObjectsMatching:offset:limit:sortedBy:error:));
  class_duplicateMethod(self, @selector(insertMessage:error:), @selector(insertObject:error:));
  class_duplicateMethod(self, @selector(updateMessage:error:), @selector(updateObject:error:));
  class_duplicateMethod(self, @selector(upsertMessage:error:), @selector(upsertObject:error:));
  class_duplicateMethod(self, @selector(deleteMessage:error:), @selector(deleteObject:error:));
  class_duplicateMethod(self, @selector(deleteAllMessagesInArray:error:), @selector(deleteAllObjectsInArray:error:));
  class_duplicateMethod(self, @selector(deleteAllMessagesAndReturnError:), @selector(deleteAllObjectsAndReturnError:));
  class_duplicateMethod(self, @selector(deleteAllMessagesMatching:error:), @selector(deleteAllObjectsMatching:error:));
  class_duplicateMethod(self, @selector(deleteAllMessagesMatching:parameters:error:), @selector(deleteAllObjectsMatching:parameters:error:));
  class_duplicateMethod(self, @selector(deleteAllMessagesMatching:parametersNamed:error:), @selector(deleteAllObjectsMatching:parametersNamed:error:));
}

-(instancetype) initWithDBManager:(RTDBManager *)dbManager
{
  __block RTDBTableInfo *tableInfo;
  [dbManager.pool inReadableDatabase:^(FMDatabase *db) {
    tableInfo = [RTDBTableInfo loadTableInfo:db tableName:@"message"];
  }];
  
  self = [super initWithDBManager:dbManager
                        tableInfo:tableInfo
                        rootClass:RTMessage.class
                   derivedClasses:@[RTTextMessage.class, RTImageMessage.class, RTAudioMessage.class,
                                    RTVideoMessage.class, RTLocationMessage.class, RTContactMessage.class,
                                    RTEnterMessage.class, RTExitMessage.class, RTConferenceMessage.class]];
  if (self) {

    _chatFieldIdx = [tableInfo findField:@"chat"];
    _senderFieldIdx = [tableInfo findField:@"sender"];
    _sentFieldIdx = [tableInfo findField:@"sent"];
    _updatedFieldIdx = [tableInfo findField:@"updated"];
    _statusFieldIdx = [tableInfo findField:@"status"];
    _statusTimestampFieldIdx = [tableInfo findField:@"statusTimestamp"];
    _flagsFieldIdx = [tableInfo findField:@"flags"];
    _data1FieldIdx = [tableInfo findField:@"data1"];
    _data2FieldIdx = [tableInfo findField:@"data2"];
    _data3FieldIdx = [tableInfo findField:@"data3"];
    _data4FieldIdx = [tableInfo findField:@"data4"];

  }

  return self;
}

-(NSString *) name
{
  return @"Message";
}

-(id) dbIdForId:(id)id
{
  return [id data];
}

-(void) failAllSendingMessagesExcluding:(NSArray *)excludedMessageIds
{
  [self.dbManager.pool inWritableDatabase:^(FMDatabase *db) {

    NSMutableArray *params = [@[@(RTMessageStatusFailed), @(RTMessageStatusSending)] mutableCopy];
    NSMutableArray *paramSpecs = [NSMutableArray new];

    for (RTId *excludedMessageId in excludedMessageIds) {
      [params addObject:excludedMessageId];
      [paramSpecs addObject:@"?"];
    }

    NSString *sql = [NSString stringWithFormat:@"UPDATE message SET status = ? WHERE status = ? AND id NOT IN (%@)", [paramSpecs componentsJoinedByString:@","]];

    [db executeUpdate:sql withArgumentsInArray:params];

  }];
}

-(NSArray *) fetchUnsentMessagesAndReturnError:(NSError **)error
{
  __block NSArray *res;

  [self.dbManager.pool inReadableDatabase:^(FMDatabase *db) {

    FMResultSet *resultSet = [db executeQuery:@"SELECT * FROM message WHERE status < ?",
                              @(RTMessageStatusSending)];

    res = [self loadAll:resultSet error:error];

    [resultSet close];
  }];

  return res;
}

-(RTMessage *) fetchLatestUnviewedMessageForChat:(RTChat *)chat
{
  __block RTMessage *res = nil;

  [self.dbManager.pool inReadableDatabase:^(FMDatabase *db) {

    FMResultSet *resultSet = [db executeQuery:@"SELECT * FROM message WHERE chat = ? AND sender <> ? AND status < ? ORDER BY sent DESC LIMIT 1",
                              chat.dbId, chat.localAlias, @(RTMessageStatusViewed)];

    if ([resultSet next]) {

      res = [self load:resultSet error:nil]; //FIXME error handling

    }

    [resultSet close];
  }];

  return res;
}

-(RTMessage *) fetchLastMessageForChat:(RTChat *)chat
{
  __block RTMessage *res = nil;

  [self.dbManager.pool inReadableDatabase:^(FMDatabase *db) {

    FMResultSet *resultSet = [db executeQuery:@"SELECT * FROM message WHERE chat = ? ORDER BY sent DESC LIMIT 1",
                              chat.dbId];

    if ([resultSet next]) {

      res = [self load:resultSet error:nil]; //FIXME error handling

    }

    [resultSet close];
  }];

  return res;
}


-(BOOL) viewAllMessagesForChat:(RTChat *)chat before:(NSDate *)sent error:(NSError **)error
{
  __block BOOL valid = NO;
  __block NSArray *updated;
  __block int count =0;

  [self.dbManager.pool inTransaction:^(FMDatabase *db, BOOL *rollback) {

    FMResultSet *resultSet = [db executeQuery:@"SELECT * FROM message WHERE chat = ? AND sender <> ? AND status < ? AND sent <= ?"
                                  valuesArray:@[chat.dbId, chat.localAlias, @(RTMessageStatusViewed), sent]
                                        error:error];
    if (!resultSet) {
      *rollback = YES;
      return;
    }

    updated = [self loadAll:resultSet error:error];
    [resultSet close];
    
    if (!updated) {
      *rollback = YES;
      return;
    }

    NSDate *now = [NSDate date];

    valid = [db executeUpdate:@"UPDATE message SET status = ?, statusTimestamp = ? WHERE chat = ? AND sender <> ? AND status < ? AND sent <= ?"
                  valuesArray:@[@(RTMessageStatusViewed), now, chat.dbId, chat.localAlias, @(RTMessageStatusViewed), sent]
                        error:error];
    if (!valid) {
      *rollback = YES;
      return;
    }
    
    count = db.changes;

    for (RTMessage *up in updated) {
      up.status = RTMessageStatusViewed;
      up.statusTimestamp = now;
    }
    
  }];
  
  if (count && updated) {
    [self updatedAll:updated];
  }

  return valid;
}

-(BOOL) readAllMessagesForChat:(RTChat *)chat error:(NSError **)error
{
  __block BOOL valid = NO;
  __block NSArray *updated;
  __block int count =0;

  [self.dbManager.pool inTransaction:^(FMDatabase *db, BOOL *rollback) {

    FMResultSet *resultSet = [db executeQuery:@"SELECT * FROM message WHERE chat = ? AND flags & ?"
                                  valuesArray:@[chat.dbId, @(RTMessageFlagUnread)]
                                        error:error];
    if (!resultSet) {
      *rollback = YES;
      return;
    }
    
    updated = [self loadAll:resultSet error:error];
    [resultSet close];
    
    if (!updated) {
      *rollback = YES;
      return;
    }

    valid = [db executeUpdate:@"UPDATE message SET flags = flags & ? WHERE chat = ? AND flags & ?"
                  valuesArray:@[@(~RTMessageFlagUnread), chat.dbId, @(RTMessageFlagUnread)]
                        error:error];
    if (!valid) {
      *rollback = YES;
      return;
    }
    
    count = db.changes;
    
    for (RTMessage *msg in updated) {
      msg.unreadFlag = NO;
    }
    
  }];

  if (count && updated) {
    [self updatedAll:updated];
  }

  return valid;
}

-(BOOL) updateMessage:(RTMessage *)message withStatus:(RTMessageStatus)status error:(NSError **)error
{
  return [self updateMessage:message withStatus:status timestamp:[NSDate date] error:error];
}

-(BOOL) updateMessage:(RTMessage *)message withStatus:(RTMessageStatus)status timestamp:(NSDate *)timestamp error:(NSError **)error
{
  __block BOOL valid = NO;
  __block BOOL updated = NO;

  [self.dbManager.pool inWritableDatabase:^(FMDatabase *db) {

    message.status = status;
    message.statusTimestamp = timestamp;

    valid = [db executeUpdate:@"UPDATE message SET status = ?, statusTimestamp = ? WHERE id = ?"
                  valuesArray:@[@(status), timestamp, message.dbId]
                        error:error];
    if (!valid) {
      return;
    }
    
    updated = db.changes > 0;
  }];

  if (updated) {

    [self.objectCache setObject:message forKey:message.dbId];

    [self updated:message];
  }

  return valid;
}

-(BOOL) updateMessage:(RTMessage *)message withSent:(NSDate *)sent error:(NSError **)error
{
  __block BOOL valid = NO;
  __block BOOL updated = NO;

  [self.dbManager.pool inWritableDatabase:^(FMDatabase *db) {

    message.sent = sent;

    valid = [db executeUpdate:@"UPDATE message SET sent = ? WHERE id = ?"
                  valuesArray:@[sent, message.dbId]
                        error:error];
    if(!valid) {
      return;
    }
    
    updated = db.changes > 0;
  }];

  if (updated) {

    [self.objectCache setObject:message forKey:message.dbId];

    [self updated:message];
  }

  return valid;
}

-(BOOL) updateMessage:(RTMessage *)message withFlags:(int64_t)flags error:(NSError **)error
{
  __block BOOL valid = NO;
  __block BOOL updated = NO;

  [self.dbManager.pool inWritableDatabase:^(FMDatabase *db) {

    message.flags = flags;

    valid = [db executeUpdate:@"UPDATE message SET flags = ? WHERE id = ?"
                  valuesArray:@[@(flags), message.dbId]
                        error:error];
    if (!valid) {
      return;
    }

    updated = db.changes > 0;
  }];

  if (updated) {

    [self.objectCache setObject:message forKey:message.dbId];

    [self updated:message];
  }

  return valid;
}

-(BOOL) deleteAllMessagesForChat:(RTChat *)chat error:(NSError **)error
{
  __block NSArray *deleted;
  __block int count = 0;

  [self.dbManager.pool inTransaction:^(FMDatabase *db, BOOL *rollback) {

    FMResultSet *resultSet = [db executeQuery:@"SELECT * FROM message WHERE chat = ?",
                              chat.dbId];

    deleted = [self loadAll:resultSet error:nil]; //FIXME error handling

    [resultSet close];

    if ([db executeUpdate:@"DELETE FROM message WHERE chat = ?",
         chat.dbId])
    {
      count = db.changes;
    }

  }];

  if (count && deleted) {

    for (RTModel *del in deleted) {

      [del deleteWithDAO:self error:nil];

      [self.objectCache removeObjectForKey:[del dbId]];
    }

    [self deletedAll:deleted];
  }

  return count > 0;
}

-(int) countOfUnreadMessages
{
  __block int unread;

  [self.dbManager.pool inReadableDatabase:^(FMDatabase *db) {

    unread = [db intForQuery:@"SELECT COUNT(id) FROM message WHERE flags & ?", @(RTMessageFlagUnread)];

  }];

  return unread;
}

-(BOOL) isMessageDeletedWithId:(RTId *)msgId
{
  __block BOOL deleted;

  [self.dbManager.pool inReadableDatabase:^(FMDatabase *db) {

    deleted = [db boolForQuery:@"SELECT COUNT(id) > 0 FROM deleted WHERE id = ?", msgId.data];

  }];

  return deleted;
}

-(void) markMessageDeletedWithId:(RTId *)msgId
{
  [self.dbManager.pool inWritableDatabase:^(FMDatabase *db) {

    [db executeUpdate:@"INSERT INTO deleted (id) VALUES (?)", msgId.data];

  }];
}

@end


@implementation RTMessage (DAO)

+(RTMessageType) typeCode
{
  return -1;
}

+(NSString *) typeString
{
  return nil;
}

@end

@implementation RTTextMessage (DAO)

+(RTMessageType) typeCode
{
  return RTMessageTypeText;
}

+(NSString *) typeString
{
  return @"Text";
}

@end

@implementation RTImageMessage (DAO)

+(RTMessageType) typeCode
{
  return RTMessageTypeImage;
}

+(NSString *) typeString
{
  return @"Image";
}

@end

@implementation RTAudioMessage (DAO)

+(RTMessageType) typeCode
{
  return RTMessageTypeAudio;
}

+(NSString *) typeString
{
  return @"Audio";
}

@end

@implementation RTVideoMessage (DAO)

+(RTMessageType) typeCode
{
  return RTMessageTypeVideo;
}

+(NSString *) typeString
{
  return @"Video";
}

@end

@implementation RTLocationMessage (DAO)

+(RTMessageType) typeCode
{
  return RTMessageTypeLocation;
}

+(NSString *) typeString
{
  return @"LocationMessage";
}

@end

@implementation RTContactMessage (DAO)

+(RTMessageType) typeCode
{
  return RTMessageTypeContact;
}

+(NSString *) typeString
{
  return @"Contact";
}

@end

@implementation RTEnterMessage (DAO)

+(RTMessageType) typeCode
{
  return RTMessageTypeEnter;
}

+(NSString *) typeString
{
  return @"Enter";
}

@end

@implementation RTExitMessage (DAO)

+(RTMessageType) typeCode
{
  return RTMessageTypeExit;
}

+(NSString *) typeString
{
  return @"Exit";
}

@end

@implementation RTConferenceMessage (DAO)

+(RTMessageType) typeCode
{
  return RTMessageTypeConference;
}

+(NSString *) typeString
{
  return @"Conference";
}

@end
