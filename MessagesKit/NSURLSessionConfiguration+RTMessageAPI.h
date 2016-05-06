//
//  NSURLSessionConfiguration+RTMessageAPI.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/6/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "RTMessages.h"


NS_ASSUME_NONNULL_BEGIN


@protocol TProtocolFactory;


@interface NSURLSessionConfiguration (RTMessageAPI)

+(instancetype) clientSessionCofigurationWithProtcolFactory:(id<TProtocolFactory>)protocolFactory;
+(instancetype) backgroundSessionConfigurationWithUserId:(RTId *)userId;

@end


NS_ASSUME_NONNULL_END
