//
//  RTSettings.m
//  ReTxt
//
//  Created by Kevin Wooten on 1/19/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTSettings.h"


NSString *RTSettingPrivacyShowPreviewsName = @"io.retxt.privacy.showPreviews";
BOOL RTSettingPrivacyShowPreviewsDefault = YES;

NSString *RTSettingPrivacyConnectionsEnabledName = @"io.retxt.privacy.connections.enabled";
BOOL RTSettingPrivacyConnectionsEnabledDefault = YES;

NSString *RTSettingPrivacyConnectionsReportedName = @"io.retxt.privacy.connections.reported";


NSString *RTSettingsReferralAttributedName = @"io.retxt.referral.attributed";
NSString *RTSettingsReferralSourceName = @"io.retxt.referral.source";
NSString *RTSettingsReferralCampaignName = @"io.retxt.referral.campaign";
NSString *RTSettingsReferralGenerationName = @"io.retxt.referral.generation";


NSString *RTSettingsViralUseInviterName = @"io.retxt.viral.useInviter";
BOOL RTSettingsViralUseInviterDefault = YES;



@interface RTSettings () {
  NSUserDefaults *_defaults;
}

@end


@implementation RTSettings

static RTSettings *instance;

+(void) initialize
{
  instance = [RTSettings new];
}

+(RTSettings *) sharedSettings
{
  return instance;
}

-(instancetype) init
{
  self = [super init];
  if (self) {

    _defaults = NSUserDefaults.standardUserDefaults;

    // Set default values

    if (![_defaults objectForKey:RTSettingPrivacyShowPreviewsName]) {
      [self setPrivacyShowPreviews:RTSettingPrivacyShowPreviewsDefault];
    }

    if (![_defaults objectForKey:RTSettingPrivacyConnectionsEnabledName]) {
      [self setPrivacyConnectionsEnabled:RTSettingPrivacyConnectionsEnabledDefault];
    }

    if (![_defaults objectForKey:RTSettingsViralUseInviterName]) {
      [self setViralUserInviter:RTSettingsViralUseInviterDefault];
    }

    if (![_defaults objectForKey:RTSettingsReferralSourceName]) {
      [self setReferralSource:@""];
    }

    if (![_defaults objectForKey:RTSettingsReferralCampaignName]) {
      [self setReferralCampaign:@""];
    }

  }

  return self;
}

-(BOOL) privacyShowPreviews
{
  return [_defaults boolForKey:RTSettingPrivacyShowPreviewsName];
}

-(void) setPrivacyShowPreviews:(BOOL)privacyShowPreviews
{
  [_defaults setBool:privacyShowPreviews forKey:RTSettingPrivacyShowPreviewsName];
}

-(BOOL) privacyConnectionsEnabled
{
  return [_defaults boolForKey:RTSettingPrivacyConnectionsEnabledName];
}

-(void) setPrivacyConnectionsEnabled:(BOOL)privacyConnectionsEnabled
{
  [_defaults setBool:privacyConnectionsEnabled forKey:RTSettingPrivacyConnectionsEnabledName];
}

-(NSDate *) privacyConnectionsReported
{
  return [_defaults objectForKey:RTSettingPrivacyConnectionsReportedName];
}

-(void) setPrivacyConnectionsReported:(NSDate *)privacyConnectionsReported
{
  [_defaults setObject:privacyConnectionsReported forKey:RTSettingPrivacyConnectionsReportedName];
}

-(BOOL) referralAttributed
{
  return [_defaults boolForKey:RTSettingsReferralAttributedName];
}

-(void) setReferralAttributed:(BOOL)referralAttributed
{
  [_defaults setBool:referralAttributed forKey:RTSettingsReferralAttributedName];
}

-(NSString *) referralSource
{
  return [_defaults stringForKey:RTSettingsReferralSourceName];
}

-(void) setReferralSource:(NSString *)referralSource
{
  [_defaults setObject:referralSource forKey:RTSettingsReferralSourceName];
}

-(NSString *) referralCampaign
{
  return [_defaults stringForKey:RTSettingsReferralCampaignName];
}

-(void) setReferralCampaign:(NSString *)referralCampaign
{
  [_defaults setObject:referralCampaign forKey:RTSettingsReferralCampaignName];
}

-(NSUInteger) referralGeneration
{
  return [_defaults integerForKey:RTSettingsReferralGenerationName];
}

-(void) setReferralGeneration:(NSUInteger)referralGeneration
{
  [_defaults setInteger:referralGeneration forKey:RTSettingsReferralGenerationName];
}

-(BOOL) viralUserInviter
{
  return [_defaults boolForKey:RTSettingsViralUseInviterName];
}

-(void) setViralUserInviter:(BOOL)viralUserInviter
{
  [_defaults setBool:viralUserInviter forKey:RTSettingsViralUseInviterName];
}

-(void) save
{
  [_defaults synchronize];
}

@end
