//
//  WebSocket.m
//  MessagesKit
//
//  Created by Francisco Rimoldi on 02/05/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "WebSocket.h"

#import "SRWebSocket.h"
#import "ServerAPI.h"
#import "NSError+Utils.h"
#import "Log.h"

@import Thrift;


CL_DECLARE_LOG_LEVEL()


static const double kReconnectInterval = 1.0;
static const double kReconnectIntervalMultiplier = 1.0;
static const double kReconnectIntervalMax = 10.0;
static const int kReconnectAttemptsMax = 50;


@interface WebSocket () <SRWebSocketDelegate, DeviceService> {
  SRWebSocket *_internalWebSocket;
  uint _reconnectCount;
  DeviceServiceProcessor *_processor;
  id<TProtocolFactory> _protocolFactory;
}

@end


@interface NullTransport : NSObject <TTransport>

@end



@implementation WebSocket

-(instancetype) initWithURL:(NSURL *)URL
{
  return [self initWithURLRequest:[[NSURLRequest alloc] initWithURL:URL]];
}

-(instancetype) initWithURLRequest:(NSURLRequest *)URLRequest
{
  self = [super init];
  if (self) {
    
    _URLRequest = URLRequest;
    
  }
  return self;
}

-(void) setURLRequest:(NSURLRequest *)URLRequest
{
  NSMutableURLRequest *reqs = [URLRequest mutableCopy];
  reqs.SR_SSLPinnedCertificates = ServerAPI.pinnedCerts;
  _URLRequest = reqs;
}

-(void) reconnect
{
  [self _invalidate];
  [self _connect];
}

-(void) connect
{
  _reconnectCount = 0;

  switch (_internalWebSocket.readyState) {
  case SR_OPEN:
    return;

  case SR_CLOSED:
  case SR_CLOSING:
    [self reconnect];
    return;

  default:
    [self _connect];
  }
}

-(void) _connect
{
  NSLog(@"WebSocket: connecting");

  if (!_internalWebSocket) {
    
    NSMutableURLRequest *request = _URLRequest.mutableCopy;
    
    if ([_delegate respondsToSelector:@selector(webSocket:willConnect:)]) {
      [_delegate webSocket:self willConnect:request];
    }
    
    _internalWebSocket = [[SRWebSocket alloc] initWithURLRequest:request protocols:@[@"compact", @"binary"] allowsUntrustedSSLCertificates:NO];
    [_internalWebSocket setDelegateDispatchQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    _internalWebSocket.delegate = self;
  }

  [_internalWebSocket open];
}

-(void) disconnect
{
  if (!_internalWebSocket) {
    return;
  }

  NSLog(@"WebSocket: disconnecting");

  [_internalWebSocket closeWithCode:SRStatusCodeNormal reason:@"requested"];

  [self _invalidate];
}

-(void) _invalidate
{
  _internalWebSocket.delegate = nil;
  _internalWebSocket = nil;
}

-(BOOL) isOpen
{
  return _internalWebSocket && _internalWebSocket.readyState == SR_OPEN;
}

-(BOOL) isClosed
{
  return _internalWebSocket && _internalWebSocket.readyState == SR_CLOSED;
}

-(BOOL) isConnecting
{
  return _internalWebSocket && _internalWebSocket.readyState == SR_CONNECTING;
}

-(void) webSocketDidOpen:(SRWebSocket *)webSocket
{
  NSLog(@"WebSocket: connected");

  _reconnectCount = 0;

  _processor = [[DeviceServiceProcessor alloc] initWithDeviceService:self];
  
  if ([webSocket.protocol isEqualToString:@"compact"]) {
    _protocolFactory = TCompactProtocolFactory.sharedFactory;
  }
  else if ([webSocket.protocol isEqualToString:@"binary"]) {
    _protocolFactory = TBinaryProtocolFactory.sharedFactory;
  }
  else {
    DDLogWarn(@"Unknown websocket protocol %@, using default (binary)", webSocket.protocol);
    _protocolFactory = TBinaryProtocolFactory.sharedFactory;
  }
  
}

-(void) webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
  NSLog(@"WebSocket: closed");

  if (code != SRStatusCodeNormal) {
    [self tryToReconnect];
  }
}

