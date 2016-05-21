//
//  URLDataReference.h
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "DataReference.h"


NS_ASSUME_NONNULL_BEGIN


/*
 * URLDataReference
 *
 * Reference to data stored in a location referenced by a URL
 */
@interface URLDataReference : NSObject <DataReference>

@property(readonly) NSURL *URL;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithURL:(NSURL *)url NS_DESIGNATED_INITIALIZER;

-(NSInputStream *) openInputStreamAndReturnError:(NSError **)error;

-(BOOL) removeAndReturnError:(NSError * _Nullable __autoreleasing *)error;

@end


NS_ASSUME_NONNULL_END
