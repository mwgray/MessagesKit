//
//  TextMessage.m
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "TextMessage.h"

#import "MessageDAO.h"
#import "MemoryDataReference.h"
#import "DataReferences.h"
#import "HTMLText.h"
#import "Messages+Exts.h"
#import "NSObject+Utils.h"
#import "NSString+Utils.h"
#import "NSMutableDictionary+Utils.h"


@interface TextMessage ()

@property (assign, nonatomic) TextMessageType type;
@property (strong, nonatomic) id data;

@property (strong, nonatomic) NSString *cachedText;

@end


@implementation TextMessage

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat data:(id)data type:(TextMessageType)type
{
  self = [super initWithId:id chat:chat];
  if (self) {
    
    _data = data;
    _type = type;
    
  }
  return self;
}

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat text:(NSString *)text
{
  return [self initWithId:id chat:chat data:text type:TextMessageType_Simple];
}

-(instancetype) initWithChat:(Chat *)chat text:(NSString *)text
{
  return [self initWithId:[Id generate] chat:chat text:text];
}

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat html:(NSString *)html
{
  MemoryDataReference *data = [MemoryDataReference.alloc initWithData:[html dataUsingEncoding:NSUTF8StringEncoding]];
  return [self initWithId:id chat:chat data:data type:TextMessageType_Html];
}

-(instancetype) initWithChat:(Chat *)chat html:(NSString *)html
{
  return [self initWithId:[Id generate] chat:chat html:html];
}

-(BOOL) load:(FMResultSet *)resultSet dao:(MessageDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }

  self.type = [resultSet intForColumnIndex:dao.data2FieldIdx];

  switch (self.type) {
  case TextMessageType_Simple:
    self.data = [resultSet stringForColumnIndex:dao.data1FieldIdx];
    break;

  case TextMessageType_Html:
    self.data = [resultSet dataForColumnIndex:dao.data1FieldIdx];
    break;
  }
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(DAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super save:values dao:dao error:error]) {
    return NO;
  }

  [values setNillableObject:self.data forKey:@"data1"];
  [values setObject:@(self.type) forKey:@"data2"];
  
  return YES;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:[TextMessage class]]) {
    return NO;
  }

  return [self isEquivalentToTextMessage:object];
}

-(BOOL) isEquivalentToTextMessage:(TextMessage *)textMessage
{
  return [super isEquivalentToMessage:textMessage] &&
         isEqual(self.data, textMessage.data) &&
         self.type == textMessage.type;
}

-(id) copy
{
  TextMessage *copy = [super copy];
  copy.data = [self.data copy];
  copy.type = self.type;
  return copy;
}

-(void) setData:(id)data
{
  _data = data;
  _cachedText = nil;
}

-(void) setData:(id)data withType:(TextMessageType)type
{
  self.type = type;
  self.data = [data copy];
}

-(NSString *) text
{
  if (!_cachedText) {
    switch (_type) {
    case TextMessageType_Simple:
      _cachedText = self.data;
      break;

    case TextMessageType_Html:
      _cachedText = [HTMLTextParser extractText:self.data];
      break;
    }
  }

  return _cachedText;
}

-(void) setText:(NSString *)text
{
  [self setData:text withType:TextMessageType_Simple];
  
  _cachedText = text;
}

-(NSData *) html
{
  switch (_type) {
  case TextMessageType_Html:
    return _data;
      
  case TextMessageType_Simple:
    return [[[@"<html><body>" stringByAppendingString:_data] stringByAppendingString:@"</body></html>"] dataUsingEncoding:NSUTF8StringEncoding];
  }
}

-(void) setHtml:(NSData *)html
{
  [self setData:html withType:TextMessageType_Html];
}

-(NSString *) alertText
{
  return self.text;
}

-(NSString *) summaryText
{
  return self.text;
}

-(BOOL) exportPayloadIntoData:(id<DataReference>  _Nonnull __autoreleasing *)payloadData withMetaData:(NSDictionary *__autoreleasing  _Nonnull *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  switch (_type) {
  case TextMessageType_Simple:
    *metaData = @{@"type":@"text/plain"};
    *payloadData = [MemoryDataReference.alloc initWithData:[self.data dataUsingEncoding:NSUTF8StringEncoding]];
    break;

  case TextMessageType_Html:
    *metaData = @{@"type":@"text/html"};
    *payloadData = [MemoryDataReference.alloc initWithData:self.data];
    break;
  }
  
  return YES;
}

-(BOOL) importPayloadFromData:(id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  TextMessageType type = [metaData[@"type"] isEqualToStringCI:@"text/html"] ? TextMessageType_Html : TextMessageType_Simple;
  
  NSData *data = [DataReferences readAllDataFromReference:payloadData error:error];
  if (!data) {
    return NO;
  }

  switch (type) {
  case TextMessageType_Simple:
    [self setData:[NSString stringWithData:data encoding:NSUTF8StringEncoding] withType:TextMessageType_Simple];
    break;

  case TextMessageType_Html:
    [self setData:data withType:TextMessageType_Html];
    break;
  }
  
  return YES;
}

-(MsgType) payloadType
{
  return MsgTypeText;
}

@end
