//
//  NSURL+Utils.h
//  MessagesKit
//
//  Created by Kevin Wooten on 6/12/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;


NS_ASSUME_NONNULL_BEGIN


@interface NSURL (Utils)

+(NSURL *) URLForTemporaryFile;
+(NSURL *) URLForTemporaryFileWithExtension:(NSString *)extension;

-(nullable NSString *) UTI;
-(nullable NSString *) MIMEType;

-(NSDictionary<NSString *, NSString *> *) queryValues;

-(NSURL *) URLByAppendingQueryParameters:(NSDictionary<NSString *, NSString *> *)parameters;

-(NSURL *) relativeFileURLWithBaseURL:(NSURL *)baseURL;

+(NSString *) extensionForMimeType:(NSString *)mimeType;

@end


NS_ASSUME_NONNULL_END
