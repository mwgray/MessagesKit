//
//  RTSettings.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/19/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;


NS_ASSUME_NONNULL_BEGIN


@interface RTSettings : NSObject

+(RTSettings *) sharedSettings;

@property(assign, nonatomic) BOOL privacyShowPreviews;

@property(assign, nonatomic) BOOL privacyConnectionsEnabled;
@property(nullable, assign, nonatomic) NSDate *privacyConnectionsReported;

@property (assign, nonatomic) BOOL referralAttributed;
@property (nullable, assign, nonatomic) NSString *referralSource;
@property (nullable, assign, nonatomic) NSString *referralCampaign;
@property (assign, nonatomic) NSUInteger referralGeneration;

@property (assign, nonatomic) BOOL viralUserInviter;

-(void) save;

@end


NS_ASSUME_NONNULL_END