-(void) webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
  NSLog(@"WebSocket: failed");

  if (![error checkDomain:NSURLErrorDomain code:NSURLErrorUserAuthenticationRequired]) {
    [self tryToReconnect];
  }
}

-(void) tryToReconnect
{
  if (_reconnectCount > kReconnectAttemptsMax) {
    NSLog(@"WebSocket: Max reconnect attempts reached, failed to reconnect");
    return;
  }

  NSTimeInterval reconnectTime = MIN(kReconnectIntervalMax, kReconnectInterval * _reconnectCount * kReconnectIntervalMultiplier);

  _reconnectCount++;

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(reconnectTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self checkAndReconnect];
  });

}

-(void) checkAndReconnect
{
  if (![self isConnecting] && ![self isOpen]) {
    [self reconnect];
  }
}

-(void) webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
  // Only process binary messages
  if (![message isKindOfClass:[NSData class]]) {
    return;
  }

  TMemoryBuffer *messageBuffer = [[TMemoryBuffer alloc] initWithDataNoCopy:message];
  id<TProtocol> inMessageProtocol = [_protocolFactory newProtocolOnTransport:messageBuffer];
  id<TProtocol> outMessageProtocol = [_protocolFactory newProtocolOnTransport:[NullTransport new]];

  NSError *error;
  if (![_processor processOnInputProtocol:inMessageProtocol outputProtocol:outMessageProtocol error:&error]) {
    DDLogError(@"Error processing device service: %@", error);
    return;
  }

}

-(BOOL) userStatus:(Alias)sender recipient:(Alias)recipient status:(UserStatus)status error:(NSError *__autoreleasing *)__thriftError
{
  [_delegate webSocket:self didReceiveUserStatus:sender recipient:recipient status:status];

  return YES;
}

-(BOOL) groupStatus:(Alias)sender chatId:(Id *)chatId status:(UserStatus)status error:(NSError *__autoreleasing *)__thriftError
{
  [_delegate webSocket:self didReceiveGroupStatus:sender chatId:chatId status:status];

  return YES;
}

-(BOOL) msgReady:(MsgHdr *)msgHdr error:(NSError *__autoreleasing *)__thriftError
{
  [_delegate webSocket:self didReceiveMsgReady:msgHdr];

  return YES;
}

-(BOOL) msgDelivery:(Msg *)msg error:(NSError *__autoreleasing *)__thriftError
{
  [_delegate webSocket:self didReceiveMsgDelivery:msg];

  return YES;
}

-(BOOL) msgDirect:(DirectMsg *)msg error:(NSError *__autoreleasing *)__thriftError
{
  [_delegate webSocket:self didReceiveMsgDirect:msg];

  return YES;
}

-(BOOL) msgDelivered:(Id *)msgId recipient:(Alias)recipient error:(NSError *__autoreleasing *)__thriftError
{
  [_delegate webSocket:self didReceiveMsgDelivered:msgId recipient:recipient];

  return YES;
}

@end



@implementation NullTransport

-(BOOL) readAll:(UInt8 *)buf offset:(UInt32)offset length:(UInt32)length error:(NSError *__autoreleasing *)error
{
  return NO;
}

-(BOOL) readAvail:(UInt8 *)buf offset:(UInt32)offset length:(UInt32 *)length error:(NSError *__autoreleasing *)error
{
  return NO;
}

-(BOOL) write:(const UInt8 *)data offset:(UInt32)offset length:(UInt32)length error:(NSError *__autoreleasing *)error
{
  return YES;
}

-(BOOL) flush:(NSError *__autoreleasing *)error
{
  return YES;
}


@end
