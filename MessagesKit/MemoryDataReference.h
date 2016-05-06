//
//  MemoryDataReference.h
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "DataReference.h"


NS_ASSUME_NONNULL_BEGIN


/*
 * MemoryDataReference
 *
 * Reference to data stored in memory
 */
@interface MemoryDataReference : NSObject <DataReference>

@property(readonly, nonatomic) NSData *data;

-(instancetype) initWithData:(NSData *)data;

+(nullable instancetype) copyFrom:(id<DataReference>)source filteredBy:(nullable DataReferenceFilter)filter error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
