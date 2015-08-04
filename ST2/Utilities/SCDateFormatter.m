/*
Copyright (C) 2013-2015, Silent Circle, LLC. All rights reserved.

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
#import "SCDateFormatter.h"


@implementation SCDateFormatter

/**
 * This method is extensively documented in the header file.
 * Please read the header file as "templates" can be confusing.
**/
+ (NSDateFormatter *)localizedDateFormatterFromTemplate:(NSString *)templateString
{
	NSLocale *currentLocale = [NSLocale currentLocale];
	NSString *localizedDateFormatString = [NSDateFormatter dateFormatFromTemplate:templateString
	                                                                      options:0
	                                                                       locale:currentLocale];
	
	return [self dateFormatterWithLocalizedFormat:localizedDateFormatString
	                                       locale:currentLocale
	                                     timeZone:nil
	                   doesRelativeDateFormatting:NO
	                                        cache:YES];
}

/**
 * This method is extensively documented in the header file.
 * Please read the header file as "templates" can be confusing.
**/
+ (NSDateFormatter *)localizedDateFormatterFromTemplate:(NSString *)templateString
                                                  cache:(BOOL)shouldCacheInThreadDictionary
{
	NSLocale *currentLocale = [NSLocale currentLocale];
	NSString *localizedDateFormatString = [NSDateFormatter dateFormatFromTemplate:templateString
	                                                                      options:0
	                                                                       locale:currentLocale];
	
	return [self dateFormatterWithLocalizedFormat:localizedDateFormatString
	                                       locale:currentLocale
	                                     timeZone:nil
	                   doesRelativeDateFormatting:NO
	                                        cache:YES];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Styles
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * See header file for documentation.
**/
+ (NSDateFormatter *)dateFormatterWithDateStyle:(NSDateFormatterStyle)dateStyle
                                      timeStyle:(NSDateFormatterStyle)timeStyle
{
	return [self dateFormatterWithDateStyle:dateStyle
	                              timeStyle:timeStyle
	             doesRelativeDateFormatting:NO
	                                  cache:YES];
}

/**
 * See header file for documentation.
**/
+ (NSDateFormatter *)dateFormatterWithDateStyle:(NSDateFormatterStyle)dateStyle
                                      timeStyle:(NSDateFormatterStyle)timeStyle
                     doesRelativeDateFormatting:(BOOL)doesRelativeDateFormatting
{
	return [self dateFormatterWithDateStyle:dateStyle
	                              timeStyle:timeStyle
	             doesRelativeDateFormatting:doesRelativeDateFormatting
	                                  cache:YES];
}

/**
 * See header file for documentation.
**/
+ (NSDateFormatter *)dateFormatterWithDateStyle:(NSDateFormatterStyle)dateStyle
                                      timeStyle:(NSDateFormatterStyle)timeStyle
                     doesRelativeDateFormatting:(BOOL)doesRelativeDateFormatting
                                          cache:(BOOL)shouldCacheInThreadDictionary
{
	if (shouldCacheInThreadDictionary)
	{
		NSString *key = [NSString stringWithFormat:@"SCDateFormatter(%lu,%lu) %@",
		                                           (unsigned long)dateStyle,
		                                           (unsigned long)timeStyle,
		                                           doesRelativeDateFormatting ? @"Y" : @"N"];
		
		NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
		NSDateFormatter *dateFormatter = [threadDictionary objectForKey:key];
        
        if (dateFormatter == nil)
        {
            dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.dateStyle = dateStyle;
			dateFormatter.timeStyle = timeStyle;
			
			if (doesRelativeDateFormatting)
				dateFormatter.doesRelativeDateFormatting = doesRelativeDateFormatting;
			
			[threadDictionary setObject:dateFormatter forKey:key];
        }
        
        return dateFormatter;
	}
	else
	{
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateStyle = dateStyle;
		dateFormatter.timeStyle = timeStyle;
		
		if (doesRelativeDateFormatting)
			dateFormatter.doesRelativeDateFormatting = doesRelativeDateFormatting;
        
        return dateFormatter;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Formats
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * See header file for documentation.
**/
+ (NSDateFormatter *)dateFormatterWithLocalizedFormat:(NSString *)localizedDateFormatString
{
	return [self dateFormatterWithLocalizedFormat:localizedDateFormatString
	                                       locale:nil
	                                     timeZone:nil
	                   doesRelativeDateFormatting:NO
	                                        cache:YES];
}

/**
 * See header file for documentation.
**/
+ (NSDateFormatter *)dateFormatterWithLocalizedFormat:(NSString *)localizedDateFormatString
                                               locale:(NSLocale *)locale
{
	return [self dateFormatterWithLocalizedFormat:localizedDateFormatString
	                                       locale:locale
	                                     timeZone:nil
	                   doesRelativeDateFormatting:NO
	                                        cache:YES];
}

/**
 * See header file for documentation.
**/
+ (NSDateFormatter *)dateFormatterWithLocalizedFormat:(NSString *)localizedDateFormatString
                                               locale:(NSLocale *)locale
											 timeZone:(NSTimeZone *)timeZone
{
	return [self dateFormatterWithLocalizedFormat:localizedDateFormatString
	                                       locale:locale
	                                     timeZone:timeZone
	                   doesRelativeDateFormatting:NO
	                                        cache:YES];
}

/**
 * See header file for documentation.
**/
+ (NSDateFormatter *)dateFormatterWithLocalizedFormat:(NSString *)localizedDateFormatString
                                               locale:(NSLocale *)locale
                                             timeZone:(NSTimeZone *)timeZone
                           doesRelativeDateFormatting:(BOOL)doesRelativeDateFormatting;
{
	return [self dateFormatterWithLocalizedFormat:localizedDateFormatString
	                                       locale:locale
	                                     timeZone:timeZone
	                   doesRelativeDateFormatting:doesRelativeDateFormatting
	                                        cache:YES];
}

/**
 * See header file for documentation.
**/
+ (NSDateFormatter *)dateFormatterWithLocalizedFormat:(NSString *)localizedDateFormatString
                                               locale:(NSLocale *)locale
                                             timeZone:(NSTimeZone *)timeZone
                           doesRelativeDateFormatting:(BOOL)doesRelativeDateFormatting
                                                cache:(BOOL)shouldCacheInThreadDictionary
{
	if (shouldCacheInThreadDictionary)
	{
		NSString *key = [NSString stringWithFormat:@"SCDateFormatter(%@) %@ %@ %@",
		                                           localizedDateFormatString,
		                                           locale ? [locale localeIdentifier] : @"nil",
		                                           timeZone ? [timeZone name] : @"nil",
		                                           doesRelativeDateFormatting ? @"Y" : @"N"];
		
		NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
		NSDateFormatter *dateFormatter = [threadDictionary objectForKey:key];
        
        if (dateFormatter == nil)
        {
            dateFormatter = [[NSDateFormatter alloc] init];
            dateFormatter.dateFormat = localizedDateFormatString;
            
			if (locale)
				dateFormatter.locale = locale;
			
            if (timeZone)
                dateFormatter.timeZone = timeZone;
			
			if (doesRelativeDateFormatting)
				dateFormatter.doesRelativeDateFormatting = doesRelativeDateFormatting;
			
			[threadDictionary setObject:dateFormatter forKey:key];
        }
        
        return dateFormatter;
    }
    else
    {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = localizedDateFormatString;
		
		if (locale)
			dateFormatter.locale = locale;
		
        if (timeZone)
            dateFormatter.timeZone = timeZone;
		
		if (doesRelativeDateFormatting)
			dateFormatter.doesRelativeDateFormatting = doesRelativeDateFormatting;
        
        return dateFormatter;
    }
}

@end
