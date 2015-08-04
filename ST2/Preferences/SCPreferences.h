/*
Copyright (C) 2015, Silent Circle, LLC. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Any redistribution, use, or modification is done solely for personal
      benefit and not for any commercial purpose or for monetary gain
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name Silent Circle nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL SILENT CIRCLE, LLC BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
#import <Foundation/Foundation.h>
#import "YapDatabase.h"


extern NSString *const PreferencesChangedNotification; // Posted to main thread
extern NSString *const PreferencesChangedKey;          // Key in notification.userInfo which gives changed key


@interface SCPreferences : NSObject

/**
 * Returns the default value, which is not necessarily the effective value.
**/
+ (id)defaultObjectForKey:(NSString *)key;

/**
 * Fetches the effective value for the given key.
 * This will either be a previously set value, or will fallback to the default value.
**/
+ (id)objectForKey:(NSString *)key;

/**
 * Allows you to change the value for the given key.
 * If the value doesn't effectively change, then nothing is written to disk.
**/
+ (void)setObject:(id)object forKey:(NSString *)key;

/**
 * This setter allows you to change a value within the atomic commit.
 * This is helpful for any situation in which you want the changed preference to hit at the same time as other changes.
 * 
 * You MUST use this method rather than setting the value directly yourself.
**/
+ (void)setObject:(id)object forKey:(NSString *)key withTransaction:(YapDatabaseReadWriteTransaction *)transaction;

@end
