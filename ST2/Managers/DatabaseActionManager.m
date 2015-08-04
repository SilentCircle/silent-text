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
#import "DatabaseActionManager.h"

#import "AppConstants.h"
#import "AppDelegate.h"
#import "MessageStream.h"
#import "SCWebAPIManager.h"
#import "SCimpUtilities.h"
#import "STConversation.h"
#import "STMessage.h"
#import "STLocalUser.h"
#import "STLogging.h"
#import "STNotification.h"
#import "STPreferences.h"
#import "STPublicKey.h"
#import "STSCloud.h"
#import "STSRVRecord.h"
#import "STSymmetricKey.h"
#import "STUser.h"
#import "STUserManager.h"
#import "YapCollectionKey.h"

#import "NSDate+SCDate.h"

#import <Reachability/Reachability.h>

// Log levels: off, error, warn, info, verbose
#if DEBUG && vinnie_moscaritolo
  static const int ddLogLevel = LOG_LEVEL_INFO; // | LOG_FLAG_TRACE;
#elif DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_INFO; // | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_WARN;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

typedef NS_OPTIONS(NSUInteger, DatabaseActionManagerFlags) {
	
	Action_LocalUser_KeyGeneration       = 1 << 0,
	Action_LocalUser_RegisterPushToken   = 1 << 1,
	Action_LocalUser_DeprovisionUser     = 1 << 2,
	
	Action_User_RefreshWebInfo           = 1 << 3,
	
	Action_PublicKey_Upload              = 1 << 4,
	Action_PublicKey_Delete              = 1 << 5,
};


@implementation DatabaseActionManager
{
	YapDatabaseConnection *databaseConnection;
	NSTimer *timer;
	
	dispatch_queue_t dictionaryQueue;
	void *dictionaryQueueTag;
	NSMutableDictionary *inFlightServerActions; // can only be read/modified within dictionaryQueue
}

static DatabaseActionManager *sharedInstance;

+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		initialized = YES;
		sharedInstance = [[DatabaseActionManager alloc] init];
	}
}

+ (DatabaseActionManager *)sharedInstance
{
	return sharedInstance;
}

- (id)init
{
	DDLogAutoTrace();
	
	if ((self = [super init]))
	{
		YapDatabase *database = STDatabaseManager.database;
		databaseConnection = [database newConnection];
		databaseConnection.name = @"DatabaseActionManager";
		
		if (databaseConnection == nil)
		{
			NSString *reason =
			  @"DatabaseActionManager is being called before the database has been started!"
			  @" DatabaseActionManager depends upon the database, so you must ensure the startup flow"
		      @" sets up the database before anything attempts to use this class.";
			
			@throw [NSException exceptionWithName:@"DatabaseActionManager" reason:reason userInfo:nil];
		}
		
		dictionaryQueue = dispatch_queue_create("DatabaseActionManager", DISPATCH_QUEUE_SERIAL);
		
		dictionaryQueueTag = &dictionaryQueueTag;
		dispatch_queue_set_specific(dictionaryQueue, dictionaryQueueTag, dictionaryQueueTag, NULL);
		
		inFlightServerActions = [[NSMutableDictionary alloc] initWithCapacity:4];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(databaseModified:)
		                                             name:YapDatabaseModifiedNotification
		                                           object:database];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(reachabilityChanged:)
		                                             name:kReachabilityChangedNotification
		                                           object:nil];
		
		[self updateTimer];
		[self checkForServerActions];
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)databaseModified:(NSNotification *)notification
{
	// We can check to see if the changes had any impact on our views.
	// If not we can skip the unnecessary processing.
	
	if ([[databaseConnection ext:Ext_View_Action] hasChangesForNotifications:@[notification]])
	{
		[self updateTimer];
	}
	
	if ([[databaseConnection ext:Ext_View_Server] hasChangesForNotifications:@[ notification ]])
	{
		[self checkForServerActions];
	}
}

