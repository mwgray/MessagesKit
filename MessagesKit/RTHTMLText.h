//
//  RTHTMLText.h
//  MessagesKit
//
//  Created by Kevin Wooten on 5/30/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;
@import UIKit;


@interface RTHTMLTextParser : NSObject

-(instancetype) initWithDefaultFont:(UIFont *)font;

-(NSAttributedString *) parseWithData:(NSData *)data;
-(NSAttributedString *) parseWithString:(NSString *)string;

+(NSString *) extractText:(NSData *)data;

@end
