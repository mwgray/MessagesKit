//
//  ContactTests.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/11/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "ContactDAO.h"
#import "ContactAliasDAO.h"

#import <CocoaLumberjack/DDTTYLogger.h>

@interface ContactTests : XCTestCase <DBManagerDelegate>

@property (nonatomic, strong) DBManager *dbManager;
@property (nonatomic, weak) ContactDAO *contactDAO;
@property (nonatomic, weak) ContactAliasDAO *aliasDAO;
@property (strong, nonatomic) NSMutableSet *inserted;
@property (strong, nonatomic) NSMutableSet *updated;
@property (strong, nonatomic) NSMutableSet *deleted;

@end

@implementation ContactTests

-(void) setUp
{
  [super setUp];

  [DDLog addLogger:[DDTTYLogger sharedInstance]];

  NSString *dbPath = [NSTemporaryDirectory() stringByAppendingString:@"temp.sqlite"];
  [[NSFileManager defaultManager] removeItemAtPath:dbPath error:nil];

  self.dbManager = [[DBManager alloc] initWithPath:dbPath kind:@"Contact" daoClasses:@[[ContactDAO class],
                                                                                         [ContactAliasDAO class]]];
  [self.dbManager addDelegatesObject:self];

  self.contactDAO = self.dbManager[@"Contact"];
  self.aliasDAO = self.dbManager[@"ContactAlias"];

  self.inserted = [NSMutableSet new];
  self.updated = [NSMutableSet new];
  self.deleted = [NSMutableSet new];
}

-(void) tearDown
{
  self.dbManager = nil;

  [super tearDown];
}

-(void) testComplexPredicateSelect
{
  ContactAlias *alias = [self newAlias];
  [self.dbManager[@"Contact"] insertObject:alias.contact error:nil];
  [self.dbManager[@"ContactAlias"] insertObject:alias error:nil];

  NSString *query = @"test";

  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"value CONTAINS[cd] %@ OR contact.name CONTAINS[cd] %@", query, query];


  NSArray *results = [self.aliasDAO fetchAllObjectsMatching:predicate
                                                     offset:0
                                                      limit:0
                                                   sortedBy:nil
                                                      error:nil];

  XCTAssertNotNil(results);
  XCTAssertEqual(results.count, 1);
  XCTAssertEqualObjects(results[0], alias);
}

-(void) testContactFetchAll
{
  Contact *contact1 = [Contact new];
  contact1.name = @"Test Guy";

  Contact *contact2 = [Contact new];
  contact2.name = @"Test Guy";

  XCTAssertTrue([self.contactDAO insertObject:contact1 error:nil]);
  XCTAssertTrue([self.contactDAO insertObject:contact2 error:nil]);

  NSArray *all1 = [self.contactDAO fetchAllObjectsMatching:nil error:nil];
  XCTAssertEqual(all1.count, 2);

  NSArray *all2 = [self.contactDAO fetchAllObjectsMatching:@"name = ?" parameters:@[contact1.name] error:nil];
  XCTAssertEqual(all2.count, 2);
}

-(void) testContactInsertFetch
{
  Contact *contact = [Contact new];
  contact.name = @"Test Guy";
  contact.addressBookId = 1000;
  contact.image = [NSData dataWithBytes:"12345" length:5];
  contact.aliases = [NSSet set];

  XCTAssertTrue([self.contactDAO insertObject:contact error:nil]);
  XCTAssertTrue([_inserted containsObject:contact.id]);
  XCTAssertTrue([contact isEquivalent:[self.contactDAO fetchObjectWithId:contact.id]]);
}

-(void) testContactUpdate
{
  Contact *contact = [Contact new];
  contact.name = @"Test Guy";

  XCTAssertTrue([self.contactDAO insertObject:contact error:nil]);

  contact.name = @"Testing 123";

  XCTAssertTrue([self.contactDAO updateObject:contact error:nil]);
  XCTAssertTrue([_updated containsObject:contact.id]);
  XCTAssertTrue([contact isEquivalent:[self.contactDAO fetchObjectWithId:contact.id]]);
}

-(void) testContactUpsert
{
  Contact *contact = [Contact new];
  contact.name = @"Test Guy";

  XCTAssertTrue([self.contactDAO upsertObject:contact error:nil]);

  XCTAssertTrue([_inserted containsObject:contact.id]);

  XCTAssertTrue([self.contactDAO upsertObject:contact error:nil]);

  XCTAssertTrue([_updated containsObject:contact.id]);
}

-(void) testContactDelete
{
  Contact *contact = [Contact new];
  contact.name = @"Test Guy";

  XCTAssertTrue([self.contactDAO insertObject:contact error:nil]);
  XCTAssertTrue([self.contactDAO deleteObject:contact error:nil]);
  XCTAssertTrue([_deleted containsObject:contact.id]);
  XCTAssertNil([self.contactDAO fetchObjectWithId:contact.id]);
}

