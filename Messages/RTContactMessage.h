//
//  RTContactMessage.h
//  ReTxt
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessage.h"


@interface RTContactMessage : RTMessage

@property (nonatomic, retain) NSData *vcardData;
@property (nonatomic, retain) NSString *firstName;
@property (nonatomic, retain) NSString *lastName;
@property (nonatomic, retain) NSString *extraLabel;

-(BOOL) isEquivalentToContactMessage:(RTContactMessage *)contactMessage;
-(NSString *) fullName;
@end
