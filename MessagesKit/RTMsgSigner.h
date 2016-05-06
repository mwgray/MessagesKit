//
//  RTMsgSigner.h
//  MessagesKit
//
//  Created by Kevin Wooten on 8/27/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "RTMessages.h"
#import "RTOpenSSLKeyPair.h"


NS_ASSUME_NONNULL_BEGIN


@interface RTMsgSigner : NSObject

@property (assign, nonatomic) RTSignatureType type;

+(instancetype) signerWithPublicKey:(RTOpenSSLPublicKey *)publicKey signature:(NSData *)signature;
+(instancetype) defaultSignerWithKeyPair:(RTOpenSSLKeyPair *)keyPair;

-(nullable NSData *) signWithId:(RTId *)id type:(RTMsgType)type sender:(NSString *)sender recipient:(NSString *)recipient chatId:(nullable RTId *)chatId msgKey:(nullable NSData *)msgKey error:(NSError **)error;
-(nullable NSData *) signWithId:(RTId *)id type:(NSString *)type sender:(NSString *)sender recipientDevice:(RTId *)recipientDeviceID msgKey:(nullable NSData *)msgKey error:(NSError **)error;

-(BOOL) verifyMsg:(RTMsg *)msg result:(BOOL *)result error:(NSError **)error NS_REFINED_FOR_SWIFT;
-(BOOL) verifyDirectMsg:(RTDirectMsg *)msg forDevice:(RTId *)deviceId result:(BOOL *)result error:(NSError **)error NS_REFINED_FOR_SWIFT;

@end


NS_ASSUME_NONNULL_END
