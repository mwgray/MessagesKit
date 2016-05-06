//
//  RTDBManagerTests.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/18/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTLog.h"

@import XCTest;
@import CocoaLumberjack;
@import FMDB;
@import MessagesKit;


RT_LUMBERJACK_DECLARE_LOG_LEVEL()


@class DelegateTester;

@interface RTDBManagerTests : XCTestCase

@property (nonatomic, strong) RTDBManager *dbManager;
@property (nonatomic, weak) RTContactDAO *contactDAO;
@property (nonatomic, assign) int delegateHits;
@property (nonatomic, strong) DelegateTester *delegateTester;

@end


@interface DelegateTester : NSObject <RTDBManagerDelegate>

@property (nonatomic, strong) RTDBManagerTests *tests;

@end



@implementation RTDBManagerTests

-(void) setUp
{
  [super setUp];

  NSString *dbPath = [NSTemporaryDirectory() stringByAppendingString:@"temp.sqlite"];
  [[NSFileManager defaultManager] removeItemAtPath:dbPath error:nil];

  self.dbManager = [[RTDBManager alloc] initWithPath:dbPath kind:@"Contact" daoClasses:@[[RTContactDAO class]]];
  self.contactDAO = self.dbManager[@"Contact"];

  self.delegateTester = [DelegateTester new];
  self.delegateTester.tests = self;
  [self.dbManager addDelegatesObject:self.delegateTester];
}

-(void) tearDown
{
  self.dbManager = nil;

  [super tearDown];
}

//-(void) testContains
//{
//  RTContact *contact = [RTContact new];
//  contact.name = @"Testing 123";
//
//  XCTAssertTrue([self.contactDAO insertObject:contact error:nil]);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"CONTAINS(name,'ING',1,1)" error:nil].count, 1);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"CONTAINS(name,'ING',0,0)" error:nil].count, 0);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"CONTAINS(name,'ing',0,0)" error:nil].count, 1);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"CONTAINS(NULL,'ing',0,0)" error:nil].count, 0);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"CONTAINS(name,NULL,0,0)" error:nil].count, 0);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"CONTAINS(NULL,NULL,0,0)" error:nil].count, 1);
//}
//
//-(void) testBeginsWith
//{
//  RTContact *contact = [RTContact new];
//  contact.name = @"Testing 123";
//
//  XCTAssertTrue([self.contactDAO insertObject:contact]);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"BEGINSWITH(name,'TEST',1,1)"].count, 1);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"BEGINSWITH(name,'TEST',0,0)"].count, 0);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"BEGINSWITH(name,'Test',0,0)"].count, 1);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"BEGINSWITH(NULL,'Test',0,0)"].count, 0);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"BEGINSWITH(name,NULL,0,0)"].count, 0);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"BEGINSWITH(NULL,NULL,0,0)"].count, 1);
//}
//
//-(void) testEndsWith
//{
//  RTContact *contact = [RTContact new];
//  contact.name = @"Testing 123";
//
//  XCTAssertTrue([self.contactDAO insertObject:contact]);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"ENDSWITH(name,'G 123',1,1)"].count, 1);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"ENDSWITH(name,'G 123',0,0)"].count, 0);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"ENDSWITH(name,'g 123',0,0)"].count, 1);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"ENDSWITH(NULL,'g 123',0,0)"].count, 0);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"ENDSWITH(name,NULL,0,0)"].count, 0);
//  XCTAssertEqual([self.contactDAO fetchAllObjectsMatching:@"ENDSWITH(NULL,NULL,0,0)"].count, 1);
//}

-(void) testDelegateRemove
{
  [self.dbManager removeDelegatesObject:self.delegateTester];

  XCTAssertEqual(self.dbManager.countOfDelegates, 0);
}

