//
//  RTMessageAPI.h
//  ReTxt
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTAPIError.h"
#import "RTMessage.h"
#import "RTUserChat.h"
#import "RTGroupChat.h"
#import "RTCredentials.h"


NS_ASSUME_NONNULL_BEGIN


@class RTOpenSSLKeyPair;

@class RTContact;
@class RTContactAlias;

@class RTMessageAPI;

@class RTDBManager;
@class RTFetchedResultsController;
@class RTBackgroundTaskManager;


/**
 * Notifications
 **/

extern NSString *RTMessageAPIUserMessageReceivedNotification;
extern NSString *RTMessageAPIUserMessageReceivedNotification_MessageKey;

extern NSString *RTMessageAPIDirectMessageReceivedNotification;
extern NSString *RTMessageAPIDirectMessageReceivedNotification_MsgIdKey;
extern NSString *RTMessageAPIDirectMessageReceivedNotification_MsgTypeKey;
extern NSString *RTMessageAPIDirectMessageReceivedNotification_MsgDataKey;
extern NSString *RTMessageAPIDirectMessageReceivedNotification_SenderKey;
extern NSString *RTMessageAPIDirectMessageReceivedNotification_SenderDeviceIdKey;

extern NSString *RTMessageAPIDirectMessageMsgTypeKeySet;

extern NSString *RTMessageAPIUserStatusDidChangeNotification;
extern NSString *RTMessageAPIUserStatusDidChangeNotification_InfoKey;

extern NSString *RTMessageAPISignedInNotification;
extern NSString *RTMessageAPISignedOutNotification;

extern NSString *RTMessageAPIAccessTokenRefreshed;

/**
 * RTMessageAPI
 **/

@interface RTMessageAPI : NSObject

+(void) initializeWithPublicAPIClient:(nullable RTPublicAPIClientAsync *)publicAPIClient;


/**
 * Sign-In
 **/

+(AnyPromise *) profileWithId:(RTId *)userId password:(NSString *)password;
+(AnyPromise *) profileWithAlias:(NSString *)alias password:(NSString *)password;

+(AnyPromise *) signInWithProfile:(RTUserProfile *)profile password:(NSString *)password;
+(AnyPromise *) isDeviceRegistered:(RTUserProfile *)profile;


/**
 * User Registration
 **/

+(AnyPromise *) requestAliasAuthentication:(NSString *)alias;
+(AnyPromise *) checkAliasAuthentication:(NSString *)alias pin:(NSString *)pin;

+(AnyPromise *) registerUserWithAliases:(NSArray<RTAuthenticatedAlias *> *)aliases
                               password:(NSString *)password
                   documentDirectoryURL:(NSURL *)docsDirURL;


/**
 * Password Reset
 **/

+(AnyPromise *) requestTemporaryPasswordForUser:(NSString *)alias;

+(AnyPromise *) checkTemporaryPasswordForUser:(RTId *)userId
                            temporaryPassword:(NSString *)temporaryPassword;

+(AnyPromise *) resetPasswordForUser:(RTId *)userId
                   temporaryPassword:(NSString *)temporaryPassword
                            password:(NSString *)password;

-(AnyPromise *) changePasswordWithOldPassword:(NSString *)oldPassword
                                  newPassword:(NSString *)newPassword;

@property (readonly, nonatomic) RTCredentials *credentials;

@property (readonly, nonatomic, nullable) NSString *accessToken;
@property (readonly, nonatomic) BOOL accessTokenValid;

@property (strong, nonatomic) NSData *messageNotificationToken;
@property (strong, nonatomic) NSData *informationNotificationToken;


/**
 * Init
 **/

+(nullable RTMessageAPI *) APIWithCredentials:(RTCredentials *)credentials
                         documentDirectoryURL:(NSURL *)docsDirURL
                                        error:(NSError **)error;


-(void) requestAuthorization;
-(AnyPromise *) resetKeys;

/**
 * System
 **/

-(void) signOut;


/**
 * States
 **/

-(BOOL) isChatActive:(RTChat *)chat;
-(BOOL) isOtherChatActive:(RTChat *)chat;

-(void) activateChat:(RTChat *)chat;
-(void) deactivateChat;

-(AnyPromise *) backgroundPoll;

/**
 * Users
 **/

