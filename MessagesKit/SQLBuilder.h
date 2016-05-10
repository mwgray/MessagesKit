//
//  SQLBuilder.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/14/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;


@interface SQLBuilder : NSObject

@property (nonatomic, strong) NSString *selectFields;
@property (nonatomic, readonly) NSDictionary *parameters;

-(instancetype) initWithRootClass:(NSString *)rootClassName tableNames:(NSDictionary *)tableNames;

-(NSString *) processPredicate:(NSPredicate *)predicate sortedBy:(NSArray<NSSortDescriptor *> *)sortDescriptors offset:(NSUInteger)offset limit:(NSUInteger)limit;

@end

