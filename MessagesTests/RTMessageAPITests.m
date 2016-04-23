//
//  RTMessageAPITests.m
//  ReTxt
//
//  Created by Kevin Wooten on 7/12/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>

#import "RTWebSocket.h"
#import "RTMessageAPI.h"
#import "RTDAO+Internal.h"
#import "RTChatDAO.h"
#import "RTMessageDAO.h"
#import "RTNotificationDAO.h"
#import "RTFetchedResultsController.h"
#import "RTTextMessage.h"
#import "TTransportError.h"
#import "RTMsgCipher.h"
#import "NSDate+Utils.h"
#import "RTMessages+Exts.h"


NSString *RTMockAPIGoodAlias = @"test@guy.com";
NSString *RTMockAPIGoodOtherAlias = @"other@guy.com";
NSString *RTMockAPIGoodOther2Alias = @"other2@guy.com";
NSString *RTMockAPIUnusedAlias = @"unused@guy.com";
NSString *RTMockAPIInvalidAlias = @"guy";
NSString *RTMockAPINetworkErrorAlias = @"network.error@guy.com";

RTId *RTMockAPIGoodUserId;
RTId *RTMockAPIGoodOtherUserId;
RTId *RTMockAPIGoodOther2UserId;
RTId *RTMockAPIGoodDeviceId;

NSArray *RTMockAPIGroupMembers;
NSDictionary *RTMockAPIGroupResolve;


extern RTPublicAPIClient *_s_publicAPIClient;
extern dispatch_queue_t _s_apiQueue;


@interface RTMessageAPI (Testing) <RTWebSocketDelegate>

+(RTPublicAPIClient *) publicAPIClient;
+(RTUserAPIClient *) userAPIClientWithUserId:(RTId *)userId password:(NSString *)password deviceId:(RTId *)deviceId;
+(RTWebSocket *) webSocketWithUserId:(RTId *)userId password:(NSString *)password deviceId:(RTId *)deviceId;
+(RTDBManager *) dbManagerWithURL:(NSURL *)dbURL;

@end


@interface RTMessageAPITests : XCTestCase <RTFetchedResultsControllerDelegate, RTMessageAPIDelegate>

@property (nonatomic, strong) RTMessageAPI *messageAPI;
@property (nonatomic, strong) RTMessageAPI *messageAPIBad;
@property (nonatomic, strong) RTPublicAPIClient *messageAPIPublicAPI;
@property (nonatomic, strong) RTUserAPIClient *messageAPIUserAPI;
@property (nonatomic, strong) RTUserAPIClient *messageAPIUserAPIBad;
@property (nonatomic, strong) RTWebSocket *messageAPIWebSocket;
@property (nonatomic, strong) RTDBManager *messageAPIDBManager;
@property (nonatomic, strong) RTMessageDAO *messageAPIMessageDAO;
@property (nonatomic, strong) RTChatDAO *messageAPIChatDAO;
@property (nonatomic, strong) RTNotificationDAO *messageAPINotificationDAO;

@property (nonatomic, strong) RTMsgCipher *msgCipher;
@property (nonatomic, strong) RTKeyPair *keyPair;

@property (nonatomic, strong) NSCountedSet *inserted;
@property (nonatomic, strong) NSCountedSet *updated;
@property (nonatomic, strong) NSCountedSet *moved;
@property (nonatomic, strong) NSCountedSet *deleted;
@property (nonatomic, assign) int receivedAlertPlayed;
@property (nonatomic, assign) int sendAlertPlayed;

@property (nonatomic, strong) RTId *lastSentMsgId;
@property (nonatomic, strong) RTId *lastSentMsgChatId;

@end

@implementation RTMessageAPITests


+(void) initialize
{
  RTMockAPIGoodUserId = [RTId idWithString:@"BE6F1345-15E5-4DE4-B701-0F30AA8BA6A4"];
  RTMockAPIGoodOtherUserId = [RTId idWithString:@"BCED7524-5510-4F2B-B853-6CD4D903F34D"];
  RTMockAPIGoodOther2UserId = [RTId idWithString:@"89280AD8-BA07-477C-9A1C-1E4188C10009"];
  RTMockAPIGoodDeviceId = [RTId idWithString:@"6E5AD00A-4365-4CB7-A281-E41E2D15E8FB"];
  RTMockAPIGroupMembers = @[RTMockAPIGoodOtherAlias, RTMockAPIGoodOther2Alias, RTMockAPIGoodAlias];

  RTKeyPair *keyPair = [RTKeyPair generateKeyPairWithKeySize:1024];

  RTMockAPIGroupResolve = @{RTMockAPIGoodAlias: [[RTUserInfo alloc] initWithId:RTMockAPIGoodUserId aliases:[NSMutableSet set] publicKeyData:[keyPair exportPublicKey] verifyKeyData:[keyPair exportPublicKey] eTag:0],
                            RTMockAPIGoodOtherAlias: [[RTUserInfo alloc] initWithId:RTMockAPIGoodOtherUserId aliases:[NSMutableSet set] publicKeyData:[keyPair exportPublicKey] verifyKeyData:[keyPair exportPublicKey] eTag:0],
                            RTMockAPIGoodOther2Alias: [[RTUserInfo alloc] initWithId:RTMockAPIGoodOther2UserId aliases:[NSMutableSet set] publicKeyData:[keyPair exportPublicKey] verifyKeyData:[keyPair exportPublicKey] eTag:0]};
}

