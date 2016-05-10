//
//  ChatTests.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/9/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "ChatDAO.h"
#import "UserChat.h"
#import "GroupChat.h"
#import "MessageDAO.h"
#import "TextMessage.h"
#import "Messages+Exts.h"

@import KVOController;
@import YOLOKit;
@import FMDB;


@interface ChatTests : XCTestCase <DBManagerDelegate>

@property (strong, nonatomic) NSString *dbPath;
@property (strong, nonatomic) DBManager *dbManager;
@property (weak, nonatomic) ChatDAO *chatDAO;
@property (weak, nonatomic) MessageDAO *msgDAO;
@property (strong, nonatomic) NSMutableSet *inserted;
@property (strong, nonatomic) NSMutableSet *updated;
@property (strong, nonatomic) NSMutableSet *deleted;

@end


@implementation ChatTests

-(void) setUp
{
  [super setUp];

  self.dbPath = [NSTemporaryDirectory() stringByAppendingString:@"test.sqlite"];
  self.dbManager = [[DBManager alloc] initWithPath:self.dbPath kind:@"Message" daoClasses:@[[MessageDAO class], [ChatDAO class]] error:nil];
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

-(Message *) newMessage
{
  TextMessage *message = [TextMessage new];
  message.id = [Id generate];
  message.sender = @"Me";
  message.sent = [NSDate date];

  return message;
}

-(UserChat *) newUserChat
{
  UserChat *userChat = [UserChat new];
  userChat.id = [Id generate];
  userChat.alias = @"Them";
  userChat.localAlias = @"Me";
  userChat.updatedCount = 13;
  userChat.clarifiedCount = 4;
  userChat.lastMessage = [self newMessage];
  userChat.lastMessage.chat = userChat;

  return userChat;
}

-(GroupChat *) newGroupChat
{
  GroupChat *groupChat = [GroupChat new];
  groupChat.id = [Id generate];
  groupChat.alias = [[Id generate] UUIDString];
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

-(BOOL) compareFetched:(Chat *)chat
{
  XCTAssertTrue([self.chatDAO insertChat:chat error:nil]);
  if (chat.lastMessage) {
    XCTAssertTrue([self.msgDAO insertMessage:chat.lastMessage error:nil]);
  }

  [self.chatDAO clearCache];

  UserChat *chat2 = [self.chatDAO fetchChatWithId:chat.id];

  return [chat isEquivalent:chat2];
}

-(void) testNullLastMessage
{
  Chat *chat = [self newUserChat];
  
  chat.lastMessage = nil;

  [self compareFetched:chat];
}

-(void) testKVO
{
  GroupChat *chat = [self newGroupChat];

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
  
  Id *noId = nil;

  UserChat *chat = [UserChat new];
  chat.id = noId;
  chat.alias = @"test";
  chat.localAlias = @"test2";

  XCTAssertFalse([self.chatDAO insertChat:chat error:nil]);
}

-(void) testUserChat
{
  UserChat *chat = [self newUserChat];

  XCTAssertEqualObjects(chat.activeRecipients, [NSSet setWithArray:@[@"Them"]]);
}

-(void) testGroupChat
{
  GroupChat *chat = [self newGroupChat];

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
  UserChat *userChat = [self newUserChat];

  XCTAssertTrue([self compareFetched:userChat]);
  XCTAssertTrue([_inserted containsObject:userChat.id]);
}

-(void) testGroupChatInsertFetch
{
  GroupChat *groupChat = [self newGroupChat];

  XCTAssertTrue([self compareFetched:groupChat]);
  XCTAssertTrue([_inserted containsObject:groupChat.id]);
}

-(void) testChatDelete
{
  MessageDAO *msgDAO = self.dbManager[@"Message"];

  UserChat *chat = [self newUserChat];

  Message *msg1 = [self newMessage];
  msg1.chat = chat;
  [msgDAO insertMessage:msg1 error:nil];

  Message *msg2 = [self newMessage];
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
  UserChat *chat1 = [self newUserChat];
  UserChat *chat2 = [self newUserChat];
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
  UserChat *chat = [self newUserChat];

  XCTAssertTrue([self.chatDAO insertChat:chat error:nil]);

  [self.chatDAO clearCache];

  UserChat *found;
  [self.chatDAO fetchChatForAlias:chat.alias localAlias:chat.localAlias returning:&found error:nil];
  XCTAssertNotNil(found);
}

-(void) testChatUpdate
{
  UserChat *chat = [self newUserChat];

  XCTAssertTrue([self.chatDAO insertChat:chat error:nil]);
  XCTAssertTrue([self.chatDAO updateChat:chat error:nil]);

  XCTAssertTrue([_updated containsObject:chat.id]);
}

-(void) testChatUpsert
{
  UserChat *chat = [self newUserChat];

  XCTAssertTrue([self.chatDAO upsertChat:chat error:nil]);

  XCTAssertTrue([_inserted containsObject:chat.id]);

  XCTAssertTrue([self.chatDAO upsertChat:chat error:nil]);

  XCTAssertTrue([_updated containsObject:chat.id]);
}

-(void) testChatUpdateAddMember
{
  GroupChat *chat = [self newGroupChat];

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
  GroupChat *chat = [self newGroupChat];

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
  UserChat *chat = [self newUserChat];

  XCTAssertTrue([self.chatDAO insertChat:chat error:nil]);
  XCTAssertTrue([self.msgDAO insertMessage:chat.lastMessage error:nil]);

  XCTAssertTrue([self.chatDAO updateChat:chat withLastMessage:[self newMessage] error:nil]);

  chat.lastMessage.chat = chat;
  XCTAssertTrue([self.msgDAO insertMessage:chat.lastMessage error:nil]);

  [self.chatDAO clearCache];

  XCTAssertTrue([chat isEquivalent:[self.chatDAO fetchChatWithId:chat.id]]);
  XCTAssertTrue([_updated containsObject:chat.id]);
}

-(void) modelObject:(Model *)model insertedInDAO:(DAO *)dao
{
  [_inserted addObject:model.id];
}

-(void) modelObject:(Model *)model updatedInDAO:(DAO *)dao
{
  [_updated addObject:model.id];
}

-(void) modelObject:(Model *)model deletedInDAO:(DAO *)dao
{
  [_deleted addObject:model.id];
}

@end
