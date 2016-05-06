//
//  RTWebSocket.h
//  MessagesKit
//
//  Created by Francisco Rimoldi on 02/05/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "RTMessages.h"


NS_ASSUME_NONNULL_BEGIN


@class RTWebSocket;


@protocol RTWebSocketDelegate <NSObject>

-(void) webSocket:(RTWebSocket *)webSocket willConnect:(NSMutableURLRequest *)request;

-(void) webSocket:(RTWebSocket *)webSocket didReceiveUserStatus:(NSString *)sender recipient:(NSString *)recipient status:(enum RTUserStatus)status;
-(void) webSocket:(RTWebSocket *)webSocket didReceiveGroupStatus:(NSString *)sender chatId:(RTId *)chatId status:(enum RTUserStatus)status;
-(void) webSocket:(RTWebSocket *)webSocket didReceiveMsgReady:(RTMsgHdr *)msgHdr;
-(void) webSocket:(RTWebSocket *)webSocket didReceiveMsgDelivery:(RTMsg *)msg;
-(void) webSocket:(RTWebSocket *)webSocket didReceiveMsgDelivered:(RTId *)msgId recipient:(NSString *)recipient;
-(void) webSocket:(RTWebSocket *)webSocket didReceiveMsgDirect:(RTDirectMsg *)msg;

@end


@interface RTWebSocket : NSObject

@property (strong, nonatomic) NSURLRequest *URLRequest;
@property (weak, nonatomic) id<RTWebSocketDelegate> delegate;

-(instancetype) initWithURL:(NSURL *)URL;
-(instancetype) initWithURLRequest:(NSURLRequest *)URLRequest;

-(void) connect;
-(void) disconnect;
-(void) reconnect;

-(BOOL) isOpen;
-(BOOL) isConnecting;
-(BOOL) isClosed;

@end


NS_ASSUME_NONNULL_END
