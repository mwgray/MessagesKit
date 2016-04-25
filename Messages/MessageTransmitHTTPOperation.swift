//
//  MessageTransmitHTTPOperation.swift
//  ReTxt
//
//  Created by Kevin Wooten on 7/23/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import Operations
import Thrift


/*
  Transmits the message via the HTTP upload API
*/
class MessageTransmitHTTPOperation: Operation {
  
  
  class func temporaryDirectory() throws -> NSURL {
    
    let sendTempDir = NSURL(fileURLWithPath: NSTemporaryDirectory() + "/Send")
  
    if !sendTempDir.checkResourceIsReachableAndReturnError(nil) {
      try NSFileManager.defaultManager().createDirectoryAtURL(sendTempDir, withIntermediateDirectories: true, attributes: nil)
    }
    
    return sendTempDir
  }
  
  
  var context : MessageTransmitContext
  
  var task : NSURLSessionUploadTask?
  
  let api : MessageAPI
  
  
  init(context: MessageTransmitContext, api: MessageAPI) {
    self.context = context
    self.api = api
    
    super.init()
    
    addCondition(NoFailedDependencies())
    addCondition(ReachabilityCondition(host: RTServerAPI.userSendURL()))
    
    addObserver(NetworkObserver())
  }
  
  convenience init(task: NSURLSessionUploadTask, context: MessageTransmitContext, api: MessageAPI) {
    
    self.init(context: context, api: api)
    
    self.task = task
    
  }
  
  override func execute() {
    
    do {
      
      // Resurrected transmit operations will already
      // have a task reference
      
      if task == nil {
        try initiateUpload()
      }
      
      // Wait for task notification from background transfer service
      
      let backgroundOperations = api.backgroundURLSession.delegate as! BackgroundSessionOperations
      backgroundOperations.addOperation(self)
      
    }
    catch let error as NSError {
      finishWithError(error)
    }
    
  }
  
  override func cancel() {
    task?.cancel()
    super.cancel()
  }
  
  override var description : String {
    return "Send: Transmit (HTTP)"
  }
  
  private func initiateUpload() throws {
    
    // Build request
    //
    let msgInfo = try TBaseUtils.serializeToBase64String(context.msgPack!)
    
    let request = NSMutableURLRequest(URL: RTServerAPI.userSendURL())
    request.HTTPMethod = "POST";
    request.addHTTPBearerAuthorizationWithToken(api.accessToken)
    request.setValue(RTOctetStreamContentType, forHTTPHeaderField: RTContentTypeHTTPHeader)
    request.setValue(RTThriftContentType, forHTTPHeaderField: RTAcceptHTTPHeader)
    request.setValue("\(try context.encryptedData!.dataSize())", forHTTPHeaderField: RTContentLengthHTTPHeader)
    request.setValue(msgInfo, forHTTPHeaderField: RTMsgInfoHTTPHeader)
    
    // Generate file for uploading
    //
    
    let sendTempDir = try MessageTransmitHTTPOperation.temporaryDirectory()
    
    let sendTempFile = sendTempDir.URLByAppendingPathComponent(context.msgPack!.id.UUIDString())
    do {
      try NSFileManager.defaultManager().removeItemAtURL(sendTempFile)
    }
    catch _ {
    }
    
    let sendTempRef = try FileDataReference.copyFrom(context.encryptedData!, toPath: sendTempFile.path!, filteredBy: nil)
    
    // Initiate upload task
    //
    task = api.backgroundURLSession.uploadTaskWithRequest(request, fromFile: sendTempRef.URL)
    
    task!.resume()
  }
  
  func cleanup() {
    
    // Remove temporary file
    do {

      let sendTempDir = try MessageTransmitHTTPOperation.temporaryDirectory()
      
      let sendTempFile = sendTempDir.URLByAppendingPathComponent(context.msgPack!.id.UUIDString())
      
      try NSFileManager.defaultManager().removeItemAtURL(sendTempFile)
      
    }
    catch _ {
    }
    
  }
  
}

extension MessageTransmitHTTPOperation: BackgroundSessionUploadOperation {
  
  var taskIdentifier: Int {
    return task!.taskIdentifier
  }
  
  func taskCompletedWithData(data: NSData) {
    
    cleanup()
    
    do {
      
      let resultClass = NSClassFromString("RTUserAPI_send_result") as! NSObject.Type

      if let result = try TBaseUtils.deserialize(resultClass.init() as! TBase, fromData: data) as? NSObject {
      
        if let sentAt = result.valueForKey("success") as? RTTimeStamp {
        
          context.sentAt = sentAt
        
          finish()
        
          return
        
        }
        else {
        
          if let ex = result.valueForKey("invalidSender") as? RTInvalidSender {
            throw ex
          }
          else if let ex = result.valueForKey("invalidRecipient") as? RTInvalidRecipient {
            throw ex
          }
          else if let ex = result.valueForKey("invalidCredentials") as? RTInvalidCredentials {
            throw ex
          }
          else {
            throw NSError(domain: TApplicationErrorDomain, code: Int(TApplicationError.MissingResult.rawValue), userInfo: nil)
          }
          
        }
      
      }
      else {
        throw NSError(domain: TApplicationErrorDomain, code: Int(TApplicationError.Unknown.rawValue), userInfo: nil)
      }
      
    }
    catch let error as NSError {
    
      finishWithError(error)
      
    }
    
  }
  
  func taskCompletedWithError(error: NSError) {
    
    cleanup()
    
    finishWithError(error)
  }
  
}
