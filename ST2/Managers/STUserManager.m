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
#import "STUserManager.h"

#import "AppConstants.h"
#import "AppDelegate.h"
#import "MessageStream.h"
#import "SCCalendar.h"
#import "SCimpUtilities.h"
#import "SilentTextStrings.h"
#import "STConversation.h"
#import "STUser.h"
#import "STLocalUser.h"
#import "STLogging.h"
#import "STNotification.h"
#import "STPreferences.h"
#import "STPublicKey.h"

// Managers
#import "AddressBookManager.h"
#import "AvatarManager.h"
#import "MessageStreamManager.h"
#import "SCWebAPIManager.h"
#import "SCWebDownloadManager.h"
#import "StoreManager.h"

// Categories
#import "NSDate+SCDate.h"
#import "NSString+SCUtilities.h"
#import "NSDictionary+vCard.h"
#import "UIImage+Crop.h"

// Libraries
#import <libkern/OSAtomic.h>

// Log levels: off, error, warn, info, verbose

#if DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)


@implementation STUserManager
{
    YapDatabaseConnection *databaseConnection;
}


static STUserManager *sharedInstance;

+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		initialized = YES;
		sharedInstance = [[STUserManager alloc] init];
  	}
}

+ (STUserManager *)sharedInstance
{
	return sharedInstance;
}

- (instancetype)init
{
	NSAssert(sharedInstance == nil, @"You MUST used the sharedInstance singleton.");
	
	if ((self = [super init]))
	{
		databaseConnection = [STDatabaseManager.database newConnection];
		databaseConnection.objectCacheLimit = 20;
		databaseConnection.metadataCacheEnabled = NO;
		databaseConnection.name = @"STUserManager";
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Activation & Deactivation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Description needed
**/
- (void)activateUserName:(NSString *)userName
            withPassword:(NSString *)password
              deviceName:(NSString *)deviceName
               networkID:(NSString *)networkID
         completionBlock:(STUserManagerCompletionBlock)completion
{
	DDLogAutoTrace();
	
	NSString *domain = [AppConstants xmppDomainForNetworkID:networkID];
	XMPPJID *jid = [XMPPJID jidWithUser:userName domain:domain resource:nil];
	
	__block STLocalUser *localUser = nil;
	
	[STDatabaseManager.roDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		STUser *user = [STDatabaseManager findUserWithJID:jid transaction:transaction];
		if (user && user.isLocal)
		{
			localUser = (STLocalUser *)user;
		}
	}];
	
	// Attempt to use the same deviceID we were using before.
	
	NSString *deviceID = localUser.deviceID;
	if (deviceID == nil)
	{
		// If the localUser still exists, then we want to *REUSE* the same deviceID.
		// If the localUser was deleted, then we want the deviceID to be *DIFFERENT* from the last time we activated.
		//
		// This is wrong.
	//	deviceID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
		//
		// This is right.
		deviceID = [[NSUUID UUID] UUIDString];
	}
	
	[[SCWebAPIManager sharedInstance] provisionWithUsername:userName
	                                               password:password
	                                             deviceName:deviceName
	                                               deviceID:deviceID
	                                              networkID:networkID
	                                        completionBlock:^(NSError *error, NSDictionary *infoDict)
	{
		if (error)
		{
			if (completion) {
				completion(error, NULL);
			}
		}
	    else
		{
			NSString *apiKey = [infoDict objectForKey:@"api_key"];
			
			if (apiKey == nil)
			{
				DDLogError(@"SCWebAPIManager provisionUser returned non-error, but missing api_key !");
				
				NSDictionary *userInfo = @{ NSLocalizedDescriptionKey :
				  @"The response from the server was ill formed (missing api_key)." };
				NSError *internalError = [NSError errorWithDomain:@"SCWebAPI" code:0 userInfo:userInfo];
				
				if (completion) {
					completion(internalError, NULL);
				}
				
				return;
			}
			
			[self activateDevice:deviceID
			              apiKey:apiKey
			           networkID:networkID
			     completionBlock:^(NSError *error, NSString *newUUID)
			{
				if (error)
				{
					if (completion) {
						completion(error, NULL);
					}
				}
				else
				{
					if (completion) {
						completion(NULL, newUUID);
					}
				}
			}]; // end STUserManager completionBlock
				
		} // end else if (!error)
			
	}]; // end SCWebAPIManager completionBlock
}

/**
 * Description needed
**/
- (void)activateDevice:(NSString *)inDeviceID
                apiKey:(NSString *)inApiKey
             networkID:(NSString *)inNetworkID
       completionBlock:(STUserManagerCompletionBlock)completionBlock
{
	DDLogAutoTrace();
	
	NSString *deviceID  = [inDeviceID copy];  // mutable string protection
	NSString *apiKey    = [inApiKey copy];    // mutable string protection
	NSString *networkID = [inNetworkID copy]; // mutable string protection
	
	DDLogOrange(@"Activating deviceID: %@", deviceID);
	
	dispatch_block_t GetConfigForDeviceID = ^{
		
		[[SCWebAPIManager sharedInstance] getConfigForDeviceID:deviceID
		                                                apiKey:apiKey
		                                             networkID:networkID
		                                       completionBlock:^(NSError *error, NSDictionary *configInfoDict)
		{
			if (error)
			{
				if (completionBlock) {
					completionBlock(error, NULL);
				}
				return;// from block
			}
			
			// {
			//   "silent_phone" = {
			//     "numbers" = (
			//       15558675309
			//     );
			//     "password" = LOTSOFRANDOMPASSWORDLOTSOFRANDOMPASSWORDLOTSOFRANDOMPASSWORD;
			//     "pstn_calling" = 0;
			//     "tls1" = "blahblahblah1.silentcircle.net";
			//     "tls2" = "blahblahblah.silentcircle.net";
			//   };
			//   "silent_text" = {
			//     "password" = "LotsOfRandomPasswordLotsOfRandomPasswordLotsOfRandomPassword";
			//     "username" = "someone@silentcircle.com";
			//   };
			// }
			
		//	NSDictionary *spInfo = [configInfoDict objectForKey:@"silent_phone"];
			NSDictionary *stInfo = [configInfoDict objectForKey:@"silent_text"];
			
			NSString * jidStr = [stInfo objectForKey:@"username"];
			NSString * jidPwd = [stInfo objectForKey:@"password"];
			
			if (!jidStr || !jidPwd)
    	    {
				if (completionBlock) {
					NSError *err = [STAppDelegate otherError:@"Internal Error - user not completly provisioned"];
					completionBlock(err, nil);
				}
				return;// from block
			}
			
			XMPPJID *realJID = [XMPPJID jidWithString:jidStr];
			
			ABRecordID abRecordID = kABRecordInvalidID;
			NSDictionary *abDict = [[AddressBookManager sharedInstance] infoForSilentCircleJID:realJID];
			if (abDict && [abDict objectForKey:kABInfoKey_abRecordID])
			{
				abRecordID = [[abDict objectForKey:kABInfoKey_abRecordID] intValue];
			}
			
			// update the user new user record with phone number
		
			[self addLocalUserToDB:realJID
			             networkID:networkID
			          xmppPassword:jidPwd
			                apiKey:apiKey
			              deviceID:deviceID
			          canSendMedia:YES
			                enable:YES
			       completionBlock:^(NSString *newUUID)
			{
				if (completionBlock) {
					completionBlock(error, newUUID);
				}
				
			}]; // end [self addLocalUserToDB:...
			
		}]; // end [[SCWebAPIManager sharedInstance] getConfigForDeviceID:...
		
	}; // end GetConfigForDeviceID()
	
	dispatch_block_t MarkActiveDeviceID = ^{
	
		[[SCWebAPIManager sharedInstance] markActiveDeviceID:deviceID
		                                              apiKey:apiKey
		                                           networkID:networkID
		                                     completionBlock:^(NSError *error, NSDictionary *infoDict)
		{
			if (error)
			{
				if (completionBlock) {
					completionBlock(error, NULL);
				}
				return;// from block
			}
			
			GetConfigForDeviceID();
			
		}]; // end [[SCWebAPIManager sharedInstance] markActiveDeviceID:...
		
	}; // end MarkActiveDeviceID()
	
	
	// Order of operations:
	//
	// 1st: MarkActiveDeviceID()
	// 2nd: GetConfigForDeviceID()
	
	MarkActiveDeviceID();
}


/**
 * Deactivates the user account (by clearing the xmppPassword & apiKey).
 * 
 * If needsDeprovision is YES, then configures it so the DatabaseActionManager will handle:
 * - deprovisiong the device
 * - unregistering the push token
**/
- (void)deactivateUser:(NSString *)userID andDeprovision:(BOOL)needsDeprovision completionBlock:(dispatch_block_t)block
{
	DDLogAutoTrace();
	
	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STUser *user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
		if (user.isLocal)
		{
			[self deactivateLocalUser:(STLocalUser *)user
			           andDeprovision:needsDeprovision
			          withTransaction:transaction];
		}
		
	} completionBlock:block];
}

- (void)deactivateLocalUser:(STLocalUser *)localUser
             andDeprovision:(BOOL)needsDeprovision
            withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	localUser = [localUser deactivatedCopy];
	localUser.needsRegisterPushToken = NO;
	
	if (needsDeprovision)
	{
		localUser.needsDeprovisionUser = YES;
		
		// Note: the DatabaseActionManager handles the corresponding WebAPI calls.
	}
	
	[transaction setObject:localUser
	                forKey:localUser.uuid
	          inCollection:kSCCollection_STUsers];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Account Creation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Description needed
