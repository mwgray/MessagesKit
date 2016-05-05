//
//  RTNotification.m
//  ReTxt
//
//  Created by Kevin Wooten on 2/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTNotification.h"

#import "RTNotificationDAO.h"
#import "RTMessages+Exts.h"
#import "NSObject+Utils.h"
#import "NSMutableDictionary+Utils.h"
#import "FMResultSet+Utils.h"


@implementation RTNotification

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
  self.msgId = [RTId idWithData:dbId];
}

-(BOOL) load:(FMResultSet *)resultSet dao:(RTNotificationDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }

  self.chatId = [resultSet idForColumnIndex:dao.chatIdFieldIdx];
  self.data = [resultSet dataForColumnIndex:dao.dataFieldIdx];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(RTDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super save:values dao:dao error:error]) {
    return NO;
  }
  
  [values setNillableObject:self.chatId forKey:@"chatId"];
  [values setNillableObject:self.data forKey:@"data"];
  
  return YES;
}

-(BOOL) isEquivalent:(RTNotification *)notification
{
  return isEqual(self.msgId, notification.msgId) &&
         isEqual(self.chatId, notification.chatId) &&
         isEqual(self.data, notification.data);
}

@end
