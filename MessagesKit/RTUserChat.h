//
//  RTUserChat.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/26/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTChat.h"


@interface RTUserChat : RTChat

-(BOOL) isEquivalentToUserChat:(RTUserChat *)chat;

@end
