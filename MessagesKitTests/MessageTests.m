//
//  MessageTests.m
//  MessagesKit
//
//  Created by Kevin Wooten on 5/14/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import XCTest;
@import MessagesKit;
@import CoreGraphics;


@interface MessageTests : XCTestCase <DBManagerDelegate> {
  UserChat *userChat;
}

@property (strong, nonatomic) NSString *dbPath;
@property (strong, nonatomic) DBManager *dbManager;
@property (strong, nonatomic) NSMutableSet *inserted;
@property (strong, nonatomic) NSMutableSet *updated;
@property (strong, nonatomic) NSMutableSet *deleted;

-(TextMessage *) newTextMessage;
-(ImageMessage *) newImageMessage;
-(AudioMessage *) newAudioMessage;
-(VideoMessage *) newVideoMessage;
-(LocationMessage *) newLocationMessage;
-(ContactMessage *) newContactMessage;
-(EnterMessage *) newEnterMessage;
-(ExitMessage *) newExitMessage;

@end


@implementation MessageTests

-(void) setUp
{
  [super setUp];

  self.dbPath = [NSTemporaryDirectory() stringByAppendingString:@"temp.sqlite"];
  
  [NSFileManager.defaultManager removeItemAtPath:self.dbPath error:nil];

  self.dbManager = [DBManager.alloc initWithPath:self.dbPath
                                              kind:@"Message"
                                        daoClasses:@[[MessageDAO class],
                                                     [ChatDAO class]]
                                             error:nil];
  [self.dbManager addDelegatesObject:self];

  self.inserted = [NSMutableSet new];
  self.updated = [NSMutableSet new];
  self.deleted = [NSMutableSet new];

  userChat = [UserChat new];
  userChat.id = [Id generate];
  userChat.alias = @"12345";
  userChat.localAlias = @"me";

  [self.dbManager[@"Chat"] insertChat:userChat error:nil];
}

-(void) tearDown
{
  [self.dbManager shutdown];
  self.dbManager = nil;
  
  [[NSFileManager defaultManager] removeItemAtPath:self.dbPath error:nil];
  
  [super tearDown];
}

-(id) fill:(Message *)msg
{
  msg.id = [Id generate];
  msg.chat = userChat;
  msg.sender = @"me";
  msg.sent = [NSDate date];
  msg.status = MessageStatusUnsent;
  msg.statusTimestamp = [NSDate date];
  msg.flags = MessageFlagClarify;

  return msg;
}

-(NSString *) pathForResourceNamed:(NSString *)name ofType:(NSString *)type
{
  return [[NSBundle bundleForClass:[self class]] pathForResource:name ofType:type];
}

-(TextMessage *) newTextMessage
{
  TextMessage *msg = [self fill:[TextMessage new]];
  msg.text = @"Yo!";
  return msg;
}

-(ImageMessage *) newImageMessage
{
  ImageMessage *msg = [self fill:[ImageMessage new]];
  msg.data = [[FileDataReference alloc] initWithPath:[self pathForResourceNamed:@"test" ofType:@"png"]];
  msg.dataMimeType = ImageType_PNG;

  CGSize size;
  msg.thumbnailData = [ImageMessage generateThumbnailWithData:msg.data size:&size error:nil];
  msg.thumbnailSize = size;

  return msg;
}

-(AudioMessage *) newAudioMessage
{
  AudioMessage *msg = [self fill:[AudioMessage new]];
  msg.data = [FileDataReference.alloc initWithPath:[self pathForResourceNamed:@"test" ofType:@"mp3"]];
  msg.dataMimeType = AudioType_MP3;
  return msg;
}

-(VideoMessage *) newVideoMessage
{
  VideoMessage *msg = [self fill:[VideoMessage new]];
  msg.data = [FileDataReference.alloc initWithPath:[self pathForResourceNamed:@"test" ofType:@"mp4"]];
  msg.dataMimeType = VideoType_MP4;
  
  CGSize size;
  msg.thumbnailData = [VideoMessage generateThumbnailWithData:msg.data atFrameTime:@"0" size:&size error:nil];
  msg.thumbnailSize = size;

  return msg;
}

-(LocationMessage *) newLocationMessage
{
  LocationMessage *msg = [self fill:[LocationMessage new]];
  msg.latitude = +37.30411079;
  msg.longitude = -121.97536127;
  msg.title = @"Location Title";
  msg.thumbnailData = nil;

  return msg;
}

