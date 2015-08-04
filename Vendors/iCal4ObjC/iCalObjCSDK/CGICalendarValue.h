//
//  CGICalendarValue.h
//
//  Created by Satoshi Konno on 11/01/27.
//  Copyright 2011 Satoshi Konno. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
	CGICalendarValueTypeUnknown = 0,
	CGICalendarValueTypeBinary,
	CGICalendarValueTypeBoolean,
	CGICalendarValueTypeCalendarUserAddress,
	CGICalendarValueTypeDate,
	CGICalendarValueTypeDateTime,
	CGICalendarValueTypeDuration,
	CGICalendarValueTypeFloat,
	CGICalendarValueTypeInteger,
	CGICalendarValueTypePeriodOfTime,
	CGICalendarValueTypeRecurrenceRule,
	CGICalendarValueTypeText,
	CGICalendarValueTypeTime,
	CGICalendarValueTypeURI,
	CGICalendarValueTypeUTCOffset,
} CGICalendarValueType;

@interface CGICalendarValue : NSObject

@property (assign) CGICalendarValueType type;
@property (strong) NSString *name;
@property (strong) NSString *value;

- (BOOL)hasName;
- (BOOL)hasValue;

- (BOOL)isName:(NSString *)aName;
- (BOOL)isValue:(NSString *)aValue;

- (void)setObject:(id)value;
- (void)setDate:(NSDate *)value;

- (NSDate *)dateValue;
- (NSInteger)integerValue;
- (float)floatValue;

@end
