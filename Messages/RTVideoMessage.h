//
//  RTVideoMessage.h
//  ReTxt
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessage.h"


@interface RTVideoMessage : RTMessage

@property (nonatomic, retain) id<DataReference> thumbnailData;
@property (nonatomic, assign) CGSize thumbnailSize;

@property (nonatomic, retain) id<DataReference> data;
@property (nonatomic, retain) NSString *dataMimeType;

-(BOOL) isEquivalentToVideoMessage:(RTVideoMessage *)videoMessage;

@end
