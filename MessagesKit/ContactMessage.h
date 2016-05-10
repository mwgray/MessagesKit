//
//  ContactMessage.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Message.h"


NS_ASSUME_NONNULL_BEGIN


@interface ContactMessage : Message

@property (retain, nonatomic) NSData *vcardData;
@property (retain, nullable, nonatomic) NSString *firstName;
@property (retain, nullable, nonatomic) NSString *lastName;
@property (retain, nullable, nonatomic) NSString *extraLabel;

@property (readonly, nullable, nonatomic) NSString *fullName;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithId:(Id *)id chat:(Chat *)chat NS_UNAVAILABLE;

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat vcardData:(NSData *)data NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithChat:(Chat *)chat vcardData:(NSData *)data;

-(BOOL) isEquivalentToContactMessage:(ContactMessage *)contactMessage;

@end


NS_ASSUME_NONNULL_END
