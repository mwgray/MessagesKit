//
//  X509Utils.m
//  MessagesKit
//
//  Created by Kevin Wooten on 12/2/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "X509Utils.h"

#import "OpenSSL.h"
#import "NSDate+Utils.h"

#import <openssl/pkcs12.h>
#import <openssl/x509v3.h>
#import <openssl/err.h>

@import YOLOKit;


@implementation X509Utils

+(void)initialize
{
  [OpenSSL go];
}

+(X509_NAME *)nameWithDictionary:(NSDictionary<NSString *, NSString *> *)nameParts
{
  X509_NAME* name = X509_NAME_new();
  
  // Add common parts in normal order
  {
    NSString *uid = nameParts[@"UID"];
    if (uid) {
      X509_NAME_add_entry_by_txt(name, "UID", MBSTRING_UTF8, (const unsigned char *)uid.UTF8String, (int)uid.length, -1, 0);
      nameParts = nameParts.without(@"UID");
    }
  }
  
  {
    NSString *cn = nameParts[@"CN"];
    if (cn) {
      X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_UTF8, (const unsigned char *)cn.UTF8String, (int)cn.length, -1, 0);
      nameParts = nameParts.without(@"CN");
    }
  }
  
  {
    NSString *ou = nameParts[@"OU"];
    if (ou) {
      X509_NAME_add_entry_by_txt(name, "OU", MBSTRING_UTF8, (const unsigned char *)ou.UTF8String, (int)ou.length, -1, 0);
      nameParts = nameParts.without(@"OU");
    }
  }
  
  {
    NSString *o = nameParts[@"O"];
    if (o) {
      X509_NAME_add_entry_by_txt(name, "O", MBSTRING_UTF8, (const unsigned char *)o.UTF8String, (int)o.length, -1, 0);
      nameParts = nameParts.without(@"O");
    }
  }
  
  {
    NSString *l = nameParts[@"L"];
    if (l) {
      X509_NAME_add_entry_by_txt(name, "L", MBSTRING_UTF8, (const unsigned char *)l.UTF8String, (int)l.length, -1, 0);
      nameParts = nameParts.without(@"L");
    }
  }
  
  {
    NSString *st = nameParts[@"ST"];
    if (st) {
      X509_NAME_add_entry_by_txt(name, "ST", MBSTRING_UTF8, (const unsigned char *)st.UTF8String, (int)st.length, -1, 0);
      nameParts = nameParts.without(@"ST");
    }
  }
  
  {
    NSString *c = nameParts[@"C"];
    if (c) {
      X509_NAME_add_entry_by_txt(name, "C", MBSTRING_UTF8, (const unsigned char *)c.UTF8String, (int)c.length, -1, 0);
      nameParts = nameParts.without(@"C");
    }
  }
  
  // Add the rest... in any order
  [nameParts enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
    X509_NAME_add_entry_by_txt(name, key.UTF8String, MBSTRING_UTF8, (const unsigned char *)obj.UTF8String, (int)obj.length, -1, 0);
  }];
  
  return name;
}

+(X509_EXTENSION *) buildExtensionNamed:(const char *)name withValue:(NSString *)value
{
  int ext_nid = OBJ_sn2nid(name);
  
  const X509V3_EXT_METHOD *method = X509V3_EXT_get_nid(ext_nid);
  
  void *ext_struc;
  if(method->v2i) {
    STACK_OF(CONF_VALUE) *nval = X509V3_parse_list(value.UTF8String);
    ext_struc = method->v2i(method, NULL, nval);
  }
  else if(method->s2i) {
    ext_struc = method->s2i(method, NULL, value.UTF8String);
  }
  else if(method->r2i) {
    ext_struc = method->r2i(method, NULL, value.UTF8String);
  }
  else {
    return NULL;
  }
  
  return X509V3_EXT_i2d(ext_nid, 0, ext_struc);
}

+(BOOL) addExtenstionNamed:(const char *)name withValue:(NSString *)value toRequest:(X509_REQ *)req
{
  if (value.length == 0) {
    return YES;
  }
  
  X509_EXTENSION *ext = [self buildExtensionNamed:name withValue:value];
  if (!ext) {
    return NO;
  }
  
  STACK_OF(X509_EXTENSION) *exts = sk_X509_EXTENSION_new_null();
  sk_X509_EXTENSION_push(exts, ext);
  
  X509_REQ_add_extensions(req, exts);
  
  sk_X509_EXTENSION_free(exts);
  X509_EXTENSION_free(ext);
  
  return YES;
}

+(BOOL) addExtenstionNamed:(const char *)name withValue:(NSString *)value toCertificate:(X509 *)cert
{
  if (value.length == 0) {
    return YES;
  }
  
  X509_EXTENSION *ext = [self buildExtensionNamed:name withValue:value];
  if (!ext) {
    return NO;
  }
  
  X509_add_ext(cert, ext, -1);
  
  X509_EXTENSION_free(ext);
  
  return YES;
}

