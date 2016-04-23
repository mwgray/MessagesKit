//
//  RTPersistentCacheTests.m
//  ReTxt
//
//  Created by Kevin Wooten on 5/24/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTPersistentCache.h"
#import <XCTest/XCTest.h>

@interface RTPersistentCacheTests : XCTestCase

@property (strong, nonatomic) RTPersistentCache *cache;
@property (assign, nonatomic) BOOL fetched;

@end

@implementation RTPersistentCacheTests

-(void) setUp
{
  [super setUp];
  
}

-(void) tearDown
{
  self.cache = nil;
  
  [super tearDown];
}

-(void) testExpiration
{
  self.cache = [[RTPersistentCache alloc] initWithName:@"test"
                                                loader:^id (id key, NSDate *__autoreleasing *expires, NSError *__autoreleasing *error) {
                                                  
                                                  *expires = [NSDate dateWithTimeIntervalSinceNow:.25];
                                                  self.fetched = YES;
                                                  
                                                  return key;
                                                  
                                                } clear:YES];
  
  NSError *error;
  id value;

  self.fetched = NO;
  value = [self.cache objectForKey:@"123" error:&error];
  XCTAssertEqual(self.fetched, YES);
  XCTAssertEqualObjects(value, @"123");

  self.fetched = NO;
  value = [self.cache objectForKey:@"123" error:&error];
  XCTAssertEqual(self.fetched, NO);
  XCTAssertEqualObjects(value, @"123");

  usleep(.3*1000000);

  self.fetched = NO;
  value = [self.cache objectForKey:@"123" error:&error];
  XCTAssertEqual(self.fetched, YES);
  XCTAssertEqualObjects(value, @"123");

}

-(void) testAvailable
{
  self.cache = [[RTPersistentCache alloc] initWithName:@"test"
                                                loader:^id (id key, NSDate *__autoreleasing *expires, NSError *__autoreleasing *error) {

    *expires = [NSDate dateWithTimeIntervalSinceNow:.25];
    self.fetched = YES;

    return key;

  } clear:YES];

  NSError *error;
  id value;

  self.fetched = NO;
  value = [self.cache availableObjectForKey:@"123"];
  XCTAssertEqual(self.fetched, NO);
  XCTAssertEqualObjects(value, nil);

  self.fetched = NO;
  value = [self.cache objectForKey:@"123" error:&error];
  XCTAssertEqual(self.fetched, YES);
  XCTAssertEqualObjects(value, @"123");

  value = [self.cache availableObjectForKey:@"123"];
  XCTAssertEqualObjects(value, @"123");
}

-(void) testCompaction
{
  self.cache = [[RTPersistentCache alloc] initWithName:@"test"
                                                loader:^id (id key, NSDate *__autoreleasing *expires, NSError *__autoreleasing *error) {

    *expires = [NSDate dateWithTimeIntervalSinceNow:.25];
    self.fetched = YES;

    return key;

  } clear:YES];

  NSError *error;
  id value;

  self.fetched = NO;
  value = [self.cache objectForKey:@"123" error:&error];
  XCTAssertEqual(self.fetched, YES);
  XCTAssertEqualObjects(value, @"123");

  self.fetched = NO;
  value = [self.cache objectForKey:@"123" error:&error];
  XCTAssertEqual(self.fetched, NO);
  XCTAssertEqualObjects(value, @"123");

  usleep(.3*1000000);

  [self.cache compact];

  self.fetched = NO;
  value = [self.cache availableObjectForKey:@"123"];
  XCTAssertEqual(self.fetched, NO);
  XCTAssertEqual(value, nil);

}

-(void) testAutoCompaction
{
  self.cache = [[RTPersistentCache alloc] initWithName:@"test"
                                                loader:^id (id key, NSDate *__autoreleasing *expires, NSError *__autoreleasing *error) {

    *expires = [NSDate dateWithTimeIntervalSinceNow:.2];
    self.fetched = YES;

    return key;

  } clear:YES];

  NSError *error;
  id value;

  self.fetched = NO;
  value = [self.cache objectForKey:@"123" error:&error];
  XCTAssertEqual(self.fetched, YES);
  XCTAssertEqualObjects(value, @"123");

  self.fetched = NO;
  value = [self.cache objectForKey:@"123" error:&error];
  XCTAssertEqual(self.fetched, NO);
  XCTAssertEqualObjects(value, @"123");

  usleep(.3*1000000);

  for (int c=0; c < 100; ++c) {
    [self.cache objectForKey:@"456" error:nil];
  }

  usleep(1*1000000);

  self.fetched = NO;
  value = [self.cache availableObjectForKey:@"123"];
  XCTAssertEqual(self.fetched, NO);
  XCTAssertEqualObjects(value, nil);

}

-(void) testInvalidation
{
  self.cache = [[RTPersistentCache alloc] initWithName:@"test"
                                                loader:^id (id key, NSDate *__autoreleasing *expires, NSError *__autoreleasing *error) {

    *expires = [NSDate dateWithTimeIntervalSinceNow:10000];
    self.fetched = YES;

    return key;

  } clear:YES];

  NSError *error;
  id value;

  self.fetched = NO;
  value = [self.cache objectForKey:@"123" error:&error];
  XCTAssertEqual(self.fetched, YES);
  XCTAssertEqualObjects(value, @"123");

  self.fetched = NO;
  value = [self.cache objectForKey:@"123" error:&error];
  XCTAssertEqual(self.fetched, NO);
  XCTAssertEqualObjects(value, @"123");

  [self.cache invalidateObjectForKey:@"123"];

  self.fetched = NO;
  value = [self.cache objectForKey:@"123" error:&error];
  XCTAssertEqual(self.fetched, YES);
  XCTAssertEqualObjects(value, @"123");

}

-(void) testNullValue
{
  
  self.cache = [[RTPersistentCache alloc] initWithName:@"test"
                                                loader:^id<NSCoding> (id<NSCopying> key, NSDate **expires, NSError **error) {
    *expires = nil;
    return nil;
                                                  
  } clear:YES];
  
  XCTAssertNil([self.cache objectForKey:@"123" error:nil]);
}

@end
