//
//  MessageRecipientResolveOperation.swift
//  ReTxt
//
//  Created by Kevin Wooten on 7/23/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import Operations


/*
  Resolves recipient aliases into UserInfo objects
*/
class MessageRecipientResolveOperation: MessageAPIOperation {
  
  
  var context : MessageResolveContext
  
  
  init(context: MessageResolveContext, api: MessageAPI) {
    
    self.context = context
    
    super.init(api: api)
    
    addCondition(NoFailedDependencies())
    addCondition(ReachabilityCondition(host: MessageAPI.target.userURL))
    
    addObserver(NetworkObserver())
  }
  
  override func execute() {
    
    var recipientsInfo = [String: RTUserInfo]()
    
    for recipientAlias in context.recipients {
      
      do {
        if let recipientInfo = try api.resolveUserInfoWithAlias(recipientAlias) {
          recipientsInfo[recipientAlias] = recipientInfo
        }
        else {
          throw NSError(code: MessageAPIError.InvalidRecipientAlias, userInfo: ["alias":recipientAlias])
        }
      }
      catch let error as NSError {
        finishWithError(error)
        return;
      }
    }
    
    context.recipientInformation = recipientsInfo
    
    finish()
  }
  
  override var description : String {
    return "Send: Resolve Recipients"
  }
  
}
