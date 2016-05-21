//
//  EnterMessage.m
//  MessagesKit
//
//  Created by Francisco Rimoldi on 03/07/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "EnterMessage.h"

#import "MessageDAO.h"
#import "MemoryDataReference.h"
#import "Messages+Exts.h"
#import "NSObject+Utils.h"
#import "NSMutableDictionary+Utils.h"


@implementation EnterMessage

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat alias:(NSString *)alias
{
  self = [super initWithId:id chat:chat];
  if (self) {
    
    self.alias = alias;
    
  }
  return self;
}

-(instancetype) initWithChat:(Chat *)chat alias:(NSString *)alias
{
  return [self initWithId:[Id generate] chat:chat alias:alias];
}

-(id) copy
{
  EnterMessage *copy = [super copy];
  copy.alias = self.alias;
  return copy;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:[EnterMessage class]]) {
    return NO;
  }

  return [self isEquivalentToEnterMessage:object];
}

-(BOOL) isEquivalentToEnterMessage:(EnterMessage *)enterMessage
{
  return
  [super isEquivalentToMessage:enterMessage] &&
  isEqual(self.alias, enterMessage.alias);
}

-(BOOL) load:(FMResultSet *)resultSet dao:(MessageDAO *)dao error:(NSError **)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }
  
  self.alias = [resultSet stringForColumnIndex:dao.data1FieldIdx];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(DAO *)dao error:(NSError **)error
{
  if (![super save:values dao:dao error:error]) {
    return NO;
  }
  
  [values setNillableObject:self.alias forKey:@"data1"];
  
  return YES;
}

-(enum MsgType) payloadType
{
  return MsgTypeEnter;
}

-(BOOL) exportPayloadIntoData:(id<DataReference> *)payloadData withMetaData:(NSDictionary **)metaData error:(NSError **)error
{
  *metaData = @{@"member" : self.alias};
  *payloadData = nil;
  
  return YES;
}

-(BOOL) importPayloadFromData:(id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError **)error
{
  self.alias = metaData[@"member"];
  
  return YES;
}

@end
