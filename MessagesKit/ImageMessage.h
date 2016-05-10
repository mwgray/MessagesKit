//
//  ImageMessage.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Message.h"


NS_ASSUME_NONNULL_BEGIN


@interface ImageMessage : Message

@property (retain, nullable, nonatomic) id<DataReference> thumbnailData;
@property (assign, nonatomic) CGSize thumbnailSize;

@property (retain, nonatomic) id<DataReference> data;
@property (copy, nonatomic) NSString *dataMimeType;

@property (nonatomic, readonly) id<DataReference> thumbnailOrImageData;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithId:(Id *)id chat:(Chat *)chat NS_UNAVAILABLE;

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat data:(id<DataReference>)data mimeType:(NSString *)mimeType thumbnailData:(nullable id<DataReference>)thumbnailData NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithId:(Id *)id chat:(Chat *)chat data:(id<DataReference>)data mimeType:(NSString *)mimeType;
-(instancetype) initWithChat:(Chat *)chat data:(id<DataReference>)data mimeType:(NSString *)mimeType thumbnailData:(nullable id<DataReference>)thumbnailData;
-(instancetype) initWithChat:(Chat *)chat data:(id<DataReference>)data mimeType:(NSString *)mimeType;

-(BOOL) isEquivalentToImageMessage:(ImageMessage *)imageMessage;

+(nullable id<DataReference>) generateThumbnailWithData:(id<DataReference>)imageData size:(CGSize *)outPointSize error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
