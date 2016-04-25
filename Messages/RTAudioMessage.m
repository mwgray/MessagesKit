//
//  RTAudioMessage.m
//  ReTxt
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTAudioMessage.h"

#import "TBase+Utils.h"
#import "RTMessageDAO.h"
#import "NSObject+Utils.h"
#import "NSMutableDictionary+Utils.h"
#import "FMResultSet+Utils.h"
#import "RTLog.h"


RT_LUMBERJACK_DECLARE_LOG_LEVEL()


@interface RTAudioMessage ()

@property(nonatomic, copy) NSString *mimeType;

@end


@implementation RTAudioMessage

-(BOOL) load:(FMResultSet *)resultSet dao:(RTMessageDAO *)dao error:(NSError **)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }

  self.data = [resultSet dataReferenceForColumnIndex:dao.data1FieldIdx forOwner:self.id.description usingDB:dao.dbManager];
  self.mimeType = [resultSet stringForColumnIndex:dao.data2FieldIdx];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(RTMessageDAO *)dao error:(NSError **)error
{
  if (![super save:values dao:dao error:error]) {
    return NO;
  }

  // Internalize data references
  if (self.data && !(self.data = [self internalizeData:self.data dbManager:dao.dbManager error:error])) {
    return NO;
  }
  
  [values setNillableObject:self.data forKey:@"data1"];
  [values setNillableObject:self.mimeType forKey:@"data2"];
  
  return YES;
}

-(void) delete
{
  NSError *error;
  if (![_data deleteAndReturnError:&error]) {
    DDLogError(@"Unable to delete audio data: %@", self.data);
  }
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:[RTAudioMessage class]]) {
    return NO;
  }

  return [self isEquivalentToAudioMessage:object];
}

-(BOOL) isEquivalentToAudioMessage:(RTAudioMessage *)audioMessage
{
  return [super isEquivalentToMessage:audioMessage] &&
         isEqual(self.data, audioMessage.data);
}

-(id) copy
{
  RTAudioMessage *copy = [super copy];
  copy.data = self.data;
  copy.mimeType = self.mimeType;
  return copy;
}

-(void) setData:(id<DataReference>)data
{
  if (_data) {
    [_data deleteAndReturnError:nil];
  }
  
  _data = data;
}

-(NSString *) alertText
{
  return @"Sent you some audio";
}

-(NSString *) summaryText
{
  return @"New audio";
}

-(BOOL) exportPayloadIntoData:(id<DataReference>  _Nonnull __autoreleasing *)payloadData withMetaData:(NSDictionary *__autoreleasing  _Nonnull *)metaData error:(NSError * _Nullable __autoreleasing *)error

{
  *metaData = @{RTMetaDataKey_MimeType: self.mimeType};
  *payloadData = self.data;
  
  return YES;
}

-(BOOL) importPayloadFromData:(id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  self.mimeType = metaData[RTMetaDataKey_MimeType];
  self.data = payloadData;
  
  return YES;
}

-(enum RTMsgType) payloadType
{
  return RTMsgTypeAudio;
}

@end
