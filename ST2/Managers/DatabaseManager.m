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
#import "DatabaseManager.h"

#import "AddressBookManager.h"
#import "AppDelegate.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "AppTheme.h"
#import "DatabaseActionManager.h"
#import "MessageStreamManager.h"
#import "SCWebAPIManager.h"
#import "STConversation.h"
#import "STDatabaseObject.h"
#import "STImage.h"
#import "STLocalUser.h"
#import "STLogging.h"
#import "STMessage.h"
#import "STNotification.h"
#import "STPreferences.h"
#import "STPublicKey.h"
#import "SCimpSnapshot.h"
#import "STSCloud.h"
#import "STSRVRecord.h"
#import "STSymmetricKey.h"
#import "STUser.h"
#import "STUserManager.h"
#import "STXMPPElement.h"

// Categories
#import "CLLocation+NSDictionary.h"
#import "NSDate+SCDate.h"
#import "NSString+SCUtilities.h"

// Libraries
#import <libkern/OSAtomic.h>
#import <SCCrypto/SCcrypto.h>


#include "git_version_hash.h"

// Log Levels: off, error, warn, info, verbose
// Log Flags : trace
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_INFO;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_WARN;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

NSString *const UIDatabaseConnectionWillUpdateNotification = @"UIDatabaseConnectionWillUpdateNotification";
NSString *const UIDatabaseConnectionDidUpdateNotification = @"UIDatabaseConnectionDidUpdateNotification";
NSString *const kNotificationsKey = @"notifications";
NSString *const kCurrentUserUpdatedKey = @"currentUserUpdatedKey";
NSString *const kCurrentUserIDChangedKey = @"currentUserIDChangedKey";

NSString *const Ext_Relationship          = @"graph";
NSString *const Ext_View_Order            = @"order";
NSString *const Ext_View_Queue            = @"queue";
NSString *const Ext_View_Unread           = @"unread";
NSString *const Ext_View_Action           = @"action";
NSString *const Ext_View_Server           = @"server";
NSString *const Ext_View_NeedsReSend      = @"needsReSend";
NSString *const Ext_View_StatusMessage    = @"statusMessage";
NSString *const Ext_View_HasScloud        = @"hasScloud";
NSString *const Ext_View_HasGeo           = @"hasGeolocation";
NSString *const Ext_View_SavedContacts    = @"savedContacts";
NSString *const Ext_View_LocalContacts    = @"localContacts";
NSString *const Ext_View_FilteredContacts = @"filteredContacts";
NSString *const Ext_SecondaryIndex        = @"idx";
NSString *const Ext_Hooks                 = @"hooks";

NSString *const Cleanup_Key_2_0_6           = @"v2.0.6_upgrade";
NSString *const Cleanup_Key_2_1_scimpStates = @"v2.1_scimpStates";

DatabaseManager *STDatabaseManager;

@interface DatabaseManager()
@property (nonatomic, strong, readwrite) STLocalUser *currentUser;
@end


@implementation DatabaseManager
{
	int32_t contactsViewRetainCount;
	int32_t filteredContactsViewRetainCount;
    
    NSString *currentUserID;
	
	BOOL needsRemoveKeyingMessagesAndStatusMessageView;
	BOOL needsFixOrphanedScimpStates;
}

@synthesize currentUser = currentUser;

+ (void)start
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		STDatabaseManager = [[DatabaseManager alloc] init];
    });
}

+ (instancetype)sharedInstance
{
	if (STDatabaseManager == nil)
	{
		DDLogError(@"Somebody attempted to access STDatabaseManager before the database was setup.");
	}
	
	return STDatabaseManager;
}

+ (NSString *)databasePath
{
 	NSString *databaseName = @"silentText.sqlite";
	
    NSURL *baseURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
	                                                        inDomain:NSUserDomainMask
	                                               appropriateForURL:nil
	                                                          create:YES
	                                                           error:NULL];
    
	NSURL *databaseURL = [baseURL URLByAppendingPathComponent:databaseName isDirectory:NO];
	
	return databaseURL.filePathURL.path;
}

+ (NSString *)blobDirectory
{
	// This method is optimized because it is called very frequently during runtime.
	
	static NSString *blobDirectory = nil;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		NSString *blobDirectoryName = @"blobs";
		
		NSURL *baseURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
																inDomain:NSUserDomainMask
													   appropriateForURL:nil
																  create:YES
																   error:NULL];
		
		NSURL *blobDirectoryURL = [baseURL URLByAppendingPathComponent:blobDirectoryName isDirectory:YES];
		
		[[NSFileManager defaultManager] createDirectoryAtURL:blobDirectoryURL
		                         withIntermediateDirectories:YES
		                                          attributes:nil
		                                               error:NULL];
		
		blobDirectory = blobDirectoryURL.filePathURL.path;
	});
	
	return blobDirectory;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Instance
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@synthesize database = database;
@synthesize uiDatabaseConnection = uiDatabaseConnection;
@synthesize roDatabaseConnection = roDatabaseConnection;
@synthesize rwDatabaseConnection = rwDatabaseConnection;

- (YapDatabaseConnection *)uiDatabaseConnection
{
	NSAssert([NSThread isMainThread], @"Can't use the uiDatabaseConnection outside the main thread");
	
	return uiDatabaseConnection;
}

- (STLocalUser *)currentUser
{
	// This assert is MANDATORY.
	//
	// If you're hitting this assert, then you MUST either:
	// A) use the currentUserWithTransaction method
	// B) Get a reference to the currentUser on the main thread, and then reference it from your background block.
	//
	// Important Note: In the past we had several REALLY BAD bugs because this assert wasn't here.
	// Here's how they went down:
	// - we dispatched a background process to do something, like send a message for the current user
	// - the background process did a bunch of stuff, and then tried to grab the current user,
	//   prior to sending the message from that account
	// - The bug was, of course, that by the time the background process went to grab the current user,
	//   it may have changed.
	// - Then end result was that it was possible to send a message from the WRONG ACCOUNT !!
	//
	// Do NOT remove, or comment out!
	NSAssert([NSThread isMainThread],
	  @"The currentUser property is not thread-safe and can only be accessed on the main thread. "
	  @"Background tasks should use currentUserWithTransaction: to fetch the current user. "
	  @"Or they should fetch and store the currentUser on the main thread, before dispatching their background task.");
	// Do NOT remove, or comment out!
	
	return currentUser;
}

