//
//  RTHTTPSessionTransportFactory.m
//  ReTxt
//
//  Created by Kevin Wooten on 12/21/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTHTTPSessionTransportFactory.h"

#import "NSMutableURLRequest+Utils.h"
#import "RTServerAPI.h"


@interface THTTPSessionTransportFactory (Internal)

-(NSURLSessionDataTask *) taskWithRequest:(NSURLRequest *)request
                        completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler
                                    error:(NSError *__autoreleasing *)error;
@end



@implementation RTHTTPSessionTransportFactory

-(NSURLSessionDataTask *) taskWithRequest:(NSURLRequest *)request
                        completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler
                                    error:(NSError *__autoreleasing *)error
{
  NSMutableURLRequest *processedRequest = request.mutableCopy;

  if (self.requestInterceptor) {
    NSError *intError = self.requestInterceptor(processedRequest);
    if (intError) {
      if (error) {
        *error = intError;
      }
      return nil;
    }
  }
  
  return [super taskWithRequest:processedRequest
              completionHandler:completionHandler
                          error:error];
}

@end
