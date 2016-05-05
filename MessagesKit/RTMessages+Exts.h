//
//  RTMessages+Exts.h
//  ReTxt
//
//  Created by Kevin Wooten on 12/13/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessages.h"


NS_ASSUME_NONNULL_BEGIN



@interface RTId (Exts)

+(RTId *) null;
+(RTId *) generate;
+(RTId *) idWithString:(NSString *)string;
+(RTId *) idWithUUID:(NSUUID *)uuid;
+(RTId *) idWithData:(NSData *)data;

-(nullable instancetype) initWithString:(NSString *)string;
-(instancetype) initWithUUID:(NSUUID *)uuid;

-(BOOL) isNull;

-(NSString *) UUIDString;
-(NSComparisonResult) compare:(RTId *)other;

@end



@interface RTUserInfo (Exts)

@property (nonatomic, readonly) NSData *fingerprint;

@end



NS_ASSUME_NONNULL_END
