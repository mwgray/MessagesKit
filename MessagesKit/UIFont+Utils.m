//
//  UIFont+Utils.m
//  MessagesKit
//
//  Created by Kevin Wooten on 5/30/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

#import "UIFont+Utils.h"

#import <CoreText/CoreText.h>


@implementation UIFont (Utils)

-(UIFont *) bold
{
  UIFontDescriptor *fontDesc = [self.fontDescriptor fontDescriptorWithSymbolicTraits:self.fontDescriptor.symbolicTraits|UIFontDescriptorTraitBold];
  return [UIFont fontWithDescriptor:fontDesc size:self.pointSize];
}

-(UIFont *) italic
{
  UIFontDescriptor *fontDesc = [self.fontDescriptor fontDescriptorWithSymbolicTraits:self.fontDescriptor.symbolicTraits|UIFontDescriptorTraitItalic];
  return [UIFont fontWithDescriptor:fontDesc size:self.pointSize];
}

@end