- (void)reachabilityChanged:(NSNotification *)notification
{
	Reachability *reachability = notification.object;
	if (reachability.isReachable)
	{
		// Re-try any WebAPI calls that previously failed.
		
		[self checkForServerActions];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Action Logic
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Standard object that enumerates the supported object types, and extracts their specific action date.
**/
- (void)getNextActionDate:(NSDate **)nextActionDatePtr
             actionObject:(id *)nextActionObjectPtr
          withTransaction:(YapDatabaseReadTransaction *)transaction
{
	NSDate *nextActionDate = nil;
	id nextActionObject = nil;
	
	BOOL done = NO;
	NSUInteger index = 0;
	
	do
	{
		nextActionObject = [[transaction ext:Ext_View_Action] objectAtIndex:index inGroup:@""];
		
		if ([nextActionObject isKindOfClass:[STLocalUser class]])
		{
			STLocalUser *localUser = (STLocalUser *)nextActionObject;
			
			if (!localUser.subscriptionHasExpired && localUser.subscriptionExpireDate)
			{
				NSDate *date1 = localUser.subscriptionExpireDate;
				NSDate *date2 = localUser.nextWebRefresh;
				NSDate *date3 = localUser.nextKeyGeneration;
				
				nextActionDate = SCEarliestDate3(date1, date2, date3);
			}
			else
			{
				NSDate *date1 = localUser.nextWebRefresh;
				NSDate *date2 = localUser.nextKeyGeneration;
				
				nextActionDate = SCEarliestDate2(date1, date2);
			}
			
			DDLogVerbose(@"nextAction: STLocalUser(%@) -> %@", [localUser.jid bare],
			          [nextActionDate descriptionWithLocale:[NSLocale currentLocale]]);
		}
		else if ([nextActionObject isKindOfClass:[STUser class]]) // MUST come after STLocalUser
		{
			STUser *user = (STUser *)nextActionObject;
			nextActionDate = user.nextWebRefresh;
			
			DDLogVerbose(@"nextAction: STUser(%@) -> %@", [user.jid bare],
			          [nextActionDate descriptionWithLocale:[NSLocale currentLocale]]);
		}
		else if ([nextActionObject isKindOfClass:[STMessage class]])
		{
			STMessage *message = (STMessage *)nextActionObject;
			nextActionDate = message.shredDate;
			
			DDLogVerbose(@"nextAction: STMessage(%@) -> %@", message.uuid,
			          [nextActionDate descriptionWithLocale:[NSLocale currentLocale]]);
		}
		else if ([nextActionObject isKindOfClass:[STPublicKey class]])
		{
			STPublicKey *publicKey = (STPublicKey *)nextActionObject;
			nextActionDate = publicKey.expireDate;
			
			DDLogVerbose(@"nextAction: STPublicKey(%@) -> %@", publicKey.uuid,
			          [nextActionDate descriptionWithLocale:[NSLocale currentLocale]]);
			
			if (nextActionDate == nil) // How the heck is this happening ?
			{
				DDLogError(@"Found STPublicKey in expire view that has a nil expireDate !!!");
				nextActionDate = [NSDate distantPast]; // delete it
			}
		}
		else if ([nextActionObject isKindOfClass:[STSymmetricKey class]])
		{
			STSymmetricKey *sym = (STSymmetricKey *)nextActionObject;
			NSDate *date1 = sym.expireDate;
			NSDate *date2 = sym.recycleDate;
			
			nextActionDate = SCEarliestDate2(date1, date2);
			
			DDLogVerbose(@"nextAction: STSymmetricKey(%@) -> %@", sym.uuid,
			          [nextActionDate descriptionWithLocale:[NSLocale currentLocale]]);
		}
		else if ([nextActionObject isKindOfClass:[STSRVRecord class]])
		{
			STSRVRecord *srv = (STSRVRecord *)nextActionObject;
			nextActionDate = srv.expireDate;
			
			DDLogVerbose(@"nextAction: STSRVRecord(%@) -> %@", srv.srvName,
					  [nextActionDate descriptionWithLocale:[NSLocale currentLocale]]);
		}
		else if ([nextActionObject isKindOfClass:[STSCloud class]])
		{
			STSCloud *scl = (STSCloud *)nextActionObject;
			nextActionDate = scl.unCacheDate;
			
			DDLogVerbose(@"nextAction: STSCloud(%@) -> %@", scl.uuid,
					  [nextActionDate descriptionWithLocale:[NSLocale currentLocale]]);
		}
		else if ([nextActionObject isKindOfClass:[STNotification class]])
		{
			STNotification *note = (STNotification *)nextActionObject;
			nextActionDate = note.fireDate;
			
			DDLogVerbose(@"nextAction: STNotification(%@) -> %@", note.uuid,
					  [nextActionDate descriptionWithLocale:[NSLocale currentLocale]]);
		}
		else
		{
			nextActionDate = nil;
		}
		
		if (nextActionDate)
		{
			done = YES;
		}
		else if (nextActionObject)
		{
			// OH SHIT !
			//
			// Our code is dependent upon being able to extract the actionDate from the object.
			// So something very very very bad has happened.
			// Essentially, this breaks the DatabaseActionManager.
			// Which means all kinds of stuff can stop working, such as burning messages & uploading public keys.
			// Yeah... it's that kind of "oh shit".
			//
			// So how do we deal with it?
			// The only appropriate action on debug builds is to throw an exception.
			// But on release builds, perhaps we shouldn't crash, but instead try to skip the bad object.
			// The repercussions of this is that something that's supposed to happen won't.
			// And the bad object may end sitting at the front of the view forever.
			
		#if DEBUG
			
			NSString *reason = [NSString stringWithFormat:
			  @"BAD object found in Ext_View_Expire!"
			  @" The DatabaseActionManager cannot process this item,"
			  @" either because it is an unrecognized class,"
			  @" or because it has a bad property which is causing the nextExpireDate to be nil.\n"
			  @" BAD object: %@", nextActionObject];
			
			NSString *className = NSStringFromClass([self class]);
			
			@throw [NSException exceptionWithName:className reason:reason userInfo:nil];
			
		#else
			
			DDLogError(@"BAD object found in Ext_View_Expire!"
			           @" The DatabaseActionManager cannot process this item,"
			           @" either because it is an unrecognized class,"
			           @" or because it has a bad property which is causing the nextExpireDate to be nil.\n"
			           @" BAD object: %@", nextActionObject);
			
		#endif
			
			done = NO;
			index++;
		}
		else
		{
			// Nothing left in the Ext_View_Expire.
			done = YES;
		}
			
	} while (!done);
	
	if (nextActionDate && nextActionObject)
	{
		if (nextActionDatePtr) *nextActionDatePtr = nextActionDate;
		if (nextActionObjectPtr) *nextActionObjectPtr = nextActionObject;
	}
	else
	{
		if (nextActionDatePtr) *nextActionDatePtr = nil;
		if (nextActionObjectPtr) *nextActionObjectPtr = nil;
	}
}

- (void)updateTimer
{
	DDLogAutoTrace();
	
	__block NSDate *nextExpireDate = nil;
	
	[databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		[self getNextActionDate:&nextExpireDate actionObject:NULL withTransaction:transaction];
		
	} completionBlock:^{
		
		// The completion block is invoked on the main thread
		
		[self setTimerWithDate:nextExpireDate];
	}];
}

- (void)setTimerWithDate:(NSDate *)nextExpireDate
{
	DDLogAutoTrace();
	NSAssert([NSThread isMainThread], @"This method is not thread-safe");
	
	if (nextExpireDate)
	{
		[timer invalidate];
		timer = [NSTimer scheduledTimerWithTimeInterval:[nextExpireDate timeIntervalSinceNow]
		                                         target:self
		                                       selector:@selector(timerFired:)
		                                       userInfo:nil
		                                        repeats:NO];
	}
	else
	{
		[timer invalidate];
		timer = nil;
	}
}

- (void)timerFired:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	__block NSDate *nextActionDate = nil;

	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		NSDate *now = [NSDate date];
		BOOL done = NO;
		
		do
		{
			id nextActionObject = nil;
			
			[self getNextActionDate:&nextActionDate actionObject:&nextActionObject withTransaction:transaction];
			
			if (nextActionDate && ([nextActionDate compare:now] != NSOrderedDescending))
			{
				// Do NOT add any special processing code in this method.
				//
				// You should add special processing code into the procesX:withTransaction: method.
				// This method should stay lean and mean.
				
				if ([nextActionObject isKindOfClass:[STLocalUser class]])
				{
					STLocalUser *localUser = (STLocalUser *)nextActionObject;
					[self processLocalUser:localUser withTransaction:transaction];
				}
				else if ([nextActionObject isKindOfClass:[STUser class]]) // MUST come after STLocalUser
				{
					STUser *user = (STUser *)nextActionObject;
					[self processUser:user withTransaction:transaction];
				}
				else if ([nextActionObject isKindOfClass:[STMessage class]])
				{
					STMessage *message = (STMessage *)nextActionObject;
					[self processMessage:message withTransaction:transaction];
				}
				else if ([nextActionObject isKindOfClass:[STPublicKey class]])
				{
					STPublicKey *key = (STPublicKey *)nextActionObject;
					[self processAsymmetricKey:key withTransaction:transaction];
				}
				else if ([nextActionObject isKindOfClass:[STSymmetricKey class]])
				{
					STSymmetricKey *symmetricKey = (STSymmetricKey *)nextActionObject;
					[self processSymmetricKey:symmetricKey withTransaction:transaction];
				}
				else if ([nextActionObject isKindOfClass:[STSRVRecord class]])
				{
					STSRVRecord *srv = (STSRVRecord *)nextActionObject;
					[self processSRVRecord:srv withTransaction:transaction];
				}
				else if ([nextActionObject isKindOfClass:[STSCloud class]])
				{
                	STSCloud *scl = (STSCloud *)nextActionObject;
					[self processSCloud:scl withTransaction:transaction];
				}
				else if ([nextActionObject isKindOfClass:[STNotification class]])
				{
					STNotification *notification = (STNotification *)nextActionObject;
					[self processNotifcation:notification withTransaction:transaction];
				}
				else
				{
				#if DEBUG
					
					NSString *reason = [NSString stringWithFormat:
					  @"BAD logic in DatabaseActionManager!"
					  @" Missing logic to process object: %@", nextActionObject];
					
					NSString *className = NSStringFromClass([self class]);
					
					@throw [NSException exceptionWithName:className reason:reason userInfo:nil];
					
				#endif
					
					done = YES;
				}
			}
			else // nextActionDate is in future
			{
				done = YES;
			}
			
		} while (!done);
		
		
	} completionBlock:^{
        
		[self setTimerWithDate:nextActionDate];
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Logic
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)checkForServerActions
{
	[databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		[[transaction ext:Ext_View_Server] enumerateKeysAndObjectsInGroup:@"" usingBlock:
		    ^(NSString *collection, NSString *key, id object, NSUInteger index, BOOL *stop)
		{
			if ([object isKindOfClass:[STLocalUser class]])
			{
				__unsafe_unretained STLocalUser *localUser = (STLocalUser *)object;
				YapCollectionKey *ck = [[YapCollectionKey alloc] initWithCollection:collection key:key];
				
				[self syncLocalUser:localUser withIdentifier:ck transaction:transaction];
			}
			else if ([object isKindOfClass:[STUser class]])
			{
				__unsafe_unretained STUser *user = (STUser *)object;
				YapCollectionKey *ck = [[YapCollectionKey alloc] initWithCollection:collection key:key];
				
				[self syncUser:user withIdentifier:ck transaction:transaction];
			}
			else if ([object isKindOfClass:[STPublicKey class]])
			{
				__unsafe_unretained STPublicKey *asymmetricKey = (STPublicKey *)object;
				YapCollectionKey *ck = [[YapCollectionKey alloc] initWithCollection:collection key:key];
				
				[self syncAsymmetricKey:asymmetricKey withIdentifier:ck transaction:transaction];
			}
		}];
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Action Processing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)processLocalUser:(STLocalUser *)localUser withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	localUser = [localUser copy];
	
	NSDate *now = [NSDate date];
	
	if (!localUser.subscriptionHasExpired && [localUser.subscriptionExpireDate isBefore:now])
	{
		DDLogInfo(@"Subscription has expired for user: %@", [localUser.jid bare]);
		
		localUser.subscriptionHasExpired = YES;
		localUser.nextWebRefresh = now; // force refresh right now
	}
	
	if ([localUser.nextKeyGeneration isBefore:now])
	{
		DDLogInfo(@"Auto public/private key refresh for user: %@", [localUser.jid bare]);
		
		localUser.nextKeyGeneration = nil;
		localUser.needsKeyGeneration = YES;
	}
	
	if ([localUser.nextWebRefresh isBeforeOrEqual:now])
	{
		DDLogInfo(@"Auto web refresh for user: %@", [localUser.jid bare]);
		
		[[STUserManager sharedInstance] refreshWebInfoForLocalUser:localUser completionBlock:NULL];
		
		// If the web fetch fails, then we just retry it again in 2 mintues.
		// If it succeeds, then the nextWebRefresh is updated to a date further in the future (by STUserManager).
		localUser.nextWebRefresh = [now dateByAddingTimeInterval:(60 * 2)];
	}
	
	[transaction setObject:localUser
					forKey:localUser.uuid
			  inCollection:kSCCollection_STUsers];
}