-(void) testContactDeleteAll
{
  Contact *contact1 = [Contact new];
  contact1.name = @"Test Guy";

  Contact *contact2 = [Contact new];
  contact2.name = @"Test Guy";

  NSArray *all = @[contact1, contact2];

  XCTAssertTrue([self.contactDAO insertObject:contact1 error:nil]);
  XCTAssertTrue([self.contactDAO insertObject:contact2 error:nil]);
  XCTAssertTrue([self.contactDAO deleteAllObjectsInArray:all error:nil]);
  XCTAssertTrue([_deleted containsObject:contact1.id]);
  XCTAssertTrue([_deleted containsObject:contact2.id]);
}

-(ContactAlias *) newAlias
{
  Contact *contact = [Contact new];
  contact.name = @"Tester Guy";

  ContactAlias *alias = [ContactAlias new];
  alias.contact = contact;
  alias.type = ContactAliasTypeEMailAddress;
  alias.displayValue = @"Testing";
  alias.value = @"testing";

  return alias;
}

-(void) testContactAliasFetchAll
{
  ContactAlias *alias1 = [self newAlias];
  ContactAlias *alias2 = [self newAlias];

  [self.contactDAO insertObject:alias1.contact error:nil];
  XCTAssertTrue([self.aliasDAO insertObject:alias1 error:nil]);
  [self.contactDAO insertObject:alias2.contact error:nil];
  XCTAssertTrue([self.aliasDAO insertObject:alias2 error:nil]);

  NSArray *all1 = [self.aliasDAO fetchAllObjectsMatching:nil error:nil];
  XCTAssertEqual(all1.count, 2);

  NSArray *all2 = [self.aliasDAO fetchAllObjectsMatching:@"value = ?" parameters:@[alias1.value] error:nil];
  XCTAssertEqual(all2.count, 2);
}

-(void) testContactAliasInsertFetch
{
  ContactAlias *alias = [self newAlias];

  [self.contactDAO insertObject:alias.contact error:nil];
  XCTAssertTrue([self.aliasDAO insertObject:alias error:nil]);
  XCTAssertTrue([_inserted containsObject:alias.id]);
  [self.aliasDAO clearCache];
  XCTAssertTrue([alias isEquivalent:[self.aliasDAO fetchObjectWithId:alias.id]]);
}

-(void) testContactAliasUpdate
{
  ContactAlias *alias = [self newAlias];

  [self.contactDAO insertObject:alias.contact error:nil];
  XCTAssertTrue([self.aliasDAO insertObject:alias error:nil]);

  alias.value = @"Testing 123";

  XCTAssertTrue([self.aliasDAO updateObject:alias error:nil]);
  XCTAssertTrue([_updated containsObject:alias.id]);
  XCTAssertTrue([alias isEquivalent:[self.aliasDAO fetchObjectWithId:alias.id]]);
}

-(void) testContactAliasUpsert
{
  ContactAlias *alias = [self newAlias];

  [self.contactDAO insertObject:alias.contact error:nil];

  XCTAssertTrue([self.aliasDAO upsertObject:alias error:nil]);

  XCTAssertTrue([_inserted containsObject:alias.id]);

  XCTAssertTrue([self.aliasDAO upsertObject:alias error:nil]);

  XCTAssertTrue([_updated containsObject:alias.id]);
}

-(void) testContactAliasDelete
{
  ContactAlias *alias = [self newAlias];

  [self.contactDAO insertObject:alias.contact error:nil];
  XCTAssertTrue([self.aliasDAO insertObject:alias error:nil]);
  XCTAssertTrue([self.aliasDAO deleteObject:alias error:nil]);
  XCTAssertTrue([_deleted containsObject:alias.id]);
  XCTAssertNil([self.aliasDAO fetchObjectWithId:alias.id]);
}

-(void) testContactAliasDeleteAll
{
  ContactAlias *alias1 = [self newAlias];
  ContactAlias *alias2 = [self newAlias];

  NSArray *all = @[alias1, alias2];

  [self.contactDAO insertObject:alias1.contact error:nil];
  XCTAssertTrue([self.aliasDAO insertObject:alias1 error:nil]);
  [self.contactDAO insertObject:alias2.contact error:nil];
  XCTAssertTrue([self.aliasDAO insertObject:alias2 error:nil]);
  XCTAssertTrue([self.aliasDAO deleteAllObjectsInArray:all error:nil]);
  XCTAssertTrue([_deleted containsObject:alias1.id]);
  XCTAssertTrue([_deleted containsObject:alias2.id]);
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
