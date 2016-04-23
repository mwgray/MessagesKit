//
//  RTImageMessage.h
//  ReTxt
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessage.h"


@interface RTImageMessage : RTMessage

@property (nonatomic, retain) id<DataReference> thumbnailData;
@property (nonatomic, assign) CGSize thumbnailSize;

@property (nonatomic, retain) id<DataReference> data;
@property (nonatomic, retain) NSString *dataMimeType;

@property (nonatomic, readonly) id<DataReference> thumbnailOrImageData;

+(id<DataReference>) generateThumbnailWithData:(id<DataReference>)imageData size:(CGSize *)outPointSize;

-(BOOL) isEquivalentToImageMessage:(RTImageMessage *)imageMessage;

@end