-(void) setUp
{
  [super setUp];

  [UIApplication sharedApplication].applicationIconBadgeNumber = 0;

  NSURL *docsDirURL = [NSURL fileURLWithPath:NSTemporaryDirectory()];
  NSURL *dbURL = [docsDirURL URLByAppendingPathComponent:@"message-api-test.sqlite"];
  [[NSFileManager defaultManager] removeItemAtURL:dbURL error:nil];

  _inserted = [NSCountedSet set];
  _updated = [NSCountedSet set];
  _moved = [NSCountedSet set];
  _deleted = [NSCountedSet set];

  _messageAPIPublicAPI = [self publicAPIClientMock];
  _messageAPIUserAPI = [self userAPIClientMock:YES];
  _messageAPIUserAPIBad = [self userAPIClientMock:NO];
  _messageAPIWebSocket = [self webSocketMock];
  _messageAPIDBManager = [self dbManagerMock];

  _msgCipher = [RTMsgCipher new];
  _keyPair = [RTKeyPair generateKeyPairWithKeySize:2048];

  RTCredentials *credentials = [RTCredentials new];
  credentials.userId = RTMockAPIGoodUserId;
  credentials.password = @"test";
  credentials.deviceId = RTMockAPIGoodDeviceId;
  credentials.allAliases = @[RTMockAPIGoodAlias];
  credentials.preferredAlias = RTMockAPIGoodAlias;
  credentials.encryptionKeyPair = _keyPair;
  credentials.signingKeyPair = _keyPair;

  _messageAPI = [[self messageAPIMock] initWithUserAPIClient:_messageAPIUserAPI
                                                 credentials:credentials
                                       documentsDirectoryURL:docsDirURL];
  _messageAPI.delegate = self;

  _messageAPIBad = [[self messageAPIMock] initWithUserAPIClient:_messageAPIUserAPIBad
                                                    credentials:credentials
                                          documentsDirectoryURL:docsDirURL];
  _messageAPI.delegate = self;
}

-(void) tearDown
{
  [super tearDown];
}

