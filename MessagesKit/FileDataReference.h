//
//  FileDataReference.h
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "DataReference.h"


NS_ASSUME_NONNULL_BEGIN


@interface FileDataReference : NSObject <DataReference>

@property(copy, nonatomic) NSString *path;
@property(copy, nonatomic) NSURL *URL;

-(instancetype) initWithPath:(NSString *)path;

+(nullable instancetype) copyFrom:(id<DataReference>)source toPath:(NSString *)path filteredBy:(nullable DataReferenceFilter)filter error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
