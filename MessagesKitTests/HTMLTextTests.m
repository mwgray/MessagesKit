//
//  HTMLTextTests.m
//  MessagesKit
//
//  Created by Kevin Wooten on 5/30/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

#import "HtmlText.h"

#import "Log.h"

@import XCTest;
@import CocoaLumberjack;


CL_DECLARE_LOG_LEVEL()


@interface HTMLTextTests : XCTestCase

@end


@implementation HTMLTextTests

-(void) setUp
{
  [super setUp];
}

-(void) tearDown
{
  [super tearDown];
}

-(void) testParser
{
  NSString *text = @"This <i>is a <b>bold</b> test</i> with a <a href=\"yo:test\">link</a>";

  HTMLTextParser *parser = [HTMLTextParser new];

  NSAttributedString *res = [parser parseWithData:[text dataUsingEncoding:NSUTF8StringEncoding]];
  DDLogDebug(@"Result %@", res);
}

@end
