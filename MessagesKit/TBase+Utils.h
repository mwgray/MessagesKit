//
//  TBase+Utils.h
//  ReTxt
//
//  Created by Kevin Wooten on 5/14/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Thrift;


NS_ASSUME_NONNULL_BEGIN


@interface TBaseUtils : NSObject

+(nullable NSData *) serializeToData:(id<TBase>)obj error:(NSError **)error;
+(nullable id) deserialize:(id<TBase>)obj fromData:(NSData *)data error:(NSError **)error;

+(nullable NSString *) serializeToBase64String:(id<TBase>)obj error:(NSError **)error;
+(nullable id) deserialize:(id<TBase>)obj fromBase64String:(NSString *)data error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
