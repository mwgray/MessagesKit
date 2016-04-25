//
//  RTMessage.m
//  ReTxt
//
//  Created by Kevin Wooten on 1/27/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessage.h"

#import "RTChat.h"
#import "RTChatDAO.h"
#import "RTMessageDAO.h"
#import "MemoryDataReference.h"
#import "FileDataReference.h"
#import "BlobDataReference.h"
#import "RTMessages+Exts.h"
#import "NSObject+Utils.h"
#import "NSDate+Utils.h"
#import "NSMutableDictionary+Utils.h"
#import "FMResultSet+Utils.h"


@implementation RTMessage

@synthesize id=_id;

-(instancetype) initWithChat:(RTChat *)chat
{
  return [self initWithId:[RTId generate] chat:chat];
}

-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat
{
  self = [super init];
  if (self) {
    self.id = id;
    self.chat = chat;
  }
  return self;
}

-(id) dbId
{
  return self.id.data;
}

-(void) setDbId:(id)dbId
{
  self.id = [RTId idWithData:dbId];
}

-(BOOL) load:(FMResultSet *)resultSet dao:(RTMessageDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }

  RTChatDAO *chatDAO = dao.dbManager[@"Chat"];

  RTChat *chat = nil;
  if (![chatDAO fetchChatWithId:[resultSet idForColumnIndex:dao.chatFieldIdx]
                      returning:&chat
                          error:error]) {
    return NO;
  }
  self.chat = chat;
  
  self.sender = [resultSet stringForColumnIndex:dao.senderFieldIdx];
  self.sent = [resultSet dateForColumnIndex:dao.sentFieldIdx];
  self.updated = [resultSet dateForColumnIndex:dao.updatedFieldIdx];
  self.status = [resultSet intForColumnIndex:dao.statusFieldIdx];
  self.statusTimestamp = [resultSet dateForColumnIndex:dao.statusTimestampFieldIdx];
  self.flags = [resultSet intForColumnIndex:dao.flagsFieldIdx];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(RTDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super save:values dao:dao error:error]) {
    return NO;
  }

  [values setNillableObject:self.chat.dbId forKey:@"chat"];
  [values setNillableObject:self.sender forKey:@"sender"];
  [values setNillableObject:self.sent forKey:@"sent"];
  [values setNillableObject:self.updated forKey:@"updated"];
  [values setNillableObject:@(self.status) forKey:@"status"];
  [values setNillableObject:self.statusTimestamp forKey:@"statusTimestamp"];
  [values setNillableObject:@(self.flags) forKey:@"flags"];
  
  return YES;
}

-(BOOL) isEquivalent:(id)object
{
  return [self isEquivalentToMessage:object];
}

-(BOOL) isEquivalentToMessage:(RTMessage *)message
{
  return isEqual(self.id, message.id) &&
         isEqual(self.chat, message.chat) &&
         isEqual(self.sender, message.sender) &&
         isEqualDate(self.sent, message.sent) &&
         (self.status == message.status) &&
         isEqualDate(self.statusTimestamp, message.statusTimestamp) &&
         (self.flags == message.flags);
}

-(id) copy
{
  RTMessage *copy = [[self class] new];
  copy.id = self.id;
  copy.chat = self.chat;
  copy.sender = self.sender;
  copy.sent = self.sent;
  copy.status = self.status;
  copy.statusTimestamp = self.statusTimestamp;
  copy.flags = self.flags;
  return copy;
}

-(BOOL) sentByMe
{
  return [_sender isEqualToString:_chat.localAlias];
}

-(RTMessageSoundAlert) soundAlert
{
  return (_flags & RTMessageFlagSilent) ? RTMessageSoundAlertNone : RTMessageSoundAlertStandard;
}

-(BOOL) clarifyFlag
{
  return _flags & RTMessageFlagClarify;
}

-(void) setClarifyFlag:(BOOL)clarifyFlag
{
  if (clarifyFlag) {
    _flags |= RTMessageFlagClarify;
  }
  else {
    _flags &= ~RTMessageFlagClarify;
  }
}

-(BOOL) unreadFlag
{
  return _flags & RTMessageFlagUnread;
}

-(void) setUnreadFlag:(BOOL)unreadFlag
{
  if (unreadFlag) {
    _flags |= RTMessageFlagUnread;
  }
  else {
    _flags &= ~RTMessageFlagUnread;
  }
}

-(BOOL) newlyClarified
{
  return self.unreadFlag && self.clarifyFlag;
}

-(BOOL) newlyUpdated
{
  return self.unreadFlag && self.updated;
}

-(NSString *) alertText
{
  return @"Sent you a message";
}

-(NSString *) summaryText
{
  return @"New message";
}

-(RTMsgType) payloadType
{
  return -1;
}

-(BOOL)exportPayloadIntoData:(id<DataReference>  _Nonnull __autoreleasing *)payloadData withMetaData:(NSDictionary *__autoreleasing  _Nonnull *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  return NO;
}

-(BOOL)importPayloadFromData:(id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  return NO;
}

-(NSString *) statusString
{
  switch (self.status) {
  case RTMessageStatusDelivered:
    return @"Delivered";
    break;

  case RTMessageStatusFailed:
    return @"Failed";
    break;

  case RTMessageStatusSending:
    return @"Sending";
    break;

  case RTMessageStatusSent:
    return @"Sent";
    break;

  case RTMessageStatusUnsent:
    return @"Unsent";
    break;

  case RTMessageStatusViewed:
    return @"Viewed";
    break;

  default:
    break;
  }
}

+(NSNumber *)shouldConvertDataToBlob:(id<DataReference>)data error:(NSError **)error
{
  NSObject<DataReference> *anyData = (id)data;
  
  if ([anyData isKindOfClass:MemoryDataReference.class]) {
    // Memory - Convert if larger than 64kb
    NSNumber *size = [anyData dataSizeAndReturnError:error];
    if (!size) {
      return nil;
    }
    return [NSNumber numberWithBool:size.unsignedLongLongValue > 1024];
  }
  else if ([anyData isKindOfClass:FileDataReference.class]) {
    // Files - Convert all of them
    return [NSNumber numberWithBool:YES];
  }
  
  return [NSNumber numberWithBool:NO];
}

-(id<DataReference>)internalizeData:(id<DataReference>)data dbManager:(RTDBManager *)dbManager error:(NSError **)error
{
  // Check and convert data if necessary
  NSNumber *shouldConvert = [RTMessage shouldConvertDataToBlob:data error:error];
  if (!shouldConvert) {
    return nil;
  }
  
  if (!shouldConvert.boolValue) {
    return data;
  }
  
  return [BlobDataReference copyFrom:data
                             toOwner:self.id.description
                            forTable:@"blob"
                          inDatabase:@"main"
                               using:dbManager
                          filteredBy:nil
                               error:error];
}

@end
