//
//  TestClient.swift
//  ReTxt
//
//  Created by Kevin Wooten on 3/12/16.
//  Copyright © 2016 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import OMGHTTPURLRQ
@testable import MessagesKit

public typealias SenderInterceptor = (RTMsgPack) throws -> Void
public typealias SendMethod = (RTMsgPack) throws -> Int64

public class TestClient: NSObject {
  
  public class Device: NSObject, RTWebSocketDelegate {
    
    let client : TestClient
  
    public var deviceInfo : RTDeviceInfo!
    public var refreshToken : NSData!
    public var accessToken : String!
    public var preferredAlias : String!
    
    var userAPI : RTUserAPIClient
    var webSocket : RTWebSocket
    
    public var receivedUserStatuses = [(String, RTUserStatus)]()
    public var receivedUserStatusQueue = UnboundedBlockingQueue<(String, RTUserStatus)>()
    
    public var receivedGroupStatuses = [(String, RTUserStatus)]()
    public var receivedGroupStatusQueue = UnboundedBlockingQueue<(String, RTUserStatus)>()
    
    public var receivedReceipts = [String]()
    public var receivedReceiptQueue = UnboundedBlockingQueue<String>()
    
    public var receivedMessages = [RTMsg]()
    public var receivedMessageQueue = UnboundedBlockingQueue<RTMsg>()
    
    public var receivedDirectMessages = [RTDirectMsg]()
    public var receivedDirectMessageQueue = UnboundedBlockingQueue<RTDirectMsg>()
    
    init(deviceInfo: RTDeviceInfo, preferredAlias: String, client: TestClient) {
      self.client = client
      self.deviceInfo = deviceInfo
      self.preferredAlias = preferredAlias
      self.refreshToken = try! client.publicAPI.signIn(client.userId, password: client.password, deviceId: deviceInfo.id)
      self.accessToken = try! client.publicAPI.generateAccessToken(client.userId, deviceId: deviceInfo.id, refreshToken: self.refreshToken)
      self.userAPI = Device.createUserAPIClient(self.accessToken, baseURL: client.baseURL)
      self.webSocket = RTWebSocket(URL: NSURL(string: "api/user/connect", relativeToURL: client.baseURL)!)
      
      super.init()
      
      self.webSocket.delegate = self
    }
    
    public func openWebSocket() {
      webSocket.connect()
    }
    
    public func closeWebSocket() {
      webSocket.disconnect()
    }
    
    public func webSocket(webSocket: RTWebSocket, willConnect request: NSMutableURLRequest) {
      request.addHTTPBearerAuthorizationWithToken(accessToken)
    }
    
    public func webSocket(webSocket: RTWebSocket, didReceiveUserStatus sender: String, recipient: String, status: RTUserStatus) {
      
      let pair = ("\(sender):\(recipient)",status)
      receivedUserStatuses.append(pair)
      receivedUserStatusQueue.put(pair)
      
      print("Device \(deviceInfo.name): User Status: \(pair.0) @ \(pair.1)")
    }
    
    public func webSocket(webSocket: RTWebSocket, didReceiveGroupStatus sender: String, chatId: RTId, status: RTUserStatus) {
      
      let pair = ("\(sender):\(chatId.description)",status)
      receivedGroupStatuses.append(pair)
      receivedGroupStatusQueue.put(pair)
      
      print("Device \(deviceInfo.name): Group Status: \(pair.0) @ \(pair.1)")
    }
    
    public func webSocket(webSocket: RTWebSocket, didReceiveMsgDelivery msg: RTMsg) {
      
      try! verifyDecryptAndAddMsg(msg)
      
      print("Device \(deviceInfo.name): Delivery: \(msg.id)")
    }
    
