//
//  SendReceiptOperation.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation


class SendMessageReceiptOperation: MessageAPIOperation {
  
  let message : Message
  
  init(message: Message, api: MessageAPI) {
    self.message = message
    super.init(api: api)
  }
  
  override func execute() {
    
    if message.sentByMe || message is EnterMessage || message is ExitMessage {
      // Skip... no need for these
      finish()
      return
    }
    
    let receipt = MessageSendSystemOperation(msgType: .View,
                                             chat: message.chat,
                                             metaData: [MetaDataKey_TargetMessageId: message.id.UUIDString],
                                             target: .Standard,
                                             api: api)
    produceOperation(receipt)
  }

}


class SendChatReceiptOperation: MessageAPIOperation {
  
  let chat : Chat
  
  init(chat: Chat, api: MessageAPI) {
    self.chat = chat
    super.init(api: api)
  }
  
  override func execute() {
    
    if let message = try! api.messageDAO.fetchLatestUnviewedMessageForChat(chat) {
      
      try! api.messageDAO.viewAllMessagesForChat(chat, before: message.sent ?? NSDate())
      
      produceOperation(SendMessageReceiptOperation(message: message, api: api))
      
    }
    
  }
  
}
