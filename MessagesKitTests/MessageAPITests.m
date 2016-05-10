//
//  MessageAPITests.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/12/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <OCMock/OCMock.h>

#import "WebSocket.h"
#import "MessageAPI.h"
#import "DAO+Internal.h"
#import "ChatDAO.h"
#import "MessageDAO.h"
#import "NotificationDAO.h"
#import "FetchedResultsController.h"
#import "TextMessage.h"
#import "TTransportError.h"
#import "MsgCipher.h"
#import "NSDate+Utils.h"
#import "Messages+Exts.h"


NSString *MockAPIGoodAlias = @"test@guy.com";
NSString *MockAPIGoodOtherAlias = @"other@guy.com";
NSString *MockAPIGoodOther2Alias = @"other2@guy.com";
NSString *MockAPIUnusedAlias = @"unused@guy.com";
NSString *MockAPIInvalidAlias = @"guy";
NSString *MockAPINetworkErrorAlias = @"network.error@guy.com";

Id *MockAPIGoodUserId;
Id *MockAPIGoodOtherUserId;
Id *MockAPIGoodOther2UserId;
Id *MockAPIGoodDeviceId;

NSArray *MockAPIGroupMembers;
NSDictionary *MockAPIGroupResolve;


extern PublicAPIClient *_s_publicAPIClient;
extern dispatch_queue_t _s_apiQueue;


@interface MessageAPI (Testing) <WebSocketDelegate>

+(PublicAPIClient *) publicAPIClient;
+(UserAPIClient *) userAPIClientWithUserId:(Id *)userId password:(NSString *)password deviceId:(Id *)deviceId;
+(WebSocket *) webSocketWithUserId:(Id *)userId password:(NSString *)password deviceId:(Id *)deviceId;
+(DBManager *) dbManagerWithURL:(NSURL *)dbURL;

@end


@interface MessageAPITests : XCTestCase <FetchedResultsControllerDelegate, MessageAPIDelegate>

@property (nonatomic, strong) MessageAPI *messageAPI;
@property (nonatomic, strong) MessageAPI *messageAPIBad;
@property (nonatomic, strong) PublicAPIClient *messageAPIPublicAPI;
@property (nonatomic, strong) UserAPIClient *messageAPIUserAPI;
@property (nonatomic, strong) UserAPIClient *messageAPIUserAPIBad;
@property (nonatomic, strong) WebSocket *messageAPIWebSocket;
@property (nonatomic, strong) DBManager *messageAPIDBManager;
@property (nonatomic, strong) MessageDAO *messageAPIMessageDAO;
@property (nonatomic, strong) ChatDAO *messageAPIChatDAO;
@property (nonatomic, strong) NotificationDAO *messageAPINotificationDAO;

@property (nonatomic, strong) MsgCipher *msgCipher;
@property (nonatomic, strong) KeyPair *keyPair;

@property (nonatomic, strong) NSCountedSet *inserted;
@property (nonatomic, strong) NSCountedSet *updated;
@property (nonatomic, strong) NSCountedSet *moved;
@property (nonatomic, strong) NSCountedSet *deleted;
@property (nonatomic, assign) int receivedAlertPlayed;
@property (nonatomic, assign) int sendAlertPlayed;

@property (nonatomic, strong) Id *lastSentMsgId;
@property (nonatomic, strong) Id *lastSentMsgChatId;

@end

@implementation MessageAPITests


