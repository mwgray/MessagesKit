//
//  NSObject+Utils.h
//  ReTxt
//
//  Created by Kevin Wooten on 3/7/15.
//  Copyright (c) 2015 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;
@import ObjectiveC;


static inline
BOOL isEqual(id a, id b)
{
  return a == b || [a isEqual:b];
}

static inline
void class_duplicateMethod(Class class, SEL newName, SEL oldName)
{
  Method method = class_getInstanceMethod(class, oldName);

  char sig[512];
  memset(sig, 0, sizeof(sig));

  method_getReturnType(method, sig + strlen(sig), sizeof(sig)-strlen(sig));
  for (int c=0, cnt=method_getNumberOfArguments(method); c < cnt; ++c) {
    method_getArgumentType(method, c, sig + strlen(sig), sizeof(sig)-strlen(sig));
  }

  class_addMethod(class, newName, method_getImplementation(method), sig);
}


@interface NSObject (Utils)

@end
