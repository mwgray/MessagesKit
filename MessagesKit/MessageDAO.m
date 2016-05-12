//
//  MessageDAO.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "MessageDAO.h"

#import "DAO+Internal.h"
#import "NSObject+Utils.h"

#import "Chat.h"
#import "TextMessage.h"
#import "ImageMessage.h"
#import "AudioMessage.h"
#import "VideoMessage.h"
#import "ContactMessage.h"
#import "LocationMessage.h"
#import "EnterMessage.h"
#import "ExitMessage.h"
#import "ConferenceMessage.h"

@import ObjectiveC;


@implementation MessageDAO

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

-(instancetype) initWithDBManager:(DBManager *)dbManager
{
  __block DBTableInfo *tableInfo;
  [dbManager.pool inReadableDatabase:^(FMDatabase *db) {
    tableInfo = [DBTableInfo loadTableInfo:db tableName:@"message"];
  }];
  
  self = [super initWithDBManager:dbManager
                        tableInfo:tableInfo
                        rootClass:Message.class
                   derivedClasses:@[TextMessage.class, ImageMessage.class, AudioMessage.class,
                                    VideoMessage.class, LocationMessage.class, ContactMessage.class,
                                    EnterMessage.class, ExitMessage.class, ConferenceMessage.class]];
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

    NSMutableArray *params = [@[@(MessageStatusFailed), @(MessageStatusSending)] mutableCopy];
    NSMutableArray *paramSpecs = [NSMutableArray new];

    for (Id *excludedMessageId in excludedMessageIds) {
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
                              @(MessageStatusSending)];

    res = [self loadAll:resultSet error:error];

    [resultSet close];
  }];

  return res;
}

-(BOOL) fetchLatestUnviewedMessage:(Message **)returnedMessage forChat:(Chat *)chat error:(NSError **)error
{
  __block BOOL valid = NO;

  [self.dbManager.pool inReadableDatabase:^(FMDatabase *db) {

    FMResultSet *resultSet = [db executeQuery:@"SELECT * FROM message WHERE chat = ? AND sender <> ? AND status < ? ORDER BY sent DESC LIMIT 1",
                              chat.dbId, chat.localAlias, @(MessageStatusViewed)];

    BOOL hasResult = NO;
    if (![resultSet nextReturning:&hasResult error:error]) {
      return;
    }

    if (!hasResult) {
      valid = YES;
      return;
    }
    
    Message *result = [self load:resultSet error:error];
    if (result) {
      *returnedMessage = result;
      valid = YES;
    }
    
    [resultSet close];
  }];
  
  return valid;
}

-(BOOL) fetchLastMessage:(Message **)returnedMessage forChat:(Chat *)chat error:(NSError **)error
{
  __block BOOL valid = NO;

  [self.dbManager.pool inReadableDatabase:^(FMDatabase *db) {

    FMResultSet *resultSet = [db executeQuery:@"SELECT * FROM message WHERE chat = ? ORDER BY sent DESC LIMIT 1",
                              chat.dbId];

    BOOL hasResult = NO;
    if (![resultSet nextReturning:&hasResult error:error]) {
      return;
    }

    if (!hasResult) {
      valid = YES;
      return;
    }
    
    Message *result = [self load:resultSet error:error];
    if (!result) {
      *returnedMessage = result;
      valid = YES;
    }

    [resultSet close];
  }];

  return valid;
}


-(BOOL) viewAllMessagesForChat:(Chat *)chat before:(NSDate *)sent error:(NSError **)error
{
  __block BOOL valid = NO;
  __block NSArray *updated;
  __block int count =0;

  [self.dbManager.pool inTransaction:^(FMDatabase *db, BOOL *rollback) {

    FMResultSet *resultSet = [db executeQuery:@"SELECT * FROM message WHERE chat = ? AND sender <> ? AND status < ? AND sent <= ?"
                                  valuesArray:@[chat.dbId, chat.localAlias, @(MessageStatusViewed), sent]
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
                  valuesArray:@[@(MessageStatusViewed), now, chat.dbId, chat.localAlias, @(MessageStatusViewed), sent]
                        error:error];
    if (!valid) {
      *rollback = YES;
      return;
    }
    
    count = db.changes;

    for (Message *up in updated) {
      up.status = MessageStatusViewed;
      up.statusTimestamp = now;
    }
    
  }];
  
  if (count && updated) {
    [self updatedAll:updated];
  }

  return valid;
}

