//
//  AudioMessage.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Message.h"
#import "URLDataReference.h"


NS_ASSUME_NONNULL_BEGIN


@interface AudioMessage : Message

@property (copy, nonatomic) id<DataReference> data;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithId:(Id *)id chat:(Chat *)chat NS_UNAVAILABLE;

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat data:(id<DataReference>)data NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithChat:(Chat *)chat data:(id<DataReference>)data;

-(BOOL) isEquivalentToAudioMessage:(AudioMessage *)audioMessage;

@end


NS_ASSUME_NONNULL_END
