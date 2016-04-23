//
//  RTMsgCipher.h
//  ReTxt
//
//  Created by Kevin Wooten on 4/2/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "RTMessages.h"


NS_ASSUME_NONNULL_BEGIN


@protocol DataInputStream;
@protocol DataOutputStream;


extern NSString *const RTMsgCipherErrorDomain;

typedef NS_ENUM(int, RTMsgCipherError) {
  RTMsgCipherErrorRandomGeneratorFailed   = 0
};


@interface RTMsgCipher : NSObject

@property (assign, nonatomic) RTEncryptionType type;

+(instancetype) defaultCipher;
+(instancetype) cipherForKey:(NSData *)key;
+(instancetype) cipherForEncryptionType:(RTEncryptionType)encryptionType;

-(nullable NSData *) randomKeyWithError:(NSError **)error;

-(nullable NSData *) encryptData:(NSData *)data withKey:(NSData *)key error:(NSError **)error;
-(BOOL) encryptFromStream:(id<DataInputStream>)inStream toStream:(id<DataOutputStream>)outStream withKey:(NSData *)key error:(NSError **)error;

-(nullable NSData *) decryptData:(NSData *)data withKey:(NSData *)key error:(NSError **)error;
-(BOOL) decryptFromStream:(id<DataInputStream>)inStream toStream:(id<DataOutputStream>)outStream withKey:(NSData *)key error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
