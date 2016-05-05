//
//  RTCredentials.m
//  ReTxt
//
//  Created by Kevin Wooten on 7/15/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTCredentials.h"

#import "RTAsymmetricKeyPairGenerator.h"

#import "RTMessages+Exts.h"
#import "NSData+CommonDigest.h"
#import "NSData+Encoding.h"
#import "RTLog.h"

@import SSKeychain;


RT_LUMBERJACK_DECLARE_LOG_LEVEL()


static NSString *RTSecServiceCredentialsName  = @"io.retxt.credentials";
static NSString *RTSecServiceUserName  = @"io.retxt.user";
static NSString *RTSecAccountCurrentName  = @"current";

// Legacy value for user defaults
static NSString *RTAccountPreferenceName  = @"io.retxt.account";


@implementation RTCredentials

+(void) initialize
{
  [SSKeychain setAccessibilityType:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly];
}

-(instancetype) initWithRefreshToken:(NSData *)refreshToken userId:(RTId *)userId deviceId:(RTId *)deviceId
                          allAliases:(NSArray *)allAliases preferredAlias:(NSString *)preferredAlias
                  encryptionIdentity:(RTAsymmetricIdentity *)encryptionIdentity signingIdentity:(RTAsymmetricIdentity *)signingIdentity
                          authorized:(BOOL)authorized
{
  self = [super init];
  if (self) {
    
    _refreshToken = refreshToken;
    _userId = userId;
    _deviceId = deviceId;
    _allAliases = allAliases;
    _preferredAlias = preferredAlias;
    _encryptionIdentity = encryptionIdentity;
    _signingIdentity = signingIdentity;
    _authorized = authorized;
    
  }
  
  return self;
}

-(instancetype) initWithCoder:(NSCoder *)aDecoder
{
  self = [super init];
  if (self) {

    _refreshToken = [aDecoder decodeObjectOfClass:NSData.class forKey:@"refreshToken"];
    _userId = [aDecoder decodeObjectOfClass:RTId.class forKey:@"userId"];
    _deviceId = [aDecoder decodeObjectOfClass:RTId.class forKey:@"deviceId"];
    _allAliases = [aDecoder decodeObjectOfClass:NSArray.class forKey:@"allAliases"];
    _preferredAlias = [aDecoder decodeObjectOfClass:NSString.class forKey:@"preferredAlias"];
    _encryptionIdentity = [aDecoder decodeObjectOfClass:RTAsymmetricIdentity.class forKey:@"encryptionIdentity"];
    _signingIdentity = [aDecoder decodeObjectOfClass:RTAsymmetricIdentity.class forKey:@"signingIdentity"];
    _authorized = [aDecoder decodeBoolForKey:@"authorized"];

    if (!self.preferredAlias) {
      _preferredAlias = [self.allAliases firstObject];
    }

  }
  return self;
}

-(void) encodeWithCoder:(NSCoder *)aCoder
{
  [aCoder encodeObject:self.refreshToken forKey:@"refreshToken"];
  [aCoder encodeObject:self.userId forKey:@"userId"];
  [aCoder encodeObject:self.deviceId forKey:@"deviceId"];
  [aCoder encodeObject:self.allAliases forKey:@"allAliases"];
  [aCoder encodeObject:self.preferredAlias forKey:@"preferredAlias"];
  [aCoder encodeObject:self.encryptionIdentity forKey:@"encryptionIdentity"];
  [aCoder encodeObject:self.signingIdentity forKey:@"signingIdentity"];
  [aCoder encodeBool:self.authorized forKey:@"authorized"];
}

-(BOOL) validate
{
  return
    self.refreshToken && self.userId && self.deviceId &&
    self.preferredAlias && self.allAliases.count &&
    self.encryptionIdentity && self.signingIdentity;
}

-(RTCredentials *) authorizeWithEncryptionIdentity:(RTAsymmetricIdentity *)encryptionIdentity
                                   signingIdentity:(RTAsymmetricIdentity *)signingIdentity
{
  return [[RTCredentials alloc] initWithRefreshToken:_refreshToken userId:_userId deviceId:_deviceId
                                          allAliases:_allAliases preferredAlias:_preferredAlias
                                  encryptionIdentity:encryptionIdentity signingIdentity:signingIdentity
                                          authorized:YES];
}

-(RTCredentials *) updateRefreshToken:(NSData *)refreshToken
{
  return [[RTCredentials alloc] initWithRefreshToken:refreshToken userId:_userId deviceId:_deviceId
                                          allAliases:_allAliases preferredAlias:_preferredAlias
                                  encryptionIdentity:_encryptionIdentity signingIdentity:_signingIdentity
                                          authorized:YES];
}

