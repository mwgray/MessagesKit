//
//  RTOpenSSLCertificateSet.h
//  ReTxt
//
//  Created by Kevin Wooten on 12/13/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTOpenSSLCertificate.h"


NS_ASSUME_NONNULL_BEGIN


@interface RTOpenSSLCertificateSet : NSObject <NSFastEnumeration>

@property(nonatomic, readonly) X509_STACK *pointer;

@property(nonatomic, readonly) NSUInteger count;

-(nullable instancetype) initWithPEMEncodedData:(NSData *)pemData error:(NSError **)error;

-(RTOpenSSLCertificate *) objectAtIndexedSubscript:(NSUInteger)idx;

@end


NS_ASSUME_NONNULL_END
