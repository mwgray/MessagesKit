//
//  UserChat.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/26/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Chat.h"


@interface UserChat : Chat

-(BOOL) isEquivalentToUserChat:(UserChat *)chat;

@end