- (id)init
{
	NSAssert(STDatabaseManager == nil, @"Must use sharedInstance singleton (global STDatabaseManager)");
	
	if ((self = [super init]))
	{
		[self setupDatabase];
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The serializer block converts objects into encrypted data blobs.
 *
 * First we use the NSCoding protocol to turn the object into a data blob.
 * Thus all objects that go into the databse need only support the NSCoding protocol.
 * Then we encrypt the data blob.
**/
- (YapDatabaseSerializer)databaseSerializer
{
	YapDatabaseSerializer serializer = ^(NSString *collection, NSString *key, id object){
		
		NSData *pData = [NSKeyedArchiver archivedDataWithRootObject:object];
		NSData *theData = nil;
		
		SCLError err      = kSCLError_NoErr;
        uint8_t *blob     = NULL;
        size_t   blobSize = 0;
		
		err = SCKeyStorageEncrypt(STAppDelegate.storageKey, pData.bytes, pData.length, &blob, &blobSize);
		
		if (IsntSCLError(err) && IsntNull(blob))
		{
			theData = [[NSData alloc] initWithBytesNoCopy:(void *)blob length:blobSize freeWhenDone:YES];
		}
		else
		{
			abort();
		}
		
		return theData;
	};
	
	return serializer;
}

/**
 * The deserializer block converts encrypted data blobs back into objects.
**/
- (YapDatabaseDeserializer)databaseDeserializer
{
	YapDatabaseDeserializer deserializer = ^(NSString *collection, NSString *key, NSData *data){
		
		id object = nil;
		
		if ([data length] > 0)
		{
			SCLError  err      = kSCLError_NoErr;
			uint8_t  *blob     = NULL;
			size_t    blobSize = 0;
			
			err = SCKeyStorageDecrypt(STAppDelegate.storageKey, data.bytes, data.length, &blob, &blobSize);
			
			if (IsntSCLError(err) && IsntNull(blob) && blobSize)
			{
				NSData *pData = [[NSData alloc] initWithBytesNoCopy:(void *)blob length:blobSize freeWhenDone:YES];
				
				object = [NSKeyedUnarchiver unarchiveObjectWithData:pData];
			}
			else
			{
				abort();
			}
		}
		
		if ([object isKindOfClass:[STDatabaseObject class]])
		{
			[object makeImmutable];
		}
		
		return object;
	};
	
	return deserializer;
}

- (YapDatabasePreSanitizer)databasePreSanitizer
{
	YapDatabasePreSanitizer preSanitizer = ^(NSString *collection, NSString *key, id object){
		
		if ([object isKindOfClass:[STDatabaseObject class]])
		{
			[object makeImmutable];
		}
		
		return object;
	};
	
	return preSanitizer;
}

- (YapDatabasePostSanitizer)databasePostSanitizer
{
	YapDatabasePostSanitizer postSanitizer = ^(NSString *collection, NSString *key, id object){
		
		if ([object isKindOfClass:[STDatabaseObject class]])
		{
			[object clearChangedProperties];
		}
	};
	
	return postSanitizer;
}

- (void)setupDatabase
{
	NSString *databasePath = [[self class] databasePath];
	DDLogOrange(@"databasePath = %@", databasePath);
	
	currentUser = nil;
    currentUserID = nil;

	// Configure custom class mappings
	
	[NSKeyedUnarchiver setClass:[STImage class] forClassName:@"STThumbnail"];
    [NSKeyedUnarchiver setClass:[SCimpSnapshot class] forClassName:@"STScimpState"];
	[NSKeyedUnarchiver setClass:[SCimpSnapshot class] forClassName:@"STScimpStateObject"];
    
	// Create the database
	
	database = [[YapDatabase alloc] initWithPath:databasePath
	                                             serializer:[self databaseSerializer]
	                                           deserializer:[self databaseDeserializer]
	                                           preSanitizer:[self databasePreSanitizer]
	                                          postSanitizer:[self databasePostSanitizer]
	                                                options:nil];
	
	database.defaultObjectPolicy = YapDatabasePolicyShare;
	database.defaultMetadataPolicy = YapDatabasePolicyShare;
	
	// Setup all the extensions
	
	[self setupRelationship];
	[self setupOrderView];
	[self setupQueueView];
	[self setupUnreadView];
    [self setupActionView];
	[self setupServerView];
    [self setupNeedsResendView];
    [self setupHasScloudView];
    [self setupHasGeoView];
	[self setupSavedContactsView];
	[self setupLocalContactsView];
	[self setupSecondaryIndex];
	[self setupHooks];
	
	// Check for needed cleanup
	//
	// We need a better mechanism for this...
	
	if (![[NSUserDefaults standardUserDefaults] boolForKey:Cleanup_Key_2_0_6])
	{
		[self setupStatusMessageView];
		needsRemoveKeyingMessagesAndStatusMessageView = YES;
	}
	
	if (![[NSUserDefaults standardUserDefaults] boolForKey:Cleanup_Key_2_1_scimpStates])
	{
		needsFixOrphanedScimpStates = YES;
	}
	
	// Create a dedicated read-only connection for the UI (main thread).
	// It will use a longLivedReadTransaction,
	// and uses the UIDatabaseConnectionModifiedNotification to post when it updates.
	
	uiDatabaseConnection = [database newConnection];
	uiDatabaseConnection.objectCacheLimit = 500;
	uiDatabaseConnection.metadataCacheLimit = 500;
	uiDatabaseConnection.name = @"uiDatabaseConnection";
	#if DEBUG
	uiDatabaseConnection.permittedTransactions = YDB_MainThreadOnly | YDB_AnyReadTransaction;
//	uiDatabaseConnection.permittedTransactions = YDB_MainThreadOnly | YDB_SyncReadTransaction /* NO asyncReads! */;
	#endif
	
	// Create convenience connections for other classes.
	// They can be used by classes that don't need a dedicated connection.
	// Basically it helps to cut down on [database newConnection] one-off's.
	
	roDatabaseConnection = [database newConnection];
	roDatabaseConnection.objectCacheLimit = 200;
	roDatabaseConnection.metadataCacheLimit = 200;
	roDatabaseConnection.name = @"roDatabaseConnection";
	#if DEBUG
	roDatabaseConnection.permittedTransactions = YDB_AnyReadTransaction;
	#endif
	
	rwDatabaseConnection = [database newConnection];
	rwDatabaseConnection.objectCacheLimit = 200;
	rwDatabaseConnection.metadataCacheLimit = 200;
	rwDatabaseConnection.name = @"rwDatabaseConnection";
	
	//
	// Start the longLivedReadTransaction on the UI connection.
	//
	
	[uiDatabaseConnection enableExceptionsForImplicitlyEndingLongLivedReadTransaction];
	[uiDatabaseConnection beginLongLivedReadTransaction];

    // initialize the current User
    [uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
		currentUserID = [transaction objectForKey:prefs_selectedUserId inCollection:kSCCollection_Prefs];
		if (currentUserID)
		{
			currentUser = [transaction objectForKey:currentUserID inCollection:kSCCollection_STUsers];
		}
    }];
	
	if (currentUser)
	{
		NSAssert([currentUser isKindOfClass:[STLocalUser class]], @"Oops");
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(yapDatabaseModified:)
	                                             name:YapDatabaseModifiedNotification
	                                           object:database];
}

- (void)setupRelationship
{
	//
	// GRAPH RELATIONSHIP
	//
	// Create "graph" extension.
	// It manages relationships between objects, and handles cascading deletes.
	//
	
	NSSet *whitelist = [NSSet setWithObjects:kSCCollection_STImage_Message, kSCCollection_STUsers, nil];
	
	YapDatabaseRelationshipOptions *relationshipOptions = [[YapDatabaseRelationshipOptions alloc] init];
	relationshipOptions.allowedCollections = [[YapWhitelistBlacklist alloc] initWithWhitelist:whitelist];
	
	relationshipOptions.destinationFilePathEncryptor = ^NSData* (NSString *dstFilePath){
		
		NSData *unencryptedData = [dstFilePath dataUsingEncoding:NSUTF8StringEncoding];
		NSData *encryptedData = nil;
		
		uint8_t *blob = NULL;
		size_t   blobSize = 0;
		SCLError err = SCKeyStorageEncrypt(STAppDelegate.storageKey,
		                                   unencryptedData.bytes, unencryptedData.length,
		                                   &blob, &blobSize);
		
		if (IsntSCLError(err) && IsntNull(blob))
		{
			encryptedData = [[NSData alloc] initWithBytesNoCopy:(void *)blob
			                                             length:blobSize
			                                       freeWhenDone:YES];
		}
		
		return encryptedData;
	};
	relationshipOptions.destinationFilePathDecryptor = ^NSString* (NSData *encryptedData){
		
		NSString *dstFilePath = nil;
		NSData *unencryptedData = nil;
		
		uint8_t *blob = NULL;
		size_t blobSize = 0;
		SCLError err = SCKeyStorageDecrypt(STAppDelegate.storageKey,
		                                   encryptedData.bytes, encryptedData.length,
		                                   &blob, &blobSize);
		
		if (IsntSCLError(err) && IsntNull(blob))
		{
			unencryptedData = [[NSData alloc] initWithBytesNoCopy:(void *)blob
			                                               length:blobSize
			                                         freeWhenDone:YES];
		}
		
		dstFilePath = [[NSString alloc] initWithData:unencryptedData encoding:NSUTF8StringEncoding];
		return dstFilePath;
	};
	
	YapDatabaseRelationship *graph =
	  [[YapDatabaseRelationship alloc] initWithVersionTag:@"2" options:relationshipOptions];
	
	NSString *extName = Ext_Relationship;
	[database asyncRegisterExtension:graph withName:extName completionBlock:^(BOOL ready) {
		
		if (!ready) {
			DDLogError(@"Error registering \"%@\" !!!", extName);
		}
	}];
}

- (void)setupOrderView
{
	//
	// ORDER VIEW
	//
	// Sorts:
	//  - messages by timestamp
	//  - conversations by lastUpdated
	//  - scloud items by timestamp
	//
	// We use it to order messages and conversation in their respective view controllers.
	//
	
	YapDatabaseViewGrouping *orderGrouping = [YapDatabaseViewGrouping withObjectBlock:
	    ^NSString *(NSString *collection, NSString *key, id object)
	{
		if ([object isKindOfClass:[STConversation class]])
		{
			STConversation *conversation = (STConversation *)object;
			if (conversation.hidden)
				return nil;        // exclude from conversationsTableView
			else
				return collection; // collection == STConversation.userId == STUser.uuid
		}
		if ([object isKindOfClass:[STMessage class]])
		{
			return collection; // collection == STMessage.conversationId == STConversation.uuid
		}
        if ([object isKindOfClass:[STSCloud class]])
		{
			return collection; // collection == kSCCollection_STSCloud
		}
		
		return nil; // exclude from view
	}];
	
	YapDatabaseViewSorting *orderSorting = [YapDatabaseViewSorting withObjectBlock:
	    ^(NSString *group, NSString *collection1, NSString *key1, id obj1,
	                       NSString *collection2, NSString *key2, id obj2)
	{
		if ([obj1 isKindOfClass:[STConversation class]])
		{
			__unsafe_unretained STConversation *conversation1 = (STConversation *)obj1;
			__unsafe_unretained STConversation *conversation2 = (STConversation *)obj2;
			
			// We want:
			// - Most recent conversation at index 0.
			// - Least recent conversation at the end.
			//
			// This is descending order (opposite of "standard" in Cocoa) so we swap the normal comparison.
			
			NSComparisonResult cmp = [conversation1 compareByLastUpdated:conversation2];
			
			if (cmp == NSOrderedAscending) return NSOrderedDescending;
			if (cmp == NSOrderedDescending) return NSOrderedAscending;
			return NSOrderedSame;
		}
		else if ([obj1 isKindOfClass:[STMessage class]])
		{
			__unsafe_unretained STMessage *message1 = (STMessage *)obj1;
			__unsafe_unretained STMessage *message2 = (STMessage *)obj2;
			
			// We want:
			// - Oldest message at index 0.
			// - Newest message at the end.
			//
			// This is standard ascending order.
			
			return [message1 compareByTimestamp:message2];
		}
        else // if ([obj1 isKindOfClass:[STSCloud class]])
		{
			__unsafe_unretained STSCloud *scloud1 = (STSCloud *)obj1;
			__unsafe_unretained STSCloud *scloud2 = (STSCloud *)obj2;
			
			// We want:
			// - Oldest scloud at index 0.
			// - Newest scloud at the end.
			//
			// This is standard ascending order.
			
			return [scloud1 compareByTimestamp:scloud2];
		}
	}];
	
	YapDatabaseView *orderView =
	  [[YapDatabaseView alloc] initWithGrouping:orderGrouping
	                                    sorting:orderSorting
	                                 versionTag:@"2014-12-30"];
	
	NSString *const extName = Ext_View_Order;
	[database asyncRegisterExtension:orderView withName:extName completionBlock:^(BOOL ready) {
		
		if (!ready) {
			DDLogError(@"Error registering \"%@\" !!!", extName);
		}
	}];
}

- (void)setupQueueView
{
	//
	// QUEUE VIEW
	//
	// The outgoing queue for the xmppStream(s).
	// Stores STMessage & STXMPPElement items, grouped by userId, sorted by timestamp.
	//
	
	YapDatabaseViewGrouping *queueGrouping = [YapDatabaseViewGrouping withObjectBlock:
	    ^NSString *(NSString *collection, NSString *key, id object)
	{
		if ([object isKindOfClass:[STMessage class]])
		{
			__unsafe_unretained STMessage *message = (STMessage *)object;
			
			if (message.statusMessage || !message.isOutgoing)
			{
				return nil;
			}
			else if (message.serverAckDate == nil)
			{
				if (message.timestamp == nil)
				{
					DDLogWarn(@"Found STMessage with nil timestamp");
					return nil;
				}
				
				return message.userId;
			}
		}
		else if ([object isKindOfClass:[STXMPPElement class]])
		{
			__unsafe_unretained STXMPPElement *element = (STXMPPElement *)object;
			
			return element.localUserID;
		}
		
		return nil; // exclude from view
	}];
	
	YapDatabaseViewSorting *queueSorting = [YapDatabaseViewSorting withObjectBlock:
	    ^(NSString *group, NSString *collection1, NSString *key1, id obj1,
	                       NSString *collection2, NSString *key2, id obj2)
	{
		NSDate *(^TimestampForObj)(id) = ^NSDate *(id obj){
			
			NSDate *timestamp = nil;
			
			if ([obj isKindOfClass:[STMessage class]])
			{
				timestamp = [(STMessage *)obj timestamp];
			}
			else if ([obj isKindOfClass:[STXMPPElement class]])
			{
				timestamp = [(STXMPPElement *)obj timestamp];
			}
			
			return timestamp;
		};
		
		NSDate *timestamp1 = TimestampForObj(obj1);
		NSDate *timestamp2 = TimestampForObj(obj2);
		
		NSAssert(timestamp1 != nil, @"timestamp1 is nil");
		NSAssert(timestamp2 != nil, @"timestamp2 is nil");
		
		return [timestamp1 compare:timestamp2];
	}];
	
	YapDatabaseView *queueView =
	  [[YapDatabaseView alloc] initWithGrouping:queueGrouping
	                                    sorting:queueSorting
	                                      versionTag:@"2c"];
	
	NSString *const extName = Ext_View_Queue;
	[database asyncRegisterExtension:queueView withName:extName completionBlock:^(BOOL ready) {
		
		if (!ready) {
			DDLogError(@"Error registering \"%@\" !!!", extName);
		}
	}];
}

- (void)setupUnreadView
{
	//
	// UNREAD VIEW
	//
	// Sorts unread messages by conversationId & timestamp.
	// We use it to quickly calculate unread counts by conversation and user.
	//
	
	YapDatabaseViewGrouping *unreadGrouping = [YapDatabaseViewGrouping withObjectBlock:
	    ^NSString *(NSString *collection, NSString *key, id object)
	{
		if ([object isKindOfClass:[STMessage class]])
		{
			__unsafe_unretained STMessage *message = (STMessage *)object;
			
			if (!message.isRead)
			{
				// Place all unread messages for the conversation in the same group.
				//
				// view[Ext_View_Unread] = @{
				//
				//     @"conversationId-1" : @[msgId3, msgId4, msgId5],
				//     @"conversationId-2" : @[msgId8]
				// }
				
				return message.conversationId; // add or update in view
			}
		}
		
		return nil; // exclude from view
	}];
	
	YapDatabaseViewSorting *unreadSorting = [YapDatabaseViewSorting withObjectBlock:
	    ^(NSString *group, NSString *collection1, NSString *key1, id obj1,
	                       NSString *collection2, NSString *key2, id obj2)
	{
		__unsafe_unretained STMessage *message1 = (STMessage *)obj1;
		__unsafe_unretained STMessage *message2 = (STMessage *)obj2;
		
		// Sorting by timestamp:
		// - Oldest message at index 0
		// - Newest message at the end
		//
		// This is standard ascending order.
		
		return [message1.timestamp compare:message2.timestamp];
	}];
	
	YapDatabaseView *unreadView =
	  [[YapDatabaseView alloc] initWithGrouping:unreadGrouping
	                                    sorting:unreadSorting];
	
	NSString *const extName = Ext_View_Unread;
	[database asyncRegisterExtension:unreadView withName:extName completionBlock:^(BOOL ready) {
		
		if (!ready) {
			DDLogError(@"Error registering \"%@\" !!!", extName);
		}
	}];
}

- (void)setupActionView
{
	//
	// ACTION VIEW
	//
	// Includes anything that needs to be acted upon by the DatabaseActionManager.
	// For example:
	//
	// - burning messages
	// - deleting expired private keys
	//
	
	YapDatabaseViewGrouping *grouping = [YapDatabaseViewGrouping withObjectBlock:
	    ^NSString *(NSString *collection, NSString *key, id object)
	{
		if ([object isKindOfClass:[STLocalUser class]])
		{
			__unsafe_unretained STLocalUser *localUser = (STLocalUser *)object;
			
			// Note: We do NOT take into account subscriptionAutoRenews here.
			// Because even if an account is supposed to auto-renew, the credit card authorization may fail.
			// Meaning their account can still expire.
			
			if (!localUser.subscriptionHasExpired && localUser.subscriptionExpireDate)
			{
				return @"";
			}
			else if (localUser.nextWebRefresh || localUser.nextKeyGeneration)
			{
				return @"";
			}
		}
		else if ([object isKindOfClass:[STUser class]]) // MUST come after STLocalUser check
		{
			__unsafe_unretained STUser *user = (STUser *)object;
			
			if (user.nextWebRefresh)
			{
				return @"";
			}
		}
		else if ([object isKindOfClass:[STMessage class]])
		{
			__unsafe_unretained STMessage *message = (STMessage *)object;
			
			// A message may be shredable, but doesn't have a shredDate yet.
			// We're not concerned with those messages.
			//
			// Eventually, the user will look at them, the shredDate will be set,
			// and at that point the message will be automatically added to this view.
			
			if (message.shredDate != nil)
			{
				return @"";
			}
		}
		else if ([object isKindOfClass:[STPublicKey class]])
		{
			__unsafe_unretained STPublicKey *publicKey = (STPublicKey *)object;
			
			if ((publicKey.expireDate != nil) && !publicKey.isExpired)
			{
				return @"";
			}
		}
		else if ([object isKindOfClass:[STSymmetricKey class]])
		{
			__unsafe_unretained STSymmetricKey *symKey = (STSymmetricKey *)object;
			
			if (symKey.recycleDate != nil || symKey.expireDate != nil)
			{
				return @"";
			}
		}
		else if ([object isKindOfClass:[STSRVRecord class]])
		{
			__unsafe_unretained STSRVRecord *srvRecord = (STSRVRecord *)object;
			
			if (srvRecord.expireDate != nil)
			{
				return @"";
			}
		}
        else if ([object isKindOfClass:[STSCloud class]])
		{
			__unsafe_unretained STSCloud *scl = (STSCloud *)object;
            
			if (scl.isCached && scl.unCacheDate && !scl.dontExpire)
			{
				return @"";
			}
		}
        else if ([object isKindOfClass:[STNotification class]])
        {
            __unsafe_unretained STNotification *noteRecord = (STNotification *)object;
            
            if (noteRecord.fireDate != nil)
            {
                return @"";
            }
        }
        
		return nil; // exclude from view
	}];
	
	YapDatabaseViewSorting *sorting = [YapDatabaseViewSorting withObjectBlock:
	    ^(NSString *group, NSString *collection1, NSString *key1, id obj1,
                           NSString *collection2, NSString *key2, id obj2)
	{
		NSDate *(^ActionDateForObj)(id) = ^NSDate *(id obj){
			
			NSDate *actionDate = nil;
			
			if ([obj isKindOfClass:[STLocalUser class]])
			{
				__unsafe_unretained STLocalUser *localUser = (STLocalUser *)obj;
				
				if (!localUser.subscriptionHasExpired && localUser.subscriptionExpireDate)
				{
					NSDate *date1 = localUser.subscriptionExpireDate;
					NSDate *date2 = localUser.nextWebRefresh;
					NSDate *date3 = localUser.nextKeyGeneration;
				
					actionDate = SCEarliestDate3(date1, date2, date3);
				}
				else
				{
					NSDate *date1 = localUser.nextWebRefresh;
					NSDate *date2 = localUser.nextKeyGeneration;
					
					actionDate = SCEarliestDate2(date1, date2);
				}
			}
			else if ([obj isKindOfClass:[STUser class]]) // MUST come after STLocalUser check
			{
				actionDate = [(STUser *)obj nextWebRefresh];
			}
			else if ([obj isKindOfClass:[STMessage class]])
			{
				actionDate = [(STMessage *)obj shredDate];
			}
			else if ([obj isKindOfClass:[STPublicKey class]])
			{
				actionDate = [(STPublicKey *)obj expireDate];
			}
			else if ([obj isKindOfClass:[STSymmetricKey class]])
			{
				NSDate *date1 = [(STSymmetricKey *)obj expireDate];
				NSDate *date2 = [(STSymmetricKey *)obj recycleDate];
				
				actionDate = SCEarliestDate2(date1, date2);
			}
			else if ([obj isKindOfClass:[STSRVRecord class]])
			{
				actionDate = [(STSRVRecord *)obj expireDate];
			}
			else if ([obj isKindOfClass:[STSCloud class]])
			{
				actionDate = [(STSCloud *)obj unCacheDate];
			}
			else if ([obj isKindOfClass:[STNotification class]])
			{
				actionDate = [(STNotification *)obj fireDate];
			}
			
			return actionDate;
		};
		
		NSDate *actionDate1 = ActionDateForObj(obj1);
		NSDate *actionDate2 = ActionDateForObj(obj2);
        
        NSAssert(actionDate1 != nil, @"expireDate1 was nil");
        NSAssert(actionDate2 != nil, @"expireDate2 was nil");
        
		return [actionDate1 compare:actionDate2];
	}];
	
	YapDatabaseView *view =
	  [[YapDatabaseView alloc] initWithGrouping:grouping
	                                    sorting:sorting
	                                 versionTag:@"2.3"];
	
	NSString *const extName = Ext_View_Action;
	[database asyncRegisterExtension:view withName:extName completionBlock:^(BOOL ready) {
		
		if (ready) {
			// Start the DatabaseActionManager (which uses this view).
			[DatabaseActionManager initialize];
		}
		else {
			DDLogError(@"Error registering \"%@\" !!!", extName);
		}
	}];
}

- (void)setupServerView
{
	//
	// SERVER VIEW
	//
	// Flags items in the database that need to be synced with the server.
	// For example:
	//
	// - user needs another public key generated
	// - public key needs to be uploaded
	// - public key needs to be removed from server
	//
	// Todo: Replace this view with a YapDatabaseSet (once implemented)
	//
	
	YapDatabaseViewGrouping *grouping = [YapDatabaseViewGrouping withObjectBlock:
	    ^NSString *(NSString *collection, NSString *key, id object)
	{
		if ([object isKindOfClass:[STLocalUser class]])
		{
			__unsafe_unretained STLocalUser *localUser = (STLocalUser *)object;
			
			if (localUser.needsKeyGeneration       ||
			    localUser.needsRegisterPushToken   ||
				localUser.needsDeprovisionUser     ||
			    localUser.awaitingReKeying          )
			{
				return @"";
			}
		}
		else if ([object isKindOfClass:[STUser class]])
		{
			__unsafe_unretained STUser *user = (STUser *)object;
			
			if (user.awaitingReKeying)
			{
				return @"";
			}
		}
		else if ([object isKindOfClass:[STPublicKey class]])
		{
			__unsafe_unretained STPublicKey *key = (STPublicKey *)object;
			
			if (key.isPrivateKey)
			{
				if (key.serverUploadDate == nil || key.needsServerDelete)
				{
					return @"";
				}
			}
		}
		
		return nil;
	}];
	
	YapDatabaseViewSorting *sorting = [YapDatabaseViewSorting withKeyBlock:
	    ^NSComparisonResult(NSString *group, NSString *collection1, NSString *key1,
	                                         NSString *collection2, NSString *key2)
	{
		// We don't actually care about sorting,
		// because we're treating this view like a set.
		//
		// This will get removed when we migrate to YapDatabaseSet.
		
		NSComparisonResult result = [collection1 compare:collection2];
		if (result == NSOrderedSame)
		{
			result = [key1 compare:key2];
		}
		
		return result;
	}];
	
	NSArray *collections = @[ kSCCollection_STPublicKeys, kSCCollection_STUsers ];
	
	YapWhitelistBlacklist *allowedCollections =
	  [[YapWhitelistBlacklist alloc] initWithWhitelist:[NSSet setWithArray:collections]];
	
	YapDatabaseViewOptions *options = [[YapDatabaseViewOptions alloc] init];
	options.allowedCollections = allowedCollections;
	
	YapDatabaseView *view = [[YapDatabaseView alloc] initWithGrouping:grouping
	                                                          sorting:sorting
	                                                       versionTag:@"2.2 C"
	                                                          options:options];
	
	NSString *const extName = Ext_View_Server;
	[database asyncRegisterExtension:view withName:extName completionBlock:^(BOOL ready) {
		
		if (!ready) {
			DDLogError(@"Error registering \"%@\" !!!", extName);
		}
	}];
}

- (void)setupNeedsResendView
{
	//
	// NEEDSRESEND VIEW
	//
	// Messages that failed to send for whatever reason (grouped by conversation, sorted by timestamp)
	// We use it to determine if a conversation has failed messages,
	// and if so, we display the exclamation image next to the conversation.
	//
	
	YapDatabaseViewGrouping *grouping = [YapDatabaseViewGrouping withObjectBlock:
	    ^NSString *(NSString *collection, NSString *key, id object)
	{
		if ([object isKindOfClass:[STMessage class]])
		{
			__unsafe_unretained STMessage *message = (STMessage *)object;
			
			if (message.needsReSend)
			{
				// Place all needsReSend messages for the conversation in the same group.
				//
				// view[Ext_View_NeedsReSend] = @{
				//
				//     @"conversationId-1" : @[msgId3, msgId4, msgId5],
				//     @"conversationId-2" : @[msgId8]
				// }
				
				return message.conversationId; // add or update in view
			}
		}
		
		return nil; // exclude from view
	}];
	
	YapDatabaseViewSorting *sorting = [YapDatabaseViewSorting withObjectBlock:
	    ^(NSString *group, NSString *collection1, NSString *key1, id obj1,
	                       NSString *collection2, NSString *key2, id obj2)
	{
		__unsafe_unretained STMessage *message1 = (STMessage *)obj1;
		__unsafe_unretained STMessage *message2 = (STMessage *)obj2;
		
		// Sorting by timestamp:
		// - Oldest message at index 0
		// - Newest message at the end
		//
		// This is standard ascending order.
		
		return [message1.timestamp compare:message2.timestamp];
	}];
	
	YapDatabaseView *view =
	  [[YapDatabaseView alloc] initWithGrouping:grouping
	                                    sorting:sorting];
	
	NSString *const extName = Ext_View_NeedsReSend;
	[database asyncRegisterExtension:view withName:extName completionBlock:^(BOOL ready) {
		
		if (!ready) {
			DDLogError(@"Error registering \"%@\" !!!", extName);
		}
	}];
}

- (void)setupStatusMessageView
{
	//
	// STATUSMESSAGE VIEW
	//
	// Sorts status messages (like scimp keying) by timestamp.
	// We use it to quickly find, and delete, status messages.
	//
	
	YapDatabaseViewGrouping *grouping = [YapDatabaseViewGrouping withObjectBlock:
	    ^NSString *(NSString *collection, NSString *key, id object)
	{
		if ([object isKindOfClass:[STMessage class]])
		{
			__unsafe_unretained STMessage *message = (STMessage *)object;
			
			if (message.statusMessage)
			{
				// Place all statusMessage messages for the conversation in the same group.
				//
				// view[Ext_View_StatusMessage] = @{
				//
				//     @"conversationId-1" : @[msgId3, msgId4, msgId5],
				//     @"conversationId-2" : @[msgId8]
				// }
				
				return message.conversationId; // add or update in view
			}
		}
		
		return nil; // exclude from view
	}];
	
	YapDatabaseViewSorting *sorting = [YapDatabaseViewSorting withObjectBlock:
	    ^(NSString *group, NSString *collection1, NSString *key1, id obj1,
	                       NSString *collection2, NSString *key2, id obj2)
	{
		__unsafe_unretained STMessage *message1 = (STMessage *)obj1;
		__unsafe_unretained STMessage *message2 = (STMessage *)obj2;
		
		// Sorting by timestamp:
		// - Oldest message at index 0
		// - Newest message at the end
		//
		// This is standard ascending order.
		
		return [message1.timestamp compare:message2.timestamp];
	}];
	
	YapDatabaseView *view =
      [[YapDatabaseView alloc] initWithGrouping:grouping
                                        sorting:sorting];
	
	NSString *const extName = Ext_View_StatusMessage;
	[database asyncRegisterExtension:view withName:extName completionBlock:^(BOOL ready) {
		
		if (!ready) {
			DDLogError(@"Error registering \"%@\" !!!", extName);
		}
	}];
}

- (void)setupHasScloudView
{
	//
	// HASSCLOUD VIEW
	//
	// Sorts messages that have scloudIDs by conversationId & timestamp.
	// We use it to display all the media for a given conversation.
	//
	
	YapDatabaseViewGrouping *grouping = [YapDatabaseViewGrouping withObjectBlock:
	    ^NSString *(NSString *collection, NSString *key, id object)
	{
		if ([object isKindOfClass:[STMessage class]])
		{
			__unsafe_unretained STMessage *message = (STMessage *)object;
			
			if (message.scloudID)
			{
				// Place all hasScloud messages for the conversation in the same group.
				//
				// view[Ext_View_HasScloud] = @{
				//
				//     @"conversationId-1" : @[msgId3, msgId4, msgId5],
				//     @"conversationId-2" : @[msgId8]
				// }
				
				return message.conversationId; // add or update in view
			}
		}
		
		return nil; // exclude from view
	}];
	
	YapDatabaseViewSorting *sorting = [YapDatabaseViewSorting withObjectBlock:
	    ^(NSString *group, NSString *collection1, NSString *key1, id obj1,
	                       NSString *collection2, NSString *key2, id obj2)
	{
		__unsafe_unretained STMessage *message1 = (STMessage *)obj1;
		__unsafe_unretained STMessage *message2 = (STMessage *)obj2;
		
		// Sorting by timestamp:
		// - Oldest message at index 0
		// - Newest message at the end
		//
		// This is standard ascending order.
		
		return [message1.timestamp compare:message2.timestamp];
	}];
	
	YapDatabaseView *view =
	  [[YapDatabaseView alloc] initWithGrouping:grouping
	                                    sorting:sorting];
	
	NSString *const extName = Ext_View_HasScloud;
	[database asyncRegisterExtension:view withName:extName completionBlock:^(BOOL ready) {
		
		if (!ready) {
			DDLogError(@"Error registering \"%@\" !!!", extName);
		}
	}];
}

- (void)setupHasGeoView
{
	//
	// HAS GEOLOCATION VIEW
	//
	// Sorts messages that have geoloaction information  by conversationId & timestamp.
	// We use it to display all the geo location mapping information for a given conversation.
	//
	
	YapDatabaseViewGrouping *grouping = [YapDatabaseViewGrouping withObjectBlock:
	    ^NSString *(NSString *collection, NSString *key, id object)
	{
		if ([object isKindOfClass:[STMessage class]])
		{
			__unsafe_unretained STMessage *message = (STMessage *)object;
			
			if (message.hasGeo)
			{
				// Place all hasGeo messages for the conversation in the same group.
				//
				// view[Ext_View_HasGeo] = @{
				//
				//     @"conversationId-1" : @[msgId3, msgId4, msgId5],
				//     @"conversationId-2" : @[msgId8]
				// }
				
				return message.conversationId; // add or update in view
			}
		}
		
		return nil; // exclude from view
	}];
	
	YapDatabaseViewSorting *sorting = [YapDatabaseViewSorting withObjectBlock:
	    ^(NSString *group, NSString *collection1, NSString *key1, id obj1,
                           NSString *collection2, NSString *key2, id obj2)
	{
		__unsafe_unretained STMessage *message1 = (STMessage *)obj1;
		__unsafe_unretained STMessage *message2 = (STMessage *)obj2;
		
		// Sorting by timestamp:
		// - Oldest message at index 0
		// - Newest message at the end
		//
		// This is standard ascending order.
		
		return [message1.timestamp compare:message2.timestamp];
	}];
	
	YapDatabaseView *hasGeoView =
	  [[YapDatabaseView alloc] initWithGrouping:grouping
	                                    sorting:sorting];
	
	NSString *const extName = Ext_View_HasGeo;
	[database asyncRegisterExtension:hasGeoView withName:extName completionBlock:^(BOOL ready) {
		
		if (!ready) {
			DDLogError(@"Error registering \"%@\" !!!", extName);
		}
	}];
}

- (void)setupSavedContactsView
{
	//
	// SAVED CONTACTS VIEW
	//
	// Sorts all saved contacts by name (localized)
	//
	// Saved => STUser.isSavedToSilentContacts
	//
	
	UILocalizedIndexedCollation *localizedIndexedCollation = [UILocalizedIndexedCollation currentCollation];
	
	YapDatabaseViewGrouping *grouping = [YapDatabaseViewGrouping withObjectBlock:
	    ^NSString *(NSString *collection, NSString *key, id object)
	{
		if ([object isKindOfClass:[STUser class]])
		{
			__unsafe_unretained STUser *user = (STUser *)object;
			if (user.isSavedToSilentContacts)
			{
				NSInteger section = [localizedIndexedCollation sectionForObject:object
				                                        collationStringSelector:@selector(displayName)];
				
				return [localizedIndexedCollation.sectionIndexTitles objectAtIndex:section];
			}
		}
		
		return nil; // exclude from view
	}];
	
	YapDatabaseViewSorting *sorting = [YapDatabaseViewSorting withObjectBlock:
	    ^(NSString *group, NSString *collection1, NSString *key1, id obj1,
	                       NSString *collection2, NSString *key2, id obj2)
	{
		__unsafe_unretained STUser *user1 = (STUser *)obj1;
		__unsafe_unretained STUser *user2 = (STUser *)obj2;
		
		NSString *name1 = user1.displayName;
		NSString *name2 = user2.displayName;
		
		NSComparisonResult result = [name1 localizedStandardCompare:name2];
		
		if (result == NSOrderedSame) { // If display name is the same, fall back to JID sort
			result = [user1.jid.bare compare:user2.jid.bare];
		}
		
		return result;
	}];
	
	NSSet *whitelist = [NSSet setWithObject:kSCCollection_STUsers];
	
	YapDatabaseViewOptions *options = [[YapDatabaseViewOptions alloc] init];
	options.allowedCollections = [[YapWhitelistBlacklist alloc] initWithWhitelist:whitelist];
	
	NSString *version = @"6";
	NSString *locale = [[NSLocale currentLocale] localeIdentifier];
	
	NSString *tag = [NSString stringWithFormat:@"%@-%@", version, locale];
	
	YapDatabaseView *view =
	  [[YapDatabaseView alloc] initWithGrouping:grouping
	                                    sorting:sorting
	                                 versionTag:tag
	                                    options:options];
	
	NSString *const extName = Ext_View_SavedContacts;
	[database asyncRegisterExtension:view withName:extName completionBlock:^(BOOL ready) {
		
		if (!ready) {
			DDLogError(@"Error registering \"%@\" !!!", extName);
		}
	}];
}

- (void)setupLocalContactsView
{
	//
	// LOCAL CONTACTS VIEW
	//
	// Sorts all localUsers by name (localized)
	//
	
	YapDatabaseViewGrouping *contactsGrouping = [YapDatabaseViewGrouping withObjectBlock:
	    ^NSString *(NSString *collection, NSString *key, id object)
	{
		if ([object isKindOfClass:[STUser class]])
		{
			__unsafe_unretained STUser *user = (STUser *)object;
			if (user.isLocal)
			{
				return @"";
			}
		}
		
		return nil; // exclude from view
	}];
	
	YapDatabaseViewSorting *contactsSorting = [YapDatabaseViewSorting withObjectBlock:
	    ^(NSString *group, NSString *collection1, NSString *key1, id obj1,
	                       NSString *collection2, NSString *key2, id obj2)
	{
		__unsafe_unretained STUser *user1 = (STUser *)obj1;
		__unsafe_unretained STUser *user2 = (STUser *)obj2;
		
		NSString *name1 = user1.displayName;
		NSString *name2 = user2.displayName;
		
		NSComparisonResult result = [name1 localizedStandardCompare:name2];
		
		if (result == NSOrderedSame) { // If display name is the same, fall back to JID sort
			result = [user1.jid.bare compare:user2.jid.bare];
		}
		
		return result;
	}];
	
	NSSet *whitelist = [NSSet setWithObject:kSCCollection_STUsers];
	
	YapDatabaseViewOptions *options = [[YapDatabaseViewOptions alloc] init];
	options.allowedCollections = [[YapWhitelistBlacklist alloc] initWithWhitelist:whitelist];
	
	NSString *version = @"6";
	NSString *locale = [[NSLocale currentLocale] localeIdentifier];
	
	NSString *tag = [NSString stringWithFormat:@"%@-%@", version, locale];
	
	YapDatabaseView *view =
	  [[YapDatabaseView alloc] initWithGrouping:contactsGrouping
	                                    sorting:contactsSorting
	                                 versionTag:tag
	                                    options:options];
	
	NSString *const extName = Ext_View_LocalContacts;
	[database asyncRegisterExtension:view withName:extName completionBlock:^(BOOL ready) {
		
		if (!ready) {
			DDLogError(@"Error registering \"%@\" !!!", extName);
		}
	}];
}

- (void)setupSecondaryIndex
{
	//
	// SECONDARY INDEX
	//
	// Indexes the following:
	//
	// - HASH(STUser.jid)
	//   -> for quickly looking up a user by their JID.
	//
	
	YapDatabaseSecondaryIndexSetup *secondaryIdxSetup = [[YapDatabaseSecondaryIndexSetup alloc] init];
	[secondaryIdxSetup addColumn:@"hash" withType:YapDatabaseSecondaryIndexTypeText];
	
	YapDatabaseSecondaryIndexHandler *secondaryIdxHandler = [YapDatabaseSecondaryIndexHandler withObjectBlock:
	    ^(NSMutableDictionary *dict, NSString *collection, NSString *key, id object)
	{
		if ([object isKindOfClass:[STUser class]])
		{
			__unsafe_unretained STUser *user = (STUser *)object;
			
			NSString *jidHash = [self hashStr:[user.jid bare]];
			if (jidHash)
			{
				[dict setObject:jidHash forKey:@"hash"];
			}
		}
	}];

	NSSet *whitelist = [NSSet setWithObject:kSCCollection_STUsers];
	
	YapDatabaseSecondaryIndexOptions *secondaryIdxOptions = [[YapDatabaseSecondaryIndexOptions alloc] init];
	secondaryIdxOptions.allowedCollections = [[YapWhitelistBlacklist alloc] initWithWhitelist:whitelist];
	
	YapDatabaseSecondaryIndex *secondaryIndex =
	  [[YapDatabaseSecondaryIndex alloc] initWithSetup:secondaryIdxSetup
	                                           handler:secondaryIdxHandler
	                                        versionTag:@"2"
	                                           options:secondaryIdxOptions];

	NSString *const extName = Ext_SecondaryIndex;
	[database asyncRegisterExtension:secondaryIndex withName:extName completionBlock:^(BOOL ready) {

		if (!ready) {
			DDLogError(@"Error registering \"%@\" !!!", extName);
		}
	}];
}

- (void)setupHooks
{
	//
	// HOOKS
	//
	// Performs the following:
	//
	// - Automatically updates STConversation.lastUpdated based on new messages
	
	YapDatabaseHooks *hooks = [[YapDatabaseHooks alloc] init];
	
	// DidInsertObject && DidUpdateObject && DidReplaceObject
	{
		void (^InsertUpdateHook)(YapDatabaseReadWriteTransaction*, NSString*, NSString*, id) =
		^(YapDatabaseReadWriteTransaction *transaction, NSString *collection, NSString *key, id object)
		{
			// Are we inserting or updating a message object ?
			
			if ([object isKindOfClass:[STMessage class]])
			{
				__unsafe_unretained STMessage *message = (STMessage *)object;
				
				STConversation *conversation = [transaction objectForKey:message.conversationId
				                                            inCollection:message.userId];
				if (conversation)
				{
					// Grab the previous conversation.lastUpdated value
					
					NSDate *old_lastUpdated = conversation.lastUpdated;
					NSDate *new_lastUpdated = nil;
					
					// Calculate the current conversation.lastUpdated value
					
					STMessage *message = [[transaction ext:Ext_View_Order] lastObjectInGroup:conversation.uuid];
					if (message)
						new_lastUpdated = message.timestamp;
					else
						new_lastUpdated = [NSDate dateWithTimeIntervalSince1970:0.0];
					
					// If the value has changed, then update the conversation
					
					if ( ! SCEqualDates(old_lastUpdated, new_lastUpdated))
					{
						conversation = [conversation copy];
						conversation.lastUpdated = new_lastUpdated;
						
						[transaction setObject:conversation
						                forKey:conversation.uuid
						          inCollection:conversation.userId];
					}
				}
			}
		};
		
		hooks.didInsertObject =
		^(YapDatabaseReadWriteTransaction *transaction, NSString *collection, NSString *key, id object, id metadata)
		{
			InsertUpdateHook(transaction, collection, key, object);
		};
		
		hooks.didUpdateObject =
		^(YapDatabaseReadWriteTransaction *transaction, NSString *collection, NSString *key, id object, id metadata)
		{
			InsertUpdateHook(transaction, collection, key, object);
		};
		
		hooks.didReplaceObject =
		^(YapDatabaseReadWriteTransaction *transaction, NSString *collection, NSString *key, id object)
		{
			InsertUpdateHook(transaction, collection, key, object);
		};
	}
	
	// WillRemoveObject, DidRemoveObject, WillRemoveObjects, DidRemoveObjects
	{
		NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
		
		void (^WillRemoveHook)(YapDatabaseReadWriteTransaction*, NSString*, NSString*) =
		^(YapDatabaseReadWriteTransaction *transaction, NSString *collection, NSString *key)
		{
			id object = [transaction objectForKey:key inCollection:collection];
			
			if ([object isKindOfClass:[STMessage class]])
			{
				__unsafe_unretained STMessage *message = (STMessage *)object;
				
				NSString *conversationID = collection; // collection == message.conversationId;
				NSString *userID = message.userId;
				
				dict[conversationID] = userID;
			}
		};
		
		void (^DidRemoveHook)(YapDatabaseReadWriteTransaction*, NSString*) =
		^(YapDatabaseReadWriteTransaction *transaction, NSString *collection)
		{
			// If the item removed was a STMessage, then 'dict' contains the info we need to
			// fetch the corresponding STConversation from the database.
			//
			// Remember:
			//
			// - STUser         : collection="users", key=<userID>
			// - STConversation : collection=<userID>, key=<conversationID>
			// - STMessage      : collection=<conversationID>, key=<messageID>
			
			__unsafe_unretained NSString *conversationID = collection;
			
			NSString *userID = dict[conversationID];
			if (userID)
			{
				STConversation *conversation = [transaction objectForKey:conversationID inCollection:userID];
				if (conversation)
				{
					// Grab the previous conversation.lastUpdated value
					
					NSDate *old_lastUpdated = conversation.lastUpdated;
					NSDate *new_lastUpdated = nil;
					
					// Calculate the current conversation.lastUpdated value
					
					STMessage *message = [[transaction ext:Ext_View_Order] lastObjectInGroup:conversation.uuid];
					if (message)
						new_lastUpdated = message.timestamp;
					else
						new_lastUpdated = [NSDate dateWithTimeIntervalSince1970:0.0];
					
					// If the value has changed, then update the conversation
					
					if ( ! SCEqualDates(old_lastUpdated, new_lastUpdated))
					{
						// This code automatically alters a STConversation to act as if a removed STMessage had never been received.
						// In other words, if you have a conversation history like this:
						//
						// - messageA (3:15 pm)
						// - messageB (3:30 pm)
						//
						// And messageA gets removed, then the STConversation's lastUpdated timestamp will change
						// from 3:30 to 3:15 pm.
						//
						// This is technically more "secure", because it fully removes any evidence of the message being received.
						//
						// However, it has the side-effect of moving conversations towards the bottom of the list.
						// Meaning it makes conversations more difficult to find because it disagrees with the mental ordering.
						// This is especially true for converasations that make regular use of burn.
						//
						// Thus ST-979 was introduced and discussed in order to change this code.
						
					//	conversation = [conversation copy];
					//	conversation.lastUpdated = new_lastUpdated;
					//
					//	[transaction setObject:conversation
					//	                forKey:conversation.uuid
					//	          inCollection:conversation.userId];
						
						[transaction touchObjectForKey:conversation.uuid inCollection:conversation.userId];
					}
				}
				
				[dict removeObjectForKey:conversationID];
			}
		};
		
		
		hooks.willRemoveObject = ^(YapDatabaseReadWriteTransaction *transaction, NSString *collection, NSString *key)
		{
			WillRemoveHook(transaction, collection, key);
		};
		
		hooks.didRemoveObject = ^(YapDatabaseReadWriteTransaction *transaction, NSString *collection, NSString *key)
		{
			DidRemoveHook(transaction, collection);
		};
		
		hooks.willRemoveObjects = ^(YapDatabaseReadWriteTransaction *transaction, NSString *collection, NSArray *keys)
		{
			// If we're deleting a bunch of STMessage objects,
			// then we can use any key in the array in order to process this.
			
			WillRemoveHook(transaction, collection, [keys firstObject]);
		};
		
		hooks.didRemoveObjects = ^(YapDatabaseReadWriteTransaction *transaction, NSString *collection, NSArray *keys)
		{
			DidRemoveHook(transaction, collection);
		};
	}
	
	NSString *const extName = Ext_Hooks;
	[database asyncRegisterExtension:hooks withName:extName completionBlock:^(BOOL ready) {
		
		if (!ready) {
			DDLogError(@"Error registering \"%@\" !!!", extName);
		}
		
		// MUST be invoked by LAST extension to get registered !!!
		[self extensionsSetupComplete];
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Upgrades & Cleanup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * We invoke this method when the last extension finishes setting up.
**/
- (void)extensionsSetupComplete
{
	__block BOOL needsVacuum = NO;
	
	[rwDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		NSString *auto_vacuum = [rwDatabaseConnection pragmaAutoVacuum];
		needsVacuum = [auto_vacuum isEqualToString:@"NONE"];
		
		if (needsVacuum){
			DDLogInfo(@"PRAGMA auto_vacuum = %@", auto_vacuum);
		}
		
	} completionBlock:^{
		
		if (needsVacuum)
		{
			// We don't vacuum right away.
			// The app just launched, so it could be pulling down stuff from the server.
			// Instead, we queue up the vacuum operation to run after a slight delay.
			
			dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC));
			dispatch_after(when, dispatch_get_main_queue(), ^{
				
				[rwDatabaseConnection asyncVacuumWithCompletionBlock:^{
					
					DDLogInfo(@"VACUUM complete (upgrading database auto_vacuum setting)");
				}];
			});
		}
	}];
	
	if (needsRemoveKeyingMessagesAndStatusMessageView)
	{
		[self cleanup_removeKeyingMessagesAndStatusMessageView];
	}
	if (needsFixOrphanedScimpStates)
	{
		[self cleanup_fixOrphanedScimpStates];
	}
}

- (void)cleanup_removeKeyingMessagesAndStatusMessageView
{
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		NSArray *conversationIDs = [[transaction ext:Ext_View_StatusMessage] allGroups];
		
		for (NSString *conversationID in conversationIDs)
		{
			NSUInteger capacity = [[transaction ext:Ext_View_StatusMessage] numberOfItemsInGroup:conversationID];
			NSMutableArray *keys = [NSMutableArray arrayWithCapacity:capacity];
			
			__block NSString *localUserID = nil;
			
			[[transaction ext:Ext_View_StatusMessage] enumerateKeysInGroup:conversationID usingBlock:
			    ^(NSString *collection, NSString *key, NSUInteger index, BOOL *stop)
			{
				[keys addObject:key];
				
				if (localUserID == nil)
				{
					STMessage *message = [transaction objectForKey:key inCollection:collection];
					localUserID = message.userId;
				}
			}];
			
			[transaction removeObjectsForKeys:keys inCollection:conversationID];
			
			if (localUserID)
			{
				[transaction touchObjectForKey:conversationID inCollection:localUserID];
			}
		}
		
	} completionBlock:^{
		
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:Cleanup_Key_2_0_6];
		[database asyncUnregisterExtensionWithName:Ext_View_StatusMessage completionBlock:NULL];
	}];
}

