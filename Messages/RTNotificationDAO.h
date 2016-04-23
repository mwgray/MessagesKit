//
//  RTNotificationDAO.h
//  ReTxt
//
//  Created by Kevin Wooten on 7/8/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "RTDAO.h"
#import "RTChat.h"
#import "RTNotification.h"


NS_ASSUME_NONNULL_BEGIN


@interface RTNotificationDAO : RTDAO

@property (nonatomic, assign) int chatIdFieldIdx;
@property (nonatomic, assign) int dataFieldIdx;

-(NSArray<__kindof RTNotification *> *) fetchAllNotificationsForChat:(RTChat *)chat error:(NSError **)error;

@end


@interface RTNotificationDAO (Generics)

-(nullable __kindof RTNotification *) fetchNotificationWithId:(RTId *)id NS_REFINED_FOR_SWIFT;
-(BOOL) fetchNotificationWithId:(RTId *)id returning:(RTNotification *__nullable *__nonnull)msg error:(NSError **)error;
-(nullable NSArray<__kindof RTNotification *> *) fetchAllNotificationsMatching:(nullable NSString *)where error:(NSError **)error;
-(nullable NSArray<__kindof RTNotification *> *) fetchAllNotificationsMatching:(nullable NSString *)where parameters:(nullable NSArray *)parameters error:(NSError **)error;
-(nullable NSArray<__kindof RTNotification *> *) fetchAllNotificationsMatching:(nullable NSString *)where parametersNamed:(nullable NSDictionary *)parameters error:(NSError **)error;
-(nullable NSArray<__kindof RTNotification *> *) fetchAllNotificationsMatching:(NSPredicate *)predicate
                                                                        offset:(NSUInteger)offset limit:(NSUInteger)limit
                                                                      sortedBy:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                                                                         error:(NSError **)error;

-(BOOL) insertNotification:(RTNotification *)model error:(NSError **)error;
-(BOOL) updateNotification:(RTNotification *)model error:(NSError **)error;
-(BOOL) upsertNotification:(RTNotification *)model error:(NSError **)error;
-(BOOL) deleteNotification:(RTNotification *)model error:(NSError **)error;
-(int) deleteAllNotificationsInArray:(NSArray<RTNotification *> *)models error:(NSError **)error;
-(int) deleteAllNotificationsAndReturnError:(NSError **)error;
-(int) deleteAllNotificationsMatching:(nullable NSString *)where error:(NSError **)error;
-(int) deleteAllNotificationsMatching:(nullable NSString *)where parameters:(nullable NSArray *)parameters error:(NSError **)error;
-(int) deleteAllNotificationsMatching:(nullable NSString *)where parametersNamed:(nullable NSDictionary *)parameters error:(NSError **)error;

@end


NS_ASSUME_NONNULL_END