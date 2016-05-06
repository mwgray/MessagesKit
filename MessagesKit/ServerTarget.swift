//
//  ServerTarget.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 4/26/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation


@objc public enum ServerTargetScheme : Int {
  case HTTP
  case HTTPS
}


@objc public enum ServerEnvironment : Int {
  case Sandbox
  case Production
}


@objc public class ServerTarget : NSObject {
  
  let scheme : ServerTargetScheme
  let hostName : String
  let port : Int?
  
  public init(scheme: ServerTargetScheme, hostName: String, port: Int) {
    self.scheme = scheme
    self.hostName = hostName
    self.port = port
  }
  
  public init(scheme: ServerTargetScheme, hostName: String) {
    self.scheme = scheme
    self.hostName = hostName
    self.port = nil
  }
  
  public init(searchForLocalServer serverName: String?) {
    
    let sd = ServerDiscovery()
    let service = sd.waitForService(serverName)
    
    self.scheme = .HTTP
    self.hostName = service.hostName!
    self.port = service.port
  }
 
  public init(environment: ServerEnvironment) {
    
    self.scheme = .HTTPS
    
    switch environment {
    case .Sandbox:
      self.hostName = "master.stg.retxt.io"
      self.port = nil
    
    case .Production:
      self.hostName = "master.prd.retxt.io"
      self.port = nil
    }
    
  }
  
}


extension ServerTargetScheme : CustomStringConvertible {
  
  public var description : String {
    switch self {
    case .HTTPS:
      return "https"
    case .HTTP:
      return "http"
    }
  }
  
}

extension ServerTarget {
  
  var baseURL : NSURL {
    
    let comps = NSURLComponents()
    comps.scheme = scheme.description
    comps.host = hostName
    comps.port = port
    
    return comps.URL!.URLByAppendingPathComponent("api")
  }
  
  var publicURL : NSURL {
    return baseURL.URLByAppendingPathComponent("public")
  }
  
  var userURL : NSURL {
    return baseURL.URLByAppendingPathComponent("user")
  }
  
  var userSendURL : NSURL {
    return userURL.URLByAppendingPathComponent("send")
  }
  
  var userFetchURL : NSURL {
    return userURL.URLByAppendingPathComponent("fetch")
  }
  
  var userConnectURL : NSURL {
    return userURL.URLByAppendingPathComponent("connect")
  }
  
}
