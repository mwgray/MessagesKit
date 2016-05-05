//
//  BackgroundSessionOperations.swift
//  ReTxt
//
//  Created by Kevin Wooten on 7/15/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import Security
import PSOperations
import CocoaLumberjack


public protocol BackgroundSessionOperation {
  
  var taskIdentifier : Int { get }

  func taskCompletedWithError(error: NSError)
  
}


public protocol BackgroundSessionUploadOperation: BackgroundSessionOperation {
  
  
  func taskCompletedWithData(data: NSData)
  
}


public protocol BackgroundSessionDownloadOperation: BackgroundSessionOperation {
  
  
  func taskCompletedWithURL(url: NSURL)
  
}



@objc public class BackgroundSessionOperations: NSObject {
  
  
  enum Error: ErrorType {
    case InvalidResponse
  }
  
  
  static let TaskStartNotification = "BackgroundSessionOperationsTaskStartNotification"
  static let TaskProgressNotification = "BackgroundSessionOperationsTaskProgressNotification"
  static let TaskFinishNotification = "BackgroundSessionOperationsTaskFinishNotification"

  public typealias DelegateCompletionHandler = () -> Void
  
  static var delegateCompletionHandlers = [String: DelegateCompletionHandler]()
  
  public class func addDelegateCompletionHandler(completionHandler: DelegateCompletionHandler, withSessionIdentifier identifier: String) {
    delegateCompletionHandlers[identifier] = completionHandler
  }
  
  var taskData = [Int: NSMutableData]()
  
  let sslValidator : RTURLSessionSSLValidator
  
  weak var api : MessageAPI?
  
  let dao : RTMessageDAO
  
  let queue: OperationQueue
  
  var operations = [Int: BackgroundSessionOperation]()
  
  
  public init(trustedCertificates: [AnyObject], api: MessageAPI, dao: RTMessageDAO, queue: OperationQueue) {
    self.sslValidator = RTURLSessionSSLValidator(trustedCertificates: trustedCertificates)
    self.api = api
    self.dao = dao
    self.queue = queue
    super.init()
  }
  
  public func addOperation(operation: BackgroundSessionOperation) {
    operations[operation.taskIdentifier] = operation
  }

  public func resurrectOperationsForSession(session: NSURLSession, withCompletion completion: ([RTId]) -> Void) {
    
    session.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
      
      var backgroundTransferringMessageIds = [RTId]()
      
      for upload in (uploadTasks as [NSURLSessionUploadTask]) {
        
        let request = upload.originalRequest!
        
        switch upload.state {
          
        case .Running, .Suspended:
          
          if request.URL?.path == MessageAPI.target.userSendURL.path {
            
            do {
              
              if let msgInfoHeader = request.allHTTPHeaderFields?[RTMsgInfoHTTPHeader],
                let msgPack = try TBaseUtils.deserialize(RTMsgPack(), fromBase64String: msgInfoHeader) as? RTMsgPack,
                let api = self.api {
                
                  backgroundTransferringMessageIds.append(msgPack.id)
                  
                  self.queue.addOperation(try MessageSendResurrectedOperation(msgPack: msgPack, task: upload, api: api))
                  
              }
              else {
                DDLogError("BackgroundSessionOperation: Error resurrecting send: missing or invalid header")
              }
              
            }
            catch let error {
              DDLogError("BackgroundSessionOperation: Error resurrecting send: \(error)")
            }
            
          }
          
        default:
          break;
        }
        
      }
      
      for download in (downloadTasks as [NSURLSessionDownloadTask]) {
        
        let request = download.originalRequest!
        
        switch download.state {
          
        case .Running, .Suspended:
          
          if request.URL?.path == MessageAPI.target.userFetchURL.path {
            
            if let msgIdParam = request.URL?.queryValues()["id"],
              let msgId = RTId(string: msgIdParam)
            {
              
              backgroundTransferringMessageIds.append(msgId)
              
            }
            else {
              NSLog("BackgroundSessionOperation: Error resurrecting fetch: missing or invalid id param")
            }
            
          }
          
        default:
          break;
        }
        
      }
     
      completion(backgroundTransferringMessageIds)
    }
    
  }
  
}


