//
//  CGICalendarObject.h
//
//  Created by Satoshi Konno on 11/01/27.
//  Copyright 2011 Satoshi Konno. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CGICalendarComponent.h"
#import "CGICalendarProperty.h"

extern NSString * const CGICalendarObjectVersionDefault;
extern NSString * const CGICalendarObjectProdidDefault;

@interface CGICalendarObject : CGICalendarComponent

+ (id)object;
+ (id)objectWithProdid:(NSString *)prodid;
+ (id)objectWithProdid:(NSString *)prodid version:(NSString *)version;

- (id)init;
- (id)initWithProdid:(NSString *)prodid;
- (id)initWithProdid:(NSString *)prodid version:(NSString *)version;

- (void)setVersion:(NSString *)version;
- (NSString *)version;

- (void)setProdid:(NSString *)prodid;
- (NSString *)prodid;

- (NSArray *)componentsWithType:(NSString *)type;
- (NSArray *)events;
- (NSArray *)todos;
- (NSArray *)journals;
- (NSArray *)freebusies;
- (NSArray *)timezones;

@end

