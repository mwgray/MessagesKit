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
  
  let api : MessageAPI
  
  
  init(context: MessageFetchContext, api: MessageAPI) {
    
    self.context = context
    self.api = api
    
    super.init()
    
    addCondition(NoFailedDependencies())
    addCondition(ReachabilityCondition(host: MessageAPI.target.userFetchURL))
    
    addObserver(NetworkObserver())
  }
  
  convenience init(task: NSURLSessionDownloadTask, context: MessageFetchContext, api: MessageAPI) {
    
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
    
    let backgroundOperations = api.backgroundURLSession.delegate as! BackgroundSessionOperations
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
    
    let fetchURL = MessageAPI.target.userFetchURL.URLByAppendingQueryParameters(["id": context.msgHdr!.id.UUIDString()])
    
    let request = NSMutableURLRequest(URL: fetchURL)
    request.HTTPMethod = "GET";
    request.addHTTPBearerAuthorizationWithToken(api.accessToken)
    request.setValue(RTOctetStreamContentType, forHTTPHeaderField: RTAcceptHTTPHeader)
    
    task = api.backgroundURLSession.downloadTaskWithRequest(request)
    
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
      
      context.encryptedData = try FileDataReference(path: downloadURL.path!).temporaryDuplicate()
      
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
