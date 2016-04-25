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
#import "RTWebSocket.h"

#import "RTPersistentCache.h"

#import "RTOpenSSLCertificateValidator.h"


NS_ASSUME_NONNULL_BEGIN


@class OperationQueue;


@interface RTMessageAPI (Internal)

+(id<RTPublicAPIAsync>) publicAPI;

@property(assign, nonatomic) BOOL active;
@property(retain, nullable, nonatomic) RTId *activeChatId;
@property(retain, nullable, nonatomic) RTId *suspendedChatId;

@property (assign, nonatomic) BOOL networkAvailable;

@property (readonly, nonatomic) OperationQueue *queue;

@property (readonly, nonatomic) RTMessageDAO *messageDAO;
@property (readonly, nonatomic) RTChatDAO *chatDAO;
@property (readonly, nonatomic) RTNotificationDAO *notificationDAO;

@property (readonly, nonatomic) id<RTPublicAPIAsync> publicAPI;
@property (readonly, nonatomic) id<RTUserAPIAsync> userAPI;
@property (readonly, nonatomic) RTWebSocket *webSocket;

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
  RTSystemMsgTargetActiveRecipients   = (1 << 0),
  RTSystemMsgTargetCC                 = (1 << 1),
  RTSystemMsgTargetInactiveRecipients = (1 << 2),
  RTSystemMsgTargetStandard           = RTSystemMsgTargetActiveRecipients | RTSystemMsgTargetCC,
  RTSystemMsgTargetEverybody          = RTSystemMsgTargetActiveRecipients | RTSystemMsgTargetCC | RTSystemMsgTargetInactiveRecipients,
};


NS_ASSUME_NONNULL_END
