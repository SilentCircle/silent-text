//
//  CGICalendarValue.m
//
//  Created by Satoshi Konno on 11/01/27.
//  Copyright 2011 Satoshi Konno. All rights reserved.
//

#import "CGICalendarValue.h"
#import "NSDate+CGICalendar.h"

@implementation CGICalendarValue

- (BOOL)hasName {
	if ([self name] != nil && 0 < [[self name] length]) {
		return YES;
	}
	return NO;
}

- (BOOL)hasValue {
	if ([self value] != nil && 0 < [[self value] length]) {
		return YES;
	}
	return NO;
}

- (BOOL)isName:(NSString *)aName {
	if (aName == nil || [aName length] <= 0) {
		return NO;
	}
	return [aName isEqualToString:[self name]];
}

- (BOOL)isValue:(NSString *)aValue {
	if (aValue == nil || [aValue length] <= 0) {
		return NO;
	}
	return [aValue isEqualToString:[self value]];
}

- (void)setObject:(id)aValue {
	[self setValue:[self.value description]];
}

- (void)setDate:(NSDate *)aValue {
	[self setValue:[aValue descriptionICalendar]];
}

- (NSDate *)dateValue {
	return [NSDate dateWithICalendarString:[self value]];
}

- (NSInteger)integerValue {
	return [[self value] integerValue];
}

- (float)floatValue {
	return [[self value] floatValue];}

@end