    public func webSocket(webSocket: RTWebSocket, didReceiveMsgReady msgHdr: RTMsgHdr) {
     
      print("Device \(deviceInfo.name): Ready (Started): \(msgHdr.id)")

      let msg : RTMsg
      
      if msgHdr.dataLength > (16 * 1024) {
        
        let url = NSURL(string: "api/user/fetch", relativeToURL: client.baseURL)
        
        let req = try! OMGHTTPURLRQ.GET(url!.absoluteString, ["id":msgHdr.id.description])
        req.addHTTPBearerAuthorizationWithToken(accessToken)
        req.setValue(RTOctetStreamContentType, forHTTPHeaderField: RTAcceptHTTPHeader)

        NSURLConnection.sendAsynchronousRequest(req, queue: client.operationQueue, completionHandler: { (response, data, error) -> Void in
          
          if let httpResponse = response as? NSHTTPURLResponse {
            let msgInfoHdr = httpResponse.allHeaderFields[RTMsgInfoHTTPHeader] as! String
            let msg = try! TBaseUtils.deserialize(RTMsg(), fromBase64String: msgInfoHdr) as! RTMsg
            msg.data = data
            
            try! self.verifyDecryptAndAddMsg(msg)

            print("Device \(self.deviceInfo.name): Ready (Finished): \(msg.id)")
          }
          
        })
        
      }
      else {
        
        msg = try! userAPI.fetch(msgHdr.id)
        
        try! verifyDecryptAndAddMsg(msg)
      
        print("Device \(deviceInfo.name): Ready (Finished): \(msg.id)")
      }
      
    }
    
    public func webSocket(webSocket: RTWebSocket, didReceiveMsgDirect msg: RTDirectMsg) {
      
      try! verifyDecryptAndAddDirectMsg(msg)
      
      print("Device \(deviceInfo.name): Direct: \(msg.id)")
    }
    
    public func webSocket(webSocket: RTWebSocket, didReceiveMsgDelivered msgId: RTId, recipient: String) {

      let receipt = "\(msgId.description)-\(recipient)"
      receivedReceipts.append(receipt)
      receivedReceiptQueue.put(receipt)
      
      print("Delivered: \(msgId) @ \(recipient)")
    }
    
    func verifyDecryptAndAddMsg(msg: RTMsg) throws {
      
      if msg.signatureIsSet {
        
        let senderInfo = try client.publicAPI.findUserWithAlias(msg.sender)
        let senderCert = try RTOpenSSLCertificate(DEREncodedData: senderInfo.signingCert)
        
        try RTMsgSigner(publicKey: senderCert.publicKey, signature: msg.signature).verifyMsg(msg)
      }
      
      if msg.keyIsSet {
        msg.key = try client.encryptionIdentity.privateKey.decryptData(msg.key)
        msg.data = try RTMsgCipher(forKey: msg.key).decryptData(msg.data, withKey: msg.key)
      }
      
      receivedMessages.append(msg)
      receivedMessageQueue.put(msg)
    }
    
    func verifyDecryptAndAddDirectMsg(msg: RTDirectMsg) throws {
      
      if msg.signatureIsSet {
        
        let senderInfo = try client.publicAPI.findUserWithAlias(msg.sender)
        let senderCert = try RTOpenSSLCertificate(DEREncodedData: senderInfo.signingCert)
        
        try RTMsgSigner(publicKey: senderCert.publicKey, signature: msg.signature).verifyDirectMsg(msg, forDevice: deviceInfo.id)
      }
      
      if msg.keyIsSet {
        msg.key = try client.encryptionIdentity.privateKey.decryptData(msg.key)
        msg.data = try RTMsgCipher(forKey: msg.key).decryptData(msg.data, withKey: msg.key)
      }
      
      receivedDirectMessages.append(msg)
      receivedDirectMessageQueue.put(msg)
    }
    
    class func createUserAPIClient(token: String, baseURL: NSURL) -> RTUserAPIClient {
      
      let url = NSURL(string: "api/user", relativeToURL: baseURL)!

      let transport = THTTPTransport(URL: url)
      let request = transport.valueForKey("request")!
      request.setValue(RTThriftContentType + ";p=compact", forHTTPHeaderField: RTContentTypeHTTPHeader)
      request.setValue(RTThriftContentType + ";p=compact", forHTTPHeaderField: RTAcceptHTTPHeader)
      request.addHTTPBearerAuthorizationWithToken(token)
      
