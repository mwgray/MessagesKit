//
//  NotificationTests.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/11/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "NotificationDAO.h"
#import "Messages+Exts.h"


@interface NotificationTests : XCTestCase <DBManagerDelegate>

@property (nonatomic, strong) DBManager *dbManager;
@property (nonatomic, weak) NotificationDAO *dao;
@property (strong, nonatomic) NSMutableSet *inserted;
@property (strong, nonatomic) NSMutableSet *updated;
@property (strong, nonatomic) NSMutableSet *deleted;

@end

@implementation NotificationTests

-(void) setUp
{
  [super setUp];

  NSString *dbPath = [NSTemporaryDirectory() stringByAppendingString:@"temp.sqlite"];
  [[NSFileManager defaultManager] removeItemAtPath:dbPath error:nil];

  self.dbManager = [[DBManager alloc] initWithPath:dbPath kind:@"Message" daoClasses:@[[NotificationDAO class]] error:nil];
  [self.dbManager addDelegatesObject:self];

  self.dao = self.dbManager[@"Notification"];

  self.inserted = [NSMutableSet new];
  self.updated = [NSMutableSet new];
  self.deleted = [NSMutableSet new];
}

-(void) tearDown
{
  self.dbManager = nil;

  [super tearDown];
}

-(void) testNotificationFetchAll
{
  Id *chatId = [Id generate];

  Notification *not1 = [Notification new];
  not1.msgId = [Id generate];
  not1.chatId = chatId;

  Notification *not2 = [Notification new];
  not2.msgId = [Id generate];
  not2.chatId = chatId;

  XCTAssertTrue([self.dao insertNotification:not1 error:nil]);
  XCTAssertTrue([self.dao insertNotification:not2 error:nil]);

  NSArray *all1 = [self.dao fetchAllNotificationsMatching:nil parameters:nil error:nil];
  XCTAssertEqual(all1.count, 2);

  NSArray *all2 = [self.dao fetchAllNotificationsMatching:@"chatId = ?" parameters:@[chatId] error:nil];
  XCTAssertEqual(all2.count, 2);
}

-(void) testNotificationInsertFetch
{
  Notification *not = [Notification new];
  not.msgId = [Id generate];
  not.chatId = [Id generate];
  not.data = [NSData data];

  XCTAssertTrue([self.dao insertNotification:not error:nil]);
  XCTAssertTrue([_inserted containsObject:not.id]);
  XCTAssertTrue([not isEquivalent:[self.dao fetchNotificationWithId:not.id]]);
}

-(void) testNotificationUpdate
{
  Notification *not = [Notification new];
  not.msgId = [Id generate];
  not.chatId = [Id generate];
  not.data = [NSData data];

  XCTAssertTrue([self.dao insertNotification:not error:nil]);

  not.chatId = [Id generate];
  not.data = [NSData data];

  XCTAssertTrue([self.dao updateNotification:not error:nil]);
  XCTAssertTrue([_updated containsObject:not.id]);
  XCTAssertTrue([not isEqual:[self.dao fetchNotificationWithId:not.id]]);
}

-(void) testNotificationUpsert
{
  Notification *not = [Notification new];
  not.msgId = [Id generate];
  not.chatId = [Id generate];
  not.data = [NSData data];

  XCTAssertTrue([self.dao upsertNotification:not error:nil]);

  XCTAssertTrue([_inserted containsObject:not.id]);

  XCTAssertTrue([self.dao upsertNotification:not error:nil]);

  XCTAssertTrue([_updated containsObject:not.id]);
}

-(void) testNotificationDelete
{
  Notification *not = [Notification new];
  not.msgId = [Id generate];
  not.chatId = [Id generate];
  not.data = [NSData data];

  XCTAssertTrue([self.dao insertNotification:not error:nil]);
  XCTAssertTrue([self.dao deleteNotification:not error:nil]);
  XCTAssertTrue([_deleted containsObject:not.id]);
  XCTAssertNil([self.dao fetchNotificationWithId:not.id]);
}

-(void) testNotificationDeleteAll
{
  Notification *not1 = [Notification new];
  not1.msgId = [Id generate];
  not1.chatId = [Id generate];
  not1.data = [NSData data];

  Notification *not2 = [Notification new];
  not2.msgId = [Id generate];
  not2.chatId = [Id generate];
  not2.data = [NSData data];

  NSArray *all = @[not1, not2];

  XCTAssertTrue([self.dao insertNotification:not1 error:nil]);
  XCTAssertTrue([self.dao insertNotification:not2 error:nil]);
  XCTAssertTrue([self.dao deleteAllNotificationsInArray:all error:nil]);
  XCTAssertTrue([_deleted containsObject:not1.id]);
  XCTAssertTrue([_deleted containsObject:not2.id]);
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
