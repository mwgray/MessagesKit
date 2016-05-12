//
//  MessageDAO.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "DAO.h"
#import "Message.h"


NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM (int32_t, MessageType) {
  MessageTypeText,
  MessageTypeImage,
  MessageTypeAudio,
  MessageTypeVideo,
  MessageTypeContact,
  MessageTypeLocation,
  MessageTypeEnter,
  MessageTypeExit,
  MessageTypeConference
};

@interface MessageDAO : DAO

@property (nonatomic, assign) int chatFieldIdx;
@property (nonatomic, assign) int senderFieldIdx;
@property (nonatomic, assign) int sentFieldIdx;
@property (nonatomic, assign) int updatedFieldIdx;
@property (nonatomic, assign) int statusFieldIdx;
@property (nonatomic, assign) int statusTimestampFieldIdx;
@property (nonatomic, assign) int flagsFieldIdx;
@property (nonatomic, assign) int data1FieldIdx;
@property (nonatomic, assign) int data2FieldIdx;
@property (nonatomic, assign) int data3FieldIdx;
@property (nonatomic, assign) int data4FieldIdx;


-(void) failAllSendingMessagesExcluding:(NSArray<Id *> *)excludedMessageIds;
-(nullable NSArray<__kindof Message *> *) fetchUnsentMessagesAndReturnError:(NSError **)error;

-(BOOL) fetchLastMessage:(Message *__nullable *__nonnull)returnedMessage forChat:(Chat *)chat error:(NSError **)error NS_REFINED_FOR_SWIFT;
-(BOOL) fetchLatestUnviewedMessage:(Message *__nullable *__nonnull)returnedMessage forChat:(Chat *)chat error:(NSError **)error NS_REFINED_FOR_SWIFT;

-(BOOL) viewAllMessagesForChat:(Chat *)chat before:(NSDate *)sent error:(NSError **)error;
-(BOOL) readAllMessagesForChat:(Chat *)chat error:(NSError **)error;

-(int) countOfUnreadMessages;

-(BOOL) updateMessage:(Message *)message withStatus:(MessageStatus)status error:(NSError **)error;
-(BOOL) updateMessage:(Message *)message withStatus:(MessageStatus)status timestamp:(NSDate *)timestamp error:(NSError **)error;
-(BOOL) updateMessage:(Message *)message withSent:(NSDate *)sent error:(NSError **)error;
-(BOOL) updateMessage:(Message *)message withFlags:(int64_t)flags error:(NSError **)error;

-(BOOL) deleteAllMessagesForChat:(Chat *)chat error:(NSError **)error;

-(BOOL) isMessageDeletedWithId:(Id *)msgId;
-(void) markMessageDeletedWithId:(Id *)msgId;

@end


@interface MessageDAO (Generics)

-(nullable __kindof Message *) fetchMessageWithId:(Id *)id NS_REFINED_FOR_SWIFT;
-(BOOL) fetchMessageWithId:(Id *)id returning:(Message *__nullable *__nonnull)msg error:(NSError **)error;
-(nullable NSArray<__kindof Message *> *) fetchAllMessagesMatching:(nullable NSString *)where error:(NSError **)error;
-(nullable NSArray<__kindof Message *> *) fetchAllMessagesMatching:(nullable NSString *)where parameters:(nullable NSArray *)parameters error:(NSError **)error;
-(nullable NSArray<__kindof Message *> *) fetchAllMessagesMatching:(nullable NSString *)where parametersNamed:(nullable NSDictionary *)parameters error:(NSError **)error;
-(nullable NSArray<__kindof Message *> *) fetchAllMessagesMatching:(NSPredicate *)predicate
                                                              offset:(NSUInteger)offset limit:(NSUInteger)limit
                                                            sortedBy:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                                                               error:(NSError **)error;

-(BOOL) insertMessage:(Message *)model error:(NSError **)error;
-(BOOL) updateMessage:(Message *)model error:(NSError **)error;
-(BOOL) upsertMessage:(Message *)model error:(NSError **)error;
-(BOOL) deleteMessage:(Message *)model error:(NSError **)error;
-(BOOL) deleteAllMessagesInArray:(NSArray<Message *> *)models error:(NSError **)error;
-(BOOL) deleteAllMessagesAndReturnError:(NSError **)error;
-(BOOL) deleteAllMessagesMatching:(nullable NSString *)where error:(NSError **)error;
-(BOOL) deleteAllMessagesMatching:(nullable NSString *)where parameters:(nullable NSArray *)parameters error:(NSError **)error;
-(BOOL) deleteAllMessagesMatching:(nullable NSString *)where parametersNamed:(nullable NSDictionary *)parameters error:(NSError **)error;

@end



@interface Message (DAO)

+(MessageType) typeCode;
+(NSString *) typeString;

@end


NS_ASSUME_NONNULL_END
