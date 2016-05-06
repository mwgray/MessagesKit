//
//  RTMessageDAO.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTDAO.h"
#import "RTMessage.h"


NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM (int32_t, RTMessageType) {
  RTMessageTypeText,
  RTMessageTypeImage,
  RTMessageTypeAudio,
  RTMessageTypeVideo,
  RTMessageTypeContact,
  RTMessageTypeLocation,
  RTMessageTypeEnter,
  RTMessageTypeExit,
  RTMessageTypeConference
};

@interface RTMessageDAO : RTDAO

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


-(void) failAllSendingMessagesExcluding:(NSArray<RTId *> *)excludedMessageIds;
-(nullable NSArray<__kindof RTMessage *> *) fetchUnsentMessagesAndReturnError:(NSError **)error;

-(nullable RTMessage *) fetchLastMessageForChat:(RTChat *)chat;
-(nullable RTMessage *) fetchLatestUnviewedMessageForChat:(RTChat *)chat;

-(BOOL) viewAllMessagesForChat:(RTChat *)chat before:(NSDate *)sent error:(NSError **)error;
-(BOOL) readAllMessagesForChat:(RTChat *)chat error:(NSError **)error;

-(int) countOfUnreadMessages;

-(BOOL) updateMessage:(RTMessage *)message withStatus:(RTMessageStatus)status error:(NSError **)error;
-(BOOL) updateMessage:(RTMessage *)message withStatus:(RTMessageStatus)status timestamp:(NSDate *)timestamp error:(NSError **)error;
-(BOOL) updateMessage:(RTMessage *)message withSent:(NSDate *)sent error:(NSError **)error;
-(BOOL) updateMessage:(RTMessage *)message withFlags:(int64_t)flags error:(NSError **)error;

-(BOOL) deleteAllMessagesForChat:(RTChat *)chat error:(NSError **)error;

-(BOOL) isMessageDeletedWithId:(RTId *)msgId;
-(void) markMessageDeletedWithId:(RTId *)msgId;

@end


@interface RTMessageDAO (Generics)

-(nullable __kindof RTMessage *) fetchMessageWithId:(RTId *)id NS_REFINED_FOR_SWIFT;
-(BOOL) fetchMessageWithId:(RTId *)id returning:(RTMessage *__nullable *__nonnull)msg error:(NSError **)error;
-(nullable NSArray<__kindof RTMessage *> *) fetchAllMessagesMatching:(nullable NSString *)where error:(NSError **)error;
-(nullable NSArray<__kindof RTMessage *> *) fetchAllMessagesMatching:(nullable NSString *)where parameters:(nullable NSArray *)parameters error:(NSError **)error;
-(nullable NSArray<__kindof RTMessage *> *) fetchAllMessagesMatching:(nullable NSString *)where parametersNamed:(nullable NSDictionary *)parameters error:(NSError **)error;
-(nullable NSArray<__kindof RTMessage *> *) fetchAllMessagesMatching:(NSPredicate *)predicate
                                                              offset:(NSUInteger)offset limit:(NSUInteger)limit
                                                            sortedBy:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                                                               error:(NSError **)error;

-(BOOL) insertMessage:(RTMessage *)model error:(NSError **)error;
-(BOOL) updateMessage:(RTMessage *)model error:(NSError **)error;
-(BOOL) upsertMessage:(RTMessage *)model error:(NSError **)error;
-(BOOL) deleteMessage:(RTMessage *)model error:(NSError **)error;
-(BOOL) deleteAllMessagesInArray:(NSArray<RTMessage *> *)models error:(NSError **)error;
-(BOOL) deleteAllMessagesAndReturnError:(NSError **)error;
-(BOOL) deleteAllMessagesMatching:(nullable NSString *)where error:(NSError **)error;
-(BOOL) deleteAllMessagesMatching:(nullable NSString *)where parameters:(nullable NSArray *)parameters error:(NSError **)error;
-(BOOL) deleteAllMessagesMatching:(nullable NSString *)where parametersNamed:(nullable NSDictionary *)parameters error:(NSError **)error;

@end



@interface RTMessage (DAO)

+(RTMessageType) typeCode;
+(NSString *) typeString;

@end


NS_ASSUME_NONNULL_END