-(void) testDelegateWeakness
{
  RTContact *contact = [RTContact new];

  @autoreleasepool {
  
    contact.name = @"Testing 123";
    
    XCTAssertTrue([self.contactDAO insertObject:contact error:nil]);
    XCTAssertEqual(self.delegateHits, 1);
    
    self.delegateTester = nil;

  }

  XCTAssertTrue([self.contactDAO insertObject:contact error:nil]);
  XCTAssertEqual(self.delegateHits, 1);
}

-(void) testConcurrentAccess
{

  NSString *dbPath = [NSTemporaryDirectory() stringByAppendingString:@"temp2.sqlite"];

  FMDatabaseReadWritePool *pool = [FMDatabaseReadWritePool databasePoolWithPath:dbPath];

  [pool inWritableDatabase:^(FMDatabase *db) {

    XCTAssertTrue([db executeStatements:@"DROP TABLE IF EXISTS test; CREATE TABLE test(value);"]);

  }];

  dispatch_queue_t q = dispatch_queue_create("Readers/Writers", DISPATCH_QUEUE_CONCURRENT);
  __block BOOL finished = NO;

  for (int c=0; c < 5; ++c) {

    dispatch_async(q, ^{

      while (!finished) {
        
        [pool inReadableDatabase:^(FMDatabase *db) {
          
          FMResultSet *resultSet = [db executeQuery:@"SELECT value FROM test"];
          XCTAssertNotNil(resultSet, @"DB query returned nil result set");
          XCTAssertTrue(resultSet.next, @"Statement next failed");
          [resultSet close];
          XCTAssertEqual(db.lastErrorCode, 0, @"Unexpected error");
          
        }];
        
      }
      
    });

  }

  for (int c=0; c < 5000; ++c) {

    [pool inWritableDatabase:^(FMDatabase *db) {
      
      BOOL res = [db executeUpdate:@"INSERT INTO test(value) VALUES (?)", @(c)];
      XCTAssertTrue(res, @"DB update failed");
      XCTAssertEqual(db.lastErrorCode, 0, @"Unexpected error");
      
    }];

    usleep(100);
    
  }
  
  finished = YES;
  
  dispatch_barrier_sync(q, ^{
  });

  [NSFileManager.defaultManager removeItemAtPath:dbPath error:nil];
}

-(void) testConcurrentAccessNoCache
{
  
  NSString *dbPath = [NSTemporaryDirectory() stringByAppendingString:@"temp3.sqlite"];
  
  FMDatabaseReadWritePool *pool = [FMDatabaseReadWritePool databasePoolWithPath:dbPath];
  pool.cacheConnections = NO;
  
  [pool inWritableDatabase:^(FMDatabase *db) {
    
    XCTAssertTrue([db executeStatements:@"DROP TABLE IF EXISTS test; CREATE TABLE test(value);"]);
    
  }];
  
  dispatch_queue_t q = dispatch_queue_create("Readers/Writers", DISPATCH_QUEUE_CONCURRENT);
  __block BOOL finished = NO;
  
  for (int c=0; c < 5; ++c) {
    
    dispatch_async(q, ^{
      
      while (!finished) {
        
        [pool inReadableDatabase:^(FMDatabase *db) {
          
          FMResultSet *resultSet = [db executeQuery:@"SELECT value FROM test"];
          XCTAssertNotNil(resultSet, @"DB query returned nil result set");
          XCTAssertTrue(resultSet.next, @"Statement next failed");
          [resultSet close];
          XCTAssertEqual(db.lastErrorCode, 0, @"Unexpected error");
          
        }];
        
      }
      
    });
    
  }
  
  for (int c=0; c < 100; ++c) {
    
    [pool inWritableDatabase:^(FMDatabase *db) {
      
      BOOL res = [db executeUpdate:@"INSERT INTO test(value) VALUES (?)", @(c)];
      XCTAssertTrue(res, @"DB update failed");
      XCTAssertEqual(db.lastErrorCode, 0, @"Unexpected error");
      
    }];
    
    usleep(100);
    
  }
  
  finished = YES;
  
  dispatch_barrier_sync(q, ^{
  });
  
  [NSFileManager.defaultManager removeItemAtPath:dbPath error:nil];
}

