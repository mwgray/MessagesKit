//
//  RTFetchedResultsController.m
//  ReTxt
//
//  Created by Kevin Wooten on 7/12/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTFetchedResultsController.h"

#import "RTDAO.h"
#import "NSArray+Utils.h"


@implementation RTFetchRequest

@end



typedef BOOL (*InstanceCheck)(id, SEL, id);

NSComparisonResult sortObjects(NSArray *sortDescriptors, id obj1, id obj2);



@interface RTFetchedResultsController () <RTDBManagerDelegate> {
  RTDBManager *_dbManager;
  RTFetchRequest *_request;
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


@implementation RTFetchedResultsController

-(instancetype) initWithDBManager:(RTDBManager *)dbManager request:(RTFetchRequest *)request
{
  if ((self = [super init])) {
    _dbManager = dbManager;
    _request = request;
    _changeSet = [NSMutableArray array];
    _queue = dispatch_queue_create("RTFetchedResultsController Processing Queue", DISPATCH_QUEUE_SERIAL);
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

    __unsafe_unretained RTFetchedResultsController *weakSelf = self;

    _sortComparator = ^NSComparisonResult (id obj1, id obj2) {
      return sortObjects(weakSelf->_request.sortDescriptors, obj1, obj2);
    };

  }
  else {

    _sortComparator = ^NSComparisonResult (id obj1, id obj2) {
      return [obj1 compare:obj2];
    };
  }

  RTDAO *dao = [_dbManager daoForClass:_request.resultClass];

  NSError *error = nil;
  NSArray *results = [dao fetchAllObjectsMatching:_request.predicate
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

-(void) modelObjectsWillChangeInDAO:(RTDAO *)dao
{
  @synchronized(self) {

    _changeSet = [NSMutableArray array];

  }
}

-(void) modelObject:(RTModel *)model insertedInDAO:(RTDAO *)dao
{
  if (!_isMatchingInstance(model, _isMatchingInstanceSEL, _request.resultClass)) {
    return;
  }

  if (![_request.predicate evaluateWithObject:model]) {
    return;
  }

  @synchronized(self) {

    [_changeSet addObject:@[@0, model]];

  }
}


-(void) modelObject:(RTModel *)model updatedInDAO:(RTDAO *)dao
{

  if (!_isMatchingInstance(model, _isMatchingInstanceSEL, _request.resultClass)) {
    return;
  }

  if (![_request.predicate evaluateWithObject:model]) {
    return;
  }

  @synchronized(self) {

    [_changeSet addObject:@[@1, model]];

  }
}

-(void) modelObject:(RTModel *)model deletedInDAO:(RTDAO *)dao
{
  if (!_isMatchingInstance(model, _isMatchingInstanceSEL, _request.resultClass)) {
    return;
  }

  if (![_request.predicate evaluateWithObject:model]) {
    return;
  }

  @synchronized(self) {

    [_changeSet addObject:@[@2, model]];

  }
}

-(void) modelObjectsDidChangeInDAO:(RTDAO *)dao
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

    });

  }
}

-(void) processInsert:(RTModel *)model
{
  NSUInteger insertionIndex;

  insertionIndex = [self _insertionIndexOfObject:model];

  [_resultsPending insertObject:model atIndex:insertionIndex];

  [self _fireChangeType:RTFetchedResultsChangeInsert
                 object:model
                  index:NSNotFound
               newIndex:insertionIndex
             applicator:^{
    [_results insertObject:model atIndex:insertionIndex];
  }];

}

-(void) processUpdate:(RTModel *)model
{
  NSUInteger currentIndex, newIndex;
  RTFetchedResultsChangeType changeType;

  currentIndex = [_resultsPending indexOfObject:model];
  if (currentIndex == NSNotFound) {
    [self processInsert:model];
    return;
  }

  if (![_resultsPending[currentIndex] isEqual:model]) {
    NSLog(@"RTFetchedResultsController: index list corrupted");
    return;
  }

  [_resultsPending removeObjectAtIndex:currentIndex];

  newIndex = [self _insertionIndexOfObject:model];

  [_resultsPending insertObject:model atIndex:newIndex];

  if (currentIndex != newIndex) {

    // MOVE

    changeType = RTFetchedResultsChangeMove;
  }
  else {

    // UPDATE

    changeType = RTFetchedResultsChangeUpdate;
  }

  [self _fireChangeType:changeType
                 object:model
                  index:currentIndex
               newIndex:newIndex
             applicator:^{
    [_results removeObjectAtIndex:currentIndex];
    [_results insertObject:model atIndex:newIndex];
  }];

}

-(void) processDelete:(RTModel *)model
{
  NSUInteger currentIndex;

  currentIndex = [_resultsPending indexOfObject:model];
  if (currentIndex == NSNotFound) {
    NSLog(@"RTFetchedResultsController: delete of untracked object");
    return;
  }

  [_resultsPending removeObjectAtIndex:currentIndex];

  [self _fireChangeType:RTFetchedResultsChangeDelete
                 object:model
                  index:currentIndex
               newIndex:NSNotFound
             applicator:^{
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

-(void) _fireChangeType:(RTFetchedResultsChangeType)type object:(id)object index:(NSUInteger)index newIndex:(NSUInteger)newIndex applicator:(void (^)())applicator
{
  dispatch_sync(dispatch_get_main_queue(), ^{

    applicator();

    if ([self.delegate respondsToSelector:@selector(controller:didChangeObject:atIndex:forChangeType:newIndex:)]) {
      dispatch_async(_dispatchQueue, ^{
        [self.delegate controller:self
                  didChangeObject:object
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
