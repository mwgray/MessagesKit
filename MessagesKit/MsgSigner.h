//
//  MsgSigner.h
//  MessagesKit
//
//  Created by Kevin Wooten on 8/27/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "Messages.h"
#import "OpenSSLKeyPair.h"


NS_ASSUME_NONNULL_BEGIN


@interface MsgSigner : NSObject

@property (assign, nonatomic) SignatureType type;

+(instancetype) signerWithPublicKey:(OpenSSLPublicKey *)publicKey signature:(NSData *)signature;
+(instancetype) defaultSignerWithKeyPair:(OpenSSLKeyPair *)keyPair;

-(nullable NSData *) signWithId:(Id *)id type:(MsgType)type sender:(NSString *)sender recipient:(NSString *)recipient chatId:(nullable Id *)chatId msgKey:(nullable NSData *)msgKey error:(NSError **)error;
-(nullable NSData *) signWithId:(Id *)id type:(NSString *)type sender:(NSString *)sender recipientDevice:(Id *)recipientDeviceID msgKey:(nullable NSData *)msgKey error:(NSError **)error;

-(BOOL) verifyMsg:(Msg *)msg result:(BOOL *)result error:(NSError **)error NS_REFINED_FOR_SWIFT;
-(BOOL) verifyDirectMsg:(DirectMsg *)msg forDevice:(Id *)deviceId result:(BOOL *)result error:(NSError **)error NS_REFINED_FOR_SWIFT;

@end


NS_ASSUME_NONNULL_END
