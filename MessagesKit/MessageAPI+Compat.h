//
//  MessageAPI+Compat.h
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

@import  Foundation;


typedef NS_OPTIONS (int, SystemMsgTarget) {
  SystemMsgTargetActiveRecipients   = (1 << 0),
  SystemMsgTargetCC                 = (1 << 1),
  SystemMsgTargetInactiveRecipients = (1 << 2),
  SystemMsgTargetStandard           = SystemMsgTargetActiveRecipients | SystemMsgTargetCC,
  SystemMsgTargetEverybody          = SystemMsgTargetActiveRecipients | SystemMsgTargetCC | SystemMsgTargetInactiveRecipients,
};


// Notification types & dictionary keys
//
extern NSString* const MessageAPIUserMessageReceivedNotification;
extern NSString* const MessageAPIUserMessageReceivedNotification_MessageKey;

extern NSString* const MessageAPIDirectMessageReceivedNotification;
extern NSString* const MessageAPIDirectMessageReceivedNotification_MsgIdKey;
extern NSString* const MessageAPIDirectMessageReceivedNotification_MsgTypeKey;
extern NSString* const MessageAPIDirectMessageReceivedNotification_MsgDataKey;
extern NSString* const MessageAPIDirectMessageReceivedNotification_SenderKey;
extern NSString* const MessageAPIDirectMessageReceivedNotification_SenderDeviceIdKey;

extern NSString* const MessageAPIDirectMessageMsgTypeKeySet;

extern NSString* const MessageAPIUserStatusDidChangeNotification;
extern NSString* const MessageAPIUserStatusDidChangeNotification_InfoKey;

extern NSString* const MessageAPISignedInNotification;
extern NSString* const MessageAPISignedOutNotification;

extern NSString* const MessageAPIAccessTokenRefreshed;