-(void) activate
{
  [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
}

-(void) deactivate
{
  [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillResignActiveNotification object:nil];
}

-(void) flush
{
}

-(void) testFindUserWithAlias
{
  XCTestExpectation *expectation = [self expectationWithDescription:@"1 findUserWithAlias:completion:"];

  [RTMessageAPI findUserWithAlias:RTMockAPIGoodAlias].then(^(RTId *userId) {
    XCTAssertEqualObjects(userId, RTMockAPIGoodUserId);
  })
  .catch(^(NSError *error) {
    XCTAssertNil(error);

    [expectation fulfill];
  });

  XCTestExpectation *expectation2 = [self expectationWithDescription:@"2 findUserWithAlias:completion:"];

  [RTMessageAPI findUserWithAlias:RTMockAPIUnusedAlias].then(^(RTId *userId) {
    XCTAssertEqualObjects(userId, RTMockAPIGoodUserId);
  })
  .catch(^(NSError *error) {
    XCTAssertNil(error);

    [expectation2 fulfill];
  });

  XCTestExpectation *expectation3 = [self expectationWithDescription:@"3 findUserWithAlias:completion:"];

  [RTMessageAPI findUserWithAlias:RTMockAPINetworkErrorAlias].then(^(RTId *userId) {
    XCTAssertEqualObjects(userId, RTMockAPIGoodUserId);
  })
  .catch(^(NSError *error) {
    XCTAssertNil(error);

    [expectation fulfill];
  });

  [self waitForExpectationsWithTimeout:5 handler:NULL];
}

-(void) testRequestAliasAuthentication
{
  XCTestExpectation *expectation1 = [self expectationWithDescription:@"1"];

  [RTMessageAPI requestAliasAuthentication:RTMockAPIUnusedAlias completion:^(NSError *error) {
    XCTAssertNil(error);

    [expectation1 fulfill];
  }];

  XCTestExpectation *expectation2 = [self expectationWithDescription:@"2"];

  [RTMessageAPI requestAliasAuthentication:RTMockAPIGoodAlias completion:^(NSError *error) {
    XCTAssertEqual(error.code, kErrorCodeAliasInUse);

    [expectation2 fulfill];
  }];

  XCTestExpectation *expectation3 = [self expectationWithDescription:@"3"];

  [RTMessageAPI requestAliasAuthentication:RTMockAPIInvalidAlias completion:^(NSError *error) {
    XCTAssertEqual(error.code, kErrorCodeUnableToAuthenticate);

    [expectation3 fulfill];
  }];

  XCTestExpectation *expectation4 = [self expectationWithDescription:@"4"];

  [RTMessageAPI requestAliasAuthentication:RTMockAPINetworkErrorAlias completion:^(NSError *error) {
    XCTAssertEqual(error.code, kErrorGeneral);

    [expectation4 fulfill];
  }];

  [self waitForExpectationsWithTimeout:5 handler:NULL];
}

-(void) testCheckAliasAuthentication
{
  XCTestExpectation *expectation1 = [self expectationWithDescription:@"1"];

  [RTMessageAPI checkAliasAuthentication:RTMockAPIUnusedAlias pin:@"1234" completion:^(NSError *error) {
    XCTAssertNil(error);

    [expectation1 fulfill];
  }];

  XCTestExpectation *expectation2 = [self expectationWithDescription:@"2"];

  [RTMessageAPI checkAliasAuthentication:RTMockAPIInvalidAlias pin:@"1234" completion:^(NSError *error) {
    XCTAssertEqual(error.code, kErrorCodeInvalidAliasAuhtentication);

    [expectation2 fulfill];
  }];

  XCTestExpectation *expectation3 = [self expectationWithDescription:@"3"];

  [RTMessageAPI checkAliasAuthentication:RTMockAPINetworkErrorAlias pin:@"1234" completion:^(NSError *error) {
    XCTAssertEqual(error.code, kErrorCodeInvalidAliasAuhtentication);

    [expectation3 fulfill];
  }];

  [self waitForExpectationsWithTimeout:5 handler:NULL];
}

-(void) testActivate
{
  [self activate];

  [self flush];

  OCMVerify([_messageAPIWebSocket connect]);
  // _fetchWaitingMessages
  OCMVerify([_messageAPIUserAPI fetchWaiting]);
}

-(void) testActivateChat
{
  RTChat *chat = [_messageAPI loadUserChatForAlias:RTMockAPIGoodOtherAlias
                                        localAlias:RTMockAPIGoodAlias];

  [_messageAPI activateChat:chat];

  [self flush];

  OCMVerify([self activate]);
  // _sendReceiptForChat
  OCMVerify([_messageAPIMessageDAO fetchLatestUnviewedForChat:chat]);
  // _hideNotificationForChat
  OCMVerify([_messageAPINotificationDAO fetchAll:chat]);
}

-(void) testActivateChatWithWaiting
{
  RTChat *chat = [_messageAPI loadUserChatForAlias:RTMockAPIGoodOtherAlias
                                        localAlias:RTMockAPIGoodAlias];

  RTTextMessage *msg = [RTTextMessage new];
  msg.chat = chat;
  msg.text = @"Yo!";

  XCTestExpectation *expectation = [self expectationWithDescription:@"1"];

  XCTAssertTrue([_messageAPI saveMessage:msg]);

  [_messageAPI activateChat:chat];

  [self flush];

  OCMVerify([self activate]);
  // _sendReceiptForChat
  OCMVerify([_messageAPIMessageDAO fetchLatestUnviewedForChat:chat]);
  OCMVerify([_messageAPIMessageDAO viewAllForChat:chat before:[OCMArg any]]);
  // _hideNotificationForChat
  OCMVerify([_messageAPINotificationDAO fetchAll:chat]);
}

-(void) testDeactivate
{
  [self deactivate];

  [self flush];

  OCMVerify([_messageAPI deactivateChat]);
  OCMVerify([_messageAPIWebSocket disconnect]);
}

-(void) testSendMessage
{
  RTTextMessage *msg = [RTTextMessage new];
  msg.chat = [_messageAPI loadUserChatForAlias:RTMockAPIGoodOtherAlias localAlias:RTMockAPIGoodAlias];
  msg.text = @"Yo!";

  XCTAssertTrue([_messageAPI saveMessage:msg]);

  [self flush];

  OCMVerify([_messageAPIMessageDAO insert:msg]);
  OCMVerify([_messageAPIMessageDAO update:msg withStatus:RTMessageStatusSending]);
  OCMVerify([_messageAPIPublicAPI resolveUsers:[OCMArg any]]);
  OCMVerify([_messageAPIUserAPI send:[OCMArg any]]);
  OCMVerify([_messageAPIMessageDAO update:msg withSent:[OCMArg any]]);
  OCMVerify([_messageAPIChatDAO update:msg.chat withLastMessage:msg]);
  OCMVerify([_messageAPIMessageDAO update:msg withStatus:RTMessageStatusSent]);
  XCTAssertNil(msg.updated);
}

-(void) testUpdateMessage
{
  NSDate *sent = [NSDate dateWithTimeIntervalSinceNow:-10];

  RTTextMessage *msg = [RTTextMessage new];
  msg.chat = [_messageAPI loadUserChatForAlias:RTMockAPIGoodOtherAlias localAlias:RTMockAPIGoodAlias];
  msg.sender = msg.chat.localAlias;
  msg.sent = sent;
  msg.updated = nil;
  msg.status = RTMessageStatusSent;
  msg.statusTimestamp = [NSDate dateWithTimeIntervalSinceNow:-10];
  msg.text = @"Yo!";

  [_messageAPIMessageDAO insert:msg];

  XCTAssertTrue([_messageAPI updateMessage:msg]);

  [self flush];

  OCMVerify([_messageAPIMessageDAO update:msg]);
  OCMVerify([_messageAPIMessageDAO update:msg withStatus:RTMessageStatusSending]);
  OCMVerify([_messageAPIPublicAPI resolveUsers:[OCMArg any]]);
  OCMVerify([_messageAPIUserAPI send:[OCMArg any]]);
  OCMVerify([_messageAPIMessageDAO update:msg withStatus:RTMessageStatusSent]);
  XCTAssertEqualObjects(msg.sent, sent);
  XCTAssertNotNil(msg.updated);
}

-(RTMsg *) newMsg
{
  RTMsg *msg = [RTMsg new];
  msg.id = [RTId generate];
  msg.type = MsgType_Text;
  msg.sender = RTMockAPIGoodOtherAlias;
  msg.recipient = RTMockAPIGoodAlias;
  msg.sent = [[NSDate date] timeIntervalSince1970];
  msg.flags = 0;
  return msg;
}

-(RTMsg *) newTxtMsg
{
  RTMsg *msg = [self newMsg];
  msg.key = [_msgCipher randomKey];
  msg.data = [_msgCipher encrypt:[@"Yo!" dataUsingEncoding:NSUTF8StringEncoding] with:msg.key];

  msg.key = [_keyPair encrypt:msg.key];

  return msg;
}

-(void) testReceiveInBackground
{
  RTMsg *msg = [self newTxtMsg];

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:msg];

  [self flush];

  // _saveMsg
  OCMVerify([_messageAPIMessageDAO upsert:[OCMArg any]]);
  OCMVerify([_messageAPIChatDAO update:[OCMArg any] withLastMessage:[OCMArg any]]);
  // _showNotification
  OCMVerify([_messageAPINotificationDAO upsert:[OCMArg any]]);
  XCTAssertEqual([UIApplication sharedApplication].applicationIconBadgeNumber, 1);
  // Other
  XCTAssertEqual(_receivedAlertPlayed, 0);
}