+(void) initialize
{
  MockAPIGoodUserId = [Id idWithString:@"BE6F1345-15E5-4DE4-B701-0F30AA8BA6A4"];
  MockAPIGoodOtherUserId = [Id idWithString:@"BCED7524-5510-4F2B-B853-6CD4D903F34D"];
  MockAPIGoodOther2UserId = [Id idWithString:@"89280AD8-BA07-477C-9A1C-1E4188C10009"];
  MockAPIGoodDeviceId = [Id idWithString:@"6E5AD00A-4365-4CB7-A281-E41E2D15E8FB"];
  MockAPIGroupMembers = @[MockAPIGoodOtherAlias, MockAPIGoodOther2Alias, MockAPIGoodAlias];

  KeyPair *keyPair = [KeyPair generateKeyPairWithKeySize:1024];

  MockAPIGroupResolve = @{MockAPIGoodAlias: [[UserInfo alloc] initWithId:MockAPIGoodUserId aliases:[NSMutableSet set] publicKeyData:[keyPair exportPublicKey] verifyKeyData:[keyPair exportPublicKey] eTag:0],
                            MockAPIGoodOtherAlias: [[UserInfo alloc] initWithId:MockAPIGoodOtherUserId aliases:[NSMutableSet set] publicKeyData:[keyPair exportPublicKey] verifyKeyData:[keyPair exportPublicKey] eTag:0],
                            MockAPIGoodOther2Alias: [[UserInfo alloc] initWithId:MockAPIGoodOther2UserId aliases:[NSMutableSet set] publicKeyData:[keyPair exportPublicKey] verifyKeyData:[keyPair exportPublicKey] eTag:0]};
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

  _msgCipher = [MsgCipher new];
  _keyPair = [KeyPair generateKeyPairWithKeySize:2048];

  Credentials *credentials = [Credentials new];
  credentials.userId = MockAPIGoodUserId;
  credentials.password = @"test";
  credentials.deviceId = MockAPIGoodDeviceId;
  credentials.allAliases = @[MockAPIGoodAlias];
  credentials.preferredAlias = MockAPIGoodAlias;
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

  [MessageAPI findUserWithAlias:MockAPIGoodAlias].then(^(Id *userId) {
    XCTAssertEqualObjects(userId, MockAPIGoodUserId);
  })
  .catch(^(NSError *error) {
    XCTAssertNil(error);

    [expectation fulfill];
  });

  XCTestExpectation *expectation2 = [self expectationWithDescription:@"2 findUserWithAlias:completion:"];

  [MessageAPI findUserWithAlias:MockAPIUnusedAlias].then(^(Id *userId) {
    XCTAssertEqualObjects(userId, MockAPIGoodUserId);
  })
  .catch(^(NSError *error) {
    XCTAssertNil(error);

    [expectation2 fulfill];
  });

  XCTestExpectation *expectation3 = [self expectationWithDescription:@"3 findUserWithAlias:completion:"];

  [MessageAPI findUserWithAlias:MockAPINetworkErrorAlias].then(^(Id *userId) {
    XCTAssertEqualObjects(userId, MockAPIGoodUserId);
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

  [MessageAPI requestAliasAuthentication:MockAPIUnusedAlias completion:^(NSError *error) {
    XCTAssertNil(error);

    [expectation1 fulfill];
  }];

  XCTestExpectation *expectation2 = [self expectationWithDescription:@"2"];

  [MessageAPI requestAliasAuthentication:MockAPIGoodAlias completion:^(NSError *error) {
    XCTAssertEqual(error.code, kErrorCodeAliasInUse);

    [expectation2 fulfill];
  }];

  XCTestExpectation *expectation3 = [self expectationWithDescription:@"3"];

  [MessageAPI requestAliasAuthentication:MockAPIInvalidAlias completion:^(NSError *error) {
    XCTAssertEqual(error.code, kErrorCodeUnableToAuthenticate);

    [expectation3 fulfill];
  }];

  XCTestExpectation *expectation4 = [self expectationWithDescription:@"4"];

  [MessageAPI requestAliasAuthentication:MockAPINetworkErrorAlias completion:^(NSError *error) {
    XCTAssertEqual(error.code, kErrorGeneral);

    [expectation4 fulfill];
  }];

  [self waitForExpectationsWithTimeout:5 handler:NULL];
}

-(void) testCheckAliasAuthentication
{
  XCTestExpectation *expectation1 = [self expectationWithDescription:@"1"];

  [MessageAPI checkAliasAuthentication:MockAPIUnusedAlias pin:@"1234" completion:^(NSError *error) {
    XCTAssertNil(error);

    [expectation1 fulfill];
  }];

  XCTestExpectation *expectation2 = [self expectationWithDescription:@"2"];

  [MessageAPI checkAliasAuthentication:MockAPIInvalidAlias pin:@"1234" completion:^(NSError *error) {
    XCTAssertEqual(error.code, kErrorCodeInvalidAliasAuhtentication);

    [expectation2 fulfill];
  }];

  XCTestExpectation *expectation3 = [self expectationWithDescription:@"3"];

  [MessageAPI checkAliasAuthentication:MockAPINetworkErrorAlias pin:@"1234" completion:^(NSError *error) {
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
  Chat *chat = [_messageAPI loadUserChatForAlias:MockAPIGoodOtherAlias
                                        localAlias:MockAPIGoodAlias];

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
  Chat *chat = [_messageAPI loadUserChatForAlias:MockAPIGoodOtherAlias
                                        localAlias:MockAPIGoodAlias];

  TextMessage *msg = [TextMessage new];
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
  TextMessage *msg = [TextMessage new];
  msg.chat = [_messageAPI loadUserChatForAlias:MockAPIGoodOtherAlias localAlias:MockAPIGoodAlias];
  msg.text = @"Yo!";

  XCTAssertTrue([_messageAPI saveMessage:msg]);

  [self flush];

  OCMVerify([_messageAPIMessageDAO insert:msg]);
  OCMVerify([_messageAPIMessageDAO update:msg withStatus:MessageStatusSending]);
  OCMVerify([_messageAPIPublicAPI resolveUsers:[OCMArg any]]);
  OCMVerify([_messageAPIUserAPI send:[OCMArg any]]);
  OCMVerify([_messageAPIMessageDAO update:msg withSent:[OCMArg any]]);
  OCMVerify([_messageAPIChatDAO update:msg.chat withLastMessage:msg]);
  OCMVerify([_messageAPIMessageDAO update:msg withStatus:MessageStatusSent]);
  XCTAssertNil(msg.updated);
}

-(void) testUpdateMessage
{
  NSDate *sent = [NSDate dateWithTimeIntervalSinceNow:-10];

  TextMessage *msg = [TextMessage new];
  msg.chat = [_messageAPI loadUserChatForAlias:MockAPIGoodOtherAlias localAlias:MockAPIGoodAlias];
  msg.sender = msg.chat.localAlias;
  msg.sent = sent;
  msg.updated = nil;
  msg.status = MessageStatusSent;
  msg.statusTimestamp = [NSDate dateWithTimeIntervalSinceNow:-10];
  msg.text = @"Yo!";

  [_messageAPIMessageDAO insert:msg];

  XCTAssertTrue([_messageAPI updateMessage:msg]);

  [self flush];

  OCMVerify([_messageAPIMessageDAO update:msg]);
  OCMVerify([_messageAPIMessageDAO update:msg withStatus:MessageStatusSending]);
  OCMVerify([_messageAPIPublicAPI resolveUsers:[OCMArg any]]);
  OCMVerify([_messageAPIUserAPI send:[OCMArg any]]);
  OCMVerify([_messageAPIMessageDAO update:msg withStatus:MessageStatusSent]);
  XCTAssertEqualObjects(msg.sent, sent);
  XCTAssertNotNil(msg.updated);
}

-(Msg *) newMsg
{
  Msg *msg = [Msg new];
  msg.id = [Id generate];
  msg.type = MsgType_Text;
  msg.sender = MockAPIGoodOtherAlias;
  msg.recipient = MockAPIGoodAlias;
  msg.sent = [[NSDate date] timeIntervalSince1970];
  msg.flags = 0;
  return msg;
}

-(Msg *) newTxtMsg
{
  Msg *msg = [self newMsg];
  msg.key = [_msgCipher randomKey];
  msg.data = [_msgCipher encrypt:[@"Yo!" dataUsingEncoding:NSUTF8StringEncoding] with:msg.key];

  msg.key = [_keyPair encrypt:msg.key];

  return msg;
}

-(void) testReceiveInBackground
{
  Msg *msg = [self newTxtMsg];

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
  Msg *msg = [self newTxtMsg];
  msg.flags = [retxtConstants MsgFlagCC];

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
  Msg *msg = [self newTxtMsg];

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
  Msg *msg = [self newTxtMsg];
  msg.flags = [retxtConstants MsgFlagCC];

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
  Msg *msg = [self newTxtMsg];
  Chat *chat = [_messageAPI loadUserChatForAlias:msg.sender localAlias:msg.recipient];

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
  Msg *msg = [self newTxtMsg];
  msg.flags = [retxtConstants MsgFlagCC];

  Chat *chat = [_messageAPI loadUserChatForAlias:msg.sender localAlias:msg.recipient];

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
  Msg *msg = [self newTxtMsg];
  Chat *otherChat = [_messageAPI loadUserChatForAlias:@"other2@guy.com" localAlias:msg.recipient];

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
  Msg *msg = [self newTxtMsg];
  msg.flags = [retxtConstants MsgFlagCC];

  Chat *chat = [_messageAPI loadUserChatForAlias:msg.sender localAlias:msg.recipient];

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
  Msg *txtMsg = [self newTxtMsg];

  [self activate];

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:txtMsg];

  [self flush];

  Msg *viewMsg = [self newMsg];
  viewMsg.id = txtMsg.id;
  viewMsg.type = MsgType_Clarify;

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:viewMsg];

  [self flush];

  // _saveMsg
  OCMVerify([_messageAPIMessageDAO upsert:[OCMArg any]]);
  OCMVerify([_messageAPIMessageDAO update:[OCMArg any] withFlags:MessageFlagUnread|MessageFlagClarify]);
  OCMVerify([_messageAPIChatDAO update:[OCMArg any] withLastMessage:[OCMArg any]]);
  // _showNotification (ENSURE WASN'T CALLED)
  OCMVerify([_messageAPINotificationDAO upsert:[OCMArg any]]);
  XCTAssertEqual([UIApplication sharedApplication].applicationIconBadgeNumber, 1);
  // Other
  XCTAssertEqual(_receivedAlertPlayed, 2);
}

-(void) testReceiveClarifyForegroundCurrentChat
{
  Msg *txtMsg = [self newTxtMsg];

  Chat *chat = [_messageAPI loadUserChatForAlias:txtMsg.sender localAlias:txtMsg.recipient];

  [_messageAPI activateChat:chat];

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:txtMsg];

  [self flush];

  Msg *viewMsg = [self newMsg];
  viewMsg.id = txtMsg.id;
  viewMsg.type = MsgType_Clarify;

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:viewMsg];

  [self flush];

  // _saveMsg
  OCMVerify([_messageAPIMessageDAO upsert:[OCMArg any]]);
  OCMVerify([_messageAPIMessageDAO update:[OCMArg any] withFlags:MessageFlagClarify]);
  OCMVerify([_messageAPIChatDAO update:[OCMArg any] withLastMessage:[OCMArg any]]);
  // _showNotification (ENSURE WASN'T CALLED)
  XCTAssertEqual([_messageAPINotificationDAO fetchAllMatching:nil].count, 0);
  XCTAssertEqual([UIApplication sharedApplication].applicationIconBadgeNumber, 0);
  // Other
  XCTAssertEqual(_receivedAlertPlayed, 2);
}