-(BOOL) readAllMessagesForChat:(Chat *)chat error:(NSError **)error
{
  __block BOOL valid = NO;
  __block NSArray *updated;
  __block int count =0;

  [self.dbManager.pool inTransaction:^(FMDatabase *db, BOOL *rollback) {

    FMResultSet *resultSet = [db executeQuery:@"SELECT * FROM message WHERE chat = ? AND flags & ?"
                                  valuesArray:@[chat.dbId, @(MessageFlagUnread)]
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
                  valuesArray:@[@(~MessageFlagUnread), chat.dbId, @(MessageFlagUnread)]
                        error:error];
    if (!valid) {
      *rollback = YES;
      return;
    }
    
    count = db.changes;
    
    for (Message *msg in updated) {
      msg.unreadFlag = NO;
    }
    
  }];

  if (count && updated) {
    [self updatedAll:updated];
  }

  return valid;
}

-(BOOL) updateMessage:(Message *)message withStatus:(MessageStatus)status error:(NSError **)error
{
  return [self updateMessage:message withStatus:status timestamp:[NSDate date] error:error];
}

-(BOOL) updateMessage:(Message *)message withStatus:(MessageStatus)status timestamp:(NSDate *)timestamp error:(NSError **)error
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

-(BOOL) updateMessage:(Message *)message withSent:(NSDate *)sent error:(NSError **)error
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

-(BOOL) updateMessage:(Message *)message withFlags:(int64_t)flags error:(NSError **)error
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

-(BOOL) deleteAllMessagesForChat:(Chat *)chat error:(NSError **)error
{
  __block BOOL valid = NO;
  __block NSArray *deleted;
  __block int count = 0;

  [self.dbManager.pool inTransaction:^(FMDatabase *db, BOOL *rollback) {

    FMResultSet *resultSet = [db executeQuery:@"SELECT * FROM message WHERE chat = ?",
                              chat.dbId];

    deleted = [self loadAll:resultSet error:error];
    if (!deleted) {
      return;
    }

    [resultSet close];

    if (![db executeUpdate:@"DELETE FROM message WHERE chat = ?" valuesArray:@[chat.dbId] error:error]) {
      return;
    }
    
    valid = YES;
    count = db.changes;

  }];

  if (count && deleted) {

    for (Model *del in deleted) {

      [del deleteWithDAO:self error:nil];

      [self.objectCache removeObjectForKey:[del dbId]];
    }

    [self deletedAll:deleted];
  }

  return valid;
}

-(int) countOfUnreadMessages
{
  __block int unread;

  [self.dbManager.pool inReadableDatabase:^(FMDatabase *db) {

    unread = [db intForQuery:@"SELECT COUNT(id) FROM message WHERE flags & ?", @(MessageFlagUnread)];

  }];

  return unread;
}

-(BOOL) isMessageDeletedWithId:(Id *)msgId
{
  __block BOOL deleted;

  [self.dbManager.pool inReadableDatabase:^(FMDatabase *db) {

    deleted = [db boolForQuery:@"SELECT COUNT(id) > 0 FROM deleted WHERE id = ?", msgId.data];

  }];

  return deleted;
}

-(void) markMessageDeletedWithId:(Id *)msgId
{
  [self.dbManager.pool inWritableDatabase:^(FMDatabase *db) {

    [db executeUpdate:@"INSERT INTO deleted (id) VALUES (?)", msgId.data];

  }];
}

@end


@implementation Message (DAO)

+(MessageType) typeCode
{
  return -1;
}

+(NSString *) typeString
{
  return nil;
}

@end

@implementation TextMessage (DAO)

+(MessageType) typeCode
{
  return MessageTypeText;
}

+(NSString *) typeString
{
  return @"Text";
}

@end

@implementation ImageMessage (DAO)

+(MessageType) typeCode
{
  return MessageTypeImage;
}

+(NSString *) typeString
{
  return @"Image";
}

@end

@implementation AudioMessage (DAO)

+(MessageType) typeCode
{
  return MessageTypeAudio;
}

+(NSString *) typeString
{
  return @"Audio";
}

@end

@implementation VideoMessage (DAO)

+(MessageType) typeCode
{
  return MessageTypeVideo;
}

+(NSString *) typeString
{
  return @"Video";
}

@end

@implementation LocationMessage (DAO)

+(MessageType) typeCode
{
  return MessageTypeLocation;
}

+(NSString *) typeString
{
  return @"LocationMessage";
}

@end

@implementation ContactMessage (DAO)

+(MessageType) typeCode
{
  return MessageTypeContact;
}

+(NSString *) typeString
{
  return @"Contact";
}

@end

@implementation EnterMessage (DAO)

+(MessageType) typeCode
{
  return MessageTypeEnter;
}

+(NSString *) typeString
{
  return @"Enter";
}

@end

@implementation ExitMessage (DAO)

+(MessageType) typeCode
{
  return MessageTypeExit;
}

+(NSString *) typeString
{
  return @"Exit";
}

@end

@implementation ConferenceMessage (DAO)

+(MessageType) typeCode
{
  return MessageTypeConference;
}

+(NSString *) typeString
{
  return @"Conference";
}

@end
