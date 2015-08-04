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
#import "XMPPJID.h"

@class STUser;
@class STLocalUser;
@class STPublicKey;

/**
 * Keys defined for NSDictionary returned by parseLocalUserInfoResult & parseUserInfoResult methods.
**/
extern NSString *const kUserInfoKey_hash;                   // NSString
extern NSString *const kUserInfoKey_avatarUrl;              // NSString
extern NSString *const kUserInfoKey_hasPhone;               // NSNumber (BOOL)
extern NSString *const kUserInfoKey_hasOCA;                 // NSNumber (BOOL)
extern NSString *const kUserInfoKey_canSendMedia;           // NSNumber (BOOL)
extern NSString *const kUserInfoKey_pubKeys;                // NSArray
extern NSString *const kUserInfoKey_firstName;              // NSString
extern NSString *const kUserInfoKey_lastName;               // NSString
extern NSString *const kUserInfoKey_displayName;            // NSString
extern NSString *const kUserInfoKey_email;                  // NSString
extern NSString *const kUserInfoKey_organization;           // NSString
extern NSString *const kUserInfoKey_activeDeviceID;         // NSString
extern NSString *const kUserInfoKey_spNumbers;              // NSArray
extern NSString *const kUserInfoKey_subscriptionExpireDate; // NSDate
extern NSString *const kUserInfoKey_subscriptionAutoRenews; // NSNumber (BOOL)
extern NSString *const kUserInfoKey_handlesOwnBilling;      // NSNumber (BOOL)


@interface SCWebAPIManager : NSObject

+ (SCWebAPIManager *)sharedInstance;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Account Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*  
    createAccountFor someUser / somePassword  / Some / User / foo@bar.com
    returns the following dict..   the user needs to pay for the account before provisioning
 
    the expires in the distant past means subscription has expired and it will delete soon.
 
     {
     "display_name" = "Some User";
     "first_name" = Some;
     "force_password_change" = 0;
     keys =     (
     );
     "last_name" = User;
     permissions =     {
     "can_send_media" = 1;
     "has_oca" = 0;
     "silent_desktop" = 0;
     "silent_phone" = 0;
     "silent_text" = 0;
     };
     "silent_phone" = 1;
     "silent_text" = 1;
     subscription =     {
     expires = "1900-01-01T00:00:00Z";
     };
     }
 */
-(void) createAccountFor:(NSString *)userName
            withPassword:(NSString *)password
               networkID:(NSString *)networkID
               firstName:(NSString *)firstName   // optional
                lastName:(NSString *)lastName    // optional
                   email:(NSString *)email       // optional
         completionBlock:(void (^)(NSError *error, NSDictionary* infoDict))completion;

/**
 * This method does ?
 * This method returns ?
**/
- (void)provisionCodeFor:(NSString *)userName
            withPassword:(NSString *)password
               networkID:(NSString *)networkID
         completionBlock:(void (^)(NSError *error, NSDictionary* infoDict))completion;

/**
 * Performs a PUT to /v1/me/device/[deviceID]/.
 * 
 * Passes an activationCode as credentials.
 * This essentially registers the given deviceID (if needed),
 * and allows the server to setup the proper database entries for the deviceID.
 *
 * The server returns an API key which is tied to the username/deviceID combo.
 * 
 * @param deviceName
 *   User supplied field (e.g. "My iPhone 6")
 * 
 * @param deviceID
 *   The deviceID MUST be the same as the JID.resource to be used for this account.
 *   The deviceID should NOT change (for this user on this device),
 *   unless the user logs out and we delete scimp context items from persistent storage.
 * 
 * @param networkID
 *   One of the constants from AppConstants.h (e.g. kNetworkID_Production)
**/
- (void)provisionWithCode:(NSString *)activationCode
			   deviceName:(NSString *)deviceName
				 deviceID:(NSString *)deviceID
				networkID:(NSString *)networkID
		  completionBlock:(void (^)(NSError *error, NSDictionary* infoDict))completion;