- (void)cleanup_fixOrphanedScimpStates
{
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		NSMutableArray *scimpIDsToDelete = [NSMutableArray array];
		NSMutableDictionary *scimpIDsToAdd = [NSMutableDictionary dictionary];
		
		// Enumerate all of the STScimpState objects.
		// Make sure that the corresponding conversation.scimpStateIDs includes the proper reference.
		
		[transaction enumerateKeysAndObjectsInCollection:kSCCollection_STScimpState
		                                      usingBlock:^(NSString *key, id object, BOOL *stop)
		{
			__unsafe_unretained SCimpSnapshot *scimpSnapshot = object;
			
			STUser *localUser = [STDatabaseManager findUserWithJID:scimpSnapshot.localJID transaction:transaction];
			
			NSString *localUserID = localUser.uuid;
			NSString *conversationID = scimpSnapshot.conversationID;
			
			STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
			if (conversation)
			{
				if (![conversation.scimpStateIDs containsObject:scimpSnapshot.uuid])
				{
					YapCollectionKey *ck = YapCollectionKeyCreate(localUserID, conversationID);
					
					NSMutableArray *missingScimpIDs = [scimpIDsToAdd objectForKey:ck];
					if (missingScimpIDs == nil) {
						missingScimpIDs = [NSMutableArray arrayWithCapacity:1];
					}
					
					[missingScimpIDs addObject:scimpSnapshot.uuid];
				}
			}
			else
			{
				[scimpIDsToDelete addObject:scimpSnapshot.uuid];
			}
		}];
		
		[transaction removeObjectsForKeys:scimpIDsToDelete inCollection:kSCCollection_STScimpState];
		
		[scimpIDsToAdd enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
			
			YapCollectionKey *ck = (YapCollectionKey *)key;
			NSArray *missingScimpIDs = (NSArray *)obj;
			
			STConversation *conversation = [transaction objectForKey:ck.key inCollection:ck.collection];
			conversation = [conversation copy];
			
			NSMutableSet *newScimpStateIDs = [conversation.scimpStateIDs mutableCopy];
			if (newScimpStateIDs == nil) {
				newScimpStateIDs = [NSMutableSet setWithCapacity:1];
			}
			
			[newScimpStateIDs addObjectsFromArray:missingScimpIDs];
			conversation.scimpStateIDs = newScimpStateIDs;
			
			[transaction setObject:conversation
			                forKey:conversation.uuid
			          inCollection:conversation.userId];
		}];
		
	} completionBlock:^{
		
		[[NSUserDefaults standardUserDefaults] setBool:YES forKey:Cleanup_Key_2_1_scimpStates];
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)yapDatabaseModified:(NSNotification *)ignored
{
	// Notify observers we're about to update the database connection
	
	[[NSNotificationCenter defaultCenter] postNotificationName:UIDatabaseConnectionWillUpdateNotification object:self];
	
	// Move uiDatabaseConnection to the latest commit.
	// Do so atomically, and fetch all the notifications for each commit we jump.
	
	NSArray *notifications = [uiDatabaseConnection beginLongLivedReadTransaction];
	
    BOOL currentUserIDChanged = [uiDatabaseConnection hasChangeForKey:prefs_selectedUserId
	                                                  inCollection:kSCCollection_Prefs
	                                               inNotifications:notifications];

	BOOL currentUserChanged =  [uiDatabaseConnection hasChangeForKey:currentUserID
	                                                    inCollection:kSCCollection_STUsers
	                                                 inNotifications:notifications];
    
	if (currentUserIDChanged || currentUserChanged)
    {
        // We need to update cached currentUserId and/or currentUser
		[uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			if (currentUserIDChanged) {
				currentUserID = [transaction objectForKey:prefs_selectedUserId inCollection:kSCCollection_Prefs];
			}
			
			currentUser = [transaction objectForKey:currentUserID inCollection:kSCCollection_STUsers];
		}];
	}
	
	if (currentUser) {
		NSAssert([currentUser isKindOfClass:[STLocalUser class]], @"Oops");
	}
	
	// Notify observers that the uiDatabaseConnection was updated
	
	NSDictionary *userInfo = @{
	  kNotificationsKey : notifications,
	  kCurrentUserUpdatedKey : @(currentUserIDChanged || currentUserChanged),
	  kCurrentUserIDChangedKey : @(currentUserIDChanged)
	};

	[[NSNotificationCenter defaultCenter] postNotificationName:UIDatabaseConnectionDidUpdateNotification
	                                                    object:self
	                                                  userInfo:userInfo];
	
	// Notify observers that the theme changed (if needed)
	if (currentUserIDChanged)
	{
		NSString *theme = [STPreferences appThemeNameForAccount:currentUserID];
		
		// Note: This method will post a notification.
		// So its important we do this AFTER we post UIDatabaseConnectionDidUpdateNotification.
		// Otherwise the viewControllers may wind up in a bad state.
		[AppTheme selectWithKey:theme];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark On-The-Fly Contacts View
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)configureFilteredContactsDBView:(NSString *)inNetworkId withUserId:(NSString *)optionalUserIdToFilter
{
	NSAssert(inNetworkId != nil, @"Bad parameter: networkId");
	
	if (OSAtomicIncrement32(&filteredContactsViewRetainCount) != 1) {
		return;
	}
	
	// Setup filter view
	
	NSString *networkId = [inNetworkId copy];
	NSString *userIdToFilter = [optionalUserIdToFilter copy];
	
	YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withObjectBlock:
	    ^BOOL (NSString *group, NSString *collection, NSString *key, id object){
		
		__unsafe_unretained STUser *user = (STUser *)object; // just cast, don't retain
			
		if ([networkId isEqualToString:user.networkID])
		{
			if (userIdToFilter && [userIdToFilter isEqualToString:user.uuid])
				return NO; // Filter out our own user
			else
				return YES;
		}
		else
		{
			return NO; // Filter out different network
		}
	}];
	
	NSString *tag;
	if (userIdToFilter)
		tag = [NSString stringWithFormat:@"%@ - %@", networkId, userIdToFilter];
	else
		tag = networkId;
	
	YapDatabaseViewOptions *options = [[YapDatabaseViewOptions alloc] init];
	options.isPersistent = NO;
	
	YapDatabaseFilteredView *filteredView =
	  [[YapDatabaseFilteredView alloc] initWithParentViewName:Ext_View_SavedContacts
	                                                filtering:filtering
	                                               versionTag:tag
	                                                  options:options];
	
	[database asyncRegisterExtension:filteredView withName:Ext_View_FilteredContacts completionBlock:^(BOOL ready) {
		
		if (ready) {
			DDLogInfo(@"filteredContacts view registered");
		}
		else {
			DDLogError(@"Error registering filteredContacts view !!!");
		}
	}];
}