-(ContactMessage *) newContactMessage
{
  ContactMessage *msg = [self fill:[ContactMessage new]];
  msg.vcardData = [NSData dataWithContentsOfFile:[self pathForResourceNamed:@"test" ofType:@"vcf"]];
  msg.firstName = @"Test";
  msg.lastName = @"Guy";
  return msg;
}

-(EnterMessage *) newEnterMessage
{
  EnterMessage *msg = [self fill:[EnterMessage new]];
  msg.alias = @"Alias";
  return msg;
}

-(ExitMessage *) newExitMessage
{
  ExitMessage *msg = [self fill:[ExitMessage new]];
  msg.alias = @"Alias";
  return msg;
}

-(void) testSentByMe
{
  TextMessage *msg = [self newTextMessage];

  XCTAssertTrue(msg.sentByMe);
}

-(void) testFlags
{
  TextMessage *msg = [self newTextMessage];

  msg.flags = 0;
  XCTAssertFalse(msg.unreadFlag);
  XCTAssertFalse(msg.clarifyFlag);

  msg.unreadFlag = YES;
  XCTAssertTrue(msg.unreadFlag);
  XCTAssertTrue(msg.flags & MessageFlagUnread);
  XCTAssertFalse(msg.clarifyFlag);

  msg.unreadFlag = NO;
  XCTAssertFalse(msg.unreadFlag);
  XCTAssertFalse(msg.flags & MessageFlagUnread);
  XCTAssertFalse(msg.clarifyFlag);

  msg.clarifyFlag = YES;
  XCTAssertTrue(msg.clarifyFlag);
  XCTAssertTrue(msg.flags & MessageFlagClarify);
  XCTAssertFalse(msg.unreadFlag);

  msg.clarifyFlag = NO;
  XCTAssertFalse(msg.clarifyFlag);
  XCTAssertFalse(msg.flags & MessageFlagClarify);
  XCTAssertFalse(msg.unreadFlag);
}

-(void) testInvalidInsert
{
  [_dbManager.pool inWritableDatabase:^(FMDatabase * _Nonnull db) {
    db.logsErrors = NO;
  }];
  
  Id *noId = nil;

  Message *msg = [TextMessage new];
  msg.id = noId;
  msg.sender = @"test";
  msg.chat = userChat;

  XCTAssertFalse([self.dbManager[@"Message"] insertMessage:msg error:nil]);
}

-(BOOL) dbRoundtripForMessage:(Message *)message dao:(MessageDAO *)dao
{
  XCTAssertTrue([dao insertMessage:message error:nil]);

  Message *message2 = [dao fetchMessageWithId:message.id];

  return [message isEquivalent:message2];
}

-(void) testTextMessageInsertFetch
{
  TextMessage *msg = [self newTextMessage];

  XCTAssertTrue([self dbRoundtripForMessage:msg dao:self.dbManager[@"Message"]], @"Text message failed DB roundtrip");
  
  XCTAssertTrue([self.dbManager[@"Message"] deleteObject:msg error:nil]);
}

-(void) testImageMessageInsertFetch
{
  ImageMessage *msg = [self newImageMessage];

  XCTAssertTrue([self dbRoundtripForMessage:msg dao:self.dbManager[@"Message"]], @"Image message failed DB roundtrip");
  
  XCTAssertTrue([msg.data isKindOfClass:BlobDataReference.class]);
  XCTAssertTrue([msg.thumbnailData isKindOfClass:BlobDataReference.class]);
  
  XCTAssertTrue([self.dbManager[@"Message"] deleteObject:msg error:nil]);
}

-(void) testAudioMessageInsertFetch
{
  AudioMessage *msg = [self newAudioMessage];

  XCTAssertTrue([self dbRoundtripForMessage:msg dao:self.dbManager[@"Message"]], @"Audio message failed DB roundtrip");
  
  XCTAssertTrue([msg.data isKindOfClass:BlobDataReference.class]);
  
  XCTAssertTrue([self.dbManager[@"Message"] deleteObject:msg error:nil]);
}

-(void) testVideoMessageInsertFetch
{
  VideoMessage *msg = [self newVideoMessage];

  XCTAssertTrue([self dbRoundtripForMessage:msg dao:self.dbManager[@"Message"]], @"Video message failed DB roundtrip");
  
  XCTAssertTrue([msg.data isKindOfClass:BlobDataReference.class]);
  XCTAssertTrue([msg.thumbnailData isKindOfClass:BlobDataReference.class]);
  
  XCTAssertTrue([self.dbManager[@"Message"] deleteObject:msg error:nil]);
}