- (void)processUser:(STUser *)user withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	user = [user copy];
	
	NSDate *now = [NSDate date];
	
	if ([user.nextWebRefresh isBeforeOrEqual:now])
	{
		DDLogInfo(@"Auto web refresh for user: %@", [user.jid bare]);
		
        
        [[STUserManager sharedInstance] refreshWebInfoForUser:user
                                              completionBlock:^(NSError *error, NSString *userID, NSDictionary *infoDict) {
                                                  
                                                  // If it succeeds, then the nextWebRefresh is updated to a date further in the future (by STUserManager).
                                                  
                                                  if(error)
                                                  {
                                                      [databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction)
                                                       {
                                                           STUser* user =  [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
                                                           if(user)
                                                           {
                                                               user = user.copy;
                                                               if(error.code == 404) // user not found
                                                               {
                                                                   // in this case lets make the user visable and stop the insistant refreshing
                                                                   user.nextWebRefresh = [NSDate distantFuture];
                                                                   user.isSavedToSilentContacts  = YES;
                                                               }
                                                               
                                                               [transaction setObject:user
                                                                               forKey:user.uuid
                                                                         inCollection:kSCCollection_STUsers];
                                                               
                                                           }
                                                       }];
                                                      
                                                  }
                                                  
                                              }];
		
		// If the web fetch fails, then we just retry it again in 2 mintues.
		// If it succeeds, then the nextWebRefresh is updated to a date further in the future (by STUserManager).
		user.nextWebRefresh = [now dateByAddingTimeInterval:(60 * 2)];
	}
	
	[transaction setObject:user
					forKey:user.uuid
			  inCollection:kSCCollection_STUsers];
}

