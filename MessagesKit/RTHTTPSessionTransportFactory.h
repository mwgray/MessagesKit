//
//  RTHTTPSessionTransportFactory.h
//  ReTxt
//
//  Created by Kevin Wooten on 12/21/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import <Thrift/THTTPSessionTransport.h>


NS_ASSUME_NONNULL_BEGIN


typedef NSError  * _Nullable  (^RTHttpSessionTransportFactoryRequestInterceptor)(NSMutableURLRequest *request);

@interface RTHTTPSessionTransportFactory : THTTPSessionTransportFactory

@property (strong, nonatomic) RTHttpSessionTransportFactoryRequestInterceptor requestInterceptor;

@end


NS_ASSUME_NONNULL_END
