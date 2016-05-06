//
//  RTContactMessage.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessage.h"


NS_ASSUME_NONNULL_BEGIN


@interface RTContactMessage : RTMessage

@property (retain, nonatomic) NSData *vcardData;
@property (retain, nullable, nonatomic) NSString *firstName;
@property (retain, nullable, nonatomic) NSString *lastName;
@property (retain, nullable, nonatomic) NSString *extraLabel;

@property (readonly, nullable, nonatomic) NSString *fullName;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat NS_UNAVAILABLE;

-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat vcardData:(NSData *)data NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithChat:(RTChat *)chat vcardData:(NSData *)data;

-(BOOL) isEquivalentToContactMessage:(RTContactMessage *)contactMessage;

@end


NS_ASSUME_NONNULL_END