- (void)processMessage:(STMessage *)message withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogVerbose(@"Burning message from(%@) with timestamp(%@)",
	             message.from,
	             [message.timestamp descriptionWithLocale:[NSLocale currentLocale]]);
    
	// Fetch the scloud item (if it exists) and delete the corresponding files from disk
	NSString *scloudId = message.siren.cloudLocator;
	if (scloudId)
	{
		STSCloud *scl = [transaction objectForKey:scloudId inCollection:kSCCollection_STSCloud];
		
		[scl removeFromCache];
	}
	
	// Delete the message
    [transaction removeObjectForKey:message.uuid
	                   inCollection:message.conversationId];
    
	// Notes:
	//
	// - The relationship extension will automatically remove the thumbnail (if needed)
	// - The relationship extension will automatically remove the scloud item (if needed)
	// - The hooks extension will automatically update the conversation item (if needed)
	
	if (message.isStatusMessage)
	{
		// Add a flag for this transaction specifying that we "cleared" this message.
		// This is used by the UI to avoid the usual burn animation when it sees a message was deleted.
		
		if (transaction.yapDatabaseModifiedNotificationCustomObject)
		{
			NSMutableDictionary *info = [transaction.yapDatabaseModifiedNotificationCustomObject mutableCopy];
			
			NSSet *clearedMessageIds = [info objectForKey:kTransactionExtendedInfo_ClearedMessageIds];
			if (clearedMessageIds)
				clearedMessageIds = [clearedMessageIds setByAddingObject:message.uuid];
			else
				clearedMessageIds = [NSSet setWithObject:message.uuid];
			
			[info setObject:clearedMessageIds forKey:kTransactionExtendedInfo_ClearedMessageIds];
			
			transaction.yapDatabaseModifiedNotificationCustomObject = [info copy];
		}
		else
		{
			NSDictionary *info = @{
			  kTransactionExtendedInfo_ClearedMessageIds: [NSSet setWithObject:message.uuid]
			};
			transaction.yapDatabaseModifiedNotificationCustomObject = info;
		}
	}
}

