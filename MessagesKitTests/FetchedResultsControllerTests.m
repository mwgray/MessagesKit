//
//  FetchedResultsControllerTests.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/16/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import XCTest;
@import FMDB;

#import "ChatDAO.h"
#import "MessageDAO.h"
#import "TextMessage.h"
#import "FetchedResultsController.h"
#import "Messages+Exts.h"


@interface FetchedResultsControllerTests : XCTestCase <DBManagerDelegate, FetchedResultsControllerDelegate>

@property (nonatomic, strong) DBManager *dbManager;
@property (nonatomic, weak) MessageDAO *messageDAO;
@property (strong, nonatomic) NSMutableSet *inserted;
@property (strong, nonatomic) NSMutableSet *moved;
@property (strong, nonatomic) NSMutableSet *updated;
@property (strong, nonatomic) NSMutableSet *deleted;
@property (strong, nonatomic) NSMutableArray *results;
@property (strong, nonatomic) NSMutableArray *expectations;

@property (strong, nonatomic) Chat *chat;

@end


@implementation FetchedResultsControllerTests

-(void) setUp
{
  [super setUp];

  self.expectations = [NSMutableArray array];

  NSString *dbPath = [NSTemporaryDirectory() stringByAppendingString:@"temp.sqlite"];
  [NSFileManager.defaultManager removeItemAtPath:dbPath error:nil];

  self.dbManager = [[DBManager alloc] initWithPath:dbPath kind:@"Message" daoClasses:@[[MessageDAO class],
                                                                                         [ChatDAO class]]
                                               error:nil];
  [self.dbManager addDelegatesObject:self];

  self.messageDAO = self.dbManager[@"Message"];

  self.inserted = [NSMutableSet new];
  self.moved = [NSMutableSet new];
  self.updated = [NSMutableSet new];
  self.deleted = [NSMutableSet new];

  self.chat = [UserChat new];
  self.chat.id = [Id generate];
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

-(id) fill:(Message *)msg
{
  msg.id = [Id generate];
  msg.chat = self.chat;
  msg.sender = @"me";
  msg.sent = [NSDate date];
  msg.status = MessageStatusUnsent;
  msg.statusTimestamp = [NSDate date];
  msg.flags = MessageFlagClarify;

  return msg;
}

-(TextMessage *) newTextMessage
{
  TextMessage *msg = [self fill:[TextMessage new]];
  msg.text = @"Yo!";
  return msg;
}

-(int) insertMessages
{
  int c;
  for (c=0; c < 50; ++c) {

    Message *msg = [self newTextMessage];
    [self.messageDAO insertObject:msg error:nil];


  }
  return c;
}

-(void) testUnsorted
{
  FetchRequest *request = [FetchRequest new];
  request.resultClass = [Message class];
  request.includeSubentities = YES;
  request.predicate = [NSPredicate predicateWithFormat:@"chat = %@", self.chat];

  FetchedResultsController *controller = [[FetchedResultsController alloc] initWithDBManager:self.dbManager
                                                                                         request:request];
  controller.delegate = self;

  [controller executeAndReturnError:nil];

  int inserted = [self insertMessages];

  [self flush];

  XCTAssertEqual(inserted, _inserted.count);
}


-(void) testSorted
{
  FetchRequest *request = [FetchRequest new];
  request.resultClass = [Message class];
  request.includeSubentities = YES;
  request.predicate = [NSPredicate predicateWithFormat:@"chat = %@", self.chat];
  request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"sent" ascending:NO]];

  FetchedResultsController *controller = [[FetchedResultsController alloc] initWithDBManager:self.dbManager
                                                                                         request:request];
  controller.delegate = self;

  [controller executeAndReturnError:nil];

  NSMutableArray *msgs = [NSMutableArray new];

  for (int c=0; c < 100; ++c) {

    [self.expectations addObject:[self expectationWithDescription:@"Insert"]];

    Message *msg = [self newTextMessage];
    msg.sent = [NSDate dateWithTimeIntervalSinceNow:(drand48()-0.5)*1000];

    [msgs addObject:msg];

    [self.messageDAO insertObject:msg error:nil];

    [self waitForExpectationsWithTimeout:10 handler:NULL];

    [self assertSorted:controller];
  }

  for (int c=0; c < 1000; ++c) {

    [self.expectations addObject:[self expectationWithDescription:@"Move|Update"]];

    [self.messageDAO updateMessage:msgs[(int)(drand48()*100)] withSent:[NSDate dateWithTimeIntervalSinceNow:-2000-(c*100)] error:nil];

    [self waitForExpectationsWithTimeout:10 handler:NULL];

    [self assertSorted:controller];
  }

}

