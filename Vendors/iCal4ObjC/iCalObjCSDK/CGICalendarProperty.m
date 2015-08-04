//
//  CGICalendarProperty.m
//
//  Created by Satoshi Konno on 11/01/27.
//  Copyright 2011 Satoshi Konno. All rights reserved.
//

#import "CGICalendarProperty.h"
#import "CGICalendarContentLine.h"
#import "NSDate+CGICalendar.h"

NSString * const CGICalendarPropertyPartstat = @"PARTSTAT";
NSString * const CGICalendarPropertyCompleted = @"COMPLETED";
NSString * const CGICalendarPropertyDtend = @"DTEND";
NSString * const CGICalendarPropertyDue = @"DUE";
NSString * const CGICalendarPropertyDtstart = @"DTSTART";
NSString * const CGICalendarPropertyDescription = @"DESCRIPTION";
NSString * const CGICalendarPropertyPriority = @"PRIORITY";
NSString * const CGICalendarPropertySummary = @"SUMMARY";
NSString * const CGICalendarPropertyUid = @"UID";
NSString * const CGICalendarPropertyCreated = @"CREATED";
NSString * const CGICalendarPropertyDtstamp = @"DTSTAMP";
NSString * const CGICalendarPropertyLastModified = @"LAST-MODIFIED";
NSString * const CGICalendarPropertySequence = @"SEQUENCE";
NSString * const CGICalendarPropertyLocation = @"LOCATION";
NSString * const CGICalendarPropertyURL = @"URL";

@implementation CGICalendarProperty

#pragma mark -
#pragma mark Parameter

- (BOOL)hasParameterForName:(NSString *)name {
	for (CGICalendarParameter *icalProp in [self parameters]) {
		if ([icalProp isName:name]) {
			[[self parameters] removeObject:icalProp];
			return YES;
		}
	}
	return NO;
}

- (void)addParameter:(CGICalendarParameter *)parameter {
    if(!self.parameters)
       self.parameters = [NSMutableArray array];
       
	[[self parameters] addObject:parameter];
}

- (void)removeParameterForName:(NSString *)name {
	for (CGICalendarParameter *icalProp in [self parameters]) {
		if ([icalProp isName:name]) {
			[[self parameters] removeObject:icalProp];
			return;
		}
	}
}

- (void)setParameterValue:(NSString *)value forName:(NSString *)name {
	CGICalendarParameter *icalProp = [self parameterForName:name];
	if (icalProp == nil) {
		icalProp = [[CGICalendarParameter alloc] init];
		[icalProp setName:name];
		[self addParameter:icalProp];
	}
	[icalProp setValue:value];
}

- (void)setParameterValue:(NSString *)value forName:(NSString *)name parameterValues:(NSArray *)parameterValues parameterNames:(NSArray *)parameterNames; {
	[self setParameterValue:value forName:name parameterValues:[NSArray array] parameterNames:[NSArray array]];
}

- (void)setParameterObject:(id)object forName:(NSString *)name parameterValues:(NSArray *)parameterValues parameterNames:(NSArray *)parameterNames {
	[self setParameterValue:[object description] forName:name parameterValues:parameterValues parameterNames:parameterNames];
}

- (void)setParameterObject:(id)object forName:(NSString *)name {
	[self setParameterValue:[object description] forName:name];
}

- (void)setParameterDate:(NSDate *)object forName:(NSString *)name {
	[self setParameterValue:[object descriptionICalendar] forName:name];
}

- (void)setParameterDate:(NSDate *)object forName:(NSString *)name parameterValues:(NSArray *)parameterValues parameterNames:(NSArray *)parameterNames {
	[self setParameterValue:[object descriptionICalendar] forName:name parameterValues:parameterValues parameterNames:parameterNames];
}

- (void)setParameterInteger:(NSInteger)value forName:(NSString *)name {
	[self setParameterValue:[[NSNumber numberWithInteger:value] stringValue] forName:name parameterValues:[NSArray array] parameterNames:[NSArray array]];
}

