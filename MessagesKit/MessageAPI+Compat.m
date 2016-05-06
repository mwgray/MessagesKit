//
//  MessageAPI+Compat.h
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "MessageAPI+Compat.h"


NSString* const MessageAPIUserMessageReceivedNotification = @"UserMessageReceived";
NSString* const MessageAPIUserMessageReceivedNotification_MessageKey = @"message";

NSString* const MessageAPIDirectMessageReceivedNotification = @"DirectMessageReceivedNotification";
NSString* const MessageAPIDirectMessageReceivedNotification_MsgIdKey = @"msgId";
NSString* const MessageAPIDirectMessageReceivedNotification_MsgTypeKey = @"msgType";
NSString* const MessageAPIDirectMessageReceivedNotification_MsgDataKey = @"msgData";
NSString* const MessageAPIDirectMessageReceivedNotification_SenderKey = @"sender";
NSString* const MessageAPIDirectMessageReceivedNotification_SenderDeviceIdKey = @"senderDeviceId";

NSString* const MessageAPIDirectMessageMsgTypeKeySet = @"keySet";

NSString* const MessageAPIUserStatusDidChangeNotification = @"UserStatusDidChange";
NSString* const MessageAPIUserStatusDidChangeNotification_InfoKey = @"info";

NSString* const MessageAPISignedInNotification = @"MessageAPISignedInNotification";
NSString* const MessageAPISignedOutNotification = @"MessageAPISignedOutNotification";

NSString* const MessageAPIAccessTokenRefreshed = @"MessageAPIAccessTokenRefreshed";