/**
 * Performs a PUT to /v1/me/device/[deviceID]/.
 *
 * Passes the username & password as credentials.
 * This essentially registers the given deviceID (if needed),
 * and allows the server to setup the proper database entries for the deviceID.
 *
 * The server returns an API key which is tied to the username/deviceID combo.
 * 
 * @param deviceName
 *   User supplied field (e.g. "My iPhone 6")
 * 
 * @param deviceID
 *   The deviceID MUST be the same as the JID.resource to be used for this account.
 *   The deviceID should NOT change (for this user on this device),
 *   unless the user logs out and we delete scimp context items from persistent storage.
 * 
 * @param networkID
 *   One of the constants from AppConstants.h (e.g. kNetworkID_Production)
**/
- (void)provisionWithUsername:(NSString *)username
		             password:(NSString *)password
                   deviceName:(NSString *)deviceName
                     deviceID:(NSString *)deviceID
                    networkID:(NSString *)networkID
              completionBlock:(void (^)(NSError *error, NSDictionary* infoDict))completion;

/**
 * Performs a DELETE to /v1/me/device/[deviceID]/?api_key=[apiKey]
 *
 * - unregisters the deviceID
 * - de-activates the apiKey
 * - deletes the associated pushToken
**/
- (void)deprovisionLocalUser:(STLocalUser *)localUser
             completionBlock:(void (^)(NSError *error, NSDictionary* infoDict))completion;

/**
 * Performs a PUT to /v1/me/device/<deviceID>/active?api_key=<key>
 * 
 * This makes the given deviceID the active_st_device.
**/
- (void)markActiveDeviceID:(NSString *)deviceID
                    apiKey:(NSString *)apiKey
                 networkID:(NSString *)networkID
           completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion;

/**
 * Performs a GET to /v1/me/device/<deviceID>/?api_key=<key>
 * 
 *
**/
- (void)getConfigForDeviceID:(NSString *)deviceID
                      apiKey:(NSString *)apiKey
                   networkID:(NSString *)networkID
             completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public Keys
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)uploadPublicKeyWithLocator:(NSString *)locator
                   publicKeyString:(NSString *)keyString
                      forLocalUser:(STLocalUser *)localUser
                   completionBlock:(void (^)(NSError *error, NSDictionary* infoDict))completion;


- (void)removePublicKeyWithLocator:(NSString *)locator
                      forLocalUser:(STLocalUser *)localUser
                   completionBlock:(void (^)(NSError *error, NSDictionary* infoDict))completion;

- (void)getKeyWithLocator:(NSString *)locator
             forLocalUser:(STLocalUser *)localUser
          completionBlock:(void (^)(NSError *error, NSDictionary* infoDict))completion;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark User Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Fetches info specific for a localUser (such as subscription information).
 * 
 * @param localUser
 *   The localUser with which to fetch info about from the server.
 * 
 * @param completion
 *   Will be invoked when the HTTP request completes.
 *   The corresponding jsonDict is raw JSON.
 *   You should use the parseLocalUserInfoResult method to perform standard parsing on the raw JSON dict.
 * 
 * @see parseLocalUserInfoResult
**/
- (void)getLocalUserInfo:(STLocalUser *)localUser
         completionBlock:(void (^)(NSError *error, NSDictionary *jsonDict))completion;

/**
 * Standard parsing of the JSON response from getLocalUserInfo:completion:
 * Use me, instead of copy-n-pasting code.
 *
 * The returned dictionary has the following defined keys:
 *
 * - kUserInfoKey_avatarUrl               => NSString
 * - kUserInfoKey_hasPhone                => NSNumber (BOOL)
 * - kUserInfoKey_hasOCA                  => NSNumber (BOOL)
 * - kUserInfoKey_canSendMedia            => NSNumber (BOOL)
 * - kUserInfoKey_firstName               => NSString
 * - kUserInfoKey_lastName                => NSString
 * - kUserInfoKey_displayName             => NSString
 * - kUserInfoKey_email                   => NSString
 * - kUserInfoKey_spNumbers               => NSArray
 * - kUserInfoKey_subscriptionExpireDate  => NSDate
 * - kUserInfoKey_subscriptionAutoRenews  => NSNumber (BOOL)
 * - kUserInfoKey_handlesOwnBilling       => NSNumber (BOOL)
**/
- (NSDictionary *)parseLocalUserInfoResult:(NSDictionary *)jsonDict;

