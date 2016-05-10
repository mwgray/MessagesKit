//
//  TextMessage.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Message.h"


NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM (int, TextMessageType) {
  TextMessageType_Simple = 0,
  TextMessageType_Html
};


@interface TextMessage : Message

@property (readonly, nonatomic) TextMessageType type;
@property (readonly, nonatomic) id data;

@property (nonatomic) NSString *text;
@property (nonatomic) NSData *html;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithId:(Id *)id chat:(Chat *)chat NS_UNAVAILABLE;

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat data:(id)data type:(TextMessageType)type NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithId:(Id *)id chat:(Chat *)chat text:(NSString *)text;
-(instancetype) initWithChat:(Chat *)chat text:(NSString *)text;
-(instancetype) initWithId:(Id *)id chat:(Chat *)chat html:(NSString *)html;
-(instancetype) initWithChat:(Chat *)chat html:(NSString *)html;

-(BOOL) isEquivalentToTextMessage:(TextMessage *)textMessage;

@end


NS_ASSUME_NONNULL_END
