//
//  NSDictionaryExtras.m
//
//  Created by Misha Melikov on 8/29/10.
//  Copyright 2010 Artizia. All rights reserved.
//

#import "NSDictionaryExtras.h"
//#import "NSStringExtras.h"

@implementation NSDictionary (AZExtras)

- (BOOL)contains:(NSString *)key
{
	return ([self objectForKey:key] != nil);
}

- (NSString *)safeStringForKey:(NSString *)key
{
	id value = [self objectForKey:key];
	if ( (!value) || (value == [NSNull null]) )
		return nil;
	if (![value isKindOfClass:[NSString class]])
		return nil;	
	return value;
}

- (NSDate *)safeDateForKey:(NSString *)key format:(NSString *)format
{
	return [self safeDateForKey:key format:format timezone:@"PST"]; // default server timezone
}

- (NSDate *)safeDateForKey:(NSString *)key format:(NSString *)format timezone:(NSString *)timezone
{
	NSDate *resultDate = nil;
	NSString *dateS = [self safeStringForKey:key];
	if ([dateS length] > 0) {	
		// convert date out of server time
		NSTimeZone *timeZoneServer = [NSTimeZone timeZoneWithAbbreviation:timezone];
		NSDateFormatter *df = [[NSDateFormatter alloc] init];
		[df setTimeZone:timeZoneServer];
		[df setDateFormat:format];
		resultDate = [df dateFromString:dateS]; // [[df dateFromString:dateS] retain];
		//[df release];
	}
	return resultDate;
}

- (NSNumber *)safeNumberForKey:(NSString *)key
{
	id value = [self objectForKey:key];
	if ( (!value) || (value == [NSNull null]) )
		return nil;
	if ([value isKindOfClass:[NSNumber class]])
		return value;
	if (![value isKindOfClass:[NSString class]])
		return nil;
	
	NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
	NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
	[f setLocale:usLocale];
	//[usLocale release];
	[f setNumberStyle:NSNumberFormatterDecimalStyle];
	NSNumber *n = [f numberFromString:value];
	//[f release];
	return n;
}
- (NSNumber *)safeNumberNoNILForKey:(NSString *)key
{
	id value = [self safeNumberForKey:key];
	if (!value)
		value = [NSNumber numberWithInt:0];
	return value;
}

- (BOOL)safeBoolForKey:(NSString *)key
{
	id value = [self objectForKey:key];
	if ( (!value) || (value == [NSNull null]) )
		return NO;
	if ([value isKindOfClass:[NSNumber class]])
		return ([value intValue] != 0);
	if (![value isKindOfClass:[NSString class]])
		return NO;

	NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
	NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
	[f setLocale:usLocale];
	//[usLocale release];
	[f setNumberStyle:NSNumberFormatterDecimalStyle];
	NSNumber *n = [f numberFromString:value];
	//[f release];
	
	return ([n intValue] != 0);
}

- (int)safeIntForKey:(NSString *)key
{
	id value = [self objectForKey:key];
	if ( (!value) || (value == [NSNull null]) )
		return 0;
	if ([value isKindOfClass:[NSNumber class]])
		return [value intValue];
	if (![value isKindOfClass:[NSString class]])
		return 0;
	
	NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
	NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
	[f setLocale:usLocale];
	//[usLocale release];
	[f setNumberStyle:NSNumberFormatterDecimalStyle];
	NSNumber *n = [f numberFromString:value];
	//[f release];
	
	return [n intValue];
}

- (double)safeDoubleForKey:(NSString *)key
{
	id value = [self objectForKey:key];
	if ( (!value) || (value == [NSNull null]) )
		return 0;
	if ([value isKindOfClass:[NSNumber class]])
		return [value doubleValue];
	if (![value isKindOfClass:[NSString class]])
		return 0;
	
	NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
	NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
	[f setLocale:usLocale];
	//[usLocale release];
	[f setNumberStyle:NSNumberFormatterDecimalStyle];
	NSNumber *n = [f numberFromString:value];
	//[f release];
	
	return [n doubleValue];
}

- (unsigned long)safeUnsignedLongForKey:(NSString *)key
{
	id value = [self objectForKey:key];
	if ( (!value) || (value == [NSNull null]) )
		return 0;
	if ([value isKindOfClass:[NSNumber class]])
		return [value unsignedLongValue];
	if (![value isKindOfClass:[NSString class]])
		return 0;
	
	NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
	NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
	[f setLocale:usLocale];
	//[usLocale release];
	[f setNumberStyle:NSNumberFormatterDecimalStyle];
	NSNumber *n = [f numberFromString:value];
	//[f release];
	return [n unsignedLongValue];
}

@end
