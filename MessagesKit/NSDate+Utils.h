//
//  NSDate+Utils.h
//  MessagesKit
//
//  Created by Kevin Wooten on 2/1/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;


NS_ASSUME_NONNULL_BEGIN


@interface NSDate (Compat)

+(instancetype) dateWithMillisecondsSince1970:(long long)ms;

@property(nonatomic, readonly) long long millisecondsSince1970;

@property (readonly) BOOL isToday;
@property (readonly) NSDate *startOfDay;
@property (readonly) NSDate *endOfDay;

-(BOOL) isBetweenDate:(NSDate *)earlierDate andDate:(NSDate *)laterDate;

-(NSDate *) offsetDays:(NSInteger)days;
-(NSDate *) offsetMonths:(NSInteger)months;
-(NSDate *) offsetYears:(NSInteger)years;
-(NSDate *) offsetDays:(NSInteger)days withCalendar:(NSCalendar *)calendar;
-(NSDate *) offsetMonths:(NSInteger)months withCalendar:(NSCalendar *)calendar;
-(NSDate *) offsetYears:(NSInteger)years withCalendar:(NSCalendar *)calendar;

@end



/** Compare dates with millisecond precision
 *
 * NSDates have sub-millisecond precision but
 * when storing and retrieving from SQLite
 * we only get millisecond precision.
 */
static inline
BOOL isEqualDate(NSDate *a, NSDate *b)
{
  return a == b || a.timeIntervalSince1970 == b.timeIntervalSince1970;
}


NS_ASSUME_NONNULL_END