-(void) testConcurrentAccess2
{
  NSString *dbPath = [NSTemporaryDirectory() stringByAppendingString:@"temp4.sqlite"];
  
  FMDatabaseReadWritePool *pool = [FMDatabaseReadWritePool databasePoolWithPath:dbPath];
  
  [pool inWritableDatabase:^(FMDatabase *db) {
    
    XCTAssertTrue([db executeStatements:@"DROP TABLE IF EXISTS test; CREATE TABLE test(id INTEGER PRIMARY KEY, name TEXT);"]);
    XCTAssertTrue([db executeUpdate:@"INSERT INTO test(id,name) VALUES(0,'test0')"]);
    XCTAssertTrue([db executeUpdate:@"INSERT INTO test(id,name) VALUES(1,'test1')"]);
    XCTAssertTrue([db executeUpdate:@"INSERT INTO test(id,name) VALUES(2,'test2')"]);
    XCTAssertTrue([db executeUpdate:@"INSERT INTO test(id,name) VALUES(3,'test3')"]);
    XCTAssertTrue([db executeUpdate:@"INSERT INTO test(id,name) VALUES(4,'test4')"]);
    
  }];
  
  dispatch_queue_t q = dispatch_queue_create("Readers/Writers", DISPATCH_QUEUE_CONCURRENT);
  __block BOOL finished = NO;
  
  for (int c=0; c < 5; ++c) {
    
    dispatch_async(q, ^{
      
      [pool inReadableDatabase:^(FMDatabase *db) {
        
        FMResultSet *resultSet = [db executeQuery:@"SELECT name FROM test WHERE id = ?", @(c)];
        XCTAssertNotNil(resultSet, @"DB query returned nil result set");
        XCTAssertTrue(resultSet.next, @"Statement next failed");
        
        __block NSString *cur = [resultSet stringForColumnIndex:0];
        [resultSet close];

        XCTAssertEqual(db.lastErrorCode, 0, @"Unexpected error");

        while (!finished) {
          
          FMResultSet *resultSet = [db executeQuery:@"SELECT name FROM test WHERE id = ?", @(c)];
          XCTAssertNotNil(resultSet, @"DB query returned nil result set");
          XCTAssertTrue(resultSet.next, @"Statement next failed");

          NSString *now = [resultSet stringForColumnIndex:0];
          XCTAssertNotNil(now);
          
          if (![now isEqualToString:cur]) {
            cur = now;
          }

          [resultSet close];          

          XCTAssertEqual(db.lastErrorCode, 0, @"Unexpected error");
        }
        
      }];
      
    });
    
  }
  
  __block BOOL lastResult = true;
  for (int c=10; c < 5000 && lastResult; ++c) {
    
    [pool inWritableDatabase:^(FMDatabase *db) {
      
      NSString *name = [NSString stringWithFormat:@"test%d", c];
      NSInteger idx = rand() % 5;
      
      lastResult = [db executeUpdate:@"UPDATE test SET name=? WHERE id=?", name, @(idx)];
      XCTAssertTrue(lastResult, @"DB update failed");
      XCTAssertEqual(db.lastErrorCode, 0, @"Unexpected error");
      
    }];
    
    usleep(500);
    
  }
  
  finished = YES;
  
  dispatch_barrier_sync(q, ^{
  });
  
  [NSFileManager.defaultManager removeItemAtPath:dbPath error:nil];
}

@end


@implementation DelegateTester

-(void)dealloc
{
  DDLogDebug(@"Deallocating delegate");
}

-(void) modelObjectsWillChangeInDAO:(RTDAO *)dao
{
  self.tests.delegateHits += 1;
}

@end