- (void)processAsymmetricKey:(STPublicKey *)key withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogInfo(@"Deleting STPublicKey(%@) with expired date: %@",
	          key.uuid, [key.expireDate descriptionWithLocale:[NSLocale currentLocale]]);
	
	[self deleteExpiredAsymmetricKey:key withTransaction:transaction];
}

- (void)processSymmetricKey:(STSymmetricKey *)symmetricKey
            withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogInfo(@"Deleting STSymmetricKey(%@) with expired date: %@",
	          symmetricKey.uuid, [symmetricKey.expireDate descriptionWithLocale:[NSLocale currentLocale]]);
	
	[transaction removeObjectForKey:symmetricKey.uuid
					   inCollection:kSCCollection_STSymmetricKeys];
}

- (void)processSRVRecord:(STSRVRecord *)srvRecord withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
    DDLogInfo(@"Expiring STSRVRecord: %@", srvRecord.srvName);
    
    [transaction removeObjectForKey:srvRecord.srvName
	                   inCollection:kSCCollection_STSRVRecord];
    
	// Maybe refire SRV lookup for this record ?
}

- (void)processSCloud:(STSCloud *)sclToExpire withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogInfo(@"Removing STSCloud(%@) cached files with unCacheDate: %@",
	          sclToExpire.uuid, [sclToExpire.unCacheDate descriptionWithLocale:[NSLocale currentLocale]]);

    STSCloud *scl = [sclToExpire copy];
    scl.unCacheDate = nil;
	
	[transaction setObject:scl
	                forKey:scl.uuid
	          inCollection:kSCCollection_STSCloud];
    
    [scl removeFromCache];
}

- (void)processNotifcation:(STNotification *)notification
           withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogInfo(@"Processing Notification: %@", notification.uuid);
	
	NSString *notificationType = [notification.userInfo objectForKey:kSTNotificationKey_Type];
	
	if ([notificationType isEqualToString:kSTNotificationType_SubscriptionExpire])
	{
		NSString *userID = notification.userID;
		STUser *user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
           
		if (user && user.isLocal)
		{
			__unsafe_unretained STLocalUser *localUser = (STLocalUser *)user;
			
			if (!localUser.subscriptionHasExpired &&
			    !localUser.subscriptionAutoRenews &&
			     localUser.subscriptionExpireDate)
			{
				[[STUserManager sharedInstance] resyncSubscriptionWarningsForLocalUser:localUser];
			}
		}
	}
	else // extend here for other kinds of STNotifications
	{
		// extend here for other kinds of STNotifications
	}
	
	// And don't forget to finally delete the notification
	// so it gets removed from the front of our queue.
	
	[transaction removeObjectForKey:notification.uuid
	                   inCollection:kSCCollection_STNotification];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Action Sub Processing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
- (void)deleteExpiredAsymmetricKey:(STPublicKey *)key withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	STUser *user = [transaction objectForKey:key.userID inCollection:kSCCollection_STUsers];
	if (user && [user.publicKeyIDs containsObject:key.uuid])
	{
		// Remove the key from the user.publicKeyIDs set.
		
		user = [user copy];
		
		NSMutableSet *newPublicKeyIDs = [user.publicKeyIDs mutableCopy];
		[newPublicKeyIDs removeObject:key.uuid];
		
		user.publicKeyIDs = [newPublicKeyIDs copy];
		
		if (user.isRemote)
		{
			// Since we deleted a pubKey,
			// let's make sure the currentKeyID is still correct.
			
			NSMutableArray *pubKeys = [NSMutableArray arrayWithCapacity:[newPublicKeyIDs count]];
			
			for (NSString *pubKeyID in newPublicKeyIDs)
			{
				STPublicKey *pubKey = [transaction objectForKey:pubKeyID inCollection:kSCCollection_STPublicKeys];
				if (pubKey) {
					[pubKeys addObject:pubKey];
				}
			}
			
			STPublicKey *currentKey = [STPublicKey currentKeyFromKeys:pubKeys]; // MUST use this method for proper alg
			user.currentKeyID = currentKey.uuid;
		}
		
		[transaction setObject:user
		                forKey:user.uuid
		          inCollection:kSCCollection_STUsers];
	}
		
	// The key should be deleted from the server by now.
	// But if not, we'll make one last attempt...
		
	if (user.isLocal && (key.serverDeleteDate == nil))
	{
		[[SCWebAPIManager sharedInstance] removePublicKeyWithLocator:key.uuid
		                                                forLocalUser:(STLocalUser *)user
		                                             completionBlock:NULL];
	}
	
	// Remove the key itself
	
	[transaction removeObjectForKey:key.uuid inCollection:kSCCollection_STPublicKeys];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Server Flags
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSUInteger)prevFlagsForIdentifier:(YapCollectionKey *)ck withNewFlags:(NSUInteger)newFlags
{
	__block NSUInteger oldFlags = 0;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		oldFlags = [[inFlightServerActions objectForKey:ck] unsignedIntegerValue];
		
		[inFlightServerActions setObject:@(newFlags) forKey:ck];
	}};
	
	if (dispatch_get_specific(dictionaryQueueTag))
		block();
	else
		dispatch_sync(dictionaryQueue, block);
	
	return oldFlags;
}

