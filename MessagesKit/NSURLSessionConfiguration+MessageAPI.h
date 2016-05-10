//
//  NSURLSessionConfiguration+MessageAPI.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/6/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "Messages.h"


NS_ASSUME_NONNULL_BEGIN


@protocol TProtocolFactory;


@interface NSURLSessionConfiguration (MessageAPI)

+(instancetype) clientSessionCofigurationWithProtcolFactory:(id<TProtocolFactory>)protocolFactory;
+(instancetype) backgroundSessionConfigurationWithUserId:(Id *)userId;

@end


NS_ASSUME_NONNULL_END
