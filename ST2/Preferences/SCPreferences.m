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
#import "SCPreferences.h"
#import "DatabaseManager.h"
#import "AppConstants.h"
#import "STLogging.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif


NSString *const PreferencesChangedNotification = @"PreferencesChangedNotification";
NSString *const PreferencesChangedKey = @"key";

static dispatch_queue_t queue;
static YapDatabaseConnection *databaseConnection;

static NSMutableDictionary *databasePrefs;


@implementation SCPreferences

+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		initialized = YES;
		
		queue = dispatch_queue_create("SCPreferences", DISPATCH_QUEUE_SERIAL);
		
		databaseConnection = [STDatabaseManager.database newConnection];
		databaseConnection.objectCacheLimit = 20;
		databaseConnection.metadataCacheEnabled = NO;
		databaseConnection.name = @"SCPreferences";
		
		if (databaseConnection == nil)
		{
			NSString *reason =
			@"SCPreferences is being called before the database has been started!"
			@" SCPreferences depends upon the database, so you must ensure the startup flow sets up the database"
			@" before anything attempts to use it.";
			
			@throw [NSException exceptionWithName:@"SCPreferences" reason:reason userInfo:nil];
		}
		
		dispatch_async(queue, ^{ @autoreleasepool {
			
			[self populatePrefsDictionary];
		}});
	
		// Todo: Add hook & inspection so we can recover if user disobeys documentation,
		// and directly modifies the database themselves.
	//	[[NSNotificationCenter defaultCenter] addObserver:self
	//	                                         selector:@selector(databaseModified:)
	//	                                             name:YapDatabaseModifiedNotification
	//	                                           object:STDatabaseManager.database];
	}
}

+ (void)populatePrefsDictionary
{
	if (databasePrefs == nil) {
		databasePrefs = [[NSMutableDictionary alloc] init];
	}
	
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		[transaction enumerateKeysAndObjectsInCollection:kSCCollection_Prefs
		                                      usingBlock:^(NSString *key, id object, BOOL *stop)
		{
			if (object) {
				[databasePrefs setObject:object forKey:key];
			}
		}];
	}];
}

+ (void)postChangeNotification:(NSString *)prefKey
{
	// We MUST post these notifications to the main thread.
	
	dispatch_block_t block = ^{
		
		[[NSNotificationCenter defaultCenter] postNotificationName:PreferencesChangedNotification
		                                                    object:nil
		                                                  userInfo:@{ PreferencesChangedKey:prefKey }];
	};
	
	if ([NSThread isMainThread])
		block();
	else
		dispatch_async(dispatch_get_main_queue(), block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Subclass Template
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSDictionary *)defaults
{
	// Override me in subclass
	return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Getter & Setter Logic
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the default value, which is not necessarily the effective value.
**/
+ (id)defaultObjectForKey:(NSString *)key
{
	return [[self defaults] objectForKey:key];
}

/**
 * Fetches the effective value for the given key.
 * This will either be a previously set value, or will fallback to the default value.
**/
+ (id)objectForKey:(NSString *)key
{
	if (key == nil) return nil;
	
	__block id result = nil;
	
	dispatch_sync(queue, ^{
		result = [databasePrefs objectForKey:key];
	});
	
	if (result == nil) {
		result = [[self defaults] objectForKey:key];
	}
	
	return result;
}

/**
 * Allows you to change the value for the given key.
 * If the value doesn't effectively change, then nothing is written to disk.
**/
+ (void)setObject:(id)object forKey:(NSString *)inKey
{
	if (inKey == nil) {
		DDLogError(@"%@ - Ignoring nil key !", THIS_METHOD);
		return;
	}
	
	NSString *key = [inKey copy]; // mutable string protection
	
	dispatch_async(queue, ^{ @autoreleasepool {
		
		id prevDatabaseObject = [databasePrefs objectForKey:key];
		id defaultObject = [[self defaults] objectForKey:key];
		
		id prevObject = prevDatabaseObject ?: defaultObject;
		
		if (![prevObject isEqual:object])
		{
			if (object == nil)
			{
				// Todo: We need to figure out what 'nil' means if there is a defaultObject.
				//
				// Does 'nil' mean we intend to override the defaultObject with nil?
				// Or does 'nil' mean we intend to fallback to the defaultObject (removing the prevObject only)?
				//
				// Currently we're doing the latter.
				
				[databasePrefs removeObjectForKey:key];
				[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
					
					[transaction removeObjectForKey:key inCollection:kSCCollection_Prefs];
				}];
			}
			else if (defaultObject && [defaultObject isEqual:object])
			{
				[databasePrefs removeObjectForKey:key];
				[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
					
					[transaction removeObjectForKey:key inCollection:kSCCollection_Prefs];
				}];
			}
			else
			{
				[databasePrefs setObject:object forKey:key];
				[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
					
					[transaction setObject:object forKey:key inCollection:kSCCollection_Prefs];
				}];
			}
			
			[self postChangeNotification:key];
		}
	}});
}

/**
 * This setter allows you to change a value within the atomic commit.
 * This is helpful for any situation in which you want the changed preference to hit at the same time as other changes.
 * 
 * You MUST use this method rather than setting the value directly yourself.
**/
+ (void)setObject:(id)object forKey:(NSString *)inKey withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	if (inKey == nil) {
		DDLogError(@"%@ - Ignoring nil key !", THIS_METHOD);
		return;
	}
	
	NSString *key = [inKey copy]; // mutable string protection
	
	// Important: This must be a synchronous operation
	dispatch_sync(queue, ^{ @autoreleasepool {
		
		id prevDatabaseObject = [databasePrefs objectForKey:key];
		id defaultObject = [[self defaults] objectForKey:key];
		
		id prevObject = prevDatabaseObject ?: defaultObject;
		
		if (![prevObject isEqual:object])
		{
			if (defaultObject && [defaultObject isEqual:object])
			{
				[databasePrefs removeObjectForKey:key];
				[transaction removeObjectForKey:key inCollection:kSCCollection_Prefs];
			}
			else
			{
				[databasePrefs setObject:object forKey:key];
				[transaction setObject:object forKey:key inCollection:kSCCollection_Prefs];
			}
			
			[self postChangeNotification:key];
		}
	}});
}

@end
