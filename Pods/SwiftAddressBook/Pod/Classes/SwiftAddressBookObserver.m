//
//  AddressBookExternalObserver.m
//  Timee
//
//  Created by salabaha on 4/2/15.
//  Copyright (c) 2015 Timee. All rights reserved.
//

#import "SwiftAddressBookObserver.h"

@interface SwiftAddressBookObserver()

@property (nonatomic, copy) ChangeCallback changeCallback;
@property (nonatomic, readonly) ABAddressBookRef addressBook;

@end

@implementation SwiftAddressBookObserver

-(id)init {
	self = [super init];
	if (self) {

		CFErrorRef *error = NULL;
		_addressBook = ABAddressBookCreateWithOptions(NULL, error);
		if (error)
		{
			NSLog(@"%@", (__bridge_transfer NSString *)CFErrorCopyFailureReason(*error));
			return nil;
		}
	}
	return self;
}

- (void)startObserveChangesWithCallback:(ChangeCallback)callback
{
	if (callback)
	{
		if (!self.changeCallback)
		{
			ABAddressBookRegisterExternalChangeCallback(self.addressBook,
														APAddressBookExternalChangeCallback,
														(__bridge void *)(self));
		}
		self.changeCallback = callback;
	}
}

- (void)stopObserveChanges
{
	if (self.changeCallback)
	{
		self.changeCallback = nil;
		ABAddressBookUnregisterExternalChangeCallback(self.addressBook,
													  APAddressBookExternalChangeCallback,
													  (__bridge void *)(self));
	}
}

#pragma mark - external change callback

void APAddressBookExternalChangeCallback(ABAddressBookRef __unused addressBookRef,
										 CFDictionaryRef __unused info,
										 void *context)
{
	SwiftAddressBookObserver *addressBook = (__bridge SwiftAddressBookObserver *)(context);
	addressBook.changeCallback ? addressBook.changeCallback(addressBookRef) : nil;
}

@end
