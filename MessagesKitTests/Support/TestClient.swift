//
//  TestClient.swift
//  MessagesKit
//
//  Created by Kevin Wooten on 3/12/16.
//  Copyright © 2016 reTXT Labs, LLC. All rights reserved.
//

import Foundation
import OMGHTTPURLRQ
@testable import MessagesKit

public typealias SenderInterceptor = (MsgPack) throws -> Void
public typealias SendMethod = (MsgPack) throws -> Int64

public class TestClient: NSObject {
  
  public class Device: NSObject, WebSocketDelegate {
    
    let client : TestClient
  
    public var deviceInfo : DeviceInfo!
    public var refreshToken : NSData!
    public var accessToken : String!
    public var preferredAlias : String!
    
    var userAPI : UserAPIClient
    var webSocket : WebSocket
    
    public var receivedUserStatuses = [(String, UserStatus)]()
    public var receivedUserStatusQueue = UnboundedBlockingQueue<(String, UserStatus)>()
    
    public var receivedGroupStatuses = [(String, UserStatus)]()
    public var receivedGroupStatusQueue = UnboundedBlockingQueue<(String, UserStatus)>()
    
    public var receivedReceipts = [String]()
    public var receivedReceiptQueue = UnboundedBlockingQueue<String>()
    
    public var receivedMessages = [Msg]()
    public var receivedMessageQueue = UnboundedBlockingQueue<Msg>()
    
    public var receivedDirectMessages = [DirectMsg]()
    public var receivedDirectMessageQueue = UnboundedBlockingQueue<DirectMsg>()
    
    init(deviceInfo: DeviceInfo, preferredAlias: String, client: TestClient) {
      self.client = client
      self.deviceInfo = deviceInfo
      self.preferredAlias = preferredAlias
      self.refreshToken = try! client.publicAPI.signIn(client.userId, password: client.password, deviceId: deviceInfo.id)
      self.accessToken = try! client.publicAPI.generateAccessToken(client.userId, deviceId: deviceInfo.id, refreshToken: self.refreshToken)
      self.userAPI = Device.createUserAPIClient(self.accessToken, baseURL: client.baseURL)
      self.webSocket = WebSocket(URL: NSURL(string: "api/user/connect", relativeToURL: client.baseURL)!)
      
      super.init()
      
      self.webSocket.delegate = self
    }
    
    public func openWebSocket() {
      webSocket.connect()
    }
    
    public func closeWebSocket() {
      webSocket.disconnect()
    }
    
    public func webSocket(webSocket: WebSocket, willConnect request: NSMutableURLRequest) {
      request.addHTTPBearerAuthorizationWithToken(accessToken)
    }
    
    public func webSocket(webSocket: WebSocket, didReceiveUserStatus sender: String, recipient: String, status: UserStatus) {
      
      let pair = ("\(sender):\(recipient)",status)
      receivedUserStatuses.append(pair)
      receivedUserStatusQueue.put(pair)
      
      print("Device \(deviceInfo.name): User Status: \(pair.0) @ \(pair.1)")
    }
    
    public func webSocket(webSocket: WebSocket, didReceiveGroupStatus sender: String, chatId: Id, status: UserStatus) {
      
      let pair = ("\(sender):\(chatId.description)",status)
      receivedGroupStatuses.append(pair)
      receivedGroupStatusQueue.put(pair)
      
      print("Device \(deviceInfo.name): Group Status: \(pair.0) @ \(pair.1)")
    }
    
    public func webSocket(webSocket: WebSocket, didReceiveMsgDelivery msg: Msg) {
      
      try! verifyDecryptAndAddMsg(msg)
      
      print("Device \(deviceInfo.name): Delivery: \(msg.id)")
    }
    