extension BackgroundSessionOperations: NSURLSessionTaskDelegate {
  
  public func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {

    if let operation = operations[task.taskIdentifier] {
      
      if let uploadTask = task as? NSURLSessionUploadTask, let uploadOp = operation as? BackgroundSessionUploadOperation {
        
        do {
          let data = try dataWithResponse(uploadTask.response, data: taskData[task.taskIdentifier], networkError: error)
          uploadOp.taskCompletedWithData(data)
        }
        catch let error as NSError {
          uploadOp.taskCompletedWithError(error)
        }
        
      }
      else if let finalError = error {
        
        operation.taskCompletedWithError(finalError)
        
      }
      
    }
    else {
      
      NSLog("BackgroundSessionOperations: No operation for task #\(task.taskIdentifier)")
      
    }
    
    taskData.removeValueForKey(task.taskIdentifier)
    
    operations.removeValueForKey(task.taskIdentifier)
  }
  
  public func URLSession(session: NSURLSession, task: NSURLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
    NSLog("BackgroundSessionOperations: #\(task.taskIdentifier) Uploading: \(totalBytesSent)/\(totalBytesExpectedToSend)")
  }
  
}


extension BackgroundSessionOperations: NSURLSessionDataDelegate {
  
  public func URLSession(session: NSURLSession, dataTask: NSURLSessionDataTask, didReceiveData data: NSData) {
    
    if let taskData = taskData[dataTask.taskIdentifier] {
    
      taskData.appendData(data)
      
    }
    else {
      
      taskData[dataTask.taskIdentifier] = NSMutableData(data: data)
      
    }
    
  }
  
}


extension BackgroundSessionOperations: NSURLSessionDownloadDelegate {
  
  public func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    NSLog("BackgroundSessionOperations: #\(downloadTask.taskIdentifier) Downloading: \(totalBytesWritten)/\(totalBytesExpectedToWrite)")
  }
  
  public func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
    
    if let downloadOp = operations[downloadTask.taskIdentifier] as? BackgroundSessionDownloadOperation {
      
      downloadOp.taskCompletedWithURL(location)
      
    }
    else {
      
      NSLog("BackgroundSessionOperations: No operation for download task #\(downloadTask.taskIdentifier)")
      
    }
    
  }
  
}


extension BackgroundSessionOperations: NSURLSessionDelegate {
  
  public func URLSession(session: NSURLSession, didReceiveChallenge challenge: NSURLAuthenticationChallenge, completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential?) -> Void) {
    sslValidator.URLSession(session, didReceiveChallenge: challenge, completionHandler: completionHandler)
  }
  
  public func URLSession(session: NSURLSession, didBecomeInvalidWithError error: NSError?) {
    
  }

  public func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession) {
    
    if let delegateCompletionHandler = BackgroundSessionOperations.delegateCompletionHandlers[session.configuration.identifier!] {
      
      dispatch_async(dispatch_get_main_queue(), delegateCompletionHandler)
      
    }
    
  }
  
}


private func dataWithResponse(response: NSURLResponse?, data: NSData?, networkError: NSError?) throws -> NSData {

  if let networkError = networkError {
    throw networkError
  }
  
  var error = NSURLError.Unknown
  
  if let response = response as? NSHTTPURLResponse, let data = data {
    
    if response.statusCode == 200 {
      
      return data
      
    }
    else if response.statusCode == 401 {
      
      error = NSURLError.UserAuthenticationRequired
      
    }
    else {
      
      error = NSURLError.BadServerResponse
      
    }
    
  }
  else {
    
    error = data == nil ? NSURLError.ZeroByteResource : NSURLError.BadServerResponse
    
  }
  
  throw error
}
