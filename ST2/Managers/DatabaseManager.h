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
#import "YapDatabaseView.h"
#import "YapDatabaseFilteredView.h"
#import "YapDatabaseSecondaryIndex.h"
#import "YapDatabaseRelationship.h"
#import "YapDatabaseHooks.h"

#import "XMPPJID.h"

@class DatabaseManager;
@class STUser;
@class STLocalUser;
@class STConversation;

/**
 * The following notifications are automatically posted for the uiDatabaseConnection:
 * 
 * - UIDatabaseConnectionWillUpdateNotification
 * - UIDatabaseConnectionDidUpdateNotification
 * 
 * The notifications correspond with the longLivedReadTransaction of the uiDatabaseConnection.
 * The DatabaseManager class listens for YapDatabaseModifiedNotification's.
 * 
 * The UIDatabaseConnectionWillUpdateNotification is posted immediately before the uiDatabaseConnection
 * is moved to the latest commit. And the UIDatabaseConnectionDidUpdateNotification is posted immediately after
 * the uiDatabaseConnection was moved to the latest commit.
 * 
 * These notifications are always posted to the main thread.
 *
 * The UIDatabaseConnectionDidUpdateNotification will always contain a userInfo dictionary with:
 * 
 * - kNotificationsKey
 *     Contains the NSArray returned by [uiDatabaseConnection beginLongLivedReadTransaction].
 *     That is, the array of commit info from each commit the connection jumped.
 *     This is the information that is fed into the various YapDatabase API's to figure out what changed.
 * 
 * - kCurrentUserUpdatedKey
 *     A BOOL (wrapped in NSNumber) representing whether the currentUser object changed.
 * 
 * - kCurrentUserIDChangedKey
 *     A BOOL (wrapped in NSNumber) representing whether the we switched accounts (currentUserA -> currentUserB)
**/
extern NSString *const UIDatabaseConnectionWillUpdateNotification;
extern NSString *const UIDatabaseConnectionDidUpdateNotification;
extern NSString *const kNotificationsKey;
extern NSString *const kCurrentUserUpdatedKey;
extern NSString *const kCurrentUserIDChangedKey;

/**
 * The following constants are the database extension names.
 * 
 * E.g.: [[transaction ext:Ext_View_Order] objectAtIndexPath:indexPath withMappings:mappings]
**/
extern NSString *const Ext_Relationship;
extern NSString *const Ext_View_Order;
extern NSString *const Ext_View_Queue;
extern NSString *const Ext_View_Unread;
extern NSString *const Ext_View_Action;
extern NSString *const Ext_View_Server;
extern NSString *const Ext_View_NeedsReSend;
extern NSString *const Ext_View_StatusMessage;
extern NSString *const Ext_View_HasScloud;
extern NSString *const Ext_View_HasGeo;
extern NSString *const Ext_View_SavedContacts;
extern NSString *const Ext_View_LocalContacts;
extern NSString *const Ext_View_FilteredContacts;
extern NSString *const Ext_SecondaryIndex;
extern NSString *const Ext_Hooks;

/**
 * You can use this as an alternative to the sharedInstance:
 * [[DatabaseManager sharedInstance] uiDatabaseConnection] -> STDatabaseManager.uiDatabaseConnection
**/
extern DatabaseManager *STDatabaseManager;



@interface DatabaseManager : NSObject

/**
 * The database manager must be started manually via this method.
 * This method cannot be called until STAppDelegate.storageKey is ready.
**/
+ (void)start;

/**
 * Standard singleton pattern.
 * As a shortcut, you can use the global STDatabaseManager ivar instead.
**/
+ (instancetype)sharedInstance; // Or STDatabaseManager global ivar

/**
 * The path of the raw database file.
**/
+ (NSString *)databasePath;

/**
 * The path of the directory containing all the encrypted blobs.
**/
+ (NSString *)blobDirectory;

/**
 * The root database class.
 * Most of the time you'll instead want a database connection (see below).
**/
@property (nonatomic, strong, readonly) YapDatabase *database;

/**
 * The UI connection is read-only, and is reserved for use EXCLUSIVELY on the MAIN THREAD.
 * Attempting to access this property outside the main thread will throw an exception.
**/
@property (nonatomic, strong, readonly) YapDatabaseConnection *uiDatabaseConnection; // main thread only

/**
 * These connections are read-only and read-write (respectively).
 * They may be used on ANY THREAD.
**/
@property (nonatomic, strong, readonly) YapDatabaseConnection *roDatabaseConnection; // read-only
@property (nonatomic, strong, readonly) YapDatabaseConnection *rwDatabaseConnection; // read-write

/**
 * Returns the currently selected user account.
 *
 * Attempting to access this property outside the main thread will throw an exception.
 * To get the currentUser from a background thread, you must use the currentUserWithTransaction: method.
**/
@property (nonatomic, strong, readonly) STLocalUser *currentUser;


