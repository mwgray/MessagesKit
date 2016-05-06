//
//  RTUserStatusInfo.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/29/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessages.h"
#import "RTChat.h"


@interface RTUserStatusInfo : NSObject

@property (nonatomic, retain) RTChat *chat;
@property (nonatomic, retain) NSString *userAlias;
@property (nonatomic, assign) enum RTUserStatus status;

-(instancetype) initWithStatus:(enum RTUserStatus)status forUser:(NSString *)userAlias inChat:(RTChat *)chat;

+(instancetype) userStatus:(enum RTUserStatus)status forUser:(NSString *)userAlias inChat:(RTChat *)chat;
-(NSString *) statusString;

@end


