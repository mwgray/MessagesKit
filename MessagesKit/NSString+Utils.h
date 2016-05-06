//
//  NSString+Utils.h
//  MessagesKit
//
//  Created by Kevin Wooten on 6/11/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;


@interface NSString (Utils)

+(NSString *) stringWithData:(NSData *)data encoding:(NSStringEncoding)encoding;

-(BOOL) isEqualToStringCI:(NSString *)other;

-(NSUInteger) unsignedIntegerValue;

@end
