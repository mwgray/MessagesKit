//
//  Settings.m
//  MessagesKit
//
//  Created by Kevin Wooten on 1/19/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

#import "Settings.h"


NSString *SettingPrivacyShowPreviewsName = @"io.retxt.privacy.showPreviews";
BOOL SettingPrivacyShowPreviewsDefault = YES;

NSString *SettingPrivacyConnectionsEnabledName = @"io.retxt.privacy.connections.enabled";
BOOL SettingPrivacyConnectionsEnabledDefault = YES;

NSString *SettingPrivacyConnectionsReportedName = @"io.retxt.privacy.connections.reported";


NSString *SettingsReferralAttributedName = @"io.retxt.referral.attributed";
NSString *SettingsReferralSourceName = @"io.retxt.referral.source";
NSString *SettingsReferralCampaignName = @"io.retxt.referral.campaign";
NSString *SettingsReferralGenerationName = @"io.retxt.referral.generation";


NSString *SettingsViralUseInviterName = @"io.retxt.viral.useInviter";
BOOL SettingsViralUseInviterDefault = YES;



@interface Settings () {
  NSUserDefaults *_defaults;
}

@end


@implementation Settings

static Settings *instance;

+(void) initialize
{
  instance = [Settings new];
}

+(Settings *) sharedSettings
{
  return instance;
}

-(instancetype) init
{
  self = [super init];
  if (self) {

    _defaults = NSUserDefaults.standardUserDefaults;

    // Set default values

    if (![_defaults objectForKey:SettingPrivacyShowPreviewsName]) {
      [self setPrivacyShowPreviews:SettingPrivacyShowPreviewsDefault];
    }

    if (![_defaults objectForKey:SettingPrivacyConnectionsEnabledName]) {
      [self setPrivacyConnectionsEnabled:SettingPrivacyConnectionsEnabledDefault];
    }

    if (![_defaults objectForKey:SettingsViralUseInviterName]) {
      [self setViralUserInviter:SettingsViralUseInviterDefault];
    }

    if (![_defaults objectForKey:SettingsReferralSourceName]) {
      [self setReferralSource:@""];
    }

    if (![_defaults objectForKey:SettingsReferralCampaignName]) {
      [self setReferralCampaign:@""];
    }

  }

  return self;
}

-(BOOL) privacyShowPreviews
{
  return [_defaults boolForKey:SettingPrivacyShowPreviewsName];
}

-(void) setPrivacyShowPreviews:(BOOL)privacyShowPreviews
{
  [_defaults setBool:privacyShowPreviews forKey:SettingPrivacyShowPreviewsName];
}

-(BOOL) privacyConnectionsEnabled
{
  return [_defaults boolForKey:SettingPrivacyConnectionsEnabledName];
}

-(void) setPrivacyConnectionsEnabled:(BOOL)privacyConnectionsEnabled
{
  [_defaults setBool:privacyConnectionsEnabled forKey:SettingPrivacyConnectionsEnabledName];
}

-(NSDate *) privacyConnectionsReported
{
  return [_defaults objectForKey:SettingPrivacyConnectionsReportedName];
}

-(void) setPrivacyConnectionsReported:(NSDate *)privacyConnectionsReported
{
  [_defaults setObject:privacyConnectionsReported forKey:SettingPrivacyConnectionsReportedName];
}

-(BOOL) referralAttributed
{
  return [_defaults boolForKey:SettingsReferralAttributedName];
}

-(void) setReferralAttributed:(BOOL)referralAttributed
{
  [_defaults setBool:referralAttributed forKey:SettingsReferralAttributedName];
}

-(NSString *) referralSource
{
  return [_defaults stringForKey:SettingsReferralSourceName];
}

-(void) setReferralSource:(NSString *)referralSource
{
  [_defaults setObject:referralSource forKey:SettingsReferralSourceName];
}

-(NSString *) referralCampaign
{
  return [_defaults stringForKey:SettingsReferralCampaignName];
}

-(void) setReferralCampaign:(NSString *)referralCampaign
{
  [_defaults setObject:referralCampaign forKey:SettingsReferralCampaignName];
}

-(NSUInteger) referralGeneration
{
  return [_defaults integerForKey:SettingsReferralGenerationName];
}

-(void) setReferralGeneration:(NSUInteger)referralGeneration
{
  [_defaults setInteger:referralGeneration forKey:SettingsReferralGenerationName];
}

-(BOOL) viralUserInviter
{
  return [_defaults boolForKey:SettingsViralUseInviterName];
}

-(void) setViralUserInviter:(BOOL)viralUserInviter
{
  [_defaults setBool:viralUserInviter forKey:SettingsViralUseInviterName];
}

-(void) save
{
  [_defaults synchronize];
}

@end
