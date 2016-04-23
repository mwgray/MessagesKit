//
//  RTWebSocket.m
//  ReTxt
//
//  Created by Francisco Rimoldi on 02/05/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTWebSocket.h"

#import "SRWebSocket.h"
#import "RTServerAPI.h"
#import "NSError+Utils.h"
#import "RTLog.h"

@import Thrift;


RT_LUMBERJACK_DECLARE_LOG_LEVEL()


static const double kRTReconnectInterval = 1.0;
static const double kRTReconnectIntervalMultiplier = 1.0;
static const double kRTReconnectIntervalMax = 10.0;
static const int kRTReconnectAttemptsMax = 50;


@interface RTWebSocket () <SRWebSocketDelegate, RTDeviceService> {
  SRWebSocket *_internalWebSocket;
  uint _reconnectCount;
  RTDeviceServiceProcessor *_processor;
  id<TProtocolFactory> _protocolFactory;
}

@end


@implementation RTWebSocket

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
  reqs.SR_SSLPinnedCertificates = RTServerAPI.pinnedCerts;
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
  NSLog(@"RTWebSocket: connecting");

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

  NSLog(@"RTWebSocket: disconnecting");

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
  NSLog(@"RTWebSocket: connected");

  _reconnectCount = 0;

  _processor = [[RTDeviceServiceProcessor alloc] initWithDeviceService:self];
  
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
  NSLog(@"RTWebSocket: closed");

  if (code != SRStatusCodeNormal) {
    [self tryToReconnect];
  }
}

-(void) webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
  NSLog(@"RTWebSocket: failed");

  if (![error checkDomain:NSURLErrorDomain code:NSURLErrorUserAuthenticationRequired]) {
    [self tryToReconnect];
  }
}

-(void) tryToReconnect
{
  if (_reconnectCount > kRTReconnectAttemptsMax) {
    NSLog(@"RTWebSocket: Max reconnect attempts reached, failed to reconnect");
    return;
  }

  NSTimeInterval reconnectTime = MIN(kRTReconnectIntervalMax, kRTReconnectInterval * _reconnectCount * kRTReconnectIntervalMultiplier);

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
  id<TProtocol> messageProtocol = [_protocolFactory newProtocolOnTransport:messageBuffer];

  NSError *error;
  if (![_processor processOnInputProtocol:messageProtocol outputProtocol:messageProtocol error:&error]) {
    DDLogError(@"Error processing device service: %@", error);
    return;
  }

}

-(BOOL) userStatus:(RTAlias)sender recipient:(RTAlias)recipient status:(RTUserStatus)status error:(NSError *__autoreleasing *)__thriftError
{
  [_delegate webSocket:self didReceiveUserStatus:sender recipient:recipient status:status];

  return YES;
}

-(BOOL) groupStatus:(RTAlias)sender chatId:(RTId *)chatId status:(RTUserStatus)status error:(NSError *__autoreleasing *)__thriftError
{
  [_delegate webSocket:self didReceiveGroupStatus:sender chatId:chatId status:status];

  return YES;
}

-(BOOL) msgReady:(RTMsgHdr *)msgHdr error:(NSError *__autoreleasing *)__thriftError
{
  [_delegate webSocket:self didReceiveMsgReady:msgHdr];

  return YES;
}

-(BOOL) msgDelivery:(RTMsg *)msg error:(NSError *__autoreleasing *)__thriftError
{
  [_delegate webSocket:self didReceiveMsgDelivery:msg];

  return YES;
}

-(BOOL) msgDirect:(RTDirectMsg *)msg error:(NSError *__autoreleasing *)__thriftError
{
  [_delegate webSocket:self didReceiveMsgDirect:msg];

  return YES;
}

-(BOOL) msgDelivered:(RTId *)msgId recipient:(RTAlias)recipient error:(NSError *__autoreleasing *)__thriftError
{
  [_delegate webSocket:self didReceiveMsgDelivered:msgId recipient:recipient];

  return YES;
}

@end
