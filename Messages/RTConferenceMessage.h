//
//  RTConferenceMessage.h
//  ReTxt
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessage.h"


typedef NS_ENUM (int, RTConferenceMessageLocalAction) {
  RTConferenceMessageLocalActionNone = 0,
  RTConferenceMessageLocalActionDeclined = 1,
  RTConferenceMessageLocalActionAccepted = 2
};


@interface RTConferenceMessage : RTMessage

@property (assign, nonatomic) RTConferenceStatus conferenceStatus;
@property (retain, nonatomic) RTId *callingDeviceId;
@property (retain, nonatomic) NSString *message;
@property (assign, nonatomic) RTConferenceMessageLocalAction localAction;

-(BOOL) isEquivalentToConferenceMessage:(RTConferenceMessage *)conferenceMessage;

@end
