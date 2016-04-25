//
//  RTTextMessage.m
//  ReTxt
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTTextMessage.h"

#import "RTMessageDAO.h"
#import "MemoryDataReference.h"
#import "DataReferences.h"
#import "RTHTMLText.h"
#import "NSObject+Utils.h"
#import "NSString+Utils.h"
#import "NSMutableDictionary+Utils.h"


@interface RTTextMessage ()

@property (assign, nonatomic) RTTextMessageType type;
@property (strong, nonatomic) id data;

@property (strong, nonatomic) NSString *cachedText;

@end


@implementation RTTextMessage

-(BOOL) load:(FMResultSet *)resultSet dao:(RTMessageDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }

  self.type = [resultSet intForColumnIndex:dao.data2FieldIdx];

  switch (self.type) {
  case RTTextMessageType_Simple:
    self.data = [resultSet stringForColumnIndex:dao.data1FieldIdx];
    break;

  case RTTextMessageType_Html:
    self.data = [resultSet dataForColumnIndex:dao.data1FieldIdx];
    break;
  }
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(RTDAO *)dao error:(NSError *__autoreleasing *)error
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
  if (![object isKindOfClass:[RTTextMessage class]]) {
    return NO;
  }

  return [self isEquivalentToTextMessage:object];
}

-(BOOL) isEquivalentToTextMessage:(RTTextMessage *)textMessage
{
  return [super isEquivalentToMessage:textMessage] &&
         isEqual(self.data, textMessage.data) &&
         self.type == textMessage.type;
}

-(id) copy
{
  RTTextMessage *copy = [super copy];
  copy.data = [self.data copy];
  copy.type = self.type;
  return copy;
}

-(void) setData:(id)data
{
  _data = data;
  _cachedText = nil;
}

-(void) setData:(id)data withType:(RTTextMessageType)type
{
  self.type = type;
  self.data = [data copy];
}

-(NSString *) text
{
  if (!_cachedText) {
    switch (_type) {
    case RTTextMessageType_Simple:
      _cachedText = self.data;
      break;

    case RTTextMessageType_Html:
      _cachedText = [RTHTMLTextParser extractText:self.data];
      break;
    }
  }

  return _cachedText;
}

-(void) setText:(NSString *)text
{
  [self setData:text withType:RTTextMessageType_Simple];

  _cachedText = text;
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
  case RTTextMessageType_Simple:
    *metaData = @{@"type":@"text/plain"};
    *payloadData = [[MemoryDataReference alloc] initWithData:[self.data dataUsingEncoding:NSUTF8StringEncoding]];
    break;

  case RTTextMessageType_Html:
    *metaData = @{@"type":@"text/html"};
    *payloadData = [[MemoryDataReference alloc] initWithData:self.data];
    break;
  }
  
  return YES;
}

-(BOOL) importPayloadFromData:(id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  self.type = [metaData[@"type"] isEqualToStringCI:@"text/html"] ? RTTextMessageType_Html : RTTextMessageType_Simple;
  
  NSData *data = [DataReferences readAllDataFromReference:payloadData error:error];
  if (!data) {
    return NO;
  }

  switch (self.type) {
  case RTTextMessageType_Simple:
    self.text = [NSString stringWithData:data encoding:NSUTF8StringEncoding];
    break;

  case RTTextMessageType_Html:
    self.data = data;
    break;
  }
  
  return YES;
}

-(RTMsgType) payloadType
{
  return RTMsgTypeText;
}

@end