**/
- (void)createAccountFor:(NSString *)username
            withPassword:(NSString *)password
               networkID:(NSString *)networkID
              deviceName:(NSString *)deviceName
               firstName:(NSString *)firstName   // optional
                lastName:(NSString *)lastName    // optional
                   email:(NSString *)email       // optional
         completionBlock:(STUserManagerCompletionBlock)completion
{
	DDLogAutoTrace();

	NSParameterAssert(username != nil);
	NSParameterAssert(password != nil);
	NSParameterAssert(networkID != nil);
	NSParameterAssert(deviceName != nil);
	
	if (firstName && (firstName.length == 0)) {
		firstName = nil;
	}
	if (lastName && (lastName.length == 0)) {
		lastName = nil;
	}
	if (email && (email.length == 0)) {
		email = nil;
	}
	
	//
	// Why does this require two seperate Web API calls ?!?!?
	//
	
	[[SCWebAPIManager sharedInstance] createAccountFor:username
	                                      withPassword:password
	                                         networkID:networkID
	                                         firstName:firstName
	                                          lastName:lastName
	                                             email:email
	                                   completionBlock:^(NSError *error, NSDictionary *ignoredDict)
	{
		if (error)
		{
			if (completion) {
				completion(error, NULL);
			}
			return;
		}
		
		[[SCWebAPIManager sharedInstance] provisionCodeFor:username
		                                      withPassword:password
		                                         networkID:networkID
		                                   completionBlock:^(NSError *error, NSDictionary *jsonDict)
		{
			NSString *provisionCode = nil;
			if (!error)
			{
				provisionCode = [jsonDict valueForKey:@"code"];
				if (provisionCode == nil)
				{
					NSString *msg = @"SCWebAPIManager returned non-error, but missing provisionCode";
					
					NSAssert(NO, msg);                      // For dev builds
					error = [STAppDelegate otherError:msg]; // For production builds
				}
			}
			
			if (error)
			{
				if (completion) {
					completion(error, NULL);
				}
				return;
			}
			
			NSDictionary *provisionInfo = @{
			  kProvisionInfoKey_provisionCode : provisionCode,
			  kProvisionInfoKey_deviceName    : deviceName
			};
			
			NSString *xmppDomain = [AppConstants xmppDomainForNetworkID:networkID];
			XMPPJID *jid = [XMPPJID jidWithUser:username domain:xmppDomain resource:nil];
			
			__block STUser *localUser = nil;
			
			YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
			[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
				
				// Search for user in database with this JID.
				
				STUser *user = [STDatabaseManager findUserWithJID:jid transaction:transaction];
				if (user)
				{
					if (user.isRemote)
					{
						localUser = [[STLocalUser alloc] initWithRemoteUser:user provisonInfo:provisionInfo];
					}
					else // if (user.isLocal)
					{
						localUser = [(STLocalUser *)user copyWithNewProvisionInfo:provisionInfo];
					}
				}
				else
				{
					NSString *uuid = [[NSUUID UUID] UUIDString];
					
					localUser = [[STLocalUser alloc] initWithUUID:uuid
															  jid:jid
														networkID:networkID
													 provisonInfo:provisionInfo];
					localUser.sc_firstName = firstName;
					localUser.sc_lastName = lastName;
					localUser.email = email;
				}
				
				[transaction setObject:localUser
								forKey:localUser.uuid
						  inCollection:kSCCollection_STUsers];
				
				
			} completionBlock:^{
			
				if (completion) {
					completion(NULL, localUser.uuid);
				}
				
			}]; // end [rwDatabaseConnection asyncReadWriteWithBlock:
			
		}]; // end [[SCWebAPIManager sharedInstance] provisionCodeFor:...
		
	}]; // end [[SCWebAPIManager sharedInstance] createAccountFor:
}


/**
 * The user has paid for the account, now we need to provsion them using the provisionCode.
**/
- (void)continueCreateAccountForUserID:(NSString *)userID
                       completionBlock:(STUserManagerCompletionBlock)completion
{
    DDLogAutoTrace();
    
	__block STUser *user = nil;
	
	[STDatabaseManager.roDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
	}];
	
	if (user && user.isLocal)
	{
		STLocalUser *localUser = (STLocalUser *)user;
		
		NSString *deviceID = localUser.deviceID;
		if (deviceID == nil)
		{
			// If the localUser still exists, then we want to *REUSE* the same deviceID.
			// If the localUser was deleted, then we want the deviceID to be *DIFFERENT* from the last time we activated.
			//
			// This is wrong.
		//	deviceID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
			//
			// This is right.
			deviceID = [[NSUUID UUID] UUIDString];
		}
		
		NSString * provisionCode = [localUser.provisonInfo objectForKey:kProvisionInfoKey_provisionCode];
		NSString * deviceName    = [localUser.provisonInfo objectForKey:kProvisionInfoKey_deviceName];
		
		[[SCWebAPIManager sharedInstance] provisionWithCode:provisionCode
		                                         deviceName:deviceName
		                                           deviceID:deviceID
		                                          networkID:user.networkID
		                                    completionBlock:^(NSError *error, NSDictionary *infoDict)
		{
			if (error)
			{
				if (completion) {
					completion(error, localUser.uuid);
				}
			}
			else
			{
				NSString *apiKey = [infoDict valueForKey:@"api_key"];
				NSAssert(apiKey != nil, @"provisionWithCode did not return api_key");
				
				[[STUserManager sharedInstance] activateDevice:deviceID
				                                        apiKey:apiKey
				                                     networkID:localUser.networkID
				                               completionBlock:^(NSError *error, NSString *newUserID)
				{
                	if (!error) {
						[STPreferences setSelectedUserId:newUserID];
					}
					
					if (completion) {
						completion(error, newUserID);
					}
				}];
			}
		}];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark General User Management
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
- (void)addNewUser:(STUser *)inUser
       withPubKeys:(NSArray *)pubKeysArray
   completionBlock:(void (^)(NSString *userID))completionBlock
{
	DDLogAutoTrace();
	
	if (inUser == nil)
	{
		DDLogWarn(@"%@ - Ignoring: newUser parameter is nil !", THIS_METHOD);
		
		if (completionBlock) {
			dispatch_async(dispatch_get_main_queue(), ^{
				completionBlock(nil);
			});
		}
		return;
	}
	if (inUser.jid == nil)
	{
		DDLogWarn(@"%@ - Ignoring: newUser.jid parameter is nil !", THIS_METHOD);
		
		if (completionBlock) {
			dispatch_async(dispatch_get_main_queue(), ^{
				completionBlock(nil);
			});
		}
		return;
	}
	
	__block STUser *user = [inUser copy];
	__block NSString *userID = user.uuid;
	
	__block BOOL isDuplicateUser = NO;
	__block BOOL shouldDownloadWebAvatar = YES;
	
	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		NSDate *now = [NSDate date];
		
		// Sanity checks.
		// Make sure user isn't already in the database.
		//
		// Note: Don't use this method to update an existing user.
		// There is a different method for that. Use that one instead.
		
		if (userID)
		{
			if ([transaction hasObjectForKey:userID inCollection:kSCCollection_STUsers])
			{
				DDLogWarn(@"%@ - Ignoring: exsting user with same uuid !", THIS_METHOD);
				isDuplicateUser = YES;
			}
		}
		
		if (!isDuplicateUser)
		{
			STUser *existingUser = [STDatabaseManager findUserWithJID:user.jid transaction:transaction];
			if (existingUser)
			{
				DDLogInfo(@"%@ - Ignoring: exsting user with same jid: %@", THIS_METHOD, user.jid);
				
				userID = existingUser.uuid;
				user = [user copyWithNewUUID:userID];
				
				isDuplicateUser = YES;
			}
		}
		
		if (isDuplicateUser)
		{
			[self updateUser:user withPubKeys:pubKeysArray completionBlock:completionBlock];
			
			return; // from transaction block (jump to completionBlock)
		}
		
		// Process the given publicKeys (if needed)
		
		if (pubKeysArray) {
			[self processPubKeys:pubKeysArray forUser:user withTransaction:transaction];
		}
		
		// Update the user's basic properties
		
		if (userID == nil)
		{
			userID = [[NSUUID UUID] UUIDString];
			user = [user copyWithNewUUID:userID];
		}
		user.lastUpdated = now;
		
		// Add the user to the database
		
		[transaction setObject:user
		                forKey:user.uuid
		          inCollection:kSCCollection_STUsers];

		// When should we download the avatar?
		//
		// - it has a web_avatarURL AND
		// - it has no avatar (avatarSource is none)
		//
		shouldDownloadWebAvatar = user.web_avatarURL && user.avatarSource == kAvatarSource_None;
		
		
	} completionBlock:^{
		
		if (isDuplicateUser)
		{
			// Ignore.
			// Do NOT invoke completionBlock.
			//
			// We forwarded everything to the updateUser:withPubKeys:completionBlock: method.
		}
		else
		{
			// Check for link in contacts book entry.
			//
			// What is that uuid stuff?
			// It doesn't even have a kABInfoKey_ constant.
			// Undocumented code :(
			//
			// Todo:
			// - Figure out what the uuid stuff is.
			// - Create a constant for it.
			// - Document it.
			//
			NSDictionary *abInfo = [[AddressBookManager sharedInstance] infoForSilentCircleJID:user.jid];
			if (abInfo && ![abInfo objectForKey:@"uuid"])
			{
				ABRecordID abNum = [[abInfo objectForKey:kABInfoKey_abRecordID] intValue];
				[[AddressBookManager sharedInstance] updateUser:user.uuid withABRecordID:abNum isLinkedByAB:YES];
			}
			
			if (shouldDownloadWebAvatar)
			{
				[[STUserManager sharedInstance] downloadWebAvatarForUserIfNeeded:user];
			}
			
			if (completionBlock) {
				completionBlock(user.uuid);
			}
		}
	}];
}

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
- (void)updateUser:(STUser *)inUser
       withPubKeys:(NSArray *)pubKeysArray
   completionBlock:(void (^)(NSString *userID))completionBlock
{
	DDLogAutoTrace();
	
	__block STUser *updatedUser = [inUser copy];
	__block STUser *mergedUser = nil;
	
	__block BOOL didUpdateUser = YES;
	__block BOOL didDeactivateLocalUser = NO;
	__block BOOL shouldDownloadWebAvatar = NO;
	
	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STUser *existingUser = [transaction objectForKey:updatedUser.uuid inCollection:kSCCollection_STUsers];
		if (existingUser == nil)
		{
			DDLogWarn(@"%@ - Ignoring: user with uuid doesn't exist !", THIS_METHOD);
			
			didUpdateUser = NO;
			return; // from transaction block (jump to completionBlock)
		}
		
		BOOL awaitingReKeying = NO;
		BOOL deviceIDChanged = NO;
		
		mergedUser = [existingUser copy];
		
		// Update the user's changed properties
		
		NSSet *changedProperties = updatedUser.changedProperties;
		
		for (NSString *changedPropertyName in changedProperties)
		{
			id newValue = [updatedUser valueForKey:changedPropertyName];
			
			[mergedUser setValue:newValue forKey:changedPropertyName];
		}
		
		// Process the given publicKeys (if needed)
		
		if (pubKeysArray) {
			[self processPubKeys:pubKeysArray forUser:mergedUser withTransaction:transaction];
		}
		
		// Force update required properties (if needed)
		
		if (![changedProperties containsObject:@"lastUpdated"])
		{
			mergedUser.lastUpdated = [NSDate date];
		}
		
		if (mergedUser.awaitingReKeying)
		{
			mergedUser.awaitingReKeying = NO;
			awaitingReKeying = YES;
		}
		
		NSString *oldDeviceID = existingUser.activeDeviceID;
		NSString *newDeviceID = mergedUser.activeDeviceID;
		
		if (oldDeviceID == nil)
		{
			// We settting user.activeDeviceID for the first time.
			// So there's no evidence that the user changed devices.
		}
		else if (![oldDeviceID isEqualToString:newDeviceID])
		{
			deviceIDChanged = YES;
		}
		
		// Write the merged existingUser/updatedUser back to the database
		
		[transaction setObject:mergedUser
						forKey:mergedUser.uuid
				  inCollection:kSCCollection_STUsers];
		
		[mergedUser clearChangedProperties];
		
		// When should we download the avatar?
		// If the web_avatarURL changes, then we should IF
		// - the user has no avatar OR
		// - is using the previous webAvatar.
		//
		// Also, we should download it if the user has no avatar, and now we have a webAvatarURL.
		//
		BOOL didChangeAvatarURL = NO;
		if ([changedProperties containsObject:@"web_avatarURL"])
		{
			NSString *old_web_avatarURL = existingUser.web_avatarURL;
			NSString *new_web_avatarURL = updatedUser.web_avatarURL;
			
			if (![NSString isString:old_web_avatarURL equalToString:new_web_avatarURL])
			{
				didChangeAvatarURL = YES;
			}
		}
		
		if (didChangeAvatarURL)
			shouldDownloadWebAvatar = mergedUser.avatarSource <= kAvatarSource_Web;
		else if (mergedUser.web_avatarURL)
			shouldDownloadWebAvatar = mergedUser.avatarSource == kAvatarSource_None;
		
		// Re-Key if needed.
		//
		// That is, if we were awaiting a web refresh in order to properly initiate scimp v2 re-keying
		// using the user's most recent public key.
		
		if (awaitingReKeying)
		{
			XMPPJID *remoteJID = mergedUser.jid;
			
			NSMutableArray *streams = [NSMutableArray arrayWithCapacity:1];
			NSMutableArray *conversations = [NSMutableArray arrayWithCapacity:1];
			
			[[transaction ext:Ext_View_LocalContacts] enumerateKeysAndObjectsInGroup:@"" usingBlock:
			    ^(NSString *collection, NSString *key, id object, NSUInteger index, BOOL *stop)
			{
				__unsafe_unretained STLocalUser *localUser = (STLocalUser *)object;
				
				NSString *conversationID = [MessageStream conversationIDForLocalJid:localUser.jid remoteJid:remoteJID];
				STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUser.uuid];
				
				if (conversation) {
					
					MessageStream *ms = [MessageStreamManager messageStreamForUser:localUser];
					if (ms)
					{
						[streams addObject:ms];
						[conversations addObject:conversation];
					}
				}
			}];
			
			NSUInteger count = conversations.count;
			for (NSUInteger i = 0; i < count; i++)
			{
				MessageStream *ms = [streams objectAtIndex:i];
				STConversation *conversation = [conversations objectAtIndex:i];
				
				[ms rekeyConversationIfAwaitingReKeying:conversation withTransaction:transaction];
			}
		}
		else if (deviceIDChanged)
		{
			XMPPJID *remoteJID = mergedUser.jid;
			
			NSMutableArray *conversations = [NSMutableArray arrayWithCapacity:1];
			
			[[transaction ext:Ext_View_LocalContacts] enumerateKeysAndObjectsInGroup:@"" usingBlock:
			    ^(NSString *collection, NSString *key, id object, NSUInteger index, BOOL *stop)
			{
				__unsafe_unretained STLocalUser *localUser = (STLocalUser *)object;
				
				NSString *conversationID = [MessageStream conversationIDForLocalJid:localUser.jid remoteJid:remoteJID];
				STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUser.uuid];
				
				if (conversation) {
					[conversations addObject:conversation];
				}
			}];
			
			NSUInteger count = conversations.count;
			for (NSUInteger i = 0; i < count; i++)
			{
				STConversation *conversation = [conversations objectAtIndex:i];
				NSString *resource = conversation.remoteJid.resource;
				
				if (resource && ![resource isEqualToString:newDeviceID])
				{
					// Update the remoteJid.resource.
					// This will ensure that the next time we send a message in that conversation,
					// we'll either fallback to using a new scimp context,
					// or revert to using a proper scimp context for the new remoteFullJid.
					//
					// At a minimum, we'll at least use one that isn't tied to the previous remoteFullJid.
					
					conversation = [conversation copy];
					conversation.remoteJid = [conversation.remoteJid jidWithNewResource:newDeviceID];
					
					[transaction setObject:conversation forKey:conversation.uuid inCollection:conversation.userId];
				}
			}
		}
		
		if (mergedUser.isLocal)
		{
			STLocalUser *localUser = (STLocalUser *)mergedUser;
			
			if (localUser.isActivated && ![localUser.deviceID isEqualToString:localUser.activeDeviceID])
			{
				// localUser.deviceID    : Same as localUser.xmppResource
				// localUser.oldDeviceID : Before ST-989, the deviceID was seperate from xmppResource
				
				if (![localUser.deviceID isEqualToString:localUser.activeDeviceID]   &&
					![localUser.oldDeviceID isEqualToString:localUser.activeDeviceID] )
				{
					// Our device is no longer the active device !
					// We need to deactive the localUser !
					
					[self deactivateLocalUser:localUser
					           andDeprovision:NO // <- It's already been deprovistioned (implicitly)
					          withTransaction:transaction];
					
					didDeactivateLocalUser = YES;
				}
			}
		}
		
		
	} completionBlock:^{
		
		if (didUpdateUser)
		{
			// Note: We don't bother with the AddressBook JID stuff here simply because
			// the user's JID should NEVER change, once added to the database.
			
			if (shouldDownloadWebAvatar)
			{
				[[STUserManager sharedInstance] downloadWebAvatarForUserIfNeeded:mergedUser];
			}
			
			if (completionBlock) {
				completionBlock(updatedUser.uuid);
			}
		}
		else
		{
			if (completionBlock) {
				completionBlock(nil);
			}
		}
		
		if (didDeactivateLocalUser)
		{
			// Note: This message matches the info message that a user would get if he/she manually
			// deauthorized the account on this device.
			
			NSString *title = nil;
			
			XMPPJID *jid = mergedUser.jid;
			if (IsProductionNetworkDomain(jid))
				title = jid.user;
			else
				title = [NSString stringWithFormat:@"%@ (%@)", jid.user, [AppConstants networkDisplayNameForJID:jid]];
			
			NSString *msg = NSLocalizedString(@"You have deauthorized this device for Silent Text.",
											  @"Deauthorization message");
			
		//	[MessageStream sendInfoMessage:msg toUser:mergedUser.uuid];
			
			UIAlertView *alert =
			  [[UIAlertView alloc] initWithTitle:title
			                             message:msg
			                            delegate:nil
			                   cancelButtonTitle:NSLS_COMMON_OK
			                   otherButtonTitles:nil];
			
			[alert show];
			
			[[MessageStreamManager existingMessageStreamForUser:(STLocalUser *)mergedUser] disconnect];
		}
	}];
}

