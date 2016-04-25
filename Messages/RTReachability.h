//
//  RTReachability.h
//  ReTxt
//
//  Created by Kevin Wooten on 7/21/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;


extern NSString *RTNetworkConnectivityAvailableNotification;
extern NSString *RTNetworkConnectivityUnavailableNotification;


@interface RTReachability : NSObject

+(void) start;
+(void) stop;

@end