      let proto = TCompactProtocol(transport: transport)
      
      return RTUserAPIClient(withProtocol: proto)
    }
    
    public func sendUserStatus(status: RTUserStatus, from sender: String? = nil, to recipient: String) throws -> (String, RTUserStatus) {
      let sender : String = sender ?? preferredAlias
      try userAPI.sendUserStatus(sender, recipient: recipient, status: status)
      return ("\(sender):\(recipient)",status)
    }
    
    public func sendGroupStatus(status: RTUserStatus, from sender: String? = nil, to group: RTGroup) throws -> (String, RTUserStatus) {
      let sender : String = sender ?? preferredAlias
      try userAPI.sendGroupStatus(sender, group: group, status: status)
      return ("\(sender):\(group.chat.description)",status)
    }
    
    public func sendImage(image: NSData, mimeType: String, from sender: String? = nil, to recipient: String, interceptor: SenderInterceptor? = nil) throws -> RTMsg {
      return try self.send(from: sender ?? preferredAlias,
        to: recipient,
        type: RTMsgType.Image,
        data: image,
        metaData: [RTMetaDataKey_MimeType:mimeType],
        interceptor: interceptor,
        method: self.sendViaHTTP)
    }
    
    public func sendText(text: String, from sender: String? = nil, to recipient: String, interceptor: SenderInterceptor? = nil) throws -> RTMsg {
      return try self.send(from: sender ?? preferredAlias,
        to: recipient,
        type: RTMsgType.Text,
        data: text.dataUsingEncoding(NSUTF8StringEncoding)!,
        metaData: [RTMetaDataKey_MimeType:"text/plain"],
        interceptor: interceptor,
        method: self.sendViaAPI)
    }
    
    public func sendViaAPI(msg: RTMsgPack) throws -> RTTimeStamp {
      return try userAPI.send(msg).longLongValue
    }
    
    public func sendViaHTTP(msg: RTMsgPack) throws -> RTTimeStamp {
      
      let msgData = msg.data
      msg.unsetData()
      
      let url = NSURL(string: "api/user/send", relativeToURL: client.baseURL)!
      
      let req = NSMutableURLRequest(URL: url)
      req.HTTPMethod = "POST"
      req.addValue(RTOctetStreamContentType, forHTTPHeaderField: RTContentTypeHTTPHeader)
      req.addValue(RTThriftContentType + ";p=binary", forHTTPHeaderField: RTAcceptHTTPHeader)
      req.addValue(try TBaseUtils.serializeToBase64String(msg), forHTTPHeaderField: RTMsgInfoHTTPHeader)
      req.addHTTPBearerAuthorizationWithToken(accessToken)
      req.HTTPBody = msgData
      
      var response : NSURLResponse?
      let responseData = try NSURLConnection.sendSynchronousRequest(req, returningResponse: &response)
      
      let resultClass = NSClassFromString("RTUserAPI_send_result") as! NSObject.Type
      
      if let result = try TBaseUtils.deserialize(resultClass.init() as! TBase, fromData: responseData) as? NSObject {
        
        if let sentAt = result.valueForKey("success") as? RTTimeStamp {
          
          return sentAt
          
        }
        else {
          
          if let ex = result.valueForKey("invalidSender") as? RTInvalidSender {
            throw ex
          }
          else if let ex = result.valueForKey("invalidRecipient") as? RTInvalidRecipient {
            throw ex
          }
          else if let ex = result.valueForKey("invalidCredentials") as? RTInvalidCredentials {
            throw ex
          }
          else {
            throw NSError(domain: TApplicationErrorDomain, code: Int(TApplicationError.MissingResult.rawValue), userInfo: nil)
          }
          
        }
        
      }
      
      throw NSError(domain: TApplicationErrorDomain, code: Int(TApplicationError.Unknown.rawValue), userInfo: nil)
    }
    