- (void)processPubKeys:(NSArray *)pubKeysArray
               forUser:(STUser *)user
       withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	if (user.isLocal) return;
	if ([pubKeysArray count] == 0) return;
	
	// Parse the given pubKeys,
	// and put ALL non-expired keys into the database along with the user.
	//
	// Why don't we just put one key into the databsae, instead of all of them?
	// Because, that assumes the user is only using a single device.
	// And that's just foolish wishful thinking.
	// It doesn't matter what you tell people, they're going to use multiple devices.
	// And that means there could be several valid public keys, one per device essentially.
	
	NSDate *now = [NSDate date];
	NSMutableArray *pubKeys = [NSMutableArray arrayWithCapacity:[pubKeysArray count]];
	
	for (NSDictionary *keyDict in pubKeysArray)
	{
		NSString *locator = nil;
		NSString *publicKeyString = nil;
		
		locator = [keyDict objectForKey:@"locator"];
		
		NSError *error = nil;
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:keyDict options:0 error:&error];
		
		if (jsonData) {
			publicKeyString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
		}
		else if (error) {
			DDLogWarn(@"Error parsing pubKey JSON: %@", error);
		}
		
		if (locator && publicKeyString)
		{
			NSDate *expireDate = [NSDate dateFromRfc3339String:[keyDict objectForKey:@"expire_date"]];
			if (expireDate && ([expireDate compare:now] == NSOrderedDescending))
			{
				STPublicKey *publicKey = [[STPublicKey alloc] initWithUUID:locator
				                                                    userID:user.uuid
				                                                   keyJSON:publicKeyString
				                                              isPrivateKey:NO];
				
				[pubKeys addObject:publicKey];
			}
		}
	}
	
	if ([pubKeys count] == 0)
	{
		// Didn't find any valid (non-expired) public keys
		return;
	}
	
	// Sort the pubKeys (first by startDate, then by expireDate).
	
	[pubKeys sortUsingComparator:^NSComparisonResult(id a, id b) {
		
		__unsafe_unretained STPublicKey *pubKeyA = (STPublicKey *)a;
		__unsafe_unretained STPublicKey *pubKeyB = (STPublicKey *)b;
		
		return [pubKeyA compare:pubKeyB];
	}];
	
	// We're going to add any missing public keys (that don't already exist in the database)
	//
	// Important: We do this IN-ORDER, from oldest to newest.
	// This allows us to properly handle key continuity.
	
	NSMutableArray *addedPubKeys = [NSMutableArray arrayWithCapacity:[pubKeys count]];
	
	for (STPublicKey *pubKey in pubKeys)
	{
		if ([transaction hasObjectForKey:pubKey.uuid inCollection:kSCCollection_STPublicKeys]
		  && [user.publicKeyIDs containsObject:pubKey.uuid])
		{
			// Already in the database.
			continue;
		}
		
		// Check for key continuity.
		// That is, was newestKey signed by another key we already have in our database?
	
		NSArray *keySigs = [pubKey.keyDict objectForKey:@"signatures"];
		for (NSDictionary *sig in keySigs)
		{
			NSString *signedBy = [sig objectForKey:@"signed_by"];
			
			if ([pubKey.uuid isEqualToString:signedBy])
			{
				// Signed by yourself, huh?
				// Denied !
			}
			else
			{
				STPublicKey *signingKey = [transaction objectForKey:signedBy
				                                       inCollection:kSCCollection_STPublicKeys];
				if (signingKey)
				{
					SCLError err = kSCLError_NoErr;
					SCKeyContextRef scSig = kInvalidSCKeyContextRef;
					
					NSData *data = nil;
					
					if ([NSJSONSerialization isValidJSONObject:sig]) {
						data = [NSJSONSerialization dataWithJSONObject:sig options:0UL error:NULL];
					}
					
					if (data) {
						SCKeyDeserialize((uint8_t *)data.bytes, data.length, &scSig);
					}
					
					SCKeyContextRef pubKeyContext = kInvalidSCKeyContextRef;
					SCKey_Deserialize(pubKey.keyJSON, &pubKeyContext);
					
					SCKeyContextRef signingKeyContext = kInvalidSCKeyContextRef;
					SCKey_Deserialize(signingKey.keyJSON, &signingKeyContext);
					
					BOOL continuityVerified = NO;
					
					if (SCKeyContextRefIsValid(pubKeyContext)     &&
					    SCKeyContextRefIsValid(signingKeyContext) &&
					    SCKeyContextRefIsValid(scSig)              )
					{
						err = SCKeyVerifySig(pubKeyContext, NULL, signingKeyContext, scSig);
						if (err != kSCLError_NoErr)
						{
							continuityVerified = YES;
						}
					}
					
					if (SCKeyContextRefIsValid(pubKeyContext))
					{
						SCKeyFree(pubKeyContext);
						pubKeyContext = kInvalidSCKeyContextRef;
					}
					
					if (SCKeyContextRefIsValid(signingKeyContext))
					{
						SCKeyFree(signingKeyContext);
						signingKeyContext = kInvalidSCKeyContextRef;
					}
					
					if (SCKeyContextRefIsValid(scSig))
					{
						SCKeyFree(scSig);
						scSig = kInvalidSCKeyContextRef;
					}
					
					if (continuityVerified)
					{
						pubKey.continuityVerified = YES;
						break;
					}
				}
			}
			
		} // end for (NSDictionary *sig in keySigs)
		
		// Save the publicKey to the database
		
		[transaction setObject:pubKey
		                forKey:pubKey.uuid
		          inCollection:kSCCollection_STPublicKeys];
		
		[addedPubKeys addObject:pubKey];
		
	} // end for (STPublicKey *pubKey in pubKeys)
	
	
	// And finally, update the user's publicKey related properties
	
	if (addedPubKeys.count > 0)
	{
		NSMutableSet *newPublicKeyIDs = [user.publicKeyIDs mutableCopy];
		for (STPublicKey *pubKey in addedPubKeys)
		{
			[newPublicKeyIDs addObject:pubKey.uuid];
		}
		
		user.publicKeyIDs = [newPublicKeyIDs copy];
		
		STPublicKey *currentKey = [STPublicKey currentKeyFromKeys:pubKeys]; // MUST use this method for proper alg
		user.currentKeyID = currentKey.uuid;
	}
}

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
         completionBlock:(void (^)(NSString *uuid))completionBlock
{
	DDLogAutoTrace();
	
	__block STLocalUser *localUser = nil;
	
	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		// Search for user in database with this JID

		STUser *user = [STDatabaseManager findUserWithJID:jid transaction:transaction];
		if (user)
		{
            if (user.isRemote)
			{
				localUser = [[STLocalUser alloc] initWithRemoteUser:user
				                                       xmppResource:deviceID // deviceID == xmppResource
				                                       xmppPassword:xmppPassword
				                                             apiKey:apiKey
				                                       canSendMedia:canSendMedia
				                                          isEnabled:enable];
			}
			else // if (user.isLocal)
			{
				localUser = [(STLocalUser *)user copyWithXmppPassword:xmppPassword
				                                               apiKey:apiKey
				                                         canSendMedia:canSendMedia
				                                            isEnabled:enable];
				
				// If we are updating the apiKey then remove the provision info.
				if (localUser.provisonInfo) {
					localUser = [localUser copyWithNewProvisionInfo:nil];
				}
				
				// Clear server sync information
				localUser.needsRegisterPushToken = NO;
				localUser.needsDeprovisionUser = NO;
			}
		}
		else
		{
            // new user
            
            NSString *uuid = [[NSUUID UUID] UUIDString];
            
			localUser = [[STLocalUser alloc] initWithUUID:uuid
			                                          jid:jid
			                                    networkID:networkID
			                                 xmppResource:deviceID // deviceID == xmppResource
			                                 xmppPassword:xmppPassword
			                                       apiKey:apiKey
			                                 canSendMedia:canSendMedia
			                                    isEnabled:enable];
		}
		
		localUser.isSavedToSilentContacts = YES;
		
		// Set pushToken, and flag it for registration with the server.
		
		NSString *pushToken = [STPreferences applicationPushToken];
		if (pushToken && ![networkID isEqualToString:kNetworkID_Fake])
		{
			localUser.pushToken = pushToken;
			localUser.needsRegisterPushToken = YES;
			
			// Note: The pushToken is AUTOMATICALLY REGISTERED by the DatabaseActionManager.
		}
		
		// Create privateKey, and flag it for upload to the server.
		
		NSDictionary *networkInfo = [[AppConstants SilentCircleNetworkInfo] objectForKey:networkID];
		if ([[networkInfo objectForKey:@"canProvision"] boolValue] == YES)
		{
			NSTimeInterval keyLifespan = [STPreferences publicKeyLifespan];
			SCKeySuite keySuite = [STPreferences scimpKeySuite];
			
			NSDate *expireDate = [NSDate dateWithTimeIntervalSinceNow:keyLifespan];
			
			STPublicKey *privateKey = [STPublicKey privateKeyWithOwner:[jid full]
			                                                    userID:localUser.uuid
			                                                expireDate:expireDate
			                                                storageKey:STAppDelegate.storageKey
			                                                  keySuite:keySuite];
			
			if (privateKey)
			{
				NSSet *keyIDs = [NSSet setWithObject:privateKey.uuid];
				
				localUser.publicKeyIDs = keyIDs;
				localUser.currentKeyID = privateKey.uuid;
				
				localUser.nextKeyGeneration = [NSDate dateWithTimeIntervalSinceNow:[STPreferences publicKeyRefresh]];
				
				[transaction setObject:privateKey
				                forKey:privateKey.uuid
				          inCollection:kSCCollection_STPublicKeys];
				
				// Note: The public key is AUTOMATICALLY UPLOADED by the DatabaseActionManager.
			}
		}
		
		[transaction setObject:localUser
		                forKey:localUser.uuid
		          inCollection:kSCCollection_STUsers];

 		
	} completionBlock:^{
        
        [[AddressBookManager sharedInstance] updateAddressBookUsers];
         
		if (completionBlock) {
			completionBlock(localUser.uuid);
		}
		
		if (localUser.isEnabled)
		{
			[[MessageStreamManager messageStreamForUser:localUser] connect];
		}
		
		[STPreferences setSelectedUserId:localUser.uuid];
    }];
}

