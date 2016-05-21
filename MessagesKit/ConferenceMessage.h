//
//  ConferenceMessage.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Message.h"


NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM (int, ConferenceMessageLocalAction) {
  ConferenceMessageLocalActionNone = 0,
  ConferenceMessageLocalActionDeclined = 1,
  ConferenceMessageLocalActionAccepted = 2
};


@interface ConferenceMessage : Message

@property (assign, nonatomic) ConferenceStatus conferenceStatus;
@property (copy, nonatomic) Id *callingDeviceId;
@property (copy, nonatomic) NSString *message;
@property (assign, nonatomic) ConferenceMessageLocalAction localAction;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithId:(Id *)id chat:(Chat *)chat NS_UNAVAILABLE;

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat callingDeviceId:(Id *)callingDeviceId message:(NSString *)message NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithChat:(Chat *)chat callingDeviceId:(Id *)callingDeviceId message:(NSString *)message;

-(BOOL) isEquivalentToConferenceMessage:(ConferenceMessage *)conferenceMessage;

@end


NS_ASSUME_NONNULL_END
