/*
Copyright (C) 2014-2015, Silent Circle, LLC. All rights reserved.

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
#import "XMPPJID.h"

@class AppConstants;

#if DEBUG
  #define INCLUDE_QA_NET    1
  #define INCLUDE_TEST_NET  1
  #define INCLUDE_DEV_NET   1
#endif

// https://tickets.silentcircle.org/browse/WEB-1092
#define WEB_1092_BUG 1

// Whether or not to charge for and expire an account
#define SUPPORT_PURCHASE_ACCOUNT 1

// Whether or not to use ANALYTICS (for now)
#define USE_APP_ANALYTICS 0

// Do we want to annoy the user with SCimp state change messages ?
#define INJECT_STATUS_MESSAGES 0

// Do we enable SCDatabaseLogger (for in-app real-time debug logging & problem reporting)
#define ENABLE_DEBUG_LOGGING 0


@interface AppConstants : NSObject

+ (BOOL)isIPhone;      // if (AppConstants.isIPhone) ...
+ (BOOL)isIPhone5;     // if (AppConstants.isIPhone5) ...
+ (BOOL)isIPhone6;     // if (AppConstants.isIPhone6) ...
+ (BOOL)isIPhone6Plus; // if (AppConstants.isIPhone6Plus) ...
+ (BOOL)isIPad;        // if (AppConstants.isIPad) ...

+ (BOOL)isIOS7OrLater; // if (AppConstants.isIOS7OrLater) ...
+ (BOOL)isIOS8OrLater; // if (AppConstants.isIOS8OrLater) ...
+ (BOOL)isLessThanIOS8; //   (isIOS7OrLater && !isIOS8OrLater)

+ (BOOL)isApsEnvironmentDevelopment; // Entitlements: <key>aps-environment</key><string>development</string>

+ (XMPPJID *)stInfoJID;
+ (XMPPJID *)ocaVoicemailJID;

BOOL IsSTInfoJID(XMPPJID *jid);
BOOL IsSTInfoJidStr(NSString *jidStr);

BOOL IsOCAVoicemailJID(XMPPJID *jid);
BOOL IsOCAVoicemailJidStr(NSString *jidStr);

+ (NSString *)STInfoDisplayName;
+ (NSString *)OCAVoicemailDisplayName;

// @"name:[ {brokerSRV, brokerURL, displayName,  xmppDomain,  xmppSHA1[], webAPISHA1[]}, ..]
+ (NSDictionary *)SilentCircleNetworkInfo;

/**
 * Returns the set of all supported xmppDomains.
 * This comes from the SilentCircleNetworkInfo dictionary,
 * by populating a set from all values for @"xmppDomain" within the dictionary.
**/
+ (NSSet *)supportedXmppDomains;

/**
 * Returns the networkID for the given xmppDomain.
 * The networkID can be used as the key within the SilentCircleNetworkInfo dictionary,
 * in order to obtain other information about the particular network.
**/
+ (NSString *)networkIdForXmppDomain:(NSString *)xmppDomain;

/**
 * Convenience method to extract the xmppDomain from the SilentCircleNetworkInfo dictionary.
**/
+ (NSString *)xmppDomainForNetworkID:(NSString *)networkID;

BOOL IsProductionNetworkDomain(XMPPJID *jid);
+ (NSString *)networkDisplayNameForJID:(XMPPJID *)jid;

@end


enum {
  kShredAfterNever = 0,
};


extern NSString *const LocalUserActiveDeviceMayHaveChangedNotification;

extern NSString *const kNetworkID_Production;
extern NSString *const kNetworkID_QA;
extern NSString *const kNetworkID_Testing;
extern NSString *const kNetworkID_Development;
extern NSString *const kNetworkID_Fake;

extern NSString *const kSilentCircleSignupURL;

extern NSString *const kDefaultAccountDomain;
extern NSString *const kTestNetAccountDomain;
  
extern NSString *const kABPersonPhoneSilentPhoneLabel;
extern NSString *const kABPersonInstantMessageServiceSilentText;
extern NSString *const kSCErrorDomain;

extern NSString *const kSilentStorageS3Bucket;
extern NSString *const kSilentStorageS3Mime;

extern NSString *const kSilentContacts_Extension;

// keychain items
extern NSString *const kAPIKeyFormat;
extern NSString *const kDeviceKeyFormat;
extern NSString *const kStorageKeyFormat;
extern NSString *const kGUIDPassphraseFormat;
extern NSString *const kPassphraseMetaDataFormat;
 

// XMPP items

extern NSString *const kXMPPBody;
extern NSString *const kXMPPChat;
extern NSString *const kXMPPID;
extern NSString *const kXMPPThread;
extern NSString *const kXMPPNotifiable;
extern NSString *const kXMPPBadge;

extern NSString *const kSTInfoUsername_deprecated;
extern NSString *const kOCAVoicemailUsername_deprecated;

// SCLOUD Broker
extern NSString *const kSCBrokerSRVname;
  
// SCIMP items

extern NSString *const kSCNameSpace;
extern NSString *const kSCPublicKeyNameSpace;
extern NSString *const kSCTimestampNameSpace;

extern NSString *const kSCPPSiren;
extern NSString *const kSCPPPubSiren;
extern NSString *const kSCPPTimestamp;
extern NSString *const kSCPPBodyTextFormat;

extern NSString *const kStreamParamEntryNetworkID;

// Scloud items
extern NSString *const kSCKey_Locator;
extern NSString *const kSCKey_Key;

// YapDatabase collection constants
extern NSString *const kSCCollection_STUsers;
extern NSString *const kSCCollection_STScimpState;
extern NSString *const kSCCollection_STMessageIDCache;
extern NSString *const kSCCollection_STPublicKeys;
extern NSString *const kSCCollection_STSymmetricKeys;
extern NSString *const kSCCollection_STSCloud;
extern NSString *const kSCCollection_STImage_Message;
extern NSString *const kSCCollection_STSRVRecord;
extern NSString *const kSCCollection_STStreamManagement;
extern NSString *const kSCCollection_Prefs;
extern NSString *const kSCCollection_Upgrades;
extern NSString *const kSCCollection_STNotification;

// Mime Types
extern NSString *const  kMimeType_vCard;

// Transaction Extended Info
//
// For any readWrite transaction, you can specify "extended information" by placing
// a custom dictionary within the YapDatabaseModifiedNotification.
//
// We may do this to occasionally handle special case scenarios.
// For example, when a conversation is cleared, we don't want to do the burn animation(s).
//
// @see yapDatabaseModifiedNotificationCustomObject

extern NSString *const kTransactionExtendedInfo_ClearedConversationId;
extern NSString *const kTransactionExtendedInfo_ClearedMessageIds;

extern NSTimeInterval const kDefaultSRVRecordLifespan;
