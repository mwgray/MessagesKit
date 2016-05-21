//
//  SQLBuilderTests.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/14/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "SQLBuilder.h"
#import "Chat.h"
#import "Message.h"
#import "Messages+Exts.h"
#import "Log.h"

@import CocoaLumberjack;


MK_DECLARE_LOG_LEVEL()


@interface SQLBuilderTests : XCTestCase

@end


@implementation SQLBuilderTests

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
  Chat *chat = [Chat new];
  chat.id = [Id generate];

  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"chat.name = %@ AND status < %d AND id IN %@",
                            chat, MessageStatusSent, @[]];

  SQLBuilder *sqlBuilder = [[SQLBuilder alloc] initWithRootClass:@"Message"
                                                          tableNames:@{@"Chat" : @"chat",
                                                                       @"Message" : @"message"}];

  DDLogDebug(@"%@", [sqlBuilder processPredicate:predicate sortedBy:nil offset:0 limit:0]);
}

-(void) testSortedWhereConversion
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"lastMessage.sent > %@", [NSDate date]];

  SQLBuilder *sqlBuilder = [[SQLBuilder alloc] initWithRootClass:@"Chat"
                                                          tableNames:@{@"Chat" : @"chat",
                                                                       @"Message" : @"message"}];

  DDLogDebug(@"%@", [sqlBuilder processPredicate:predicate
                                        sortedBy:@[[NSSortDescriptor sortDescriptorWithKey:@"lastMessage.sent" ascending:NO]]
                                          offset:0
                                           limit:0]);

}

-(void) testIsKindOfClass
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(self isMemberOfClass: %@ OR self isMemberOfClass: %@) AND chat = %@",
                            NSClassFromString(@"ImageMessage"), NSClassFromString(@"VideoMessage"), @(10)];

  SQLBuilder *sqlBuilder = [[SQLBuilder alloc] initWithRootClass:@"Message" tableNames:@{@"Chat" : @"chat",
                                                                                               @"Message" : @"message"}];

  DDLogDebug(@"%@", [sqlBuilder processPredicate:predicate sortedBy:nil offset:0 limit:0]);
}

@end

