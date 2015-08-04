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
#import "STPreferences.h"
#import "STLogging.h"
#import "AppDelegate.h"
#import "AppConstants.h"


NSString *const prefs_pushToken                     = @"pushToken";
NSString* const prefs_lastGitHash                   = @"key_lastGitHash";
NSString *const prefs_experimentalFeatures          = @"experimental_Features";

NSString *const prefs_selectedUserId                = @"selectedUserId";
NSString *const prefs_lastSelectedContactId         = @"lastSelectedContactId";

NSString *const prefs_prefix_selectedConversationId = @"selectedConversationId";
NSString *const prefs_prefix_appThemeName           = @"appThemeName";

NSString *const prefs_defaultBurnTime               = @"defaultBurnTime";
NSString *const prefs_defaultShouldBurn             = @"defaultShouldBurn";
NSString *const prefs_defaultSendReceipts           = @"sendReceipts";

NSString *const prefs_soundVibrate                  = @"sound_vibrate";
NSString *const prefs_soundInMessage                = @"sound_inMessage";
NSString *const prefs_soundSentMessage              = @"sound_sentMessage";

NSString *const prefs_scimpCipherSuite              = @"scimpCipherSuite";
NSString *const prefs_scimpSASmethod                = @"scimpSASmethod";

NSString *const prefs_showVerfiedMessageSigs        = @"showVerfiedMessageSigs";
NSString *const prefs_notificationDate              = @"notificationDate";
NSString *const prefs_preferedMapType               = @"preferedMapType";



@implementation STPreferences