    public func send(from sender: String, to recipient: String, type: RTMsgType, data: NSData, metaData: [String:String], interceptor: SenderInterceptor?, method: SendMethod) throws -> RTMsg {
      
      let cipher = RTMsgCipher.defaultCipher()
      let msgKey = try cipher.randomKey()
      
      let recipientInfo = try client.publicAPI.findUserWithAlias(recipient)
      
      let msg = RTMsgPack()
      msg.id = RTId.generate()
      msg.type = type
      msg.sender = sender
      msg.metaData = (metaData as NSDictionary).mutableCopy() as! NSMutableDictionary
      msg.data = try cipher.encryptData(data, withKey: msgKey)
      
      let envelope = RTEnvelope()
      envelope.recipient = recipient
      envelope.key = try RTOpenSSLCertificate(DEREncodedData: recipientInfo.encryptionCert).publicKey.encryptData(msgKey)
      envelope.signature = try RTMsgSigner.defaultSignerWithKeyPair(client.signingIdentity.keyPair)
        .signWithId(msg.id, type: msg.type, sender: msg.sender, recipient: recipient, chatId: msg.chat, msgKey: envelope.key)
      envelope.fingerprint = recipientInfo.fingerprint
      
      let ccEnvelope = RTEnvelope()
      ccEnvelope.recipient = sender
      ccEnvelope.key = try client.encryptionIdentity.publicKey.encryptData(msgKey)
      ccEnvelope.signature = try RTMsgSigner.defaultSignerWithKeyPair(client.signingIdentity.keyPair)
        .signWithId(msg.id, type: msg.type, sender: msg.sender, recipient: recipient, chatId: msg.chat, msgKey: envelope.key)
      ccEnvelope.fingerprint = nil
      
      msg.envelopes = [envelope, ccEnvelope]
      
      if let interceptor = interceptor {
        try interceptor(msg)
      }
      
      let sent = try method(msg)
      
      let result = RTMsg()
      result.id = msg.id
      result.type = msg.type
      result.sender = msg.sender
      result.recipient = recipient
      result.key = msgKey
      result.signature = envelope.signature
      result.data = data
      result.metaData = (metaData as NSDictionary).mutableCopy() as! NSMutableDictionary
      result.sent = sent
      return result
    }
    
    public func clearHistory() {
      receivedUserStatuses.removeAll()
      receivedGroupStatuses.removeAll()
      receivedReceipts.removeAll()
      receivedMessages.removeAll()
      receivedDirectMessages.removeAll()
    }
    
    public func clearQueues() {
      receivedUserStatusQueue.clear()
      receivedGroupStatusQueue.clear()
      receivedReceiptQueue.clear()
      receivedMessageQueue.clear()
      receivedDirectMessageQueue.clear()
    }
    
  }
  
  var baseURL : NSURL
  
  var publicAPI : RTPublicAPIClient!
  
  public var userId : RTId!
  public var password : String!
  public var devices = [Device]()
  
  public var encryptionIdentity : RTAsymmetricIdentity!
  public var signingIdentity : RTAsymmetricIdentity!
  
  var operationQueue = NSOperationQueue()
 
