//
//  RTChatTests.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/9/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RTChatDAO.h"
#import "RTUserChat.h"
#import "RTGroupChat.h"
#import "RTMessageDAO.h"
#import "RTTextMessage.h"
#import "RTMessages+Exts.h"

@import KVOController;
@import YOLOKit;
@import FMDB;


@interface RTChatTests : XCTestCase <RTDBManagerDelegate>

@property (strong, nonatomic) NSString *dbPath;
@property (strong, nonatomic) RTDBManager *dbManager;
@property (weak, nonatomic) RTChatDAO *chatDAO;
@property (weak, nonatomic) RTMessageDAO *msgDAO;
@property (strong, nonatomic) NSMutableSet *inserted;
@property (strong, nonatomic) NSMutableSet *updated;
@property (strong, nonatomic) NSMutableSet *deleted;

@end


@implementation RTChatTests

-(void) setUp
{
  [super setUp];

  self.dbPath = [NSTemporaryDirectory() stringByAppendingString:@"test.sqlite"];
  self.dbManager = [[RTDBManager alloc] initWithPath:self.dbPath kind:@"Message" daoClasses:@[[RTMessageDAO class], [RTChatDAO class]] error:nil];
  [self.dbManager addDelegatesObject:self];

  self.chatDAO = self.dbManager[@"Chat"];
  self.msgDAO = self.dbManager[@"Message"];

  self.inserted = [NSMutableSet set];
  self.updated = [NSMutableSet set];
  self.deleted = [NSMutableSet set];
}

-(void) tearDown
{
  self.dbManager = nil;

  [[NSFileManager defaultManager] removeItemAtPath:self.dbPath error:nil];
  
  [super tearDown];
}

-(RTMessage *) newMessage
{
  RTTextMessage *message = [RTTextMessage new];
  message.id = [RTId generate];
  message.sender = @"Me";
  message.sent = [NSDate date];

  return message;
}

-(RTUserChat *) newUserChat
{
  RTUserChat *userChat = [RTUserChat new];
  userChat.id = [RTId generate];
  userChat.alias = @"Them";
  userChat.localAlias = @"Me";
  userChat.updatedCount = 13;
  userChat.clarifiedCount = 4;
  userChat.lastMessage = [self newMessage];
  userChat.lastMessage.chat = userChat;

  return userChat;
}

-(RTGroupChat *) newGroupChat
{
  RTGroupChat *groupChat = [RTGroupChat new];
  groupChat.id = [RTId generate];
  groupChat.alias = [[RTId generate] UUIDString];
  groupChat.localAlias = @"Me";
  groupChat.updatedCount = 10;
  groupChat.clarifiedCount = 3;
  groupChat.lastMessage = [self newMessage];
  groupChat.lastMessage.chat = groupChat;
  groupChat.customTitle = @"My Chat";
  groupChat.activeMembers = [NSSet setWithObjects:@"One", @"Two", @"Three", @"Me", nil];
  groupChat.members = [NSSet setWithObjects:@"One", @"Two", @"Three", @"Me", nil];

  return groupChat;
}

-(BOOL) compareFetched:(RTChat *)chat
{
  XCTAssertTrue([self.chatDAO insertChat:chat error:nil]);
  if (chat.lastMessage) {
    XCTAssertTrue([self.msgDAO insertMessage:chat.lastMessage error:nil]);
  }

  [self.chatDAO clearCache];

  RTUserChat *chat2 = [self.chatDAO fetchChatWithId:chat.id];

  return [chat isEquivalent:chat2];
}

-(void) testNullLastMessage
{
  RTChat *chat = [self newUserChat];
  
  chat.lastMessage = nil;

  [self compareFetched:chat];
}

-(void) testKVO
{
  RTGroupChat *chat = [self newGroupChat];

  FBKVOController *kvoController = [FBKVOController controllerWithObserver:self];

  __block BOOL received = NO;

  [kvoController observe:chat keyPath:@"members" options:NSKeyValueObservingOptionNew block:^(id observer, id object, NSDictionary *change) {
    received = YES;
  }];

  chat.members = [NSSet set];

  kvoController = nil;

  XCTAssertTrue(received);
}

