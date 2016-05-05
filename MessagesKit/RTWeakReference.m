//
//  RTWeakReference.m
//  ReTxt
//
//  Created by Kevin Wooten on 12/4/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

#import "RTWeakReference.h"

static intptr_t hashShiftValue;

@implementation RTWeakReference

+(void) initialize
{
  hashShiftValue = (intptr_t)log2(1 + sizeof(id));
}

+(instancetype) weakReferenceWithValue:(id)value
{
  return [[self alloc] initWithValue:value track:YES];
}

-(instancetype) initWithValue:(id)value track:(BOOL)track
{
  self = [super init];
  if (self) {
    _currentReference = track ? value : nil;
    _originalReference = value;
  }
  return self;
}

-(BOOL) isEqual:(id)object
{
  if (![object isMemberOfClass:RTWeakReference.class]) return NO;
  RTWeakReference *other = object;
  return _originalReference == other->_originalReference;
}

-(NSUInteger) hash
{
  return ((intptr_t)_originalReference) >> hashShiftValue;
}

@end