/**
 * Fetches info about the given JID, which may be for either a localUser or remoteUser.
 * 
 * @param remoteJID
 *   The user to fetch info about.
 * 
 * @param localUser
 *   A localUser that is typically associated with the remoteJID.
 *   The localUser parameter is needed for its networkID & apiKey.
 * 
 * @param completion
 *   Will be invoked when the HTTP request completes.
 *   The corresponding infoDict is raw JSON.
 *   You should use the parseUserInfoResult method to perform standard parsing on the raw JSON dict.
 * 
 * @see parseUserInfoResult
**/
- (void)getUserInfo:(XMPPJID *)remoteJID
       forLocalUser:(STLocalUser *)localUser
    completionBlock:(void (^)(NSError *error, NSDictionary *jsonDict))completion;

/**
 * Standard parsing of the JSON response from getUserInfo:::
 * Use me, instead of copy-n-pasting code.
 * 
 * The returned dictionary has the following defined keys:
 *
 * - kUserInfoKey_hash          => NSString
 * - kUserInfoKey_avatarUrl     => NSString
 * - kUserInfoKey_hasPhone      => NSNumber (BOOL)
 * - kUserInfoKey_hasOCA        => NSNumber (BOOL)
 * - kUserInfoKey_canSendMedia  => NSNumber (BOOL)
 * - kUserInfoKey_pubKeys       => NSArray
 * - kUserInfoKey_firstName     => NSString
 * - kUserInfoKey_lastName      => NSString
 * - kUserInfoKey_displayName   => NSString
**/
- (NSDictionary *)parseUserInfoResult:(NSDictionary *)jsonDict;

/**
 * Used to download raw data (non JSON result).
 * For example, this method is used to download a user avatar (given the avatarURL).
**/
- (void)getDataForNetworkID:(NSString *)networkID
                  urlString:(NSString *)relativeUrlPath
       completionBlock:(void (^)(NSError *error, NSData *data))completion;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Updating LocalUser Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Documentation needed...
**/
- (void)updateInfoForLocalUser:(STLocalUser *)localUser
               completionBlock:(void (^)(NSError *error, NSDictionary* infoDict))completion;

/**
 * Documentation needed...
**/
- (void)uploadAvatarForLocalUser:(STLocalUser *)localUser
                           image:(UIImage *)image
                 completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Push Tokens
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)registerApplicationPushToken:(NSString *)pushToken
                        forLocalUser:(STLocalUser *)localUser
                        useDebugCert:(BOOL)useDebugCert
                     completionBlock:(void (^)(NSError *error, NSDictionary* infoDict))completion;

- (void)unregisterApplicationPushTokenForLocalUser:(STLocalUser *)localUser
                                   completionBlock:(void (^)(NSError *error, NSDictionary* infoDict))completion;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Reporting Problems
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)postFeedbackForLocalUser:(STLocalUser *)localUser
                  withReportInfo:(NSDictionary *)reportInfo
                 completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Unknown
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Documentation needed...
**/
- (void)brokerUploadRequestForLocalUser:(STLocalUser *)localUser
                                reqDict:(NSDictionary*)reqDict
                        completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completionBlock;

/**
 * Documentation needed...
**/
- (void)setBlacklist:(NSDictionary *)blackList
        forLocalUser:(STLocalUser *)localUser
     completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark In-App Purchases
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//-(void) loadProductsForUser:(STUser *)user
//			completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion;

- (void)recordPaymentReceipt:(NSString *)receiptS
                     forUser:(STUser *)user
             completionBlock:(void (^)(NSError *error, NSDictionary *infoDict))completion;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - SC Directory
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)searchUsers:(NSString *)searchS
	   forLocalUser:(STLocalUser *)localUser limit:(int)limit
	completionBlock:(void (^)(NSError *error, NSArray *peopleList))completion;

@end
