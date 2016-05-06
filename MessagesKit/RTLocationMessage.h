//
//  RTLocationMessage.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessage.h"


extern const CGSize kRTLocationMessageThumbnailSize;

NS_ASSUME_NONNULL_BEGIN


@interface RTLocationMessage : RTMessage

@property (assign, nonatomic) double latitude;
@property (assign, nonatomic) double longitude;
@property (retain, nullable, nonatomic) NSString *title;
@property (retain, nullable, nonatomic) NSData *thumbnailData;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat NS_UNAVAILABLE;

-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat longitude:(double)longitude latitude:(double)latitude NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithChat:(RTChat *)chat longitude:(double)longitude latitude:(double)latitude;

+(void) generateThumbnailData:(RTLocationMessage *)msg completion:(void (^)(NSData *_Nonnull data, NSError *_Nullable error))completionBlock;

@end


NS_ASSUME_NONNULL_END