+(X509 *) generateSelfSignedCertificateNamed:(NSDictionary *)name
                                  forKeyPair:(EVP_PKEY *)keyPair
                                    keyUsage:(NSString *)keyUsage
                                       error:(NSError **)error
{
  X509 *cert = X509_new();
  if (cert == NULL) {
    EVP_PKEY_free(keyPair);
    _RETURN_OPENSSL_ERROR(CertBuildFailed, NULL);
  }
  
  BOOL certValid = ^BOOL {
    
    { // Set Issuer Name field
      X509_NAME* issuerName = [X509Utils nameWithDictionary:@{@"CN":@"reTXT"}];
      if (!X509_set_issuer_name(cert, issuerName)) {
        X509_NAME_free(issuerName);
        _RETURN_OPENSSL_ERROR(CertBuildFailed, NO);
      }
      X509_NAME_free(issuerName);
    }
    
    { // Set Subject Name field
      X509_NAME* subjectName = [X509Utils nameWithDictionary:name];
      if (!X509_set_subject_name(cert, subjectName)) {
        X509_NAME_free(subjectName);
        _RETURN_OPENSSL_ERROR(CertBuildFailed, NO);
      }
      X509_NAME_free(subjectName);
    }
    
    { // Set Serial field
      ASN1_INTEGER* serial = ASN1_INTEGER_new();
      ASN1_INTEGER_set(serial, CFAbsoluteTimeGetCurrent());
      if (!X509_set_serialNumber(cert, serial)) {
        ASN1_INTEGER_free(serial);
        _RETURN_OPENSSL_ERROR(CertBuildFailed, NO);
      }
      ASN1_INTEGER_free(serial);
    }
    
    { // Set Not Before field
      ASN1_TIME* notBefore = ASN1_TIME_new();
      NSDate *yesterday = [[NSDate date] offsetDays:-1 withCalendar:NSCalendar.currentCalendar];
      ASN1_TIME_set(notBefore, (time_t)[yesterday timeIntervalSince1970]);
      if (!X509_set_notBefore(cert, notBefore)) {
        ASN1_TIME_free(notBefore);
        _RETURN_OPENSSL_ERROR(CertBuildFailed, NO);
      }
      ASN1_TIME_free(notBefore);
    }
    
    { // Set Not After field
      ASN1_TIME* notAfter = ASN1_TIME_new();
      NSDate *future = [[NSDate date] offsetYears:100 withCalendar:NSCalendar.currentCalendar];
      ASN1_TIME_set(notAfter, (time_t)[future timeIntervalSince1970]);
      if (!X509_set_notAfter(cert, notAfter)) {
        ASN1_TIME_free(notAfter);
        _RETURN_OPENSSL_ERROR(CertBuildFailed, NO);
      }
      ASN1_TIME_free(notAfter);
    }
    
    [X509Utils addExtenstionNamed:SN_key_usage
                          withValue:keyUsage
                      toCertificate:cert];
    
    // Set the Public Key
    if (!X509_set_pubkey(cert, keyPair)) {
      _RETURN_OPENSSL_ERROR(CertBuildFailed, NO);
    }
    
    // Sign the certificate
    if (!X509_sign(cert, keyPair, EVP_sha256())) {
      _RETURN_OPENSSL_ERROR(CertBuildFailed, NO);
    }
    
    return YES;
  }();
  
  if (!certValid) {
    X509_free(cert);
    cert = NULL;
  }
  
  return cert;
}

+(NSData *) packageIdentityNamed:(NSString *)name
                     withKeyPair:(EVP_PKEY *)keyPair certificate:(X509 *)cert
          inPKCS12WithPassphrase:(NSString *)password error:(NSError **)error
{
  PKCS12 *package = PKCS12_create((char *)password.UTF8String, (char *)name.UTF8String, keyPair, cert, NULL, 0, 0, 0, 0, 0);
  if (!package) {
    _RETURN_OPENSSL_ERROR(PKCS12ExportFailed, nil);
  }
  
  NSData *data = ^NSData *{
    
    BIO *buffer = BIO_new(BIO_s_mem());
    if (!buffer) {
      _RETURN_OPENSSL_ERROR(PKCS12ExportFailed, nil);
    }
    
    NSData *data = ^NSData *{
      
      if (i2d_PKCS12_bio(buffer, package) <= 0) {
        _RETURN_OPENSSL_ERROR(PKCS12ExportFailed, nil);
      }
      
      BIO_flush(buffer);
      
      void *bufferBytes;
      long bufferLen = BIO_get_mem_data(buffer, &bufferBytes);
      
      return [NSData dataWithBytes:bufferBytes length:bufferLen];
    }();
    
    BIO_free_all(buffer);
    
    return data;
  }();
  
  PKCS12_free(package);
  
  return data;
}

+(NSData *) exportCertificate:(X509 *)cert andPrivateKey:(EVP_PKEY *)privateKey
         inPKCS12PackageNamed:(NSString *)name withPassphrase:(NSString *)passphrase
                        error:(NSError **)error
{
  NSData *pkcs12 = [self packageIdentityNamed:name
                                  withKeyPair:privateKey
                                  certificate:cert
                       inPKCS12WithPassphrase:passphrase
                                        error:error];
  
  X509_free(cert);
  EVP_PKEY_free(privateKey);
  
  return pkcs12;
}

@end