-(void) testReceiveClarifyForegroundOtherChat
{
  Msg *txtMsg = [self newTxtMsg];

  Chat *otherChat = [_messageAPI loadUserChatForAlias:@"other2@guy.com" localAlias:txtMsg.recipient];

  [_messageAPI activateChat:otherChat];

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:txtMsg];

  [self flush];

  Msg *viewMsg = [self newMsg];
  viewMsg.id = txtMsg.id;
  viewMsg.type = MsgType_Clarify;

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:viewMsg];

  [self flush];

  // _saveMsg
  OCMVerify([_messageAPIMessageDAO upsert:[OCMArg any]]);
  OCMVerify([_messageAPIMessageDAO update:[OCMArg any] withFlags:MessageFlagUnread|MessageFlagClarify]);
  OCMVerify([_messageAPIChatDAO update:[OCMArg any] withLastMessage:[OCMArg any]]);
  // _showNotification
  OCMVerify([_messageAPINotificationDAO upsert:[OCMArg any]]);
  XCTAssertEqual([UIApplication sharedApplication].applicationIconBadgeNumber, 1);
  // Other
  XCTAssertEqual(_receivedAlertPlayed, 0);
}

-(void) testReceiveView
{
  Chat *chat = [_messageAPI loadUserChatForAlias:MockAPIGoodOtherAlias localAlias:MockAPIGoodAlias];

  TextMessage *txtMessage = [TextMessage new];
  txtMessage.chat = chat;
  txtMessage.text = @"Yo!";

  [_messageAPI saveMessage:txtMessage];

  Msg *msg = [Msg new];
  msg.id = txtMessage.id;
  msg.type = MsgType_View;
  msg.sender = MockAPIGoodOtherAlias;
  msg.recipient = MockAPIGoodAlias;
  msg.sent = [[NSDate date] millisecondsSince1970];
  msg.flags = 0;

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:msg];

  [self flush];

  // _saveMsg
  OCMVerify([_messageAPIMessageDAO update:[OCMArg any] withStatus:MessageStatusViewed timestamp:[OCMArg any]]);
  OCMVerify([_messageAPINotificationDAO fetch:msg.id]);
  // _showNotification (ENSURE WASN'T CALLED)
  XCTAssertEqual([_messageAPINotificationDAO fetchAllMatching:nil].count, 0);
  XCTAssertEqual([UIApplication sharedApplication].applicationIconBadgeNumber, 0);
  // Other
  XCTAssertEqual(_receivedAlertPlayed, 0);
}

