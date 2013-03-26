/*
Copyright © 2012-2013, Silent Circle, LLC.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Any redistribution, use, or modification is done solely for personal 
      benefit and not for any commercial purpose or for monetary gain
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name Silent Circle nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SILENT CIRCLE, LLC BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import "NSDate+SCDate.h"

@implementation NSDate (whenString)

- (NSDate *)dateWithZeroTime
{
    NSCalendar *calendar = [NSCalendar currentCalendar];
    unsigned unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSWeekdayCalendarUnit;
    NSDateComponents *comps = [calendar components:unitFlags fromDate:self];
    [comps setHour:0];
    [comps setMinute:0];
    [comps setSecond:0];
    return [calendar dateFromComponents:comps];
}

- (NSString *)whenString
{
    NSDate *selfZero = [self dateWithZeroTime];
    NSDate *todayZero = [[NSDate date] dateWithZeroTime];
    NSTimeInterval interval = [todayZero timeIntervalSinceDate:selfZero];
    int dayDiff = interval/(60*60*24);
    
    // Initialize the formatter.
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    if (dayDiff == 0) { // today: show time only
        [formatter setDateStyle:NSDateFormatterNoStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
    } else if (dayDiff == 1 || dayDiff == -1) {
        [formatter setDoesRelativeDateFormatting:YES];
        [formatter setDateStyle:NSDateFormatterMediumStyle];
        [formatter setTimeStyle:NSDateFormatterNoStyle];
    } else if (dayDiff <= 7) { // < 1 week ago: show weekday
        [formatter setDateFormat:@"EEEE"];
    } else { // show date
        [formatter setDateStyle:NSDateFormatterShortStyle];
        [formatter setTimeStyle:NSDateFormatterNoStyle];
    }
    
    return [formatter stringFromDate:self];
}


- (NSString *)rfc3339String
{
    NSString *const kZuluTimeFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"; // ISO 8601 time.

    // Quinn "The Eskimo" pointed me to:
    // <https://developer.apple.com/library/ios/#qa/qa1480/_index.html>.
    // The contained advice recommends all internet time formatting to use US POSIX standards.
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier: @"en_US_POSIX"];
    
    NSDateFormatter* formatter = NSDateFormatter.new;
    
    [formatter setLocale: enUSPOSIXLocale];
    [formatter setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
    [formatter setDateFormat: kZuluTimeFormat];
    
    return [formatter stringFromDate:self];

}


+ (NSDate*) dateFromRfc3339String:(NSString*)dateTime
{
    NSString *const kZuluTimeFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"; // ISO 8601 time.
    
    // Quinn "The Eskimo" pointed me to:
    // <https://developer.apple.com/library/ios/#qa/qa1480/_index.html>.
    // The contained advice recommends all internet time formatting to use US POSIX standards.
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier: @"en_US_POSIX"];
    
    NSDateFormatter* formatter = NSDateFormatter.new;
    
    [formatter setLocale: enUSPOSIXLocale];
    [formatter setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
    [formatter setDateFormat: kZuluTimeFormat];
    
    return [formatter dateFromString:dateTime];
    
}

+ (NSDateFormatter *)shFormatter {
    static NSDateFormatter *formatter = nil;
    if (formatter == nil) {
    	formatter = [[NSDateFormatter alloc] init];
    	NSLocale *enUS = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    	[formatter setLocale:enUS];
    	[formatter setDateFormat:@"EEE MMM dd HH:mm:ss z yyyy"];
    }
    return formatter;
}

+ (NSDate *)dateFromSh:(NSString *)date {
    NSDateFormatter *formatter = [NSDate shFormatter];
    return [formatter dateFromString:date];
}


+ (NSDate*) dateFromEXIF:(NSString*)dateTime
{
    NSDate* originalDate = nil;
    
    if (dateTime) {
        NSDateFormatter* exifFormat =  [[NSDateFormatter alloc] init] ;
        [exifFormat setDateFormat:@"yyyy:MM:dd HH:mm:ss"];
        originalDate = [exifFormat dateFromString:dateTime];
    }
    return originalDate;
}

- (NSString *)ExifString {
    
    static NSDateFormatter *dateFormatter;
    
    if (dateFormatter == nil) {
        dateFormatter = [[NSDateFormatter alloc] init];
        NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        [dateFormatter setTimeZone:timeZone];
        [dateFormatter setDateFormat:@"yyyy:MM:dd HH:mm:ss"];
    }
    NSString *dateString = [dateFormatter stringFromDate:self];
    return dateString;
}


- (BOOL) isBefore: (NSDate *) date {
	
	return [self compare: date] == NSOrderedDescending;
	
}  


- (BOOL) isAfter: (NSDate *)   date {
	
	return [self compare: date] == NSOrderedAscending;
	
}  



@end
