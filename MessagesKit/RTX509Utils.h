//
//  RTX509Utils.h
//  ReTxt
//
//  Created by Kevin Wooten on 12/2/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTOpenSSL.h"


NS_ASSUME_NONNULL_BEGIN


@interface RTX509Utils : NSObject

+(nullable X509_NAME *)nameWithDictionary:(NSDictionary<NSString *, NSString *> *)nameParts;

+(nullable X509_EXTENSION *) buildExtensionNamed:(const char *)name withValue:(NSString *)value;
+(BOOL) addExtenstionNamed:(const char *)name withValue:(NSString *)value toRequest:(X509_REQ *)req;
+(BOOL) addExtenstionNamed:(const char *)name withValue:(NSString *)value toCertificate:(X509 *)cert;

+(nullable X509 *) generateSelfSignedCertificateNamed:(NSDictionary<NSString *, NSString *> *)name
                                           forKeyPair:(EVP_PKEY *)keyPair
                                             keyUsage:(NSString *)keyUsage
                                                error:(NSError **)error;

+(nullable NSData *) packageIdentityNamed:(NSString *)name
                              withKeyPair:(EVP_PKEY *)keyPair certificate:(X509 *)cert
                   inPKCS12WithPassphrase:(NSString *)password error:(NSError **)error;

+(nullable NSData *) exportCertificate:(X509 *)cert andPrivateKey:(EVP_PKEY *)privateKey
                  inPKCS12PackageNamed:(NSString *)name withPassphrase:(NSString *)passphrase
                                 error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END
