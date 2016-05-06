//
//  RTNotificationDAO.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/8/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTNotificationDAO.h"

#import "RTDAO+Internal.h"
#import "NSObject+Utils.h"

@import ObjectiveC;


@implementation RTNotificationDAO

+(void) initialize
{
  class_duplicateMethod(self, @selector(fetchNotificationWithId:), @selector(fetchObjectWithId:));
  class_duplicateMethod(self, @selector(fetchNotificationWithId:returning:error:), @selector(fetchObjectWithId:returning:error:));
  class_duplicateMethod(self, @selector(fetchAllNotificationsMatching:error:), @selector(fetchAllObjectsMatching:error:));
  class_duplicateMethod(self, @selector(fetchAllNotificationsMatching:parameters:error:), @selector(fetchAllObjectsMatching:parameters:error:));
  class_duplicateMethod(self, @selector(fetchAllNotificationsMatching:parametersNamed:error:), @selector(fetchAllObjectsMatching:parametersNamed:error:));
  class_duplicateMethod(self, @selector(fetchAllNotificationsMatching:offset:limit:sortedBy:error:), @selector(fetchAllObjectsMatching:offset:limit:sortedBy:error:));
  class_duplicateMethod(self, @selector(insertNotification:error:), @selector(insertObject:error:));
  class_duplicateMethod(self, @selector(updateNotification:error:), @selector(updateObject:error:));
  class_duplicateMethod(self, @selector(upsertNotification:error:), @selector(upsertObject:error:));
  class_duplicateMethod(self, @selector(deleteNotification:error:), @selector(deleteObject:error:));
  class_duplicateMethod(self, @selector(deleteAllNotificationsInArray:error:), @selector(deleteAllObjectsInArray:error:));
  class_duplicateMethod(self, @selector(deleteAllNotificationsAndReturnError:), @selector(deleteAllObjectsAndReturnError:));
  class_duplicateMethod(self, @selector(deleteAllNotificationsMatching:error:), @selector(deleteAllObjectsMatching:error:));
  class_duplicateMethod(self, @selector(deleteAllNotificationsMatching:parameters:error:), @selector(deleteAllObjectsMatching:parameters:error:));
  class_duplicateMethod(self, @selector(deleteAllNotificationsMatching:parametersNamed:error:), @selector(deleteAllObjectsMatching:parametersNamed:error:));
}

-(instancetype) initWithDBManager:(RTDBManager *)dbManager
{
  __block RTDBTableInfo *tableInfo;
  [dbManager.pool inReadableDatabase:^(FMDatabase *db) {
    tableInfo = [RTDBTableInfo loadTableInfo:db tableName:@"notification"];
  }];
  
  self = [super initWithDBManager:dbManager
                        tableInfo:tableInfo
                        rootClass:[RTNotification class]
                   derivedClasses:@[]];
  if (self) {

    _chatIdFieldIdx = [tableInfo findField:@"chatId"];
    _dataFieldIdx = [tableInfo findField:@"data"];

  }

  return self;
}

-(NSString *) name
{
  return @"Notification";
}

-(id) dbIdForId:(id)id
{
  return [id data];
}

-(NSArray *) fetchAllNotificationsForChat:(RTChat *)chat error:(NSError **)error
{
  __block NSArray *res;

  [self.dbManager.pool inReadableDatabase:^(FMDatabase *db) {

    FMResultSet *resultSet = [db executeQuery:@"SELECT * FROM notification WHERE chatId = ?",
                              chat.dbId];

    res = [self loadAll:resultSet error:error];

    [resultSet close];
  }];

  return res;
}

@end
