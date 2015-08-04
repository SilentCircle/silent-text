//
//  CGICalendarParameter.m
//
//  Created by Satoshi Konno on 11/01/27.
//  Copyright 2011 Satoshi Konno. All rights reserved.
//

#import "CGICalendarParameter.h"

NSString * const CGICalendarParameterDelimiter = @"=";

@implementation CGICalendarParameter

- (id)initWithString:(NSString *)aString {
	if ((self = [self init])) {
		[self setString:aString];
	}
	return self;
}

- (void)setString:(NSString *)aString {
	NSArray *values = [aString componentsSeparatedByString:CGICalendarParameterDelimiter];
	if ([values count] < 2) {
		return;
	}
	[self setName:[values objectAtIndex:0]];
	[self setValue:[values objectAtIndex:1]];
}

- (NSString *) string {
	return [NSString stringWithFormat:@"%@%@%@",
			[self name] ? [self name] : @"",
			CGICalendarParameterDelimiter,
			[self value] ? [self value] : @""];
}

@end
