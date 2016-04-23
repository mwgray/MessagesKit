//
//  RTFetchedResultsControllerTests.m
//  ReTxt
//
//  Created by Kevin Wooten on 7/16/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "RTChatDAO.h"
#import "RTMessageDAO.h"
#import "RTTextMessage.h"
#import "RTFetchedResultsController.h"
#import "RTMessages+Exts.h"


@interface RTFetchedResultsControllerTests : XCTestCase <RTDBManagerDelegate, RTFetchedResultsControllerDelegate>

@property (nonatomic, strong) RTDBManager *dbManager;
@property (nonatomic, weak) RTMessageDAO *messageDAO;
@property (strong, nonatomic) NSMutableSet *inserted;
@property (strong, nonatomic) NSMutableSet *moved;
@property (strong, nonatomic) NSMutableSet *updated;
@property (strong, nonatomic) NSMutableSet *deleted;
@property (strong, nonatomic) NSMutableArray *results;
@property (strong, nonatomic) NSMutableArray *expectations;

@property (strong, nonatomic) RTChat *chat;

@end

@implementation RTFetchedResultsControllerTests

-(void) setUp
{
  [super setUp];

  self.expectations = [NSMutableArray array];

  NSString *dbPath = [NSTemporaryDirectory() stringByAppendingString:@"temp.sqlite"];
  [[NSFileManager defaultManager] removeItemAtPath:dbPath error:nil];

  self.dbManager = [[RTDBManager alloc] initWithPath:dbPath kind:@"Message" daoClasses:@[[RTMessageDAO class],
                                                                                         [RTChatDAO class]]];
  [self.dbManager addDelegatesObject:self];

  self.messageDAO = self.dbManager[@"Message"];

  self.inserted = [NSMutableSet new];
  self.moved = [NSMutableSet new];
  self.updated = [NSMutableSet new];
  self.deleted = [NSMutableSet new];

  self.chat = [RTUserChat new];
  self.chat.id = [RTId generate];
  self.chat.alias = @"12345";
  self.chat.localAlias = @"me";

  [self.dbManager[@"Chat"] insertObject:self.chat error:nil];
}

-(void) tearDown
{
  self.dbManager = nil;

  [super tearDown];
}

-(void) flush
{
  [[NSRunLoop mainRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.25]];
}

-(id) fill:(RTMessage *)msg
{
  msg.id = [RTId generate];
  msg.chat = self.chat;
  msg.sender = @"me";
  msg.sent = [NSDate date];
  msg.status = RTMessageStatusUnsent;
  msg.statusTimestamp = [NSDate date];
  msg.flags = RTMessageFlagClarify;

  return msg;
}

-(RTTextMessage *) newTextMessage
{
  RTTextMessage *msg = [self fill:[RTTextMessage new]];
  msg.text = @"Yo!";
  return msg;
}

-(int) insertMessages
{
  int c;
  for (c=0; c < 50; ++c) {

    RTMessage *msg = [self newTextMessage];
    [self.messageDAO insertObject:msg error:nil];


  }
  return c;
}

-(void) testUnsorted
{
  RTFetchRequest *request = [RTFetchRequest new];
  request.resultClass = [RTMessage class];
  request.includeSubentities = YES;
  request.predicate = [NSPredicate predicateWithFormat:@"chat = %@", self.chat];

  RTFetchedResultsController *controller = [[RTFetchedResultsController alloc] initWithDBManager:self.dbManager
                                                                                         request:request];
  controller.delegate = self;

  [controller execute];

  int inserted = [self insertMessages];

  [self flush];

  XCTAssertEqual(inserted, _inserted.count);
}


-(void) testSorted
{
  RTFetchRequest *request = [RTFetchRequest new];
  request.resultClass = [RTMessage class];
  request.includeSubentities = YES;
  request.predicate = [NSPredicate predicateWithFormat:@"chat = %@", self.chat];
  request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"sent" ascending:NO]];

  RTFetchedResultsController *controller = [[RTFetchedResultsController alloc] initWithDBManager:self.dbManager
                                                                                         request:request];
  controller.delegate = self;

  [controller execute];

  NSMutableArray *msgs = [NSMutableArray new];

  for (int c=0; c < 100; ++c) {

    [self.expectations addObject:[self expectationWithDescription:@"Insert"]];

    RTMessage *msg = [self newTextMessage];
    msg.sent = [NSDate dateWithTimeIntervalSinceNow:(drand48()-0.5)*1000];

    [msgs addObject:msg];

    [self.messageDAO insertObject:msg error:nil];

    [self waitForExpectationsWithTimeout:10 handler:NULL];

    [self assertSorted:controller];
  }

  for (int c=0; c < 1000; ++c) {

    [self.expectations addObject:[self expectationWithDescription:@"Move|Update"]];

    [self.messageDAO updateMessage:msgs[(int)(drand48()*100)] withSent:[NSDate dateWithTimeIntervalSinceNow:-2000-(c*100)]];

    [self waitForExpectationsWithTimeout:10 handler:NULL];

    [self assertSorted:controller];
  }

}