// findUserWithAlias -> RTId
-(AnyPromise *) findUserWithAlias:(NSString *)alias NS_REFINED_FOR_SWIFT;
-(AnyPromise *) findUserWithId:(RTId *)userId;


/**
 * Messages
 **/

-(AnyPromise *) findMessageById:(RTId *)messageId;

-(AnyPromise *) findMessagesMatching:(NSPredicate *)predicate
                              offset:(NSUInteger)offset
                               limit:(NSUInteger)limit
                            sortedBy:(NSArray *)sortDescriptors;

-(RTFetchedResultsController *) fetchMessagesMatching:(NSPredicate *)predicate
                                               offset:(NSUInteger)offset
                                                limit:(NSUInteger)limit
                                             sortedBy:(NSArray *)sortDescriptors;

-(BOOL) saveMessage:(RTMessage *)message;
-(BOOL) updateMessage:(RTMessage *)message;
-(BOOL) updateMessageLocally:(RTMessage *)message;
-(void) clarifyMessage:(RTMessage *)message;
-(BOOL) deleteMessage:(RTMessage *)message;
-(BOOL) deleteMessageLocally:(RTMessage *)message;

-(AnyPromise *) reportWaitingMessage:(RTId *)msgId
                                type:(RTMsgType)msgType
                          dataLength:(int)msgDataLength;

-(NSUInteger) updateUnreadMessageCount;

-(void) sendDirectFrom:(NSString *)sender
    toRecipientDevices:(NSDictionary<NSString *, RTId *> *)recipientDevices
                 msgId:(RTId *)msgId
               msgType:(NSString *)msgType
                  data:(id)data;

-(AnyPromise *) reportDirectMessage:(RTDirectMsg *)msg;

-(void) sendReceiptForMessage:(RTMessage *)message;

/**
 * Chats
 **/

-(AnyPromise *) findChatsMatching:(NSPredicate *)predicate
                           offset:(NSUInteger)offset
                            limit:(NSUInteger)limit
                         sortedBy:(nullable NSArray *)sortDescriptors;

-(RTFetchedResultsController *) fetchChatsMatching:(NSPredicate *)predicate
                                            offset:(NSUInteger)offset
                                             limit:(NSUInteger)limit
                                          sortedBy:(nullable NSArray *)sortDescriptors;

-(RTUserChat *) loadUserChatForAlias:(NSString *)alias localAlias:(NSString *)localAlias;
-(RTGroupChat *) loadGroupChatForId:(RTId *)chatId members:(NSSet<NSString *> *)members localAlias:(NSString *)localAlias;

-(void) exitChat:(RTGroupChat *)chat;
-(void) enterChat:(RTGroupChat *)chat;

-(BOOL) updateChatLocally:(RTChat *)chat;
-(BOOL) deleteChat:(RTChat *)chat;
-(BOOL) deleteChatLocally:(RTChat *)chat;

-(void) sendReceiptForChat:(RTChat *)chat;
-(void) sendReceiptForChatStartingWithMessage:(RTMessage *)message;

/**
 * Status
 **/

-(void) sendUserStatusWithSender:(NSString *)sender recipient:(NSString *)recipient status:(enum RTUserStatus)status;
-(void) sendGroupStatusWithSender:(NSString *)sender chat:(RTId *)chat members:(NSSet *)members status:(enum RTUserStatus)status;


/**
 * Devices
 **/

-(AnyPromise *) listDevices;

+(AnyPromise *) addDeviceNamed:(NSString *)name toProfile:(RTUserProfile *)userProfile withPassword:(NSString *)password;
+(AnyPromise *) replaceDeviceWithId:(RTId *)deviceId withDeviceNamed:(NSString *)deviceName
                          inProfile:(RTUserProfile *)userProfile withPassword:(NSString *)password;
+(AnyPromise *) removeDeviceWithId:(RTId *)deviceId fromProfile:(RTUserProfile *)userProfile withPassword:(NSString *)password;


/**
 * Aliases
 **/

-(AnyPromise *) listAliases;
-(AnyPromise *) addAlias:(NSString *)alias pin:(NSString *)pin;
-(AnyPromise *) removeAlias:(NSString *)alias;

-(void) setPreferredAlias:(NSString *)preferredAlias;

-(AnyPromise *) updateDevice:(RTId *)deviceId withActiveAliases:(NSSet<NSString *> *)activeAliases;


@end


NS_ASSUME_NONNULL_END
