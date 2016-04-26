//
//  RTAudioMessage.h
//  ReTxt
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTMessage.h"
#import "DataReference.h"


NS_ASSUME_NONNULL_BEGIN


@interface RTAudioMessage : RTMessage

@property (retain, nonatomic) id<DataReference> data;
@property (copy, nonatomic) NSString *dataMimeType;

-(BOOL) isEquivalentToAudioMessage:(RTAudioMessage *)audioMessage;

@end


NS_ASSUME_NONNULL_END