-(void) testReceiveAndSendView
{
  Msg *txtMsg = [self newTxtMsg];

  UserChat *chat = [_messageAPI loadUserChatForAlias:txtMsg.sender localAlias:txtMsg.recipient];

  [_messageAPI activateChat:chat];

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:txtMsg];

  [self flush];

//  OCMVerify([_messageAPIUserAPI view:txtMsg.id sender:txtMsg.recipient
//  recipient:txtMsg.sender]);
}

-(void) testReceiveGroup
{
  Msg *txtMsg = [self newTxtMsg];
  txtMsg.group = [[Group alloc] initWithChat:[Id generate] members:(id)MockAPIGroupMembers];

  [_messageAPI webSocket:self.messageAPIWebSocket didReceiveMsgDelivery:txtMsg];

  [self flush];
}

-(void) testSendUser
{
  UserChat *chat = [_messageAPI loadUserChatForAlias:MockAPIGoodOtherAlias localAlias:MockAPIGoodAlias];

  TextMessage *msg = [TextMessage new];
  msg.chat = chat;
  msg.text = @"Yo!";

  [_messageAPI saveMessage:msg];

  [self flush];

  XCTAssertEqualObjects(_lastSentMsgId, msg.id);
  XCTAssertNil(_lastSentMsgChatId);
}

