//
//  MsgCipher.h
//  MessagesKit
//
//  Created by Kevin Wooten on 4/2/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "Messages.h"
#import "DataReference.h"


NS_ASSUME_NONNULL_BEGIN


extern NSString *const MsgCipherErrorDomain;

typedef NS_ENUM(int, MsgCipherError) {
  MsgCipherErrorRandomGeneratorFailed   = 0
};


@interface MsgCipher : NSObject

@property (assign, nonatomic) EncryptionType type;

+(instancetype) defaultCipher;
+(instancetype) cipherForKey:(NSData *)key;
+(instancetype) cipherForEncryptionType:(EncryptionType)encryptionType;

-(nullable NSData *) randomKeyWithError:(NSError **)error;

-(nullable NSData *) encryptData:(NSData *)data withKey:(NSData *)key error:(NSError **)error;
-(BOOL) encryptFromStream:(id<DataInputStream>)inStream toStream:(id<DataOutputStream>)outStream withKey:(NSData *)key error:(NSError **)error;

-(nullable NSData *) decryptData:(NSData *)data withKey:(NSData *)key error:(NSError **)error;
-(BOOL) decryptFromStream:(id<DataInputStream>)inStream toStream:(id<DataOutputStream>)outStream withKey:(NSData *)key error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
