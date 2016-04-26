import Foundation

public let OperationErrorDomain = "OperationErrors"

public enum OperationErrorCode: Int {
  case ConditionFailed = 1
  case ExecutionFailed = 2
  case TimeoutExceeded = 3
}

public let OperationErrorOriginalErrorKey = "originalError"

extension NSError {

  public convenience init(failedConditionName: String, extraInfo: [String: AnyObject]? = nil) {
    
    var userInfo : [String: AnyObject] = [OperationConditionKey: failedConditionName]
    
    if let extras = extraInfo {
      extras.forEach { userInfo[$0] = $1 }
    }
    
    self.init(domain: OperationErrorDomain, code: OperationErrorCode.ConditionFailed.rawValue, userInfo: userInfo)
  }
  
  public convenience init(code: OperationErrorCode, userInfo: [NSObject: AnyObject]? = nil) {
    self.init(domain: OperationErrorDomain, code: code.rawValue, userInfo: userInfo)
  }
  
  public convenience init(code: OperationErrorCode, originalError: NSError) {
    self.init(domain: OperationErrorDomain, code: code.rawValue, userInfo: [OperationErrorOriginalErrorKey: originalError])
  }
  
}

// Compare an `NSError.code` to an `OperationErrorCode`.
public func ==(lhs: Int, rhs: OperationErrorCode) -> Bool {
  return lhs == rhs.rawValue
}

public func ==(lhs: OperationErrorCode, rhs: Int) -> Bool {
  return lhs.rawValue == rhs
}
