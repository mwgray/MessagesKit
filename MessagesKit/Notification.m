//
//  Notification.m
//  MessagesKit
//
//  Created by Kevin Wooten on 2/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Notification.h"

#import "NotificationDAO.h"
#import "Messages+Exts.h"
#import "NSObject+Utils.h"
#import "NSMutableDictionary+Utils.h"
#import "FMResultSet+Utils.h"


@implementation Notification

-(id) id
{
  return self.msgId;
}

-(id) dbId
{
  return self.msgId.data;
}

-(void) setDbId:(id)dbId
{
  self.msgId = [Id idWithData:dbId];
}

-(BOOL) load:(FMResultSet *)resultSet dao:(NotificationDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }

  self.chatId = [resultSet idForColumnIndex:dao.chatIdFieldIdx];
  self.data = [resultSet dataForColumnIndex:dao.dataFieldIdx];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(DAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super save:values dao:dao error:error]) {
    return NO;
  }
  
  [values setNillableObject:self.chatId forKey:@"chatId"];
  [values setNillableObject:self.data forKey:@"data"];
  
  return YES;
}

-(BOOL) isEquivalent:(Notification *)notification
{
  return isEqual(self.msgId, notification.msgId) &&
         isEqual(self.chatId, notification.chatId) &&
         isEqual(self.data, notification.data);
}

@end
