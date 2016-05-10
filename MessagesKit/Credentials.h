//
//  Credentials.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/15/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "Messages.h"
#import "AsymmetricKeyPairGenerator.h"


NS_ASSUME_NONNULL_BEGIN


@interface Credentials : NSObject <NSCoding>

@property (nonatomic, readonly) NSData *refreshToken;
@property (nonatomic, readonly) Id *userId;
@property (nonatomic, readonly) Id *deviceId;
@property (nonatomic, readonly) NSArray<NSString *> *allAliases;
@property (nonatomic, readonly) NSString *preferredAlias;
@property (nonatomic, readonly) AsymmetricIdentity *encryptionIdentity;
@property (nonatomic, readonly) AsymmetricIdentity *signingIdentity;
@property (nonatomic, readonly) BOOL authorized;

-(instancetype) initWithRefreshToken:(NSData *)refreshToken userId:(Id *)userId deviceId:(Id *)deviceId
                          allAliases:(NSArray<NSString *> *)allAliases preferredAlias:(NSString *)preferredAlias
                  encryptionIdentity:(AsymmetricIdentity *)encryptionIdentity signingIdentity:(AsymmetricIdentity *)signingIdentity
                          authorized:(BOOL)authorized;

-(BOOL) validate;

-(Credentials *) authorizeWithEncryptionIdentity:(AsymmetricIdentity *)encryptionIdentity
                                   signingIdentity:(AsymmetricIdentity *)signingIdentity;

-(Credentials *) updateRefreshToken:(NSData *)refreshToken;
-(Credentials *) updateDeviceId:(Id *)deviceId;
-(Credentials *) updateAllAliases:(NSArray<NSString *> *)allAliases preferredAlias:(NSString *)preferredAlias;
-(Credentials *) updatePreferredAlias:(NSString *)preferredAlias;

+(nullable instancetype) loadFromKeychain;
+(nullable instancetype) loadFromKeychain:(Id *)userId;

-(BOOL) saveToKeychain:(NSError **)error;
+(void) deleteFromKeychain;

@end


NS_ASSUME_NONNULL_END