- (void)reconfigureFilteredContactsDBView:(NSString *)inNetworkId withUserId:(NSString *)optionalUserIdToFilter
{
	NSAssert(inNetworkId != nil, @"Bad parameter: networkId");
	
	if (OSAtomicAdd32(0, &filteredContactsViewRetainCount) == 0) {
		
		DDLogWarn(@"filteredContacts view not registered (unable to reconfigure)");
		return;
	}
	
	// Setup filter view
	
	NSString *networkId = [inNetworkId copy];
	NSString *userIdToFilter = [optionalUserIdToFilter copy];
	
	YapDatabaseViewFiltering *filtering = [YapDatabaseViewFiltering withObjectBlock:
	    ^BOOL (NSString *group, NSString *collection, NSString *key, id object)
	{
		__unsafe_unretained STUser *user = (STUser *)object; // just cast, don't retain
			
		if ([networkId isEqualToString:user.networkID])
		{
			if (userIdToFilter && [userIdToFilter isEqualToString:user.uuid])
				return NO; // Filter out our own user
			else
				return YES;
		}
		else
		{
			return NO; // Filter out different network
		}
	}];
	
	NSString *tag;
	if (userIdToFilter)
		tag = [NSString stringWithFormat:@"%@ - %@", networkId, userIdToFilter];
	else
		tag = networkId;
	
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		// Update filtering block.
		//
		// The filteredView will automatically update the view, and post a proper changeset that reflects
		// what changed between the previous & new filter.
		//
		// Note: If the tag didn't change, then this method does nothing.
		
		[[transaction ext:Ext_View_FilteredContacts] setFiltering:filtering versionTag:tag];
	}];
}

