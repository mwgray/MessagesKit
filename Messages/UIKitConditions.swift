//
//  UIKitConditions.swift
//  Messages
//
//  Created by Kevin Wooten on 5/3/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation
import PSOperations


public enum Modal {}
public typealias ModalCondition = MutuallyExclusive<Modal>

public typealias ViewHierarchyCondition = MutuallyExclusive<UIViewController>
