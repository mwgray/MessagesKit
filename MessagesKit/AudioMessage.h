//
//  AudioMessage.h
//  MessagesKit
//
//  Created by Kevin Wooten on 1/3/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "Message.h"
#import "DataReference.h"


NS_ASSUME_NONNULL_BEGIN


@interface AudioMessage : Message

@property (retain, nonatomic) id<DataReference> data;
@property (copy, nonatomic) NSString *dataMimeType;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithId:(Id *)id chat:(Chat *)chat NS_UNAVAILABLE;

-(instancetype) initWithId:(Id *)id chat:(Chat *)chat data:(id<DataReference>)data mimeType:(NSString *)mimeType NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithChat:(Chat *)chat data:(id<DataReference>)data mimeType:(NSString *)mimeType;

-(BOOL) isEquivalentToAudioMessage:(AudioMessage *)audioMessage;

@end


NS_ASSUME_NONNULL_END