-(void) testLocationMessageInsertFetch
{
  XCTestExpectation *expectation = [self expectationWithDescription:@"Location Message"];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{

    LocationMessage *msg = [self newLocationMessage];

    XCTAssertTrue([self dbRoundtripForMessage:msg dao:self.dbManager[@"Message"]], @"Location message failed DB roundtrip");
    
    XCTAssertTrue([self.dbManager[@"Message"] deleteObject:msg error:nil]);

    [expectation fulfill];
  });

  [self waitForExpectationsWithTimeout:10 handler:NULL];
}

-(void) testContactMessageInsertFetch
{
  ContactMessage *msg = [self newContactMessage];

  XCTAssertTrue([self dbRoundtripForMessage:msg dao:self.dbManager[@"Message"]], @"Contact message failed DB roundtrip");
  
  XCTAssertTrue([self.dbManager[@"Message"] deleteObject:msg error:nil]);
}

-(void) testEnterMessageInsertFetch
{
  EnterMessage *msg = [self newEnterMessage];

  XCTAssertTrue([self dbRoundtripForMessage:msg dao:self.dbManager[@"Message"]], @"Enter message failed DB roundtrip");
  
  XCTAssertTrue([self.dbManager[@"Message"] deleteObject:msg error:nil]);
}

-(void) testExitMessageInsertFetch
{
  ExitMessage *msg = [self newExitMessage];

  XCTAssertTrue([self dbRoundtripForMessage:msg dao:self.dbManager[@"Message"]], @"Exit message failed DB roundtrip");
  
  XCTAssertTrue([self.dbManager[@"Message"] deleteObject:msg error:nil]);
}

-(void) testMessageFetchUnsent
{
  MessageDAO *dao = self.dbManager[@"Message"];

  for (int c=0; c < 12; ++c) {
    Message *msg = [self newTextMessage];
    msg.status = MessageStatusUnsent + (c/2);
    XCTAssertTrue([self.dbManager[@"Message"] insertMessage:msg error:nil]);
  }

  XCTAssertEqual(4, [dao fetchUnsentMessagesAndReturnError:nil].count);
}

-(void) testMessageDelete
{
  Message *msg = [self newTextMessage];

  MessageDAO *dao = self.dbManager[@"Message"];

  XCTAssertTrue([dao insertMessage:msg error:nil]);
  XCTAssertTrue([dao deleteMessage:msg error:nil]);

  XCTAssertNil([dao fetchMessageWithId:msg.id]);
  XCTAssertTrue([_deleted containsObject:msg.id]);
}

-(void) testMessageDeleteAll
{
  Message *msg1 = [self newTextMessage];
  Message *msg2 = [self newTextMessage];
  NSArray *all = @[msg1, msg2];

  MessageDAO *dao = self.dbManager[@"Message"];

  XCTAssertTrue([dao insertMessage:msg1 error:nil]);
  XCTAssertTrue([dao insertMessage:msg2 error:nil]);
  XCTAssertTrue([dao deleteAllMessagesInArray:all error:nil]);

  XCTAssertNil([dao fetchMessageWithId:msg1.id]);
  XCTAssertNil([dao fetchMessageWithId:msg2.id]);
  XCTAssertTrue([_deleted containsObject:msg1.id]);
  XCTAssertTrue([_deleted containsObject:msg2.id]);
}

-(void) testMessageUpdateSent
{
  Message *msg = [self newTextMessage];

  MessageDAO *dao = self.dbManager[@"Message"];

  XCTAssertTrue([dao insertMessage:msg error:nil]);
  XCTAssertTrue([dao updateMessage:msg withSent:[NSDate date] error:nil]);

  [dao clearCache];
  XCTAssertTrue([msg isEquivalent:[dao fetchMessageWithId:msg.id]]);

  XCTAssertTrue([_updated containsObject:msg.id]);
}

-(void) testMessageUpdateStatus
{
  Message *msg = [self newTextMessage];

  MessageDAO *dao = self.dbManager[@"Message"];

  XCTAssertTrue([dao insertMessage:msg error:nil]);
  XCTAssertTrue([dao updateMessage:msg withStatus:MessageStatusDelivered error:nil]);
  [dao clearCache];
  XCTAssertTrue([msg isEquivalent:[dao fetchMessageWithId:msg.id]]);

  XCTAssertTrue([_updated containsObject:msg.id]);
}

-(void) testMessageUpdate
{
  Message *msg = [self newTextMessage];

  MessageDAO *dao = self.dbManager[@"Message"];

  XCTAssertTrue([dao insertMessage:msg error:nil]);
  XCTAssertTrue([dao updateMessage:msg error:nil]);
  [dao clearCache];
  XCTAssertTrue([msg isEquivalent:[dao fetchMessageWithId:msg.id]]);

  XCTAssertTrue([_updated containsObject:msg.id]);
}

