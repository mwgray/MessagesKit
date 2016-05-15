//
//  AddressBookExternalObserver.h
//  Timee
//
//  Created by salabaha on 4/2/15.
//  Copyright (c) 2015 Timee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AddressBook/AddressBook.h>

typedef void (^ChangeCallback)(ABAddressBookRef addressBookRef);

@interface SwiftAddressBookObserver : NSObject

- (void)startObserveChangesWithCallback:(ChangeCallback)callback;
- (void)stopObserveChanges;

@end