-(RTCredentials *) updateDeviceId:(RTId *)deviceId
{
  return [[RTCredentials alloc] initWithRefreshToken:_refreshToken userId:_userId deviceId:deviceId
                                          allAliases:_allAliases preferredAlias:_preferredAlias
                                  encryptionIdentity:_encryptionIdentity signingIdentity:_signingIdentity
                                          authorized:YES];
}

-(RTCredentials *) updateAllAliases:(NSArray *)allAliases preferredAlias:(NSString *)preferredAlias
{
  return [[RTCredentials alloc] initWithRefreshToken:_refreshToken userId:_userId deviceId:_deviceId
                                          allAliases:allAliases preferredAlias:preferredAlias
                                  encryptionIdentity:_encryptionIdentity signingIdentity:_signingIdentity
                                          authorized:YES];
}

-(RTCredentials *) updatePreferredAlias:(NSString *)preferredAlias
{
  return [[RTCredentials alloc] initWithRefreshToken:_refreshToken userId:_userId deviceId:_deviceId
                                          allAliases:_allAliases preferredAlias:preferredAlias
                                  encryptionIdentity:_encryptionIdentity signingIdentity:_signingIdentity
                                          authorized:YES];
}

+(RTId *) legacyCurrentUserId
{
  // Try legacy method & upgrade
  NSData *data = [NSUserDefaults.standardUserDefaults dataForKey:RTAccountPreferenceName];
  if (!data) {
    return RTId.null;
  }

  RTId *userId = [RTId idWithData:data];

  if (!userId.isNull) {
    // Upgrade saving location
    [self saveCurrentUserId:userId];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:RTAccountPreferenceName];
  }

  return userId;
}

+(RTId *) currentUserId
{
  SSKeychainQuery *query = [SSKeychainQuery new];
  query.service = RTSecServiceUserName;
  query.account = RTSecAccountCurrentName;

  NSError *error;
  if (![query fetch:&error]) {
    return self.legacyCurrentUserId;
  }

  RTId *userId = [RTId idWithData:query.passwordData];
  if (userId.isNull) {
    return self.legacyCurrentUserId;
  }

  return userId;
}

+(void) saveCurrentUserId:(RTId *)userId
{
  SSKeychainQuery *query = [SSKeychainQuery new];
  query.service = RTSecServiceUserName;
  query.account = RTSecAccountCurrentName;
  query.passwordData = userId.data;

  NSError *error;
  if (![query save:&error]) {
    DDLogError(@"Error saving current user to keychain");
  }
}

+(void) deleteCurrentUserId
{
  NSError *error;
  if (![SSKeychain deletePasswordForService:RTSecServiceUserName account:RTSecAccountCurrentName error:&error]) {
    DDLogError(@"Error deleting current user from keychain");
  }
}

+(instancetype) loadFromKeychain
{
  return [self loadFromKeychain:self.currentUserId];
}

+(instancetype) loadFromKeychain:(RTId *)userId
{
  NSError *error;

  SSKeychainQuery *query = [SSKeychainQuery new];
  query.service = RTSecServiceCredentialsName;
  query.account = userId.UUIDString;
  [query fetch:&error];

  if (error) {
    return nil;
  }

  RTCredentials *creds = (id)query.passwordObject;
  if (!creds.validate) {
    return nil;
  }

  return creds;
}

-(BOOL) saveToKeychain:(NSError **)error
{
  SSKeychainQuery *credsQuery = [SSKeychainQuery new];
  credsQuery.service = RTSecServiceCredentialsName;
  credsQuery.account = self.userId.UUIDString;
  credsQuery.passwordObject = self;
  if (![credsQuery save:error]) {
    DDLogError(@"Error saving credentials for user %@ to keychain", self.userId.UUIDString);
    return NO;
  }

  [RTCredentials saveCurrentUserId:self.userId];

  return YES;
}

+(void) deleteFromKeychain
{
  [self deleteFromKeychain:self.currentUserId];
  [self deleteCurrentUserId];
}

+(void) deleteFromKeychain:(RTId *)userId
{
  NSError *error;
  if (![SSKeychain deletePasswordForService:RTSecServiceCredentialsName account:userId.UUIDString error:&error]) {
    DDLogError(@"Error deleting credentials for user %@ from keychain", userId.UUIDString);
  }
}

@end
