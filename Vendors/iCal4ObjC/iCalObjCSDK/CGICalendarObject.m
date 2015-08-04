//
//  CGICalendarObject.m
//
//  Created by Satoshi Konno on 11/01/27.
//  Copyright 2011 Satoshi Konno. All rights reserved.
//

#import "CGICalendarObject.h"

NSString * const CGICalendarObjectVersionDefault = @"2.0";
NSString * const CGICalendarObjectProdidDefault = @"//CyberGarage//iCal4ObjC//EN";

NSString * const CGICalendarObjectTypeDefault = @"VCALENDAR";
NSString * const CGICalendarObjectVersionParam = @"VERSION";
NSString * const CGICalendarObjectProdidParam = @"PRODID";

@implementation CGICalendarObject

#pragma mark -
#pragma mark Global

+ (id)object {
	return [[CGICalendarObject alloc] init];
}

+ (id)objectWithProdid:(NSString *)prodid {
	return [[CGICalendarObject alloc] initWithProdid:prodid];
}

+ (id)objectWithProdid:(NSString *)prodid version:(NSString *)version {
	return [[CGICalendarObject alloc] initWithProdid:prodid version:version];
}

#pragma mark -
#pragma mark Initialize

- (id)init {
	if ((self = [super init])) {
		[self setType:CGICalendarObjectTypeDefault];
		[self setVersion:CGICalendarObjectVersionDefault];
		[self setProdid:CGICalendarObjectProdidDefault];
	}
	return self;
}

- (id)initWithProdid:(NSString *)prodid version:(NSString *)version; {
	if ((self = [super init])) {
		[self setType:CGICalendarObjectTypeDefault];
		[self setVersion:version];
		[self setProdid:prodid];
	}
	return self;
}

- (id)initWithProdid:(NSString *)prodid {
	if ((self = [super init])) {
		[self setType:CGICalendarObjectTypeDefault];
		[self setVersion:CGICalendarObjectVersionDefault];
		[self setProdid:prodid];
	}
	return self;
}

#pragma mark -
#pragma mark Property Utility Methods

- (void)setVersion:(NSString *)version {
	[self setPropertyValue:version forName:CGICalendarObjectVersionParam];
}

- (NSString *)version {
	return [self propertyValueForName:CGICalendarObjectVersionParam];
}

- (void)setProdid:(NSString *)prodid {
	[self setPropertyValue:prodid forName:CGICalendarObjectProdidParam];
}

- (NSString *)prodid {
	return [self propertyValueForName:CGICalendarObjectProdidParam];
}

#pragma mark -
#pragma mark conponents

- (NSArray *)componentsWithType:(NSString *)type {
	NSMutableArray *typeComponents = [NSMutableArray array];
	for (CGICalendarComponent *icalComponent in [self components]) {
		if ([icalComponent isType:type] == NO) {
			continue;
		}
		[typeComponents addObject:icalComponent];
	}
	return typeComponents;
}

- (NSArray *)events {
	return [self componentsWithType:CGICalendarComponentTypeEvent];
}

- (NSArray *)todos {
	return [self componentsWithType:CGICalendarComponentTypeTodo];
}

- (NSArray *)journals {
	return [self componentsWithType:CGICalendarComponentTypeJournal];
}

- (NSArray *)freebusies {
	return [self componentsWithType:CGICalendarComponentTypeFreebusy];
}

- (NSArray *)timezones {
	return [self componentsWithType:CGICalendarComponentTypeTimezone];
}

@end