-(void) testReceiveCCInBackground
{
  RTMsg *msg = [self newTxtMsg];
  msg.flags = [RTretxtConstants MsgFlagCC];

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:msg];

  [self flush];

  // _saveMsg
  OCMVerify([_messageAPIMessageDAO upsert:[OCMArg any]]);
  OCMVerify([_messageAPIChatDAO update:[OCMArg any] withLastMessage:[OCMArg any]]);
  // _showNotification (ENSURE WASN'T CALLED)
  XCTAssertEqual([_messageAPINotificationDAO fetchAllMatching:nil].count, 0);
  XCTAssertEqual([UIApplication sharedApplication].applicationIconBadgeNumber, 0);
  // Other
  XCTAssertEqual(_receivedAlertPlayed, 0);
}

-(void) testReceiveInForeground
{
  RTMsg *msg = [self newTxtMsg];

  [self activate];

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:msg];

  [self flush];

  // _saveMsg
  OCMVerify([_messageAPIMessageDAO upsert:[OCMArg any]]);
  OCMVerify([_messageAPIChatDAO update:[OCMArg any] withLastMessage:[OCMArg any]]);
  // _showNotification
  OCMVerify([_messageAPINotificationDAO upsert:[OCMArg any]]);
  XCTAssertEqual([UIApplication sharedApplication].applicationIconBadgeNumber, 1);
  // Other
  XCTAssertEqual(_receivedAlertPlayed, 1);
}

-(void) testReceiveCCInForeground
{
  RTMsg *msg = [self newTxtMsg];
  msg.flags = [RTretxtConstants MsgFlagCC];

  [self activate];

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:msg];

  [self flush];

  // _saveMsg
  OCMVerify([_messageAPIMessageDAO upsert:[OCMArg any]]);
  OCMVerify([_messageAPIChatDAO update:[OCMArg any] withLastMessage:[OCMArg any]]);
  // _showNotification (ENSURE WASN'T CALLED)
  XCTAssertEqual([_messageAPINotificationDAO fetchAllMatching:nil].count, 0);
  XCTAssertEqual([UIApplication sharedApplication].applicationIconBadgeNumber, 0);
  // Other
  XCTAssertEqual(_receivedAlertPlayed, 0);
}

-(void) testReceiveInForegroundCurrentChat
{
  RTMsg *msg = [self newTxtMsg];
  RTChat *chat = [_messageAPI loadUserChatForAlias:msg.sender localAlias:msg.recipient];

  [_messageAPI activateChat:chat];

  [self flush];

  OCMVerify([self activate]);
  // _sendReceiptForChat
  OCMVerify([_messageAPIMessageDAO fetchLatestUnviewedForChat:chat]);
  OCMVerify([_messageAPINotificationDAO fetchAll:chat]);

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:msg];

  [self flush];

  // _saveMsg
  OCMVerify([_messageAPIMessageDAO upsert:[OCMArg any]]);
  OCMVerify([_messageAPIChatDAO update:[OCMArg any] withLastMessage:[OCMArg any]]);
  // _showNotification (ENSURE WASN'T CALLED)
  XCTAssertEqual([_messageAPINotificationDAO fetchAllMatching:nil].count, 0);
  XCTAssertEqual([UIApplication sharedApplication].applicationIconBadgeNumber, 0);
  // Other
  XCTAssertEqual(_receivedAlertPlayed, 1);
}

