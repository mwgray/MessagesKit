//
//  EnterMessage.h
//  MessagesKit
//
//  Created by Francisco Rimoldi on 03/07/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Message.h"


NS_ASSUME_NONNULL_BEGIN


@interface EnterMessage : Message

@property (retain, nonatomic) NSString *alias;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithId:(Id *)id chat:(Chat *)chat NS_UNAVAILABLE;

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat alias:(NSString *)alias NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithChat:(Chat *)chat alias:(NSString *)alias;

-(BOOL) isEquivalentToEnterMessage:(EnterMessage *)enterMessage;

@end


NS_ASSUME_NONNULL_END
