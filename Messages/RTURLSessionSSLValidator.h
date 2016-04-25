//
//  RTURLSessionSSLValidator.h
//  ReTxt
//
//  Created by Kevin Wooten on 7/7/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


@interface RTURLSessionSSLValidator : NSObject <NSURLSessionDelegate>

-(instancetype) initWithTrustedCertificates:(NSArray *)trustedCertificates;

@end


NS_ASSUME_NONNULL_END