-(void) testReceiveCCInForegroundCurrentChat
{
  RTMsg *msg = [self newTxtMsg];
  msg.flags = [RTretxtConstants MsgFlagCC];

  RTChat *chat = [_messageAPI loadUserChatForAlias:msg.sender localAlias:msg.recipient];

  [_messageAPI activateChat:chat];

  [self flush];

  OCMVerify([self activate]);
  // _sendReceiptForChat
  OCMVerify([_messageAPIMessageDAO fetchLatestUnviewedForChat:chat]);
  OCMVerify([_messageAPINotificationDAO fetchAll:chat]);

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:msg];

  [self flush];

  // _saveMsg
  OCMVerify([_messageAPIMessageDAO upsert:[OCMArg any]]);
  OCMVerify([_messageAPIChatDAO update:[OCMArg any] withLastMessage:[OCMArg any]]);
  // _showNotification (ENSURE WASN'T CALLED)
  XCTAssertEqual([_messageAPINotificationDAO fetchAllMatching:nil].count, 0);
  XCTAssertEqual([UIApplication sharedApplication].applicationIconBadgeNumber, 0);
  // Other
  XCTAssertEqual(_receivedAlertPlayed, 0);
}

-(void) testReceiveInForegroundOtherChat
{
  RTMsg *msg = [self newTxtMsg];
  RTChat *otherChat = [_messageAPI loadUserChatForAlias:@"other2@guy.com" localAlias:msg.recipient];

  [_messageAPI activateChat:otherChat];

  [self flush];

  OCMVerify([self activate]);
  // _sendReceiptForChat
  OCMVerify([_messageAPIMessageDAO fetchLatestUnviewedForChat:otherChat]);
  OCMVerify([_messageAPINotificationDAO fetchAll:otherChat]);

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:msg];

  [self flush];

  // _saveMsg
  OCMVerify([_messageAPIMessageDAO upsert:[OCMArg any]]);
  OCMVerify([_messageAPIChatDAO update:[OCMArg any] withLastMessage:[OCMArg any]]);
  // _showNotification
  OCMVerify([_messageAPINotificationDAO upsert:[OCMArg any]]);
  XCTAssertEqual([UIApplication sharedApplication].applicationIconBadgeNumber, 1);
  // Other
  XCTAssertEqual(_receivedAlertPlayed, 0);
}

-(void) testReceiveCCInForegroundOtherChat
{
  RTMsg *msg = [self newTxtMsg];
  msg.flags = [RTretxtConstants MsgFlagCC];

  RTChat *chat = [_messageAPI loadUserChatForAlias:msg.sender localAlias:msg.recipient];

  [_messageAPI activateChat:chat];

  [self flush];

  OCMVerify([self activate]);
  // _sendReceiptForChat
  OCMVerify([_messageAPIMessageDAO fetchLatestUnviewedForChat:chat]);
  OCMVerify([_messageAPINotificationDAO fetchAll:chat]);

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:msg];

  [self flush];

  // _saveMsg
  OCMVerify([_messageAPIMessageDAO upsert:[OCMArg any]]);
  OCMVerify([_messageAPIChatDAO update:[OCMArg any] withLastMessage:[OCMArg any]]);
  // _showNotification (ENSURE WASN'T CALLED)
  XCTAssertEqual([_messageAPINotificationDAO fetchAllMatching:nil].count, 0);
  XCTAssertEqual([UIApplication sharedApplication].applicationIconBadgeNumber, 0);
  // Other
  XCTAssertEqual(_receivedAlertPlayed, 0);
}

-(void) testReceiveClarifyForeground
{
  RTMsg *txtMsg = [self newTxtMsg];

  [self activate];

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:txtMsg];

  [self flush];

  RTMsg *viewMsg = [self newMsg];
  viewMsg.id = txtMsg.id;
  viewMsg.type = MsgType_Clarify;

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:viewMsg];

  [self flush];

  // _saveMsg
  OCMVerify([_messageAPIMessageDAO upsert:[OCMArg any]]);
  OCMVerify([_messageAPIMessageDAO update:[OCMArg any] withFlags:RTMessageFlagUnread|RTMessageFlagClarify]);
  OCMVerify([_messageAPIChatDAO update:[OCMArg any] withLastMessage:[OCMArg any]]);
  // _showNotification (ENSURE WASN'T CALLED)
  OCMVerify([_messageAPINotificationDAO upsert:[OCMArg any]]);
  XCTAssertEqual([UIApplication sharedApplication].applicationIconBadgeNumber, 1);
  // Other
  XCTAssertEqual(_receivedAlertPlayed, 2);
}