-(void) testMessageUpdateFlags
{
  Message *msg = [self newTextMessage];

  MessageDAO *dao = self.dbManager[@"Message"];

  XCTAssertTrue([dao insertMessage:msg error:nil]);
  XCTAssertTrue([dao updateMessage:msg withFlags:MessageFlagClarify error:nil]);
  [dao clearCache];
  XCTAssertTrue([msg isEquivalent:[dao fetchMessageWithId:msg.id]]);

  XCTAssertTrue([_updated containsObject:msg.id]);
}

-(void) testMessageUpsert
{
  Message *msg = [self newTextMessage];

  MessageDAO *dao = self.dbManager[@"Message"];

  XCTAssertTrue([dao upsertMessage:msg error:nil]);

  XCTAssertTrue([_inserted containsObject:msg.id]);

  XCTAssertTrue([dao upsertMessage:msg error:nil]);

  XCTAssertTrue([_updated containsObject:msg.id]);
}

-(void) testMessageFetchLatestUnviewedForChat
{
  Message *msg = [self newTextMessage];
  msg.sender = userChat.alias;

  MessageDAO *dao = self.dbManager[@"Message"];

  XCTAssertTrue([dao insertMessage:msg error:nil]);

  [dao clearCache];

  Message *msg2 = [dao fetchLatestUnviewedMessageForChat:msg.chat];

  XCTAssertEqualObjects(msg, msg2);
}

-(void) testMessageViewAllForChatBefore
{
  MessageDAO *dao = self.dbManager[@"Message"];

  Message *msg;

  for (int c=0; c < 5; ++c) {

    msg = [self newTextMessage];
    msg.sender = userChat.alias;

    XCTAssertTrue([dao insertMessage:msg error:nil]);
  }

  [dao clearCache];

  XCTAssertEqual([dao viewAllMessagesForChat:msg.chat before:[NSDate date] error:nil], YES);
  XCTAssertEqual(_inserted.count, 6);
  XCTAssertEqual(_updated.count, 5);
}

-(BOOL) payloadRoundtripForMessage:(Message *)message
{
  Message *copy = [message copy];

  id<DataReference> dataRef;
  NSMutableDictionary *metaData;

  [message exportPayloadIntoData:&dataRef withMetaData:&metaData error:nil];

  [copy importPayloadFromData:dataRef withMetaData:metaData error:nil];

  return [message isEquivalent:copy];
}

-(void) testTextMessagePayload
{
  TextMessage *msg = [self newTextMessage];

  XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Text message (simple) failed Payload roundtrip");
  
  msg.html = [@"Yo!" dataUsingEncoding:NSUTF8StringEncoding];
  
  XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Text message (HTML) failed Payload roundtrip");
}

-(void) testImageMessagePayload
{
  ImageMessage *msg = [self newImageMessage];

  XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Image message failed Payload roundtrip");
}

-(void) testAudioMessagePayload
{
  AudioMessage *msg = [self newAudioMessage];

  XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Audio message failed Payload roundtrip");
}

-(void) testVideoMessagePayload
{
  VideoMessage *msg = [self newVideoMessage];

  XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Video message failed Payload roundtrip");
}

-(void) testLocationMessagePayload
{
  XCTestExpectation *expectation = [self expectationWithDescription:@"Location Message"];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{

    LocationMessage *msg = [self newLocationMessage];

    XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Location message failed Payload roundtrip");

    [expectation fulfill];
  });

  [self waitForExpectationsWithTimeout:10 handler:NULL];
}

-(void) testContactMessagePayload
{
  ContactMessage *msg = [self newContactMessage];

  XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Contact message failed Payload roundtrip");
}

-(void) testEnterMessagePayload
{
  EnterMessage *msg = [self newEnterMessage];

  XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Enter message failed Payload roundtrip");
}

-(void) testExitMessagePayload
{
  ExitMessage *msg = [self newExitMessage];

  XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Exit message failed Payload roundtrip");
}

-(void) modelObject:(Model *)model insertedInDAO:(DAO *)dao
{
  [_inserted addObject:model.id];
}

-(void) modelObject:(Model *)model updatedInDAO:(DAO *)dao
{
  [_updated addObject:model.id];
}

-(void) modelObject:(Model *)model deletedInDAO:(DAO *)dao
{
  [_deleted addObject:model.id];
}

@end