- (void)teardownFilteredContactsDBView
{
	if (OSAtomicDecrement32(&filteredContactsViewRetainCount) == 0)
	{
		// Teardown filteredContacts view
		[database asyncUnregisterExtensionWithName:Ext_View_FilteredContacts completionBlock:^{
		
			DDLogInfo(@"filteredContacts view UNregistered");
		}];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Key Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray *)symmetricKeyIDsforThreadID:(NSString *)threadID
                        withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	NSMutableArray *keyIds = [NSMutableArray array];
	
	[transaction enumerateKeysAndObjectsInCollection:kSCCollection_STSymmetricKeys
	                                      usingBlock:^(NSString *key, id object, BOOL *stop)
	{
		__unsafe_unretained STSymmetricKey *mcKey = (STSymmetricKey *)object;
		
		if ([mcKey.threadID isEqualToString:threadID])
		{
			[keyIds addObject:mcKey.uuid];
		}
	}];
    
    return keyIds;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark User Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)hashStr:(NSString *)hashMe
{
	if ([hashMe length] == 0) return nil;
	
	SCKeyContextRef storageKey = STAppDelegate.storageKey;
	if (storageKey == nil)
		return nil;
	
	NSData *data = [hashMe dataUsingEncoding:NSUTF8StringEncoding];
	
	NSString *hashStr = nil;
	
	uint8_t symKey[64];
	size_t  symKeyLen = 0;
	
	uint8_t hashBuf[64];
	size_t  hashSize = 0;
	
	SCLError err = kSCLError_NoErr;
	HASH_ContextRef hashRef = kInvalidHASH_ContextRef;
	
	err = SCKeyGetProperty(storageKey, kSCKeyProp_SymmetricKey, NULL, &symKey, sizeof(symKey), &symKeyLen); CKERR;
	
	err = HASH_Init(kHASH_Algorithm_SHA1, &hashRef);         CKERR;
	err = HASH_GetSize(hashRef, &hashSize);                  CKERR;
	
	NSAssert(hashSize <= sizeof(hashBuf), @"Hash buffer is too small for algorithm");
	
	err = HASH_Update(hashRef, symKey, symKeyLen);           CKERR;
	err = HASH_Update(hashRef, [data bytes], [data length]); CKERR;
	
	err = HASH_Final(hashRef, hashBuf);                      CKERR;
	
	hashStr = [NSString hexEncodeBytes:hashBuf length:hashSize];
	
done:
	
	ZERO(symKey, sizeof(symKey));
	
	if (!IsNull(hashRef))
		HASH_Free(hashRef);
	
	return hashStr;
}

