//
//  MessageTransmitHTTPOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 7/23/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import PSOperations
import Thrift


/*
  Transmits the message via the HTTP upload API
*/
class MessageTransmitHTTPOperation: Operation {
  
  
  var context : MessageTransmitContext
  
  var task : NSURLSessionUploadTask?
  
  let api : MessageAPI
  
  
  init(context: MessageTransmitContext, api: MessageAPI) {
    self.context = context
    self.api = api
    
    super.init()
    
    addCondition(NoFailedDependencies())
    addCondition(ReachabilityCondition(host: MessageAPI.target.userSendURL))
    
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
    
    let request = NSMutableURLRequest(URL: MessageAPI.target.userSendURL)
    request.HTTPMethod = "POST";
    request.addHTTPBearerAuthorizationWithToken(api.accessToken)
    request.setValue(OctetStreamContentType, forHTTPHeaderField: ContentTypeHTTPHeader)
    request.setValue(ThriftContentType, forHTTPHeaderField: AcceptHTTPHeader)
    request.setValue("\(try context.encryptedData!.dataSize())", forHTTPHeaderField: ContentLengthHTTPHeader)
    request.setValue(msgInfo, forHTTPHeaderField: MsgInfoHTTPHeader)
    
    // Generate file for uploading
    //
    
    
    let sendTempURL = NSURL(fileURLWithPath: NSTemporaryDirectory())
      .URLByAppendingPathComponent(context.msgPack!.id.UUIDString)
      .URLByAppendingPathExtension("send")
    let _ = try? NSFileManager.defaultManager().removeItemAtURL(sendTempURL)
    
    try context.encryptedData?.writeToURL(sendTempURL)
    
    // Initiate upload task
    //
    task = api.backgroundURLSession.uploadTaskWithRequest(request, fromFile: sendTempURL)
    
    task!.resume()
  }
  
  func cleanup() {
    
    // Remove temporary file
    let sendTempURL = NSURL(fileURLWithPath: NSTemporaryDirectory())
      .URLByAppendingPathComponent(context.msgPack!.id.UUIDString)
      .URLByAppendingPathExtension("send")
    let _ = try? NSFileManager.defaultManager().removeItemAtURL(sendTempURL)
    
  }
  
}

extension MessageTransmitHTTPOperation: BackgroundSessionUploadOperation {
  
  var taskIdentifier: Int {
    return task!.taskIdentifier
  }
  
  func taskCompletedWithData(data: NSData) {
    
    cleanup()
    
    do {
      
      let resultClass = NSClassFromString("UserAPI_send_result") as! NSObject.Type

      if let result = try TBaseUtils.deserialize(resultClass.init() as! TBase, fromData: data) as? NSObject {
      
        if let sentAt = result.valueForKey("success") as? TimeStamp {
        
          context.sentAt = sentAt
        
          finish()
        
          return
        
        }
        else {
        
          if let ex = result.valueForKey("invalidSender") as? InvalidSender {
            throw ex
          }
          else if let ex = result.valueForKey("invalidRecipient") as? InvalidRecipient {
            throw ex
          }
          else if let ex = result.valueForKey("invalidCredentials") as? InvalidCredentials {
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
