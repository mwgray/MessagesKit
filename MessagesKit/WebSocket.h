//
//  WebSocket.h
//  MessagesKit
//
//  Created by Francisco Rimoldi on 02/05/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;

#import "Messages.h"


NS_ASSUME_NONNULL_BEGIN


@class WebSocket;


@protocol WebSocketDelegate <NSObject>

-(void) webSocket:(WebSocket *)webSocket willConnect:(NSMutableURLRequest *)request;

-(void) webSocket:(WebSocket *)webSocket didReceiveUserStatus:(NSString *)sender recipient:(NSString *)recipient status:(enum UserStatus)status;
-(void) webSocket:(WebSocket *)webSocket didReceiveGroupStatus:(NSString *)sender chatId:(Id *)chatId status:(enum UserStatus)status;
-(void) webSocket:(WebSocket *)webSocket didReceiveMsgReady:(MsgHdr *)msgHdr;
-(void) webSocket:(WebSocket *)webSocket didReceiveMsgDelivery:(Msg *)msg;
-(void) webSocket:(WebSocket *)webSocket didReceiveMsgDelivered:(Id *)msgId recipient:(NSString *)recipient;
-(void) webSocket:(WebSocket *)webSocket didReceiveMsgDirect:(DirectMsg *)msg;

@end


@interface WebSocket : NSObject

@property (strong, nonatomic) NSURLRequest *URLRequest;
@property (weak, nonatomic) id<WebSocketDelegate> delegate;

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
