//
//  NSError+Utils.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (Utils)

-(BOOL) checkDomain:(NSString *)domain code:(NSInteger)code;
-(BOOL) checkDomain:(NSString *)domain;

@end
