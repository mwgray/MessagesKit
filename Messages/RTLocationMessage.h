//
//  RTLocationMessage.h
//  ReTxt
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessage.h"


extern const CGSize kRTLocationMessageThumbnailSize;

NS_ASSUME_NONNULL_BEGIN


@interface RTLocationMessage : RTMessage

@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@property (nonatomic, retain, nullable) NSString *title;
@property (nonatomic, retain, nullable) NSData *thumbnailData;

+(void) generateThumbnailData:(RTLocationMessage *)msg completion:(void (^)(NSData *_Nonnull data, NSError *_Nullable error))completionBlock;

@end


NS_ASSUME_NONNULL_END