- (void)unsetFlag:(DatabaseActionManagerFlags)flag forIdentifier:(YapCollectionKey *)ck
{
	dispatch_block_t block = ^{ @autoreleasepool {
		
		NSUInteger flags = [[inFlightServerActions objectForKey:ck] unsignedIntegerValue];
		
		flags &= ~flag;
		
		[inFlightServerActions setObject:@(flags) forKey:ck];
	}};
	
	if (dispatch_get_specific(dictionaryQueueTag))
		block();
	else
		dispatch_sync(dictionaryQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Processing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)syncLocalUser:(STLocalUser *)localUser
       withIdentifier:(YapCollectionKey *)ck
          transaction:(YapDatabaseReadTransaction *)transaction
{
	NSUInteger oldFlags = 0;
	NSUInteger newFlags = 0;
	
	BOOL needsKeyGeneration = NO;
	BOOL needsRegisterPushToken = NO;
	BOOL needsDeprovisionUser = NO;
	BOOL awaitingReKeying = NO;
	
	if (localUser.needsKeyGeneration) {
		needsKeyGeneration = YES;
		newFlags |= Action_LocalUser_KeyGeneration;
	}
	
	if (localUser.needsRegisterPushToken) {
		needsRegisterPushToken = YES;
		newFlags |= Action_LocalUser_RegisterPushToken;
	}
	
	if (localUser.needsDeprovisionUser) {
		needsDeprovisionUser = YES;
		newFlags |= Action_LocalUser_DeprovisionUser;
	}
	
	if (localUser.awaitingReKeying) {
		awaitingReKeying = YES;
		newFlags |= Action_User_RefreshWebInfo;
	}
	
	// Atomically update flags:
	// - set new flags
	// - fetch old flags
	
	oldFlags = [self prevFlagsForIdentifier:ck withNewFlags:newFlags];
	
	// Sanity checks
	
	if (needsRegisterPushToken)
	{
		if (needsDeprovisionUser)
		{
			// deprovision implicitly unregisters pushToken
			
			needsDeprovisionUser = NO;
			DDLogWarn(@"LocalUser(%@) in unexpected shape: needsRegisterPushToken && needsDeprovisionUser",
			          localUser.jid);
		}
	}
	
	// Queue needed actions
	
	if (needsKeyGeneration && !(oldFlags & Action_LocalUser_KeyGeneration))
	{
		DDLogInfo(@"Generating new public/private key for localUser: %@", [localUser.jid bare]);
		
		__weak typeof(self) weakSelf = self;
		[[STUserManager sharedInstance] createPrivateKeyForUserID:localUser.uuid completionBlock:^(NSString *newKeyID) {
			
			[weakSelf completeKeyGeneration:newKeyID forLocalUserWithIdentifier:ck];
		}];
	}
	
	if (needsRegisterPushToken && !(oldFlags & Action_LocalUser_RegisterPushToken))
	{
		DDLogInfo(@"Registering pushToken for localUser: %@", [localUser.jid bare]);
		
		NSString *pushToken = localUser.pushToken;
		BOOL isDebug = [AppConstants isApsEnvironmentDevelopment];
		
		__weak typeof(self) weakSelf = self;
		[[SCWebAPIManager sharedInstance] registerApplicationPushToken:pushToken
		                                                  forLocalUser:localUser
		                                                  useDebugCert:isDebug
		                                               completionBlock:^(NSError *error, NSDictionary *infoDict)
		{
			if (error)
				[weakSelf failRegisterPushTokenForLocalUserWithIdentifier:ck];
			else
				[weakSelf completeRegisterPushToken:pushToken forLocalUserWithIdentifier:ck];
				
		 }];
	}
	
	if (needsDeprovisionUser && !(oldFlags & Action_LocalUser_DeprovisionUser))
	{
		DDLogInfo(@"Deprovisioning localUser: %@", [localUser.jid bare]);
		
		__weak typeof(self) weakSelf = self;
		[[SCWebAPIManager sharedInstance] deprovisionLocalUser:localUser
		                                       completionBlock:^(NSError *error, NSDictionary *infoDict)
		{
			if (error)
				[weakSelf failDeprovisionLocalUserWithIdentifier:ck error:error];
			else
				[weakSelf completeDeprovisionLocalUserWithIdentifier:ck];
		}];
	}
	
	if (awaitingReKeying && !(oldFlags & Action_User_RefreshWebInfo))
	{
		DDLogInfo(@"Refreshing WebInfo for user: %@", [localUser.jid bare]);
		
		__weak typeof(self) weakSelf = self;
		[[STUserManager sharedInstance] refreshWebInfoForLocalUser:localUser completionBlock:
		    ^(NSError *error, NSString *userID, NSDictionary *parsedInfo)
		{
			// The refreshWebInfo method automatically handles resetting the awaitingReKeying flag,
			// and invokes the proper methods in MessageStream to start the rekeying process.
			
			[weakSelf unsetFlag:Action_User_RefreshWebInfo forIdentifier:ck];
		}];
	}
}

- (void)syncUser:(STUser *)user
  withIdentifier:(YapCollectionKey *)ck
     transaction:(YapDatabaseReadTransaction *)transaction
{
	NSUInteger oldFlags = 0;
	NSUInteger newFlags = 0;
	
	if (user.awaitingReKeying)
		newFlags |= Action_User_RefreshWebInfo;
	
	// Atomically update flags:
	// - set new flags
	// - fetch old flags
	
	oldFlags = [self prevFlagsForIdentifier:ck withNewFlags:newFlags];
	
	// Queue needed actions
	
	if (user.awaitingReKeying && !(oldFlags & Action_User_RefreshWebInfo))
	{
		DDLogInfo(@"Refreshing WebInfo for user: %@", [user.jid bare]);
		
		__weak typeof(self) weakSelf = self;
		[[STUserManager sharedInstance] refreshWebInfoForUser:user completionBlock:
		    ^(NSError *error, NSString *userID, NSDictionary *parsedInfo)
		{
			// The refreshWebInfo method automatically handles resetting the awaitingReKeying flag,
			// and invokes the proper methods in MessageStream to start the rekeying process.
			
			[weakSelf unsetFlag:Action_User_RefreshWebInfo forIdentifier:ck];
		}];
	}
}

- (void)syncAsymmetricKey:(STPublicKey *)key
		   withIdentifier:(YapCollectionKey *)ck
              transaction:(YapDatabaseReadTransaction *)transaction
{
	NSUInteger oldFlags = 0;
	NSUInteger newFlags = 0;
	
	BOOL needsDelete = NO;
	BOOL needsUpload = NO;
	
	if (key.needsServerDelete) {
		needsDelete = YES;
		newFlags = Action_PublicKey_Delete;
	}
	else if (key.serverUploadDate == nil && key.serverDeleteDate == nil) {
		needsUpload = YES;
		newFlags |= Action_PublicKey_Upload;
	}
	
	// Atomically update flags:
	// - set new flags
	// - fetch old flags
	
	oldFlags = [self prevFlagsForIdentifier:ck withNewFlags:newFlags];
	
	// Queue needed actions
	
	if (needsDelete && !(oldFlags & Action_PublicKey_Delete))
	{
		STLocalUser *localUser = [transaction objectForKey:key.userID inCollection:kSCCollection_STUsers];
		if (localUser.isRemote)
		{
			NSAssert(NO, @"Oops");
			return;
		}
		
		DDLogInfo(@"Deleting publicKey(%@) from server for localUser: %@", key.uuid, [localUser.jid bare]);
		
		__weak typeof(self) weakSelf = self;
		[[SCWebAPIManager sharedInstance] removePublicKeyWithLocator:key.uuid
		                                                forLocalUser:localUser
		                                             completionBlock:^(NSError *error, NSDictionary *infoDict)
		{
			if (error)
				[weakSelf failDeleteForAsymmetricKeyWithIdentifier:ck];
			else
				[weakSelf completeDeleteForAsymmetricKeyWithIdentifier:ck];
		}];
	}
	
	if (needsUpload && !(oldFlags & Action_PublicKey_Upload))
	{
		STLocalUser *localUser = [transaction objectForKey:key.userID inCollection:kSCCollection_STUsers];
		if (localUser.isRemote)
		{
			NSAssert(NO, @"Oops");
			return;
		}
		
		DDLogInfo(@"Uploading publicKey(%@) to server for localUser: %@", key.uuid, [localUser.jid bare]);
		
		SCKeyContextRef keyContext = kInvalidSCKeyContextRef;
		SCKey_Deserialize(key.keyJSON, &keyContext);
		
		NSString *publicKeyString = nil;
		SCKey_SerializePublic(keyContext, &publicKeyString);
		
		if (SCKeyContextRefIsValid(keyContext))
		{
			SCKeyFree(keyContext);
			keyContext = kInvalidSCKeyContextRef;
		}
		
		__weak typeof(self) weakSelf = self;
		[[SCWebAPIManager sharedInstance] uploadPublicKeyWithLocator:key.uuid
		                                             publicKeyString:publicKeyString
		                                                forLocalUser:localUser
		                                             completionBlock:^(NSError *error, NSDictionary *infoDict)
		{
			if (error)
				[weakSelf failUploadForAsymmetricKeyWithIdentifier:ck];
			else
				[weakSelf completeUploadForAsymmetricKeyWithIdentifier:ck];
		}];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Error Processing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)failRegisterPushTokenForLocalUserWithIdentifier:(YapCollectionKey *)ck
{
	[self unsetFlag:Action_LocalUser_RegisterPushToken forIdentifier:ck];
}

- (void)failDeprovisionLocalUserWithIdentifier:(YapCollectionKey *)ck error:(NSError *)error
{
	DDLogWarn(@"Failed deprovisioning localUser: %@", error);
	
	[self unsetFlag:Action_LocalUser_DeprovisionUser forIdentifier:ck];
}

- (void)failDeleteForAsymmetricKeyWithIdentifier:(YapCollectionKey *)ck
{
	[self unsetFlag:Action_PublicKey_Delete forIdentifier:ck];
}

- (void)failUploadForAsymmetricKeyWithIdentifier:(YapCollectionKey *)ck
{
	[self unsetFlag:Action_PublicKey_Upload forIdentifier:ck];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Server Completion Processing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)completeKeyGeneration:(NSString *)newKeyID forLocalUserWithIdentifier:(YapCollectionKey *)ck
{
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STLocalUser *localUser = [transaction objectForKey:ck.key inCollection:ck.collection];
		if (localUser)
		{
			localUser = [localUser copy];
			localUser.nextKeyGeneration = [NSDate dateWithTimeIntervalSinceNow:[STPreferences publicKeyRefresh]];
			localUser.needsKeyGeneration = NO;
			
			[transaction setObject:localUser forKey:ck.key inCollection:ck.collection];
		}
		
		DDLogInfo(@"Generated new public/private key(%@) for localUser: %@", newKeyID, [localUser.jid bare]);
		
	} completionQueue:dictionaryQueue completionBlock:^{
		
		[self unsetFlag:Action_LocalUser_KeyGeneration forIdentifier:ck];
	}];
}

