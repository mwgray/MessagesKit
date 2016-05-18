//
//  OpenSSLCertificateValidator.h
//  MessagesKit
//
//  Created by Kevin Wooten on 12/13/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "OpenSSLCertificate.h"
#import "OpenSSLCertificateSet.h"


NS_ASSUME_NONNULL_BEGIN


@interface OpenSSLCertificateTrust : NSObject

@property(nonatomic, readonly) OpenSSLCertificateSet *roots;
@property(nonatomic, readonly) OpenSSLCertificateSet *intermediates;

-(instancetype) initWithRoots:(OpenSSLCertificateSet *)roots intermediates:(OpenSSLCertificateSet *)intermediates;
-(nullable instancetype) initWithPEMEncodedRoots:(NSData *)rootsData intermediates:(NSData *)intermediatesData error:(NSError **)error;

@end


@interface OpenSSLCertificateValidator : NSObject

@property(nonatomic, readonly) X509_STORE *pointer;

-(nullable instancetype) initWithRootCertificates:(OpenSSLCertificateSet *)rootCerts error:(NSError **)error;
-(nullable instancetype) initWithRootCertificatesInFile:(NSString *)rootCertsFile error:(NSError **)error;

-(BOOL) validate:(OpenSSLCertificate *)certificate chain:(nullable OpenSSLCertificateSet *)chain error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