/**
 * Optimized method to find a user with the given JID.
 * Uses a secondary index on the STUser.jid.
**/
- (STUser *)findUserWithJID:(XMPPJID *)jid transaction:(YapDatabaseReadTransaction *)transaction
{
	if (jid == nil) return nil;
	
	YapDatabaseSecondaryIndexTransaction *secondaryIndexTransaction = [transaction ext:Ext_SecondaryIndex];
	if (secondaryIndexTransaction)
	{
		// Use secondary index extension for fast lookup (uses sqlite indexes)
		
		NSString *hash = [self hashStr:[jid bare]];
		if (hash == nil) return nil;
		
		__block STUser *matchingUser = nil;
		
		YapDatabaseQuery *query = [YapDatabaseQuery queryWithFormat:@"WHERE hash = ?", hash];
		
		[secondaryIndexTransaction enumerateKeysAndObjectsMatchingQuery:query usingBlock:
		    ^(NSString *collection, NSString *key, id object, BOOL *stop)
		{
			__unsafe_unretained STUser *user = (STUser *)object;
			
			if ([user.jid isEqualToJID:jid options:XMPPJIDCompareBare])
			{
				matchingUser = user;
				*stop = YES;
			}
		}];
		
		return matchingUser;
	}
	else
	{
		// Backup Plan (defensive programming)
		//
		// Secondary Index extension isn't ready yet.
		// It must be still initializing / updating.
		//
		// Scan the users collection and look for a match (slow but functional).
		
		__block STUser *matchingUser = nil;
		
		[transaction enumerateKeysAndObjectsInCollection:kSCCollection_STUsers usingBlock:
		    ^(NSString *key, id object, BOOL *stop)
		{
			if ([object isKindOfClass:[STUser class]])
			{
				__unsafe_unretained STUser *user = (STUser *)object;
				
				if ([user.jid isEqualToJID:jid options:XMPPJIDCompareBare])
				{
					matchingUser = user;
					*stop = YES;
				}
			}
		}];
		
		return matchingUser;
	}
}