  public init(baseURL: NSURL) throws {
    
    self.baseURL = baseURL
    
    super.init()
    
    self.publicAPI = TestClient.createPublicAPIClient(baseURL)
    
    let firstAlias = TestClient.randomStringWithLength(8) + "@m.retxt.io"
    let secondAlias = TestClient.randomStringWithLength(8) + "@m.retxt.io"
    let thirdAlias = TestClient.randomStringWithLength(8) + "@m.retxt.io"
    
    let firstDevice = RTDeviceInfo()
    firstDevice.id = RTId.generate()
    firstDevice.name = "First"
    firstDevice.manufacturer = "reTXT"
    firstDevice.model = "Test"
    firstDevice.osVersion = "N/A"
    firstDevice.version = "1"
    firstDevice.activeAliases = [firstAlias]

    let secondDevice = RTDeviceInfo()
    secondDevice.id = RTId.generate()
    secondDevice.name = "Second"
    secondDevice.manufacturer = "reTXT"
    secondDevice.model = "Test"
    secondDevice.osVersion = "N/A"
    secondDevice.version = "2"
    secondDevice.activeAliases = [secondAlias]
    
    let thirdDevice = RTDeviceInfo()
    thirdDevice.id = RTId.generate()
    thirdDevice.name = "Second"
    thirdDevice.manufacturer = "reTXT"
    thirdDevice.model = "Test"
    thirdDevice.osVersion = "N/A"
    thirdDevice.version = "3"
    thirdDevice.activeAliases = [firstAlias, secondAlias, thirdAlias]
    
    self.password = TestClient.randomStringWithLength(8)
    
    let encryptionIdentity = try RTAsymmetricKeyPairGenerator.generateIdentityRequestNamed("TestEncrypt", withKeySize: 2048, usage: .KeyEncipherment)
    let signingIdentity = try RTAsymmetricKeyPairGenerator.generateIdentityRequestNamed("TestSigning", withKeySize: 2048, usage: .DigitalSignature)
    
    let userProfile = try publicAPI.registerUser(password,
      encryptionCSR: encryptionIdentity.certificateSigningRequest.encoded,
      signingCSR: signingIdentity.certificateSigningRequest.encoded,
      authenticatedAliases: [
        RTAuthenticatedAlias(name: firstAlias, pin: "$#$#"),
        RTAuthenticatedAlias(name: secondAlias, pin: "$#$#"),
        RTAuthenticatedAlias(name: thirdAlias, pin: "$#$#")
      ],
      deviceInfo: firstDevice)
    
    try publicAPI.registerDevice(userProfile.id, password: password, deviceInfo: secondDevice)
    try publicAPI.registerDevice(userProfile.id, password: password, deviceInfo: thirdDevice)
    
    self.userId = userProfile.id
    
    self.encryptionIdentity = encryptionIdentity.buildIdentityWithCertificate(try RTOpenSSLCertificate(DEREncodedData: userProfile.encryptionCert))
    self.signingIdentity = signingIdentity.buildIdentityWithCertificate(try RTOpenSSLCertificate(DEREncodedData: userProfile.signingCert))
    
    self.devices = [
      Device(deviceInfo: firstDevice, preferredAlias: firstAlias, client: self),
      Device(deviceInfo: secondDevice, preferredAlias: secondAlias, client: self),
      Device(deviceInfo: thirdDevice, preferredAlias: thirdAlias, client: self)
    ]
  }
  
  public func findDeviceForSender(sender: String) -> Device {
    return devices.filter { $0.preferredAlias == sender }.first ?? devices.filter { $0.deviceInfo.activeAliases.containsObject(sender) }.first!
  }
  
  public func sendUserStatus(status: RTUserStatus, from sender: String, to recipient: String) throws -> (String, RTUserStatus) {
    return try findDeviceForSender(sender).sendUserStatus(status, from: sender, to: recipient)
  }
  
  class func createPublicAPIClient(baseURL: NSURL) -> RTPublicAPIClient {
    
    let url = NSURL(string: "/api/public", relativeToURL: baseURL)!
    
    let transport = THTTPTransport(URL: url)
    let request = transport.valueForKey("request")!
    request.setValue(RTThriftContentType + ";p=compact", forHTTPHeaderField: RTContentTypeHTTPHeader)
    request.setValue(RTThriftContentType + ";p=compact", forHTTPHeaderField: RTAcceptHTTPHeader)
    
    let proto = TCompactProtocol(transport: transport)
    
    return RTPublicAPIClient(withProtocol: proto)
  }

  class func randomStringWithLength(len : Int) -> String {
    
    let digits : String = "0123456789abcdefghijklmnopqrstuvwxyz"
    
    var pass = ""
    
    for _ in 0 ..< len {
      let pos = Int(arc4random_uniform(UInt32(digits.characters.count)))
      pass.append(digits[digits.startIndex.advancedBy(pos)])
    }
    
    return pass
  }
  
}
