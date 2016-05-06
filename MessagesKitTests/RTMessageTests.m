//
//  RTMessageTests.m
//  ReTxt
//
//  Created by Kevin Wooten on 5/14/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import XCTest;
@import MessagesKit;
@import CoreGraphics;


@interface RTMessageTests : XCTestCase <RTDBManagerDelegate> {
  RTUserChat *userChat;
}

@property (strong, nonatomic) NSString *dbPath;
@property (strong, nonatomic) RTDBManager *dbManager;
@property (strong, nonatomic) NSMutableSet *inserted;
@property (strong, nonatomic) NSMutableSet *updated;
@property (strong, nonatomic) NSMutableSet *deleted;

-(RTTextMessage *) newTextMessage;
-(RTImageMessage *) newImageMessage;
-(RTAudioMessage *) newAudioMessage;
-(RTVideoMessage *) newVideoMessage;
-(RTLocationMessage *) newLocationMessage;
-(RTContactMessage *) newContactMessage;
-(RTEnterMessage *) newEnterMessage;
-(RTExitMessage *) newExitMessage;

@end


@implementation RTMessageTests

-(void) setUp
{
  [super setUp];

  self.dbPath = [NSTemporaryDirectory() stringByAppendingString:@"temp.sqlite"];
  
  [NSFileManager.defaultManager removeItemAtPath:self.dbPath error:nil];

  self.dbManager = [RTDBManager.alloc initWithPath:self.dbPath
                                              kind:@"Message"
                                        daoClasses:@[[RTMessageDAO class],
                                                     [RTChatDAO class]]
                                             error:nil];
  [self.dbManager addDelegatesObject:self];

  self.inserted = [NSMutableSet new];
  self.updated = [NSMutableSet new];
  self.deleted = [NSMutableSet new];

  userChat = [RTUserChat new];
  userChat.id = [RTId generate];
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

-(id) fill:(RTMessage *)msg
{
  msg.id = [RTId generate];
  msg.chat = userChat;
  msg.sender = @"me";
  msg.sent = [NSDate date];
  msg.status = RTMessageStatusUnsent;
  msg.statusTimestamp = [NSDate date];
  msg.flags = RTMessageFlagClarify;

  return msg;
}

-(NSString *) pathForResourceNamed:(NSString *)name ofType:(NSString *)type
{
  return [[NSBundle bundleForClass:[self class]] pathForResource:name ofType:type];
}

-(RTTextMessage *) newTextMessage
{
  RTTextMessage *msg = [self fill:[RTTextMessage new]];
  msg.text = @"Yo!";
  return msg;
}

-(RTImageMessage *) newImageMessage
{
  RTImageMessage *msg = [self fill:[RTImageMessage new]];
  msg.data = [[FileDataReference alloc] initWithPath:[self pathForResourceNamed:@"test" ofType:@"png"]];
  msg.dataMimeType = RTImageType_PNG;

  CGSize size;
  msg.thumbnailData = [RTImageMessage generateThumbnailWithData:msg.data size:&size error:nil];
  msg.thumbnailSize = size;

  return msg;
}

-(RTAudioMessage *) newAudioMessage
{
  RTAudioMessage *msg = [self fill:[RTAudioMessage new]];
  msg.data = [FileDataReference.alloc initWithPath:[self pathForResourceNamed:@"test" ofType:@"mp3"]];
  msg.dataMimeType = RTAudioType_MP3;
  return msg;
}

-(RTVideoMessage *) newVideoMessage
{
  RTVideoMessage *msg = [self fill:[RTVideoMessage new]];
  msg.data = [FileDataReference.alloc initWithPath:[self pathForResourceNamed:@"test" ofType:@"mp4"]];
  msg.dataMimeType = RTVideoType_MP4;
  
  CGSize size;
  msg.thumbnailData = [RTVideoMessage generateThumbnailWithData:msg.data atFrameTime:@"0" size:&size error:nil];
  msg.thumbnailSize = size;

  return msg;
}

-(RTLocationMessage *) newLocationMessage
{
  RTLocationMessage *msg = [self fill:[RTLocationMessage new]];
  msg.latitude = +37.30411079;
  msg.longitude = -121.97536127;
  msg.title = @"Location Title";
  msg.thumbnailData = nil;

  return msg;
}

-(RTContactMessage *) newContactMessage
{
  RTContactMessage *msg = [self fill:[RTContactMessage new]];
  msg.vcardData = [NSData dataWithContentsOfFile:[self pathForResourceNamed:@"test" ofType:@"vcf"]];
  msg.firstName = @"Test";
  msg.lastName = @"Guy";
  return msg;
}

-(RTEnterMessage *) newEnterMessage
{
  RTEnterMessage *msg = [self fill:[RTEnterMessage new]];
  msg.alias = @"Alias";
  return msg;
}

-(RTExitMessage *) newExitMessage
{
  RTExitMessage *msg = [self fill:[RTExitMessage new]];
  msg.alias = @"Alias";
  return msg;
}

-(void) testSentByMe
{
  RTTextMessage *msg = [self newTextMessage];

  XCTAssertTrue(msg.sentByMe);
}

-(void) testFlags
{
  RTTextMessage *msg = [self newTextMessage];

  msg.flags = 0;
  XCTAssertFalse(msg.unreadFlag);
  XCTAssertFalse(msg.clarifyFlag);

  msg.unreadFlag = YES;
  XCTAssertTrue(msg.unreadFlag);
  XCTAssertTrue(msg.flags & RTMessageFlagUnread);
  XCTAssertFalse(msg.clarifyFlag);

  msg.unreadFlag = NO;
  XCTAssertFalse(msg.unreadFlag);
  XCTAssertFalse(msg.flags & RTMessageFlagUnread);
  XCTAssertFalse(msg.clarifyFlag);

  msg.clarifyFlag = YES;
  XCTAssertTrue(msg.clarifyFlag);
  XCTAssertTrue(msg.flags & RTMessageFlagClarify);
  XCTAssertFalse(msg.unreadFlag);

  msg.clarifyFlag = NO;
  XCTAssertFalse(msg.clarifyFlag);
  XCTAssertFalse(msg.flags & RTMessageFlagClarify);
  XCTAssertFalse(msg.unreadFlag);
}

-(void) testInvalidInsert
{
  [_dbManager.pool inWritableDatabase:^(FMDatabase * _Nonnull db) {
    db.logsErrors = NO;
  }];
  
  RTId *noId = nil;

  RTMessage *msg = [RTTextMessage new];
  msg.id = noId;
  msg.sender = @"test";
  msg.chat = userChat;

  XCTAssertFalse([self.dbManager[@"Message"] insertMessage:msg error:nil]);
}

-(BOOL) dbRoundtripForMessage:(RTMessage *)message dao:(RTMessageDAO *)dao
{
  XCTAssertTrue([dao insertMessage:message error:nil]);

  RTMessage *message2 = [dao fetchMessageWithId:message.id];

  return [message isEquivalent:message2];
}

-(void) testTextMessageInsertFetch
{
  RTTextMessage *msg = [self newTextMessage];

  XCTAssertTrue([self dbRoundtripForMessage:msg dao:self.dbManager[@"Message"]], @"Text message failed DB roundtrip");
  
  XCTAssertTrue([self.dbManager[@"Message"] deleteObject:msg error:nil]);
}

-(void) testImageMessageInsertFetch
{
  RTImageMessage *msg = [self newImageMessage];

  XCTAssertTrue([self dbRoundtripForMessage:msg dao:self.dbManager[@"Message"]], @"Image message failed DB roundtrip");
  
  XCTAssertTrue([msg.data isKindOfClass:BlobDataReference.class]);
  XCTAssertTrue([msg.thumbnailData isKindOfClass:BlobDataReference.class]);
  
  XCTAssertTrue([self.dbManager[@"Message"] deleteObject:msg error:nil]);
}

-(void) testAudioMessageInsertFetch
{
  RTAudioMessage *msg = [self newAudioMessage];

  XCTAssertTrue([self dbRoundtripForMessage:msg dao:self.dbManager[@"Message"]], @"Audio message failed DB roundtrip");
  
  XCTAssertTrue([msg.data isKindOfClass:BlobDataReference.class]);
  
  XCTAssertTrue([self.dbManager[@"Message"] deleteObject:msg error:nil]);
}

-(void) testVideoMessageInsertFetch
{
  RTVideoMessage *msg = [self newVideoMessage];

  XCTAssertTrue([self dbRoundtripForMessage:msg dao:self.dbManager[@"Message"]], @"Video message failed DB roundtrip");
  
  XCTAssertTrue([msg.data isKindOfClass:BlobDataReference.class]);
  XCTAssertTrue([msg.thumbnailData isKindOfClass:BlobDataReference.class]);
  
  XCTAssertTrue([self.dbManager[@"Message"] deleteObject:msg error:nil]);
}

-(void) testLocationMessageInsertFetch
{
  XCTestExpectation *expectation = [self expectationWithDescription:@"Location Message"];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{

    RTLocationMessage *msg = [self newLocationMessage];

    XCTAssertTrue([self dbRoundtripForMessage:msg dao:self.dbManager[@"Message"]], @"Location message failed DB roundtrip");
    
    XCTAssertTrue([self.dbManager[@"Message"] deleteObject:msg error:nil]);

    [expectation fulfill];
  });

  [self waitForExpectationsWithTimeout:10 handler:NULL];
}

