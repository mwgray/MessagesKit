//
//  NSDate+Utils.m
//  ReTxt
//
//  Created by Kevin Wooten on 2/1/14.
//  Copyright (c) 2014 reTXT Labs, LLC. All rights reserved.
//

#import "NSDate+Utils.h"


@implementation NSDate (Compat)

+(instancetype) dateWithMillisecondsSince1970:(long long)ms
{
  return [NSDate dateWithTimeIntervalSince1970:((double)ms) / 1000.0];
}

-(long long) millisecondsSince1970
{
  return ((long long)[self timeIntervalSince1970]) * 1000ll;
}

-(BOOL) isToday
{
  NSCalendar *cal = [NSCalendar autoupdatingCurrentCalendar];
  NSDateComponents *components = [cal components:(NSCalendarUnitEra|NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay) fromDate:[NSDate date]];
  NSDate *today = [cal dateFromComponents:components];
  components = [cal components:(NSCalendarUnitEra|NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay) fromDate:self];
  NSDate *otherDate = [cal dateFromComponents:components];

  return [today isEqualToDate:otherDate];
}

-(NSDate *) startOfDay
{
  NSCalendar *calendar = [NSCalendar autoupdatingCurrentCalendar];
  NSUInteger preservedComponents = (NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay);
  return [calendar dateFromComponents:[calendar components:preservedComponents fromDate:self]];
}

-(NSDate *) endOfDay
{
  return [[self dateByAddingTimeInterval:86400] startOfDay];
}

-(BOOL) isBetweenDate:(NSDate *)earlierDate andDate:(NSDate *)laterDate
{
  // first check that we are later than the earlierDate.
  if ([self compare:earlierDate] == NSOrderedDescending) {

    // next check that we are earlier than the laterData
    if ([self compare:laterDate] == NSOrderedAscending) {
      return YES;
    }
  }

  // otherwise we are not
  return NO;
}

-(NSDate *) offsetDays:(NSUInteger)days withCalendar:(NSCalendar *)calendar
{
  NSDateComponents *comps = [NSDateComponents new];
  comps.day = days;
  
  return [calendar dateByAddingComponents:comps toDate:self options:0];
}

-(NSDate *) offsetMonths:(NSUInteger)months withCalendar:(NSCalendar *)calendar
{
  NSDateComponents *comps = [NSDateComponents new];
  comps.month = months;
  
  return [calendar dateByAddingComponents:comps toDate:self options:0];
}

-(NSDate *) offsetYears:(NSUInteger)years withCalendar:(NSCalendar *)calendar
{
  NSDateComponents *comps = [NSDateComponents new];
  comps.year = years;
  
  return [calendar dateByAddingComponents:comps toDate:self options:0];
}

@end
