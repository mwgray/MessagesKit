//
//  NetworkConnectivity.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/21/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "NetworkConnectivity.h"

#import "ServerAPI.h"
#import "Reachability.h"
#import "Log.h"


CL_DECLARE_LOG_LEVEL()


NSString *NetworkConnectivityAvailableNotification = @"NetworkConnectivityAvailable";
NSString *NetworkConnectivityUnavailableNotification = @"NetworkConnectivityUnavailable";


@interface NetworkConnectivity ()

@property (strong, nonatomic) Reachability *reachability;

@end


@implementation NetworkConnectivity

static NetworkConnectivity *_s_instance;

+(void) initialize
{
  _s_instance = [self new];
}

+(void) start
{
  [_s_instance.reachability startNotifier];
}

+(void) stop
{
  [_s_instance.reachability stopNotifier];
}

-(instancetype) init
{
  self = [super init];
  if (self) {

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];

    _reachability = [Reachability reachabilityWithHostName:@"master.retxt.io"];
    
  }
  return self;
}

-(void) reachabilityChanged:(NSNotification *)note
{
  NetworkStatus netStatus = [self.reachability currentReachabilityStatus];
  BOOL available = NO;
  switch (netStatus) {
  case NotReachable:
    DDLogWarn(@"Network Not Reachable");
    break;

  case ReachableViaWiFi:
    DDLogWarn(@"Network Reachable (WiFi)");
    available = YES;
    break;

  case ReachableViaWWAN:
    DDLogWarn(@"Network Reachable (WWAN)");
    available = YES;
    break;

  default:
    break;
  }

  if (available) {
    [[NSNotificationCenter defaultCenter] postNotificationName:NetworkConnectivityAvailableNotification object:self];
  }
  else {
    [[NSNotificationCenter defaultCenter] postNotificationName:NetworkConnectivityUnavailableNotification object:self];
  }

}

@end
