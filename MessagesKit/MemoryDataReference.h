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

@property(readonly) NSData *data;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithData:(NSData *)data ofMIMEType:(NSString *)MIMEType NS_DESIGNATED_INITIALIZER;

@end


NS_ASSUME_NONNULL_END
