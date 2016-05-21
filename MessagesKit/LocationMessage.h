//
//  LocationMessage.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Message.h"


extern const CGSize kLocationMessageThumbnailSize;

NS_ASSUME_NONNULL_BEGIN


@interface LocationMessage : Message

@property (assign, nonatomic) double latitude;
@property (assign, nonatomic) double longitude;
@property (copy, nullable, nonatomic) NSString *title;
@property (copy, nullable, nonatomic) NSData *thumbnailData;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithId:(Id *)id chat:(Chat *)chat NS_UNAVAILABLE;

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat longitude:(double)longitude latitude:(double)latitude NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithChat:(Chat *)chat longitude:(double)longitude latitude:(double)latitude;

+(void) generateThumbnailData:(LocationMessage *)msg completion:(void (^)(NSData *_Nonnull data, NSError *_Nullable error))completionBlock;

@end


NS_ASSUME_NONNULL_END
