//
//  RTFetchedResultsController.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/12/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTDBManager.h"


@class RTFetchedResultsController;


NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM (NSInteger, RTFetchedResultsChangeType) {
  RTFetchedResultsChangeInsert = 1,
  RTFetchedResultsChangeDelete = 2,
  RTFetchedResultsChangeMove   = 3,
  RTFetchedResultsChangeUpdate = 4
};


@protocol RTFetchedResultsControllerDelegate <NSObject>

@optional

-(void) controllerWillChangeResults:(RTFetchedResultsController *)controller;

-(void) controller:(RTFetchedResultsController *)controller
   didChangeObject:(id)object
           atIndex:(NSInteger)index
     forChangeType:(RTFetchedResultsChangeType)changeType
          newIndex:(NSInteger)newIndex;

-(void) controllerDidChangeResults:(RTFetchedResultsController *)controller;

@end


@interface RTFetchRequest : NSObject

@property (weak, nonatomic) Class resultClass;
@property (strong, nonatomic) NSPredicate *predicate;
@property (assign, nonatomic) BOOL includeSubentities;
@property (assign, nonatomic) NSUInteger fetchOffset;
@property (assign, nonatomic) NSUInteger fetchLimit;
@property (assign, nonatomic) NSUInteger fetchBatchSize;
@property (strong, nonatomic) NSArray *sortDescriptors;

@end


@interface RTFetchedResultsController : NSObject

-(instancetype) initWithDBManager:(RTDBManager *)dbManager request:(RTFetchRequest *)request;

@property (readonly, nonatomic) RTFetchRequest *request;

@property (assign, nonatomic) NSInteger cacheSize;

@property (weak, nonatomic, nullable) NSObject<RTFetchedResultsControllerDelegate> *delegate;

-(void) execute;

-(NSInteger) numberOfObjects;
-(NSInteger) lastIndex;

-(id) objectAtIndex:(NSInteger)index;
-(id) objectAtIndexedSubscript:(NSInteger)idx;

@end


NS_ASSUME_NONNULL_END