/**
 * This method fires off a requet to the web API to fetch info for the given JID.
 * 
 * If the web fetch succeeds,
 * then it automatically creates the user in the database before invoking the completionBlock.
**/
- (void)createUserIfValidJID:(XMPPJID *)jid
             completionBlock:(void (^)(NSError *error, NSString *userID))completionBlock
{
	__block STLocalUser *localUser = nil;
	
	if ([NSThread isMainThread])
	{
		localUser = STDatabaseManager.currentUser;
	}
	else
	{
		YapDatabaseConnection *roDatabaseConnection = STDatabaseManager.roDatabaseConnection;
		[roDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			localUser = [STDatabaseManager currentUserWithTransaction:transaction];
		}];
	}
	
	[[SCWebAPIManager sharedInstance] getUserInfo:jid
	                                 forLocalUser:localUser
	                              completionBlock:^(NSError *error, NSDictionary *jsonDict)
	{
		// Workaround for possible server bug
		if (!error && jsonDict)
		{
			NSString *errorString = [jsonDict valueForKey:@"error"];
			if (errorString)
			{
				error = [STAppDelegate otherError:errorString];
			}
		}
		
		if (error)
		{
			if (completionBlock)
				completionBlock(error, nil);
		}
		else
		{
			NSDictionary *parsedDict = [[SCWebAPIManager sharedInstance] parseUserInfoResult:jsonDict];
			
			NSArray *pubKeysArray = [parsedDict objectForKey:kUserInfoKey_pubKeys];
			
			NSString *uuid = [[NSUUID UUID] UUIDString];
			NSString *networkID = [AppConstants networkIdForXmppDomain:jid.domain];
			
			STUser *remoteUser = [[STUser alloc] initWithUUID:uuid networkID:networkID jid:jid];
			
			remoteUser.web_firstName     = [parsedDict objectForKey:kUserInfoKey_firstName];
			remoteUser.web_lastName      = [parsedDict objectForKey:kUserInfoKey_lastName];
			remoteUser.web_compositeName = [parsedDict objectForKey:kUserInfoKey_displayName];
			remoteUser.web_avatarURL     = [parsedDict objectForKey:kUserInfoKey_avatarUrl];
			remoteUser.web_organization  = [parsedDict objectForKey:kUserInfoKey_organization];
			remoteUser.hasPhone     = [[parsedDict objectForKey:kUserInfoKey_hasPhone] boolValue];
			remoteUser.canSendMedia = [[parsedDict objectForKey:kUserInfoKey_canSendMedia] boolValue];
			
			NSDate *now = [NSDate date];
			
			remoteUser.lastUpdated = now;
			remoteUser.nextWebRefresh = [now dateByAddingTimeInterval:[STPreferences remoteUserWebRefreshInterval]];
			
			[self addNewUser:remoteUser withPubKeys:pubKeysArray completionBlock:^(NSString *userID) {
				 
				if (completionBlock)
					completionBlock(nil, userID);
			}];
		}
         
	}]; // end [SCWebAPIManager getUserInfo:::]
}

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
- (void)createPrivateKeyForUserID:(NSString *)inUserID
                  completionBlock:(void (^)(NSString *newKeyID))completion
{
	DDLogAutoTrace();
	
	NSString *userID = [inUserID copy]; // mutable string protection
	
	NSTimeInterval keyLifespan = [STPreferences publicKeyLifespan];
	SCKeySuite keySuite = [STPreferences scimpKeySuite];
	
	__block STUser *user = nil;
	__block STPublicKey *currentKey = nil;
	__block STPublicKey *newPrivateKey = nil;
    
    [databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
		if (user.currentKeyID)
		{
			currentKey = [transaction objectForKey:user.currentKeyID inCollection:kSCCollection_STPublicKeys];
		}
		
	} completionQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) completionBlock:^{
		
		if (user == nil || !user.isLocal)
		{
			if (!user.isLocal) { // Whatcha doing there cowboy?
				DDLogWarn(@"%@ - Unable to create private keys for non-local user", THIS_METHOD);
			}
			
			if (completion)
			{
				dispatch_async(dispatch_get_main_queue(), ^{
					completion(nil);
				});
			}
			
			return;
		}
		
		NSDate *expireDate = [NSDate dateWithTimeIntervalSinceNow:keyLifespan];
        
		newPrivateKey = [STPublicKey privateKeyWithOwner:[user.jid full]
		                                          userID:user.uuid
		                                      expireDate:expireDate
		                                      storageKey:STAppDelegate.storageKey
		                                        keySuite:keySuite];
		
		// Attempt to sign new key with previous one
		if (currentKey)
		{
			STPublicKey *signedNewPrivateKey = nil;
			SCLError err = SCKey_Sign(currentKey, newPrivateKey, &signedNewPrivateKey);
			
			if (err == kSCLError_NoErr && signedNewPrivateKey)
			{
				NSAssert(signedNewPrivateKey.isPrivateKey, @"Oops");
				NSAssert([signedNewPrivateKey.keyDict objectForKey:@"privKey"] != nil, @"Missing privateKey info !");
				
				newPrivateKey = signedNewPrivateKey;
			}
		}
		
		[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
			
			// Add the new key to the database.
			
			[transaction setObject:newPrivateKey
			                forKey:newPrivateKey.uuid
			          inCollection:kSCCollection_STPublicKeys];
			
			// The corresponding new publicKey will beAUTOMATICALLY UPLOADED by the DatabaseActionManager.
			//
			// This happens automatically because newPrivateKey.serverUploadDate is nil,
			// which triggers the DatabaseActionManager to fire off the upload.
			// It also handles failures, and automatically retries the upload when possible.
			// And it will pick up the process again if the app is relaunched.
			
			// Update the user.
			//
			// Don't forget:
			// You MUST re-fetch the user to ensure you have the most up-to-date version.
			
			user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
			user = [user copy];
			
			NSMutableSet *newUserKeyIDs = [user.publicKeyIDs mutableCopy];
			[newUserKeyIDs addObject:newPrivateKey.uuid];
			
			user.publicKeyIDs = newUserKeyIDs;
			user.currentKeyID = newPrivateKey.uuid;
			
			[transaction setObject:user
			                forKey:user.uuid
			          inCollection:kSCCollection_STUsers];
			
		} completionBlock:^{
			
			if (completion) {
				completion(newPrivateKey.uuid);
			}
		
		}]; // end [databaseConnection asyncReadWriteWithBlock:
		
	}]; // end [databaseConnection asyncReadWithBlock:
}

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
- (void)removeAllPrivateKeysForUserID:(NSString *)inUserID
                      completionBlock:(void (^)(NSString *newKeyID))completion
{
	DDLogAutoTrace();
	
	NSString *userID = [inUserID copy]; // mutable string protection
	
	NSTimeInterval keyLifespan = [STPreferences publicKeyLifespan];
	SCKeySuite keySuite = [STPreferences scimpKeySuite];
	
	__block STUser *user = nil;
	__block STPublicKey *currentKey = nil;
	__block STPublicKey *newPrivateKey = nil;
	
	[databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
		if (user.currentKeyID)
		{
			currentKey = [transaction objectForKey:user.currentKeyID inCollection:kSCCollection_STPublicKeys];
		}
		
	} completionQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) completionBlock:^{
		
		if (user == nil || !user.isLocal)
		{
			if (!user.isLocal) { // Whatcha doing there cowboy?
				DDLogWarn(@"%@ - Unable to create private keys for non-local user", THIS_METHOD);
			}
			
			if (completion)
			{
				dispatch_async(dispatch_get_main_queue(), ^{
					completion(nil);
				});
			}
			
			return;
		}
		
		NSDate *expireDate = [NSDate dateWithTimeIntervalSinceNow:keyLifespan];
        
		newPrivateKey = [STPublicKey privateKeyWithOwner:[user.jid full]
		                                          userID:user.uuid
		                                      expireDate:expireDate
		                                      storageKey:STAppDelegate.storageKey
		                                        keySuite:keySuite];
		
		// Attempt to sign new key with previous one
		if (currentKey)
		{
			STPublicKey *signedNewPrivateKey = nil;
			SCLError err = SCKey_Sign(currentKey, newPrivateKey, &signedNewPrivateKey);
			
			if (err == kSCLError_NoErr && signedNewPrivateKey)
			{
				NSAssert(signedNewPrivateKey.isPrivateKey, @"Oops");
				NSAssert([signedNewPrivateKey.keyDict objectForKey:@"privKey"] != nil, @"Missing privateKey info !");
				
				newPrivateKey = signedNewPrivateKey;
			}
		}
		
		[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
			
			// Add the new key to the database.
			
			[transaction setObject:newPrivateKey
			                forKey:newPrivateKey.uuid
			          inCollection:kSCCollection_STPublicKeys];
			
			// The corresponding new publicKey is AUTOMATICALLY UPLOADED by the DatabaseActionManager.
			
			// Fetch the user.
			//
			// Don't forget:
			// You MUST re-fetch the user to ensure you have the most up-to-date version.
			
			user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
			
			// Mark all older private keys for the user as deleted.
			
			for (NSString *keyID in user.publicKeyIDs)
			{
				STPublicKey *key = [transaction objectForKey:keyID inCollection:kSCCollection_STPublicKeys];
				if (key.isPrivateKey && !key.needsServerDelete && !key.serverDeleteDate)
				{
					key = [key copy];
					key.needsServerDelete = YES;
					
					[transaction setObject:key
					                forKey:keyID
					          inCollection:kSCCollection_STPublicKeys];
				}
			}
			
			// Update the user
			
			user = [user copy];
			
			NSMutableSet *newUserKeyIDs = [user.publicKeyIDs mutableCopy];
			[newUserKeyIDs addObject:newPrivateKey.uuid];
			
			user.publicKeyIDs = newUserKeyIDs;
			user.currentKeyID = newPrivateKey.uuid;
			
			[transaction setObject:user
			                forKey:user.uuid
			          inCollection:kSCCollection_STUsers];
			
		} completionBlock:^{
			
			if (completion) {
				completion(newPrivateKey.uuid);
			}
			
		}]; // end [databaseConnection asyncReadWriteWithBlock:
		
	}]; // end [databaseConnection asyncReadWithBlock:
}

