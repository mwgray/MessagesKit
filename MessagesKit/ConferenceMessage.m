//
//  ConferenceMessage.m
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "ConferenceMessage.h"

#import "MessageDAO.h"
#import "MemoryDataReference.h"
#import "DataReferences.h"
#import "Messages+Exts.h"
#import "NSObject+Utils.h"
#import "NSMutableDictionary+Utils.h"
#import "TBase+Utils.h"


@interface ConferenceMessage ()

@end


@implementation ConferenceMessage

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat callingDeviceId:(Id *)callingDeviceId message:(NSString *)message
{
  self = [super initWithId:id chat:chat];
  if (self) {
    
    self.callingDeviceId = callingDeviceId;
    self.message = message;
    
  }
  return self;
}

-(instancetype) initWithChat:(Chat *)chat callingDeviceId:(Id *)callingDeviceId message:(NSString *)message
{
  return [self initWithId:[Id generate] chat:chat callingDeviceId:callingDeviceId message:message];
}

-(id) copy
{
  ConferenceMessage *copy = [super copy];
  copy.callingDeviceId = self.callingDeviceId;
  copy.conferenceStatus = self.conferenceStatus;
  copy.message = self.message;
  copy.localAction = self.localAction;
  return copy;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:ConferenceMessage.class]) {
    return NO;
  }

  return [self isEquivalentToConferenceMessage:object];
}

-(BOOL) isEquivalentToConferenceMessage:(ConferenceMessage *)conferenceMessage
{
  return
  [super isEquivalentToMessage:conferenceMessage] &&
  (self.conferenceStatus == conferenceMessage.conferenceStatus) &&
  isEqual(self.message, conferenceMessage.message) &&
  (self.localAction == conferenceMessage.localAction);
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
    case ConferenceStatusWaiting:
      text = @"Let's talk!";
      break;
      
    case ConferenceStatusInProgress:
      text = @"We're talking...";
      break;
      
    case ConferenceStatusCompleted:
      text = @"Thanks for the chat";
      break;
      
    case ConferenceStatusMissed:
      text = @"You missed my call, call me when you can.";
      break;
  }
  
  return text;
}

-(NSString *) summaryText
{
  return [self alertText];
}

-(MessageSoundAlert) soundAlert
{
  switch (_conferenceStatus) {
    case ConferenceStatusCompleted:
    case ConferenceStatusInProgress:
    case ConferenceStatusMissed:
      return MessageSoundAlertNone;
      
    default:
      return [super soundAlert];
  }
}

-(BOOL) load:(FMResultSet *)resultSet dao:(MessageDAO *)dao error:(NSError **)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }
  
  self.callingDeviceId = [Id idWithData:[resultSet dataForColumnIndex:dao.data1FieldIdx]];
  self.conferenceStatus =  [resultSet intForColumnIndex:dao.data2FieldIdx];
  self.message = [resultSet stringForColumnIndex:dao.data3FieldIdx];
  self.localAction = [resultSet intForColumnIndex:dao.data4FieldIdx];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(DAO *)dao error:(NSError **)error
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

-(enum MsgType) payloadType
{
  return MsgTypeConference;
}

-(BOOL) exportPayloadIntoData:(id<DataReference> *)payloadData withMetaData:(NSDictionary **)metaData error:(NSError **)error
{
  Conference *conference = [[Conference alloc] initWithCallingDeviceId:_callingDeviceId
                                                                    status:_conferenceStatus
                                                                   message:_message];
  
  NSData *data = [TBaseUtils serializeToData:conference error:error];
  if (!data) {
    return NO;
  }

  *metaData = nil;
  *payloadData = [MemoryDataReference.alloc initWithData:data ofMIMEType:@"application/x-thrift"];
  
  return YES;
}

-(BOOL) importPayloadFromData:(id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError **)error
{
  NSData *data = [DataReferences readAllDataFromReference:payloadData error:error];
  if (!data) {
    return NO;
  }
  
  Conference *conference = [TBaseUtils deserialize:[Conference new]
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

@end