- (void)completeRegisterPushToken:(NSString *)pushToken forLocalUserWithIdentifier:(YapCollectionKey *)ck
{
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STLocalUser *localUser = [transaction objectForKey:ck.key inCollection:ck.collection];
		if (localUser)
		{
			// Sanity checks:
			// Make sure the push token hasn't changed since we registered it with the server.
			
			if (localUser.needsRegisterPushToken && [pushToken isEqualToString:localUser.pushToken])
			{
				localUser = [localUser copy];
				localUser.needsRegisterPushToken = NO;
				
				[transaction setObject:localUser forKey:ck.key inCollection:ck.collection];
			}
		}
		
		DDLogInfo(@"Registered pushToken(%@) for localUser: %@", pushToken, [localUser.jid bare]);
		
	} completionQueue:dictionaryQueue completionBlock:^{
		
		[self unsetFlag:Action_LocalUser_RegisterPushToken forIdentifier:ck];
	}];
}

- (void)completeDeprovisionLocalUserWithIdentifier:(YapCollectionKey *)ck
{
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STLocalUser *localUser = [transaction objectForKey:ck.key inCollection:ck.collection];
		if (localUser)
		{
			localUser = [localUser copy];
			localUser.needsDeprovisionUser = NO;
			
			[transaction setObject:localUser forKey:ck.key inCollection:ck.collection];
		}
		
		DDLogInfo(@"Deprovisioned localUser: %@", [localUser.jid bare]);
		
	} completionBlock:^{
		
		[self unsetFlag:Action_LocalUser_DeprovisionUser forIdentifier:ck];
		
		// Post info message for the user account
		
		NSString *msg = NSLocalizedString(@"You have deauthorized this device for Silent Text.",
		                                  @"Deauthorization message");
		
		NSString *localUserID = ck.key;
		[MessageStream sendInfoMessage:msg toUser:localUserID];
	}];
}

