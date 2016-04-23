//
//  MessageFetchHTTPOperation.swift
//  ReTxt
//
//  Created by Kevin Wooten on 7/26/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import Operations


class MessageFetchHTTPOperation: Operation {
  
  enum Error: ErrorType {
    case InvalidResponse
    case InvalidMessageHeader
  }
  
  
  var context: MessageFetchContext
  
  var task : NSURLSessionDownloadTask?
  
  let api : RTMessageAPI
  
  
  init(context: MessageFetchContext, api: RTMessageAPI) {
    
    self.context = context
    self.api = api
    
    super.init()
    
    addCondition(NoFailedDependencies())
    addCondition(ReachabilityCondition(host: RTServerAPI.userURL()))
    
    addObserver(NetworkObserver())
  }
  
  convenience init(task: NSURLSessionDownloadTask, context: MessageFetchContext, api: RTMessageAPI) {
    
    self.init(context: context, api: api)
    
    self.task = task
    
  }
  
  override func execute() {
    
    // Resurrected fetch operations will already
    // have a task reference
    
    if task == nil {
    
      if !initiateDownload() {
        return
      }
      
    }
    
    // Wait for task notification from background transfer service
    
    let backgroundOperations = api.backgroundSession.delegate as! BackgroundSessionOperations
    backgroundOperations.addOperation(self)
    
  }
  
  override func cancel() {
    task?.cancel()
    super.cancel()
  }
  
  override var description : String {
    return "Recv: Fetch (HTTP)"
  }
  
  func initiateDownload() -> Bool {
    
    let fetchURL = RTServerAPI.userFetchURL().URLByAppendingQueryParameters(["id": context.msgHdr!.id.UUIDString()])
    
    let request = NSMutableURLRequest(URL: fetchURL)
    request.HTTPMethod = "GET";
    request.addHTTPBearerAuthorizationWithToken(api.accessToken)
    request.setValue(RTOctetStreamContentType, forHTTPHeaderField: RTAcceptHTTPHeader)
    
    task = api.backgroundSession.downloadTaskWithRequest(request)
    
    task!.resume()
    
    return true
  }
  
}


extension MessageFetchHTTPOperation: BackgroundSessionDownloadOperation {

  var taskIdentifier : Int {
    return task!.taskIdentifier
  }
  
  func taskCompletedWithURL(downloadURL: NSURL) {
    
    guard let response = task?.response as? NSHTTPURLResponse where response.statusCode == 200 else {
      finishWithError(Error.InvalidResponse as NSError)
      return
    }
    
    do {

      // Deserialize the Msg-Info header
      
      if let msgInfoHeader = response.allHeaderFields[RTMsgInfoHTTPHeader] as? String,
        let msg = try TBaseUtils.deserialize(RTMsg(), fromBase64String:msgInfoHeader) as? RTMsg
      {
        context.msg = msg
      }
      else {
        throw Error.InvalidMessageHeader
      }
      
      // Copy data to safe location & store it
      
      let tempPath = NSTemporaryDirectory().stringByAppendingPathComponent(NSUUID().UUIDString)
      
      let data = try FileDataReference.copyFrom(FileDataReference(path: downloadURL.path!), toPath: tempPath)
        
      context.encryptedData = data
      
      finish()
      
    }
    catch let error as NSError {
      finishWithError(error)
      return
    }
    
  }
  
  func taskCompletedWithError(error: NSError) {
   
    finishWithError(error)
    
  }
  
}
