//
//  RTAudioMessage.m
//  ReTxt
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTAudioMessage.h"

#import "TBase+Utils.h"
#import "DataReferences.h"
#import "RTMessageDAO.h"
#import "NSObject+Utils.h"
#import "NSMutableDictionary+Utils.h"
#import "FMResultSet+Utils.h"
#import "RTLog.h"


@interface RTAudioMessage ()

@end


@implementation RTAudioMessage

-(id) copy
{
  RTAudioMessage *copy = [super copy];
  copy.data = self.data;
  copy.dataMimeType = self.dataMimeType;
  return copy;
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
    [DataReferences isDataReference:_data equivalentToDataReference:audioMessage.data];
}

-(void) setData:(id<DataReference>)data
{
  if (_data == data) {
    return;
  }
  
  if (_data) {
    [_data deleteAndReturnError:nil];
  }
  
  _data = [data temporaryDuplicateFilteredBy:nil error:nil];
}

-(void) setOwnedData:(id<DataReference>)ownedData
{
  if (_data == ownedData) {
    return;
  }
  
  if (_data) {
    [_data deleteAndReturnError:nil];
  }
  
  _data = ownedData;
}

-(BOOL) load:(FMResultSet *)resultSet dao:(RTMessageDAO *)dao error:(NSError **)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }
  
  self.data = [resultSet dataReferenceForColumnIndex:dao.data1FieldIdx forOwner:self.id.description usingDB:dao.dbManager];
  self.dataMimeType = [resultSet stringForColumnIndex:dao.data2FieldIdx];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(RTMessageDAO *)dao error:(NSError **)error
{
  if (![super save:values dao:dao error:error]) {
    return NO;
  }
  
  // Internalize data references
  if (_data && !(self.ownedData = [self internalizeData:_data dbManager:dao.dbManager error:error])) {
    return NO;
  }
  
  [values setNillableObject:self.data forKey:@"data1"];
  [values setNillableObject:self.dataMimeType forKey:@"data2"];
  
  return YES;
}

-(BOOL) deleteWithDAO:(RTDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (_data && ![_data deleteAndReturnError:error]) {
    return NO;
  }
  
  return YES;
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
  *metaData = @{RTMetaDataKey_MimeType: self.dataMimeType ?: @""};
  *payloadData = self.data;
  
  return YES;
}

-(BOOL) importPayloadFromData:(id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  self.dataMimeType = metaData[RTMetaDataKey_MimeType];
  self.data = payloadData;
  
  return YES;
}

-(enum RTMsgType) payloadType
{
  return RTMsgTypeAudio;
}

@end
