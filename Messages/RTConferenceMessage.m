//
//  RTConferenceMessage.m
//  ReTxt
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTConferenceMessage.h"

#import "Messages-Swift.h"
#import "RTMessageDAO.h"
#import "RTMessages+Exts.h"
#import "NSObject+Utils.h"
#import "NSMutableDictionary+Utils.h"
#import "TBase+Utils.h"


@interface RTConferenceMessage () {
}

@end


@implementation RTConferenceMessage

-(BOOL) load:(FMResultSet *)resultSet dao:(RTMessageDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }

  self.callingDeviceId = [RTId idWithData:[resultSet dataForColumnIndex:dao.data1FieldIdx]];
  self.conferenceStatus =  [resultSet intForColumnIndex:dao.data2FieldIdx];
  self.message = [resultSet stringForColumnIndex:dao.data3FieldIdx];
  self.localAction = [resultSet intForColumnIndex:dao.data4FieldIdx];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(RTDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super save:values dao:dao error:error]) {
    return NO;
  }

  [values setNillableObject:_callingDeviceId forKey:@"data1"];
  [values setNillableObject:@(_conferenceStatus) forKey:@"data2"];
  [values setNillableObject:_message forKey:@"data3"];
  [values setNillableObject:@(_localAction) forKey:@"data4"];
  
  return YES;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:RTConferenceMessage.class]) {
    return NO;
  }

  return [self isEquivalentToConferenceMessage:object];
}

-(BOOL) isEquivalentToConferenceMessage:(RTConferenceMessage *)conferenceMessage
{
  return [super isEquivalentToMessage:conferenceMessage] &&
         (self.conferenceStatus == conferenceMessage.conferenceStatus) &&
         isEqual(self.message, conferenceMessage.message) &&
         (self.localAction == conferenceMessage.localAction);
}

-(id) copy
{
  RTConferenceMessage *copy = [super copy];
  copy.callingDeviceId = _callingDeviceId;
  copy.conferenceStatus = _conferenceStatus;
  copy.message = _message;
  copy.localAction = _localAction;
  return copy;
}

-(void) setUpdated:(NSDate *)updated
{
  // never mark conferences as updated
  [super setUpdated:nil];
}

-(NSString *) alertText
{
  NSString *text;

  switch (_conferenceStatus) {
  case RTConferenceStatusWaiting:
    text = @"Let's talk!";
    break;

  case RTConferenceStatusInProgress:
    text = @"We're talking...";
    break;

  case RTConferenceStatusCompleted:
    text = @"Thanks for the chat";
    break;

  case RTConferenceStatusMissed:
    text = @"You missed my call, call me when you can.";
    break;
  }

  return text;
}

-(NSString *) summaryText
{
  return [self alertText];
}

-(RTMessageSoundAlert) soundAlert
{
  switch (_conferenceStatus) {
  case RTConferenceStatusCompleted:
  case RTConferenceStatusInProgress:
  case RTConferenceStatusMissed:
    return RTMessageSoundAlertNone;

  default:
    return [super soundAlert];
  }
}

-(BOOL) exportPayloadIntoData:(id<DataReference>  _Nonnull __autoreleasing *)payloadData withMetaData:(NSDictionary *__autoreleasing  _Nonnull *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  RTConference *conference = [[RTConference alloc] initWithCallingDeviceId:_callingDeviceId
                                                                    status:_conferenceStatus
                                                                   message:_message];
  
  NSData *data = [TBaseUtils serializeToData:conference error:error];
  if (!data) {
    return NO;
  }

  *metaData = nil;
  *payloadData = [[MemoryDataReference alloc] initWithData:data];
  
  return YES;
}

-(BOOL) importPayloadFromData:(id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  NSData *data = [DataReferences readAllDataFromReference:payloadData error:error];
  if (!data) {
    return NO;
  }
  
  RTConference *conference = [TBaseUtils deserialize:[RTConference new]
                                            fromData:data
                                               error:error];
  if (!conference) {
    return NO;
  }

  _callingDeviceId = conference.callingDeviceId;
  _conferenceStatus = conference.status;
  _message = conference.message;
  
  return YES;
}

-(enum RTMsgType) payloadType
{
  return RTMsgTypeConference;
}

@end