#pragma mark On-The-Fly Views

/**
 * The filteredContacts view is an in-memory view that is created on-the-fly. (YapDatabaseFilteredView)
 * 
 * Use the configure method to create and register the view.
 * Use the teardown method to dealloc and unregister the view.
 * 
 * These methods are used as a reference counting scheme.
 * Thus you MUST balance all calls to 'configure...' with a matching 'teardown...'.
 * It's recommended you call configure within your init method,
 * and invoke teardown in the dealloc method.
 * 
 * @param networkId
 *   Only STUser objects whose networkID matches the given networkId will be displayed in the view.
 * 
 * @param optionalUserIdToFilter
 *   If you also want to filter out the local user, then you may pass the corresponding userId.
 *   Note that there may be multiple local users in the same networkID.
**/

- (void)configureFilteredContactsDBView:(NSString *)networkId withUserId:(NSString *)optionalUserIdToFilter;
- (void)reconfigureFilteredContactsDBView:(NSString *)inNetworkId withUserId:(NSString *)optionalUserIdToFilter;
- (void)teardownFilteredContactsDBView;

#pragma mark User Utilities

- (NSArray *)symmetricKeyIDsforThreadID:(NSString *)threadID
                        withTransaction:(YapDatabaseReadWriteTransaction *)transaction;

- (STUser *)findUserWithJID:(XMPPJID *)jid transaction:(YapDatabaseReadTransaction *)transaction;

- (STLocalUser *)findUserWithAppStoreHash:(NSString *)hashStr transaction:(YapDatabaseReadTransaction *)transaction;

/**
 * The currentUser property is not thread-safe (can only be used on the main thread).
 * Background tasks should use this method to fetch the current user.
 * Or they should fetch and store the currentUser on the main thread, before dispatching their background task.
**/
- (STLocalUser *)currentUserWithTransaction:(YapDatabaseReadTransaction *)transaction;

/**
 * User this method to create a temp STUser object, for any users that don't exist in the database.
 * 
 * There are several ViewController classes that take STUser properties.
 * Generally, you fetch the user first, possibly using findUserWithJID, etc.
 * If the user doesn't exist in the database, then simply use this method to create a temp/stub STUser
 * with the proper values set, and then pass it to the viewController.
**/
- (STUser *)tempUserWithJID:(XMPPJID *)jid;
- (STUser *)tempUserWithJID:(XMPPJID *)jid networkID:(NSString *)networkID;

/**
 *
**/
- (NSArray *)multiCastUsersForConversation:(STConversation *)conversation
                           withTransaction:(YapDatabaseReadTransaction *)transaction;

/**
 * Returns the sum total of all unread messages for the given userId.
 *
 * This number is suitable as a badge for the user, as in the SettingsViewController.
**/
- (NSUInteger)numberOfUnreadMessagesForUser:(NSString *)userId
                            withTransaction:(YapDatabaseReadTransaction *)transaction;

/**
 * Returns the sum total of all unread messages for the given userId, excluding one particular conversation.
 * 
 * This number is suitable as a badge within the given conversation,
 * representing the number of unread messages elsewhere.
**/
- (NSUInteger)numberOfUnreadMessagesForUser:(NSString *)userId
                      excludingConversation:(NSString *)conversationId
							withTransaction:(YapDatabaseReadTransaction *)transaction;

/**
 * Returns the sum total of all unread messages for every local user.
 * 
 * This number is suitable as a badge for the application.
**/
- (NSUInteger)numberOfUnreadMessagesForAllUsersWithTransaction:(YapDatabaseReadTransaction *)transaction;

#pragma mark User Management

/**
 * Description needed...
**/
- (BOOL)isUserProvisioned:(NSString *)userName
                networkID:(NSString *)networkID;

/**
 * Deletes the given local user.
 * Automatically deletes all associated information such as conversations and messages.
**/
- (void)asyncDeleteLocalUser:(NSString *)userID completionBlock:(dispatch_block_t)completionBlock;

/**
 * This method "deletes" a saved remote user.
 * And by "delete" what we really mean is set user.isSavedToSilentContacts to NO.
 * 
 * We do not want to actually delete the user from our database.
 * We just want to "delete" it from the UI.
 * 
 * This method also performs all the other actions we might expect,
 * such as clearing all the user.sc_X properties, and deleting the saved avatar (if needed).
**/
- (void)asyncUnSaveRemoteUser:(NSString *)userID completionBlock:(dispatch_block_t)completionBlock;

#pragma mark Conversation Utilities

/** 
 * Returns an array (no it doesn't) of locations for all the messages in this conversation ?
**/
- (void)geoLocationsForConversation:(NSString *)conversationId
                    completionBlock:(void (^)(NSError *error, NSDictionary *locations))completionBlock;

@end
