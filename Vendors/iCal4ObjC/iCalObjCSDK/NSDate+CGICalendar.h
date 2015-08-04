//
//  NSDate+CGICalendar.h
//
//  Created by Satoshi Konno on 5/12/11.
//  Copyright 2011 Satoshi Konno. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (CGICalendar)

+ (id)dateWithICalendarString:(NSString *)aString;
+ (id)dateWithICalendarISO8601:(NSString *)aString;
- (NSString *)descriptionICalendar;
- (NSString *)descriptionISO8601;

@end
