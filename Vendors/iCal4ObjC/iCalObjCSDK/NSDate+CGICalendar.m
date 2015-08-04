//
//  NSDate+CGICalendar.m
//
//  Created by Satoshi Konno on 5/12/11.
//  Copyright 2011 Satoshi Konno. All rights reserved.
//

#import "NSDate+CGICalendar.h"

NSString * const CGNSDateICalendarDatetimeFormat = @"yyyyMMdd'T'kkmmss'Z'";
NSString * const CGNSDateISO8601DatetimeFormat = @"yyyy-MM-dd kk:mm:ss";

@implementation NSDate(CGICalendar)

+ (id)dateWithICalendarString:(NSString *)aString {
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
	[dateFormatter setTimeZone:timeZone];
	[dateFormatter setDateFormat:CGNSDateICalendarDatetimeFormat];
	NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
	[dateFormatter setLocale:locale];
	return [dateFormatter dateFromString:aString];
}

+ (id)dateWithICalendarISO8601:(NSString *)aString {
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
	[dateFormatter setTimeZone:timeZone];
	[dateFormatter setTimeStyle:NSDateFormatterFullStyle];
	[dateFormatter setDateFormat:CGNSDateISO8601DatetimeFormat];
	return [dateFormatter dateFromString:aString];
}

- (NSString *)descriptionICalendar {
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
	[dateFormatter setTimeZone:timeZone];
	[dateFormatter setDateFormat:CGNSDateICalendarDatetimeFormat];
	return [dateFormatter stringFromDate:self];
}

- (NSString *)descriptionISO8601 {
	NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setLocale:[NSLocale systemLocale]];
	[dateFormatter setDateFormat:CGNSDateISO8601DatetimeFormat];
	return [dateFormatter stringFromDate:self];
}

@end