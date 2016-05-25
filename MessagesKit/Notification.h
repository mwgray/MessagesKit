//
//  Notification.h
//  MessagesKit
//
//  Created by Kevin Wooten on 2/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Model.h"


@interface SavedNotification : Model

@property (nonatomic, retain) Id *msgId;
@property (nonatomic, retain) Id *chatId;
@property (nonatomic, retain) NSData *data;

-(BOOL) isEquivalent:(SavedNotification *)notification;

@end