-(void) testContactMessageInsertFetch
{
  RTContactMessage *msg = [self newContactMessage];

  XCTAssertTrue([self dbRoundtripForMessage:msg dao:self.dbManager[@"Message"]], @"Contact message failed DB roundtrip");
  
  XCTAssertTrue([self.dbManager[@"Message"] deleteObject:msg error:nil]);
}

-(void) testEnterMessageInsertFetch
{
  RTEnterMessage *msg = [self newEnterMessage];

  XCTAssertTrue([self dbRoundtripForMessage:msg dao:self.dbManager[@"Message"]], @"Enter message failed DB roundtrip");
  
  XCTAssertTrue([self.dbManager[@"Message"] deleteObject:msg error:nil]);
}

-(void) testExitMessageInsertFetch
{
  RTExitMessage *msg = [self newExitMessage];

  XCTAssertTrue([self dbRoundtripForMessage:msg dao:self.dbManager[@"Message"]], @"Exit message failed DB roundtrip");
  
  XCTAssertTrue([self.dbManager[@"Message"] deleteObject:msg error:nil]);
}

-(void) testMessageFetchUnsent
{
  RTMessageDAO *dao = self.dbManager[@"Message"];

  for (int c=0; c < 12; ++c) {
    RTMessage *msg = [self newTextMessage];
    msg.status = RTMessageStatusUnsent + (c/2);
    XCTAssertTrue([self.dbManager[@"Message"] insertMessage:msg error:nil]);
  }

  XCTAssertEqual(4, [dao fetchUnsentMessagesAndReturnError:nil].count);
}

