//
//  AudioMessage.m
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "AudioMessage.h"

#import "DataReferences.h"
#import "MessageDAO.h"
#import "NSObject+Utils.h"
#import "TBase+Utils.h"
#import "Messages+Exts.h"
#import "NSMutableDictionary+Utils.h"
#import "FMResultSet+Utils.h"
#import "Log.h"


@interface AudioMessage ()

@end


@implementation AudioMessage

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat data:(id<DataReference>)data mimeType:(NSString *)mimeType
{
  self = [super initWithId:id chat:chat];
  if (self) {
    
    self.data = data;
    self.dataMimeType = mimeType;
    
  }
  return self;
}

-(instancetype) initWithChat:(Chat *)chat data:(id<DataReference>)data mimeType:(NSString *)mimeType
{
  return [self initWithId:[Id generate] chat:chat data:data mimeType:mimeType];
}

-(id) copy
{
  AudioMessage *copy = [super copy];
  copy.data = self.data;
  copy.dataMimeType = self.dataMimeType;
  return copy;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:[AudioMessage class]]) {
    return NO;
  }
  
  return [self isEquivalentToAudioMessage:object];
}

-(BOOL) isEquivalentToAudioMessage:(AudioMessage *)audioMessage
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

-(BOOL) load:(FMResultSet *)resultSet dao:(MessageDAO *)dao error:(NSError **)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }
  
  self.data = [resultSet dataReferenceForColumnIndex:dao.data1FieldIdx forOwner:self.id.description usingDB:dao.dbManager];
  self.dataMimeType = [resultSet stringForColumnIndex:dao.data2FieldIdx];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(MessageDAO *)dao error:(NSError **)error
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

-(BOOL) deleteWithDAO:(DAO *)dao error:(NSError *__autoreleasing *)error
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
  *metaData = @{MetaDataKey_MimeType: self.dataMimeType ?: @""};
  *payloadData = self.data;
  
  return YES;
}

-(BOOL) importPayloadFromData:(id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  self.dataMimeType = metaData[MetaDataKey_MimeType];
  self.data = payloadData;
  
  return YES;
}

-(enum MsgType) payloadType
{
  return MsgTypeAudio;
}

@end
