//
//  RTMsgSigner.m
//  ReTxt
//
//  Created by Kevin Wooten on 8/27/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTMsgSigner.h"

#import "NSArray+Utils.h"


@interface RTMsgSigner () {
  RTSignatureType _type;
  RTOpenSSLPrivateKey *_privateKey;
  RTOpenSSLPublicKey *_publicKey;
}
@end

@implementation RTMsgSigner

+(instancetype) signerWithPublicKey:(RTOpenSSLPublicKey *)publicKey signature:(NSData *)signature
{
  return [[self alloc] initWithSignatureType:RTSignatureTypeVer1_SHA256_PSS32 publicKey:publicKey];
}

+(instancetype) defaultSignerWithKeyPair:(RTOpenSSLKeyPair *)keyPair
{
  return [[self alloc] initWithSignatureType:RTSignatureTypeVer1_SHA256_PSS32 keyPair:keyPair];
}

-(instancetype) initWithSignatureType:(RTSignatureType)type publicKey:(RTOpenSSLPublicKey *)publicKey
{
  self = [super init];
  if (self) {
    _type = type;
    _publicKey = publicKey;
    _privateKey = nil;
  }
  return self;
}

-(instancetype) initWithSignatureType:(RTSignatureType)type keyPair:(RTOpenSSLKeyPair *)keyPair
{
  self = [super init];
  if (self) {
    _type = type;
    _publicKey = keyPair.publicKey;
    _privateKey = keyPair.privateKey;
  }
  return self;
}

-(RTSignatureType) type
{
  return _type;
}

-(NSData *) signWithId:(RTId *)id type:(RTMsgType)type sender:(NSString *)sender recipient:(NSString *)recipient chatId:(RTId *)chatId msgKey:(NSData *)msgKey error:(NSError **)error
{
  char msgType = type;
  
  switch (_type) {
    case RTSignatureTypeVer1_SHA256_PSS32:
      return [_privateKey signData:[@[id.data ? : [NSData data],
                                      [NSValue valueWithBytes:&msgType objCType:@encode(char)],
                                      sender,
                                      recipient,
                                      chatId.data ? : [NSData data],
                                      msgKey ? : [NSData data]] componentsJoinedAsBinaryData]
                       withPadding:RTDigitalSignaturePaddingPSS32
                             error:error];
      break;
      
    case RTSignatureTypeVer2_SHA256_PKCS1:
      return [_privateKey signData:[@[id.data ? : [NSData data], @"|",
                                      [NSValue valueWithBytes:&msgType objCType:@encode(char)], @"|",
                                      sender, @"|",
                                      recipient, @"|",
                                      chatId.data ? : [NSData data], @"|",
                                      msgKey ? : [NSData data]] componentsJoinedAsBinaryData]
                       withPadding:RTDigitalSignaturePaddingPKCS1
                             error:error];
      break;
  }
}

-(NSData *) signWithId:(RTId *)id type:(NSString *)type sender:(NSString *)sender recipientDevice:(RTId *)recipientDeviceId msgKey:(NSData *)msgKey error:(NSError **)error
{
  switch (_type) {
    case RTSignatureTypeVer1_SHA256_PSS32:
      return [_privateKey signData:[@[id.data,
                                      type,
                                      sender,
                                      recipientDeviceId.data,
                                      msgKey ? : [NSData data]] componentsJoinedAsBinaryData]
                       withPadding:RTDigitalSignaturePaddingPSS32
                             error:error];
      break;
      
    case RTSignatureTypeVer2_SHA256_PKCS1:
      return [_privateKey signData:[@[id.data, @"|",
                                      type, @"|",
                                      sender, @"|",
                                      recipientDeviceId.data, @"|",
                                      msgKey ? : [NSData data]] componentsJoinedAsBinaryData]
                       withPadding:RTDigitalSignaturePaddingPKCS1
                             error:error];
      break;
  }
}

-(BOOL) verifyMsg:(RTMsg *)msg result:(BOOL *)result error:(NSError **)error
{
  BOOL isCC = msg.flags & RTMsgFlagCC;
  char msgType = msg.type;

  switch (_type) {
    case RTSignatureTypeVer1_SHA256_PSS32:
      return [_publicKey verifyData:[@[msg.id.data,
                                      [NSValue valueWithBytes:&msgType objCType:@encode(char)],
                                      msg.sender,
                                      isCC ? msg.sender : msg.recipient,
                                      msg.groupIsSet ? msg.group.chat.data : [NSData data],
                                      msg.key ? : [NSData data]] componentsJoinedAsBinaryData]
                   againstSignature:msg.signature
                        withPadding:RTDigitalSignaturePaddingPSS32
                             result:result
                              error:error];
      break;
      
    case RTSignatureTypeVer2_SHA256_PKCS1:
      return [_publicKey verifyData:[@[msg.id.data ? : [NSData data], @"|",
                                      [NSValue valueWithBytes:&msgType objCType:@encode(char)], @"|",
                                      msg.sender, @"|",
                                      isCC ? msg.sender : msg.recipient, @"|",
                                      msg.groupIsSet ? msg.group.chat.data : [NSData data], @"|",
                                      msg.key ? : [NSData data]] componentsJoinedAsBinaryData]
                   againstSignature:msg.signature
                        withPadding:RTDigitalSignaturePaddingPKCS1
                             result:result
                              error:error];
      break;
  }
}

-(BOOL) verifyDirectMsg:(RTDirectMsg *)msg forDevice:(RTId *)deviceId result:(BOOL *)result error:(NSError **)error
{
  switch (_type) {
    case RTSignatureTypeVer1_SHA256_PSS32:
      return [_publicKey verifyData:[@[msg.id.data,
                                      msg.type,
                                      msg.sender,
                                      deviceId.data,
                                      msg.key ? : [NSData data]] componentsJoinedAsBinaryData]
                   againstSignature:msg.signature
                        withPadding:RTDigitalSignaturePaddingPSS32
                             result:result
                              error:error];
      break;
      
    case RTSignatureTypeVer2_SHA256_PKCS1:
      return [_publicKey verifyData:[@[msg.id.data, @"|",
                                      msg.type, @"|",
                                      msg.sender, @"|",
                                      deviceId.data, @"|",
                                      msg.key ? : [NSData data]] componentsJoinedAsBinaryData]
                   againstSignature:msg.signature
                        withPadding:RTDigitalSignaturePaddingPKCS1
                             result:result
                              error:error];
      break;
  }
}

@end