-(void) testReceiveClarifyForegroundCurrentChat
{
  RTMsg *txtMsg = [self newTxtMsg];

  RTChat *chat = [_messageAPI loadUserChatForAlias:txtMsg.sender localAlias:txtMsg.recipient];

  [_messageAPI activateChat:chat];

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:txtMsg];

  [self flush];

  RTMsg *viewMsg = [self newMsg];
  viewMsg.id = txtMsg.id;
  viewMsg.type = MsgType_Clarify;

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:viewMsg];

  [self flush];

  // _saveMsg
  OCMVerify([_messageAPIMessageDAO upsert:[OCMArg any]]);
  OCMVerify([_messageAPIMessageDAO update:[OCMArg any] withFlags:RTMessageFlagClarify]);
  OCMVerify([_messageAPIChatDAO update:[OCMArg any] withLastMessage:[OCMArg any]]);
  // _showNotification (ENSURE WASN'T CALLED)
  XCTAssertEqual([_messageAPINotificationDAO fetchAllMatching:nil].count, 0);
  XCTAssertEqual([UIApplication sharedApplication].applicationIconBadgeNumber, 0);
  // Other
  XCTAssertEqual(_receivedAlertPlayed, 2);
}

-(void) testReceiveClarifyForegroundOtherChat
{
  RTMsg *txtMsg = [self newTxtMsg];

  RTChat *otherChat = [_messageAPI loadUserChatForAlias:@"other2@guy.com" localAlias:txtMsg.recipient];

  [_messageAPI activateChat:otherChat];

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:txtMsg];

  [self flush];

  RTMsg *viewMsg = [self newMsg];
  viewMsg.id = txtMsg.id;
  viewMsg.type = MsgType_Clarify;

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:viewMsg];

  [self flush];

  // _saveMsg
  OCMVerify([_messageAPIMessageDAO upsert:[OCMArg any]]);
  OCMVerify([_messageAPIMessageDAO update:[OCMArg any] withFlags:RTMessageFlagUnread|RTMessageFlagClarify]);
  OCMVerify([_messageAPIChatDAO update:[OCMArg any] withLastMessage:[OCMArg any]]);
  // _showNotification
  OCMVerify([_messageAPINotificationDAO upsert:[OCMArg any]]);
  XCTAssertEqual([UIApplication sharedApplication].applicationIconBadgeNumber, 1);
  // Other
  XCTAssertEqual(_receivedAlertPlayed, 0);
}

-(void) testReceiveView
{
  RTChat *chat = [_messageAPI loadUserChatForAlias:RTMockAPIGoodOtherAlias localAlias:RTMockAPIGoodAlias];

  RTTextMessage *txtMessage = [RTTextMessage new];
  txtMessage.chat = chat;
  txtMessage.text = @"Yo!";

  [_messageAPI saveMessage:txtMessage];

  RTMsg *msg = [RTMsg new];
  msg.id = txtMessage.id;
  msg.type = MsgType_View;
  msg.sender = RTMockAPIGoodOtherAlias;
  msg.recipient = RTMockAPIGoodAlias;
  msg.sent = [[NSDate date] millisecondsSince1970];
  msg.flags = 0;

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:msg];

  [self flush];

  // _saveMsg
  OCMVerify([_messageAPIMessageDAO update:[OCMArg any] withStatus:RTMessageStatusViewed timestamp:[OCMArg any]]);
  OCMVerify([_messageAPINotificationDAO fetch:msg.id]);
  // _showNotification (ENSURE WASN'T CALLED)
  XCTAssertEqual([_messageAPINotificationDAO fetchAllMatching:nil].count, 0);
  XCTAssertEqual([UIApplication sharedApplication].applicationIconBadgeNumber, 0);
  // Other
  XCTAssertEqual(_receivedAlertPlayed, 0);
}

-(void) testReceiveAndSendView
{
  RTMsg *txtMsg = [self newTxtMsg];

  RTUserChat *chat = [_messageAPI loadUserChatForAlias:txtMsg.sender localAlias:txtMsg.recipient];

  [_messageAPI activateChat:chat];

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:txtMsg];

  [self flush];

//  OCMVerify([_messageAPIUserAPI view:txtMsg.id sender:txtMsg.recipient
//  recipient:txtMsg.sender]);
}

-(void) testReceiveGroup
{
  RTMsg *txtMsg = [self newTxtMsg];
  txtMsg.group = [[RTGroup alloc] initWithChat:[RTId generate] members:(id)RTMockAPIGroupMembers];

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:txtMsg];

  [self flush];
}

-(void) testSendUser
{
  RTUserChat *chat = [_messageAPI loadUserChatForAlias:RTMockAPIGoodOtherAlias localAlias:RTMockAPIGoodAlias];

  RTTextMessage *msg = [RTTextMessage new];
  msg.chat = chat;
  msg.text = @"Yo!";

  [_messageAPI saveMessage:msg];

  [self flush];

  XCTAssertEqualObjects(_lastSentMsgId, msg.id);
  XCTAssertNil(_lastSentMsgChatId);
}

-(void) testSendGroup
{
  RTId *chatId = [RTId generate];
  RTGroupChat *chat = [_messageAPI loadGroupChatForId:chatId
                                              members:RTMockAPIGroupMembers
                                           localAlias:RTMockAPIGoodAlias];

  RTTextMessage *msg = [RTTextMessage new];
  msg.chat = chat;
  msg.text = @"Yo!";

  [_messageAPI saveMessage:msg];

  [self flush];

  XCTAssertEqualObjects(_lastSentMsgId, msg.id);
  XCTAssertEqualObjects(_lastSentMsgChatId, chatId);
}

