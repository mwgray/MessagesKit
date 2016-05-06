//
//  RTNotificationTests.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/11/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RTNotificationDAO.h"
#import "RTMessages+Exts.h"


@interface RTNotificationTests : XCTestCase <RTDBManagerDelegate>

@property (nonatomic, strong) RTDBManager *dbManager;
@property (nonatomic, weak) RTNotificationDAO *dao;
@property (strong, nonatomic) NSMutableSet *inserted;
@property (strong, nonatomic) NSMutableSet *updated;
@property (strong, nonatomic) NSMutableSet *deleted;

@end

@implementation RTNotificationTests

-(void) setUp
{
  [super setUp];

  NSString *dbPath = [NSTemporaryDirectory() stringByAppendingString:@"temp.sqlite"];
  [[NSFileManager defaultManager] removeItemAtPath:dbPath error:nil];

  self.dbManager = [[RTDBManager alloc] initWithPath:dbPath kind:@"Message" daoClasses:@[[RTNotificationDAO class]] error:nil];
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
  RTId *chatId = [RTId generate];

  RTNotification *not1 = [RTNotification new];
  not1.msgId = [RTId generate];
  not1.chatId = chatId;

  RTNotification *not2 = [RTNotification new];
  not2.msgId = [RTId generate];
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
  RTNotification *not = [RTNotification new];
  not.msgId = [RTId generate];
  not.chatId = [RTId generate];
  not.data = [NSData data];

  XCTAssertTrue([self.dao insertNotification:not error:nil]);
  XCTAssertTrue([_inserted containsObject:not.id]);
  XCTAssertTrue([not isEquivalent:[self.dao fetchNotificationWithId:not.id]]);
}

-(void) testNotificationUpdate
{
  RTNotification *not = [RTNotification new];
  not.msgId = [RTId generate];
  not.chatId = [RTId generate];
  not.data = [NSData data];

  XCTAssertTrue([self.dao insertNotification:not error:nil]);

  not.chatId = [RTId generate];
  not.data = [NSData data];

  XCTAssertTrue([self.dao updateNotification:not error:nil]);
  XCTAssertTrue([_updated containsObject:not.id]);
  XCTAssertTrue([not isEqual:[self.dao fetchNotificationWithId:not.id]]);
}

-(void) testNotificationUpsert
{
  RTNotification *not = [RTNotification new];
  not.msgId = [RTId generate];
  not.chatId = [RTId generate];
  not.data = [NSData data];

  XCTAssertTrue([self.dao upsertNotification:not error:nil]);

  XCTAssertTrue([_inserted containsObject:not.id]);

  XCTAssertTrue([self.dao upsertNotification:not error:nil]);

  XCTAssertTrue([_updated containsObject:not.id]);
}

-(void) testNotificationDelete
{
  RTNotification *not = [RTNotification new];
  not.msgId = [RTId generate];
  not.chatId = [RTId generate];
  not.data = [NSData data];

  XCTAssertTrue([self.dao insertNotification:not error:nil]);
  XCTAssertTrue([self.dao deleteNotification:not error:nil]);
  XCTAssertTrue([_deleted containsObject:not.id]);
  XCTAssertNil([self.dao fetchNotificationWithId:not.id]);
}

-(void) testNotificationDeleteAll
{
  RTNotification *not1 = [RTNotification new];
  not1.msgId = [RTId generate];
  not1.chatId = [RTId generate];
  not1.data = [NSData data];

  RTNotification *not2 = [RTNotification new];
  not2.msgId = [RTId generate];
  not2.chatId = [RTId generate];
  not2.data = [NSData data];

  NSArray *all = @[not1, not2];

  XCTAssertTrue([self.dao insertNotification:not1 error:nil]);
  XCTAssertTrue([self.dao insertNotification:not2 error:nil]);
  XCTAssertTrue([self.dao deleteAllNotificationsInArray:all error:nil]);
  XCTAssertTrue([_deleted containsObject:not1.id]);
  XCTAssertTrue([_deleted containsObject:not2.id]);
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
