//
//  HTMLText.m
//  MessagesKit
//
//  Created by Kevin Wooten on 5/30/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

#import "HTMLText.h"

#import "NSString+Utils.h"
#import "UIFont+Utils.h"

@import HTMLReader;
@import MobileCoreServices;


@interface HTMLTextParser ()

@property (strong, nonatomic) NSMutableAttributedString *result;
@property (strong, nonatomic) UIFont *defaultFont;

@end


@implementation HTMLTextParser

-(instancetype) init
{
  return [self initWithDefaultFont:[UIFont systemFontOfSize:UIFont.systemFontSize]];
}

-(instancetype) initWithDefaultFont:(UIFont *)font
{
  if (self) {
    self.result = [NSMutableAttributedString new];
    self.defaultFont = font;
  }
  return self;
}

-(NSAttributedString *) parseWithString:(NSString *)string
{
  HTMLDocument *doc = [HTMLDocument documentWithString:string];
  if (!doc) {
    return [[NSAttributedString alloc] initWithString:@""];
  }

  return [self parse:doc];
}

-(NSAttributedString *) parseWithData:(NSData *)data
{
  HTMLDocument *doc = [HTMLDocument documentWithData:data contentTypeHeader:@"text/html"];
  if (!doc) {
    return [[NSAttributedString alloc] initWithString:@""];
  }

  return [self parse:doc];
}

-(NSAttributedString *) parse:(HTMLDocument *)doc
{
  NSMutableAttributedString *res = [NSMutableAttributedString new];

  NSDictionary *initialAttributes = @{NSFontAttributeName: _defaultFont};

  NSDictionary *context = @{@"result": res};

  [self parse:doc.rootElement context:context attributes:[initialAttributes mutableCopy]];

  return res;
}

-(void) parse:(HTMLNode *)node context:(NSDictionary *)context attributes:(NSMutableDictionary *)attributes
{
  for (HTMLNode *childNode in node.children) {

    NSMutableAttributedString *res = context[@"result"];

    if ([childNode isKindOfClass:HTMLTextNode.class]) {

      [res appendAttributedString:[[NSAttributedString alloc] initWithString:childNode.textContent
                                                                  attributes:attributes]];

    }
    else if ([childNode isKindOfClass:HTMLElement.class]) {

      HTMLElement *element = (id)childNode;

      NSMutableDictionary *elementAttributes = [attributes mutableCopy];

      if ([element.tagName isEqualToStringCI:@"b"]) {

        elementAttributes[NSFontAttributeName] = [attributes[NSFontAttributeName] bold];

      }
      else if ([element.tagName isEqualToStringCI:@"i"]) {

        elementAttributes[NSFontAttributeName] = [attributes[NSFontAttributeName] italic];

      }
      else if ([element.tagName isEqualToStringCI:@"u"]) {

        elementAttributes[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);

      }
      else if ([element.tagName isEqualToStringCI:@"a"]) {

        NSString *href = element.attributes[@"href"];
        if (href.length) {
          elementAttributes[NSLinkAttributeName] = [NSURL URLWithString:href];
          elementAttributes[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleThick);
          elementAttributes[NSFontAttributeName] = [attributes[NSFontAttributeName] bold];
        }

      }
      else if ([element.tagName isEqualToString:@"img"]) {

        id data = element.attributes[@"data"];
        NSString *type = element.attributes[@"type"];
        NSUInteger width = [element.attributes[@"width"] unsignedIntegerValue];
        NSUInteger height = [element.attributes[@"height"] unsignedIntegerValue];

        if (data && type && width && height) {

          data = [[NSData alloc] initWithBase64EncodedString:data options:NSDataBase64DecodingIgnoreUnknownCharacters];
          type = CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)type, NULL));

          elementAttributes[NSAttachmentAttributeName] = [[NSTextAttachment alloc] initWithData:data ofType:type];

        }

      }
      else if ([element.tagName isEqualToStringCI:@"br"]) {

        [res appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];

        continue;

      }

      [self parse:element context:context attributes:elementAttributes];

    }

  }
}

+(NSString *) extractText:(NSData *)data
{
  return [HTMLDocument documentWithData:data contentTypeHeader:@"text/html"].textContent;
}

@end