/**
 * This method simply deletes the expired private key from the database.
 * 
 * It is assumed that the private key has already been deleted from the web server.
 * If not, then this method will make one last attempt to do so.
 * But if that fails, then it relies upon the server to automatically delete the expired private key
 * as part of the server's general cleanup mechanism.
 *
 * This method returns the private key's associated userID,
 * if that user still exists in the database.
**/
- (void)deleteExpiredPrivateKey:(NSString *)inKeyID
                completionBlock:(void (^)(NSString *userID))completion
{
	DDLogAutoTrace();
	
	NSString *keyID = [inKeyID copy]; // mutable string protection
	
	__block STUser *user = nil;
	__block BOOL needsDeleteFromServer = NO;
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STPublicKey *key = [transaction objectForKey:keyID inCollection:kSCCollection_STPublicKeys];
		if (key == nil)
			return; // from block
		
		user = [transaction objectForKey:key.userID inCollection:kSCCollection_STUsers];
		if (user && [user.publicKeyIDs containsObject:keyID])
		{
			// Remove the key from the user.publicKeyIDs set.
			
			user = [user copy];
			
			NSMutableSet *newPublicKeyIDs = [user.publicKeyIDs mutableCopy];
			[newPublicKeyIDs removeObject:keyID];
			
			user.publicKeyIDs = [newPublicKeyIDs copy];
			
			[transaction setObject:user
			                forKey:user.uuid
			          inCollection:kSCCollection_STUsers];
		}
		
		// The key should be deleted from the server by now.
		// But if not, we'll make one last attempt...
		
		if (user.isLocal && (key.needsServerDelete || !key.serverDeleteDate))
		{
			needsDeleteFromServer = YES;
		}
		
		// Remove the key itself
		
		[transaction removeObjectForKey:keyID inCollection:kSCCollection_STPublicKeys];
		
	} completionBlock:^{
		
		if (needsDeleteFromServer)
		{
			[[SCWebAPIManager sharedInstance] removePublicKeyWithLocator:keyID
			                                                forLocalUser:(STLocalUser *)user
			                                             completionBlock:NULL];
		}
		
		if (completion) {
			completion(user.uuid);
		}
	}];
}

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
- (void)refreshWebInfoForLocalUser:(STLocalUser *)inLocalUser
                   completionBlock:(void (^)(NSError *error, NSString *userID, NSDictionary *infoDict))completionBlock
{
	DDLogAutoTrace();
	
	if (inLocalUser == nil)
	{
		DDLogWarn(@"refreshWebInfoForLocalUser given nil user !");
		
		if (completionBlock) {
			NSError *error = [STAppDelegate otherError:@"Invalid parameter"];
			dispatch_async(dispatch_get_main_queue(), ^{
				completionBlock(error, nil, nil);
			});
		}
		return;
	}
	if (!inLocalUser.isLocal)
	{
		DDLogWarn(@"refreshWebInfoForLocalUser given non-local user !");
		
		if (completionBlock) {
			NSError *error = [STAppDelegate otherError:@"Invalid parameter"];
			dispatch_async(dispatch_get_main_queue(), ^{
				completionBlock(error, nil, nil);
			});
		}
		return;
	}
	
	STLocalUser *localUser = [inLocalUser copy];
	BOOL wasExpired = localUser.subscriptionHasExpired;
	
	[[SCWebAPIManager sharedInstance] getLocalUserInfo:localUser
	                                   completionBlock:^(NSError *error, NSDictionary *jsonDict)
	{
		// Workaround for possible server bug
		if (!error && jsonDict)
		{
			NSString *errorString = [jsonDict valueForKey:@"error"];
			if (errorString)
			{
				error = [STAppDelegate otherError:errorString];
			}
		}
		
		if (error)
		{
			if (completionBlock) {
				completionBlock(error, nil, nil);
			}
		}
		else
		{
			NSDictionary *parsedDict = [[SCWebAPIManager sharedInstance] parseLocalUserInfoResult:jsonDict];
			
			[localUser clearChangedProperties];
			
			localUser.hasPhone     = [parsedDict[kUserInfoKey_hasPhone] boolValue];
			localUser.canSendMedia = [parsedDict[kUserInfoKey_canSendMedia] boolValue];
			
			localUser.activeDeviceID = parsedDict[kUserInfoKey_activeDeviceID];
			localUser.email          = parsedDict[kUserInfoKey_email];
			
			localUser.web_avatarURL     = parsedDict[kUserInfoKey_avatarUrl];
			localUser.web_firstName     = parsedDict[kUserInfoKey_firstName];
			localUser.web_lastName      = parsedDict[kUserInfoKey_lastName];
			localUser.web_compositeName = parsedDict[kUserInfoKey_displayName];
			localUser.web_organization  = parsedDict[kUserInfoKey_organization];
			localUser.web_hash          = parsedDict[kUserInfoKey_hash];
			
			if ([parsedDict[kUserInfoKey_hasOCA] boolValue]) {
				localUser.spNumbers = parsedDict[kUserInfoKey_spNumbers];
			}
			
			localUser.subscriptionExpireDate = parsedDict[kUserInfoKey_subscriptionExpireDate];
			if ( (localUser.subscriptionExpireDate) && ([localUser.subscriptionExpireDate timeIntervalSince1970] < 0) ) {
				// not a real expiration date
				localUser.subscriptionExpireDate = nil;
			}
			
			localUser.subscriptionAutoRenews = [parsedDict[kUserInfoKey_subscriptionAutoRenews] boolValue];
			localUser.handlesOwnBilling      = [parsedDict[kUserInfoKey_handlesOwnBilling] boolValue];
			
			NSDate *now = [NSDate date];
			
			if (localUser.subscriptionExpireDate) {
				localUser.subscriptionHasExpired = ([localUser.subscriptionExpireDate timeIntervalSinceDate:now] < 0);
			}
			else {
				localUser.subscriptionHasExpired = NO;
			}
			
			NSTimeInterval webRefreshInterval;
			if (localUser.subscriptionHasExpired)
				webRefreshInterval = [STPreferences localUserWebRefreshInterval_expired];
			else
				webRefreshInterval = [STPreferences localUserWebRefreshInterval_normal];
			
			NSDate *nextWebRefresh = [now dateByAddingTimeInterval:webRefreshInterval];
			if (localUser.subscriptionExpireDate && [localUser.subscriptionExpireDate timeIntervalSinceDate:now] > 0)
			{
				nextWebRefresh = [nextWebRefresh earlierDate:localUser.subscriptionExpireDate];
			}
			
			localUser.lastUpdated = now;
			localUser.nextWebRefresh = nextWebRefresh;
			
			[self updateUser:localUser withPubKeys:nil completionBlock:^(NSString *userID) {
				
				if (completionBlock) {
					completionBlock(nil, userID, parsedDict);
				}
				
				if (wasExpired && !localUser.subscriptionHasExpired && localUser.isEnabled && localUser.isActivated)
				{
					[[MessageStreamManager messageStreamForUser:localUser] connect];
				}
			}];
		}
	}];
}

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
- (void)refreshWebInfoForRemoteUser:(STUser *)inUser
                    completionBlock:(void (^)(NSError *error, NSString *userID, NSDictionary *infoDict))completionBlock
{
	
	if (inUser == nil)
	{
		DDLogWarn(@"refreshWebInfoForRemoteUser given nil user !");
		
		if (completionBlock) {
			NSError *error = [STAppDelegate otherError:@"Invalid parameter"];
			dispatch_async(dispatch_get_main_queue(), ^{
				completionBlock(error, nil, nil);
			});
		}
		return;
	}
	if (!inUser.isRemote)
	{
		DDLogWarn(@"refreshWebInfoForRemoteUser given non-remote user !");
		
		if (completionBlock) {
			NSError *error = [STAppDelegate otherError:@"Invalid parameter"];
			dispatch_async(dispatch_get_main_queue(), ^{
				completionBlock(error, nil, nil);
			});
		}
		return;
	}
	
	STUser *remoteUser = [inUser copy];
	
	__block STLocalUser *localUser = nil;
	if ([NSThread isMainThread])
	{
		localUser = STDatabaseManager.currentUser;
	}
	else
	{
		[STDatabaseManager.roDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			localUser = [STDatabaseManager currentUserWithTransaction:transaction];
		}];
	}
	
	[[SCWebAPIManager sharedInstance] getUserInfo:remoteUser.jid
	                                 forLocalUser:localUser
	                              completionBlock:^(NSError *error, NSDictionary *jsonDict)
	{
		// Workaround for possible server bug
		if (!error && jsonDict)
		{
			NSString *errorString = [jsonDict valueForKey:@"error"];
			if (errorString)
			{
				error = [STAppDelegate otherError:errorString];
			}
		}
		
		if (error)
		{
			if (completionBlock)
				completionBlock(error, remoteUser.uuid, nil);
		}
		else
		{
			NSDictionary *parsedDict = [[SCWebAPIManager sharedInstance] parseUserInfoResult:jsonDict];
			
			NSArray *pubKeysArray = [parsedDict objectForKey:kUserInfoKey_pubKeys];
			
			[remoteUser clearChangedProperties];
			
			remoteUser.hasPhone     = [parsedDict[kUserInfoKey_hasPhone] boolValue];;
			remoteUser.canSendMedia = [parsedDict[kUserInfoKey_canSendMedia] boolValue];
			
			remoteUser.activeDeviceID = parsedDict[kUserInfoKey_activeDeviceID];
			
			remoteUser.web_avatarURL     = parsedDict[kUserInfoKey_avatarUrl];
			remoteUser.web_firstName     = parsedDict[kUserInfoKey_firstName];
			remoteUser.web_lastName      = parsedDict[kUserInfoKey_lastName];
			remoteUser.web_compositeName = parsedDict[kUserInfoKey_displayName];
			remoteUser.web_organization  = parsedDict[kUserInfoKey_organization];
			remoteUser.web_hash          = parsedDict[kUserInfoKey_hash];
			
			NSDate *now = [NSDate date];
			
			remoteUser.lastUpdated = now;
			remoteUser.nextWebRefresh = [now dateByAddingTimeInterval:[STPreferences remoteUserWebRefreshInterval]];
			
			if (remoteUser.isTempUser)
			{
				[self addNewUser:remoteUser withPubKeys:pubKeysArray completionBlock:^(NSString *userID) {
					
					if (completionBlock) {
						completionBlock(nil, userID, parsedDict);
					}
				}];
			}
			else
			{
				[self updateUser:remoteUser withPubKeys:pubKeysArray completionBlock:^(NSString *userID) {
				
					if (completionBlock) {
						completionBlock(nil, userID, parsedDict);
					}
				}];
			}
		}
         
	}]; // end [SCWebAPIManager getUserInfo:::]
}

