//
//  CGICalendarProperty.h
//
//  Created by Satoshi Konno on 11/01/27.
//  Copyright 2011 Satoshi Konno. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CGICalendarValue.h"
#import "CGICalendarParameter.h"

extern NSString * const CGICalendarPropertyPartstat;

extern NSString * const CGICalendarPropertyCompleted;
extern NSString * const CGICalendarPropertyDtend;
extern NSString * const CGICalendarPropertyDue;
extern NSString * const CGICalendarPropertyDtstart;

// 4.8.1 Descriptive Component Properties

extern NSString * const CGICalendarPropertyDescription;
extern NSString * const CGICalendarPropertyPriority;
extern NSString * const CGICalendarPropertySummary;
extern NSString * const CGICalendarPropertyLocation;
extern NSString * const CGICalendarPropertyURL;
  
// 4.8.4 Relationship Component Properties

extern NSString * const CGICalendarPropertyUid;

// 4.8.7 Change Management Component Properties

extern NSString * const CGICalendarPropertyCreated;
extern NSString * const CGICalendarPropertyDtstamp;
extern NSString * const CGICalendarPropertyLastModified;
extern NSString * const CGICalendarPropertySequence;

typedef enum : NSUInteger {
	CGICalendarParticipationStatusUnkown = 0,
	CGICalendarParticipationStatusNeedsAction,
	CGICalendarParticipationStatusAccepted,
	CGICalendarParticipationStatusDeclined,
	CGICalendarParticipationStatusTentative,
	CGICalendarParticipationStatusDelegated,
	CGICalendarParticipationStatusCompleted,
	CGICalendarParticipationStatusInProcess,
} CGICalendarParticipationStatus;

@interface CGICalendarProperty : CGICalendarValue

@property (strong) NSMutableArray *parameters;

- (BOOL)hasParameterForName:(NSString *)name;
- (void)addParameter:(CGICalendarParameter *)parameter;
- (void)removeParameterForName:(NSString *)name;

- (void)setParameterValue:(NSString *)value forName:(NSString *)name;
- (void)setParameterValue:(NSString *)value forName:(NSString *)name parameterValues:(NSArray *)parameterValues parameterNames:(NSArray *)parameterNames;
- (void)setParameterObject:(id)object forName:(NSString *)name;
- (void)setParameterObject:(id)object forName:(NSString *)name parameterValues:(NSArray *)parameterValues parameterNames:(NSArray *)parameterNames;
- (void)setParameterDate:(NSDate *)object forName:(NSString *)name;
- (void)setParameterDate:(NSDate *)object forName:(NSString *)name parameterValues:(NSArray *)parameterValues parameterNames:(NSArray *)parameterNames;
- (void)setParameterInteger:(NSInteger)value forName:(NSString *)name;
- (void)setParameterInteger:(NSInteger)value forName:(NSString *)name parameterValues:(NSArray *)parameterValues parameterNames:(NSArray *)parameterNames;
- (void)setParameterFloat:(float)value forName:(NSString *)name;
- (void)setParameterFloat:(float)value forName:(NSString *)name parameterValues:(NSArray *)parameterValues parameterNames:(NSArray *)parameterNames;

- (CGICalendarParameter *)parameterAtIndex:(NSUInteger)index;
- (CGICalendarParameter *)parameterForName:(NSString *)name;
- (NSArray *)allParameterKeys;
- (NSString *)parameterValueForName:(NSString *)name;
- (NSDate *)parameterDateForName:(NSString *)name;
- (NSInteger)parameterIntegerForName:(NSString *)name;
- (float)parameterFloatForName:(NSString *)name;

- (void)setParticipationStatus:(CGICalendarParticipationStatus)value;
- (CGICalendarParticipationStatus)participationStatus;

@end
