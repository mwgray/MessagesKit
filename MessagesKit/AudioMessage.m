//
//  AudioMessage.m
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "AudioMessage.h"

#import "MessageDAO.h"
#import "DataReferences.h"
#import "ExternalFileDataReference.h"
#import "NSObject+Utils.h"
#import "NSURL+Utils.h"
#import "TBase+Utils.h"
#import "Messages+Exts.h"
#import "NSMutableDictionary+Utils.h"
#import "FMResultSet+Utils.h"
#import "Log.h"


@interface AudioMessage ()

@end


@implementation AudioMessage

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat data:(id<DataReference>)data
{
  self = [super initWithId:id chat:chat];
  if (self) {
    
    self.data = data;
    
  }
  return self;
}

-(instancetype) initWithChat:(Chat *)chat data:(id<DataReference>)data
{
  return [self initWithId:[Id generate] chat:chat data:data];
}

-(id) copy
{
  AudioMessage *copy = [super copy];
  copy.data = self.data;
  return copy;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:AudioMessage.class]) {
    return NO;
  }
  
  return [self isEquivalentToAudioMessage:object];
}

-(BOOL) isEquivalentToAudioMessage:(AudioMessage *)audioMessage
{
  return
  [super isEquivalentToMessage:audioMessage] &&
  [DataReferences isDataReference:_data equivalentToDataReference:audioMessage.data];
}

-(NSString *) alertText
{
  return @"Sent you some audio";
}

-(NSString *) summaryText
{
  return @"New audio";
}

-(void) setData:(id<DataReference>)data
{
  if ([self.data isKindOfClass:ExternalFileDataReference.class]) {
    [NSFileManager.defaultManager removeItemAtURL:[(id)self.data URL] error:nil];
  }
  _data = data;
}

-(BOOL)internalizeDataReferenceWithDAO:(DAO *)dao error:(NSError **)error
{
  NSString *fileName = [NSUUID.UUID.UUIDString stringByAppendingPathExtension:[NSURL extensionForMimeType:self.data.MIMEType]];
  ExternalFileDataReference *externalFileRef = [ExternalFileDataReference.alloc initWithDBManager:dao.dbManager fileName:fileName];
  if (![self.data writeToURL:externalFileRef.URL error:error]) {
    return NO;
  }
  self.data = externalFileRef;
  return YES;
}

-(BOOL)willInsertIntoDAO:(DAO *)dao error:(NSError **)error
{
  return [self internalizeDataReferenceWithDAO:dao error:error];
}

-(BOOL)willUpdateInDAO:(DAO *)dao error:(NSError **)error
{
  return [self internalizeDataReferenceWithDAO:dao error:error];
}

-(BOOL)didDeleteFromDAO:(DAO *)dao error:(NSError **)error
{
  if ([self.data isKindOfClass:ExternalFileDataReference.class]) {
    ExternalFileDataReference *externalFileRef = self.data;
    return [NSFileManager.defaultManager removeItemAtURL:externalFileRef.URL error:error];
  }
  return YES;
}

-(BOOL) load:(FMResultSet *)resultSet dao:(MessageDAO *)dao error:(NSError **)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }
  
  self.data = [resultSet dataReferenceForColumnIndex:dao.data1FieldIdx usingDBManager:dao.dbManager];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(MessageDAO *)dao error:(NSError **)error
{
  if (![super save:values dao:dao error:error]) {
    return NO;
  }
  
  [values setNillableObject:[NSKeyedArchiver archivedDataWithRootObject:self.data] forKey:@"data1"];
  
  return YES;
}

-(enum MsgType) payloadType
{
  return MsgTypeAudio;
}

-(BOOL) exportPayloadIntoData:(id<DataReference> *)payloadData withMetaData:(NSDictionary **)metaData error:(NSError **)error
{
  *metaData = @{MetaDataKey_MimeType: self.data.MIMEType};
  *payloadData = self.data;
  
  return YES;
}

-(BOOL) importPayloadFromData:(id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError **)error
{
  NSString *MIMEType = metaData[MetaDataKey_MimeType];
  
  id<DataReference> data = [payloadData temporaryDuplicateFilteredBy:nil withMIMEType:MIMEType error:error];
  if (!data) {
    return NO;
  }
  
  self.data = data;
  
  return YES;
}

@end
