//
//  RTSQLBuilderTests.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/14/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RTSQLBuilder.h"
#import "RTChat.h"
#import "RTMessage.h"
#import "RTMessages+Exts.h"
#import "RTLog.h"

@import CocoaLumberjack;


RT_LUMBERJACK_DECLARE_LOG_LEVEL()


@interface RTSQLBuilderTests : XCTestCase

@end


@implementation RTSQLBuilderTests

-(void) setUp
{
  [super setUp];
}

-(void) tearDown
{
  [super tearDown];
}

-(void) testWhereConversion
{
  RTChat *chat = [RTChat new];
  chat.id = [RTId generate];

  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"chat.name = %@ AND status < %d AND id IN %@",
                            chat, RTMessageStatusSent, @[]];

  RTSQLBuilder *sqlBuilder = [[RTSQLBuilder alloc] initWithRootClass:@"RTMessage"
                                                          tableNames:@{@"RTChat" : @"chat",
                                                                       @"RTMessage" : @"message"}];

  DDLogDebug(@"%@", [sqlBuilder processPredicate:predicate sortedBy:nil offset:0 limit:0]);
}

-(void) testSortedWhereConversion
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"lastMessage.sent > %@", [NSDate date]];

  RTSQLBuilder *sqlBuilder = [[RTSQLBuilder alloc] initWithRootClass:@"RTChat"
                                                          tableNames:@{@"RTChat" : @"chat",
                                                                       @"RTMessage" : @"message"}];

  DDLogDebug(@"%@", [sqlBuilder processPredicate:predicate
                                        sortedBy:@[[NSSortDescriptor sortDescriptorWithKey:@"lastMessage.sent" ascending:NO]]
                                          offset:0
                                           limit:0]);

}

-(void) testIsKindOfClass
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(self isMemberOfClass: %@ OR self isMemberOfClass: %@) AND chat = %@",
                            NSClassFromString(@"RTImageMessage"), NSClassFromString(@"RTVideoMessage"), @(10)];

  RTSQLBuilder *sqlBuilder = [[RTSQLBuilder alloc] initWithRootClass:@"RTMessage" tableNames:@{@"RTChat" : @"chat",
                                                                                               @"RTMessage" : @"message"}];

  DDLogDebug(@"%@", [sqlBuilder processPredicate:predicate sortedBy:nil offset:0 limit:0]);
}

@end

