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
#import <StoreKit/StoreKit.h>

#import "YapDatabase.h"
#import "XMPPJID.h"

@class UserManager;
@class STUser;
@class STLocalUser;

typedef void (^STUserManagerCompletionBlock)(NSError *error, NSString *uuid);

typedef void (^STUserManagerImportCompletionBlock)(NSError *error, NSArray *uuids);


@interface STUserManager : NSObject

/**
 * Standard singleton pattern.
**/
+ (instancetype)sharedInstance;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Activation & Deactivation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is used to login an existing user.
 * The parameters should come from the UI fields presented to the user.
 * 
 * If they're re-activating an existing user, the existing deviceID will automatically be reused.
**/
- (void)activateUserName:(NSString *)userName
            withPassword:(NSString *)password
              deviceName:(NSString *)deviceName
               networkID:(NSString *)networkID
         completionBlock:(STUserManagerCompletionBlock)completion;

/**
 * Description needed
**/
- (void)activateDevice:(NSString *)deviceID
                apiKey:(NSString *)apiKey
             networkID:(NSString *)networkID
       completionBlock:(STUserManagerCompletionBlock)completion;

/**
 * Deactivates the user account (by clearing the xmppPassword & apiKey).
 * 
 * If needsDeprovision is YES, then configures it so the DatabaseActionManager will handle:
 * - deprovisiong the device
 * - unregistering the push token
**/
- (void)deactivateUser:(NSString *)userID andDeprovision:(BOOL)needsDeprovision completionBlock:(dispatch_block_t)block;

/**
 * Description needed
**/
- (void)createAccountFor:(NSString *)userName
            withPassword:(NSString *)password
               networkID:(NSString *)networkID
              deviceName:(NSString *)deviceName
               firstName:(NSString *)firstName   // optional
                lastName:(NSString *)lastName    // optional
                   email:(NSString *)email       // optional
         completionBlock:(STUserManagerCompletionBlock)completion;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark User Creation & Updates
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method adds the given user to the database,
 * and performs all the usual actions associated with this action.
 *
 * If the user already exists in the database (another user already has same uuid or jid),
 * then this method will update the user similar to the updateUser::: method.
 * 
 * @param newUser
 *   The user to add to the database.
 *   This must be a NEW user. As in there must not be an existing user in the database with the same uuid or jid.
 * 
 * @param pubKeysArray (optional)
 *   Downloaded public keys from the WebAPI manager.
 *   If non-nil, the proper key will be added to the database, and the user will be updated as appropriate.
 * 
 * @param completionBlock (optional)
 *   Called with the uuid of the added user upon completion of the readWrite transaction.
 *   If the given user had a nil uuid, one was created and added automatically, and this uuid is passed back.
 *   If the user already exists in the database (another user already has same uuid or jid),
 *   then the user is NOT added, and the completionBlock will be called with the userID of the existing user.
 *   The completionBlock will be called on the main thread.
**/
- (void)addNewUser:(STUser *)newUser
       withPubKeys:(NSArray *)pubKeysArray
   completionBlock:(void (^)(NSString *userID))completionBlock;


/**
 * This method updates the given user in the database using the changedProperties of the given user.
 *
 * That is, this method will check user.changedProperties, enumerate those values,
 * and update the user in the database with those updated values.
 * 
 * This method also handles performing other actions, such as downloading the avatar if needed.
 * 
 * If the user doesn't exist in the database,
 * then it will NOT be added, and the completionBlock will be called with a nil userID.
 *
 * @param user
 *   The user to update in the database.
 *   This method updates the existing user with any values from user.changedProperties.
 * 
 * @param pubKeysArray (optional)
 *   Downloaded public keys from the WebAPI manager.
 *   If non-nil, the proper key will be added to the database, and the user will be updated as appropriate.
 *   This is ignored if the user is a local user.
 * 
 * @param completionBlock (optional)
 *   Called with the uuid of the updated user upon completion of the readWrite transaction.
 *   If the user doesn't exist in the database, then the completionBlock will be called with a nil userID.
 *   The completionBlock will be called on the main thread.
**/
- (void)updateUser:(STUser *)user
       withPubKeys:(NSArray *)pubKeysArray
   completionBlock:(void (^)(NSString *userID))completionBlock;

/**
 * Description needed...
**/
- (void)addLocalUserToDB:(XMPPJID *)jid
               networkID:(NSString *)networkID
            xmppPassword:(NSString *)xmppPassword
                  apiKey:(NSString *)apiKey
                deviceID:(NSString *)deviceID
            canSendMedia:(BOOL)canSendMedia
                  enable:(BOOL)enable
	     completionBlock:(void (^)(NSString *uuid))completionBlock;

/**
 * This method fires off a requet to the web API to fetch info for the given JID.
 * 
 * If the web fetch succeeds,
 * then it automatically creates the user in the database before invoking the completionBlock.
**/
- (void)createUserIfValidJID:(XMPPJID *)jid
             completionBlock:(void (^)(NSError *error, NSString *userID))completionBlock;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Public & Private Keys
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Creates a new public key, and assigns it to the specified STLocalUser.
 * 
 * Once the database has been properly updated, the completionBlock is invoked.
 * The newKeyID specified the locator/uuid of the new STPublicKey object in the database.
 * If the userID is invalid (user doesn't exist, or isn't a local user) then newKeyID will be nil.
 * 
 * Note: The DatabaseActionHandler automatically handles uploading the new key.
