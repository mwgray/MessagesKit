//
//  Credentials.m
//  MessagesKit
//
//  Created by Kevin Wooten on 7/15/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Credentials.h"

#import "AsymmetricKeyPairGenerator.h"

#import "Messages+Exts.h"
#import "NSData+CommonDigest.h"
#import "NSData+Encoding.h"
#import "Log.h"

@import SSKeychain;


CL_DECLARE_LOG_LEVEL()


static NSString *SecServiceCredentialsName  = @"io.retxt.credentials";
static NSString *SecServiceUserName  = @"io.retxt.user";
static NSString *SecAccountCurrentName  = @"current";

// Legacy value for user defaults
static NSString *AccountPreferenceName  = @"io.retxt.account";


@implementation Credentials

+(void) initialize
{
  [SSKeychain setAccessibilityType:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly];
}

-(instancetype) initWithRefreshToken:(NSData *)refreshToken userId:(Id *)userId deviceId:(Id *)deviceId
                          allAliases:(NSArray *)allAliases preferredAlias:(NSString *)preferredAlias
                  encryptionIdentity:(AsymmetricIdentity *)encryptionIdentity signingIdentity:(AsymmetricIdentity *)signingIdentity
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
    _userId = [aDecoder decodeObjectOfClass:Id.class forKey:@"userId"];
    _deviceId = [aDecoder decodeObjectOfClass:Id.class forKey:@"deviceId"];
    _allAliases = [aDecoder decodeObjectOfClass:NSArray.class forKey:@"allAliases"];
    _preferredAlias = [aDecoder decodeObjectOfClass:NSString.class forKey:@"preferredAlias"];
    _encryptionIdentity = [aDecoder decodeObjectOfClass:AsymmetricIdentity.class forKey:@"encryptionIdentity"];
    _signingIdentity = [aDecoder decodeObjectOfClass:AsymmetricIdentity.class forKey:@"signingIdentity"];
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

-(Credentials *) authorizeWithEncryptionIdentity:(AsymmetricIdentity *)encryptionIdentity
                                   signingIdentity:(AsymmetricIdentity *)signingIdentity
{
  return [[Credentials alloc] initWithRefreshToken:_refreshToken userId:_userId deviceId:_deviceId
                                          allAliases:_allAliases preferredAlias:_preferredAlias
                                  encryptionIdentity:encryptionIdentity signingIdentity:signingIdentity
                                          authorized:YES];
}

-(Credentials *) updateRefreshToken:(NSData *)refreshToken
{
  return [[Credentials alloc] initWithRefreshToken:refreshToken userId:_userId deviceId:_deviceId
                                          allAliases:_allAliases preferredAlias:_preferredAlias
                                  encryptionIdentity:_encryptionIdentity signingIdentity:_signingIdentity
                                          authorized:YES];
}

-(Credentials *) updateDeviceId:(Id *)deviceId
{
  return [[Credentials alloc] initWithRefreshToken:_refreshToken userId:_userId deviceId:deviceId
                                          allAliases:_allAliases preferredAlias:_preferredAlias
                                  encryptionIdentity:_encryptionIdentity signingIdentity:_signingIdentity
                                          authorized:YES];
}

-(Credentials *) updateAllAliases:(NSArray *)allAliases preferredAlias:(NSString *)preferredAlias
{
  return [[Credentials alloc] initWithRefreshToken:_refreshToken userId:_userId deviceId:_deviceId
                                          allAliases:allAliases preferredAlias:preferredAlias
                                  encryptionIdentity:_encryptionIdentity signingIdentity:_signingIdentity
                                          authorized:YES];
}

-(Credentials *) updatePreferredAlias:(NSString *)preferredAlias
{
  return [[Credentials alloc] initWithRefreshToken:_refreshToken userId:_userId deviceId:_deviceId
                                          allAliases:_allAliases preferredAlias:preferredAlias
                                  encryptionIdentity:_encryptionIdentity signingIdentity:_signingIdentity
                                          authorized:YES];
}

+(Id *) legacyCurrentUserId
{
  // Try legacy method & upgrade
  NSData *data = [NSUserDefaults.standardUserDefaults dataForKey:AccountPreferenceName];
  if (!data) {
    return Id.null;
  }

  Id *userId = [Id idWithData:data];

  if (!userId.isNull) {
    // Upgrade saving location
    [self saveCurrentUserId:userId];
    [NSUserDefaults.standardUserDefaults removeObjectForKey:AccountPreferenceName];
  }

  return userId;
}

+(Id *) currentUserId
{
  SSKeychainQuery *query = [SSKeychainQuery new];
  query.service = SecServiceUserName;
  query.account = SecAccountCurrentName;

  NSError *error;
  if (![query fetch:&error]) {
    return self.legacyCurrentUserId;
  }

  Id *userId = [Id idWithData:query.passwordData];
  if (userId.isNull) {
    return self.legacyCurrentUserId;
  }

  return userId;
}

+(void) saveCurrentUserId:(Id *)userId
{
  SSKeychainQuery *query = [SSKeychainQuery new];
  query.service = SecServiceUserName;
  query.account = SecAccountCurrentName;
  query.passwordData = userId.data;

  NSError *error;
  if (![query save:&error]) {
    DDLogError(@"Error saving current user to keychain");
  }
}

+(void) deleteCurrentUserId
{
  NSError *error;
  if (![SSKeychain deletePasswordForService:SecServiceUserName account:SecAccountCurrentName error:&error]) {
    DDLogError(@"Error deleting current user from keychain");
  }
}

+(instancetype) loadFromKeychain
{
  return [self loadFromKeychain:self.currentUserId];
}

+(instancetype) loadFromKeychain:(Id *)userId
{
  NSError *error;

  SSKeychainQuery *query = [SSKeychainQuery new];
  query.service = SecServiceCredentialsName;
  query.account = userId.UUIDString;
  [query fetch:&error];

  if (error) {
    return nil;
  }

  Credentials *creds = (id)query.passwordObject;
  if (!creds.validate) {
    return nil;
  }

  return creds;
}

-(BOOL) saveToKeychain:(NSError **)error
{
  SSKeychainQuery *credsQuery = [SSKeychainQuery new];
  credsQuery.service = SecServiceCredentialsName;
  credsQuery.account = self.userId.UUIDString;
  credsQuery.passwordObject = self;
  if (![credsQuery save:error]) {
    DDLogError(@"Error saving credentials for user %@ to keychain", self.userId.UUIDString);
    return NO;
  }

  [Credentials saveCurrentUserId:self.userId];

  return YES;
}

+(void) deleteFromKeychain
{
  [self deleteFromKeychain:self.currentUserId];
  [self deleteCurrentUserId];
}

+(void) deleteFromKeychain:(Id *)userId
{
  NSError *error;
  if (![SSKeychain deletePasswordForService:SecServiceCredentialsName account:userId.UUIDString error:&error]) {
    DDLogError(@"Error deleting credentials for user %@ from keychain", userId.UUIDString);
  }
}

@end
