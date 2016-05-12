//
//  ExitMessage.m
//  MessagesKit
//
//  Created by Francisco Rimoldi on 03/07/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "ExitMessage.h"

#import "MessageDAO.h"
#import "Messages+Exts.h"
#import "NSObject+Utils.h"
#import "NSMutableDictionary+Utils.h"


@implementation ExitMessage

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

-(BOOL) load:(FMResultSet *)resultSet dao:(MessageDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }

  self.alias = [resultSet stringForColumnIndex:dao.data1FieldIdx];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(DAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super save:values dao:dao error:error]) {
    return NO;
  }
  
  [values setNillableObject:self.alias forKey:@"data1"];
  
  return YES;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:[ExitMessage class]]) {
    return NO;
  }

  return [self isEquivalentToExitMessage:object];
}

-(BOOL) isEquivalentToExitMessage:(ExitMessage *)exitMessage
{
  return [super isEquivalentToMessage:exitMessage] &&
         isEqual(self.alias, exitMessage.alias);
}

-(id) copy
{
  ExitMessage *copy = [super copy];
  copy.alias = self.alias;
  return copy;
}

-(BOOL) exportPayloadIntoData:(id<DataReference>  _Nonnull __autoreleasing *)payloadData withMetaData:(NSDictionary *__autoreleasing  _Nonnull *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  *metaData = @{@"member" : self.alias};
  *payloadData = nil;
  
  return YES;
}

-(BOOL) importPayloadFromData:(id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError * _Nullable __autoreleasing *)error
{
  self.alias = metaData[@"member"];
  
  return YES;
}

-(enum MsgType) payloadType
{
  return MsgTypeExit;
}

@end
