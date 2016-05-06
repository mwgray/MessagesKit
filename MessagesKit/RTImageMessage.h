//
//  RTImageMessage.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessage.h"


NS_ASSUME_NONNULL_BEGIN


@interface RTImageMessage : RTMessage

@property (retain, nullable, nonatomic) id<DataReference> thumbnailData;
@property (assign, nonatomic) CGSize thumbnailSize;

@property (retain, nonatomic) id<DataReference> data;
@property (copy, nonatomic) NSString *dataMimeType;

@property (nonatomic, readonly) id<DataReference> thumbnailOrImageData;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat NS_UNAVAILABLE;

-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat data:(id<DataReference>)data mimeType:(NSString *)mimeType thumbnailData:(nullable id<DataReference>)thumbnailData NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithId:(RTId *)id chat:(RTChat *)chat data:(id<DataReference>)data mimeType:(NSString *)mimeType;
-(instancetype) initWithChat:(RTChat *)chat data:(id<DataReference>)data mimeType:(NSString *)mimeType thumbnailData:(nullable id<DataReference>)thumbnailData;
-(instancetype) initWithChat:(RTChat *)chat data:(id<DataReference>)data mimeType:(NSString *)mimeType;

-(BOOL) isEquivalentToImageMessage:(RTImageMessage *)imageMessage;

+(nullable id<DataReference>) generateThumbnailWithData:(id<DataReference>)imageData size:(CGSize *)outPointSize error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
