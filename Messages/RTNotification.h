//
//  RTNotification.h
//  ReTxt
//
//  Created by Kevin Wooten on 2/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTModel.h"


@interface RTNotification : RTModel

@property (nonatomic, retain) RTId *msgId;
@property (nonatomic, retain) RTId *chatId;
@property (nonatomic, retain) NSData *data;

-(BOOL) isEquivalent:(RTNotification *)notification;

@end
