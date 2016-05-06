//
//  NSURL+Utils.h
//  MessagesKit
//
//  Created by Kevin Wooten on 6/12/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;


@interface NSURL (Utils)

+(NSURL *) URLForTemporaryFile;

-(NSString *) UTI;
-(NSString *) MIMEType;

-(NSDictionary<NSString *, NSString *> *) queryValues;

-(NSURL *) URLByAppendingQueryParameters:(NSDictionary *)parameters;

@end
