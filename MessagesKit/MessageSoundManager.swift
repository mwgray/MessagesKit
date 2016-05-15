//
//  MessageSoundManager.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 5/12/16.
//  Copyright © 2016 reTXT Labs LLC. All rights reserved.
//

import Foundation
import AudioToolbox


@objc public enum MessageSoundType : Int {
  case Sent      = 1
  case Received  = 2
  case Updated   = 3
  case Clarified = 4
}


@objc public class MessageSoundManager : NSObject {
  
  private static let sharedManager = MessageSoundManager()
  
  private var soundSourceURLs = [MessageSoundType: NSURL]()
  private var soundSystemIDs = [MessageSoundType: SystemSoundID]()
  
  override init() {
  }
  
  public func replaceSoundOfType(type: MessageSoundType, withSoundAtURL soundURL: NSURL) -> Bool {
    
    var soundID = SystemSoundID()
    if AudioServicesCreateSystemSoundID(soundURL, &soundID) != noErr {
      return false
    }
    
    soundSourceURLs[type] = soundURL
    soundSystemIDs[type] = soundID
    
    return true
  }
  
  public func playSoundOfType(type: MessageSoundType, asAlert alerted: Bool) -> Bool {
    
    guard let soundID = soundSystemIDs[type] else {
      return false
    }
    
    if alerted {
      AudioServicesPlayAlertSound(soundID)
    }
    else {
      AudioServicesPlaySystemSound(soundID)
    }

    return true
  }
  
  public func notificationNameForSoundOfType(type: MessageSoundType) -> String? {
    
    guard let soundURL = soundSourceURLs[type] else {
      return nil
    }
    
    return soundURL.lastPathComponent
  }
  
}



extension MessageSoundType {
  
  func play() {
    MessageSoundManager.sharedManager.playSoundOfType(self, asAlert: false)
  }
  
  func playAlert() {
    MessageSoundManager.sharedManager.playSoundOfType(self, asAlert: true)
  }
  
  func notificationName() -> String? {
    return MessageSoundManager.sharedManager.notificationNameForSoundOfType(self)
  }
  
}
