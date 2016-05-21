//
//  ExternalFileDataReference.h
//  MessagesKit
//
//  Created by Kevin Wooten on 5/20/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

#import "DataReference.h"
#import "DBManager.h"


NS_ASSUME_NONNULL_BEGIN


@interface ExternalFileDataReference : NSObject<DataReference>

@property(readonly) DBManager *dbManager;
@property(readonly) NSString *fileName;
@property(readonly) NSURL *URL;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithDBManager:(DBManager *)dbManager fileName:(NSString *)fileName NS_DESIGNATED_INITIALIZER;

@end


NS_ASSUME_NONNULL_END
