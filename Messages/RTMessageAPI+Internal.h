//
//  RTMessageAPI+Internal.h
//  ReTxt
//
//  Created by Kevin Wooten on 7/27/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

@import UIKit;

#import "RTMessageAPI.h"

#import "RTUserStatusInfo.h"
#import "RTNotification.h"
#import "RTMessageDAO.h"
#import "RTChatDAO.h"
#import "RTNotificationDAO.h"

#import "RTPersistentCache.h"

#import "RTOpenSSLCertificateValidator.h"


NS_ASSUME_NONNULL_BEGIN


@interface RTMessageAPI (Internal)

+(id<RTPublicAPIAsync>) publicAPI;

@property (readonly, nonatomic, getter=isActive) BOOL active;

@property (readonly, nonatomic, getter=isNetworkUnavailable) BOOL networkUnavailable;

@property (readonly, nonatomic) RTMessageDAO *messageDAO;
@property (readonly, nonatomic) RTChatDAO *chatDAO;
@property (readonly, nonatomic) RTNotificationDAO *notificationDAO;

@property (readonly, nonatomic) id<RTPublicAPIAsync> publicAPI;
@property (readonly, nonatomic) id<RTUserAPIAsync> userAPI;

@property (readonly, nonatomic) RTPersistentCache<NSString *, RTUserInfo *> *userInfoCache;

@property (readonly, nonatomic) NSURLSession *backgroundSession;

@property (readonly, nonatomic) RTOpenSSLCertificateTrust *certificateTrust;

-(void) updateAccessToken:(NSString *)accessToken;

-(void) hideNotificationsForChat:(RTChat *)chat;

-(void) showNotificationForMessage:(RTMessage *)message;
-(void) hideNotificationForMessage:(RTMessage *)message;

-(void) showFailNotificationForMessage:(RTMessage *)message;

-(void) saveAndScheduleNotification:(UILocalNotification *)localNotification forMessage:(RTMessage *)message;
-(void) deleteAndCancelNotification:(RTNotification *)notification ifOnOrBefore:(nullable NSDate *)sent;

-(void) adjustUnreadWithDelta:(NSInteger)delta;

@end


typedef NS_OPTIONS (int, RTSystemMsgTarget) {
  RTSystemMsgTargetRecipients = (1 << 0),
  RTSystemMsgTargetCC         = (1 << 1),
  RTSystemMsgTargetInactive   = (1 << 2),
  RTSystemMsgTargetAll        = RTSystemMsgTargetRecipients | RTSystemMsgTargetCC | RTSystemMsgTargetInactive,
};


NS_ASSUME_NONNULL_END
