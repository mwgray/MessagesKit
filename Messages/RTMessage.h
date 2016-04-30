//
//  RTMessage.h
//  ReTxt
//
//  Created by Kevin Wooten on 1/27/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "RTMessages.h"
#import "RTModel.h"


NS_ASSUME_NONNULL_BEGIN


@class RTChat;
@protocol DataReference;


typedef NS_ENUM (int32_t, RTMessageStatus) {
  RTMessageStatusUnsent      = -2,
  RTMessageStatusFailed      = -1,
  RTMessageStatusSending     =  0,
  RTMessageStatusSent        =  1,
  RTMessageStatusDelivered   =  2,
  RTMessageStatusViewed      =  3,
};


typedef NS_OPTIONS (int64_t, RTMessageFlag) {
  RTMessageFlagClarify   = (1 << 0),
  RTMessageFlagUnread    = (1 << 1),
  RTMessageFlagSilent    = (1 << 2),
};
typedef RTMessageFlag RTMessageFlags;


typedef NS_ENUM (int32_t, RTMessageSoundAlert) {
  RTMessageSoundAlertNone,
  RTMessageSoundAlertStandard,
  RTMessageSoundAlertInteractive,
};


@interface RTMessage : RTModel

@property (copy, nonatomic) RTId *id;
@property (strong, nonatomic) RTChat *chat;
@property (copy, nonatomic, nullable) NSString *sender;
@property (copy, nonatomic, nullable) NSDate *sent;
@property (copy, nonatomic, nullable) NSDate *updated;
@property (assign, nonatomic) RTMessageStatus status;
@property (copy, nonatomic, nullable) NSDate *statusTimestamp;
@property (assign, nonatomic) RTMessageFlags flags;

@property (assign, nonatomic) BOOL clarifyFlag;
@property (assign, nonatomic) BOOL unreadFlag;

@property (readonly, nonatomic) BOOL newlyUpdated;
@property (readonly, nonatomic) BOOL newlyClarified;

@property (readonly, nonatomic) BOOL sentByMe;

@property (readonly, nonatomic) RTMessageSoundAlert soundAlert;

-(instancetype) init NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithChat:(RTChat *)chat;
-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat NS_DESIGNATED_INITIALIZER;

-(BOOL) isEquivalent:(RTMessage *)message;
-(BOOL) isEquivalentToMessage:(RTMessage *)message;

-(NSString *) alertText;
-(NSString *) summaryText;

@property (readonly, nonatomic) RTMsgType payloadType;

-(BOOL) exportPayloadIntoData:(id<DataReference> __nonnull * __nullable)payloadData withMetaData:( NSDictionary * __nonnull * __nullable)metaData error:(NSError **)error;
-(BOOL) importPayloadFromData:(nullable id<DataReference>)payloadData withMetaData:(NSDictionary *)metaData error:(NSError **)error;

-(NSString *) statusString;

+(NSNumber *) shouldConvertDataToBlob:(id<DataReference>)data error:(NSError **)error;
-(id<DataReference>)internalizeData:(id<DataReference>)data dbManager:(RTDBManager *)dbManager error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
