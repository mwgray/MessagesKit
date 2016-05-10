//
//  UserStatusInfo.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/29/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Messages.h"
#import "Chat.h"


@interface UserStatusInfo : NSObject

@property (nonatomic, retain) Chat *chat;
@property (nonatomic, retain) NSString *userAlias;
@property (nonatomic, assign) enum UserStatus status;

-(instancetype) initWithStatus:(enum UserStatus)status forUser:(NSString *)userAlias inChat:(Chat *)chat;

+(instancetype) userStatus:(enum UserStatus)status forUser:(NSString *)userAlias inChat:(Chat *)chat;
-(NSString *) statusString;

@end