-(void) testThreaded
{
  FetchRequest *request = [FetchRequest new];
  request.resultClass = [Message class];
  request.includeSubentities = YES;
  request.predicate = [NSPredicate predicateWithFormat:@"chat = %@", self.chat];
  request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"sent" ascending:NO]];
  request.liveResults = NO;

  FetchedResultsController *controller = [[FetchedResultsController alloc] initWithDBManager:self.dbManager
                                                                                         request:request];
  controller.delegate = self;

  [controller executeAndReturnError:nil];

  NSMutableArray *msgs = [NSMutableArray new];

  for (int c=0; c < 100; ++c) {

    [self.expectations addObject:[self expectationWithDescription:@"Insert"]];

    Message *msg = [self newTextMessage];
    msg.sent = [NSDate dateWithTimeIntervalSinceNow:(drand48()-0.5)*1000];

    [msgs addObject:msg];

    [self.messageDAO insertObject:msg error:nil];

  }

  [self waitForExpectationsWithTimeout:10 handler:NULL];
  
  [self assertSorted:controller];

  for (int tests=1; tests < 3001; ++tests) {

    [self.expectations addObject:[self expectationWithDescription:@"Move|Update"]];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self.messageDAO updateMessage:msgs[(int)(drand48()*100)] withSent:[NSDate dateWithTimeIntervalSinceNow:-2000-(tests*100)] error:nil];
    });
    
    if (tests % 100 == 0) {
      
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.dbManager.pool inWritableDatabase:^(FMDatabase *db){
          [self assertSorted:controller];
        }];
      });

      [self waitForExpectationsWithTimeout:100 handler:NULL];
    }
  }
  
  [self assertSorted:controller];

}

-(void) assertSorted:(FetchedResultsController *)controller
{
  NSMutableArray *tester = [NSMutableArray arrayWithCapacity:controller.numberOfObjects];
  for (int d=0; d < controller.numberOfObjects; ++d) {
    [tester addObject:controller[d]];
  }

  NSArray *tester2 = [tester sortedArrayUsingDescriptors:controller.request.sortDescriptors];

  __block BOOL same = YES;
  [tester enumerateObjectsUsingBlock:^(Message *obj, NSUInteger idx, BOOL *stop) {
    Message *obj2 = tester2[idx];
    same = [obj.sent isEqual:obj2.sent];
    *stop = !same;
  }];

  XCTAssertTrue(same, @"Results not sorted");
}

-(void) controllerWillChangeResults:(FetchedResultsController *)controller
{
}

-(void) controller:(FetchedResultsController *)controller
   didChangeObject:(id)object
           atIndex:(NSInteger)index
     forChangeType:(FetchedResultsChangeType)changeType
          newIndex:(NSInteger)newIndex
{
  NSString *type;

  switch (changeType) {
  case FetchedResultsChangeInsert:
    //NSLog(@"### Inserted %@ at %d", [object id], (int)newIndex);
    [_inserted addObject:[object id]];
    type = @"Insert";
    [self.results insertObject:object atIndex:newIndex];
    break;

  case FetchedResultsChangeUpdate:
    //NSLog(@"### Updated %@ at %d", [object id], (int)index);
    [_updated addObject:[object id]];
    type = @"Update";
    break;

  case FetchedResultsChangeMove:
    //NSLog(@"### Moved %@ from %d at %d", [object id], (int)index, (int)newIndex);
    [_moved addObject:[object id]];
    type = @"Move";
    [self.results removeObjectAtIndex:index];
    [self.results insertObject:object atIndex:newIndex];
    break;

  case FetchedResultsChangeDelete:
    //NSLog(@"### Deleted %@ from %d", [object id], (int)index);
    [_deleted addObject:[object id]];
    type = @"Delete";
    [self.results removeObjectAtIndex:index];
    break;

  default:
    break;
  }

  [self fulfill:type max:1];
}

-(void) controllerDidChangeResults:(FetchedResultsController *)controller
{
}

-(void) fulfill:(NSString *)type max:(NSUInteger)maxFulfilled
{
  NSMutableArray *fulfilled = [NSMutableArray array];
  for (XCTestExpectation *exp in self.expectations) {
    if ([exp.description containsString:type]) {
      [exp fulfill];
      [fulfilled addObject:exp];
      if (fulfilled.count == maxFulfilled) {
        break;
      }
    }
  }
  [self.expectations removeObjectsInArray:fulfilled];
}

@end