/**
 * Scans the database to find the STLocalUser with the given appStoreHash.
**/
- (STLocalUser *)findUserWithAppStoreHash:(NSString *)hashStr transaction:(YapDatabaseReadTransaction *)transaction
{
	__block STLocalUser *matchingLocalUser = nil;
	
	YapDatabaseViewTransaction *localContactsViewTransaction = [transaction ext:Ext_View_LocalContacts];
	if (localContactsViewTransaction)
	{
		// Use Ext_View_LocalContacts for fastes lookup (only STLocalUsers)
		
		[localContactsViewTransaction enumerateKeysAndObjectsInGroup:@"" usingBlock:
		    ^(NSString *collection, NSString *key, id object, NSUInteger index, BOOL *stop)
		{
			__unsafe_unretained STLocalUser *localUser = (STLocalUser *)object;
			
			if ([hashStr isEqualToString:localUser.appStoreHash])
			{
				matchingLocalUser = localUser;
				*stop = YES;
			}
		}];
	}
	else
	{
		// Backup Plan (defensive programming)
		//
		// Ext_View_LocalContacts extension isn't ready yet.
		// It must be still initializing / updating.
		//
		// Scan the users collection and look for a match (slow but functional).
		
		[transaction enumerateKeysAndObjectsInCollection:kSCCollection_STUsers
		                                      usingBlock:^(NSString *key, id object, BOOL *stop)
		{
			__unsafe_unretained STUser *user = (STUser *)object;
			if (user.isLocal)
			{
				__unsafe_unretained STLocalUser *localUser = (STLocalUser *)user;
				
				if ([hashStr isEqualToString:localUser.appStoreHash])
				{
					matchingLocalUser = localUser;
					*stop = YES;
				}
			}
		}];
	}
	
	return matchingLocalUser;
}

/**
 * The currentUser property is not thread-safe and can only be accessed on the main thread.
 *
 * Background tasks should use this method to fetch the current user.
 * Or they should fetch and store the currentUser on the main thread, before dispatching their background task.
**/
- (STLocalUser *)currentUserWithTransaction:(YapDatabaseReadTransaction *)transaction
{
	NSString *currentUserId = [transaction objectForKey:prefs_selectedUserId inCollection:kSCCollection_Prefs];
	
	return [transaction objectForKey:currentUserId inCollection:kSCCollection_STUsers];
}

/**
 * User this method to create a temp STUser object, for any users that don't exist in the database.
 * 
 * There are several ViewController classes that take STUser properties.
 * Generally, you fetch the user first, possibly using findUserWithJID, etc.
 * If the user doesn't exist in the database, then simply use this method to create a temp/stub STUser
 * with the proper values set, and then pass it to the viewController.
 **/
- (STUser *)tempUserWithJID:(XMPPJID *)jid
{
	return [self tempUserWithJID:jid networkID:STDatabaseManager.currentUser.networkID];
}

- (STUser *)tempUserWithJID:(XMPPJID *)jid networkID:(NSString *)networkID
{
	STUser *user = [[STUser alloc] initWithUUID:nil
	                                  networkID:networkID
	                                        jid:jid];
    
	NSDictionary *abInfo = [[AddressBookManager sharedInstance] infoForSilentCircleJID:jid];
	if (abInfo)
	{
		ABRecordID abNum = [[abInfo objectForKey:kABInfoKey_abRecordID] intValue];
		user.abRecordID = abNum;
		user.isAutomaticallyLinkedToAB = YES;
		user.ab_firstName     = [abInfo objectForKey:kABInfoKey_firstName];
		user.ab_lastName      = [abInfo objectForKey:kABInfoKey_lastName];
		user.ab_compositeName = [abInfo objectForKey:kABInfoKey_compositeName];
		user.ab_organization  = [abInfo objectForKey:kABInfoKey_organization];
		user.ab_notes         = [abInfo objectForKey:kABInfoKey_notes];
	}
	
	return user;
}

/** ET 08/15/14
 *
 * A nice description should go here...
 *
**/
- (NSArray *)multiCastUsersForConversation:(STConversation *)conversation
                           withTransaction:(YapDatabaseReadTransaction *)transaction
{
	if (!conversation.isMulticast)
	{
		return [NSArray array];
	}
	
	// Fetch the currentUser (in a thread-safe manner)
	STUser *_currentUser = nil;
	
	if ([NSThread isMainThread]) {
		_currentUser = self.currentUser;
	}
	else {
		NSString *_currentUserID = [transaction objectForKey:prefs_selectedUserId inCollection:kSCCollection_Prefs];
		_currentUser = [transaction objectForKey:_currentUserID inCollection:kSCCollection_STUsers];
	}
	
	NSMutableArray *multicastUsers = [NSMutableArray arrayWithCapacity:[conversation.multicastJidSet count]];
	
    for (XMPPJID *jid in conversation.multicastJidSet)
	{
		STUser *user = [[DatabaseManager sharedInstance] findUserWithJID:jid transaction:transaction];
		if (user == nil)
		{
			// if the mc user is not in our database, create a pseduo one, and check for AB entry
			
			user = [self tempUserWithJID:jid networkID:currentUser.networkID];
		}
            
		[multicastUsers addObject:user];
    }

	return [multicastUsers copy];
}

/**
 * Returns the sum total of all unread messages for the given userId.
 *
 * This number is suitable as a badge for the user, as in the SettingsViewController.
**/
- (NSUInteger)numberOfUnreadMessagesForUser:(NSString *)userId
                            withTransaction:(YapDatabaseReadTransaction *)transaction
{
	__block NSUInteger totalUnread = 0;
	
	[transaction enumerateKeysInCollection:userId
	                            usingBlock:^(NSString *conversationId, BOOL *stop)
	{
		totalUnread += [[transaction ext:Ext_View_Unread] numberOfItemsInGroup:conversationId];
	}];
	
	return totalUnread;
}

/**
 * Returns the sum total of all unread messages for the given userId, excluding one particular conversation.
 * 
 * This number is suitable as a badge within the given conversation,
 * representing the number of unread messages elsewhere.
**/
- (NSUInteger)numberOfUnreadMessagesForUser:(NSString *)userId
                      excludingConversation:(NSString *)excludingConversationId
							withTransaction:(YapDatabaseReadTransaction *)transaction
{
	__block NSUInteger totalUnread = 0;
	
	[transaction enumerateKeysInCollection:userId
	                            usingBlock:^(NSString *conversationId, BOOL *stop)
	{
		if (![conversationId isEqualToString:excludingConversationId])
		{
			totalUnread += [[transaction ext:Ext_View_Unread] numberOfItemsInGroup:conversationId];
		}
	}];
	
	return totalUnread;
}

/**
 * Returns the sum total of all unread messages for every local user.
 * 
 * This number is suitable as a badge for the application.
**/
- (NSUInteger)numberOfUnreadMessagesForAllUsersWithTransaction:(YapDatabaseReadTransaction *)transaction
{
	__block NSUInteger totalUnread = 0;
	
	YapDatabaseViewTransaction *localContactsViewTransaction = [transaction ext:Ext_View_LocalContacts];
	if (localContactsViewTransaction)
	{
		// Use localContacts view for direct list of localUsers
		
		// Algorithm:
		// - Enumerate every localUser (using Ext_View_LocalContacts)
		// - Every conversation in the system is linked to local user (conversation.collection == localUserId)
		// - So we can enumerate all conversationIds (once we know their localUserId)
		// - And every conversation has a stored unread count in the "unread" extension
		
		[localContactsViewTransaction enumerateKeysInGroup:@"" usingBlock:
		    ^(NSString *collection, NSString *localUserID, NSUInteger index, BOOL *stop)
		{
			// Now enumerate every associated conversationId for this localUser.
			
			[transaction enumerateKeysInCollection:localUserID
			                            usingBlock:^(NSString *conversationId, BOOL *stop)
			{
				totalUnread += [[transaction ext:Ext_View_Unread] numberOfItemsInGroup:conversationId];
			}];
		}];
	}
	else
	{
		// Backup Plan (defensive programming)
		//
		// LocalContacts extension isn't ready yet.
		// It must be still initializing / updating.
		//
		// Scan the users collection and look for local users (slower but functional).
		
		// Algorithm:
		// - Enumerate every user (collection == kSCCollection_STUsers)
		// - Find those users that are local (non-remote)
		// - Every conversation in the system is linked to local user (conversation.collection == localUserId)
		// - So we can enumerate all conversationIds (once we know their localUserId)
		// - And every conversation has a stored unread count in the "unread" extension
		
		[transaction enumerateKeysAndObjectsInCollection:kSCCollection_STUsers
		                                      usingBlock:^(NSString *key, id object, BOOL *stop)
		{
			__unsafe_unretained STUser *user = object;
			if (user.isLocal)
			{
				// Found a local user.
				// Now enumerate every associated conversationId for this user.

				[transaction enumerateKeysInCollection:user.uuid
				                            usingBlock:^(NSString *conversationId, BOOL *stop)
				{
					totalUnread += [[transaction ext:Ext_View_Unread] numberOfItemsInGroup:conversationId];
				}];
			}
		}];
	}

	return totalUnread;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark User Management
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isUserProvisioned:(NSString *)userName
                networkID:(NSString *)networkID
{
    
    NSDictionary *netInfo = [AppConstants.SilentCircleNetworkInfo objectForKey:networkID];
 	NSString *domain = [netInfo objectForKey:@"xmppDomain"];

    XMPPJID* jid = [XMPPJID jidWithUser:userName domain:domain resource:NULL];
    
    __block STUser *user = NULL;
    
    [roDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        // Search for user in database with this JID.

		user = [self findUserWithJID:jid transaction:transaction];
    }];
 
    return (user && !user.isRemote);
 }