-(void) testThreaded
{
  RTFetchRequest *request = [RTFetchRequest new];
  request.resultClass = [RTMessage class];
  request.includeSubentities = YES;
  request.predicate = [NSPredicate predicateWithFormat:@"chat = %@", self.chat];
  request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"sent" ascending:NO]];

  RTFetchedResultsController *controller = [[RTFetchedResultsController alloc] initWithDBManager:self.dbManager
                                                                                         request:request];
  controller.delegate = self;

  [controller execute];

  NSMutableArray *msgs = [NSMutableArray new];

  for (int c=0; c < 100; ++c) {

    [self.expectations addObject:[self expectationWithDescription:@"Insert"]];

    RTMessage *msg = [self newTextMessage];
    msg.sent = [NSDate dateWithTimeIntervalSinceNow:(drand48()-0.5)*1000];

    [msgs addObject:msg];

    [self.messageDAO insertObject:msg error:nil];

    [self waitForExpectationsWithTimeout:10 handler:NULL];

    [self assertSorted:controller];
  }

  self.results = [NSMutableArray arrayWithCapacity:controller.numberOfObjects];
  for (int d=0; d < controller.numberOfObjects; ++d) {
    [self.results addObject:controller[d]];
  }


  for (int tests=0; tests < 20; ++tests) {

    XCTestExpectation *updates = [self expectationWithDescription:@"Update thread"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{

      for (int c=0; c < 100; ++c) {
        [self.messageDAO updateMessage:msgs[(int)(drand48()*100)] withSent:[NSDate dateWithTimeIntervalSinceNow:-2000-(c*100)]];
      }

      [updates fulfill];
    });

    [self waitForExpectationsWithTimeout:100 handler:^(NSError *error) {
    }];

    NSMutableArray *tester = [NSMutableArray arrayWithCapacity:controller.numberOfObjects];
    for (int d=0; d < controller.numberOfObjects; ++d) {
      [tester addObject:controller[d]];
    }

    XCTAssertEqualObjects(self.results, tester);
  }

}

-(void) assertSorted:(RTFetchedResultsController *)controller
{
  NSMutableArray *tester = [NSMutableArray arrayWithCapacity:controller.numberOfObjects];
  for (int d=0; d < controller.numberOfObjects; ++d) {
    [tester addObject:controller[d]];
  }

  NSArray *tester2 = [tester sortedArrayUsingDescriptors:controller.request.sortDescriptors];

  __block BOOL same = YES;
  [tester enumerateObjectsUsingBlock:^(RTMessage *obj, NSUInteger idx, BOOL *stop) {
    RTMessage *obj2 = tester2[idx];
    same = [obj.sent isEqual:obj2.sent];
    *stop = !same;
  }];

  XCTAssertTrue(same, @"Results not sorted");
}

-(void) controllerWillChangeResults:(RTFetchedResultsController *)controller
{
  [self fulfillAll:@"Will"];
}

-(void) controller:(RTFetchedResultsController *)controller
   didChangeObject:(id)object
           atIndex:(NSInteger)index
     forChangeType:(RTFetchedResultsChangeType)changeType
          newIndex:(NSInteger)newIndex
{
  NSString *type;

  switch (changeType) {
  case RTFetchedResultsChangeInsert:
    //NSLog(@"### Inserted %@ at %d", [object id], (int)newIndex);
    [_inserted addObject:[object id]];
    type = @"Insert";
    [self.results insertObject:object atIndex:newIndex];
    break;

  case RTFetchedResultsChangeUpdate:
    //NSLog(@"### Updated %@ at %d", [object id], (int)index);
    [_updated addObject:[object id]];
    type = @"Update";
    break;

  case RTFetchedResultsChangeMove:
    //NSLog(@"### Moved %@ from %d at %d", [object id], (int)index, (int)newIndex);
    [_moved addObject:[object id]];
    type = @"Move";
    [self.results removeObjectAtIndex:index];
    [self.results insertObject:object atIndex:newIndex];
    break;

  case RTFetchedResultsChangeDelete:
    //NSLog(@"### Deleted %@ from %d", [object id], (int)index);
    [_deleted addObject:[object id]];
    type = @"Delete";
    [self.results removeObjectAtIndex:index];
    break;

  default:
    break;
  }

  [self fulfillAll:type];
}

-(void) controllerDidChangeResults:(RTFetchedResultsController *)controller
{
  [self fulfillAll:@"Did"];
}

-(void) fulfillAll:(NSString *)type
{
  NSMutableArray *fulfilled = [NSMutableArray array];
  for (XCTestExpectation *exp in self.expectations) {
    if ([exp.description containsString:type]) {
      [exp fulfill];
      [fulfilled addObject:exp];
    }
  }
  [self.expectations removeObjectsInArray:fulfilled];
}

@end
