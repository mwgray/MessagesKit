//
//  RTVideoMessage.h
//  ReTxt
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessage.h"


NS_ASSUME_NONNULL_BEGIN


@interface RTVideoMessage : RTMessage

@property (retain, nonatomic) id<DataReference> thumbnailData;
@property (assign, nonatomic) CGSize thumbnailSize;

@property (retain, nonatomic) id<DataReference> data;
@property (copy, nonatomic) NSString *dataMimeType;

-(BOOL) isEquivalentToVideoMessage:(RTVideoMessage *)videoMessage;

+(nullable id<DataReference>) generateThumbnailWithData:(id<DataReference>)videoData atFrameTime:(NSString *)frameTime size:(CGSize *)size error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
