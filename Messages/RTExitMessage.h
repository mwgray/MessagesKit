//
//  RTExitMessage.h
//  ReTxt
//
//  Created by Francisco Rimoldi on 03/07/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessage.h"

@interface RTExitMessage : RTMessage

@property (nonatomic, retain) NSString *alias;

-(BOOL) isEquivalentToExitMessage:(RTExitMessage *)exitMessage;

@end
