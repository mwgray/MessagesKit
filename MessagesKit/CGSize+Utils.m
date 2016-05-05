//
//  CGSize+Utils.m
//  ReTxt
//
//  Created by Kevin Wooten on 3/21/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

#import "CGSize+Utils.h"

@import Foundation;


CGSize CGSizeWithMaxWidth(CGSize size, CGFloat maxWidth)
{
  CGFloat newWidth = MIN(size.width, maxWidth);
  return CGSizeMake(newWidth, size.height * (newWidth / size.width));
}

CGSize CGSizeScale(CGSize size, CGFloat scale)
{
  return CGSizeMake(size.width * scale, size.height * scale);
}
