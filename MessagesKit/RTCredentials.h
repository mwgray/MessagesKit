//
//  RTCredentials.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/15/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "RTMessages.h"
#import "RTAsymmetricKeyPairGenerator.h"


NS_ASSUME_NONNULL_BEGIN


@interface RTCredentials : NSObject <NSCoding>

@property (nonatomic, readonly) NSData *refreshToken;
@property (nonatomic, readonly) RTId *userId;
@property (nonatomic, readonly) RTId *deviceId;
@property (nonatomic, readonly) NSArray<NSString *> *allAliases;
@property (nonatomic, readonly) NSString *preferredAlias;
@property (nonatomic, readonly) RTAsymmetricIdentity *encryptionIdentity;
@property (nonatomic, readonly) RTAsymmetricIdentity *signingIdentity;
@property (nonatomic, readonly) BOOL authorized;

-(instancetype) initWithRefreshToken:(NSData *)refreshToken userId:(RTId *)userId deviceId:(RTId *)deviceId
                          allAliases:(NSArray<NSString *> *)allAliases preferredAlias:(NSString *)preferredAlias
                  encryptionIdentity:(RTAsymmetricIdentity *)encryptionIdentity signingIdentity:(RTAsymmetricIdentity *)signingIdentity
                          authorized:(BOOL)authorized;

-(BOOL) validate;

-(RTCredentials *) authorizeWithEncryptionIdentity:(RTAsymmetricIdentity *)encryptionIdentity
                                   signingIdentity:(RTAsymmetricIdentity *)signingIdentity;

-(RTCredentials *) updateRefreshToken:(NSData *)refreshToken;
-(RTCredentials *) updateDeviceId:(RTId *)deviceId;
-(RTCredentials *) updateAllAliases:(NSArray<NSString *> *)allAliases preferredAlias:(NSString *)preferredAlias;
-(RTCredentials *) updatePreferredAlias:(NSString *)preferredAlias;

+(nullable instancetype) loadFromKeychain;
+(nullable instancetype) loadFromKeychain:(RTId *)userId;

-(BOOL) saveToKeychain:(NSError **)error;
+(void) deleteFromKeychain;

@end


NS_ASSUME_NONNULL_END
