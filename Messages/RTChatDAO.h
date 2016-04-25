//
//  RTChatDAO.h
//  ReTxt
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTDAO.h"
#import "RTUserChat.h"
#import "RTGroupChat.h"


NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM (int32_t, RTChatType) {
  RTChatTypeUser,
  RTChatTypeGroup,
};


@interface RTChatDAO : RTDAO

@property (nonatomic, assign) int aliasFieldIdx;
@property (nonatomic, assign) int localAliasFieldIdx;
@property (nonatomic, assign) int lastMessageFieldIdx;
@property (nonatomic, assign) int clarifiedCountFieldIdx;
@property (nonatomic, assign) int updatedCountFieldIdx;
@property (nonatomic, assign) int startedDateFieldIdx;
@property (nonatomic, assign) int totalMessagesFieldIdx;
@property (nonatomic, assign) int totalSentFieldIdx;
@property (nonatomic, assign) int customTitleFieldIdx;
@property (nonatomic, assign) int activeMembersFieldIdx;
@property (nonatomic, assign) int membersFieldIdx;
@property (nonatomic, assign) int draftFieldIdx;

-(instancetype) initWithDBManager:(RTDBManager *)dbManager;

-(BOOL) fetchChatForAlias:(NSString *)alias localAlias:(NSString *)localAlias returning:(RTChat *__nullable __autoreleasing *__nonnull)chat error:(NSError **)error;

-(BOOL) updateChat:(RTChat *)chat withLastMessage:(nullable RTMessage *)message error:(NSError **)error;
-(BOOL) updateChat:(RTChat *)chat withLastSentMessage:(RTMessage *)message error:(NSError **)error;
-(BOOL) updateChat:(RTChat *)chat withLastReceivedMessage:(RTMessage *)message error:(NSError **)error;

-(BOOL) updateChat:(RTChat *)chat withClarifiedCount:(int)clarifiedCount;
-(BOOL) updateChat:(RTChat *)chat withUpdatedCount:(int)updatedCount;

-(BOOL) updateChat:(RTGroupChat *)chat addGroupMember:(NSString *)alias error:(NSError **)error;
-(BOOL) updateChat:(RTGroupChat *)chat removeGroupMember:(NSString *)alias error:(NSError **)error;

-(BOOL) resetUnreadCountsForChat:(RTChat *)chat;

@end


@interface RTChatDAO (Generics)

-(nullable __kindof RTChat *) fetchChatWithId:(RTId *)id NS_REFINED_FOR_SWIFT;
-(BOOL) fetchChatWithId:(RTId *)id returning:(RTChat *__nullable *__nonnull)msg error:(NSError **)error;
-(nullable NSArray<__kindof RTChat *> *) fetchAllChatsMatching:(nullable NSString *)where error:(NSError **)error;
-(nullable NSArray<__kindof RTChat *> *) fetchAllChatsMatching:(nullable NSString *)where parameters:(nullable NSArray *)parameters error:(NSError **)error;
-(nullable NSArray<__kindof RTChat *> *) fetchAllChatsMatching:(nullable NSString *)where parametersNamed:(nullable NSDictionary *)parameters error:(NSError **)error;
-(nullable NSArray<__kindof RTChat *> *) fetchAllChatsMatching:(NSPredicate *)predicate
                                                        offset:(NSUInteger)offset limit:(NSUInteger)limit
                                                      sortedBy:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                                                         error:(NSError **)error;

-(BOOL) insertChat:(RTChat *)model error:(NSError **)error;
-(BOOL) updateChat:(RTChat *)model error:(NSError **)error;
-(BOOL) upsertChat:(RTChat *)model error:(NSError **)error;
-(BOOL) deleteChat:(RTChat *)model error:(NSError **)error;
-(BOOL) deleteAllChatsInArray:(NSArray<RTChat *> *)models error:(NSError **)error;
-(BOOL) deleteAllChatsAndReturnError:(NSError **)error;
-(BOOL) deleteAllChatsMatching:(nullable NSString *)where error:(NSError **)error;
-(BOOL) deleteAllChatsMatching:(nullable NSString *)where parameters:(nullable NSArray *)parameters error:(NSError **)error;
-(BOOL) deleteAllChatsMatching:(nullable NSString *)where parametersNamed:(nullable NSDictionary *)parameters error:(NSError **)error;

@end


@interface RTChat (DAO)

+(RTChatType) typeCode;

@end


NS_ASSUME_NONNULL_END
