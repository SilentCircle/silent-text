//
//  CGICalendarContentLine.h
//
//  Created by Satoshi Konno on 11/01/28.
//  Copyright 2011 Satoshi Konno. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CGICalendarProperty.h"

extern NSString * const CGICalendarContentlineTerm;
extern NSString * const CGICalendarContentlineFoldingSpace;
extern NSString * const CGICalendarContentlineFoldingTab;
extern NSString * const CGICalendarContentlineDelimiter;
extern NSString * const CGICalendarContentlineNameparamDelimiter;

extern NSString * const CGICalendarContentlineNameBegin;
extern NSString * const CGICalendarContentlineNameEnd;

extern NSString * const CGICalendarContentlineComponentVcalendar;
extern NSString * const CGICalendarContentlineComponentVevent;
extern NSString * const CGICalendarContentlineComponentVjournal;
extern NSString * const CGICalendarContentlineComponentVfreebusy;
extern NSString * const CGICalendarContentlineComponentVtimezone;

@interface CGICalendarContentLine : CGICalendarProperty

+ (BOOL)IsFoldingLineString:(NSString *)aString;
+ (id)contentLineWithString:(NSString *)aString;

- (id)initWithString:(NSString *)aString;
- (void)setString:(NSString *)aString;

- (NSString *)description;

- (BOOL)isBegin;
- (BOOL)isEnd;

@end