-(void) testInvalidInsert
{
  [_dbManager.pool inWritableDatabase:^(FMDatabase * _Nonnull db) {
    db.logsErrors = NO;
  }];
  
  RTId *noId = nil;

  RTUserChat *chat = [RTUserChat new];
  chat.id = noId;
  chat.alias = @"test";
  chat.localAlias = @"test2";

  XCTAssertFalse([self.chatDAO insertChat:chat error:nil]);
}

-(void) testUserChat
{
  RTUserChat *chat = [self newUserChat];

  XCTAssertEqualObjects(chat.activeRecipients, [NSSet setWithArray:@[@"Them"]]);
}

-(void) testGroupChat
{
  RTGroupChat *chat = [self newGroupChat];

  NSSet *members = [NSSet setWithArray:@[@"One", @"Two", @"Three", @"Me"]];

  XCTAssertEqualObjects(chat.activeRecipients, members.without(chat.localAlias));
  XCTAssertEqualObjects(chat.allRecipients, members.without(chat.localAlias));
  XCTAssertEqualObjects(chat.members, members);
  XCTAssertEqualObjects(chat.activeMembers, members);
  XCTAssertTrue(chat.includesMe);

  chat.activeMembers = chat.activeMembers.without(chat.localAlias);

  XCTAssertEqualObjects(chat.activeRecipients, members.without(chat.localAlias));
  XCTAssertEqualObjects(chat.activeMembers, members.without(chat.localAlias));
  XCTAssertEqualObjects(chat.members, members);
  XCTAssertFalse(chat.includesMe);
}

-(void) testUserChatInsertFetch
{
  RTUserChat *userChat = [self newUserChat];

  XCTAssertTrue([self compareFetched:userChat]);
  XCTAssertTrue([_inserted containsObject:userChat.id]);
}

-(void) testGroupChatInsertFetch
{
  RTGroupChat *groupChat = [self newGroupChat];

  XCTAssertTrue([self compareFetched:groupChat]);
  XCTAssertTrue([_inserted containsObject:groupChat.id]);
}

-(void) testChatDelete
{
  RTMessageDAO *msgDAO = self.dbManager[@"Message"];

  RTUserChat *chat = [self newUserChat];

  RTMessage *msg1 = [self newMessage];
  msg1.chat = chat;
  [msgDAO insertMessage:msg1 error:nil];

  RTMessage *msg2 = [self newMessage];
  msg2.chat = chat;
  [msgDAO insertMessage:msg2 error:nil];

  XCTAssertTrue([self.chatDAO insertChat:chat error:nil]);
  XCTAssertTrue([self.chatDAO deleteChat:chat error:nil]);

  XCTAssertNil([self.chatDAO fetchChatWithId:chat.id]);
  XCTAssertTrue([_deleted containsObject:chat.id]);
  XCTAssertNil([msgDAO fetchMessageWithId:msg1.id]);
  XCTAssertNil([msgDAO fetchMessageWithId:msg2.id]);
}

-(void) testChatDeleteAll
{
  RTUserChat *chat1 = [self newUserChat];
  RTUserChat *chat2 = [self newUserChat];
  NSArray *all = @[chat1, chat2];

  XCTAssertTrue([self.chatDAO insertChat:chat1 error:nil]);
  XCTAssertTrue([self.msgDAO insertMessage:chat1.lastMessage error:nil]);
  XCTAssertTrue([self.chatDAO insertChat:chat2 error:nil]);
  XCTAssertTrue([self.msgDAO insertMessage:chat2.lastMessage error:nil]);
  XCTAssertTrue([self.chatDAO deleteAllChatsInArray:all error:nil]);

  XCTAssertNil([self.chatDAO fetchChatWithId:chat1.id]);
  XCTAssertNil([self.chatDAO fetchChatWithId:chat2.id]);
  XCTAssertTrue([_deleted containsObject:chat1.id]);
  XCTAssertTrue([_deleted containsObject:chat2.id]);
}

