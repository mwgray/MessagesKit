//
//  MessageAPIError.swift
//  ReTxt
//
//  Created by Kevin Wooten on 9/15/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation

enum MessageAPIError: Int, ErrorType {
  case RequiredUserUnknown            = 1001
  case InvalidRecipientCertificate    = 1002
}


extension RTAPIError : ErrorType {
  
  
  
}