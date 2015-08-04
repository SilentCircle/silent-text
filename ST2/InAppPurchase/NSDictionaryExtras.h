//
//  NSDictionaryExtras.h
//
//  Created by Misha Melikov on 8/29/10.
//  Copyright 2010 Artizia. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (AZExtras)

- (BOOL)contains:(NSString *)key;
- (NSString *)safeStringForKey:(NSString *)key;
- (NSDate *)safeDateForKey:(NSString *)key format:(NSString *)format;
- (NSDate *)safeDateForKey:(NSString *)key format:(NSString *)format timezone:(NSString *)timezone;
- (NSNumber *)safeNumberForKey:(NSString *)key;
- (NSNumber *)safeNumberNoNILForKey:(NSString *)key;
- (BOOL)safeBoolForKey:(NSString *)key;
- (int)safeIntForKey:(NSString *)key;
- (double)safeDoubleForKey:(NSString *)key;
- (unsigned long)safeUnsignedLongForKey:(NSString *)key;

@end