-(void) testFindMessages
{
  RTChat *chat = [_messageAPI loadUserChatForAlias:RTMockAPIGoodOtherAlias
                                        localAlias:RTMockAPIGoodAlias];
  XCTAssertNotNil(chat);

  RTTextMessage *msg = [RTTextMessage new];
  msg.chat = chat;
  msg.text = @"Some Text!";

  XCTAssertNotNil(chat);

  XCTAssertTrue([_messageAPI saveMessage:msg]);

  [_messageAPI findMessageById:msg.id completion:^(RTMessage *message) {
    XCTAssertNotNil(message);
    XCTAssertEqualObjects(msg, message);
  }];

  [_messageAPI findMessagesMatching:[NSPredicate predicateWithFormat:@"chat = %@", chat] offset:0 limit:0 sortedBy:nil completion:^(NSArray *array) {
    XCTAssertEqual(array.count, 1);
    XCTAssertEqualObjects(array[0], msg);
  }];

  [self flush];
}

-(void) testMessageResultsController
{

  RTChat *chat = [_messageAPI loadUserChatForAlias:RTMockAPIGoodOtherAlias
                                        localAlias:RTMockAPIGoodAlias];
  XCTAssertNotNil(chat);

  RTFetchedResultsController *controller = [_messageAPI fetchMessagesMatching:[NSPredicate predicateWithFormat:@"chat = %@", chat]
                                                                       offset:0
                                                                        limit:0
                                                                     sortedBy:@[]];

  controller.delegate = self;

  [controller execute];

  [self flush];

  RTTextMessage *msg = [RTTextMessage new];
  msg.chat = chat;
  msg.text = @"Some Text!";

  XCTAssertNotNil(msg);

  XCTAssertTrue([_messageAPI saveMessage:msg]);

  [self flush];

  XCTAssertEqual([_inserted countForObject:msg.id], 1);
  XCTAssertEqual([_updated countForObject:msg.id], 3);
}

-(void) testSortedMessageResultsController
{

  RTChat *chat = [_messageAPI loadUserChatForAlias:RTMockAPIGoodOtherAlias
                                        localAlias:RTMockAPIGoodAlias];
  XCTAssertNotNil(chat);

  RTFetchedResultsController *controller = [_messageAPI fetchMessagesMatching:[NSPredicate predicateWithFormat:@"chat = %@", chat]
                                                                       offset:0
                                                                        limit:0
                                                                     sortedBy:@[[NSSortDescriptor sortDescriptorWithKey:@"sent" ascending:YES]]];
  controller.delegate = self;

  [controller execute];

  [self flush];

  RTTextMessage *msg1 = [RTTextMessage new];
  msg1.chat = chat;
  msg1.text = @"Some Text!";

  XCTAssertNotNil(msg1);

  XCTAssertTrue([_messageAPI saveMessage:msg1]);

  RTTextMessage *msg2 = [RTTextMessage new];
  msg2.chat = chat;
  msg2.text = @"Some Text!";

  XCTAssertNotNil(msg2);

  XCTAssertTrue([_messageAPI saveMessage:msg2]);

  [self flush];

  XCTAssertEqual([_inserted countForObject:msg1.id], 1);
  XCTAssertEqual([_updated countForObject:msg1.id], 2);
  XCTAssertEqual([_moved countForObject:msg1.id], 1);
  XCTAssertEqual([_inserted countForObject:msg2.id], 1);
  XCTAssertEqual([_moved countForObject:msg2.id], 1);
}

-(void) controller:(RTFetchedResultsController *)controller
   didChangeObject:(id)object
           atIndex:(NSUInteger)index
     forChangeType:(RTFetchedResultsChangeType)changeType
          newIndex:(NSUInteger)newIndex
{
  switch (changeType) {
  case RTFetchedResultsChangeInsert:
    [_inserted addObject:[object id]];
    break;

  case RTFetchedResultsChangeUpdate:
    [_updated addObject:[object id]];
    break;

  case RTFetchedResultsChangeMove:
    [_moved addObject:[object id]];
    break;

  case RTFetchedResultsChangeDelete:
    [_deleted addObject:[object id]];
    break;

  default:
    break;
  }
}

-(void) messageAPI:(RTMessageAPI *)messageAPI shouldAlertMessageReceived:(RTMessage *)message
{
  _receivedAlertPlayed++;
}

-(void) messageAPI:(RTMessageAPI *)messageAPI shouldAlertMessageSent:(RTMessage *)message
{
  _sendAlertPlayed++;
}

