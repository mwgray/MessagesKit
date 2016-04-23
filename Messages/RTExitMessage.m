//
//  RTExitMessage.m
//  ReTxt
//
//  Created by Francisco Rimoldi on 03/07/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTExitMessage.h"

#import "RTMessageDAO.h"
#import "NSObject+Utils.h"
#import "NSMutableDictionary+Utils.h"


@implementation RTExitMessage

-(BOOL) load:(FMResultSet *)resultSet dao:(RTMessageDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super load:resultSet dao:dao error:error]) {
    return NO;
  }

  self.alias = [resultSet stringForColumnIndex:dao.data1FieldIdx];
  
  return YES;
}

-(BOOL) save:(NSMutableDictionary *)values dao:(RTDAO *)dao error:(NSError *__autoreleasing *)error
{
  if (![super save:values dao:dao error:error]) {
    return NO;
  }
  
  [values setNillableObject:self.alias forKey:@"data1"];
  
  return YES;
}

-(BOOL) isEquivalent:(id)object
{
  if (![object isKindOfClass:[RTExitMessage class]]) {
    return NO;
  }

  return [self isEquivalentToExitMessage:object];
}

-(BOOL) isEquivalentToExitMessage:(RTExitMessage *)exitMessage
{
  return [super isEquivalentToMessage:exitMessage] &&
         isEqual(self.alias, exitMessage.alias);
}

-(id) copy
{
  RTExitMessage *copy = [super copy];
  copy.alias = self.alias;
  return copy;
}

-(NSString *) alertText
{
  //FIXME
  //RTContact *contact = [RTAddressBook.sharedInstance findContactWithAlias:self.alias];

  //NSString *name = contact ? contact.name : [self.alias formattedAliasWithDefaultRegion:nil];

  //return [NSString stringWithFormat:@"%@ has left a group chat", name];
  
  return nil;
}

-(NSString *) summaryText
{
  //FIXME
  //RTContact *contact = [RTAddressBook.sharedInstance findContactWithAlias:self.alias];

  //NSString *name = contact ? contact.name : [self.alias formattedAliasWithDefaultRegion:nil];

  //return [NSString stringWithFormat:@"%@ has left", name];
  
  return nil;
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

-(enum RTMsgType) payloadType
{
  return RTMsgTypeExit;
}

@end
