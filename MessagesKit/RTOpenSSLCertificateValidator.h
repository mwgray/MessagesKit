//
//  RTOpenSSLCertificateValidator.h
//  MessagesKit
//
//  Created by Kevin Wooten on 12/13/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTOpenSSLCertificate.h"
#import "RTOpenSSLCertificateSet.h"


NS_ASSUME_NONNULL_BEGIN


@interface RTOpenSSLCertificateTrust : NSObject

@property(nonatomic, readonly) RTOpenSSLCertificateSet *roots;
@property(nonatomic, readonly) RTOpenSSLCertificateSet *intermediates;

-(instancetype) initWithRoots:(RTOpenSSLCertificateSet *)roots intermediates:(RTOpenSSLCertificateSet *)intermediates;
-(nullable instancetype) initWithPEMEncodedRoots:(NSData *)rootsData intermediates:(NSData *)intermediatesData error:(NSError **)error;

@end


@interface RTOpenSSLCertificateValidator : NSObject

@property(nonatomic, readonly) X509_STORE *pointer;

-(nullable instancetype) initWithRootCertificates:(RTOpenSSLCertificateSet *)rootCerts error:(NSError **)error;
-(nullable instancetype) initWithRootCertificatesInFile:(NSString *)rootCertsFile error:(NSError **)error;

-(BOOL) validate:(RTOpenSSLCertificate *)certificate chain:(nullable RTOpenSSLCertificateSet *)chain result:(BOOL *)result error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
