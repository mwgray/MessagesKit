//
//  UIKitConditions.swift
//  Messages
//
//  Created by Kevin Wooten on 5/3/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation
import PSOperations


enum Modal {}
typealias ModalCondition = MutuallyExclusive<Modal>

typealias ViewHierarchyCondition = MutuallyExclusive<UIViewController>
