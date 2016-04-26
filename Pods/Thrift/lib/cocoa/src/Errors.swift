//
//  File.swift
//  Pods
//
//  Created by Kevin Wooten on 11/27/15.
//
//

import Foundation



extension TTransportError : _BridgedNSError {
  public static var _NSErrorDomain : String {
    return TTransportErrorDomain
  }
}

extension THttpTransportError : _BridgedNSError {
  public static var _NSErrorDomain : String {
    return TTransportErrorDomain
  }
}

extension TProtocolError : _BridgedNSError {
  public static var _NSErrorDomain : String {
    return TProtocolErrorDomain
  }
}

extension TProtocolExtendedError : _BridgedNSError {
  public static var _NSErrorDomain : String {
    return TProtocolErrorDomain
  }
}

extension TApplicationError : _BridgedNSError {
  public static var _NSErrorDomain : String {
    return TApplicationErrorDomain
  }
}