/**
 * Invokes either refreshWebInfoForLocalUser or refreshWebInfoForRemoteUser,
 * depending upon the given user.
**/
- (void)refreshWebInfoForUser:(STUser *)user
              completionBlock:(void (^)(NSError *error, NSString *userID, NSDictionary *infoDict))completionBlock
{
	if (user.isLocal)
		[self refreshWebInfoForLocalUser:(STLocalUser *)user completionBlock:completionBlock];
	else
		[self refreshWebInfoForRemoteUser:user completionBlock:completionBlock];
}

/**
 * This method checks the given user's avatar setup (avatarFilename, avatarSource, web_avatarURL),
 * and downloads the users web avatar if needed.
 *
 * Once downloaded, the avatar is set properly for the user (via the AvatarManager method).
**/
- (void)downloadWebAvatarForUserIfNeeded:(STUser *)user
{
	// Should we download the avatar ?
	//
	// if (user.avatarSource > kAvatarSource_Web)  =>  User is linked to system or SC address book
	// if (user.web_avatarURL == nil            )  =>  Nothing to download
    
	if (user.avatarSource > kAvatarSource_Web || user.web_avatarURL == nil)
	{
		return;
 	}
	
	NSString *userId = user.uuid; // just retain the uuid for the duration of the HTTP request
	
	[[SCWebDownloadManager sharedInstance] maybeDownloadAvatar:user.web_avatarURL
	                                             withNetworkID:user.networkID
	                                           completionBlock:^(NSError *error, UIImage *image)
	{
		if (error)
		{
			DDLogWarn(@"Error fetching web_avatar: %@", error);
		}
		else if (image)
		{
			// The AvatarManager does everything for us:
			// - encrypts the image
			// - writes the encrypted blob to disk
			// - updates the STUser object in the database
			//
			// Along with a bunch of proper error & sanity checking.
			
			[[AvatarManager sharedInstance] asyncSetImage:image
			                                 avatarSource:kAvatarSource_Web
			                                    forUserID:userId
			                              completionBlock:NULL];
		}
    }];
}

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
- (void)resyncSubscriptionWarningsForLocalUser:(STLocalUser *)inLocalUser
{
	DDLogAutoTrace();
	
	if (inLocalUser == nil) return;
	if (!inLocalUser.isLocal)
	{
		DDLogWarn(@"%@ invoked with non-local user !", THIS_METHOD);
		return;
	}
	
	NSString *localUserID = inLocalUser.uuid;
	NSDate *expireDate = inLocalUser.subscriptionExpireDate;
	
	NSTimeInterval const kZeroDay    = 0;
    NSTimeInterval const kOneDay     = 3600 * 24;
    NSTimeInterval const kthreeDays  = kOneDay * 3;
    NSTimeInterval const kSevenDays  = kOneDay * 7;
	
	NSArray *alertIntervals = @[ @(kZeroDay), @(kOneDay), @(kthreeDays), @(kSevenDays) ];
    
    NSMutableArray *alertTimes =  [NSMutableArray arrayWithCapacity:[alertIntervals count]];
	NSDate *nextWarningDate = nil;
	
	if (expireDate)
	{
        for (NSNumber *num in alertIntervals)
		{
			NSTimeInterval interval = [num doubleValue];
			
			if (expireDate.timeIntervalSinceNow > interval)
			{
				nextWarningDate = [expireDate dateByAddingTimeInterval:(-1 * interval)];
				[alertTimes addObject:nextWarningDate];
			}
		}
	}
	
	__block NSString *userNotificationUUID = inLocalUser.notificationUUID;
	__block STNotification *newNotification = nil;
    
	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
    [rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		// Guard code for compatibiity with older versions.
		if (userNotificationUUID == nil)
		{
			userNotificationUUID = [[NSUUID UUID] UUIDString];
			
			STLocalUser *localUser = [transaction objectForKey:localUserID inCollection:kSCCollection_STUsers];
			
			localUser = [localUser copy];
			localUser.notificationUUID = userNotificationUUID;

			[transaction setObject:localUser
			                forKey:localUser.uuid
			          inCollection:kSCCollection_STUsers];
		}

		// Remove old notification(s)
		
		NSMutableArray *oldNotificationIDs = [NSMutableArray arrayWithCapacity:3];
		
        [transaction enumerateKeysAndObjectsInCollection:kSCCollection_STNotification
                                              usingBlock:^(NSString *key, id object, BOOL *stop)
		{
			__unsafe_unretained STNotification *notification = object;
			
			if ([notification.userID isEqualToString:localUserID])
			{
				NSString *notificationType = [notification.userInfo objectForKey:kSTNotificationKey_Type];
				BOOL isSubscriptionWarning = [notificationType isEqualToString:kSTNotificationType_SubscriptionExpire];
				
				if (isSubscriptionWarning)
				{
					[oldNotificationIDs addObject:notification.uuid];
				}
			}
        }];
		
        [transaction removeObjectsForKeys:oldNotificationIDs inCollection:kSCCollection_STNotification];
		
		// Create the new notification.
		//
		// Note: We only create a single STNotification, even if we create multiple UILocalNotifications.
		// The STNotification represents the first UILocalNotification that fires.
		
		if (nextWarningDate)
        {
			NSDictionary *info = @{
			  kSTNotificationKey_Type : kSTNotificationType_SubscriptionExpire,
			};
			
			newNotification = [[STNotification alloc] initWithUUID:[[NSUUID UUID] UUIDString]
			                                                userID:localUserID
			                                              fireDate:nextWarningDate
			                                              userInfo:info];
			
			[transaction setObject:newNotification
			                forKey:newNotification.uuid
			          inCollection:kSCCollection_STNotification];
		}
		
	} completionBlock:^{
		
		// Cancel any old notifcations
		
		NSArray *scheduledLocalNotifications = [[UIApplication sharedApplication] scheduledLocalNotifications];
		
		for (UILocalNotification *scheduledLocalNotification in scheduledLocalNotifications)
		{
			NSString *uuid = [scheduledLocalNotification.userInfo objectForKey:@"silent-text-notfication"];
			if ([uuid isEqualToString:userNotificationUUID])
			{
				[[UIApplication sharedApplication] cancelLocalNotification:scheduledLocalNotification];
			}
		}
		
		// Create any new notifications
		
		for (NSDate *alertDate in alertTimes)
		{
			NSString *expireWarning = nil;
			
			BOOL isExpireNotice = [alertDate isEqualToDate:expireDate];
			if (isExpireNotice)
			{
				expireWarning = NSLocalizedString(@"Your Silent Circle Subscription has expired",
				                                  @"UILocalNotification warning about subscription");
			}
			else
			{
				NSCalendar *calendar = [SCCalendar cachedAutoupdatingCurrentCalendar];
				NSDateComponents *components = [calendar components:(NSCalendarUnitDay | NSCalendarUnitSecond)
				                                           fromDate:alertDate
				                                             toDate:expireDate
				                                            options:0];
				
				NSString *frmt = NSLocalizedString(@"Your Silent Circle Subscription will expire in %d days",
				                                   @"Your Silent Circle Subscription will expire in %d days");
				
				expireWarning = [NSString stringWithFormat:frmt, components.day];
			}
			
			UILocalNotification *localNotification = [[UILocalNotification alloc] init];
			localNotification.fireDate = alertDate;
			localNotification.alertBody = expireWarning;
			
			localNotification.alertAction =  @"Silent Text Alert"; // Shouldn't this be "Renew Subscription" ??
			localNotification.timeZone = nil;
			
			localNotification.userInfo = @{ @"silent-text-notfication": userNotificationUUID };
			
			[[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
		}
	}];
}

/**
 * Description needed
**/
- (void)informUserAboutUserNotifcationUUID:(NSString *)userNotificationUUUD
{
    if (userNotificationUUUD == nil) return;
	
    // Figure out which user this pertains to
	
	__block STLocalUser *localUser = nil;
    
	[STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		YapDatabaseViewTransaction *localContactsViewTransaction = [transaction ext:Ext_View_LocalContacts];
		if (localContactsViewTransaction)
		{
			[localContactsViewTransaction enumerateKeysAndObjectsInGroup:@"" usingBlock:
			    ^(NSString *collection, NSString *key, id object, NSUInteger index, BOOL *stop)
			{
				__unsafe_unretained STLocalUser *aLocalUser = (STLocalUser *)object;
				
				if ([aLocalUser.notificationUUID isEqualToString:userNotificationUUUD])
				{
					localUser = aLocalUser;
					*stop = YES;
				}
			}];
		}
		else
		{
			[transaction enumerateKeysAndObjectsInCollection:kSCCollection_STUsers
			                                      usingBlock:^(NSString *key, id object, BOOL *stop)
			{
				__unsafe_unretained STUser *aUser = (STUser *)object;
				if (aUser.isLocal)
				{
					__unsafe_unretained STLocalUser *aLocalUser = (STLocalUser *)aUser;
					if ([aLocalUser.notificationUUID isEqualToString:userNotificationUUUD])
					{
						localUser = aLocalUser;
						*stop = YES;
					}
				}
			}];
		}
	}];
	
	if (localUser == nil)
	{
		DDLogWarn(@"%@: Unable to find localUser matching notificationUUID", THIS_METHOD);
		return;
	}
	
	// Figure out when the subscription expires
	
	NSString *frmt = nil;
	NSString *alertString = nil;
	
	if (localUser.subscriptionHasExpired)
	{
		frmt = NSLocalizedString(@"Your Silent Circle subscription for user \"%@\" has expired.", nil);
		alertString = [NSString stringWithFormat:frmt, localUser.displayName];
	}
	else
	{
		NSCalendar *calendar = [SCCalendar cachedAutoupdatingCurrentCalendar];
		NSDateComponents *components = [calendar components:(NSCalendarUnitDay | NSCalendarUnitSecond)
		                                           fromDate:[NSDate date]
		                                             toDate:localUser.subscriptionExpireDate
		                                            options:0];
		
		frmt = NSLocalizedString(@"Your Silent Circle subscription for user \"%@\" will expire in %d days", nil);
		alertString = [NSString stringWithFormat:frmt, localUser.displayName, components.day];
	}
	
	// Wouldn't it be nicer to do it this way ??
//	[MessageStream sendInfoMessage:alertString toUser:localUser.uuid];
	
	UIAlertView *alert =
	  [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Reminder", nil)
	                             message:alertString
	                            delegate:self
	                   cancelButtonTitle:NSLocalizedString(@"OK", nil)
	                   otherButtonTitles:nil];
	
	[alert show];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Payment
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)recordPaymentWithReceipt:(NSString *)receipt64S
                    forLocalUser:(STLocalUser *)inLocalUser
                 completionBlock:(STUserManagerCompletionBlock)completion
{
    
//    // payment complete, Tell Silent Circle you paid for it.
//	NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
//	NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
//	NSString *receipt64S = [receipt base64Encoded];
	
	NSString *localUserID = inLocalUser.uuid;
	BOOL localUserHasProvisionInfo = (inLocalUser.provisonInfo != nil);
	
	[[SCWebAPIManager sharedInstance] recordPaymentReceipt:receipt64S
                                                   forUser:inLocalUser
                                           completionBlock:^(NSError *error, NSDictionary *infoDict)
    {
        // was this user in the middle of a creation transaction?
		if (!error && localUserHasProvisionInfo)
		{
			[self continueCreateAccountForUserID:localUserID
			                     completionBlock:completion];
		}
        else
        {
			// connecting to the Silent Circle website failed.  We save the receipt in the user provisonInfo
			// so we might try  to record the payment at a later time.
            
            YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
            [rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
               
            	STLocalUser *localUser = [transaction objectForKey:localUserID
				                                      inCollection:kSCCollection_STUsers];
				
				NSMutableDictionary *newProvisionInfo = [localUser.provisonInfo mutableCopy];
				[newProvisionInfo setObject:receipt64S forKey:kProvisionInfoKey_receipt];
                
				localUser = [localUser copyWithNewProvisionInfo:newProvisionInfo];
				
				localUser.subscriptionExpireDate = [NSDate date];
				localUser.subscriptionHasExpired = YES;
           
				[transaction setObject:localUser
				                forKey:localUser.uuid
				          inCollection:kSCCollection_STUsers];

            } completionBlock:^{
   
				if (completion) {
					completion(error, localUserID);
				}
			}];
		}
	}];
}


