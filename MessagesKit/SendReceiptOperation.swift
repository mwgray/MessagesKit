//
//  SendReceiptOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation


class SendMessageReceiptOperation: MessageAPIOperation {
  
  let message : RTMessage
  
  init(message: RTMessage, api: MessageAPI) {
    self.message = message
    super.init(api: api)
  }
  
  override func execute() {
    
    if message.sentByMe || message is RTEnterMessage || message is RTExitMessage {
      // Skip... no need for these
      finish()
      return
    }
    
    let receipt = MessageSendSystemOperation(msgType: .View,
                                             chat: message.chat,
                                             metaData: [RTMetaDataKey_TargetMessageId: message.id.UUIDString()],
                                             target: .Standard,
                                             api: api)
    produceOperation(receipt)
  }

}


class SendChatReceiptOperation: MessageAPIOperation {
  
  let chat : RTChat
  
  init(chat: RTChat, api: MessageAPI) {
    self.chat = chat
    super.init(api: api)
  }
  
  override func execute() {
    
    if let message = api.messageDAO.fetchLatestUnviewedMessageForChat(chat) {
      
      try! api.messageDAO.viewAllMessagesForChat(chat, before: message.sent ?? NSDate())
      
      produceOperation(SendMessageReceiptOperation(message: message, api: api))
      
    }
    
  }
  
}