static NSMutableDictionary *pendingTypedMessages;
static NSMutableDictionary *pendingRecipientNames;
static NSMutableDictionary *pendingRecipientJids;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Subclass Template
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSDictionary *)defaults
{
	return @{
		
	#if DEBUG
		prefs_experimentalFeatures   : @(YES),
	#else
		prefs_experimentalFeatures   : @(NO),
	#endif
		
		prefs_defaultBurnTime        : @(3600 * 6), // 6 hours
		prefs_defaultShouldBurn      : @(NO),
		prefs_defaultSendReceipts    : @(YES),
		
		prefs_soundVibrate           : @(YES),
		prefs_soundInMessage         : @(YES),
		prefs_soundSentMessage       : @(YES),
		
		prefs_scimpCipherSuite       : @(kSCimpCipherSuite_SKEIN_AES256_ECC414), // non NIST
		prefs_scimpSASmethod         : @(kSCimpSAS_PGP),
		
		prefs_notificationDate       : [NSDate distantPast],
		prefs_showVerfiedMessageSigs : @(NO),
		prefs_preferedMapType        : @(MKMapTypeStandard),
	};
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Hard Coded
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (OSColor *)navItemTintColor
{
	return [OSColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
}

+ (NSTimeInterval)publicKeyLifespan
{
	return (NSTimeInterval)((60 * 60 * 24) * 365); // one year
}

+ (NSTimeInterval)publicKeyRefresh
{
	return (NSTimeInterval)((60 * 60 * 24) * 90); // 3 months
}

+ (NSTimeInterval)remoteUserWebRefreshInterval
{
	return (NSTimeInterval)((60 * 60 * 24) * 14); // 14 days
}

+ (NSTimeInterval)localUserWebRefreshInterval_normal
{
	return (NSTimeInterval)(60 * 60 * 24); // 24 hours
}

+ (NSTimeInterval)localUserWebRefreshInterval_expired
{
	return (NSTimeInterval)(60 * 60 * 1); // 1 hour
}

+ (NSUInteger)multicastKeysToKeep
{
	return 3;
}

+ (NSTimeInterval)multicastKeyLifespan
{
	return (NSTimeInterval)((3600 * 24) * 20); // 20 days
}

+ (NSTimeInterval)scloudCacheLifespan
{
	return (NSTimeInterval)((3600 * 24) * 30); // 30 days
}

+ (NSUInteger)initialScloudSegmentsToDownload
{
	return 5;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Persistent - General
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString *)applicationPushToken
{
	return [self objectForKey:prefs_pushToken];
}

+ (void)setApplicationPushToken:(NSString *)deviceToken
{
	[self setObject:deviceToken forKey:prefs_pushToken];
}

+ (NSString *)lastGitHash
{
	return [self objectForKey:prefs_lastGitHash];
}

+ (void)setLastGitHash:(NSString *)gitHash
{
	[self setObject:gitHash forKey:prefs_lastGitHash];
}

+ (BOOL)experimentalFeatures
{
	return [[self objectForKey:prefs_experimentalFeatures] boolValue];
}

+ (void)setExperimentalFeatures:(BOOL)experimentalFeatures
{
	[self setObject:@(experimentalFeatures) forKey:prefs_experimentalFeatures];
}

+ (NSString *)selectedUserId
{
	return [self objectForKey:prefs_selectedUserId];
}

+ (void)setSelectedUserId:(NSString *)userId
{
	[self setObject:userId forKey:prefs_selectedUserId];
}

+ (NSString *)lastSelectedContactUserId
{
	return [self objectForKey:prefs_lastSelectedContactId];
}

+ (void)setLastSelectedContactUserId:(NSString *)userId
{
	[self setObject:userId forKey:prefs_lastSelectedContactId];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Persistent - Per Account
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString *)prefs_selectedConversationIdForUserId:(NSString *)userId
{
	return [NSString stringWithFormat:@"%@-%@", prefs_prefix_selectedConversationId, userId];
}

+ (NSString *)selectedConversationIdForUserId:(NSString *)userId
{
	return [self objectForKey:[self prefs_selectedConversationIdForUserId:userId]];
}

+ (void)setSelectedConversationId:(NSString *)conversationId forUserId:(NSString *)userId
{
	[self setObject:conversationId forKey:[self prefs_selectedConversationIdForUserId:userId]];
}

+ (NSString *)prefs_appThemeNameForAccount:(NSString *)localUserID
{
	return [NSString stringWithFormat:@"%@-%@", prefs_prefix_appThemeName, localUserID];
}

+ (NSString *)appThemeNameForAccount:(NSString *)localUserID
{
	NSString *result = [self objectForKey:[self prefs_appThemeNameForAccount:localUserID]];
	
	if (result)
		return result;
	else
		return @"0";
}

+ (void)setAppThemeName:(NSString *)name forAccount:(NSString *)localUserID
{
	[self setObject:name forKey:[self prefs_appThemeNameForAccount:localUserID]];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Persistent - Conversation Defaults
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (uint32_t)defaultBurnTime
{
	return [[self objectForKey:prefs_defaultBurnTime] unsignedIntValue];
}

+ (void)setDefaultBurnTime:(uint32_t)seconds
{
	[self setObject:@(seconds) forKey:prefs_defaultBurnTime];
}

+ (BOOL)defaultShouldBurn
{
	return [[self objectForKey:prefs_defaultShouldBurn] boolValue];
}

+ (void)setDefaultShouldBurn:(BOOL)defaultShouldBurn
{
	[self setObject:@(defaultShouldBurn) forKey:prefs_defaultShouldBurn];
}

+ (BOOL)defaultSendReceipts
{
	return [[self objectForKey:prefs_defaultSendReceipts] boolValue];
}

+ (void)setDefaultSendReceipts:(BOOL)sendReceipts
{
	[self setObject:@(sendReceipts) forKey:prefs_defaultSendReceipts];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Persistent - Sounds
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (BOOL)soundVibrate
{
	return [[self objectForKey:prefs_soundVibrate] boolValue];
}

+ (void)setSoundVibrate:(BOOL)soundVibrate
{
	[self setObject:@(soundVibrate) forKey:prefs_soundVibrate];
}

+ (BOOL)soundInMessage
{
	return [[self objectForKey:prefs_soundInMessage] boolValue];
}

+ (void)setSoundInMessage:(BOOL)soundInMessage
{
	[self setObject:@(soundInMessage) forKey:prefs_soundInMessage];
}

+ (BOOL)soundSentMessage
{
	return [[self objectForKey:prefs_soundSentMessage] boolValue];
}

+ (void)setSoundSentMessage:(BOOL)soundSentMessage
{
	[self setObject:@(soundSentMessage) forKey:prefs_soundSentMessage];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Persistent - Scimp
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (SCimpCipherSuite)scimpCipherSuite
{
	return (SCimpCipherSuite)[[self objectForKey:prefs_scimpCipherSuite] intValue];
}

+ (void)setScimpCipherSuite:(SCimpCipherSuite)cipherSuite
{
	[self setObject:@(cipherSuite) forKey:prefs_scimpCipherSuite];
}

+ (SCKeySuite)scimpKeySuite
{
	SCimpCipherSuite scimpSuite = [self scimpCipherSuite];

	SCKeySuite keySuite = kSCKeySuite_Invalid;
	switch(scimpSuite)
	{
		case kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384    :
		case kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384 :
		case kSCimpCipherSuite_SKEIN_AES256_ECC384          :
		{
		    keySuite = kSCKeySuite_ECC384;
		    break;
		}
		case kSCimpCipherSuite_SKEIN_AES256_ECC414 :
		{
			keySuite = kSCKeySuite_ECC414;
		    break;
		}
		default:
		{
			keySuite = kSCKeySuite_Invalid;
		}
	}
	
	return keySuite;
}

+ (SCimpSAS)scimpSASMethod
{
	return (SCimpSAS)[[self objectForKey:prefs_scimpSASmethod] intValue];
}

+ (void)setScimpSASMethod: (SCimpCipherSuite)sasMethod
{
	[self setObject:@(sasMethod) forKey:prefs_scimpSASmethod];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Persistent - Uncategorized
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSDate *)notificationDate
{
	return [self objectForKey:prefs_notificationDate];
}

+ (void)setNotificationDate:(NSDate *)date
{
	[self setObject:date forKey:prefs_notificationDate];
}

+ (BOOL)showVerfiedMessageSigs
{
	return [[self objectForKey:prefs_showVerfiedMessageSigs] boolValue];
}

+ (void)setShowVerfiedMessageSigs:(BOOL)showVerfiedMessageSigs
{
	[self setObject:@(showVerfiedMessageSigs) forKey:prefs_showVerfiedMessageSigs];
}

+ (MKMapType)preferedMapType
{
	return [[self objectForKey:prefs_preferedMapType] unsignedIntegerValue];
}

+ (void)setPreferedMapType:(MKMapType)mapType
{
	[self setObject:@(mapType) forKey:prefs_preferedMapType];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Transient - Pending Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString *)pendingTypedMessageForConversationId:(NSString *)conversationId
{
	NSAssert([NSThread isMainThread], @"Not thread-safe");
	
	return [pendingTypedMessages objectForKey:conversationId];
}

+ (void)setPendingTypedMessage:(NSString *)msg forConversationId:(NSString *)conversationId
{
	NSAssert([NSThread isMainThread], @"Not thread-safe");
	
	if (conversationId == nil)
		return;
	
	if ([msg length] > 0)
	{
		if (pendingTypedMessages == nil)
			pendingTypedMessages = [[NSMutableDictionary alloc] init];
		
		[pendingTypedMessages setObject:msg forKey:conversationId];
	}
	else
	{
		[pendingTypedMessages removeObjectForKey:conversationId];
	}
}


+ (NSArray *)pendingRecipientNamesForConversationId:(NSString *)conversationId
{
	NSAssert([NSThread isMainThread], @"Not thread-safe");
	
	return [pendingRecipientNames objectForKey:conversationId];
}

+ (void)setPendingRecipientNames:(NSArray *)names forConversationId:(NSString *)conversationId
{
	NSAssert([NSThread isMainThread], @"Not thread-safe");
	
	if (conversationId == nil)
		return;
	
	if ([names count] > 0)
	{
		if (pendingRecipientNames == nil)
			pendingRecipientNames = [[NSMutableDictionary alloc] init];
		
		[pendingRecipientNames setObject:names forKey:conversationId];
	}
	else
	{
		[pendingRecipientNames removeObjectForKey:conversationId];
	}
}

+ (NSArray *)pendingRecipientJidsForConversationId:(NSString *)conversationId
{
	NSAssert([NSThread isMainThread], @"Not thread-safe");
	
	return [pendingRecipientJids objectForKey:conversationId];
}

+ (void)setPendingRecipientJids:(NSArray *)jids forConversationId:(NSString *)conversationId
{
	NSAssert([NSThread isMainThread], @"Not thread-safe");
	
	if (conversationId == nil)
		return;
	
	if ([jids count] > 0)
	{
		if (pendingRecipientJids == nil)
			pendingRecipientJids = [[NSMutableDictionary alloc] init];
		
		[pendingRecipientJids setObject:jids forKey:conversationId];
	}
	else
	{
		[pendingRecipientJids removeObjectForKey:conversationId];
	}
}

@end