**/
- (void)createPrivateKeyForUserID:(NSString *)userID
                  completionBlock:(void (^)(NSString *newKeyID))completion;

/**
 * This method "removes" all private keys for the given user, and automatically creates a new key.
 * 
 * By "removing" keys, we mean that we delete them from the server.
 * However, other users may not fetch our updated key right away,
 * so we always keep old keys in the database until they actually expire.
 * (At which point they're automatically deleted.)
 * 
 * After marking all old keys for removal from the server,
 * this method automatically generates a new private key.
 * 
 * Once the database has been properly updated, the completionBlock is invoked.
 * The newKeyID specified the locator/uuid of the new STPublicKey object in the database.
 * If the userID is invalid (user doesn't exist, or isn't a local user) then newKeyID will be nil.
 *
 * Note: The DatabaseActionHandler automatically handles deleting the old keys from the server.
 * Note: The DatabaseActionHandler automatically handles uploading the new key.
**/
- (void)removeAllPrivateKeysForUserID:(NSString *)userID
                      completionBlock:(void (^)(NSString *newKeyID))completion;

/**
 * This method simply deletes the expired private key from the database.
 * 
 * It is assumed that the corresponding public key has already been deleted from the web server.
 * If not, then this method will make one last attempt to do so.
 * But if that fails, then it relies upon the server to automatically delete expired public keys
 * as part of the server's general cleanup mechanism.
 *
 * This method returns (via completionBlock) the private key's associated userID,
 * if that user still exists in the database.
**/
- (void)deleteExpiredPrivateKey:(NSString *)keyID
                completionBlock:(void (^)(NSString *userID))completion;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Refreshing Web Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method tries to fetch the web info for the given localUser.
 * The web info includes:
 *
 * - web_firstName
 * - web_lastName
 * - web_compositeName
 * - web_avatarURL
 * - email
 * - hasPhone
 * - canSendMedia
 * - spNumbers
 * - subscriptionExpireDate
 * - subscriptionAutoRenews
 * - handlesOwnBilling
 *
 * If the fetch suceeds, then the method automatically updates the user in the given database.
 * And the completionBlock is invoked after the database transaction completes.
**/
- (void)refreshWebInfoForLocalUser:(STLocalUser *)localUser
                   completionBlock:(void (^)(NSError *error, NSString *userID, NSDictionary *infoDict))completion;

/**
 * This method tries to fetch the web info for the given localUser.
 * The web info includes:
 *
 * - web_firstName
 * - web_lastName
 * - web_compositeName
 * - web_avatarURL
 * - hasPhone
 * - canSendMedia
 *
 * If the fetch suceeds, then the method automatically updates the user in the given database.
 * And the completionBlock is invoked after the database transaction completes.
**/
- (void)refreshWebInfoForRemoteUser:(STUser *)remoteUser
                    completionBlock:(void (^)(NSError *error, NSString *userID, NSDictionary *infoDict))completionBlock;

/**
 * Invokes either refreshWebInfoForLocalUser or refreshWebInfoForRemoteUser,
 * depending upon the given user.
**/
- (void)refreshWebInfoForUser:(STUser *)user
              completionBlock:(void (^)(NSError *error, NSString *userID, NSDictionary *infoDict))completionBlock;

/**
 * This method checks the given user's avatar setup (avatarFilename, avatarSource, web_avatarURL),
 * and downloads the users web avatar if needed.
 *
 * Once downloaded, the avatar is set properly for the user (via the AvatarManager method).
**/
- (void)downloadWebAvatarForUserIfNeeded:(STUser *)user;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 * We create UILocalNotification's to remind the user about an upcoming subscription expiration,
 * or that their subscription expired. The UILocalNotifcations have a corresponding STNotification item in the datbase.
 * 
 * So when the STNotification fires, or when the user's subscriptionExpirationDate changes,
 * that's when this method should be invoked so that we can reset the UILocalNotifications (and STNotification's).
**/
- (void)resyncSubscriptionWarningsForLocalUser:(STLocalUser *)localUser;

/**
 * Description needed
**/
- (void)informUserAboutUserNotifcationUUID:(NSString *)userNotificationUUID;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Payments
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Description needed
**/
- (void)recordPaymentWithReceipt:(NSString *)receipt64S
                    forLocalUser:(STLocalUser *)localUser
                 completionBlock:(STUserManagerCompletionBlock)completion;

/**
 * Description needed
**/
- (void)retryPaymentForUserID:(NSString *)userID
              completionBlock:(STUserManagerCompletionBlock)completion;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Export
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Description needed
**/

- (NSString *)vcardForUser:(STUser *)user
           withTransaction:(YapDatabaseReadTransaction *) transaction;

- (NSString *)jsonForUser:(STUser *)user
          withTransaction:(YapDatabaseReadTransaction *) transaction;

- (NSDictionary *)dictionaryForUser:(STUser *)user
                    withTransaction:(YapDatabaseReadTransaction *) transaction;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Import
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)importContactsfromURL:(NSURL *)url
                    completionBlock:(STUserManagerImportCompletionBlock)completion;

/**
 * Description needed
**/
- (void)importSTUserFromDictionary:(NSDictionary*)personInfo
                   completionBlock:(STUserManagerCompletionBlock)completion;

@end
