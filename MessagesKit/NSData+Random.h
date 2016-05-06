//
//  NSData+Random.h
//  MessagesKit
//
//  Created by Kevin Wooten on 3/31/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSData (Random)

+(instancetype) dataWithRandomBytesOfLength:(NSUInteger)length;

@end
