//
//  FetchedResultsController.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/12/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "DBManager.h"


@class FetchedResultsController;


NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM (NSInteger, FetchedResultsChangeType) {
  FetchedResultsChangeInsert = 1,
  FetchedResultsChangeDelete = 2,
  FetchedResultsChangeMove   = 3,
  FetchedResultsChangeUpdate = 4
};


@protocol FetchedResultsControllerDelegate <NSObject>

@optional

-(void) controllerWillChangeResults:(FetchedResultsController *)controller;

-(void) controller:(FetchedResultsController *)controller
   didChangeObject:(id)object
           atIndex:(NSInteger)index
     forChangeType:(FetchedResultsChangeType)changeType
          newIndex:(NSInteger)newIndex;

-(void) controllerDidChangeResults:(FetchedResultsController *)controller;

@end


@interface FetchRequest : NSObject

@property (weak, nonatomic) Class resultClass;
@property (strong, nonatomic) NSPredicate *predicate;
@property (assign, nonatomic) BOOL includeSubentities;
@property (assign, nonatomic) NSUInteger fetchOffset;
@property (assign, nonatomic) NSUInteger fetchLimit;
@property (assign, nonatomic) NSUInteger fetchBatchSize;
@property (strong, nonatomic) NSArray *sortDescriptors;
@property (assign, nonatomic) BOOL liveResults;

@end


@interface FetchedResultsController : NSObject

-(instancetype) initWithDBManager:(DBManager *)dbManager request:(FetchRequest *)request;

@property (readonly, nonatomic) FetchRequest *request;

@property (assign, nonatomic) NSInteger cacheSize;

@property (weak, nonatomic, nullable) NSObject<FetchedResultsControllerDelegate> *delegate;

-(BOOL) executeAndReturnError:(NSError **)error;

-(NSInteger) numberOfObjects;
-(NSInteger) lastIndex;

-(id) objectAtIndex:(NSInteger)index;
-(id) objectAtIndexedSubscript:(NSInteger)idx;

@end


NS_ASSUME_NONNULL_END
