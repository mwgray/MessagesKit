//
//  DataReferences.h
//  Messages
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "DataReference.h"
#import "FileDataReference.h"


NS_ASSUME_NONNULL_BEGIN


@interface DataReferences : NSObject

+(DataReferenceFilter) copyFilter;

+(nullable NSData *) filterReference:(id<DataReference>)source intoMemoryUsingFilter:(nullable DataReferenceFilter)filter error:(NSError **)error;
+(BOOL) filterStreamsWithInput:(id<DataInputStream>)inputStream output:(id<DataOutputStream>)outputStream usingFilter:(nullable DataReferenceFilter)filter error:(NSError **)error;
+(nullable NSData *) readAllDataFromReference:(id<DataReference>)source error:(NSError **)error;
+(nullable FileDataReference *) duplicateDataReferenceToTemporaryFile:(id<DataReference>)source withExtension:(NSString *)extension error:(NSError **)error;

+(BOOL) isDataReference:(id<DataReference>)aref equivalentToDataReference:(id<DataReference>)bref;

@end


NS_ASSUME_NONNULL_END