- (void)retryPaymentForUserID:(NSString *)userID
              completionBlock:(STUserManagerCompletionBlock)completion

{
	__block STUser *user = NULL;
	
    [STDatabaseManager.roDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		user  = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
	}];
	
	if (user.isLocal)
	{
		STLocalUser *localUser = (STLocalUser *)user;
		
		// Is this user waiting to provision?
		NSDictionary *provisonInfo = localUser.provisonInfo;
		if (provisonInfo)
        {
            NSString *receipt64S = [provisonInfo objectForKey:kProvisionInfoKey_receipt];
			if (receipt64S)
			{
				// retry recording the purchase ?
				[[STUserManager sharedInstance] recordPaymentWithReceipt:receipt64S
				                                            forLocalUser:localUser
				                                         completionBlock:^ (NSError *error, NSString *uuid)
				{
					// the completion we are done passing in the erro
					if (completion) {
						completion(error, userID);
					}
				}];
				
			}
			else
			{
				NSError *error = [STAppDelegate otherError: @"App store purchase was not completed"];
				if (completion) {
					completion(error, userID);
				}
			}
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark vCard
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Description needed
**/
- (NSString *)SCContactInfoForUser:(STUser *)user
{
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithCapacity:8];
	
	[info setObject:user.jid.bare forKey:@"jid"];
    
	if (user.sc_firstName.length)    [info setObject:user.sc_firstName    forKey:@"sc_firstName"];
	if (user.sc_lastName.length)     [info setObject:user.sc_lastName     forKey:@"sc_lastName"];
	if (user.sc_organization.length) [info setObject:user.sc_organization forKey:@"sc_organization"];
	if (user.sc_notes.length)        [info setObject:user.sc_notes        forKey:@"sc_notes"];
    
	if (user.abRecordID != kABRecordInvalidID)
	{
		if(user.ab_firstName) [info setObject:user.ab_firstName forKey:@"ab_firstName"];
		if(user.ab_lastName)  [info setObject:user.ab_lastName  forKey:@"ab_lastName"];
	}
	
	if ([[AvatarManager sharedInstance] hasImageForUser:user])
	{
		NSString *avSourceStr;
        
        switch (user.avatarSource) {
            case kAvatarSource_Web:             avSourceStr  = @"web";  break;
            case kAvatarSource_AddressBook:     avSourceStr  = @"ab";   break;
            case kAvatarSource_SilentContacts:  avSourceStr  = @"sc";   break;
            default:                            avSourceStr  = @"none"; break;
        }
        
		[info setObject:avSourceStr forKey:@"avatarSource"];
	}
	
	NSData *data = nil;
	if ([NSJSONSerialization isValidJSONObject:info]) {
		data = [NSJSONSerialization dataWithJSONObject:info options:0 error:NULL];
	}
	
	return data? [data base64EncodedStringWithOptions:0] : NULL;
}


- (NSString *)vcardForUser:(STUser *)user
           withTransaction:(YapDatabaseReadTransaction *) transaction
{
	if (user == nil) return nil;
    
    NSString *vcardString = nil;
	
	NSMutableArray *cardItems = [[NSMutableArray alloc] init];
	
	int itemNo = 1;
	
	[cardItems addObject:@"BEGIN:VCARD"];
	[cardItems addObject:@"VERSION:3.0"];
	
	NSString* fullName = user.displayName;
	
	[cardItems addObject:[NSString stringWithFormat:@"FN:%@", fullName]];
	
	if (user.organization)
		[cardItems addObject:[NSString stringWithFormat:@"ORG:%@", user.organization]];
	
	[cardItems addObject:[NSString stringWithFormat:@"X-SILENTCIRCLE:%@", user.jid.bare]];
	
	NSString *SCInfo = [self SCContactInfoForUser:user];
	if (SCInfo)
		[cardItems addObject:[NSString stringWithFormat:@"X-SILENTCIRCLE-INFO:%@", SCInfo]];
	
	if (user.spNumbers)
	{
		for (id item in user.spNumbers)
		{
			NSString* number = NULL;
			
			if([item isKindOfClass: [NSDictionary class]])
			{
				number = [item  objectForKey:@"number"];
			}
			else  if([item isKindOfClass: [NSString class]])
			{
				number = item;
			}
			
			if(number)
			{
				[cardItems addObject:[NSString stringWithFormat:@"item%d.TEL;type=CELL;type=pref:%@", itemNo, number]];
				[cardItems addObject:[NSString stringWithFormat:@"item%d.X-ABLabel:silent circle", itemNo ]];
				
				itemNo++;
			}
			
		//	[cardItems addObject:[NSString stringWithFormat:@"TEL;type=CELL;type=VOICE;type=SILENT_CIRCLE;type=pref:%@", spNumber]];
		}
	}
	
	if (user.firstName || user.lastName)
		[cardItems addObject:[NSString stringWithFormat:@"N:%@;%@;;;", user.lastName, user.firstName]];
	
	[cardItems addObject:[NSString stringWithFormat:@"X-JABBER:%@", user.jid]];
	
	[cardItems addObject:[NSString stringWithFormat:@"item%d.X-ABLabel:Silent Circle",itemNo]];
	
	if ([user.jid.domain isEqualToString:kDefaultAccountDomain])
	{
		[cardItems addObject:[NSString stringWithFormat:@"item%d.IMPP;X-SERVICE-TYPE=silent circle;type=pref:x-apple:%@",itemNo,
                                  user.jid.user]];
	}
	else
	{
		[cardItems addObject:[NSString stringWithFormat:@"item%d.IMPP;X-SERVICE-TYPE=silent circle;type=pref:x-apple:%@",itemNo,
                                  user.jid]];
	}
	
	// IMPP;X-SERVICE-TYPE=silentcircle.com;type=xmpp:morpheus
	
	UIImage *image = [[AvatarManager sharedInstance] imageForUser:user];
	if (image)
	{
		NSData* dataData  = UIImageJPEGRepresentation(image, 1.0) ;
		NSString*  imageString = [dataData base64EncodedStringWithOptions:0];
		[cardItems addObject:[NSString stringWithFormat:@"PHOTO;ENCODING=b;TYPE=JPEG:%@", imageString]];
	}
	
	[cardItems addObject:@"END:VCARD"];
	
	vcardString = [cardItems componentsJoinedByString:@"\n"];
	vcardString = [vcardString stringByAppendingString:@"\n"];
    
    return vcardString;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma  mark SilentContacts
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


- (NSString *)jsonForUser:(STUser *)user
          withTransaction:(YapDatabaseReadTransaction *) transaction
{
    if (user == nil) return nil;
    
    NSString *jsonString = nil;
    
    NSDictionary* jsonDict = [self dictionaryForUser:user withTransaction:transaction];
    
    NSData *jsonData = ([NSJSONSerialization  isValidJSONObject: jsonDict] ?
                        [NSJSONSerialization dataWithJSONObject: jsonDict options:NSJSONWritingPrettyPrinted error: nil] :
                        nil);
    
    
    
    jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    return jsonString;
    
}


- (NSDictionary *)dictionaryForUser:(STUser *)user
                    withTransaction:(YapDatabaseReadTransaction *) transaction
{
    if (user == nil) return nil;
    
    NSMutableDictionary* jsonDict = user.syncableJsonDictionary.mutableCopy;
    
    if (user.avatarSource != kAvatarSource_Web)
    {
        
        UIImage *image = [[AvatarManager sharedInstance] imageForUser:user];
        if (image)
        {
            
            // use smaller size for exports
             CGSize frame = {180, 180};
            UIImage *scaledImage = image;
            
            if ((scaledImage.size.height > frame.height) || (scaledImage.size.width > frame.width))
            {
                scaledImage = [image imageByScalingAndCroppingForSize:frame];
            }
          
            NSData *dataData = UIImageJPEGRepresentation(scaledImage, 1.0);
            
            NSString*  imageString = [dataData base64EncodedStringWithOptions:0];
            [jsonDict setObject:imageString forKey: @"photo"];
            
        }
        
    }
    
    return jsonDict;
    
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Import
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// this is a simplistic version of SC import. we dont support endpoints yet..
// update this code once we start using the modern stuff from Kreiger

-(BOOL) importSilentContactsDictionary:(NSDictionary*) dict
                       completionBlock:(STUserManagerCompletionBlock)completion

{
    BOOL    canImport = NO;
    __block NSError *error = NULL;
    __weak STUserManager *self_ = self;
    
    XMPPJID *jid    = NULL;
    
    NSString * firstName        = [dict objectForKey:@"firstName"];
    NSString * lastName         = [dict objectForKey:@"lastName"];
    NSString * organization     = [dict objectForKey:@"organization"];
    NSString * jidString        = [dict objectForKey:@"jid"];
     NSString *imageString       = [dict objectForKey:@"photo"];
    UIImage  *userImage         = NULL;
    
    if(imageString.length)
    {
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:imageString options:NSDataBase64DecodingIgnoreUnknownCharacters];
        userImage = [UIImage imageWithData:imageData];
    }
    
    BOOL    isDuplicateUser = NO;
    
//	NSMutableArray* endpointsToMerge = [NSMutableArray array];
    
    if(jidString.length)
        jid =  [XMPPJID jidWithString:jidString];
   
    // do validity check here
    if(jid)
    {
        canImport = YES;
    }
    if(!canImport)
    {
        error = [SCimpUtilities errorWithSCLError:kSCLError_BadParams];
        
        if (completion) {
            completion(error, NULL);
        }
        
    }
    
    // start import process
    
    __block STUser* user = NULL;
    
    [STDatabaseManager.roDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
//        
//        // check for matching AB recordID
//        user = [STDatabaseManager findUserWithABuniqueID:abUniqueID transaction:transaction];
        
        // else check for matching jid
        if(!user)
            user = [STDatabaseManager findUserWithJID:jid transaction:transaction];
        
    }];
    
    if(!user)
    {
        // create new user
        NSString *networkID = [AppConstants networkIdForXmppDomain:[jid domain]];
        if (networkID == nil)
        {
            // Actually, I think we should bail at this point.
            // Because the JID isn't valid anyway.
            
            networkID = kNetworkID_Production;
        }
        
        NSString *uuid = [[NSUUID UUID] UUIDString];
        
        user = [[STUser alloc] initWithUUID:uuid
                                  networkID:networkID
                                        jid:jid];
        
    }
    else
    {
        user = user.copy;
        isDuplicateUser = YES;
    }
    
    user.sc_firstName       = firstName;
    user.sc_lastName        = lastName;
    user.sc_organization    = organization;
    user.isSavedToSilentContacts    = YES;
    
    if(!isDuplicateUser )
    {
        
        [self addNewUser:user
              withPubKeys:NULL
          completionBlock:^(NSString *uuid) {
              
              [self_ importSilentContactsDictionaryContinue:uuid
                                                      image:userImage
                                            completionBlock:^(NSError *error, NSString *userID)
               {
                   if (completion) {
                       completion(nil, userID);
                   }
                   
               }];
              
          }];
        
    }
    else
    {
        [self updateUser:user
              withPubKeys:NULL
           completionBlock:^(NSString *userID) {
              
              [self_ importSilentContactsDictionaryContinue:userID image:userImage
                                            completionBlock:^(NSError *error, NSString *userID)
               {
                   if (completion) {
                       completion(nil, userID);
                   }
                   
               }];
              
              
          }];
    }
    
    
    
    return canImport;
}


-(void)importSilentContactsDictionaryContinue:(NSString*)userID
                                        image:(UIImage*) image
                              completionBlock:(STUserManagerCompletionBlock)completion
{
    if (image)
    {
        [[AvatarManager sharedInstance] asyncSetImage:image
                                         avatarSource:kAvatarSource_AddressBook
                                            forUserID:userID
                                      completionBlock:^{
                                          if (completion) {
                                              completion(nil, userID);
                                          }
                                          
                                      }];
    }
    else
    {
        if (completion) {
            completion(nil, userID);
        }
    }
    
    
}


- (void)importSTUserFromDictionary:(NSDictionary *)personInfo
                   completionBlock:(STUserManagerCompletionBlock)completion
{
	DDLogAutoTrace();
	
	NSString * sc_firstName     = [personInfo objectForKey:@"firstName"];
	NSString * sc_lastName      = [personInfo objectForKey:@"lastName"];
	NSString * sc_compositeName = [personInfo objectForKey:@"compositeName"];
	NSString * sc_organization  = [personInfo objectForKey:@"organization"];
    
	NSDictionary *scInfo = [personInfo objectForKey:@"X-SILENTCIRCLE-INFO"];
    
	// expand on this later
	if (scInfo)
	{
		// Expand on this later.
		// Useful fields include:
		//
		// sc_firstName
		// sc_lastName
		// sc_organization
		// sc_notes
		//
		// ab_firstName
		// ab_lastName
		//
		// avatarSource = (web, ab, sc, none)
	}
    
	XMPPJID *jid = [XMPPJID jidWithString:[personInfo objectForKey:@"jid"]];
	
	NSString *spPhoneNumber = [personInfo objectForKey:@"phone_silent circle"];
	if (spPhoneNumber == nil)
		spPhoneNumber = [personInfo objectForKey:@"phone_silent phone"];
	
	NSString *networkID = [AppConstants networkIdForXmppDomain:[jid domain]];
	if (networkID == nil)
	{
		// Actually, I think we should bail at this point.
		// Because the JID isn't valid anyway.
		
		networkID = kNetworkID_Production;
	}
	
	NSString *uuid = [[NSUUID UUID] UUIDString];
	
	STUser *user = [[STUser alloc] initWithUUID:uuid networkID:networkID jid:jid];
	
	user.hasPhone = spPhoneNumber && spPhoneNumber.length;
	user.canSendMedia = YES; // we should verify this?
	
	user.sc_firstName     = sc_firstName;
	user.sc_lastName      = sc_lastName;
	user.sc_compositeName = sc_compositeName;
	user.sc_organization  = sc_organization;
	
	user.spNumbers = spPhoneNumber ? @[spPhoneNumber] : NULL;
	
	// Add the user to the database.
	//
	// Note: The user.nextWebRefresh will trigger an automatic refresh via the DatabaseActionManager.
	
	[self addNewUser:user withPubKeys:nil completionBlock:^(NSString *userID) {
		
		if (completion) {
			completion(NULL, userID);
		}
	}];
	
	// Add the image (if needed)
	
    UIImage *userImage = [personInfo objectForKey:@"thumbNail"];
	if (userImage)
	{
		[[AvatarManager sharedInstance] asyncSetImage:userImage
		                                 avatarSource:kAvatarSource_SilentContacts
		                                    forUserID:uuid
		                              completionBlock:NULL];
	}
}



- (BOOL)importVcardFilefromURL:(NSURL *)url
               completionBlock:(STUserManagerImportCompletionBlock)completion

{
    __block NSError *error = NULL;
    
    BOOL    canImport = NO;
    
    dispatch_block_t doneProcessingCompletionBlock = ^{
        
		dispatch_async(dispatch_get_main_queue(), ^{
            
			[NSFileManager.defaultManager removeItemAtURL:url error:nil];
            
			if (completion) {
				completion(error, NULL);
			}
		});
    };
    
    NSData *fileData = [NSData dataWithContentsOfURL:url options:0 error:&error];
	if (fileData == nil)
	{
		doneProcessingCompletionBlock();
        return canImport;
	}
	
	NSArray *people = [NSDictionary peopleFromvCardData:fileData];
	if (people.count == 0)
	{
		doneProcessingCompletionBlock();
        return canImport;
	}
	
    NSMutableArray*   processedUUIDs = [NSMutableArray array];

	__block int32_t itemsCount = (int32_t)people.count;
	
	for (NSDictionary *personInfo in people)
	{
		XMPPJID *jid = [XMPPJID jidWithString:[personInfo objectForKey:@"jid"]];
		
		DDLogMagenta(@"import %@",jid.user);
		
		[self importSTUserFromDictionary:personInfo completionBlock:^(NSError *error, NSString *uuid) {
			
            if(!error && uuid)
                [processedUUIDs addObject:uuid];

			if (OSAtomicDecrement32(&itemsCount) == 0)
			{
                if (completion) {
                    completion(error, processedUUIDs);
                }
 			}
		}];
	}
    
    return canImport;

}

- (BOOL)importSilentContactsFilefromURL:(NSURL *)url
                        completionBlock:(STUserManagerImportCompletionBlock)completion
{
    BOOL    canImport = NO;
    
    __block NSError *error = NULL;
    
    dispatch_block_t doneProcessingCompletionBlock = ^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (completion) {
                completion(error, NULL);
            }
        });
    };
    
    
    NSData*  jsonData = [NSData dataWithContentsOfURL:url options:0 error:&error];
    if (jsonData == nil)
    {
        doneProcessingCompletionBlock();
        return canImport;
    }
    
    
    id importedObject =   [NSJSONSerialization JSONObjectWithData:jsonData
                                                          options:NSJSONReadingMutableContainers
                                                            error:&error];
    
    if (importedObject == nil || error)
    {
        doneProcessingCompletionBlock();
        return canImport;
    }
    
    NSMutableArray*   contactArray = [NSMutableArray array];
    
    if([importedObject isKindOfClass:[NSDictionary class]])
    {
        [contactArray addObject:importedObject];
    }
    else if([importedObject isKindOfClass:[NSArray class]])
    {
        for(id importedItem in importedObject)
        {
            if([importedItem isKindOfClass:[NSDictionary class]])
            {
                [contactArray addObject:importedItem];
            }
        }
    }
    
    __block int32_t itemsCount = (int32_t)contactArray.count;
    
    if (itemsCount == 0)
    {
        doneProcessingCompletionBlock();
        return canImport;
    }
    
    NSMutableArray*   processedUUIDs = [NSMutableArray array];
    
    for (NSDictionary *personInfo in contactArray)
    {
        XMPPJID *jid = [XMPPJID jidWithString:[personInfo objectForKey:@"jid"]];
        
        DDLogMagenta(@"import %@",jid.user);
        
        [self importSilentContactsDictionary:personInfo completionBlock:^(NSError *error, NSString *uuid) {
            
            if(!error && uuid)
                [processedUUIDs addObject:uuid];
            
            if (OSAtomicDecrement32(&itemsCount) == 0)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    if (completion) {
                        completion(error, processedUUIDs);
                    }
                });
            }
        }];
    }
    
    return canImport;
}




- (BOOL)importContactsfromURL:(NSURL *)url
                    completionBlock:(STUserManagerImportCompletionBlock)completion
{
    __block NSError *error = NULL;
    
    dispatch_block_t doneProcessingCompletionBlock = ^{
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (completion) {
                completion(error, NULL);
            }
        });
    };
    
    if([NSString isString: url.pathExtension equalToString:kSilentContacts_Extension])
    {
        return [self importSilentContactsFilefromURL:url completionBlock:completion];
    }
    else if([NSString isString: url.pathExtension equalToString:@"vcf"])
    {
        return [self importVcardFilefromURL:url completionBlock:completion];
        
    }
    
    doneProcessingCompletionBlock();
    return NO;
    
}



@end