-(id) publicAPIClientMock
{
  id classMock = OCMClassMock([RTPublicAPIClient class]);

  OCMStub([classMock findUser:RTMockAPIGoodAlias]).andReturn(RTMockAPIGoodUserId);
  OCMStub([classMock findUser:RTMockAPIUnusedAlias]).andReturn([RTId null]);
  OCMStub([classMock findUser:RTMockAPINetworkErrorAlias]).andThrow([NSException exceptionWithName:@"RTNetworkError" reason:@"" userInfo:nil]);

  OCMStub([classMock requestAliasAuthentication:RTMockAPIUnusedAlias]);
  OCMStub([classMock requestAliasAuthentication:RTMockAPIInvalidAlias]).andThrow([[RTUnableToAuthenticate alloc] init]);
  OCMStub([classMock requestAliasAuthentication:RTMockAPIGoodAlias]).andThrow([[RTAliasInUse alloc] initWithProblemAlias:RTMockAPIGoodAlias]);
  OCMStub([classMock requestAliasAuthentication:RTMockAPINetworkErrorAlias]).andThrow([NSException exceptionWithName:@"RTNetworkError" reason:@"" userInfo:nil]);

  OCMStub([classMock checkAliasAuthentication:RTMockAPIUnusedAlias pin:@"1234"]).andReturn(YES);
  OCMStub([classMock checkAliasAuthentication:RTMockAPIInvalidAlias pin:@"1234"]).andReturn(NO);
  OCMStub([classMock checkAliasAuthentication:RTMockAPIGoodOtherAlias pin:@"1234"]).andThrow([NSException exceptionWithName:@"RTNetworkError" reason:@"" userInfo:nil]);

  return classMock;
}

-(id) userAPIClientMock:(BOOL)good
{
  id classMock = OCMClassMock([RTUserAPIClient class]);

  if (good) {
    OCMStub([classMock fetchWaiting]).andReturn([NSArray array]);
    OCMStub([classMock resolve:[OCMArg any]]).andReturn(RTMockAPIGroupResolve);
    OCMStub([classMock send:[OCMArg any]]).andDo(^(NSInvocation *inv) {
      RTMsgPack __unsafe_unretained *msg = nil;
      [inv getArgument:&msg atIndex:2];
      _lastSentMsgId = msg.id;
      _lastSentMsgChatId = msg.chat;
    }).andReturn([[NSDate date] millisecondsSince1970]);
  }
  else {
    OCMStub([classMock fetchWaiting]).andThrow([self authenticationException]);
    OCMStub([classMock resolve:[OCMArg any]]).andReturn([NSArray array]);
  }

  return classMock;
}

-(id) webSocketMock
{
  id classMock = OCMClassMock([RTWebSocket class]);
  OCMStub([classMock connect]);
  OCMStub([classMock disconnect]);
  return classMock;
}

-(id) dbManagerMock
{
  id real = [[RTDBManager alloc] initWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"message-api-test.sqlite"]
                                         kind:@"Message" daoClasses:@[[RTChatDAO class], [RTMessageDAO class], [RTNotificationDAO class]]];

  _messageAPIMessageDAO = OCMPartialMock([[RTMessageDAO alloc] initWithDBManager:real]);
  _messageAPIChatDAO = OCMPartialMock([[RTChatDAO alloc] initWithDBManager:real]);
  _messageAPINotificationDAO = OCMPartialMock([[RTNotificationDAO alloc] initWithDBManager:real]);

  id mock = OCMPartialMock(real);
  OCMStub([mock objectForKeyedSubscript:@"Message"]).andReturn(_messageAPIMessageDAO);
  OCMStub([mock objectForKeyedSubscript:@"Chat"]).andReturn(_messageAPIChatDAO);
  OCMStub([mock objectForKeyedSubscript:@"Notification"]).andReturn(_messageAPINotificationDAO);
  return mock;
}

-(id) messageAPIMock
{
  id mockAPI = OCMPartialMock([RTMessageAPI new]);

  OCMStub([mockAPI publicAPIClient]).andReturn(self.messageAPIPublicAPI);
  OCMStub([mockAPI userAPIClientWithUserId:RTMockAPIGoodUserId password:[OCMArg any] deviceId:RTMockAPIGoodDeviceId]).andReturn(self.messageAPIUserAPI);
  OCMStub([mockAPI userAPIClientWithUserId:[OCMArg any] password:[OCMArg any] deviceId:[OCMArg any]]).andReturn(self.messageAPIUserAPIBad);
  OCMStub([mockAPI webSocketWithUserId:[OCMArg any] password:[OCMArg any] deviceId:[OCMArg any]]).andReturn(self.messageAPIWebSocket);
  OCMStub([mockAPI dbManagerWithURL:[OCMArg any]]).andReturn(self.messageAPIDBManager);

  _s_publicAPIClient = [self publicAPIClientMock];
  _s_apiQueue = dispatch_queue_create("io.retxt.message-api[MOCK]", DISPATCH_QUEUE_SERIAL);

  return mockAPI;
}

-(id) authenticationException
{
  TTransportException *e = [[TTransportException alloc] initWithName:@"TTransportException"
                                                              reason:@"Unexpected response"
                                                            userInfo:@{@"error":[NSError errorWithDomain:NSURLErrorDomain
                                                                                                    code:NSURLErrorUserAuthenticationRequired
                                                                                                userInfo:nil]}];
  return e;
}

@end