-(void) testMessageDelete
{
  RTMessage *msg = [self newTextMessage];

  RTMessageDAO *dao = self.dbManager[@"Message"];

  XCTAssertTrue([dao insertMessage:msg error:nil]);
  XCTAssertTrue([dao deleteMessage:msg error:nil]);

  XCTAssertNil([dao fetchMessageWithId:msg.id]);
  XCTAssertTrue([_deleted containsObject:msg.id]);
}

-(void) testMessageDeleteAll
{
  RTMessage *msg1 = [self newTextMessage];
  RTMessage *msg2 = [self newTextMessage];
  NSArray *all = @[msg1, msg2];

  RTMessageDAO *dao = self.dbManager[@"Message"];

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
  RTMessage *msg = [self newTextMessage];

  RTMessageDAO *dao = self.dbManager[@"Message"];

  XCTAssertTrue([dao insertMessage:msg error:nil]);
  XCTAssertTrue([dao updateMessage:msg withSent:[NSDate date] error:nil]);

  [dao clearCache];
  XCTAssertTrue([msg isEquivalent:[dao fetchMessageWithId:msg.id]]);

  XCTAssertTrue([_updated containsObject:msg.id]);
}

-(void) testMessageUpdateStatus
{
  RTMessage *msg = [self newTextMessage];

  RTMessageDAO *dao = self.dbManager[@"Message"];

  XCTAssertTrue([dao insertMessage:msg error:nil]);
  XCTAssertTrue([dao updateMessage:msg withStatus:RTMessageStatusDelivered error:nil]);
  [dao clearCache];
  XCTAssertTrue([msg isEquivalent:[dao fetchMessageWithId:msg.id]]);

  XCTAssertTrue([_updated containsObject:msg.id]);
}

