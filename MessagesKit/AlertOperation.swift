//
//  AlertOperation.swift
//  Operations
//
//  Created by Kevin Wooten on 7/10/15.
//  Copyright © 2015 reTXT Labs, LLC. All rights reserved.
//

import UIKit
import PSOperations


class AlertOperation: Operation {

  // MARK: Properties

  private let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .Alert)
  private let presentationContext: UIViewController?
    
  var title: String? {
    get {
      return alertController.title
    }

    set {
      alertController.title = newValue
      name = newValue
    }
  }
    
  var message: String? {
    get {
      return alertController.message
    }
        
    set {
      alertController.message = newValue
    }
  }
    
  // MARK: Initialization
    
  init(presentationContext: UIViewController? = nil) {
    
    self.presentationContext = presentationContext ?? UIApplication.sharedApplication().keyWindow?.rootViewController

    super.init()
        
    addCondition(ModalCondition())
    addCondition(ViewHierarchyCondition())
  }
    
  func addAction(title: String, style: UIAlertActionStyle = .Default, handler: AlertOperation -> Void = { _ in }) {
  
    let action = UIAlertAction(title: title, style: style) { [weak self] _ in
      
      if let strongSelf = self {
        handler(strongSelf)
      }

      self?.finish()
    }
        
    alertController.addAction(action)
  }
    
  override func execute() {

    if let presentationContext = presentationContext {

      dispatch_async(dispatch_get_main_queue()) {
        
        if self.alertController.actions.isEmpty {
          self.addAction("Ok")
        }
            
        presentationContext.presentViewController(self.alertController, animated: true, completion: nil)
      }
      
    }
    else {
      
      finish()
      
    }
    
  }
  
}
