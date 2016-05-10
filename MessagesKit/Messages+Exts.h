//
//  Messages+Exts.h
//  MessagesKit
//
//  Created by Kevin Wooten on 12/13/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "Messages.h"


NS_ASSUME_NONNULL_BEGIN



@interface Id (Exts)

+(Id *) null;
+(Id *) generate;
+(Id *) idWithString:(NSString *)string;
+(Id *) idWithUUID:(NSUUID *)uuid;
+(Id *) idWithData:(NSData *)data;

-(nullable instancetype) initWithString:(NSString *)string;
-(instancetype) initWithUUID:(NSUUID *)uuid;

-(BOOL) isNull;

-(NSString *) UUIDString;
-(NSComparisonResult) compare:(Id *)other;

@end



@interface UserInfo (Exts)

@property (nonatomic, readonly) NSData *fingerprint;

@end



NS_ASSUME_NONNULL_END