-(void) testMessageUpdate
{
  RTMessage *msg = [self newTextMessage];

  RTMessageDAO *dao = self.dbManager[@"Message"];

  XCTAssertTrue([dao insertMessage:msg error:nil]);
  XCTAssertTrue([dao updateMessage:msg error:nil]);
  [dao clearCache];
  XCTAssertTrue([msg isEquivalent:[dao fetchMessageWithId:msg.id]]);

  XCTAssertTrue([_updated containsObject:msg.id]);
}

-(void) testMessageUpdateFlags
{
  RTMessage *msg = [self newTextMessage];

  RTMessageDAO *dao = self.dbManager[@"Message"];

  XCTAssertTrue([dao insertMessage:msg error:nil]);
  XCTAssertTrue([dao updateMessage:msg withFlags:RTMessageFlagClarify error:nil]);
  [dao clearCache];
  XCTAssertTrue([msg isEquivalent:[dao fetchMessageWithId:msg.id]]);

  XCTAssertTrue([_updated containsObject:msg.id]);
}

-(void) testMessageUpsert
{
  RTMessage *msg = [self newTextMessage];

  RTMessageDAO *dao = self.dbManager[@"Message"];

  XCTAssertTrue([dao upsertMessage:msg error:nil]);

  XCTAssertTrue([_inserted containsObject:msg.id]);

  XCTAssertTrue([dao upsertMessage:msg error:nil]);

  XCTAssertTrue([_updated containsObject:msg.id]);
}

-(void) testMessageFetchLatestUnviewedForChat
{
  RTMessage *msg = [self newTextMessage];
  msg.sender = userChat.alias;

  RTMessageDAO *dao = self.dbManager[@"Message"];

  XCTAssertTrue([dao insertMessage:msg error:nil]);

  [dao clearCache];

  RTMessage *msg2 = [dao fetchLatestUnviewedMessageForChat:msg.chat];

  XCTAssertEqualObjects(msg, msg2);
}

-(void) testMessageViewAllForChatBefore
{
  RTMessageDAO *dao = self.dbManager[@"Message"];

  RTMessage *msg;

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

-(BOOL) payloadRoundtripForMessage:(RTMessage *)message
{
  RTMessage *copy = [message copy];

  id<DataReference> dataRef;
  NSMutableDictionary *metaData;

  [message exportPayloadIntoData:&dataRef withMetaData:&metaData error:nil];

  [copy importPayloadFromData:dataRef withMetaData:metaData error:nil];

  return [message isEquivalent:copy];
}

-(void) testTextMessagePayload
{
  RTTextMessage *msg = [self newTextMessage];

  XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Text message failed Payload roundtrip");
}

-(void) testImageMessagePayload
{
  RTImageMessage *msg = [self newImageMessage];

  XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Image message failed Payload roundtrip");
}

-(void) testAudioMessagePayload
{
  RTAudioMessage *msg = [self newAudioMessage];

  XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Audio message failed Payload roundtrip");
}

-(void) testVideoMessagePayload
{
  RTVideoMessage *msg = [self newVideoMessage];

  XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Video message failed Payload roundtrip");
}

-(void) testLocationMessagePayload
{
  XCTestExpectation *expectation = [self expectationWithDescription:@"Location Message"];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{

    RTLocationMessage *msg = [self newLocationMessage];

    XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Location message failed Payload roundtrip");

    [expectation fulfill];
  });

  [self waitForExpectationsWithTimeout:10 handler:NULL];
}

-(void) testContactMessagePayload
{
  RTContactMessage *msg = [self newContactMessage];

  XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Contact message failed Payload roundtrip");
}

-(void) testEnterMessagePayload
{
  RTEnterMessage *msg = [self newEnterMessage];

  XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Enter message failed Payload roundtrip");
}

-(void) testExitMessagePayload
{
  RTExitMessage *msg = [self newExitMessage];

  XCTAssertTrue([self payloadRoundtripForMessage:msg], @"Exit message failed Payload roundtrip");
}

-(void) modelObject:(RTModel *)model insertedInDAO:(RTDAO *)dao
{
  [_inserted addObject:model.id];
}

-(void) modelObject:(RTModel *)model updatedInDAO:(RTDAO *)dao
{
  [_updated addObject:model.id];
}

-(void) modelObject:(RTModel *)model deletedInDAO:(RTDAO *)dao
{
  [_deleted addObject:model.id];
}

@end
