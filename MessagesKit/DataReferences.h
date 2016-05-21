//
//  DataReferences.h
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "DataReference.h"
#import "URLDataReference.h"


NS_ASSUME_NONNULL_BEGIN


@interface DataReferences : NSObject

@property(readonly) DataReferenceFilter copyFilter;

+(BOOL) filterStreamsWithInput:(id<DataInputStream>)inputStream output:(id<DataOutputStream>)outputStream usingFilter:(nullable DataReferenceFilter)filter error:(NSError **)error;
+(nullable NSData *) readAllDataFromReference:(nullable id<DataReference>)source error:(NSError **)error;
+(nullable NSURL *) saveDataReferenceToTemporaryURL:(id<DataReference>)source error:(NSError **)error;

+(BOOL) isDataReference:(id<DataReference>)aref equivalentToDataReference:(id<DataReference>)bref;

@end


NS_ASSUME_NONNULL_END
