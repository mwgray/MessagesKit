//
//  RTTextMessage.h
//  ReTxt
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessage.h"


typedef NS_ENUM (int, RTTextMessageType) {
  RTTextMessageType_Simple = 0,
  RTTextMessageType_Html
};


@interface RTTextMessage : RTMessage

@property (readonly, nonatomic) RTTextMessageType type;
@property (readonly, nonatomic) id data;

@property (nonatomic) NSString *text;

-(void) setData:(id)data withType:(RTTextMessageType)type;

-(BOOL) isEquivalentToTextMessage:(RTTextMessage *)textMessage;

@end
