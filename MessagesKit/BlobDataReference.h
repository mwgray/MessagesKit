//
//  BlobDataReference.h
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "DataReference.h"
#import "RTDBManager.h"


NS_ASSUME_NONNULL_BEGIN


@interface BlobDataReference : NSObject <DataReference>

@property(retain, nonatomic) RTDBManager *db;
@property(copy, nonatomic) NSString *owner;

@property(readonly, nonatomic) NSString *dbName;
@property(readonly, nonatomic) NSString *tableName;
@property(readonly, nonatomic) SInt64 blobId;

+(nullable instancetype) copyFrom:(id<DataReference>)source toOwner:(NSString *)owner forTable:(NSString *)tableName inDatabase:(NSString *)dbName using:(RTDBManager *)db filteredBy:(nullable DataReferenceFilter)filter error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
