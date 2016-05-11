//
//  FetchedResultsController.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/12/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "FetchedResultsController.h"

#import "DAO.h"
#import "NSArray+Utils.h"


@implementation FetchRequest

-(instancetype)init
{
  self = [super init];
  if (self) {
    
    _liveResults = YES;
    
  }
  return self;
}

@end



typedef BOOL (*InstanceCheck)(id, SEL, id);

NSComparisonResult sortObjects(NSArray *sortDescriptors, id obj1, id obj2);



@interface FetchedResultsController () <DBManagerDelegate> {
  DBManager *_dbManager;
  DAO *_dao;
  FetchRequest *_request;
  NSMutableArray *_results;
  NSMutableArray *_resultsPending;
  SEL _isMatchingInstanceSEL;
  IMP _isMatchingInstanceIMP;
  InstanceCheck _isMatchingInstance;
  NSComparator _sortComparator;
  NSMutableArray *_changeSet;
  dispatch_queue_t _queue;
  dispatch_queue_t _dispatchQueue;
}

@end


@implementation FetchedResultsController

-(instancetype) initWithDBManager:(DBManager *)dbManager request:(FetchRequest *)request
{
  if ((self = [super init])) {
    _dbManager = dbManager;
    _request = request;
    _changeSet = [NSMutableArray array];
    _queue = dispatch_queue_create("FetchedResultsController Processing Queue", DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(_queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
    _dispatchQueue = dispatch_get_main_queue();
  }

  return self;
}

-(void) dealloc
{
  [_dbManager removeDelegatesObject:self];
}

-(void) execute
{
  _isMatchingInstanceSEL = _request.includeSubentities ? @selector(isKindOfClass:) : @selector(isMemberOfClass:);
  _isMatchingInstanceIMP = [_request.resultClass methodForSelector:_isMatchingInstanceSEL];
  _isMatchingInstance = (InstanceCheck)_isMatchingInstanceIMP;

  if (_request.sortDescriptors.count) {

    __unsafe_unretained FetchedResultsController *weakSelf = self;

    _sortComparator = ^NSComparisonResult (id obj1, id obj2) {
      return sortObjects(weakSelf->_request.sortDescriptors, obj1, obj2);
    };

  }
  else {

    _sortComparator = ^NSComparisonResult (id obj1, id obj2) {
      return [obj1 compare:obj2];
    };
  }

  _dao = [_dbManager daoForClass:_request.resultClass];

  NSError *error = nil;
  NSArray *results = [_dao fetchAllObjectsMatching:_request.predicate
                                            offset:_request.fetchOffset
                                             limit:_request.fetchLimit
                                          sortedBy:_request.sortDescriptors
                                             error:&error];
  if (!results) {
    //FIXME handle error - add error handling to interface
    return;
  }

  _resultsPending = [results mutableCopy];
  _results = [results mutableCopy];

  [_dbManager addDelegatesObject:self];
}

-(NSInteger) numberOfObjects
{
  return _results.count;
}

-(NSInteger) lastIndex
{
  return _results.lastIndex;
}

-(id) objectAtIndex:(NSInteger)index
{
  return _results[index];
}

-(id) objectAtIndexedSubscript:(NSInteger)index
{
  return _results[index];
}

-(void) modelObjectsWillChangeInDAO:(DAO *)dao
{
  @synchronized(self) {

    _changeSet = [NSMutableArray array];

  }
}

-(void) modelObject:(Model *)model insertedInDAO:(DAO *)dao
{
  if (!_isMatchingInstance(model, _isMatchingInstanceSEL, _request.resultClass)) {
    return;
  }

  if (![_request.predicate evaluateWithObject:model]) {
    return;
  }

  @synchronized(self) {

    [_changeSet addObject:@[@0, model.copy]];

  }
}


-(void) modelObject:(Model *)model updatedInDAO:(DAO *)dao
{

  if (!_isMatchingInstance(model, _isMatchingInstanceSEL, _request.resultClass)) {
    return;
  }

  if (![_request.predicate evaluateWithObject:model]) {
    return;
  }

  @synchronized(self) {

    [_changeSet addObject:@[@1, model.copy]];

  }
}

-(void) modelObject:(Model *)model deletedInDAO:(DAO *)dao
{
  if (!_isMatchingInstance(model, _isMatchingInstanceSEL, _request.resultClass)) {
    return;
  }

  if (![_request.predicate evaluateWithObject:model]) {
    return;
  }

  @synchronized(self) {

    [_changeSet addObject:@[@2, model.copy]];

  }
}

-(void) modelObjectsDidChangeInDAO:(DAO *)dao
{
  NSArray *changeSet;

  @synchronized(self) {

    changeSet = _changeSet;
    _changeSet = nil;

  }

  if (changeSet.count) {

    dispatch_async(_queue, ^{

      [self _fireWillChange];

      for (NSArray *change in changeSet) {

        switch ([change[0] intValue]) {
        case 0:
          [self processInsert:change[1]];
          break;

        case 1:
          [self processUpdate:change[1]];
          break;

        case 2:
          [self processDelete:change[1]];
          break;

        default:
          break;
        }

      }

      [self _fireDidChange];
      
      NSAssert([_resultsPending isEqualToArray:[_resultsPending sortedArrayUsingComparator:_sortComparator]], @"Pending results not sorted");

    });

  }
}

-(void) processInsert:(Model *)model
{
  NSUInteger insertionIndex;

  insertionIndex = [self _insertionIndexOfObject:model];

  [_resultsPending insertObject:model atIndex:insertionIndex];

  [self _fireChangeType:FetchedResultsChangeInsert
                 object:model
                  index:NSNotFound
               newIndex:insertionIndex
             applicator:^(Model *model){
    [_results insertObject:model atIndex:insertionIndex];
  }];

}

-(void) processUpdate:(Model *)model
{
  NSUInteger currentIndex, newIndex;
  FetchedResultsChangeType changeType;

  currentIndex = [_resultsPending indexOfObject:model];
  if (currentIndex == NSNotFound) {
    [self processInsert:model];
    return;
  }

  if (![_resultsPending[currentIndex] isEqual:model]) {
    NSLog(@"FetchedResultsController: index list corrupted");
    return;
  }

  [_resultsPending removeObjectAtIndex:currentIndex];

  newIndex = [self _insertionIndexOfObject:model];

  [_resultsPending insertObject:model atIndex:newIndex];

  if (currentIndex != newIndex) {

    // MOVE

    changeType = FetchedResultsChangeMove;
  }
  else {

    // UPDATE

    changeType = FetchedResultsChangeUpdate;
  }

  [self _fireChangeType:changeType
                 object:model
                  index:currentIndex
               newIndex:newIndex
             applicator:^(Model *model) {
    [_results removeObjectAtIndex:currentIndex];
    [_results insertObject:model atIndex:newIndex];
  }];

}

-(void) processDelete:(Model *)model
{
  NSUInteger currentIndex;

  currentIndex = [_resultsPending indexOfObject:model];
  if (currentIndex == NSNotFound) {
    NSLog(@"FetchedResultsController: delete of untracked object");
    return;
  }

  [_resultsPending removeObjectAtIndex:currentIndex];

  [self _fireChangeType:FetchedResultsChangeDelete
                 object:model
                  index:currentIndex
               newIndex:NSNotFound
             applicator:^(Model *model) {
    [_results removeObjectAtIndex:currentIndex];
  }];

}

-(NSUInteger) _insertionIndexOfObject:(id)object
{
  NSRange indexRange = {0, _resultsPending.count};

  return [_resultsPending indexOfObject:object
                          inSortedRange:indexRange
                                options:NSBinarySearchingInsertionIndex
                        usingComparator:_sortComparator];
}

-(void) _fireWillChange
{
  if ([self.delegate respondsToSelector:@selector(controllerWillChangeResults:)]) {
    dispatch_async(_dispatchQueue, ^{
      [self.delegate controllerWillChangeResults:self];
    });
  }
}

-(void) _fireChangeType:(FetchedResultsChangeType)type object:(Model *)object index:(NSUInteger)index newIndex:(NSUInteger)newIndex applicator:(void (^)(Model *object))applicator
{
  dispatch_sync(dispatch_get_main_queue(), ^{
    
    Model *result = _request.liveResults ? [_dao refreshObject:object] : object;
    
    applicator(result);

    if ([self.delegate respondsToSelector:@selector(controller:didChangeObject:atIndex:forChangeType:newIndex:)]) {
      dispatch_async(_dispatchQueue, ^{
        [self.delegate controller:self
                  didChangeObject:result
                          atIndex:index
                    forChangeType:type
                         newIndex:newIndex];
      });
    }

  });

}

-(void) _fireDidChange
{
  if ([self.delegate respondsToSelector:@selector(controllerDidChangeResults:)]) {
    dispatch_async(_dispatchQueue, ^{
      [self.delegate controllerDidChangeResults:self];
    });
  }
}

@end



NSComparisonResult sortObjects(NSArray *sortDescriptors, id obj1, id obj2)
{
  NSEnumerator *sortDescriptorEnum = [sortDescriptors objectEnumerator];

  NSComparisonResult result = NSOrderedSame;
  NSSortDescriptor *sortDescriptor;
  while (result == NSOrderedSame && (sortDescriptor = [sortDescriptorEnum nextObject])) {
    result = [sortDescriptor compareObject:obj1 toObject:obj2];
  }

  return result;
}
