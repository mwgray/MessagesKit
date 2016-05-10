//
//  ChatDAO.h
//  MessagesKit
//
//  Created by Kevin Wooten on 7/7/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "DAO.h"
#import "UserChat.h"
#import "GroupChat.h"


NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM (int32_t, ChatType) {
  ChatTypeUser,
  ChatTypeGroup,
};


@interface ChatDAO : DAO

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

-(instancetype) initWithDBManager:(DBManager *)dbManager;

-(BOOL) fetchChatForAlias:(NSString *)alias localAlias:(NSString *)localAlias returning:(Chat *__nullable __autoreleasing *__nonnull)chat error:(NSError **)error;

-(BOOL) updateChat:(Chat *)chat withLastMessage:(nullable Message *)message error:(NSError **)error;
-(BOOL) updateChat:(Chat *)chat withLastSentMessage:(Message *)message error:(NSError **)error;
-(BOOL) updateChat:(Chat *)chat withLastReceivedMessage:(Message *)message error:(NSError **)error;

-(BOOL) updateChat:(Chat *)chat withClarifiedCount:(int)clarifiedCount;
-(BOOL) updateChat:(Chat *)chat withUpdatedCount:(int)updatedCount;

-(BOOL) updateChat:(GroupChat *)chat addGroupMember:(NSString *)alias error:(NSError **)error;
-(BOOL) updateChat:(GroupChat *)chat removeGroupMember:(NSString *)alias error:(NSError **)error;

-(BOOL) resetUnreadCountsForChat:(Chat *)chat;

@end


@interface ChatDAO (Generics)

-(nullable __kindof Chat *) fetchChatWithId:(Id *)id NS_REFINED_FOR_SWIFT;
-(BOOL) fetchChatWithId:(Id *)id returning:(Chat *__nullable *__nonnull)msg error:(NSError **)error;
-(nullable NSArray<__kindof Chat *> *) fetchAllChatsMatching:(nullable NSString *)where error:(NSError **)error;
-(nullable NSArray<__kindof Chat *> *) fetchAllChatsMatching:(nullable NSString *)where parameters:(nullable NSArray *)parameters error:(NSError **)error;
-(nullable NSArray<__kindof Chat *> *) fetchAllChatsMatching:(nullable NSString *)where parametersNamed:(nullable NSDictionary *)parameters error:(NSError **)error;
-(nullable NSArray<__kindof Chat *> *) fetchAllChatsMatching:(NSPredicate *)predicate
                                                        offset:(NSUInteger)offset limit:(NSUInteger)limit
                                                      sortedBy:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                                                         error:(NSError **)error;

-(BOOL) insertChat:(Chat *)model error:(NSError **)error;
-(BOOL) updateChat:(Chat *)model error:(NSError **)error;
-(BOOL) upsertChat:(Chat *)model error:(NSError **)error;
-(BOOL) deleteChat:(Chat *)model error:(NSError **)error;
-(BOOL) deleteAllChatsInArray:(NSArray<Chat *> *)models error:(NSError **)error;
-(BOOL) deleteAllChatsAndReturnError:(NSError **)error;
-(BOOL) deleteAllChatsMatching:(nullable NSString *)where error:(NSError **)error;
-(BOOL) deleteAllChatsMatching:(nullable NSString *)where parameters:(nullable NSArray *)parameters error:(NSError **)error;
-(BOOL) deleteAllChatsMatching:(nullable NSString *)where parametersNamed:(nullable NSDictionary *)parameters error:(NSError **)error;

@end


@interface Chat (DAO)

+(ChatType) typeCode;

@end


NS_ASSUME_NONNULL_END