- (void)setParameterInteger:(NSInteger)value forName:(NSString *)name parameterValues:(NSArray *)parameterValues parameterNames:(NSArray *)parameterNames {
	[self setParameterValue:[[NSNumber numberWithInteger:value] stringValue] forName:name parameterValues:parameterValues parameterNames:parameterNames];
}

- (void)setParameterFloat:(float)value forName:(NSString *)name {
	[self setParameterValue:[[NSNumber numberWithFloat:value] stringValue] forName:name parameterValues:[NSArray array] parameterNames:[NSArray array]];
}

- (void)setParameterFloat:(float)value forName:(NSString *)name parameterValues:(NSArray *)parameterValues parameterNames:(NSArray *)parameterNames {
	[self setParameterValue:[[NSNumber numberWithFloat:value] stringValue] forName:name parameterValues:parameterValues parameterNames:parameterNames];
}

- (id)parameterAtIndex:(NSUInteger)index {
	return [[self parameters] objectAtIndex:index];
}

- (CGICalendarParameter *)parameterForName:(NSString *)name {
	for (CGICalendarParameter *icalProp in [self parameters]) {
		if ([icalProp isName:name]) {
			return icalProp;
		}
	}
	return nil;
}

- (NSArray *)allParameterKeys {
	NSMutableArray *keys = [NSMutableArray array];
	for (CGICalendarParameter *icalProp in [self parameters]) {
		[keys addObject:[icalProp name]];
	}
	return keys;
}

- (NSString *)parameterValueForName:(NSString *)name {
	for (CGICalendarParameter *icalProp in [self parameters]) {
		if ([icalProp isName:name]) {
			return [icalProp value];
		}
	}
	return nil;
}

- (NSDate *)parameterDateForName:(NSString *)name {
	for (CGICalendarParameter *icalProp in [self parameters]) {
		if ([icalProp isName:name]) {
			return [icalProp dateValue];
		}
	}
	return nil;
}

- (NSInteger)parameterIntegerForName:(NSString *)name; {
	for (CGICalendarParameter *icalProp in [self parameters]) {
		if ([icalProp isName:name]) {
			return [icalProp integerValue];
		}
	}
	return 0;
}

- (float)parameterFloatForName:(NSString *)name; {
	for (CGICalendarParameter *icalProp in [self parameters]) {
		if ([icalProp isName:name]) {
			return [icalProp floatValue];
		}
	}
	return 0;
}

#pragma mark -
#pragma mark String

- (NSString *)description {
	NSMutableString *propertyString = [NSMutableString string];
	[propertyString appendFormat:@"%@", [self name]];
	for (CGICalendarParameter *icalParam in [self parameters]) {
		[propertyString appendFormat:@";%@", [icalParam description]];
	}
	[propertyString appendFormat:@"%% :%@%@", ((0 < [[self value] length]) ? [self value] : @""), CGICalendarContentlineTerm];
	return propertyString;
}

#pragma mark -
#pragma mark ParticipationStatus

- (NSArray *)participationStatusStrings {
	static NSArray *statusStrings = nil;
	if (statusStrings == nil) {
		statusStrings = [NSArray arrayWithObjects:
						 @"",
						 @"NEEDS-ACTION",
						 @"ACCEPTED",
						 @"DECLINED",
						 @"TENTATIVE",
						 @"DELEGATED",
						 @"COMPLETED",
						 @"IN-PROCESS",
						 nil];
	}
	return statusStrings;
}

- (void)setParticipationStatus:(CGICalendarParticipationStatus)status{
	NSArray *statusStrings = [self participationStatusStrings];
	if (([statusStrings count]-1) < status) {
		return;
	}
	[self setValue:[statusStrings objectAtIndex:status]];
}

- (CGICalendarParticipationStatus)participationStatus {
	if ([self value] == nil) {
		return CGICalendarParticipationStatusUnkown;
	}
	NSArray *statusStrings = [self participationStatusStrings];
	for (NSUInteger n = 0; n < [statusStrings count]; n++) {
		if ([[self value] isEqualToString:[statusStrings objectAtIndex:n]]) {
			return n;
		}
	}
	return CGICalendarParticipationStatusUnkown;
}

@end
