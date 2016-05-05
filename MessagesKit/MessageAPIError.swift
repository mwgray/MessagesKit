//
//  MessageAPIError.swift
//  ReTxt
//
//  Created by Kevin Wooten on 9/15/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import Thrift


@objc public enum MessageAPIError: Int, ErrorType {
  case UnknownError                   = 1000
  case InvalidDocumentDirectoryURL    = 1001
  case InvalidMessageState            = 1002
  case RequiredUserUnknown            = 1003
  case InvalidRecipientCertificate    = 1004
  case InvalidRecipientAlias          = 1005
  case AuthenticationError            = 1006
  case DeviceNotReady                 = 1007
  case NetworkError                   = 2001
}

public let MessageAPIErrorDomain = (MessageAPIError.UnknownError as NSError).domain


extension NSError {
  
  convenience init(code: MessageAPIError, userInfo: [NSObject: AnyObject]?) {
    self.init(domain: MessageAPIError._NSErrorDomain, code: code.rawValue, userInfo: userInfo)
  }
  
}


// Compare an `NSError` to an `MessageAPIError`.
public func ==(lhs: NSError, rhs: MessageAPIError) -> Bool {
  return lhs.domain == MessageAPIErrorDomain && lhs.code == rhs.rawValue
}

public func ==(lhs: MessageAPIError, rhs: NSError) -> Bool {
  return rhs.domain == MessageAPIErrorDomain && lhs.rawValue == rhs.code
}



public func translateError(error: NSError) -> NSError {

  switch(error.domain, error.code) {
  case (TTransportErrorDomain, _):
    return NSError(code: .NetworkError, userInfo: [
      NSLocalizedDescriptionKey: "Error communicating with server",
      NSUnderlyingErrorKey: error])
    
  case (NSURLErrorDomain, NSURLErrorUserAuthenticationRequired):
    return NSError(code: .AuthenticationError, userInfo: [
      NSLocalizedDescriptionKey: "Invalid Authentication Credentials",
      NSUnderlyingErrorKey: error])
    
  case (MessageAPIErrorDomain, _):
    return error
    
  case (TTransportErrorDomain, TTransportError.Unknown.rawValue):
    if let httpErrorCode = error.userInfo[TTransportErrorHttpErrorKey] as? Int
      where httpErrorCode == THttpTransportError.Authentication.rawValue {
      return NSError(code: .AuthenticationError, userInfo: [
        NSLocalizedDescriptionKey: "Invalid Authentication Credentials",
        NSUnderlyingErrorKey: error])
    }
    fallthrough
    
  default:
    return NSError(code: .UnknownError, userInfo: [
      NSLocalizedDescriptionKey: "Unknown Error",
      NSUnderlyingErrorKey: error])
  }

}
