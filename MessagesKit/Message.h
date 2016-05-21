//
//  Message.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/27/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "Messages.h"
#import "Model.h"


NS_ASSUME_NONNULL_BEGIN


@class Chat;
@protocol DataReference;


typedef NS_ENUM (int32_t, MessageStatus) {
  MessageStatusUnsent      = -2,
  MessageStatusFailed      = -1,
  MessageStatusSending     =  0,
  MessageStatusSent        =  1,
  MessageStatusDelivered   =  2,
  MessageStatusViewed      =  3,
};


typedef NS_OPTIONS (int64_t, MessageFlag) {
  MessageFlagClarify   = (1 << 0),
  MessageFlagUnread    = (1 << 1),
  MessageFlagSilent    = (1 << 2),
};
typedef MessageFlag MessageFlags;


typedef NS_ENUM (int32_t, MessageSoundAlert) {
  MessageSoundAlertNone,
  MessageSoundAlertStandard,
  MessageSoundAlertInteractive,
};


@interface Message : Model

@property (copy, nonatomic) Id *id;
@property (strong, nonatomic) Chat *chat;
@property (copy, nonatomic, nullable) NSString *sender;
@property (copy, nonatomic, nullable) NSDate *sent;
@property (copy, nonatomic, nullable) NSDate *updated;
@property (assign, nonatomic) MessageStatus status;
@property (copy, nonatomic, nullable) NSDate *statusTimestamp;
@property (assign, nonatomic) MessageFlags flags;

@property (assign, nonatomic) BOOL clarifyFlag;
@property (assign, nonatomic) BOOL unreadFlag;

@property (readonly, nonatomic) BOOL newlyUpdated;
@property (readonly, nonatomic) BOOL newlyClarified;

@property (readonly, nonatomic) BOOL sentByMe;

@property (readonly, nonatomic) MessageSoundAlert soundAlert;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithChat:(Chat *)chat;
-(instancetype) initWithId:(Id *)id chat:(Chat *)chat NS_DESIGNATED_INITIALIZER;

-(BOOL) isEquivalent:(Message *)message;
-(BOOL) isEquivalentToMessage:(Message *)message;

-(NSString *) alertText;
-(NSString *) summaryText;

@property (readonly, nonatomic) MsgType payloadType;

-(BOOL) exportPayloadIntoData:(id<DataReference> __nonnull * __nullable)payloadData withMetaData:( NSDictionary * __nonnull * __nullable)metaData error:(NSError **)error;
-(BOOL) importPayloadFromData:(nullable id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError **)error;

-(NSString *) statusString;

@end


NS_ASSUME_NONNULL_END