- (void)completeDeleteForAsymmetricKeyWithIdentifier:(YapCollectionKey *)ck
{
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STPublicKey *key = [transaction objectForKey:ck.key inCollection:ck.collection];
		if (key)
		{
			key = [key copy];
			key.needsServerDelete = NO;
			key.serverDeleteDate = [NSDate date];
			
			[transaction setObject:key forKey:ck.key inCollection:ck.collection];
		}
		
		if (ddLogLevel & LOG_FLAG_INFO)
		{
			STUser *localUser = [transaction objectForKey:key.userID inCollection:kSCCollection_STUsers];
			
			DDLogInfo(@"Deleted publicKey(%@) from server for localUser: %@", key.uuid, [localUser.jid bare]);
		}
		
	} completionQueue:dictionaryQueue completionBlock:^{
		
		[self unsetFlag:Action_PublicKey_Delete forIdentifier:ck];
	}];
}

- (void)completeUploadForAsymmetricKeyWithIdentifier:(YapCollectionKey *)ck
{
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STPublicKey *key = [transaction objectForKey:ck.key inCollection:ck.collection];
		if (key)
		{
			key = [key copy];
			key.serverUploadDate = [NSDate date];
			
			[transaction setObject:key forKey:ck.key inCollection:ck.collection];
		}
		
		if (ddLogLevel & LOG_FLAG_INFO)
		{
			STUser *localUser = [transaction objectForKey:key.userID inCollection:kSCCollection_STUsers];
			
			DDLogInfo(@"Uploaded publicKey(%@) to server for localUser: %@", key.uuid, [localUser.jid bare]);
		}
		
	} completionQueue:dictionaryQueue completionBlock:^{
		
		[self unsetFlag:Action_PublicKey_Upload forIdentifier:ck];
	}];
}

@end
