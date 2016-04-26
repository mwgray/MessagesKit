//
//  RTImageMessage.h
//  ReTxt
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessage.h"


NS_ASSUME_NONNULL_BEGIN


@interface RTImageMessage : RTMessage

@property (retain, nonatomic, nullable) id<DataReference> thumbnailData;
@property (assign, nonatomic) CGSize thumbnailSize;

@property (retain, nonatomic, nullable) id<DataReference> data;
@property (copy, nonatomic, nullable) NSString *dataMimeType;

@property (nonatomic, readonly) id<DataReference> thumbnailOrImageData;

+(id<DataReference>) generateThumbnailWithData:(id<DataReference>)imageData size:(CGSize *)outPointSize;

-(BOOL) isEquivalentToImageMessage:(RTImageMessage *)imageMessage;

@end


NS_ASSUME_NONNULL_END