- (void)asyncDeleteLocalUser:(NSString *)userID completionBlock:(dispatch_block_t)completionBlock
{
	__block STLocalUser *localUser = nil;
	__block NSMutableSet *scimpKeys = nil;
	
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		// Find user
		STUser *_user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
		
		if (_user == nil) {
			DDLogWarn(@"asyncDeleteLocalUser:: - Method invoked on non-existent user");
			return;
		}
		
		if (_user.isRemote)
		{
			DDLogError(@"asyncDeleteLocalUser:: - Method invoked on non-local user !");
			return;
		}
		
		localUser = (STLocalUser *)_user;
		
		// Fetch all:
		// - conversationId's
		// - symmetric keys
		// - scimp keys.
		
		NSMutableArray *conversationIds = [NSMutableArray array];
		NSMutableArray *symmetricKeyIds = [NSMutableArray array];
		scimpKeys = [NSMutableSet set];
		
		[transaction enumerateKeysAndObjectsInCollection:userID
		                                      usingBlock:^(NSString *key, STConversation *conversation, BOOL *stop)
		{
			[conversationIds addObject:conversation.uuid];
			
			if (conversation.isMulticast && conversation.keyLocator)
			{
				[symmetricKeyIds addObject:conversation.keyLocator];
			}
			
			[scimpKeys unionSet:conversation.scimpStateIDs];
		}];
		
		// Delete all messages (STMessage && STXMPPElement objects)
		//
		// For STMessage's:
		// - collection = conversationId
		// - key = messageId
		//
		// For STXMPPElement's:
		// - collection = conversationId
		// - key = uuid
		
		for (NSString *conversationId in conversationIds)
		{
			[transaction removeAllObjectsInCollection:conversationId];
		}
		
		// Delete all conversations
		//
		// For STConversation's:
		// - collection = userId
		// - key = conversationId
		
		[transaction removeAllObjectsInCollection:userID];
		
		// Delete all the ScimpStates
		
		[transaction removeObjectsForKeys:[scimpKeys allObjects] inCollection:kSCCollection_STScimpState];
		
		// Delete all symmetric keys
		
		[transaction removeObjectsForKeys:symmetricKeyIds inCollection:kSCCollection_STSymmetricKeys];
		
		// Delete all public & private keys
		
		NSMutableArray *pubPrivKeyIds = [NSMutableArray array];
		
		[transaction enumerateKeysAndObjectsInCollection:kSCCollection_STPublicKeys
											  usingBlock:^(NSString *key, id object, BOOL *stop)
		{
			__unsafe_unretained STPublicKey *publicKey = (STPublicKey *)object;
			
			if ([publicKey.userID isEqualToString:userID])
			{
				[pubPrivKeyIds addObject:key];
			}
		}];
		
		[transaction removeObjectsForKeys:pubPrivKeyIds inCollection:kSCCollection_STPublicKeys];
		
		// Maybe select another localUser (if this one is currently selected)
		
		NSString *newSelectedUserID = nil;
		
		NSString *selectedUserID = [STPreferences selectedUserId];
		if ([selectedUserID isEqualToString:userID])
		{
			NSString *group = nil;
			NSUInteger index = 0;
			BOOL found = [[transaction ext:Ext_View_LocalContacts] getGroup:&group
			                                                          index:&index
			                                                         forKey:userID
			                                                   inCollection:kSCCollection_STUsers];
			if (found)
			{
				// Auto-select the local user next to this one (within the UI)
				
				if (index > 0) {
					newSelectedUserID = [[transaction ext:Ext_View_LocalContacts] keyAtIndex:(index-1) inGroup:group];
				}
				else {
					newSelectedUserID = [[transaction ext:Ext_View_LocalContacts] keyAtIndex:(index+1) inGroup:group];
				}
			}
		}
		
		[STPreferences setSelectedUserId:newSelectedUserID];
		
		// Delete the actual user
		
		[transaction removeObjectForKey:userID inCollection:kSCCollection_STUsers];
		
		// Notes:
		//
		// - Any STImage's associated with STMessages will be automatically deleted,
		//   thanks to the YapDatabaseRelationship extension. (see [STImage yapDatabaseRelationshipEdges])
		//
		// - Any STScloud objects associated with STMessages will be automatically deleted,
		//   thanks to the YapDatabaseRelationship extension.
		//   The MessageStream class manually adds appropriate edges to the YapDatabaseRelationshipExtension.
		//
		// - Any image blobs (in the filesystem) associated with the STUser will be automatically deleted,
		//   thanks to the YapDatabaseRelationship extension. (see [STUser yapDatabaseRelationshipEdges])
		
    } completionBlock:^{
		
		MessageStream *ms = [MessageStreamManager existingMessageStreamForUser:localUser];
		if (ms)
		{
			// Disconnect the message stream
			[ms disconnect];
			
			// And deallocate the message stream
			[MessageStreamManager removeMessageStreamForUser:localUser];
		}
		
		// This can run in the background.
		//
		// Note: Deprovisioning the user automatically unregisters the pushToken.
		
		[[SCWebAPIManager sharedInstance] deprovisionLocalUser:localUser completionBlock:NULL];
		
		if (completionBlock) {
			completionBlock();
		}
    }];
}

/*
- (void)asyncDeleteRemoteUser:(NSString *)remoteUserId completionBlock:(dispatch_block_t)completionBlock
{
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		// Fetch user
		
		STUser *remoteUser = [transaction objectForKey:remoteUserId inCollection:kSCCollection_STUsers];
		
		// Sanity checks
		
		if (remoteUser == nil)
		{
			DDLogWarn(@"%@ - Unable to delete user: non-existent user", THIS_METHOD);
			return;
		}
		
		if (!remoteUser.isRemote)
		{
			DDLogWarn(@"%@ - Unable to delete user: non-remote user", THIS_METHOD);
			return;
		}
		
		// Find all local users
		
		NSMutableArray *localUsers = [NSMutableArray array];
		
		[[transaction ext:Ext_View_LocalContacts] enumerateKeysAndObjectsInGroup:@"" usingBlock:
		    ^(NSString *collection, NSString *key, id object, NSUInteger index, BOOL *stop)
		{
			__unsafe_unretained STUser *user = (STUser *)object;
			[localUsers addObject:user];
		}];
		
		// Find all associated conversations
		
		NSMutableArray *symmetricKeyIds = [NSMutableArray array];
		
		for (STUser *localUser in localUsers)
		{
			__block STConversation *conversation = nil;
			
			// Note: conversationId's are created by hashing the remoteJID & localJID.
			// So we can quickly and efficiently determine the conversationID.
			
			NSString *conversationId = [MessageStream conversationIDForRemoteJid:remoteUser.jid
			                                                            localJid:localUser.jid];
			
			conversation = [transaction objectForKey:conversationId inCollection:localUser.uuid];
			
			if (conversation == nil)
			{
				// Maybe the conversation object was created from an older codebase.
				// So we'll try to find the conversation the old-fashioned way (via enumeration).
				
				[transaction enumerateKeysAndObjectsInCollection:localUser.uuid
													  usingBlock:^(NSString *key, id object, BOOL *stop)
				{
					__unsafe_unretained STConversation *aConversation = (STConversation *)object;
					
					if ([aConversation.remoteJid isEqualToJID:remoteUser.jid options:XMPPJIDCompareBare])
					{
						conversation = aConversation;
						*stop = YES;
					}
				}];
			}
			
			if (conversation)
			{
				// Found a conversation with the remote user.
				
				if (conversation.isMulticast && conversation.keyLocator)
				{
					[symmetricKeyIds addObject:conversation.keyLocator];
				}
				
				// Delete all messages in the conversation
				[transaction removeAllObjectsInCollection:conversation.uuid];
				
				// Delete the conversation object
				[transaction removeObjectForKey:conversation.uuid inCollection:localUser.uuid];
			}
			
		} // end for (STUser *localUser in localUsers)
		
		// Delete associated symmetric keys
		
		[transaction removeObjectsForKeys:symmetricKeyIds inCollection:kSCCollection_STSymmetricKeys];
		
		// And finally, delete the actual user
		
		[transaction removeObjectForKey:remoteUserId inCollection:kSCCollection_STUsers];
		
		// Notes:
		//
		// - Any STImage's associated with STMessages will be automatically deleted,
		//   thanks to the YapDatabaseRelationship extension. (see [STImage yapDatabaseRelationshipEdges])
		//
		// - Any STScloud objects associated with STMessages will be automatically deleted,
		//   thanks to the YapDatabaseRelationship extension.
		//   The MessageStream class manually adds appropriate edges to the YapDatabaseRelationshipExtension.
		//
		// - Any image blobs (in the filesystem) associated with the STUser will be automatically deleted,
		//   thanks to the YapDatabaseRelationship extension. (see [STUser yapDatabaseRelationshipEdges])
	
    } completionBlock:completionBlock];
}
*/

/**
 * This method "deletes" a saved remote user.
 * And by "delete" what we really mean is sets user.isSavedToSilentContacts to NO.
 *
 * We do not want to actually delete the user from our database.
 * We just want to "delete" it from the UI.
 *
 * This method also performs all the other actions we might expect,
 * such as clearing all the user.sc_X properties, and deleting the saved avatar (if needed).
**/
- (void)asyncUnSaveRemoteUser:(NSString *)userID completionBlock:(dispatch_block_t)completionBlock
{
	__block STUser *remoteUser = nil;
	__block BOOL needsDownloadWebAvatar = NO;
	
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		// Fetch user
		
		remoteUser = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
		
		// Sanity checks
		
		if (remoteUser == nil)
		{
			DDLogWarn(@"%@ - Unable to UnSave user: non-existent user", THIS_METHOD);
			return;
		}
		
		if (!remoteUser.isRemote)
		{
			DDLogWarn(@"%@ - Unable to UnSave user: non-remote user", THIS_METHOD);
			return;
		}
		
		remoteUser = [remoteUser copy];
		
		remoteUser.sc_firstName = nil;
		remoteUser.sc_lastName = nil;
		remoteUser.sc_compositeName = nil;
		remoteUser.sc_organization = nil;
		remoteUser.sc_notes = nil;
		
		if (remoteUser.avatarSource == kAvatarSource_SilentContacts)
		{
			[remoteUser setAvatarFileName:nil avatarSource:kAvatarSource_None];
			needsDownloadWebAvatar = YES;
		}
		
		if (remoteUser.isAutomaticallyLinkedToAB == NO)
		{
			remoteUser.abRecordID = kABRecordInvalidID;
			remoteUser.isAutomaticallyLinkedToAB = NO;
			
			remoteUser.ab_firstName = nil;
			remoteUser.ab_lastName = nil;
			remoteUser.ab_compositeName = nil;
			remoteUser.ab_organization = nil;
			remoteUser.ab_notes = nil;
			
			if (remoteUser.avatarSource == kAvatarSource_AddressBook)
			{
				[remoteUser setAvatarFileName:nil avatarSource:kAvatarSource_None];
				needsDownloadWebAvatar = YES;
			}
		}
		
		remoteUser.isSavedToSilentContacts = NO;
		
		[transaction setObject:remoteUser
		                forKey:remoteUser.uuid
		          inCollection:kSCCollection_STUsers];
		
		
	} completionBlock:^{
		
		if (needsDownloadWebAvatar)
		{
			[[STUserManager sharedInstance] downloadWebAvatarForUserIfNeeded:remoteUser];
		}
		
		if (completionBlock) {
			completionBlock();
		}
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Conversation Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)geoLocationsForConversation:(NSString *)conversationId
                    completionBlock:(void (^)(NSError *error, NSDictionary *locations))completionBlock
{
	DDLogAutoTrace();
	
	NSMutableDictionary *locations = [NSMutableDictionary dictionary];

	[roDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction){
		
		[[transaction ext:Ext_View_HasGeo] enumerateKeysAndObjectsInGroup:conversationId
		                                                       usingBlock:
		^(NSString *collection, NSString *key, id object, NSUInteger index, BOOL *stop)
		{
			__unsafe_unretained STMessage *message = (STMessage *)object;
			
			NSString *jidStr = [message.from bare];
			BOOL addThis = YES;
			
			NSDictionary *previouslyFoundItem =  [locations objectForKey:jidStr];
			if (previouslyFoundItem)
			{
				NSDate *date = [previouslyFoundItem objectForKey:@"timeStamp"];
				if ([date isBefore:message.timestamp])
					addThis = YES;
				else
					addThis = NO;
			}
			
			if (addThis)
			{
				NSData *locationData = [message.siren.location dataUsingEncoding:NSUTF8StringEncoding];
				
				NSError *error = nil;
				NSDictionary *locationInfo = [NSJSONSerialization JSONObjectWithData:locationData
				                                                             options:0
				                                                               error:&error];
				
				if (locationInfo)
				{
					CLLocation *location = [[CLLocation alloc] initWithDictionary:locationInfo];
					
					NSDictionary *locationItem = @{
					  @"timeStamp": message.timestamp,
					  @"location": location
					};
					
					[locations setObject:locationItem forKey:jidStr];
				}
				else
				{
					DDLogWarn(@"%@ - JSON serialization error: %@", THIS_METHOD, error);
				}
			}
		}];
        
    } completionBlock:^{
		
		// Back on the main thread
		
		if (completionBlock) {
			completionBlock(nil, locations);
		}
    }];
}

@end
