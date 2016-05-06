//
//  NSDate+Utils.h
//  MessagesKit
//
//  Created by Kevin Wooten on 2/1/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

@import Foundation;


@interface NSDate (Compat)

+(instancetype) dateWithMillisecondsSince1970:(long long)ms;

@property(nonatomic, readonly) long long millisecondsSince1970;

-(BOOL) isToday;
-(NSDate *) startOfDay;
-(NSDate *) endOfDay;
-(BOOL) isBetweenDate:(NSDate *)earlierDate andDate:(NSDate *)laterDate;

-(NSDate *) offsetDays:(NSUInteger)days withCalendar:(NSCalendar *)calendar;
-(NSDate *) offsetMonths:(NSUInteger)months withCalendar:(NSCalendar *)calendar;
-(NSDate *) offsetYears:(NSUInteger)years withCalendar:(NSCalendar *)calendar;

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
