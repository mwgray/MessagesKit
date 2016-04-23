//
//  RTOpenSSLCertificationRequest.h
//  ReTxt
//
//  Created by Kevin Wooten on 12/13/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTOpenSSL.h"


NS_ASSUME_NONNULL_BEGIN


@interface RTOpenSSLCertificationRequest : NSObject <NSCoding>

@property (nonatomic, readonly) X509_REQ *pointer;

@property (nonatomic, readonly) NSData *encoded;

-(instancetype) initWithRequestPointer:(X509_REQ *)pointer;

@end


NS_ASSUME_NONNULL_END
