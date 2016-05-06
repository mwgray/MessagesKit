//
//  RTTextMessage.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessage.h"


NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM (int, RTTextMessageType) {
  RTTextMessageType_Simple = 0,
  RTTextMessageType_Html
};


@interface RTTextMessage : RTMessage

@property (readonly, nonatomic) RTTextMessageType type;
@property (readonly, nonatomic) id data;

@property (nonatomic) NSString *text;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat NS_UNAVAILABLE;

-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat data:(id<DataReference>)data type:(RTTextMessageType)type NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat text:(NSString *)text;
-(instancetype) initWithChat:(RTChat *)chat text:(NSString *)text;
-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat html:(NSString *)html;
-(instancetype) initWithChat:(RTChat *)chat html:(NSString *)html;

-(void) setData:(id)data withType:(RTTextMessageType)type;

-(BOOL) isEquivalentToTextMessage:(RTTextMessage *)textMessage;

@end


NS_ASSUME_NONNULL_END
