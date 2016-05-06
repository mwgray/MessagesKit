//
//  RTChat.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/26/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTModel.h"


NS_ASSUME_NONNULL_BEGIN


@class RTMessage;


@interface RTChat : RTModel

@property (nonatomic, retain) RTId *id;
@property (nonatomic, retain) NSString *alias;
@property (nonatomic, retain) NSString *localAlias;
@property (nonatomic, retain, nullable) RTMessage *lastMessage;
@property (nonatomic, assign) int clarifiedCount;
@property (nonatomic, assign) int updatedCount;

@property (nonatomic, retain) NSDate *startedDate;
@property (nonatomic, assign) int totalMessages;
@property (nonatomic, assign) int totalSent;

@property (nonatomic, copy, nullable) id draft;

@property (nonatomic, readonly) NSSet<NSString *> *activeRecipients;
@property (nonatomic, readonly) NSSet<NSString *> *allRecipients;

@property (nonatomic, readonly) BOOL isGroup;

-(BOOL) isEquivalent:(RTChat *)chat;
-(BOOL) isEquivalentToChat:(RTChat *)chat;

@end


NS_ASSUME_NONNULL_END