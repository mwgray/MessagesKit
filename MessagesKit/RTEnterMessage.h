//
//  RTEnterMessage.h
//  MessagesKit
//
//  Created by Francisco Rimoldi on 03/07/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessage.h"


NS_ASSUME_NONNULL_BEGIN


@interface RTEnterMessage : RTMessage

@property (retain, nonatomic) NSString *alias;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat NS_UNAVAILABLE;

-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat alias:(NSString *)alias NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithChat:(RTChat *)chat alias:(NSString *)alias;

-(BOOL) isEquivalentToEnterMessage:(RTEnterMessage *)enterMessage;

@end


NS_ASSUME_NONNULL_END