    public func webSocket(webSocket: WebSocket, didReceiveMsgReady msgHdr: MsgHdr) {
     
      print("Device \(deviceInfo.name): Ready (Started): \(msgHdr.id)")

      let msg : Msg
      
      if msgHdr.dataLength > (16 * 1024) {
        
        let url = NSURL(string: "api/user/fetch", relativeToURL: client.baseURL)
        
        let req = try! OMGHTTPURLRQ.GET(url!.absoluteString, ["id":msgHdr.id.description])
        req.addHTTPBearerAuthorizationWithToken(accessToken)
        req.setValue(OctetStreamContentType, forHTTPHeaderField: AcceptHTTPHeader)

        NSURLConnection.sendAsynchronousRequest(req, queue: client.operationQueue, completionHandler: { (response, data, error) -> Void in
          
          if let httpResponse = response as? NSHTTPURLResponse {
            let msgInfoHdr = httpResponse.allHeaderFields[MsgInfoHTTPHeader] as! String
            let msg = try! TBaseUtils.deserialize(Msg(), fromBase64String: msgInfoHdr) as! Msg
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
    
    public func webSocket(webSocket: WebSocket, didReceiveMsgDirect msg: DirectMsg) {
      
      try! verifyDecryptAndAddDirectMsg(msg)
      
      print("Device \(deviceInfo.name): Direct: \(msg.id)")
    }
    
    public func webSocket(webSocket: WebSocket, didReceiveMsgDelivered msgId: Id, recipient: String) {

      let receipt = "\(msgId.description)-\(recipient)"
      receivedReceipts.append(receipt)
      receivedReceiptQueue.put(receipt)
      
      print("Delivered: \(msgId) @ \(recipient)")
    }
    
    func verifyDecryptAndAddMsg(msg: Msg) throws {
      
      if msg.signatureIsSet {
        
        let senderInfo = try client.publicAPI.findUserWithAlias(msg.sender)
        let senderCert = try OpenSSLCertificate(DEREncodedData: senderInfo.signingCert)
        
        try MsgSigner(publicKey: senderCert.publicKey, signature: msg.signature).verifyMsg(msg)
      }
      
      if msg.keyIsSet {
        msg.key = try client.encryptionIdentity.privateKey.decryptData(msg.key)
        msg.data = try MsgCipher(forKey: msg.key).decryptData(msg.data, withKey: msg.key)
      }
      
      receivedMessages.append(msg)
      receivedMessageQueue.put(msg)
    }
    
    func verifyDecryptAndAddDirectMsg(msg: DirectMsg) throws {
      
      if msg.signatureIsSet {
        
        let senderInfo = try client.publicAPI.findUserWithAlias(msg.sender)
        let senderCert = try OpenSSLCertificate(DEREncodedData: senderInfo.signingCert)
        
        try MsgSigner(publicKey: senderCert.publicKey, signature: msg.signature).verifyDirectMsg(msg, forDevice: deviceInfo.id)
      }
      
      if msg.keyIsSet {
        msg.key = try client.encryptionIdentity.privateKey.decryptData(msg.key)
        msg.data = try MsgCipher(forKey: msg.key).decryptData(msg.data, withKey: msg.key)
      }
      
      receivedDirectMessages.append(msg)
      receivedDirectMessageQueue.put(msg)
    }
    
    class func createUserAPIClient(token: String, baseURL: NSURL) -> UserAPIClient {
      
      let url = NSURL(string: "api/user", relativeToURL: baseURL)!

      let transport = THTTPTransport(URL: url)
      let request = transport.valueForKey("request")!
      request.setValue(ThriftContentType + ";p=compact", forHTTPHeaderField: ContentTypeHTTPHeader)
      request.setValue(ThriftContentType + ";p=compact", forHTTPHeaderField: AcceptHTTPHeader)
      request.addHTTPBearerAuthorizationWithToken(token)
      
      let proto = TCompactProtocol(transport: transport)
      
      return UserAPIClient(withProtocol: proto)
    }
    
    public func sendUserStatus(status: UserStatus, from sender: String? = nil, to recipient: String) throws -> (String, UserStatus) {
      let sender : String = sender ?? preferredAlias
      try userAPI.sendUserStatus(sender, recipient: recipient, status: status)
      return ("\(sender):\(recipient)",status)
    }
    
    public func sendGroupStatus(status: UserStatus, from sender: String? = nil, to group: Group) throws -> (String, UserStatus) {
      let sender : String = sender ?? preferredAlias
      try userAPI.sendGroupStatus(sender, group: group, status: status)
      return ("\(sender):\(group.chat.description)",status)
    }
    
    public func sendImage(image: NSData, mimeType: String, from sender: String? = nil, to recipient: String, interceptor: SenderInterceptor? = nil) throws -> Msg {
      return try self.send(from: sender ?? preferredAlias,
        to: recipient,
        type: MsgType.Image,
        data: image,
        metaData: [MetaDataKey_MimeType:mimeType],
        interceptor: interceptor,
        method: self.sendViaHTTP)
    }
    
    public func sendText(text: String, from sender: String? = nil, to recipient: String, interceptor: SenderInterceptor? = nil) throws -> Msg {
      return try self.send(from: sender ?? preferredAlias,
        to: recipient,
        type: MsgType.Text,
        data: text.dataUsingEncoding(NSUTF8StringEncoding)!,
        metaData: [MetaDataKey_MimeType:"text/plain"],
        interceptor: interceptor,
        method: self.sendViaAPI)
    }
    
    public func updateTextMsg(msg:Msg, newText:String, interceptor: SenderInterceptor? = nil) throws -> Msg {
        return try self.send(
                             id: msg.id,
                             from: msg.sender,
                             to: msg.recipient,
                             type: MsgType.Text,
                             data: newText.dataUsingEncoding(NSUTF8StringEncoding)!,
                             metaData: [MetaDataKey_MimeType:"text/plain"],
                             interceptor: interceptor,
                             method: self.sendViaAPI)
    }
    
    public func sendViaAPI(msg: MsgPack) throws -> TimeStamp {
      return try userAPI.send(msg).longLongValue
    }
    
    public func sendViaHTTP(msg: MsgPack) throws -> TimeStamp {
      
      let msgData = msg.data
      msg.unsetData()
      
      let url = NSURL(string: "api/user/send", relativeToURL: client.baseURL)!
      
      let req = NSMutableURLRequest(URL: url)
      req.HTTPMethod = "POST"
      req.addValue(OctetStreamContentType, forHTTPHeaderField: ContentTypeHTTPHeader)
      req.addValue(ThriftContentType + ";p=binary", forHTTPHeaderField: AcceptHTTPHeader)
      req.addValue(try TBaseUtils.serializeToBase64String(msg), forHTTPHeaderField: MsgInfoHTTPHeader)
      req.addHTTPBearerAuthorizationWithToken(accessToken)
      req.HTTPBody = msgData
      
      var response : NSURLResponse?
      let responseData = try NSURLConnection.sendSynchronousRequest(req, returningResponse: &response)
      
      let resultClass = NSClassFromString("UserAPI_send_result") as! NSObject.Type
      
      if let result = try TBaseUtils.deserialize(resultClass.init() as! TBase, fromData: responseData) as? NSObject {
        
        if let sentAt = result.valueForKey("success") as? TimeStamp {
          
          return sentAt
          
        }
        else {
          
          if let ex = result.valueForKey("invalidSender") as? InvalidSender {
            throw ex
          }
          else if let ex = result.valueForKey("invalidRecipient") as? InvalidRecipient {
            throw ex
          }
          else if let ex = result.valueForKey("invalidCredentials") as? InvalidCredentials {
            throw ex
          }
          else {
            throw NSError(domain: TApplicationErrorDomain, code: Int(TApplicationError.MissingResult.rawValue), userInfo: nil)
          }
          
        }
        
      }
      
      throw NSError(domain: TApplicationErrorDomain, code: Int(TApplicationError.Unknown.rawValue), userInfo: nil)
    }
    
    public func send(id id:Id = Id.generate(), from sender: String, to recipient: String, type: MsgType, data: NSData, metaData: [String:String], interceptor: SenderInterceptor?, method: SendMethod) throws -> Msg {
        
      let cipher = MsgCipher.defaultCipher()
      let msgKey = try cipher.randomKey()
      
      let recipientInfo = try client.publicAPI.findUserWithAlias(recipient)
      
      let msg = MsgPack()
      msg.id = id
      msg.type = type
      msg.sender = sender
      msg.metaData = (metaData as NSDictionary).mutableCopy() as! NSMutableDictionary
      msg.data = try cipher.encryptData(data, withKey: msgKey)
      
      let envelope = Envelope()
      envelope.recipient = recipient
      envelope.key = try OpenSSLCertificate(DEREncodedData: recipientInfo.encryptionCert).publicKey.encryptData(msgKey)
      envelope.signature = try MsgSigner.defaultSignerWithKeyPair(client.signingIdentity.keyPair)
        .signWithId(msg.id, type: msg.type, sender: msg.sender, recipient: recipient, chatId: msg.chat, msgKey: envelope.key)
      envelope.fingerprint = recipientInfo.fingerprint
      
      let ccEnvelope = Envelope()
      ccEnvelope.recipient = sender
      ccEnvelope.key = try client.encryptionIdentity.publicKey.encryptData(msgKey)
      ccEnvelope.signature = try MsgSigner.defaultSignerWithKeyPair(client.signingIdentity.keyPair)
        .signWithId(msg.id, type: msg.type, sender: msg.sender, recipient: recipient, chatId: msg.chat, msgKey: envelope.key)
      ccEnvelope.fingerprint = nil
      
      msg.envelopes = [envelope, ccEnvelope]
      
      if let interceptor = interceptor {
        try interceptor(msg)
      }
      
      let sent = try method(msg)
      
      let result = Msg()
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
  
  var publicAPI : PublicAPIClient!
  
  public var userId : Id!
  public var password : String!
  public var devices = [Device]()
  
  public var encryptionIdentity : AsymmetricIdentity!
  public var signingIdentity : AsymmetricIdentity!
  
  var operationQueue = NSOperationQueue()
 
  public init(baseURL: NSURL) throws {
    
    self.baseURL = baseURL
    
    super.init()
    
    self.publicAPI = TestClient.createPublicAPIClient(baseURL)
    
    let firstAlias = TestClient.randomStringWithLength(8) + "@m.retxt.io"
    let secondAlias = TestClient.randomStringWithLength(8) + "@m.retxt.io"
    let thirdAlias = TestClient.randomStringWithLength(8) + "@m.retxt.io"
    
    let firstDevice = DeviceInfo()
    firstDevice.id = Id.generate()
    firstDevice.name = "First"
    firstDevice.manufacturer = "reTXT"
    firstDevice.model = "Test"
    firstDevice.osVersion = "N/A"
    firstDevice.version = "1"
    firstDevice.activeAliases = [firstAlias]

    let secondDevice = DeviceInfo()
    secondDevice.id = Id.generate()
    secondDevice.name = "Second"
    secondDevice.manufacturer = "reTXT"
    secondDevice.model = "Test"
    secondDevice.osVersion = "N/A"
    secondDevice.version = "2"
    secondDevice.activeAliases = [secondAlias]
    
    let thirdDevice = DeviceInfo()
    thirdDevice.id = Id.generate()
    thirdDevice.name = "Second"
    thirdDevice.manufacturer = "reTXT"
    thirdDevice.model = "Test"
    thirdDevice.osVersion = "N/A"
    thirdDevice.version = "3"
    thirdDevice.activeAliases = [firstAlias, secondAlias, thirdAlias]
    
    self.password = TestClient.randomStringWithLength(8)
    
    let encryptionIdentity = try AsymmetricKeyPairGenerator.generateIdentityRequestNamed("TestEncrypt", withKeySize: 2048, usage: .KeyEncipherment)
    let signingIdentity = try AsymmetricKeyPairGenerator.generateIdentityRequestNamed("TestSigning", withKeySize: 2048, usage: .DigitalSignature)
    
    let userProfile = try publicAPI.registerUser(password,
      encryptionCSR: encryptionIdentity.certificateSigningRequest.encoded,
      signingCSR: signingIdentity.certificateSigningRequest.encoded,
      authenticatedAliases: [
        AuthenticatedAlias(name: firstAlias, pin: "$#$#"),
        AuthenticatedAlias(name: secondAlias, pin: "$#$#"),
        AuthenticatedAlias(name: thirdAlias, pin: "$#$#")
      ],
      deviceInfo: firstDevice)
    
    try publicAPI.registerDevice(userProfile.id, password: password, deviceInfo: secondDevice)
    try publicAPI.registerDevice(userProfile.id, password: password, deviceInfo: thirdDevice)
    
    self.userId = userProfile.id
    
    self.encryptionIdentity = encryptionIdentity.buildIdentityWithCertificate(try OpenSSLCertificate(DEREncodedData: userProfile.encryptionCert))
    self.signingIdentity = signingIdentity.buildIdentityWithCertificate(try OpenSSLCertificate(DEREncodedData: userProfile.signingCert))
    
    self.devices = [
      Device(deviceInfo: firstDevice, preferredAlias: firstAlias, client: self),
      Device(deviceInfo: secondDevice, preferredAlias: secondAlias, client: self),
      Device(deviceInfo: thirdDevice, preferredAlias: thirdAlias, client: self)
    ]
  }
  
  public func findDeviceForSender(sender: String) -> Device {
    return devices.filter { $0.preferredAlias == sender }.first ?? devices.filter { $0.deviceInfo.activeAliases.containsObject(sender) }.first!
  }
  
  public func sendUserStatus(status: UserStatus, from sender: String, to recipient: String) throws -> (String, UserStatus) {
    return try findDeviceForSender(sender).sendUserStatus(status, from: sender, to: recipient)
  }
  
  class func createPublicAPIClient(baseURL: NSURL) -> PublicAPIClient {
    
    let url = NSURL(string: "/api/public", relativeToURL: baseURL)!
    
    let transport = THTTPTransport(URL: url)
    let request = transport.valueForKey("request")!
    request.setValue(ThriftContentType + ";p=compact", forHTTPHeaderField: ContentTypeHTTPHeader)
    request.setValue(ThriftContentType + ";p=compact", forHTTPHeaderField: AcceptHTTPHeader)
    
    let proto = TCompactProtocol(transport: transport)
    
    return PublicAPIClient(withProtocol: proto)
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
