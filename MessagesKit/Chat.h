//
//  Chat.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/26/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Model.h"


NS_ASSUME_NONNULL_BEGIN


@class Message;


@interface Chat : Model

@property (nonatomic, retain) Id *id;
@property (nonatomic, retain) NSString *alias;
@property (nonatomic, retain) NSString *localAlias;
@property (nonatomic, retain, nullable) Message *lastMessage;
@property (nonatomic, assign) int clarifiedCount;
@property (nonatomic, assign) int updatedCount;

@property (nonatomic, retain) NSDate *startedDate;
@property (nonatomic, assign) int totalMessages;
@property (nonatomic, assign) int totalSent;

@property (nonatomic, copy, nullable) id draft;

@property (nonatomic, readonly) NSSet<NSString *> *activeRecipients;
@property (nonatomic, readonly) NSSet<NSString *> *allRecipients;

@property (nonatomic, readonly) BOOL isGroup;

-(BOOL) isEquivalent:(Chat *)chat;
-(BOOL) isEquivalentToChat:(Chat *)chat;

@end


NS_ASSUME_NONNULL_END