//
//  MessageAPI+Compat.h
//  MessagesKit
//
//  Created by Kevin Wooten on 4/24/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

@import  Foundation;


typedef NS_OPTIONS (int, SystemMsgTarget) {
  SystemMsgTargetActiveRecipients   = (1 << 0),
  SystemMsgTargetCC                 = (1 << 1),
  SystemMsgTargetInactiveRecipients = (1 << 2),
  SystemMsgTargetStandard           = SystemMsgTargetActiveRecipients | SystemMsgTargetCC,
  SystemMsgTargetEverybody          = SystemMsgTargetActiveRecipients | SystemMsgTargetCC | SystemMsgTargetInactiveRecipients,
};
