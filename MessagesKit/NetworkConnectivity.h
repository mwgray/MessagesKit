//
//  NetworkConnectivity.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/21/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;


extern NSString *NetworkConnectivityAvailableNotification;
extern NSString *NetworkConnectivityUnavailableNotification;


@interface NetworkConnectivity : NSObject

+(void) start;
+(void) stop;

@end
