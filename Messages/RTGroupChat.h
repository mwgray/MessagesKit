//
//  RTGroupChat.h
//  ReTxt
//
//  Created by Kevin Wooten on 2/6/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTChat.h"


@interface RTGroupChat : RTChat

@property (strong, nonatomic) RTId *aliasId;

@property (strong, nonatomic) NSString *customTitle;

@property (strong, nonatomic) NSSet *activeMembers;
@property (strong, nonatomic) NSSet *members;

@property (readonly, nonatomic) BOOL includesMe;

-(BOOL) isEquivalentToGroupChat:(RTGroupChat *)chat;

@end
