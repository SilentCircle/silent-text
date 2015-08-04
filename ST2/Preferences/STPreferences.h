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
#import <MapKit/MapKit.h>
#import <SCCrypto/SCcrypto.h>

#import "SCPreferences.h"
#import "XplatformUI.h"


extern NSString *const prefs_pushToken;
extern NSString *const prefs_lastGitHash;
extern NSString *const prefs_experimentalFeatures;

extern NSString *const prefs_selectedUserId;
extern NSString *const prefs_lastSelectedContactId;

extern NSString *const prefs_prefix_selectedConversationId;
extern NSString *const prefs_prefix_appThemeName;

extern NSString *const prefs_defaultBurnTime;
extern NSString *const prefs_defaultShouldBurn;
extern NSString *const prefs_defaultSendReceipts;

extern NSString *const prefs_soundVibrate;
extern NSString *const prefs_soundSentMessage;
extern NSString *const prefs_soundReceivedMessage;

extern NSString *const prefs_scimpCipherSuite;
extern NSString *const prefs_scimpSASmethod;

extern NSString *const prefs_notificationDate;
extern NSString *const prefs_showVerfiedMessageSigs;
extern NSString *const prefs_preferedMapType;






@interface STPreferences : SCPreferences

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Hard Coded
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// These are "preferences" that are NOT configureable in the database.
// That is, the values are decided upon by the engineering team, and set in code.

+ (OSColor *)navItemTintColor;

+ (NSTimeInterval)publicKeyLifespan;   // How long a key is valid for (before expiring) - 1 year
+ (NSTimeInterval)publicKeyRefresh;    // How long until we refresh our key             - 3 months

+ (NSTimeInterval)remoteUserWebRefreshInterval;
+ (NSTimeInterval)localUserWebRefreshInterval_normal;
+ (NSTimeInterval)localUserWebRefreshInterval_expired;

+ (NSUInteger)multicastKeysToKeep;     // How many additional group keys to keep around
+ (NSTimeInterval)multicastKeyLifespan;

+ (NSTimeInterval)scloudCacheLifespan;
+ (NSUInteger)initialScloudSegmentsToDownload;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Persistent - General
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString *)applicationPushToken;
+ (void)setApplicationPushToken:(NSString *)deviceToken;

+ (NSString *)lastGitHash;
+ (void)setLastGitHash:(NSString *)gitHash;

+ (BOOL)experimentalFeatures;
+ (void)setExperimentalFeatures:(BOOL)experimentalFeatures;

/**
 * We support multiple STLocalUser's.
 * This value represents which STLocalUser the user was last using.
**/
+ (NSString *)selectedUserId;
+ (void)setSelectedUserId:(NSString *)userId;

/**
 * Which user was last selected in ContactsViewController.
**/
+ (NSString *)lastSelectedContactUserId;
+ (void)setLastSelectedContactUserId:(NSString *)userId;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Persistent - Per Account
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Which conversation was last selected.
 * This is on a per-account basis.
**/
+ (NSString *)prefs_selectedConversationIdForUserId:(NSString *)userId;

+ (NSString *)selectedConversationIdForUserId:(NSString *)userId;
+ (void)setSelectedConversationId:(NSString *)conversationId forUserId:(NSString *)userId;

/**
 * The choosed AppTheme.
 * This is on a per-account basis.
**/
+ (NSString *)prefs_appThemeNameForAccount:(NSString *)localUserID;

+ (NSString *)appThemeNameForAccount:(NSString *)localUserID;
+ (void)setAppThemeName:(NSString *)name forAccount:(NSString *)localUserID;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Persistent - Conversation Defaults
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (BOOL)defaultShouldBurn;
+ (void)setDefaultShouldBurn:(BOOL)defaultShouldBurn;

+ (uint32_t)defaultBurnTime;
+ (void)setDefaultBurnTime:(uint32_t)seconds;

+ (BOOL)defaultSendReceipts;
+ (void)setDefaultSendReceipts:(BOOL)sendReceipts;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Persistent - Sounds
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (BOOL)soundVibrate;
+ (void)setSoundVibrate:(BOOL)soundVibrate;

+ (BOOL)soundInMessage;
+ (void)setSoundInMessage:(BOOL)soundInMessage;

+ (BOOL)soundSentMessage;
+ (void)setSoundSentMessage:(BOOL)soundSentMessage;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Persistent - Scimp
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (SCimpCipherSuite)scimpCipherSuite;
+ (void)setScimpCipherSuite:(SCimpCipherSuite)cipherSuite;

+ (SCKeySuite)scimpKeySuite; // extracted from cipherSuite

+ (SCimpSAS)scimpSASMethod;
+ (void)setScimpSASMethod:(SCimpCipherSuite)sasMethod;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Persistent - Uncategorized
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSDate *)notificationDate;
+ (void)setNotificationDate:(NSDate *)notificationDate;

+ (BOOL)showVerfiedMessageSigs;
+ (void)setShowVerfiedMessageSigs:(BOOL)showVerfiedMessageSigs;

+ (MKMapType)preferedMapType;
+ (void)setPreferedMapType:(MKMapType)mapType;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Transient - Pending Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString *)pendingTypedMessageForConversationId:(NSString *)conversationId;
+ (void)setPendingTypedMessage:(NSString *)msg forConversationId:(NSString *)conversationId;

+ (NSArray *)pendingRecipientNamesForConversationId:(NSString *)conversationId;
+ (void)setPendingRecipientNames:(NSArray *)names forConversationId:(NSString *)conversationId;

+ (NSArray *)pendingRecipientJidsForConversationId:(NSString *)conversationId;
+ (void)setPendingRecipientJids:(NSArray *)jids forConversationId:(NSString *)conversationId;

@end