-(void) testChatFetchByAliases
{
  RTUserChat *chat = [self newUserChat];

  XCTAssertTrue([self.chatDAO insertChat:chat error:nil]);

  [self.chatDAO clearCache];

  RTUserChat *found;
  [self.chatDAO fetchChatForAlias:chat.alias localAlias:chat.localAlias returning:&found error:nil];
  XCTAssertNotNil(found);
}

-(void) testChatUpdate
{
  RTUserChat *chat = [self newUserChat];

  XCTAssertTrue([self.chatDAO insertChat:chat error:nil]);
  XCTAssertTrue([self.chatDAO updateChat:chat error:nil]);

  XCTAssertTrue([_updated containsObject:chat.id]);
}

-(void) testChatUpsert
{
  RTUserChat *chat = [self newUserChat];

  XCTAssertTrue([self.chatDAO upsertChat:chat error:nil]);

  XCTAssertTrue([_inserted containsObject:chat.id]);

  XCTAssertTrue([self.chatDAO upsertChat:chat error:nil]);

  XCTAssertTrue([_updated containsObject:chat.id]);
}

-(void) testChatUpdateAddMember
{
  RTGroupChat *chat = [self newGroupChat];

  XCTAssertTrue([self.chatDAO insertChat:chat error:nil]);
  XCTAssertTrue([self.msgDAO insertMessage:chat.lastMessage error:nil]);

  XCTAssertTrue([self.chatDAO updateChat:chat addGroupMember:@"New" error:nil]);
  XCTAssertTrue([chat.members containsObject:@"New"]);
  XCTAssertTrue([chat.activeMembers containsObject:@"New"]);

  XCTAssertTrue([chat.activeRecipients containsObject:@"New"]);
  XCTAssertTrue([chat.allRecipients containsObject:@"New"]);

  [self.chatDAO clearCache];

  XCTAssertTrue([chat isEquivalent:[self.chatDAO fetchChatWithId:chat.id]]);
  XCTAssertTrue([_updated containsObject:chat.id]);
}

-(void) testChatUpdateRemoveMember
{
  RTGroupChat *chat = [self newGroupChat];

  XCTAssertTrue([self.chatDAO insertChat:chat error:nil]);
  XCTAssertTrue([self.msgDAO insertMessage:chat.lastMessage error:nil]);

  XCTAssertTrue([self.chatDAO updateChat:chat removeGroupMember:@"Me" error:nil]);

  XCTAssertFalse([chat.activeRecipients containsObject:@"Me"]);
  XCTAssertFalse([chat.allRecipients containsObject:@"Me"]);
  XCTAssertTrue([chat.members containsObject:@"Me"]);
  XCTAssertFalse([chat.activeMembers containsObject:@"Me"]);

  [self.chatDAO clearCache];

  XCTAssertTrue([chat isEquivalent:[self.chatDAO fetchChatWithId:chat.id]]);
  XCTAssertTrue([_updated containsObject:chat.id]);
}

-(void) testChatUpdateLastMessage
{
  RTUserChat *chat = [self newUserChat];

  XCTAssertTrue([self.chatDAO insertChat:chat error:nil]);
  XCTAssertTrue([self.msgDAO insertMessage:chat.lastMessage error:nil]);

  XCTAssertTrue([self.chatDAO updateChat:chat withLastMessage:[self newMessage] error:nil]);

  chat.lastMessage.chat = chat;
  XCTAssertTrue([self.msgDAO insertMessage:chat.lastMessage error:nil]);

  [self.chatDAO clearCache];

  XCTAssertTrue([chat isEquivalent:[self.chatDAO fetchChatWithId:chat.id]]);
  XCTAssertTrue([_updated containsObject:chat.id]);
}

-(void) modelObject:(RTModel *)model insertedInDAO:(RTDAO *)dao
{
  [_inserted addObject:model.id];
}

-(void) modelObject:(RTModel *)model updatedInDAO:(RTDAO *)dao
{
  [_updated addObject:model.id];
}

-(void) modelObject:(RTModel *)model deletedInDAO:(RTDAO *)dao
{
  [_deleted addObject:model.id];
}

@end
