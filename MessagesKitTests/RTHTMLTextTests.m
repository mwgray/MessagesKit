//
//  RTHTMLTextTests.m
//  MessagesKit
//
//  Created by Kevin Wooten on 5/30/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTHtmlText.h"

#import "RTLog.h"

@import XCTest;
@import CocoaLumberjack;


RT_LUMBERJACK_DECLARE_LOG_LEVEL()


@interface RTHTMLTextTests : XCTestCase

@end


@implementation RTHTMLTextTests

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

  RTHTMLTextParser *parser = [RTHTMLTextParser new];

  NSAttributedString *res = [parser parseWithData:[text dataUsingEncoding:NSUTF8StringEncoding]];
  DDLogDebug(@"Result %@", res);
}

@end
