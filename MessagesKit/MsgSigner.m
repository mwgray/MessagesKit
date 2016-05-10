//
//  MsgSigner.m
//  MessagesKit
//
//  Created by Kevin Wooten on 8/27/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "MsgSigner.h"

#import "NSArray+Utils.h"


@interface MsgSigner () {
  SignatureType _type;
  OpenSSLPrivateKey *_privateKey;
  OpenSSLPublicKey *_publicKey;
}
@end

@implementation MsgSigner

+(instancetype) signerWithPublicKey:(OpenSSLPublicKey *)publicKey signature:(NSData *)signature
{
  return [[self alloc] initWithSignatureType:SignatureTypeVer1_SHA256_PSS32 publicKey:publicKey];
}

+(instancetype) defaultSignerWithKeyPair:(OpenSSLKeyPair *)keyPair
{
  return [[self alloc] initWithSignatureType:SignatureTypeVer1_SHA256_PSS32 keyPair:keyPair];
}

-(instancetype) initWithSignatureType:(SignatureType)type publicKey:(OpenSSLPublicKey *)publicKey
{
  self = [super init];
  if (self) {
    _type = type;
    _publicKey = publicKey;
    _privateKey = nil;
  }
  return self;
}

-(instancetype) initWithSignatureType:(SignatureType)type keyPair:(OpenSSLKeyPair *)keyPair
{
  self = [super init];
  if (self) {
    _type = type;
    _publicKey = keyPair.publicKey;
    _privateKey = keyPair.privateKey;
  }
  return self;
}

-(SignatureType) type
{
  return _type;
}

-(NSData *) signWithId:(Id *)id type:(MsgType)type sender:(NSString *)sender recipient:(NSString *)recipient chatId:(Id *)chatId msgKey:(NSData *)msgKey error:(NSError **)error
{
  char msgType = type;
  
  switch (_type) {
    case SignatureTypeVer1_SHA256_PSS32:
      return [_privateKey signData:[@[id.data ? : [NSData data],
                                      [NSValue valueWithBytes:&msgType objCType:@encode(char)],
                                      sender,
                                      recipient,
                                      chatId.data ? : [NSData data],
                                      msgKey ? : [NSData data]] componentsJoinedAsBinaryData]
                       withPadding:DigitalSignaturePaddingPSS32
                             error:error];
      break;
      
    case SignatureTypeVer2_SHA256_PKCS1:
      return [_privateKey signData:[@[id.data ? : [NSData data], @"|",
                                      [NSValue valueWithBytes:&msgType objCType:@encode(char)], @"|",
                                      sender, @"|",
                                      recipient, @"|",
                                      chatId.data ? : [NSData data], @"|",
                                      msgKey ? : [NSData data]] componentsJoinedAsBinaryData]
                       withPadding:DigitalSignaturePaddingPKCS1
                             error:error];
      break;
  }
}

-(NSData *) signWithId:(Id *)id type:(NSString *)type sender:(NSString *)sender recipientDevice:(Id *)recipientDeviceId msgKey:(NSData *)msgKey error:(NSError **)error
{
  switch (_type) {
    case SignatureTypeVer1_SHA256_PSS32:
      return [_privateKey signData:[@[id.data,
                                      type,
                                      sender,
                                      recipientDeviceId.data,
                                      msgKey ? : [NSData data]] componentsJoinedAsBinaryData]
                       withPadding:DigitalSignaturePaddingPSS32
                             error:error];
      break;
      
    case SignatureTypeVer2_SHA256_PKCS1:
      return [_privateKey signData:[@[id.data, @"|",
                                      type, @"|",
                                      sender, @"|",
                                      recipientDeviceId.data, @"|",
                                      msgKey ? : [NSData data]] componentsJoinedAsBinaryData]
                       withPadding:DigitalSignaturePaddingPKCS1
                             error:error];
      break;
  }
}

-(BOOL) verifyMsg:(Msg *)msg result:(BOOL *)result error:(NSError **)error
{
  BOOL isCC = msg.flags & MsgFlagCC;
  char msgType = msg.type;

  switch (_type) {
    case SignatureTypeVer1_SHA256_PSS32:
      return [_publicKey verifyData:[@[msg.id.data,
                                      [NSValue valueWithBytes:&msgType objCType:@encode(char)],
                                      msg.sender,
                                      isCC ? msg.sender : msg.recipient,
                                      msg.groupIsSet ? msg.group.chat.data : [NSData data],
                                      msg.key ? : [NSData data]] componentsJoinedAsBinaryData]
                   againstSignature:msg.signature
                        withPadding:DigitalSignaturePaddingPSS32
                             result:result
                              error:error];
      break;
      
    case SignatureTypeVer2_SHA256_PKCS1:
      return [_publicKey verifyData:[@[msg.id.data ? : [NSData data], @"|",
                                      [NSValue valueWithBytes:&msgType objCType:@encode(char)], @"|",
                                      msg.sender, @"|",
                                      isCC ? msg.sender : msg.recipient, @"|",
                                      msg.groupIsSet ? msg.group.chat.data : [NSData data], @"|",
                                      msg.key ? : [NSData data]] componentsJoinedAsBinaryData]
                   againstSignature:msg.signature
                        withPadding:DigitalSignaturePaddingPKCS1
                             result:result
                              error:error];
      break;
  }
}

-(BOOL) verifyDirectMsg:(DirectMsg *)msg forDevice:(Id *)deviceId result:(BOOL *)result error:(NSError **)error
{
  switch (_type) {
    case SignatureTypeVer1_SHA256_PSS32:
      return [_publicKey verifyData:[@[msg.id.data,
                                      msg.type,
                                      msg.sender,
                                      deviceId.data,
                                      msg.key ? : [NSData data]] componentsJoinedAsBinaryData]
                   againstSignature:msg.signature
                        withPadding:DigitalSignaturePaddingPSS32
                             result:result
                              error:error];
      break;
      
    case SignatureTypeVer2_SHA256_PKCS1:
      return [_publicKey verifyData:[@[msg.id.data, @"|",
                                      msg.type, @"|",
                                      msg.sender, @"|",
                                      deviceId.data, @"|",
                                      msg.key ? : [NSData data]] componentsJoinedAsBinaryData]
                   againstSignature:msg.signature
                        withPadding:DigitalSignaturePaddingPKCS1
                             result:result
                              error:error];
      break;
  }
}

@end