-(void) testSendGroup
{
  Id *chatId = [Id generate];
  GroupChat *chat = [_messageAPI loadGroupChatForId:chatId
                                              members:MockAPIGroupMembers
                                           localAlias:MockAPIGoodAlias];

  TextMessage *msg = [TextMessage new];
  msg.chat = chat;
  msg.text = @"Yo!";

  [_messageAPI saveMessage:msg];

  [self flush];

  XCTAssertEqualObjects(_lastSentMsgId, msg.id);
  XCTAssertEqualObjects(_lastSentMsgChatId, chatId);
}

-(void) testFindMessages
{
  Chat *chat = [_messageAPI loadUserChatForAlias:MockAPIGoodOtherAlias
                                        localAlias:MockAPIGoodAlias];
  XCTAssertNotNil(chat);

  TextMessage *msg = [TextMessage new];
  msg.chat = chat;
  msg.text = @"Some Text!";

  XCTAssertNotNil(chat);

  XCTAssertTrue([_messageAPI saveMessage:msg]);

  [_messageAPI findMessageById:msg.id completion:^(Message *message) {
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

  Chat *chat = [_messageAPI loadUserChatForAlias:MockAPIGoodOtherAlias
                                        localAlias:MockAPIGoodAlias];
  XCTAssertNotNil(chat);

  FetchedResultsController *controller = [_messageAPI fetchMessagesMatching:[NSPredicate predicateWithFormat:@"chat = %@", chat]
                                                                       offset:0
                                                                        limit:0
                                                                     sortedBy:@[]];

  controller.delegate = self;

  [controller execute];

  [self flush];

  TextMessage *msg = [TextMessage new];
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

  Chat *chat = [_messageAPI loadUserChatForAlias:MockAPIGoodOtherAlias
                                        localAlias:MockAPIGoodAlias];
  XCTAssertNotNil(chat);

  FetchedResultsController *controller = [_messageAPI fetchMessagesMatching:[NSPredicate predicateWithFormat:@"chat = %@", chat]
                                                                       offset:0
                                                                        limit:0
                                                                     sortedBy:@[[NSSortDescriptor sortDescriptorWithKey:@"sent" ascending:YES]]];
  controller.delegate = self;

  [controller execute];

  [self flush];

  TextMessage *msg1 = [TextMessage new];
  msg1.chat = chat;
  msg1.text = @"Some Text!";

  XCTAssertNotNil(msg1);

  XCTAssertTrue([_messageAPI saveMessage:msg1]);

  TextMessage *msg2 = [TextMessage new];
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

-(void) controller:(FetchedResultsController *)controller
   didChangeObject:(id)object
           atIndex:(NSUInteger)index
     forChangeType:(FetchedResultsChangeType)changeType
          newIndex:(NSUInteger)newIndex
{
  switch (changeType) {
  case FetchedResultsChangeInsert:
    [_inserted addObject:[object id]];
    break;

  case FetchedResultsChangeUpdate:
    [_updated addObject:[object id]];
    break;

  case FetchedResultsChangeMove:
    [_moved addObject:[object id]];
    break;

  case FetchedResultsChangeDelete:
    [_deleted addObject:[object id]];
    break;

  default:
    break;
  }
}

-(void) messageAPI:(MessageAPI *)messageAPI shouldAlertMessageReceived:(Message *)message
{
  _receivedAlertPlayed++;
}

-(void) messageAPI:(MessageAPI *)messageAPI shouldAlertMessageSent:(Message *)message
{
  _sendAlertPlayed++;
}

-(id) publicAPIClientMock
{
  id classMock = OCMClassMock([PublicAPIClient class]);

  OCMStub([classMock findUser:MockAPIGoodAlias]).andReturn(MockAPIGoodUserId);
  OCMStub([classMock findUser:MockAPIUnusedAlias]).andReturn([Id null]);
  OCMStub([classMock findUser:MockAPINetworkErrorAlias]).andThrow([NSException exceptionWithName:@"NetworkError" reason:@"" userInfo:nil]);

  OCMStub([classMock requestAliasAuthentication:MockAPIUnusedAlias]);
  OCMStub([classMock requestAliasAuthentication:MockAPIInvalidAlias]).andThrow([[UnableToAuthenticate alloc] init]);
  OCMStub([classMock requestAliasAuthentication:MockAPIGoodAlias]).andThrow([[AliasInUse alloc] initWithProblemAlias:MockAPIGoodAlias]);
  OCMStub([classMock requestAliasAuthentication:MockAPINetworkErrorAlias]).andThrow([NSException exceptionWithName:@"NetworkError" reason:@"" userInfo:nil]);

  OCMStub([classMock checkAliasAuthentication:MockAPIUnusedAlias pin:@"1234"]).andReturn(YES);
  OCMStub([classMock checkAliasAuthentication:MockAPIInvalidAlias pin:@"1234"]).andReturn(NO);
  OCMStub([classMock checkAliasAuthentication:MockAPIGoodOtherAlias pin:@"1234"]).andThrow([NSException exceptionWithName:@"NetworkError" reason:@"" userInfo:nil]);

  return classMock;
}

-(id) userAPIClientMock:(BOOL)good
{
  id classMock = OCMClassMock([UserAPIClient class]);

  if (good) {
    OCMStub([classMock fetchWaiting]).andReturn([NSArray array]);
    OCMStub([classMock resolve:[OCMArg any]]).andReturn(MockAPIGroupResolve);
    OCMStub([classMock send:[OCMArg any]]).andDo(^(NSInvocation *inv) {
      MsgPack __unsafe_unretained *msg = nil;
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
  id classMock = OCMClassMock([WebSocket class]);
  OCMStub([classMock connect]);
  OCMStub([classMock disconnect]);
  return classMock;
}

-(id) dbManagerMock
{
  id real = [[DBManager alloc] initWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"message-api-test.sqlite"]
                                         kind:@"Message" daoClasses:@[[ChatDAO class], [MessageDAO class], [NotificationDAO class]]];

  _messageAPIMessageDAO = OCMPartialMock([[MessageDAO alloc] initWithDBManager:real]);
  _messageAPIChatDAO = OCMPartialMock([[ChatDAO alloc] initWithDBManager:real]);
  _messageAPINotificationDAO = OCMPartialMock([[NotificationDAO alloc] initWithDBManager:real]);

  id mock = OCMPartialMock(real);
  OCMStub([mock objectForKeyedSubscript:@"Message"]).andReturn(_messageAPIMessageDAO);
  OCMStub([mock objectForKeyedSubscript:@"Chat"]).andReturn(_messageAPIChatDAO);
  OCMStub([mock objectForKeyedSubscript:@"Notification"]).andReturn(_messageAPINotificationDAO);
  return mock;
}

-(id) messageAPIMock
{
  id mockAPI = OCMPartialMock([MessageAPI new]);

  OCMStub([mockAPI publicAPIClient]).andReturn(self.messageAPIPublicAPI);
  OCMStub([mockAPI userAPIClientWithUserId:MockAPIGoodUserId password:[OCMArg any] deviceId:MockAPIGoodDeviceId]).andReturn(self.messageAPIUserAPI);
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
