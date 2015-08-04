/*
Copyright (C) 2013-2015, Silent Circle, LLC. All rights reserved.

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
#import "MessageStream.h"

#import "AppConstants.h"
#import "AppDelegate.h"
#import "GeoTracking.h"
#if TARGET_OS_IPHONE
  #import "SCAssetInfo.h"
#endif
#import "SCDateFormatter.h"
#import "SCimpSnapshot.h"
#import "SCimpWrapper.h"
#import "SCimpUtilities.h"
#import "SCloudManager.h"
#import "SCloudObject.h"
#import "SCSRVResolver.h"
#import "SCWebAPIManager.h"
#import "SRVManager.h"
#import "STConversation.h"
#import "STImage.h"
#import "STLogging.h"
#import "STMessage.h"
#import "STMessageIDCache.h"
#import "STPreferences.h"
#import "STPublicKey.h"
#import "STSCloud.h"
#import "STSoundManager.h"
#import "STStreamManagement.h"
#import "STSymmetricKey.h"
#import "STUser.h"
#import "STUserManager.h"
#import "STXMPPElement.h"
#import "XMPPFramework.h"
#import "YapCollectionKey.h"
#import "YapDatabase.h"

// Categories
#if TARGET_OS_IPHONE
  #import "ALAsset+SCUtilities.h"
#endif
#import "CLLocation+NSDictionary.h"
#import "CLLocation+SCUtilities.h"
#import "NSDate+SCDate.h"
#import "NSString+SCUtilities.h"
#import "YapDatabaseTransaction+MessageStream.h"

// Libraries
#import <CommonCrypto/CommonDigest.h>
#import <libkern/OSAtomic.h>
#import <SCCrypto/SCcrypto.h>


// LEVELS: off, error, warn, info, verbose
// FLAGS : trace
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

/**
 * Seeing a return statements within an inner block
 * can sometimes be mistaken for a return point of the enclosing method.
 * This makes inline blocks a bit easier to read.
**/
#define return_from_block return

// We chose to use Common Crypto to do SHA hashing because it's very fast and optimized on iOS devices.
#define USE_CC 1

// Transitioning to Reliable Message Delivery (RMD).
// Previous versions will have items in the queue that need to be ignored (and not resent).
NSString *const rmdQueueTransitionKey = @"rdm-queue-3";

// MessageStreamDidChangeState notification & keys
//
NSString *const MessageStreamDidChangeStateNotification = @"MessageStreamDidChangeState";
NSString *const kMessageStreamUserJidKey  = @"MessageStream_userJid";
NSString *const kMessageStreamUserUUIDKey = @"MessageStream_userUUID";
NSString *const kMessageStreamStateKey    = @"MessageStream_state";
NSString *const kMessageStreamErrorKey    = @"MessageStream_errorString";

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This class is used by the SCimpEventHandler, which is a C-style function callback with a "void *" parameter.
 *
 * The MessageStreamUserInfo is the "void *" parameter we use in order to
 * get a reference to objective-c objects we need.
**/
@interface MessageStreamUserInfo : NSObject {
@public
	
	MessageStream *ms;
	YapDatabaseReadWriteTransaction *transaction;
}
@end

@implementation MessageStreamUserInfo
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface MessageStream ()
@property (atomic, assign, readwrite) BOOL isKilled;
@property (atomic, assign, readwrite) BOOL hasPendingQueuedKeyingMessages;
@property (atomic, assign, readwrite) BOOL hasPendingQueuedDataStanzas;
@end

@implementation MessageStream
{
	dispatch_queue_t messageStreamQueue;
	void *messageStreamQueueTag;
	
	NSString *networkID;
    NSDictionary *capabilitiesDict;
	
	NSString *xmppPassword;
	
	NSString *connectedHostName;
	uint16_t connectedHostPort;
	
	YapDatabaseConnection *databaseConnection;
	
	XMPPStream *xmppStream;
	XMPPReconnect *xmppReconnect;
	XMPPStreamManagement *xmppStreamManagement;
	
	#if DEBUG
	GCDAsyncSocket *_tempAsyncSocket;
	#endif
	
	NSMutableDictionary *filteredMessageIds; // key=conversationID, value=[NSMutableOrderedSet of messageIDs]
	
	BOOL hasReceivedPresence;
    BOOL replacedByNewConnection;
	
	NSMutableArray *scimpCache;  // Array of SCimpWrapper objects
	SCimpWrapper *pubScimp;
	
	// SpinLock protected variables
	
	OSSpinLock spinlock;
	
	MessageStream_State  __spinlock_messageStreamState;
	NSString           * __spinlock_errorString;
	NSUInteger           __spinlock_connectionID;
}

@synthesize localJID = localJID;
@synthesize localUserID = localUserID;

@synthesize isKilled;
@synthesize hasPendingQueuedKeyingMessages = __mustUseAtomicGetterSetter_hasPendingQueuedKeyingMessages;
@synthesize hasPendingQueuedDataStanzas    = __mustUseAtomicGetterSetter_hasPendingQueuedDataStanzas;

@dynamic state;       // Public getter goes through messageStreamQueue
@dynamic errorString; // Public getter goes through messageStreamQueue


- (id)initWithUser:(STLocalUser *)localUser
{
	if (localUser == nil)
	{
		DDLogWarn(@"[MessageStream initWithUser: *** nil ***] ?!?");
		return nil;
	}
	
 	if ((self = [super init]))
	{
		messageStreamQueue = dispatch_queue_create("MessageStream", DISPATCH_QUEUE_SERIAL);
		
		messageStreamQueueTag = &messageStreamQueueTag;
		dispatch_queue_set_specific(messageStreamQueue, messageStreamQueueTag, messageStreamQueueTag, NULL);
		
		spinlock = OS_SPINLOCK_INIT;
		
        databaseConnection = [STDatabaseManager.database newConnection];
		databaseConnection.objectCacheLimit = 200;
		databaseConnection.metadataCacheLimit = 200;
		databaseConnection.name = @"MessageStream";
		
		localUserID  = localUser.uuid;
		networkID    = localUser.networkID;
		xmppPassword = localUser.xmppPassword;
		
		NSString *xmppResource = localUser.xmppResource;
		
		localJID = [localUser.jid jidWithNewResource:xmppResource];
		
		capabilitiesDict = @{
		  @"canSendMedia"           : @(localUser.canSendMedia),
		  @"audioWithoutThumbNails" : @(YES),
		  @"vCardWithoutThumbNails" : @(YES)
		};
		
		filteredMessageIds = [[NSMutableDictionary alloc] init];
		
		scimpCache = [[NSMutableArray alloc] init];
		
		[self configureXmpp];
		[self configurePubScimp];
	}
	return self;
}

- (void)dealloc
{
	DDLogAutoTrace();
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)configureXmpp
{
	DDLogAutoTrace();
	
	if (xmppStream != nil) return;
	
	xmppStream = [[XMPPStream alloc] init];
//	xmppStream.skipStartSession = YES; // uncomment when the server supports it to remove 1 round-trip during connect
    
    xmppReconnect = [[XMPPReconnect alloc] init];
	xmppReconnect.usesOldSchoolSecureConnect = YES;
	
	xmppStreamManagement = [[XMPPStreamManagement alloc] initWithStorage:self]; //<- retain loop. See disconnectAndKill
	xmppStreamManagement.autoResume = YES;
	xmppStreamManagement.ackResponseDelay = 0.2;
	
	[xmppStreamManagement automaticallyRequestAcksAfterStanzaCount:2 orTimeout:0.2]; // request acks after delay
	[xmppStreamManagement automaticallySendAcksAfterStanzaCount:1 orTimeout:0.0];    // send acks immediately
	
	[xmppReconnect activate:xmppStream];
	[xmppStreamManagement activate:xmppStream];
	
	[xmppStream addDelegate:self delegateQueue:messageStreamQueue];
	[xmppReconnect addDelegate:self delegateQueue:messageStreamQueue];
	[xmppStreamManagement addDelegate:self delegateQueue:messageStreamQueue];
}

- (void)configurePubScimp
{
	SCimpContextRef pubScimpCtx = kInvalidSCimpContextRef;
	SCLError err = SCimpNew([[localJID bare] UTF8String], NULL, &pubScimpCtx);
	
	if (err != kSCLError_NoErr)
	{
		DDLogError(@"SCimpNew error = %d", err);
	}
	
	SCimpCipherSuite cipherSuite = [STPreferences scimpCipherSuite];
	SCimpSAS sasMethod = [STPreferences scimpSASMethod];
	
	SCimpSetNumericProperty(pubScimpCtx, kSCimpProperty_CipherSuite, cipherSuite);
	SCimpSetNumericProperty(pubScimpCtx, kSCimpProperty_SASMethod, sasMethod);
	
	pubScimp = [[SCimpWrapper alloc] initWithPubSCimpCtx:pubScimpCtx];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark State
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (MessageStream_State)state
{
	MessageStream_State state;
	[self getMessageStreamState:&state errorString:NULL connectionID:NULL];
	
	return state;
}

- (NSString *)errorString
{
	NSString *errorString = nil;
	[self getMessageStreamState:NULL errorString:&errorString connectionID:NULL];
	
	return errorString;
}

- (BOOL)isConnected
{
	return (self.state == MessageStream_State_Connected);
}

- (BOOL)isConnecting
{
	return (self.state == MessageStream_State_Connecting);
}

- (NSString *)connectedHostName
{
	__block NSString *result = nil;
	
	dispatch_block_t block = ^{
		result = connectedHostName;
	};
	
	if (dispatch_get_specific(messageStreamQueueTag))
		block();
	else
		dispatch_sync(messageStreamQueue, block);
	
	return result;
}

- (uint16_t)connectedHostPort
{
	__block uint16_t result = 0;
	
	dispatch_block_t block = ^{
		result = connectedHostPort;
	};
	
	if (dispatch_get_specific(messageStreamQueueTag))
		block();
	else
		dispatch_sync(messageStreamQueue, block);
	
	return result;
}

- (void)getMessageStreamState:(MessageStream_State *)statePtr
                  errorString:(NSString **)errorStringPtr
                 connectionID:(NSUInteger *)connectionIDPtr
{
	OSSpinLockLock(&spinlock);
	@try {
		
		if (statePtr)        *statePtr        = __spinlock_messageStreamState;
		if (errorStringPtr)  *errorStringPtr  = __spinlock_errorString;
		if (connectionIDPtr) *connectionIDPtr = __spinlock_connectionID;
	}
	@finally {
		OSSpinLockUnlock(&spinlock);
	}
}

- (NSUInteger)setMessageStreamState:(MessageStream_State)newState
                        errorString:(NSString *)newErrorString
{
	NSUInteger connectionID = 0;
	
	OSSpinLockLock(&spinlock);
	@try {
		
		__spinlock_messageStreamState = newState;
		__spinlock_errorString = newErrorString;
		
		if (newState == MessageStream_State_Connecting) {
			__spinlock_connectionID++;
		}
		
		connectionID = __spinlock_connectionID;
	}
	@finally {
		OSSpinLockUnlock(&spinlock);
	}
	
	[self notifyStateChange:newState errorString:newErrorString];
	
	return connectionID;
}

- (void)notifyStateChange:(MessageStream_State)newState errorString:(NSString *)errorString
{
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:4];
	
	userInfo[kMessageStreamUserJidKey] = [localJID bare];
	userInfo[kMessageStreamUserUUIDKey] = localUserID;
	userInfo[kMessageStreamStateKey] = @(newState);
	
	if (errorString) {
		userInfo[kMessageStreamErrorKey] = errorString;
	}
	
	// Requirement: ALWAYS post the notifications asynchronously !
	//
	// Notifications are expected to be within their own run-loop.
	// Posting them synchronously in response to a user-invocation of a method in our public API is
	// just asking for an edge-case. And, in fact, has lead to deadlock in the past.
	//
	dispatch_async(dispatch_get_main_queue(), ^{
	
		[[NSNotificationCenter defaultCenter] postNotificationName:MessageStreamDidChangeStateNotification
		                                                    object:self
		                                                  userInfo:userInfo];
	});
}

- (void)notifyLocalUserActiveDeviceMayHaveChanged
{
	NSDictionary *userInfo = @{ @"localUserID" : localUserID };
	
	// Requirement: ALWAYS post the notifications asynchronously !
	//
	// Notifications are expected to be within their own run-loop.
	// Posting them synchronously in response to a user-invocation of a method in our public API is
	// just asking for an edge-case. And, in fact, has lead to deadlock in the past.
	//
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[[NSNotificationCenter defaultCenter] postNotificationName:LocalUserActiveDeviceMayHaveChangedNotification
		                                                    object:nil
		                                                  userInfo:userInfo];
	});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connect
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)connect
{
	DDLogAutoTrace();
	
	dispatch_block_t block = ^{ @autoreleasepool{
	
		// Validate state (shouldn't be connected / connecting already)
		
		MessageStream_State currentState;
		[self getMessageStreamState:&currentState errorString:NULL connectionID:NULL];
		
		if (currentState == MessageStream_State_Connected ||
		    currentState == MessageStream_State_Connecting )
		{
			DDLogWarn(@"Attempting to connect while already connected/connecting...");
			return_from_block;
		}
		
		if (self.isKilled)
		{
			DDLogWarn(@"Attempting to connect after being killed...");
			return_from_block;
		}
		
		// Sanity checks.
		// Spit out warnings if critical stuff is missing.
		
		if (localJID == nil) // Is this possible anymore ?
		{
			DDLogWarn(@"Unable to connect - localJID is nil ?!?");
			return_from_block;
		}
		
		__block STLocalUser *localUser = nil;
		[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			localUser = [transaction objectForKey:localUserID inCollection:kSCCollection_STUsers];
		}];
		
		if (!localUser.isEnabled)
		{
			MessageStream_State state = MessageStream_State_Error;
			NSString *errorString = NSLocalizedString(@"Account Disabled", @"Account Disabled");
			
			[self setMessageStreamState:state errorString:errorString];
			return_from_block;
		}
		
		xmppPassword = localUser.xmppPassword;
		if (!localUser.isActivated || xmppPassword.length == 0)
		{
			MessageStream_State state = MessageStream_State_Error;
			NSString *errorString = NSLocalizedString(@"User Not Activated", @"User Not Activated");
			
			[self setMessageStreamState:state errorString:errorString];
			return_from_block;
		}
		
		if (localUser.subscriptionHasExpired)
		{
			MessageStream_State state = MessageStream_State_Error;
			NSString *errorString = NSLocalizedString(@"Subscription Expired", @"Subscription Expired");
			
			[self setMessageStreamState:state errorString:errorString];
			return_from_block;
		}
		
		// Safety check for older versions that would clear localUser.xmppResource
		if (localJID.resource == nil)
		{
			NSString *xmppResource = localUser.xmppResource;
			localJID = [localJID jidWithNewResource:xmppResource];
		}
	
		// Start connection process
		
		NSUInteger requiredConnectionID = [self setMessageStreamState:MessageStream_State_Connecting errorString:nil];
		
		__weak MessageStream *weakSelf = self;
		[[SRVManager sharedInstance] xmppForNetworkID:networkID
		                               completionBlock:^(NSError *error, NSArray *srvArray)
         {
             
		#pragma clang diagnostic push
		#pragma clang diagnostic warning "-Wimplicit-retain-self"
			
             [weakSelf continueConnect:requiredConnectionID withError:error srvArray:srvArray];
			
		#pragma clang diagnostic pop
		}];
	}};
	
	if (dispatch_get_specific(messageStreamQueueTag))
		block();
	else
		dispatch_async(messageStreamQueue, block);
}

- (void)continueConnect:(NSUInteger)requiredConnectionID
              withError:(NSError *)error
               srvArray:(NSArray*)srvArray
{
	DDLogAutoTrace();
	
	dispatch_block_t block = ^{ @autoreleasepool {
	
		MessageStream_State state;
		NSUInteger connectionID;
		[self getMessageStreamState:&state errorString:NULL connectionID:&connectionID];
		
		if ((requiredConnectionID != connectionID) || (state != MessageStream_State_Connecting))
		{
			// Ignore - MessageStream already disconnected
			return;
		}
		
		if (error)
		{
			DDLogWarn(@"Unable to connect. SRV error: %@", error);
			
			state = MessageStream_State_Error;
			NSString *errorString = error.localizedDescription;
			
			[self setMessageStreamState:state errorString:errorString];
		}
		else
		{
			DDLogOrange(@"srvArray: %@", srvArray);
			
			SCSRVRecord *srvRecord = [srvArray firstObject];
            
            NSString *host   = srvRecord.host;
            NSString *hostIP = srvRecord.hostIP;
            NSNumber *port   = @(srvRecord.port);
			port = @(443);
			
			xmppStream.myJID = localJID;
			xmppStream.hostName = hostIP ?: host;
			xmppStream.hostPort = [port unsignedShortValue];
			
			NSError *xmppError = nil;
			
			if (![xmppStream oldSchoolSecureConnectWithTimeout:XMPPStreamTimeoutNone error:&xmppError])
			{

				DDLogError(@"XMPPStream configuration error: %@", xmppError);
				
				state = MessageStream_State_Error;
				NSString *errorString = xmppError.localizedDescription;
				
				[self setMessageStreamState:state errorString:errorString];
			}
		}
	}};
	
	if (dispatch_get_specific(messageStreamQueueTag))
		block();
	else
		dispatch_async(messageStreamQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Disconnect
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)disconnect
{
	DDLogAutoTrace();
	
	MessageStream_State state;
	NSString *errorString = nil;
	[self getMessageStreamState:&state errorString:&errorString connectionID:NULL];
	
	if (state == MessageStream_State_Error)
	{
		[self setMessageStreamState:MessageStream_State_Disconnected errorString:errorString];
	}
	
	// This affects stream resumption:
	//
	// [xmppStream disconnect] => TCP disconnection (FIN)
	// [xmppStream disconnectAfterSending] => XMPP disconnection (</stream:stream> + FIN)
	//
	// TCP disconnect only => server maintains our state for a bit (~ 5 mins)
	// XMPP disconnect => server closes our stream (no resumption)
	
//	[xmppStream disconnect];
	[xmppStream disconnectAfterSending];
}

/**
 * This method kills the MessageStream instance so it cannot be used again.
 * 
 * Why does this method exist ?
 *
 * - Because the MessageStream class is largely self-controlled.
 *   Once created it has the ability to reconnect its xmppStream at will.
 *
 * - Because this class has a retain loop with xmppStreamManagement.
 *   So we need to break this in order to be able to dealloc the instance.
**/
- (void)disconnectAndKill
{
	// Set kill flag
	// - prevents future connect attempts
	// - tears down xmppStream plugins in xmppStreamDidDisconnect:withError:
	self.isKilled = YES;
	
	// Use regular disconnect method for logic
	[self disconnect];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Queueing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method sends the queued elements (if needed),
 * before allowing other elements to be sent over the newly connected xmppStream.
**/
- (void)sendQueuedItems:(NSUInteger)requiredConnectionID
{
	NSMutableSet *processedStanzaIds = [NSMutableSet set];
	
	__block BOOL drainRmdQueue = NO;
	
	[databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		BOOL rmdQueueReady = [transaction hasObjectForKey:rmdQueueTransitionKey inCollection:kSCCollection_Upgrades];
		if (!rmdQueueReady)
		{
			drainRmdQueue = YES;
			
			// Don't set the flag until we've actually drained the queue.
		}
		
	} completionQueue:messageStreamQueue completionBlock:^{
		
		[self sendQueuedItemsLoop:requiredConnectionID
		   withProcessedStanzaIds:processedStanzaIds
		            drainRmdQueue:drainRmdQueue];
	}];
}

- (void)sendQueuedItemsLoop:(NSUInteger)requiredConnectionID
     withProcessedStanzaIds:(NSMutableSet *)processedStanzaIds
              drainRmdQueue:(BOOL)drainRmdQueue
{
	
	const NSUInteger maxNumProcessedPerTransaction = 20;
	__block BOOL doneProcessingAllQueuedStanzas = NO;
	
    NSMutableArray *transactionCompletionBlocks = [[NSMutableArray alloc] init];
    
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
        transaction.completionBlocks = transactionCompletionBlocks;
		transaction.requiredConnectionID = @(requiredConnectionID);
		transaction.isSendQueuedItemsLoop = YES;
		
		YapDatabaseViewTransaction *queueViewTransaction = [transaction ext:Ext_View_Queue];
		
		if ([processedStanzaIds count] == 0)
		{
			DDLogVerbose(@"sendQueuedItems: %lu items in queue (total)",
			  (unsigned long)[queueViewTransaction numberOfItemsInGroup:localUserID]);
		}
		else
		{
			DDLogVerbose(@"sendQueuedItems: %lu items in queue (left)",
			  (unsigned long)([queueViewTransaction numberOfItemsInGroup:localUserID] - [processedStanzaIds count]));
		}
		
		//
		// Helper block to send a queued STMessage
		//
		
		void (^ProcessSTMessage)(STMessage *message, YapCollectionKey *stanzaId, BOOL *modifiedDB);
		ProcessSTMessage     = ^(STMessage *message, YapCollectionKey *stanzaId, BOOL *modifiedDB){
			
			if (message.needsEncrypting || message.needsUpload)
			{
				// Ignore. Not ready to send over xmpp yet.
				return;
			}
			
			STConversation *conversation =
			  [transaction objectForKey:message.conversationId inCollection:message.userId];
			
			XMPPMessage *xmppMessage = [self xmppMessageForMessage:message withConversation:conversation];
			
			DDLogInfo(@"sendQueuedItems: Dequeing message: %@", message.uuid);
			
			if (!drainRmdQueue)
			{
				[self trySendXmppStanza:xmppMessage withTransaction:transaction];
				*modifiedDB = YES;
			}
			
			// Update the message object (if needed)
			
			if (message.sendDate == nil || drainRmdQueue)
			{
				NSDate *now = [NSDate date];
				
				STMessage *updatedMessage = [message copy];
				
				if (updatedMessage.sendDate == nil)
					updatedMessage.sendDate = now;
				
				if (drainRmdQueue) {
					updatedMessage.serverAckDate = now;
					[processedStanzaIds removeObject:stanzaId];
				}
				
				[transaction setObject:updatedMessage
				                forKey:updatedMessage.uuid
				          inCollection:updatedMessage.conversationId];
				
				*modifiedDB = YES;
			}
		};
		
		//
		// Helper block to send a queued STXMPPElement
		//
		
		void (^ProcessSTXMPPElement)(STXMPPElement *element, YapCollectionKey *stanzaId, BOOL *modifiedDB);
		ProcessSTXMPPElement     = ^(STXMPPElement *element, YapCollectionKey *stanzaId, BOOL *modifiedDB){
			
			XMPPElement *xmppElement = element.element;
			
			DDLogInfo(@"sendQueuedItems: Dequeueing stanza: elementID = %@", [xmppElement elementID]);
			
			if (!drainRmdQueue)
			{
				[self trySendXmppStanza:xmppElement withTransaction:transaction];
				*modifiedDB = YES;
			}
			
			if (drainRmdQueue)
			{
				[transaction removeObjectForKey:stanzaId.key inCollection:stanzaId.collection];
				[processedStanzaIds removeObject:stanzaId];
				
				*modifiedDB = YES;
			}
		};
		
		
		__block NSUInteger numProcessed = 0;
		
		//
		// STEP 1 of 3
		//
		// Process keying messages FIRST.
		// We do this BEFORE processing any non-keying messages.
		//
		
		__block BOOL doneProcessingKeyingMessages = NO;
		
		while (!doneProcessingKeyingMessages && (numProcessed < maxNumProcessedPerTransaction))
		{
			doneProcessingKeyingMessages = YES;
			
			NSUInteger groupCount = [queueViewTransaction numberOfItemsInGroup:localUserID];
			NSRange groupRange = NSMakeRange(0, groupCount);
			
			__block YapCollectionKey *stanzaId = nil; // set in filterBlock
			[queueViewTransaction enumerateKeysAndObjectsInGroup:localUserID
			                                         withOptions:0
			                                               range:groupRange
			                                              filter:^BOOL(NSString *collection, NSString *key)
			{
				stanzaId = YapCollectionKeyCreate(collection, key);
				
				if ([processedStanzaIds containsObject:stanzaId]) {
					// We already processed this item in a previous loop
					return NO;
				}
				else {
					return YES;
				}
				
			} usingBlock:^(NSString *collection, NSString *key, id object, NSUInteger index, BOOL *stop) {
				
				// Note: The filter (above) is invoked first.
				
				BOOL modifiedDB = NO;
				
				if ([object isKindOfClass:[STXMPPElement class]])
				{
					__unsafe_unretained STXMPPElement *element = (STXMPPElement *)object;
					
					if (element.isKeyingMessage)
					{
						[processedStanzaIds addObject:stanzaId];
						
						ProcessSTXMPPElement(element, stanzaId, &modifiedDB);
						numProcessed++;
					}
				}
				
				// modifiedDB ?
				//   -> need to break out of enumeration since we modified the database
				//
				// numProcessed >= maxNumProcessedPerTransaction ?
				//   -> take a breather and let another readWriteTransaction execute
				
				if (modifiedDB || (numProcessed >= maxNumProcessedPerTransaction))
				{
					*stop = YES;
					doneProcessingKeyingMessages = NO;
				}
				
			}]; // end [queueViewTransaction enumerateKeysAndObjectsInGroup:::
				
		} // end while (!doneProcessingKeyingMessages && (numProcessed < maxNumProcessedPerTransaction));
		
		if (doneProcessingKeyingMessages)
		{
			self.hasPendingQueuedKeyingMessages = NO;
		}
		
		//
		// STEP 2 of 3
		//
		// Process data stanzas (non-keying messages).
		// We do this AFTER processing any keying messages.
		//
		
		__block BOOL doneProcessingDataSanzas = NO;
		
		while (!doneProcessingDataSanzas && (numProcessed < maxNumProcessedPerTransaction))
		{
			doneProcessingDataSanzas = YES;
			
			NSUInteger groupCount = [queueViewTransaction numberOfItemsInGroup:localUserID];
			NSRange groupRange = NSMakeRange(0, groupCount);
			
			__block YapCollectionKey *stanzaId = nil; // set in filterBlock
			[queueViewTransaction enumerateKeysAndObjectsInGroup:localUserID
			                                         withOptions:0
			                                               range:groupRange
			                                              filter:^BOOL(NSString *collection, NSString *key)
			{
				stanzaId = YapCollectionKeyCreate(collection, key);
				
				if ([processedStanzaIds containsObject:stanzaId]) {
					// We already processed this item in a previous loop
					return NO;
				}
				else {
					return YES;
				}
				
			} usingBlock:^(NSString *collection, NSString *key, id object, NSUInteger index, BOOL *stop) {
				
				// Note: The filter (above) is invoked first.
				
				BOOL modifiedDB = NO;
				
				if ([object isKindOfClass:[STXMPPElement class]])
				{
					__unsafe_unretained STXMPPElement *element = (STXMPPElement *)object;
					
					if (!element.isKeyingMessage)
					{
						[processedStanzaIds addObject:stanzaId];
						
						ProcessSTXMPPElement(element, stanzaId, &modifiedDB);
						numProcessed++;
					}
				}
				else if ([object isKindOfClass:[STMessage class]])
				{
					__unsafe_unretained STMessage *message = (STMessage *)object;
					
					[processedStanzaIds addObject:stanzaId];
					
					ProcessSTMessage(message, stanzaId, &modifiedDB);
					numProcessed++;
				}
				
				// modifiedDB ?
				//   -> need to break out of enumeration since we modified the database
				//
				// numProcessed >= maxNumProcessedPerTransaction ?
				//   -> take a breather and let another readWriteTransaction execute
				
				if (modifiedDB || (numProcessed >= maxNumProcessedPerTransaction))
				{
					*stop = YES;
					doneProcessingDataSanzas = NO;
				}
			}];
		}
		
		if (doneProcessingDataSanzas)
		{
			self.hasPendingQueuedDataStanzas = NO;
		}
		
		//
		// Step 3 of 3
		//
		// Check to see if we're completely done.
		//
		
		if (doneProcessingKeyingMessages && doneProcessingDataSanzas)
		{
			if (drainRmdQueue) {
				[transaction setObject:@(YES) forKey:rmdQueueTransitionKey inCollection:kSCCollection_Upgrades];
			}
			
			doneProcessingAllQueuedStanzas = YES;
		}
			
	}
	completionQueue:messageStreamQueue
	completionBlock:^{
		
        DDLogVerbose(@"sendQueuedItems: done = %@", (doneProcessingAllQueuedStanzas ? @"YES" : @"NO"));
        
		if (!doneProcessingAllQueuedStanzas)
		{
			// Make sure the xmppStream is still connected,
			// and that we haven't been disconnected & reconnected since we started our process.
			
			MessageStream_State state;
			NSUInteger connectionID;
			[self getMessageStreamState:&state errorString:NULL connectionID:&connectionID];
			
			if ((state == MessageStream_State_Connected) && (connectionID == requiredConnectionID))
			{
				[self sendQueuedItemsLoop:requiredConnectionID
				   withProcessedStanzaIds:processedStanzaIds
				            drainRmdQueue:drainRmdQueue];
			}
		}
			
	}]; // end [databaseConnection asyncReadWriteWithBlock:
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Send Siren
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Use this method when creating a new conversation.
 * That is, when the user chooses to create a new conversation, and chooses a single recipient.
 *
 * This method will automatically create the conversation (if needed),
 * and then sends the given siren to the given jid.
 *
 * @param withPush
 *   The push attribute to specify in the XML for the server.
 *   (whether or not the server should send push notification)
 *
 * @param withBadge
 *   The badge attribute to specify in the XML for the server.
 *   (whether or not the server should include in badge count)
 *
 * @param createMessage
 *   If YES, then a corresponding STMessage is automatically created and added to the conversation.
 *   If NO, then a STMessage will not be created (send siren/xmpp only).
 *
 * @param completionBlock
 *   messageId         - The uuid of the corresponding STMessage that was created
 *   conversationId    - The uuid of the corresponding STConversation (which may have been created)
**/
- (void)sendSiren:(Siren *)siren
            toJID:(XMPPJID *)recipientJID
         withPush:(BOOL)withPush
            badge:(BOOL)withBadge
    createMessage:(BOOL)createMessage
       completion:(void (^)(NSString *messageId, NSString *conversationId))completionBlock
{
	DDLogAutoTrace();
	
	// Sanity checks
	
	if (siren == nil) {
		DDLogWarn(@"%@ - Ignoring: siren == nil", THIS_METHOD);
		return;
	}
	if (recipientJID == nil) {
		DDLogWarn(@"%@ - Ignoring: recipient == nil", THIS_METHOD);
		return;
	}
	
	NSAssert([recipientJID isKindOfClass:[XMPPJID class]], @"Invalid parameter type: 'recipient' not a jid");
	
	// Generate conversationId from JIDs using a hashing technique.
	// This makes it faster to find conversationIds given an xmpp stanza with just a remoteJID.
	
	NSString *conversationID = [self conversationIDForRemoteJid:recipientJID];
	__block NSString *messageID = nil;
	
	NSMutableArray *transactionCompletionBlocks = [[NSMutableArray alloc] init];
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		transaction.completionBlocks = transactionCompletionBlocks;
		
		// Create conversation if needed,
		// or touch the conversation lastUpdated timestamp.
		
		STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
		if (conversation == nil)
		{
			conversation = [[STConversation alloc] initWithUUID:conversationID
			                                        localUserID:localUserID
			                                           localJID:[localJID bareJID]
			                                          remoteJID:recipientJID];
			
			conversation.sendReceipts = [STPreferences defaultSendReceipts];
			conversation.shouldBurn   = [STPreferences defaultShouldBurn];
			conversation.shredAfter   = [STPreferences defaultBurnTime];
			
			if (createMessage)
				conversation.hidden = NO;
			else
				conversation.hidden = YES;
			
			[transaction setObject:conversation
			                forKey:conversation.uuid
			          inCollection:conversation.userId];
		}
		else if (conversation.hidden && createMessage)
		{
			conversation = [conversation copy];
			conversation.hidden = NO;
			
			// conversation.lastUpdated is updated automatically by YapDatabaseHooks extension when
			// a message is added to the conversation
			
			[transaction setObject:conversation
			                forKey:conversation.uuid
			          inCollection:conversation.userId];
		}
		
		// Create the remote user if needed.
		
		[self findOrCreateUserWithJID:recipientJID transaction:transaction wasCreated:NULL];
		
		// Send the message
		
		messageID = [self sendSiren:siren forConversation:conversation
		                                         withPush:withPush
		                                            badge:withBadge
		                                    createMessage:createMessage
		                                      transaction:transaction];
		
	} completionBlock:^{
		
		for (dispatch_block_t block in transactionCompletionBlocks) {
			block();
		}
		
		if (completionBlock) {
			completionBlock(messageID, conversationID);
		}
	}];
}

/**
 * Use this method when creating a new conversation.
 * That is, when the user chooses to create a new conversation, and chooses multiple recipients.
 * 
 * This method will automatically create the conversation (if needed),
 * and then sends the given siren to the given jids.
 * 
 * @param withPush
 *   The push attribute to specify in the XML for the server.
 *   (whether or not the server should send push notification)
 *
 * @param withBadge
 *   The badge attribute to specify in the XML for the server.
 *   (whether or not the server should include in badge count)
 *
 * @param createMessage
 *   If YES, then a corresponding STMessage is automatically created and added to the conversation.
 *   If NO, then a STMessage will not be created (send siren/xmpp only).
 *
 * @param completionBlock
 *   messageId         - The uuid of the corresponding STMessage that was created
 *   conversationId    - The uuid of the corresponding STConversation (which may have been created)
**/
- (void)sendSiren:(Siren *)siren
         toJidSet:(XMPPJIDSet *)recipients
         withPush:(BOOL)withPush
            badge:(BOOL)withBadge
    createMessage:(BOOL)createMessage
       completion:(void (^)(NSString *messageId, NSString *conversationId))completionBlock
{
	DDLogAutoTrace();
	
	// Sanity checks
	
	if (siren == nil) {
		DDLogWarn(@"%@ - Ignoring: siren == nil", THIS_METHOD);
		return;
	}
	if ([recipients containsJid:localJID options:XMPPJIDCompareBare]) {
		recipients = [recipients setByRemovingJid:localJID options:XMPPJIDCompareBare];
	}
	if (recipients.count == 0) {
		DDLogWarn(@"%@ - Ignoring: recipients.count == 0", THIS_METHOD);
		return;
	}
	
	// Generate a random threadID.
	//
	// And generate the conversationId using a hashing technique.
	// This makes it faster to find conversationIds given an xmpp stanza with just a threadID.
	
	NSString *threadID = [XMPPStream generateUUID];
	NSString *conversationID = [self conversationIDForThreadID:threadID];
	__block NSString *messageID = nil;
	
	NSMutableArray *transactionCompletionBlocks = [[NSMutableArray alloc] init];
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		transaction.completionBlocks = transactionCompletionBlocks;
		
		// Create multicastKey and add to database
		
		STSymmetricKey *multicastKey =
		  [STSymmetricKey keyWithThreadID:threadID
		                          creator:[localJID bare]
		                       expireDate:nil // dont set expire dates for conversation keys
		                       storageKey:self.storageKey];
		
		[transaction setObject:multicastKey
						forKey:multicastKey.uuid
				  inCollection:kSCCollection_STSymmetricKeys];
		
		// Create conversation and add to database
		
		STConversation *conversation =
		  [[STConversation alloc] initWithUUID:conversationID
		                           localUserID:localUserID
		                              localJID:[localJID bareJID]
		                              threadID:threadID];
		
		conversation.multicastJidSet = recipients;
		conversation.keyLocator = multicastKey.uuid;
		
		conversation.sendReceipts = NO;  // never for multicast
		conversation.shouldBurn   = [STPreferences defaultShouldBurn];
		conversation.shredAfter   = [STPreferences defaultBurnTime];
		
		conversation.hidden = NO;
		
		[transaction setObject:conversation
		                forKey:conversation.uuid
		          inCollection:conversation.userId];
		
		// Create the remote user(s) if needed.
		
		for (XMPPJID *recipientJID in recipients)
		{
			[self findOrCreateUserWithJID:recipientJID transaction:transaction wasCreated:NULL];
		}
		
		// Send multicast siren.
		// This siren gets sent to every recipient in conversation.multicastJidSet.
		
		Siren *siren = Siren.new;
		siren.multicastKey = multicastKey.keyJSON;
		
		[self sendPubSiren:siren forConversation:conversation transaction:transaction];
		
		// Send the message
		
		messageID = [self sendSiren:siren forConversation:conversation
		                                         withPush:withPush
		                                            badge:withBadge
		                                    createMessage:createMessage
		                                      transaction:transaction];
		
	} completionBlock:^{
		
		for (dispatch_block_t block in transactionCompletionBlocks) {
			block();
		}
		
		if (completionBlock) {
			completionBlock(messageID, conversationID);
		}
	}];
}

/**
 * Use this method when the conversationID is already known.
 * That is, the STConversation already exists.
 *
 * @param withPush
 *   The push attribute to specify in the XML for the server.
 *   (whether or not the server should send push notification)
 *
 * @param withBadge
 *   The badge attribute to specify in the XML for the server.
 *   (whether or not the server should include in badge count)
 *
 * @param createMessage
 *   If YES, then a corresponding STMessage is automatically created and added to the conversation.
 *   If NO, then a STMessage will not be created (send siren/xmpp only).
 *
 * @param completionBlock
 *   messageId - The uuid of the corresponding STMessage that was created
**/
- (void)sendSiren:(Siren *)siren forConversationID:(NSString *)conversationId
                                          withPush:(BOOL)withPush
                                             badge:(BOOL)withBadge
                                     createMessage:(BOOL)createMessage
                                        completion:(void (^)(NSString *messageId))completionBlock
{
	DDLogAutoTrace();
	
	// Sanity checks
	
	if (siren == nil) {
		DDLogWarn(@"%@ - Bad parameter: siren == nil", THIS_METHOD);
		return;
	}
	if (conversationId == nil) {
		DDLogWarn(@"%@ - Bad parameter: conversationId == nil", THIS_METHOD);
		return;
	}
	
	__block NSString *messageId = nil;
	
	NSMutableArray *transactionCompletionBlocks = [[NSMutableArray alloc] init];
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		transaction.completionBlocks = transactionCompletionBlocks;
		
		STConversation *conversation = [transaction objectForKey:conversationId inCollection:localUserID];
		if (conversation == nil)
		{
			DDLogWarn(@"%@ - Unable to sendSiren: conversation == nil", THIS_METHOD);
			return_from_block;
		}
		
		// conversation.lastUpdated is updated automatically by YapDatabaseHooks extension when
		// a message is added to the conversation
		
		messageId = [self sendSiren:siren forConversation:conversation
		                                         withPush:withPush
		                                            badge:withBadge
		                                    createMessage:createMessage
		                                      transaction:transaction];
		
	} completionBlock:^{
		
		for (dispatch_block_t block in transactionCompletionBlocks) {
			block();
		}
		
		if (completionBlock) {
			completionBlock(messageId);
		}
	}];
}

/**
 * Internal method that handles all the details of sending a siren.
 * 
 * Note: This method does NOT touch the conversation.
 * The caller is responsible for doing so (if needed).
 * 
 * @returns
 *   If createMessage is YES, then the messageId of the created STMessage.
 *   If createMessage is NO, then nil.
**/
- (NSString *)sendSiren:(Siren *)siren
        forConversation:(STConversation *)conversation
               withPush:(BOOL)withPush
                  badge:(BOOL)withBadge
          createMessage:(BOOL)createMessage
            transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	if (siren == nil) {
		DDLogWarn(@"%@ - Unable to sendSiren: siren == nil", THIS_METHOD);
		return nil;
	}
	
	if (conversation == nil) {
		DDLogWarn(@"%@ - Unable to sendSiren: conversation == nil", THIS_METHOD);
		return nil;
	}
	
	STUser *localUser = [transaction objectForKey:localUserID inCollection:kSCCollection_STUsers];
	if (localUser == nil)
	{
		DDLogWarn(@"Unable to sendSiren: user == nil");
		return nil;
	}
	
	NSString *messageID = [XMPPStream generateUUID];
	
	if (createMessage)
	{
		BOOL ignoreAttributes = NO;
		
		if (conversation.isMulticast)
		{
			if (siren.threadName || 0 /* add other mc changes here */ )
				ignoreAttributes = YES;
		}
		else
		{
			siren.requestReceipt = YES; // always ask for receipts
		}
		
		if (!ignoreAttributes)
		{
			if (conversation.tracking || siren.requiresLocation || siren.isMapCoordinate)
			{
				CLLocation *location = [[GeoTracking sharedInstance] currentLocation];
				if (location)
				{
					siren.location = [location JSONString];
					if (siren.isMapCoordinate)
					{
						NSString *coordString =
						  [NSString stringWithFormat:@"%@: %f\r%@: %f\r%@: %@",
						      NSLocalizedString(@"Latitude",  @"Latitude"),  location.coordinate.latitude,
						      NSLocalizedString(@"Longitude", @"Longitude"), location.coordinate.longitude,
						      NSLocalizedString(@"Altitude",  @"Altitude"),  location.altitudeString];
						
						siren.message = coordString;
					}
				}
			}
			
			if (conversation.fyeo)
				siren.fyeo = YES;
			
			if (conversation.shouldBurn && conversation.shredAfter > 0)
				siren.shredAfter = conversation.shredAfter;
		}
	}
 	
	if (!siren.signature)
	{
		STPublicKey *publicKey = [transaction objectForKey:localUser.currentKeyID
											  inCollection:kSCCollection_STPublicKeys];
		if (publicKey)
		{
			siren.signature = [self signSiren:siren withPublicKey:publicKey];
		}
	}
	
	XMPPMessage *xmppMessage = nil;
	if (conversation.isMulticast)
	{
		XMPPJIDSet *mcJids = conversation.multicastJidSet;
		mcJids = [mcJids setByRemovingJid:localJID options:XMPPJIDCompareBare];
		
		xmppMessage = [XMPPMessage multicastChatMessageWithSiren:siren
		                                                      to:[mcJids allJids]
		                                                threadID:conversation.threadID
		                                                  domain:localJID.domain
		                                               elementID:messageID];
	}
	else
	{
		xmppMessage = [XMPPMessage chatMessageWithSiren:siren
		                                             to:[conversation.remoteJid bareJID]
		                                      elementID:messageID
		                                           push:withPush
		                                          badge:withBadge];
	}
	
	if (createMessage)
	{
		STMessage *message = [[STMessage alloc] initWithUUID:messageID
		                                      conversationId:conversation.uuid
		                                              userId:localUserID
		                                                from:[localJID bareJID]
		                                                  to:[conversation.remoteJid bareJID]
		                                           withSiren:siren
		                                           timestamp:[NSDate date]
		                                          isOutgoing:YES];
		
		if (!conversation.isFakeStream)
		{
			BOOL sent = [self trySendXmppStanza:xmppMessage withTransaction:transaction];
			if (sent) {
				message.sendDate = message.timestamp;
			}
		}
		
		[transaction setObject:message
		                forKey:message.uuid
		          inCollection:message.conversationId];
		
		if (siren.thumbnail)
		{
			OSImage *image = [OSImage imageWithData:siren.thumbnail];
			STImage *thumbnail = [[STImage alloc] initWithImage:image
			                                          parentKey:messageID
			                                         collection:conversation.uuid];
			
			// Note: The STImage, when added to the database, will create a graph edge pointing to the STMessage
			// with a nodeDeleteRule such that the STImage will be automatically deleted when the STMessage is deleted.
			
			[transaction setObject:thumbnail
			                forKey:thumbnail.parentKey
			          inCollection:kSCCollection_STImage_Message];
		}
	}
	else if (!conversation.isFakeStream)
	{
		STXMPPElement *element = [[STXMPPElement alloc] initWithElement:xmppMessage
		                                                    localUserID:localUserID
		                                                 conversationID:conversation.uuid];
		
		[transaction setObject:element
		                forKey:element.uuid
		          inCollection:element.conversationID];
		
		[self trySendXmppStanza:xmppMessage withTransaction:transaction];
	}
	
	return createMessage ? messageID : nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Send Pub Siren
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Public Method.
 * 
 * Currently in "beta" status.
**/
- (void)sendPubSiren:(Siren *)siren forConversationID:(NSString *)conversationId
                                             withPush:(BOOL)withPush
                                                badge:(BOOL)withBadge
                                        createMessage:(BOOL)createMessage
                                           completion:(void (^)(NSString *messageId))completionBlock
{
	DDLogAutoTrace();
	
	// Sanity checks
	
	if (siren == nil) {
		DDLogWarn(@"%@ - Bad parameter: siren == nil", THIS_METHOD);
		return;
	}
	if (conversationId == nil) {
		DDLogWarn(@"%@ - Bad parameter: conversationId == nil", THIS_METHOD);
		return;
	}
	
	__block NSString *messageId = nil;
	
	NSMutableArray *transactionCompletionBlocks = [[NSMutableArray alloc] init];
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		transaction.completionBlocks = transactionCompletionBlocks;
		
		STConversation *conversation = [transaction objectForKey:conversationId inCollection:localUserID];
		if (conversation == nil)
		{
			DDLogWarn(@"%@ - Bad parameter: conversation == nil", THIS_METHOD);
			return_from_block;
		}
		
		if (conversation.isMulticast)
		{
			// This method does NOT support multicast conversations.
			
			DDLogWarn(@"%@ - Bad parameter: conversation.isMulticast == YES", THIS_METHOD);
			return_from_block;
		}
		
		// conversation.lastUpdated is updated automatically by YapDatabaseHooks extension when
		// a message is added to the conversation
		
		messageId = [XMPPStream generateUUID];
		
		// Create the xmpp stanza:
		//
		// <message type='chat' to='jid' id='uuid'>
		//   <pubSiren xmlns='http://silentcircle.com'>siren_as_json</pubSiren>
		// </message>
			
		NSXMLElement *pubSirenElement = [NSXMLElement elementWithName:kSCPPPubSiren xmlns:kSCNameSpace];
		pubSirenElement.stringValue = siren.json;
		
		XMPPMessage *xmppMessage = [XMPPMessage messageWithType:kXMPPChat to:[conversation.remoteJid bareJID]];
		[xmppMessage addAttributeWithName:kXMPPID stringValue:messageId];
		[xmppMessage addChild:pubSirenElement];
			
		if (createMessage)
		{
			STMessage *message = [[STMessage alloc] initWithUUID:messageId
			                                      conversationId:conversation.uuid
			                                              userId:localUserID
			                                                from:[localJID bareJID]
			                                                  to:[conversation.remoteJid bareJID]
			                                           withSiren:siren
			                                           timestamp:[NSDate date]
			                                          isOutgoing:YES];
			
			if (!conversation.isFakeStream)
			{
				BOOL sent = [self trySendXmppStanza:xmppMessage withTransaction:transaction];
				if (sent) {
					message.sendDate = message.timestamp;
				}
			}
			
			[transaction setObject:message
			                forKey:message.uuid
			          inCollection:message.conversationId];
			
			if (siren.thumbnail)
			{
				OSImage *image = [OSImage imageWithData:siren.thumbnail];
				STImage *thumbnail = [[STImage alloc] initWithImage:image
				                                          parentKey:messageId
				                                         collection:conversation.uuid];
				
				// Note: The STImage, when added to the database, will create a graph edge pointing to the STMessage
				// with a nodeDeleteRule such that the STImage will be automatically deleted when the STMessage is deleted.
				
				[transaction setObject:thumbnail
				                forKey:thumbnail.parentKey
				          inCollection:kSCCollection_STImage_Message];
			}
		}
		else if (!conversation.isFakeStream)
		{
			STXMPPElement *element = [[STXMPPElement alloc] initWithElement:xmppMessage
			                                                    localUserID:localUserID
			                                                 conversationID:conversation.uuid];
			
			[transaction setObject:element
			                forKey:element.uuid
			          inCollection:element.conversationID];
			
			[self trySendXmppStanza:xmppMessage withTransaction:transaction];
		}
		
	} completionBlock:^{
		
		for (dispatch_block_t block in transactionCompletionBlocks) {
			block();
		}
		
		if (completionBlock) {
			completionBlock(messageId);
		}
	}];
}

/**
 * Private method.
 *
 * This method is used to broadcast a siren to all participants in a group conversation.
 * It is used for:
 * - creation of the group conversation (sending "invite")
 * - rekeying a group conversation
**/
- (void)sendPubSiren:(Siren *)siren
     forConversation:(STConversation *)conversation
         transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	if (siren == nil) {
		DDLogWarn(@"%@ - Bad parameter: siren == nil", THIS_METHOD);
		return;
	}
	
	if (conversation == nil) {
		DDLogWarn(@"%@ - Bad parameter: conversation == nil", THIS_METHOD);
		return;
	}
	
	XMPPJIDSet *multicastJidSet = conversation.multicastJidSet;
	if ([multicastJidSet count] == 0)
	{
		DDLogWarn(@"%@ - Bad parameter: conversation isn't multicast", THIS_METHOD);
		return;
	}
	
	for (XMPPJID *jid in multicastJidSet)
	{
		NSString *uuid = [XMPPStream generateUUID];
		
		// Create the xmpp stanza:
		//
		// <message type='chat' to='jid' id='uuid'>
		//   <pubSiren xmlns='http://silentcircle.com'>siren_as_json</pubSiren>
		// </message>
		
		NSXMLElement *pubSirenElement = [NSXMLElement elementWithName:kSCPPPubSiren xmlns:kSCNameSpace];
		pubSirenElement.stringValue = siren.json;
		
		XMPPMessage *message = [XMPPMessage messageWithType:kXMPPChat to:jid];
		[message addAttributeWithName:kXMPPID stringValue:uuid];
		[message addChild:pubSirenElement];
		
		// Store stanza to the database (outgoing queue)
		
		STXMPPElement *element = [[STXMPPElement alloc] initWithElement:message
		                                                    localUserID:localUserID
		                                                 conversationID:conversation.uuid];
		
		[transaction setObject:element
		                forKey:element.uuid
		          inCollection:element.conversationID];
		
		// Send the stanza over xmppStream (if possible)
		
		[self trySendXmppStanza:message withTransaction:transaction];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Send Other
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Burns the given message by deleting it from the local device (first),
 * and then sending the proper IQ (if needed) to delete it from the remote device or server.
**/
- (void)burnMessage:(NSString *)messageId inConversation:(NSString *)conversationId
{
	DDLogAutoTrace();
	
	NSMutableArray *transactionCompletionBlocks = [[NSMutableArray alloc] init];
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
		
		transaction.completionBlocks = transactionCompletionBlocks;
		
		id obj = [transaction objectForKey:messageId inCollection:conversationId];
		if (obj == nil)
		{
			DDLogWarn(@"Unable to burn message: Not found in database");
			return_from_block;
		}
		if (![obj isKindOfClass:[STMessage class]])
		{
			DDLogWarn(@"Unable to burn message: Non-STMessage found in database");
			return_from_block;
		}
		
		STMessage *message = (STMessage *)obj;
		
		// Fetch the scloud item (if it exists) and delete the corresponding files from disk
		NSString *scloudId = message.siren.cloudLocator;
		if (scloudId)
		{
			STSCloud *scl = [transaction objectForKey:scloudId inCollection:kSCCollection_STSCloud];
			
			[scl removeFromCache];
		}
		
		// Remove the message
		[transaction removeObjectForKey:message.uuid
		                   inCollection:message.conversationId];
		
		// Notes:
		//
		// - The relationship extension will automatically remove the thumbnail (if needed)
		// - The relationship extension will automatically remove the scloud item (if needed)
		// - The hooks extension will automatically update the conversation item (if needed)
		
		BOOL isOutgoingMessage = message.isOutgoing;
		BOOL hasMessageLeftOurPhone = message.sendDate != nil;
		
		STConversation *conversation = [transaction objectForKey:message.conversationId inCollection:message.userId];
		
		if (isOutgoingMessage && hasMessageLeftOurPhone && !conversation.isFakeStream)
		{
			// Step 1 of 2:
			//
			// Send IQ to remove the item from the xmpp server (if sitting in offline storage)
			//
			// <iq to='silentcircle.com' type='set' id='uuid'>
			//   <offline xmlns='http://silentcircle.com/protocol/offline'>
			//     <item action='remove'
			//               to='bob@silentcircle.com'
			//               id='BBCA5B2C-9ECC-4278-88BF-F1D26F8792F7' />
			//
			//     <!- more items if needed... ->
			//   </offline>
			// </iq>
			
			NSString *iqID = [XMPPStream generateUUID];
			
			NSXMLElement *item = [NSXMLElement elementWithName:@"item" ];
			[item addAttributeWithName:@"action" stringValue:@"remove"];
			[item addAttributeWithName:@"to" stringValue:[conversation.remoteJid bare]];
			[item addAttributeWithName:@"id" stringValue:messageId];
			
			NSXMLElement *offline = [NSXMLElement elementWithName:@"offline"
			                                                xmlns:@"http://silentcircle.com/protocol/offline"];
			[offline addChild:item];
			
			XMPPJID *serverJID = [localJID domainJID];
			XMPPIQ *iq = [XMPPIQ iqWithType:@"set" to:serverJID elementID:iqID child:offline];
			
			STXMPPElement *element = [[STXMPPElement alloc] initWithElement:iq
			                                                    localUserID:localUserID
			                                                 conversationID:conversation.uuid];
			
			[transaction setObject:element
			                forKey:element.uuid
			          inCollection:element.conversationID];
			
			[self trySendXmppStanza:iq withTransaction:transaction];
			
			// Step 2 of 2:
			//
			// Send siren to burn the message from the users' device.
			
			Siren *siren = [Siren new];
			siren.requestBurn = messageId;
			
			[self sendSiren:siren forConversation:conversation
			                             withPush:NO
			                                badge:NO
			                        createMessage:NO
			                          transaction:transaction];
		}
		
	} completionBlock:^{
	
		for (dispatch_block_t block in transactionCompletionBlocks) {
			block();
		}
	}];
}



// send an info message from the silent text system to the specifid user.
// we use this for logging user reabable  events to the user
// this is not a real conversation, and the remote user can not be replied to.

+ (void)sendInfoMessage:(NSString *)messageText toUser:(NSString *)localUserID
{
	DDLogAutoTrace();
    
	Siren *siren = [Siren new];
	siren.message = messageText;

	NSDate *now = [NSDate date];
	XMPPJID *remoteJID = [AppConstants stInfoJID];
    
 	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STUser *localUser = [transaction objectForKey:localUserID inCollection:kSCCollection_STUsers];
		if (localUser == nil)
		{
			DDLogWarn(@"Unable to send welcome message to non-existent user");
			return_from_block;
		}
		
		NSString *conversationID = [self conversationIDForLocalJid:localUser.jid remoteJid:remoteJID];
		
		STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
		if (conversation == nil)
		{
			conversation = [[STConversation alloc] initWithUUID:conversationID
			                                        localUserID:localUserID
			                                           localJID:[localUser.jid bareJID]
			                                          remoteJID:remoteJID];
			
			conversation.isFakeStream  = YES;
			conversation.sendReceipts  = NO;
			conversation.shouldBurn    = NO;
			conversation.shredAfter    = kShredAfterNever;
			
			[transaction setObject:conversation
							forKey:conversation.uuid
					  inCollection:conversation.userId];
		}
		else if (conversation.hidden)
		{
			conversation = [conversation copy];
			conversation.hidden = NO;
			
			// conversation.lastUpdated is updated automatically by YapDatabaseHooks extension when
			// a message is added to the conversation
			
			[transaction setObject:conversation
			                forKey:conversation.uuid
			           inCollection:conversation.userId];
		}
		
  		STMessage *message = [[STMessage alloc] initWithUUID:[XMPPStream generateUUID]
		                                      conversationId:conversation.uuid
		                                              userId:localUserID
		                                                from:conversation.remoteJid
		                                                  to:conversation.localJid
		                                           withSiren:siren
		                                           timestamp:now
		                                          isOutgoing:NO];
		
		// These are injected messages,
		// so we can fake the verification & timestamps.
		message.isVerified = YES;
		message.sendDate = now;
		message.serverAckDate = now;
		
		[transaction setObject:message
		                forKey:message.uuid
		          inCollection:message.conversationId];
	}];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark SCloud
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Use this method when creating a new conversation.
 * That is, when the user chooses to create a new conversation, and chooses a single recipient.
 *
 * This method will automatically create the conversation (if needed),
 * and then queues the given siren to be sent automatically after the SCloud upload completes.
 *
 * @param completionBlock
 *   messageId         - The uuid of the corresponding STMessage that was created
 *   conversationId    - The uuid of the corresponding STConversation (which may have been created)
**/
- (void)sendScloudWithSiren:(Siren *)siren
                      toJID:(XMPPJID *)recipientJID
                 completion:(void (^)(NSString *messageId, NSString *conversationId))completionBlock
{
	DDLogAutoTrace();
	
	// Sanity checks
	
	if (siren == nil) {
		DDLogWarn(@"%@ - Ignoring: siren == nil", THIS_METHOD);
		return;
	}
	if (recipientJID == nil) {
		DDLogWarn(@"%@ - Ignoring: recipient == nil", THIS_METHOD);
		return;
	}
	
	NSAssert([recipientJID isKindOfClass:[XMPPJID class]], @"Invalid parameter type: 'recipient' not a jid");
	
	// Generate conversationId from JIDs using a hashing technique.
	// This makes it faster to find conversationIds given an xmpp stanza with just a remoteJID.
	
	NSString *conversationID = [self conversationIDForRemoteJid:recipientJID];
	__block NSString *messageID = nil;
	
	NSMutableArray *transactionCompletionBlocks = [[NSMutableArray alloc] init];
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		transaction.completionBlocks = transactionCompletionBlocks;
		
		// Create conversation if needed,
		// or touch the conversation lastUpdated timestamp.
		
		STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
		if (conversation == nil)
		{
			conversation = [[STConversation alloc] initWithUUID:conversationID
			                                        localUserID:localUserID
			                                           localJID:[localJID bareJID]
			                                          remoteJID:recipientJID];
			
			conversation.sendReceipts = [STPreferences defaultSendReceipts];
			conversation.shouldBurn   = [STPreferences defaultShouldBurn];
			conversation.shredAfter   = [STPreferences defaultBurnTime];
			
			conversation.hidden = NO;
			
			[transaction setObject:conversation
			                forKey:conversation.uuid
			          inCollection:conversation.userId];
			
		}
		else if (conversation.hidden)
		{
			conversation = [conversation copy];
			conversation.hidden = NO;
			
			// conversation.lastUpdated is updated automatically by YapDatabaseHooks extension when
			// a message is added to the conversation
			
			[transaction setObject:conversation
			                forKey:conversation.uuid
			          inCollection:conversation.userId];
		}
		
		// Create the remote user if needed.
		
		[self findOrCreateUserWithJID:recipientJID transaction:transaction wasCreated:NULL];
		
		// Send the message
		
		messageID = [self sendScloudWithSiren:siren forConversation:conversation transaction:transaction];
		
	} completionBlock:^{
		
		for (dispatch_block_t block in transactionCompletionBlocks) {
			block();
		}
		
		if (completionBlock) {
			completionBlock(messageID, conversationID);
		}
	}];
}

/**
 * Use this method when creating a new conversation.
 * That is, when the user chooses to create a new conversation, and chooses multiple recipients.
 *
 * This method will automatically create the conversation (if needed),
 * and then queue the given siren to be sent automatically after the SCloud upload completes.
 *
 * @param completionBlock
 *   messageId         - The uuid of the corresponding STMessage that was created
 *   conversationId    - The uuid of the corresponding STConversation (which may have been created)
**/
- (void)sendScloudWithSiren:(Siren *)siren
                   toJidSet:(XMPPJIDSet *)recipients
                 completion:(void (^)(NSString *messageId, NSString *conversationId))completionBlock
{
	DDLogAutoTrace();
	
	// Sanity checks
	
	if (siren == nil) {
		DDLogWarn(@"%@ - Ignoring: siren == nil", THIS_METHOD);
		return;
	}
	if ([recipients containsJid:localJID options:XMPPJIDCompareBare]) {
		recipients = [recipients setByRemovingJid:localJID options:XMPPJIDCompareBare];
	}
	if (recipients.count == 0) {
		DDLogWarn(@"%@ - Ignoring: recipients.count == 0", THIS_METHOD);
		return;
	}
	
	// Generate a random threadID.
	//
	// And generate the conversationId using a hashing technique.
	// This makes it faster to find conversationIds given an xmpp stanza with just a threadID.
	
	NSString *threadID = [XMPPStream generateUUID];
	NSString *conversationID = [self conversationIDForThreadID:threadID];
	
	__block NSString *messageID = nil;
	
	NSMutableArray *transactionCompletionBlocks = [[NSMutableArray alloc] init];
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		transaction.completionBlocks = transactionCompletionBlocks;
		
		// Create multicastKey and add to database
		
		STSymmetricKey *multicastKey =
		  [STSymmetricKey keyWithThreadID:threadID
		                          creator:[localJID bare]
		                       expireDate:nil // dont set expire dates for conversation keys
		                       storageKey:self.storageKey];
		
		[transaction setObject:multicastKey
						forKey:multicastKey.uuid
				  inCollection:kSCCollection_STSymmetricKeys];
		
		// Create conversation and add to database
		
		STConversation *conversation =
		  [[STConversation alloc] initWithUUID:conversationID
		                           localUserID:localUserID
		                              localJID:[localJID bareJID]
		                              threadID:threadID];
		
		conversation.multicastJidSet = recipients;
		conversation.keyLocator = multicastKey.uuid;
		
		conversation.sendReceipts = NO;  // never for multicast
		conversation.shouldBurn   = [STPreferences defaultShouldBurn];
		conversation.shredAfter   = [STPreferences defaultBurnTime];
		
		conversation.hidden = NO;
		
		[transaction setObject:conversation
		                forKey:conversation.uuid
		          inCollection:conversation.userId];
		
		// Create the remote user(s) if needed.
		
		for (XMPPJID *recipientJID in recipients)
		{
			[self findOrCreateUserWithJID:recipientJID transaction:transaction wasCreated:NULL];
		}
		
		// Send multicast siren.
		// This siren gets sent to every recipient in conversation.multicastJidSet.
		
		Siren *siren = Siren.new;
		siren.multicastKey = multicastKey.keyJSON;
		
		[self sendPubSiren:siren forConversation:conversation transaction:transaction];
		
		// Send the message
		
		messageID = [self sendScloudWithSiren:siren forConversation:conversation transaction:transaction];
		
	} completionBlock:^{
		
		for (dispatch_block_t block in transactionCompletionBlocks) {
			block();
		}
		
		if (completionBlock) {
			completionBlock(messageID, conversationID);
		}
	}];
}

/**
 * Use this method when the conversationID is already known.
 * That is, the STConversation already exists.
 *
 * @param completionBlock
 *   messageId - The uuid of the corresponding STMessage that was created
**/
- (void)sendScloudWithSiren:(Siren *)siren
          forConversationID:(NSString *)conversationId
                 completion:(void (^)(NSString *messageId))completionBlock
{
	DDLogAutoTrace();
	
	// Sanity checks
	
	if (siren == nil) {
		DDLogWarn(@"%@ - Ignoring: siren == nil", THIS_METHOD);
		return;
	}
	if (conversationId == nil) {
		DDLogWarn(@"%@ - Ignoring: conversationId == nil", THIS_METHOD);
		return;
	}
	
	__block NSString *messageId = nil;
	
	NSMutableArray *transactionCompletionBlocks = [[NSMutableArray alloc] init];
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		transaction.completionBlocks = transactionCompletionBlocks;
		
		STConversation *conversation = [transaction objectForKey:conversationId inCollection:localUserID];
		if (conversation == nil)
		{
			DDLogWarn(@"%@ - Unable to sendSiren: conversation == nil", THIS_METHOD);
			return_from_block;
		}
		
		// conversation.lastUpdated is updated automatically by YapDatabaseHooks extension when
		// a message is added to the conversation
		
		messageId = [self sendScloudWithSiren:siren forConversation:conversation transaction:transaction];
		
	} completionBlock:^{
		
		for (dispatch_block_t block in transactionCompletionBlocks) {
			block();
		}
		
		if (completionBlock) {
			completionBlock(messageId);
		}
	}];
}

/**
 * Internal method that handles all the details of sending a siren.
 * 
 * Note: This method does NOT touch the conversation.
 * The caller is responsible for doing so (if needed).
 * 
 * @returns
 *   The messageId of the created STMessage.
**/
- (NSString *)sendScloudWithSiren:(Siren *)siren
                  forConversation:(STConversation *)conversation
                      transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	NSString *messageId = [XMPPStream generateUUID];
	
	// Configure the siren for the conversation
		
	if (!conversation.isMulticast) {
		siren.requestReceipt = YES; // always ask for receipts
	}
	
	if (conversation.tracking)
	{
		// insert tracking info
		CLLocation *location = [[GeoTracking sharedInstance] currentLocation];
		if (location)
		{
			siren.location = [location JSONString];
		}
	}
    	
	if (conversation.fyeo) {
		siren.fyeo = YES;
	}
	
	if (conversation.shouldBurn && conversation.shredAfter > 0) {
		siren.shredAfter = conversation.shredAfter;
	}
	
	// Sign the siren
	// Remember: Don't change the siren after you sign it
	
	STUser *localUser = [transaction objectForKey:localUserID inCollection:kSCCollection_STUsers];
	STPublicKey *publicKey = [transaction objectForKey:localUser.currentKeyID inCollection:kSCCollection_STPublicKeys];
	
	if (publicKey)
	{
		siren.signature = [self signSiren:siren withPublicKey:publicKey];
	}
	
	// Create message & thumbnail objects
	
	STMessage *message = [[STMessage alloc] initWithUUID:messageId
	                                      conversationId:conversation.uuid
	                                              userId:localUserID
	                                                from:[localJID bareJID]
	                                                  to:[conversation.remoteJid bareJID]
	                                           withSiren:siren
	                                           timestamp:[NSDate date]
	                                          isOutgoing:YES];
	
	// We're storing the message to the database now,
	// but we can't send it until after the scloud components have been uploaded.
	// So we use the needsUpload flag to represent this.
	message.needsUpload = YES;
	
	[transaction setObject:message
	                forKey:message.uuid
	          inCollection:message.conversationId];
	
	if (siren.thumbnail)
	{
		OSImage *image = [OSImage imageWithData:siren.thumbnail];
		STImage *thumbnail = [[STImage alloc] initWithImage:image
		                                          parentKey:messageId
		                                         collection:conversation.uuid];
			
		// Note: The thumbnail, when added to the database, will create a graph edge pointing to the message
		// with a nodeDeleteRule so that the thumbnail is automatically deleted when the message is deleted.
		
		[transaction setObject:thumbnail
		                forKey:thumbnail.parentKey
		          inCollection:kSCCollection_STImage_Message];
	}
	
	NSString *conversationId = conversation.uuid;
	
	dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(backgroundQueue, ^{ @autoreleasepool{
		
		// Perform the decryption / disk IO on a background thread
		
		[self continueSendScloudWithSiren:siren messageID:messageId conversationID:conversationId];
	}});
	
	return messageId;
}

/**
 * This method is invoked on a background thread / queue.
**/
- (void)continueSendScloudWithSiren:(Siren *)siren
                          messageID:(NSString *)messageID
                     conversationID:(NSString *)conversationID
{
	SCloudObject *scloud = [[SCloudObject alloc] initWithLocatorString:siren.cloudLocator
	                                                         keyString:siren.cloudKey
                                                                  fyeo:siren.fyeo];
	
	NSError *decryptError = nil;
	if (![scloud decryptMetaDataUsingKeyString:siren.cloudKey withError:&decryptError])
	{
		DDLogWarn(@"decryptMetaDataUsingKeyString:withError: %@", decryptError);
		
 		return;
	}
	
	__block STLocalUser *localUser = nil;
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
		
		localUser = [transaction objectForKey:localUserID inCollection:kSCCollection_STUsers];
		
		STSCloud *scl = [transaction objectForKey:siren.cloudLocator inCollection:kSCCollection_STSCloud];
		if (!scl)
		{
			OSImage *lowRezThm = siren && siren.thumbnail ? [OSImage imageWithData:siren.thumbnail] : nil;
			
			scl = [[STSCloud alloc] initWithUUID:siren.cloudLocator
			                           keyString:siren.cloudKey
			                              userId:localUserID
			                           mediaType:scloud.mediaType
			                            metaData:scloud.metaData
			                            segments:scloud.segmentList
			                           timestamp:[NSDate date]
			                     lowRezThumbnail:lowRezThm
			                         isOwnedbyMe:NO
			                          dontExpire:NO
                                            fyeo:siren.fyeo];
        }
        else
        {
            scl = [scl copy];
        }
        
        scl.unCacheDate = [[NSDate date] dateByAddingTimeInterval:[STPreferences scloudCacheLifespan]];
        
        if (siren.preview) {
            scl.preview = [OSImage imageWithData:siren.preview];
        }
        
        [transaction setObject:scl
                        forKey:scl.uuid
                  inCollection:kSCCollection_STSCloud];
		
		// Create a relationship between the STMessage and STSCloud object.
		//
		// YDB_DeleteDestinationIfAllSourcesDeleted:
		//   When the every last message that points to this particular STSCloud has been deleted,
		//   then the database will automatically delete this STSCloud object.
		//
		// Further, the STSCloud object uses the YapDatabaseRelationshipNode protocol so that
		// when the STSCloud object is deleted, the database automatically deletes the folder
		// where it stores all its segments.
		
		YapDatabaseRelationshipEdge *edge =
		[YapDatabaseRelationshipEdge edgeWithName:@"scloud"
										sourceKey:messageID
									   collection:conversationID
								   destinationKey:scl.uuid
									   collection:kSCCollection_STSCloud
								  nodeDeleteRules:YDB_DeleteDestinationIfAllSourcesDeleted];
		
		[[transaction ext:Ext_Relationship] addEdge:edge];
        
        
	} completionBlock:^{
		
		[self uploadScloud:scloud
		     withBurnDelay:siren.shredAfter
		         localUser:localUser
		         messageID:messageID
		    conversationID:conversationID];
		
	}]; // end asyncReadWriteWithBlock:completionBlock:
}

/**
 * Internal method that handles the last part of the SCloud upload process:
 * - passing the prepared SCloud object to the SCloudManager
 * - setting up the completion block to properly update the message & conversation
**/
- (void)uploadScloud:(SCloudObject *)scloud
       withBurnDelay:(NSUInteger)shredAfter
           localUser:(STLocalUser *)localUser
           messageID:(NSString *)messageId
      conversationID:(NSString *)conversationId
{
	DDLogAutoTrace();
	
	YapCollectionKey *identifier = YapCollectionKeyCreate(conversationId, messageId);
	[[SCloudManager sharedInstance] startUploadForLocalUser:localUser
	                                                 scloud:scloud
	                                              burnDelay:shredAfter
	                                             identifier:identifier
	                                        completionBlock:^(NSError *error, NSDictionary *infoDict)
	{
		NSMutableArray *transactionCompletionBlocks = [[NSMutableArray alloc] init];
		
		[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
			
			transaction.completionBlocks = transactionCompletionBlocks;
			
			STMessage *message = [transaction objectForKey:messageId inCollection:conversationId];
			STConversation *conversation = [transaction objectForKey:conversationId inCollection:localUserID];
			
			message = [message copy];
			if (error)
				message.needsReSend = YES;
			else
				message.needsUpload = NO;
			
			if (!error && !conversation.isFakeStream)
			{
				XMPPMessage *xmppMessage = [self xmppMessageForMessage:message withConversation:conversation];
				
				BOOL sent = [self trySendXmppStanza:xmppMessage withTransaction:transaction];
				if (sent) {
					message.sendDate = [NSDate date];
				}
			}
			
			[transaction setObject:message
			                forKey:message.uuid
			          inCollection:message.conversationId];
			
		} completionBlock:^{
		
			for (dispatch_block_t block in transactionCompletionBlocks) {
				block();
			}
		}];
	
	}]; // end startUploadForUser::::completionBlock:
}

/**
 * The first time this method is invoked (internally, when a message with scloud is received),
 * this method downloads the first few segments.
 * 
 * Upon later invocations, all the rest of the segments are downloaded.
**/
- (void)downloadSCloudForMessage:(STMessage *)message
                   withThumbnail:(OSImage *)thumbnail
                 completionBlock:(void (^)(STMessage *message, NSError *error))completionBlock
{
	DDLogAutoTrace();
	
    NSUInteger downloadSegmentCount = [STPreferences initialScloudSegmentsToDownload];
    
	Siren *siren = message.siren;
	SCloudObject *scloud = [[SCloudObject alloc] initWithLocatorString:siren.cloudLocator
	                                                         keyString:siren.cloudKey
	                                                              fyeo:siren.fyeo];
    
	if (scloud.isCached)
	{
		// Remember:
		// - completion blocks should always be asynchronous
		// - completion blocks should always be invoked on the main thread (unless otherwise specified)
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (completionBlock) {
				completionBlock(message, NULL);
			}
		});
		
		return;
	}
    
	__block BOOL downloadRemaining = NO;
    
	YapCollectionKey *identifier = YapCollectionKeyCreate(message.conversationId, message.uuid);
	
	[[SCloudManager sharedInstance] startDownloadWithScloud:scloud
	                                           fullDownload:NO
	                                             identifier:identifier
	                                        completionBlock:^(NSError *error, NSDictionary *infoDict)
	{
		if (error)
		{
			if (completionBlock) {
				completionBlock(message, error);
			}
			return;
		}
		
		DDLogMagenta(@"downloaded  %@  ", siren.cloudLocator);
		
		NSError *decryptError = nil;
		BOOL decryptResult = [scloud decryptMetaDataUsingKeyString:siren.cloudKey withError:&decryptError];
		
		if (!decryptResult || decryptError)
		{
			DDLogWarn(@"Error decrypting scloud metadata: %@", decryptError);
			return;
		}
		
		[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
		
			STSCloud *scl = [transaction objectForKey:siren.cloudLocator inCollection:kSCCollection_STSCloud];
			if (scl)
			{
				downloadRemaining = NO;
			}
			else // if (scl == nil)
			{
				scl = [[STSCloud alloc] initWithUUID:siren.cloudLocator
				                           keyString:siren.cloudKey
				                              userId:message.userId
				                           mediaType:scloud.mediaType
				                            metaData:scloud.metaData
				                            segments:scloud.segmentList
				                           timestamp:[NSDate date]
				                     lowRezThumbnail:thumbnail
				                         isOwnedbyMe:NO
				                          dontExpire:NO
                                                fyeo:siren.fyeo];
				
				scl.unCacheDate = [[NSDate date] dateByAddingTimeInterval:[STPreferences scloudCacheLifespan]];
				
				if (siren.preview) {
					scl.preview = [OSImage imageWithData:siren.preview];
				}
				
				[transaction setObject:scl
				                forKey:scl.uuid
				          inCollection:kSCCollection_STSCloud];
				
				// Update the message.
				// We need to unset the needsDownload flag
				//
				// Important:
				// The message object may have been updated in the database since it was handed to us.
				// So it's critical that we fetch the latest version from the database, and update that version.
				
				STMessage *mostRecentVersionOfMessage =
				  [transaction objectForKey:message.uuid inCollection:message.conversationId];
				
				STMessage *msg = [mostRecentVersionOfMessage copy];
				msg.needsDownload = NO;
				
				[transaction setObject:msg
				                forKey:msg.uuid
				          inCollection:msg.conversationId];
				
				// Create a relationship between the STMessage and STSCloud object.
				//
				// YDB_DeleteDestinationIfAllSourcesDeleted:
				//   When the every last message that points to this particular STSCloud has been deleted,
				//   then the database will automatically delete this STSCloud object.
				//
				// Further, the STSCloud object uses the YapDatabaseRelationshipNode protocol so that
				// when the STSCloud object is deleted, the database automatically deletes the folder
				// where it stores all its segments.
				
				YapDatabaseRelationshipEdge *edge =
				  [YapDatabaseRelationshipEdge edgeWithName:@"scloud"
				                                  sourceKey:message.uuid
				                                 collection:message.conversationId
				                             destinationKey:scl.uuid
				                                 collection:kSCCollection_STSCloud
				                            nodeDeleteRules:YDB_DeleteDestinationIfAllSourcesDeleted];
				
				[[transaction ext:Ext_Relationship] addEdge:edge];
				
				// Check to see if there are more segments we need to download
				
				if (scl.segments.count < downloadSegmentCount) {
					downloadRemaining = YES;
				}
			}
		
		} completionBlock:^{ // [databaseConnection asyncReadWrite...
			
			if (downloadRemaining)
			{
				[[SCloudManager sharedInstance] startDownloadWithScloud:scloud
				                                           fullDownload:YES
				                                             identifier:identifier
				                                        completionBlock:
				    ^(NSError *error, NSDictionary *infoDict)
				{
					if (completionBlock) {
						completionBlock(message, error);
					}
				}];
				
			}
			else
			{
				if (completionBlock) {
					completionBlock(message, error);
				}
			}
			
		}]; // end [databaseConnection asyncReadWrite...
		
	}]; // end [[SCloudManager sharedInstance] startDownLoad...
}

#if TARGET_OS_IPHONE

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Assets
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Use this method when creating a new conversation.
 * That is, when the user chooses to create a new conversation, and chooses a single recipient.
 *
 * This method will automatically create the conversation (if needed),
 * and then queue the given asset to be sent automatically after the upload completes.
 *
 * @param recipientJID
 *   The user to send to.
 *   If a conversation for this doesn't already exist, then one is automatically created.
 *
 * @param completionBlock
 *   messageId         - The uuid of the corresponding STMessage that was created
 *   conversationId    - The uuid of the corresponding STConversation (which may have been created)
**/
- (void)sendAssetWithInfo:(NSDictionary *)assetInfo
                    toJID:(XMPPJID *)recipientJID
               completion:(void (^)(NSString *messageId, NSString *conversationId))completionBlock
{
	DDLogAutoTrace();
	
	if (assetInfo == nil) {
		DDLogWarn(@"%@ - Ignoring: assetInfo == nil", THIS_METHOD);
		return;
	}
	
	if (recipientJID == nil) {
		DDLogWarn(@"%@ - Ignoring: recipient == nil", THIS_METHOD);
		return;
	}
	
	NSAssert([recipientJID isKindOfClass:[XMPPJID class]], @"Invalid parameter type: 'recipient' not a jid");
	
	// Generate conversationId from JIDs using a hashing technique.
	// This makes it faster to find conversationIds given an xmpp stanza with just a remoteJID.
	
	NSString *conversationID = [self conversationIDForRemoteJid:recipientJID];
	__block NSString *messageID = nil;
	
	NSMutableArray *transactionCompletionBlocks = [[NSMutableArray alloc] init];
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		transaction.completionBlocks = transactionCompletionBlocks;
		
		// Create conversation if needed,
		// or touch the conversation lastUpdated timestamp.
		
		STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
		if (conversation == nil)
		{
			conversation = [[STConversation alloc] initWithUUID:conversationID
			                                        localUserID:localUserID
			                                           localJID:[localJID bareJID]
			                                          remoteJID:recipientJID];
			
			conversation.sendReceipts = [STPreferences defaultSendReceipts];
			conversation.shouldBurn   = [STPreferences defaultShouldBurn];
			conversation.shredAfter   = [STPreferences defaultBurnTime];
			
			conversation.hidden = NO;
			
			[transaction setObject:conversation
			                forKey:conversation.uuid
			          inCollection:conversation.userId];
		}
		else if (conversation.hidden)
		{
			conversation = [conversation copy];
			conversation.hidden = NO;
			
			// conversation.lastUpdated is updated automatically by YapDatabaseHooks extension when
			// a message is added to the conversation
			
			[transaction setObject:conversation
			                forKey:conversation.uuid
			          inCollection:conversation.userId];
		}
		
		// Create the remote user if needed.
		
		[self findOrCreateUserWithJID:recipientJID transaction:transaction wasCreated:NULL];
		
		// Send the message
		
		messageID = [self sendAssetWithInfo:assetInfo forConversation:conversation transaction:transaction];
		
	} completionBlock:^{
		
		for (dispatch_block_t block in transactionCompletionBlocks) {
			block();
		}
		
		if (completionBlock) {
			completionBlock(messageID, conversationID);
		}
	}];
}

/**
 * Use this method when creating a new conversation.
 * That is, when the user chooses to create a new conversation, and chooses multiple recipients.
 *
 * This method will automatically create the conversation (if needed),
 * and then queue the given asset to be sent automatically after the upload completes.
 *
 * @param completionBlock
 *   messageId         - The uuid of the corresponding STMessage that was created
 *   conversationId    - The uuid of the corresponding STConversation (which may have been created)
**/
- (void)sendAssetWithInfo:(NSDictionary *)assetInfo
                 toJidSet:(XMPPJIDSet *)recipients
               completion:(void (^)(NSString *messageId, NSString *conversationId))completionBlock
{
	DDLogAutoTrace();
	
	if (assetInfo == nil) {
		DDLogWarn(@"%@ - Ignoring: assetInfo == nil", THIS_METHOD);
		return;
	}
	if ([recipients containsJid:localJID options:XMPPJIDCompareBare]) {
		recipients = [recipients setByRemovingJid:localJID options:XMPPJIDCompareBare];
	}
	if (recipients.count == 0) {
		DDLogWarn(@"%@ - Ignoring: recipients.count == 0", THIS_METHOD);
		return;
	}
	
	// Generate a random threadID.
	//
	// And generate the conversationId using a hashing technique.
	// This makes it faster to find conversationIds given an xmpp stanza with just a threadID.
	
	NSString *threadID = [XMPPStream generateUUID];
	NSString *conversationID = [self conversationIDForThreadID:threadID];
	
	__block NSString *messageID = nil;
	
	NSMutableArray *transactionCompletionBlocks = [[NSMutableArray alloc] init];
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		transaction.completionBlocks = transactionCompletionBlocks;
		
		// Create multicastKey and add to database
		
		STSymmetricKey *multicastKey =
		  [STSymmetricKey keyWithThreadID:threadID
		                          creator:[localJID bare]
		                       expireDate:nil // dont set expire dates for conversation keys
		                       storageKey:self.storageKey];
		
		[transaction setObject:multicastKey
						forKey:multicastKey.uuid
				  inCollection:kSCCollection_STSymmetricKeys];
		
		// Create conversation and add to database
		
		STConversation *conversation =
		  [[STConversation alloc] initWithUUID:conversationID
		                           localUserID:localUserID
		                              localJID:[localJID bareJID]
		                              threadID:threadID];
		
		conversation.multicastJidSet = recipients;
		conversation.keyLocator = multicastKey.uuid;
		
		conversation.sendReceipts = NO;  // never for multicast
		conversation.shouldBurn   = [STPreferences defaultShouldBurn];
		conversation.shredAfter   = [STPreferences defaultBurnTime];
		
		conversation.hidden = NO;
		
		[transaction setObject:conversation
		                forKey:conversation.uuid
		          inCollection:conversation.userId];
		
		// Create the remote user(s) if needed.
		
		for (XMPPJID *recipientJID in recipients)
		{
			[self findOrCreateUserWithJID:recipientJID transaction:transaction wasCreated:NULL];
		}
		
		// Send multicast siren.
		// This siren gets sent to every recipient in conversation.multicastJidSet.
		
		Siren *siren = Siren.new;
		siren.multicastKey = multicastKey.keyJSON;
		
		[self sendPubSiren:siren forConversation:conversation transaction:transaction];
		
		// Send the message
		
		messageID = [self sendAssetWithInfo:assetInfo forConversation:conversation transaction:transaction];
		
	} completionBlock:^{
		
		for (dispatch_block_t block in transactionCompletionBlocks) {
			block();
		}
		
		if (completionBlock) {
			completionBlock(messageID, conversationID);
		}
	}];
}

/**
 * Use this method when the conversationID is already known.
 * That is, the STConversation already exists.
 *
 * This method will queue the given asset to be sent automatically after the upload completes.
 *
 * @param completionBlock
 *   messageId - The uuid of the corresponding STMessage that was created
**/
- (void)sendAssetWithInfo:(NSDictionary *)assetInfo
        forConversationID:(NSString *)conversationId
               completion:(void (^)(NSString *messageId))completionBlock
{
	DDLogAutoTrace();
	
	// Sanity checks
	
	if (assetInfo == nil) {
		DDLogWarn(@"%@ - Ignoring: assetInfo == nil", THIS_METHOD);
		return;
	}
	if (conversationId == nil) {
		DDLogWarn(@"%@ - Ignoring: conversationId == nil", THIS_METHOD);
		return;
	}
	
	__block NSString *messageId = nil;
	
	NSMutableArray *transactionCompletionBlocks = [[NSMutableArray alloc] init];
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		transaction.completionBlocks = transactionCompletionBlocks;
		
		STConversation *conversation = [transaction objectForKey:conversationId inCollection:localUserID];
		if (conversation == nil)
		{
			DDLogWarn(@"%@ - Unable to sendAssetWithInfo: conversation == nil", THIS_METHOD);
			return_from_block;
		}
		
		// conversation.lastUpdated is updated automatically by YapDatabaseHooks extension when
		// a message is added to the conversation
		
		messageId = [self sendAssetWithInfo:assetInfo forConversation:conversation transaction:transaction];
		
	} completionBlock:^{
		
		for (dispatch_block_t block in transactionCompletionBlocks) {
			block();
		}
		
		if (completionBlock) {
			completionBlock(messageId);
		}
	}];
}

/**
 * Internal method that handles all the details of queuing & sending the asset.
 * 
 * Note: This method does NOT touch the conversation.
 * The caller is responsible for doing so (if needed).
 * 
 * @returns
 *   The messageId of the created STMessage.
**/
- (NSString *)sendAssetWithInfo:(NSDictionary *)assetInfo
                forConversation:(STConversation *)conversation
                    transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	NSString *messageId = [XMPPStream generateUUID];
	
	// Extract info from mediaInfo
	
	NSDictionary * metadata      = [assetInfo objectForKey:kAssetInfo_Metadata];
	NSData       * thumbnailData = [assetInfo objectForKey:kAssetInfo_ThumbnailData];
	NSData       * mediaData     = [assetInfo objectForKey:kAssetInfo_MediaData];
	ALAsset      * asset         = [assetInfo objectForKey:kAssetInfo_Asset];
	
	NSString * mediaType = [metadata objectForKey:kSCloudMetaData_MediaType];
	NSString * mimeType  = [metadata objectForKey:kSCloudMetaData_MimeType];
	NSString * filename  = [metadata objectForKey:kSCloudMetaData_FileName];
	NSString * duration  = [metadata objectForKey:kSCloudMetaData_Duration];
	
	OSImage *thumbnailImage = nil;
    if (thumbnailData)
	{
		#if TARGET_OS_IPHONE
		thumbnailImage = [UIImage imageWithData:thumbnailData scale:[[UIScreen mainScreen] scale]];
		#else
		thumbnailImage = [NSImage imageWithData:thumbnailData];
		#endif
    }
	
	// Create the message siren
	
	Siren *siren = [Siren new];
	siren.mediaType  = mediaType;
	siren.mimeType   = mimeType;
	siren.duration   = duration;
	siren.thumbnail  = thumbnailData;
	siren.message    = filename;

    if ([metadata objectForKey:kSCloudMetaData_GPS]) {
		siren.hasGPS = YES;
	}
	
	// Configure the siren for the conversation
	
	if (!conversation.isMulticast)
		siren.requestReceipt = YES; // always ask for recipts
	
	if (conversation.tracking)
	{
		CLLocation *location = [[GeoTracking sharedInstance] currentLocation];
		if (location)
		{
			siren.location = [location JSONString];
		}
	}
	
	if (conversation.fyeo)
		siren.fyeo = YES;
	
	if (conversation.shouldBurn && conversation.shredAfter > 0)
		siren.shredAfter = conversation.shredAfter;
	
	// We don't sign the siren yet.
	// This happens later, in continueSendAsset:::, after we've created the encrypted SCloud item.
	
	// Create message & thumbnail objects
	
	STMessage *message = [[STMessage alloc] initWithUUID:messageId
	                                      conversationId:conversation.uuid
	                                              userId:localUserID
	                                                from:[localJID bareJID]
	                                                  to:[conversation.remoteJid bareJID]
	                                           withSiren:siren
	                                           timestamp:[NSDate date]
	                                          isOutgoing:YES];
	
	// We're storing the message to the database now,
	// but we can't send it until after the scloud components have been uploaded.
	// So we use the needsUpload flag to represent this.
	message.needsEncrypting = YES;
	
	[transaction setObject:message
	                forKey:message.uuid
	          inCollection:message.conversationId];
	
	STImage *thumbnail = [[STImage alloc] initWithImage:thumbnailImage
	                                          parentKey:messageId
	                                         collection:conversation.uuid];
	
	[transaction setObject:thumbnail
	                forKey:thumbnail.parentKey
	          inCollection:kSCCollection_STImage_Message];
			
	
	dispatch_queue_t backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(backgroundQueue, ^{
		
		if (mediaData)
		{
			// Items  with mediaData are typically smaller (scaled down photos).
			
			SCloudObject *scloud = [[SCloudObject alloc] initWithDelegate:[SCloudManager sharedInstance]
			                                                         data:mediaData
			                                                     metaData:metadata
			                                                    mediaType:mediaType
			                                                contextString:[conversation.localJid bare]];
			scloud.thumbnail = thumbnailImage;
			
			[[SCloudManager sharedInstance] startEncryptwithScloud:scloud
			                                             withSiren:siren
			                                            fromUserID:localUserID
			                                        conversationID:conversation.uuid
			                                             messageID:message.uuid
			                                       completionBlock:^(NSError *error, NSDictionary *infoDict)
			{
				if (error)
				{
					// Todo: What do we do here?
					// When is the upload re-tried?
				}
				else // if (!error)
				{
					[self continueSendAsset:scloud
							   forMessageID:messageId
							 conversationID:conversation.uuid];
				}
				
			}]; // end [SCloudManager startEncryptwithScloud:...
			
		}
		else if (asset)
		{
			// Items  with assets are typically larger ?
			
			SCloudObject *scloud = [[SCloudObject alloc] initWithDelegate:[SCloudManager sharedInstance]
			                                                        asset:asset
			                                                     metaData:metadata
			                                                    mediaType:mediaType
			                                                contextString:[conversation.localJid bare]];
			scloud.thumbnail = thumbnailImage;
			
			[[SCloudManager sharedInstance] startEncryptwithScloud:scloud
			                                             withSiren:siren
			                                            fromUserID:localUserID
			                                        conversationID:conversation.uuid
			                                             messageID:message.uuid
			                                       completionBlock:^(NSError *error, NSDictionary *infoDict)
			{
				if (error)
				{
					// Todo: What do we do here?
					// When is the upload re-tried?
				}
				else // if (!error)
				{
					[self continueSendAsset:scloud
					           forMessageID:messageId
					         conversationID:conversation.uuid];
				}
				
			}]; // end [SCloudManager startEncryptwithScloud:...
			
		}
		else // if (!mediaData && !assetURL)
		{
			DDLogWarn(@"Unable to send item without mediaData or assetURL !?!");
		}
	});
	
	return messageId;
}

/**
 *
**/
- (void)continueSendAsset:(SCloudObject *)scloud
			 forMessageID:(NSString *)messageId
		   conversationID:(NSString *)conversationId
{
    DDLogAutoTrace();
	
	__block Siren *siren = nil;
	__block STLocalUser *localUser = nil;
	
	__block BOOL readyForUpload = YES;
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
		
		STMessage *message = [transaction objectForKey:messageId inCollection:conversationId];
		
		if (message == nil)
		{
			// The message was deleted / burned by the user.
			readyForUpload = NO;
			return_from_block;
		}
		
		localUser = [transaction objectForKey:localUserID inCollection:kSCCollection_STUsers];
		
        // Update siren
		
		siren = [message.siren copy];
		siren.cloudKey = scloud.keyString;
		siren.cloudLocator = scloud.locatorString;
		
		if (!siren.location)
		{
			STConversation *conversation = [transaction objectForKey:conversationId inCollection:localUserID];
			if (conversation.tracking)
			{
				CLLocation *location = [[GeoTracking sharedInstance] currentLocation];
				if (location)
				{
					siren.location = [location JSONString];
				}
			}
		}
		
		STPublicKey *publicKey = [transaction objectForKey:localUser.currentKeyID
		                                      inCollection:kSCCollection_STPublicKeys];
	    if (publicKey)
		{
			siren.signature = [self signSiren:siren withPublicKey:publicKey];
		}
            
		// Update message
		
		message = [message copyWithNewSiren:siren];
		message.needsEncrypting = NO;
		message.needsUpload = YES;
		
		[transaction setObject:message
		                forKey:message.uuid
		          inCollection:message.conversationId];
		
		// Create or update STSCloud
		
		STSCloud *scl = [transaction objectForKey:scloud.locatorString inCollection:kSCCollection_STSCloud];
		if (scl == nil)
		{
			scl = [[STSCloud alloc] initWithUUID:scloud.locatorString
			                           keyString:scloud.keyString
			                              userId:localUserID
			                           mediaType:scloud.mediaType
			                            metaData:scloud.metaData
			                            segments:scloud.segmentList
			                           timestamp:[NSDate date]
			                     lowRezThumbnail:scloud.thumbnail
			                         isOwnedbyMe:YES
			                          dontExpire:NO
			                                fyeo:message.siren.fyeo];
		}
		else
		{
			scl = [scl copy];
		}
		
		scl.unCacheDate = [[NSDate date] dateByAddingTimeInterval:[STPreferences scloudCacheLifespan]];
		
		[transaction setObject:scl
		                forKey:scl.uuid
		          inCollection:kSCCollection_STSCloud];
		
		// Create a relationship between the STMessage and STSCloud object.
		//
		// YDB_DeleteDestinationIfAllSourcesDeleted:
		//   When the every last message that points to this particular STSCloud has been deleted,
		//   then the database will automatically delete this STSCloud object.
		//
		// Further, the STSCloud object uses the YapDatabaseRelationshipNode protocol so that
		// when the STSCloud object is deleted, the database automatically deletes the folder
		// where it stores all its segments.
		
		YapDatabaseRelationshipEdge *edge =
		  [YapDatabaseRelationshipEdge edgeWithName:@"scloud"
		                                  sourceKey:message.uuid
		                                 collection:message.conversationId
		                             destinationKey:scl.uuid
		                                 collection:kSCCollection_STSCloud
		                            nodeDeleteRules:YDB_DeleteDestinationIfAllSourcesDeleted];
		
		[[transaction ext:Ext_Relationship] addEdge:edge];
	
    } completionBlock:^{
		
		if (readyForUpload)
		{
			[self uploadScloud:scloud
			     withBurnDelay:siren.shredAfter
			         localUser:localUser
			         messageID:messageId
			    conversationID:conversationId];
		}
        
    }]; // end asyncReadWriteWithBlock:completionBlock:
}

#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Reverify
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// attempt to reverify a message's signature after it's in the database

- (void)reverifySignatureForMessage:(STMessage *)message completionBlock:(void (^)(NSError *error))completionBlock
{
	__block STUser *sender = nil;
	[databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		sender = [STDatabaseManager findUserWithJID:message.from transaction:transaction];
		
	} completionBlock:^{
		
		[[STUserManager sharedInstance] refreshWebInfoForUser:sender
		                                      completionBlock:^(NSError *error, NSString *userID, NSDictionary *infoDict)
		{
			if (error)
			{
				if (completionBlock) {
					completionBlock(error);
				}
			}
			else
			{
				[self reverifySignatureForMessageContinue:message completionBlock:completionBlock];
			}
		}];
	}];
}

- (void)reverifySignatureForMessageContinue:(STMessage *)message
                            completionBlock:(void (^)(NSError *error))completionBlock
{
	__block NSError *error = nil;
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
		
		BOOL sig_keyFound = NO;
		BOOL sig_valid    = NO;
		
		NSDictionary *signatureInfo = [self signatureInfoFromSiren:message.siren withTransaction:transaction];
		if (signatureInfo)
		{
			sig_keyFound = [[signatureInfo objectForKey:kSigInfo_keyFound] boolValue];
			
			NSString *owner = [signatureInfo objectForKey:kSigInfo_owner];
			NSString *from = [message.from bare];
			
			if ([owner isEqualToString:from])
			{
				NSDate *expireDate = [signatureInfo objectForKey:kSigInfo_expireDate];
				if ([expireDate timeIntervalSinceDate:message.timestamp] > 0)
				{
					sig_valid = [[signatureInfo objectForKey:kSigInfo_valid] boolValue];
				}
			}
		}
		
		if (!sig_keyFound) {
			error = [SCimpUtilities errorWithSCLError:kSCLError_KeyNotFound];
		}
		else if (!sig_valid) {
			error = [SCimpUtilities errorWithSCLError:kSCLError_SecretsMismatch];
		}
		
		// Fetch the latest version of the message object
		STMessage *updatedMessage = [transaction objectForKey:message.uuid inCollection:message.conversationId];
		updatedMessage = [updatedMessage copy];
		
		updatedMessage.signatureInfo = signatureInfo;
		updatedMessage.isVerified = sig_valid;
		
		[transaction setObject:updatedMessage
						forKey:updatedMessage.uuid
				  inCollection:updatedMessage.conversationId];
		
	} completionBlock:^{
		
		if (completionBlock) {
			completionBlock(error);
		}
	}];
}

- (void)reverifyRequestResendSiren:(Siren *)siren from:(XMPPJID *)senderJID
{
	DDLogAutoTrace();
	NSAssert(siren.requestResend, @"Invalid siren type");
	
	__block STUser *sender = nil;
	[databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		sender = [STDatabaseManager findUserWithJID:senderJID transaction:transaction];
		
	} completionBlock:^{
		
		[[STUserManager sharedInstance] refreshWebInfoForUser:sender
		                                      completionBlock:^(NSError *error, NSString *userID, NSDictionary *infoDict)
		{
			if (!error)
			{
				[self reverifyRequestResendSirenContinue:siren from:senderJID];
			}
		}];
	}];
}

- (void)reverifyRequestResendSirenContinue:(Siren *)siren from:(XMPPJID *)senderJID
{
	DDLogAutoTrace();
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		BOOL sig_keyFound = NO;
		BOOL sig_valid    = NO;
		
		NSDictionary *signatureInfo = [self signatureInfoFromSiren:siren withTransaction:transaction];
		if (signatureInfo)
		{
			sig_keyFound = [[signatureInfo objectForKey:kSigInfo_keyFound] boolValue];
			
			NSString *owner = [signatureInfo objectForKey:kSigInfo_owner];
			NSString *from = [senderJID bare];
			
			if ([owner isEqualToString:from])
			{
				NSDate *expireDate = [signatureInfo objectForKey:kSigInfo_expireDate];
				if ([expireDate timeIntervalSinceNow] > 0)
				{
					sig_valid = [[signatureInfo objectForKey:kSigInfo_valid] boolValue];
				}
			}
		}
		
		if (!sig_valid)
		{
			DDLogWarn(@"%@ - Ignoring requestResend. Signature still invalid.", THIS_METHOD);
			return;
		}
		
		NSString *messageID = siren.requestResend;
		NSString *conversationID = [self conversationIDForRemoteJid:senderJID];
		
		STMessage *message = [transaction objectForKey:messageID inCollection:conversationID];
		if (message == nil) {
			return;
		}
		
		// Guard code.
		if (!message.isOutgoing)
		{
			// You want me to resend a message I never sent in the first place?
			
			DDLogWarn(@"%@ - Ignoring requestResend for non-outgoing message.", THIS_METHOD);
			return;
		}
		if (message.rcvDate)
		{
			// You want me to resend a message that you've already told me you received?
			
			DDLogWarn(@"%@ - Ignoring requestResend for message with rcvDate.", THIS_METHOD);
			return;
		}
		
		// copy the message siren
		Siren *sirenToResend = [message.siren copy];
		sirenToResend.signature = NULL;
		
		// delete the old message
		[transaction removeObjectForKey:message.uuid inCollection:message.conversationId];
		
		// Touch the conversation
		[[transaction ext:Ext_View_Order] touchRowForKey:message.conversationId
											inCollection:message.userId];
		
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
		
		// Resend the siren (if needed)
		
		STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
		
		[self sendSiren:sirenToResend forConversation:conversation
		                                     withPush:YES
		                                        badge:YES
		                                createMessage:YES
		                                  transaction:transaction];
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Rekey
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)forceRekeyConversationID:(NSString *)conversationID
                 completionBlock:(void (^)(NSError *error))completionBlock
{
	DDLogAutoTrace();
	
	NSMutableArray *transactionCompletionBlocks = [[NSMutableArray alloc] init];
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		transaction.completionBlocks = transactionCompletionBlocks;
		
		STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
		
		if (conversation == nil)
		{
			DDLogWarn(@"%@ - conversation not found", THIS_METHOD);
			return_from_block;
		}
		
		[self rekeyConversation:conversation forceIfKeyingInProgress:YES withTransaction:transaction];
	
	} completionBlock:^{
		
		for (dispatch_block_t block in transactionCompletionBlocks) {
			block();
		}
		
		if (completionBlock) {
			completionBlock(nil);
		}
		
	}];
}

- (void)rekeyConversation:(STConversation *)conversation
  forceIfKeyingInProgress:(BOOL)forceIfKeyingInProgress
          withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	NSParameterAssert(conversation != nil);
	NSParameterAssert(transaction != nil);
	
	if (conversation.isMulticast)
	{
		// Generate a new symmetric key
		
		STSymmetricKey *newMulticastKey =
		  [STSymmetricKey keyWithThreadID:conversation.threadID
		                          creator:localJID.bare
		                       expireDate:nil                    // Don't set expire dates for multicast keys
		                       storageKey:self.storageKey];
		
		// Send a siren to all the conversation participants which includes the new key
		
		Siren *siren = [Siren new];
		siren.multicastKey = newMulticastKey.keyJSON;
		
		[self sendPubSiren:siren forConversation:conversation transaction:transaction];
		
		// Store the new key, and update the corresponding conversation
		
		[self saveMulticastKey:newMulticastKey withTransaction:transaction];
		
		// Update the scimp state
		
		SCimpWrapper *scimp = [self scimpForThreadID:conversation.threadID withTransaction:transaction isNew:NULL];
		if (scimp)
		{
			SCKeyContextRef scKey = kInvalidSCKeyContextRef;
			SCLError err = SCKey_Deserialize(newMulticastKey.keyJSON, &scKey);
			
			if ((err == kSCLError_NoErr) && SCKeyContextRefIsValid(scKey))
			{
				// Here's how this works:
				//
				// We invoke the SCimpUpdateSymmetricKey, which immediately invokes our MessageStreamSCimpEventHandler.
				// The event handler should advise us to save the scimp state.
				
				SCimpUpdateSymmetricKey(scimp->scimpCtx, [scimp.threadID UTF8String], scKey);
			}
			
			if (SCKeyContextRefIsValid(scKey))
			{
				SCKeyFree(scKey);
				scKey = kInvalidSCKeyContextRef;
			}
		}
	}
	else // P2P conversation
	{
		XMPPJID *remoteJID = conversation.remoteJid;
		
		SCimpWrapper *scimp = [self scimpForRemoteJID:remoteJID withTransaction:transaction isIncoming:NO isNew:NULL];
		if (scimp)
		{
			// Don't key if we're in the middle of keying (unless forceIfKeyingInProgress is set)
			BOOL keyingInProgress = YES;
			
			SCimpState current_state = scimp.protocolState;
			if (current_state == kSCimpState_Init  ||
			    current_state == kSCimpState_Ready ||
			    current_state == kSCimpState_Error  )
			{
				keyingInProgress = NO;
			}
			
			DDLogRed(@"rekey - state = %@", scimp.protocolStateString);
			
			if (keyingInProgress && !forceIfKeyingInProgress)
			{
				return; // Abort
			}
			
			scimp.awaitingReKeying = NO;
			
			if (scimp.remoteJID.resource)
			{
				NSString *oldScimpID = scimp.scimpID;
				[scimp updateRemoteJID:[scimp.remoteJID bareJID]];
				
				[transaction removeObjectForKey:oldScimpID inCollection:kSCCollection_STScimpState];
				
				NSMutableSet *newScimpIDs = [conversation.scimpStateIDs mutableCopy];
				[newScimpIDs removeObject:oldScimpID];
				//
				// Note: We don't explicitly save the updated context here.
				// Instead, it is saved at the end of the re-key flow, and also added to conversation.scimpStateIDs,
				// via the saveScimp:withTransaction method.
				
				conversation = [conversation copy];
				conversation.scimpStateIDs = newScimpIDs;
				
				[transaction setObject:conversation forKey:conversation.uuid inCollection:conversation.userId];
			}
			
			if (YES)
			{
				DDLogInfo(@"SCimpResetKeys()");
				SCimpResetKeys(scimp->scimpCtx);
				
				// SCimpResetKeys will also reset:
				// - kSCimpProperty_CipherSuite
				// - kSCimpProperty_SASMethod
			}
			
			SCimpCipherSuite cipherSuite = [STPreferences scimpCipherSuite];
			SCimpSAS sasMethod = [STPreferences scimpSASMethod];
			
			SCimpSetNumericProperty(scimp->scimpCtx, kSCimpProperty_CipherSuite, cipherSuite);
			SCimpSetNumericProperty(scimp->scimpCtx, kSCimpProperty_SASMethod, sasMethod);
			
			NSData *capData = ([NSJSONSerialization  isValidJSONObject:capabilitiesDict] ?
			                   [NSJSONSerialization dataWithJSONObject:capabilitiesDict options:0 error:nil] :
			                   nil);
			
			Siren *siren = [Siren new];
			siren.ping = kPingRequest;
			siren.capabilities = [[NSString alloc] initWithData:capData encoding:NSASCIIStringEncoding];
			
			XMPPMessage *xmppMessage =
			  [XMPPMessage chatMessageWithSiren:siren
			                                 to:[scimp.remoteJID bareJID]
			                          elementID:nil
			                               push:YES
			                              badge:YES];
			
			// This method will automatically
			
			scimp->temp_forceReKey = YES;
			transaction.isReKeying = YES;
			
			BOOL result = [self trySendXmppStanza:xmppMessage withTransaction:transaction];
			
			if (result)
			{
				[xmppMessage stripSilentCirclePlaintextDataForOutgoingStanza];
				STXMPPElement *element = [[STXMPPElement alloc] initWithKeyingMessage:xmppMessage
				                                                          localUserID:localUserID
				                                                       conversationID:conversation.uuid];
				
				[transaction setObject:element
				                forKey:element.uuid
				          inCollection:element.conversationID];
			}
			
		} // end if (scimp)
	} // end else P2P conversation
}

- (void)rekeyConversationIfAwaitingReKeying:(STConversation *)conversation
                            withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	if (conversation.isMulticast) {
		return;
	}
	
	XMPPJID *remoteJID = conversation.remoteJid;
	
	SCimpWrapper *scimp = [self scimpForRemoteJID:remoteJID withTransaction:transaction isIncoming:NO isNew:NULL];
	if (scimp)
	{
		if (scimp.awaitingReKeying)
		{
			[self rekeyConversation:conversation forceIfKeyingInProgress:NO withTransaction:transaction];
		}
	}
}

- (void)rekeyScimpAfterRefreshingUserWebInfo:(SCimpWrapper *)scimp
                             withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	if (scimp == nil) {
		DDLogWarn(@"%@ - Invalid parameter: scimp == nil", THIS_METHOD);
		return;
	}
	
	if ([scimp isReady])
	{
		// I've seen this happen before when doing a lot of back-to-back re-keying.
		// So the scimp error is because of all the re-keying.
		
		DDLogWarn(@"%@ - Expected scimp to be in a bad state !", THIS_METHOD);
		return;
	}
	
	STUser *user = [STDatabaseManager findUserWithJID:scimp.remoteJID transaction:transaction];
	if (user == nil) {
		DDLogWarn(@"%@ - Unable to find user for scimp: remoteJID = %@", THIS_METHOD, scimp.remoteJID);
		return;
	}
	
	if (user.awaitingReKeying == NO)
	{
		user = [user copy];
		user.awaitingReKeying = YES;
		
		[transaction setObject:user forKey:user.uuid inCollection:kSCCollection_STUsers];
	}
	
	if (scimp.awaitingReKeying == NO)
	{
		scimp.awaitingReKeying = YES;
		[self saveScimp:scimp withTransaction:transaction];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark IsVerified
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Use this when the user flips the "SAS verified" switch.
**/
- (void)setScimpID:(NSString *)scimpID isVerified:(BOOL)isVerifiedFlag
{
	DDLogAutoTrace();
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		SCimpWrapper *scimp = [self existingScimpForScimpID:scimpID withTransaction:transaction];
		if (scimp)
		{
			scimp.isVerified = isVerifiedFlag;
			[self saveScimp:scimp withTransaction:transaction];
		}
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Standard Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * In order to save and restore state, a key is used to encrypt the saved state,
 * and later used to decrypt saved state in order to restore it.
 *
 * If a key exists for this combination of JIDs, it should be returned.
 * Otherwise, a new key is to be generated, stored for this combination of JIDs, and then returned.
**/
- (SCKeyContextRef)storageKey
{
	return STAppDelegate.storageKey;
}

static NSString* MessageStreamSecureHash(NSData *data1, NSData *data2)
{
    NSString *hash = nil;
   
	SCLError        err     = kSCLError_NoErr;
	HASH_ContextRef hashRef = kInvalidHASH_ContextRef;
	size_t          len     = 0;
    
	uint8_t *hashString = NULL;
	uint8_t  hashBuf[64];
	size_t   hashSize = 0;
	uint8_t *p;
	
	uint8_t symKey[64];
	size_t  symKeyLen = 0;
	
	SCKeyContextRef storageKey = STAppDelegate.storageKey;
	err = SCKeyGetProperty(storageKey, kSCKeyProp_SymmetricKey, NULL, &symKey, sizeof(symKey), &symKeyLen); CKERR;

    len = (1 + data1.length) + (1 + data2.length) + (1 + symKeyLen);
    
    p = hashString = XMALLOC(len);
    
    *p++ = data1.length &0xFF;
    len = data1.length;
    memcpy(p, data1.bytes, len);
    p+=len;
 
    *p++ = data2.length &0xFF;
    len = data2.length;
    memcpy(p, data2.bytes, len);
    p+=len;
    
    *p++ = symKeyLen &0xFF;
    len = symKeyLen;
    memcpy(p, symKey, len);
    p+=len;
    
#if USE_CC
    hashSize = CC_SHA1_DIGEST_LENGTH;
    CC_SHA1(hashString, (CC_LONG)(p-hashString), hashBuf);
#else
    err = HASH_Init(kHASH_Algorithm_SHA1, &hashRef);       CKERR;
    err = HASH_GetSize(hashRef, &hashSize);                CKERR;
    err = HASH_Update(hashRef, hashString,  p-hashString); CKERR;
    err = HASH_Final(hashRef, hashBuf);                    CKERR;
#endif
	
    hash = [NSString hexEncodeBytes:hashBuf length:hashSize];
    
done:
    
    ZERO(symKey, sizeof(symKey));
    
    if (!IsNull(hashRef))
        HASH_Free(hashRef);

	if (IsntNull(hashString))
	{
		ZERO(hashString, p-hashString);
		XFREE(hashString);
	}

	return hash;
}

static NSString* MessageStreamSecureHashWithNonce(NSData *data1, NSData *data2, NSData *nonce)
{
	NSString *hash = nil;
	
	SCLError        err     = kSCLError_NoErr;
	HASH_ContextRef hashRef = kInvalidHASH_ContextRef;
	size_t          len     = 0;
    
	uint8_t *hashString = NULL;
	uint8_t  hashBuf[64];
	size_t   hashSize = 0;
	uint8_t *p;
    
    uint8_t symKey[64];
    size_t  symKeyLen = 0;
    
	SCKeyContextRef storageKey = STAppDelegate.storageKey;
	err = SCKeyGetProperty(storageKey, kSCKeyProp_SymmetricKey, NULL, &symKey , sizeof(symKey), &symKeyLen); CKERR;
   
	len = (1 + nonce.length) + (1 + data1.length) + (1 + symKeyLen) + (1 + data2.length);
    
    p = hashString = XMALLOC(len);
    
	*p++ = nonce.length &0xFF;
	len = nonce.length;
	memcpy(p, nonce.bytes, len);
	p+=len;

    *p++ = data1.length &0xFF;
    len = data1.length;
    memcpy(p, data1.bytes, len);
    p+=len;
      
    *p++ = symKeyLen &0xFF;
    len = symKeyLen;
    memcpy(p, symKey, len);
    p+=len;
    
    *p++ = data2.length &0xFF;
    len = data2.length;
    memcpy(p, data2.bytes, len);
    p+=len;

    
#if USE_CC
    hashSize = CC_SHA1_DIGEST_LENGTH;
    CC_SHA1(hashString, (CC_LONG)(p-hashString), hashBuf);
#else
    err = HASH_Init(kHASH_Algorithm_SHA1, &hashRef);       CKERR;
    err = HASH_GetSize(hashRef, &hashSize);                CKERR;
    err = HASH_Update(hashRef, hashString,  p-hashString); CKERR;
    err = HASH_Final(hashRef, hashBuf);                    CKERR;
#endif
    
    hash = [NSString hexEncodeBytes:hashBuf length:hashSize];
    
done:
    ZERO(symKey, sizeof(symKey));

    if (!IsNull(hashRef))
        HASH_Free(hashRef);
    
    if (IsntNull(hashString))
    {
		ZERO(hashString, p-hashString);
		XFREE(hashString);
    }
    
    return hash;
}

/**
 * The conversationID is NOT a random UUID.
 * Instead its actually generated by hashing the remoteJID & localJID.
 * 
 * Why do we do it this way?
 *
 * Because when the raw messages come in over the protocol (xmpp), we only have the remoteJID & localJID.
 * This way we can simply hash the existing information, and get the conversationID.
 * The alternative would require us to keep some kind of extra index in the database,
 * and use the index to do a lookup of the conversationID everytime. So our hashing technique is MUCH faster.
**/
+ (NSString *)conversationIDForLocalJid:(XMPPJID *)_localJid remoteJid:(XMPPJID *)_remoteJid
{
	NSAssert(_localJid  != nil, @"Bad param: localJid");
	NSAssert(_remoteJid != nil, @"Bad param: remoteJid");
	
	NSData *remoteBareJidData = [[_remoteJid bare] dataUsingEncoding:NSUTF8StringEncoding];
	NSData *localBareJidData = [[_localJid bare] dataUsingEncoding:NSUTF8StringEncoding];

	return MessageStreamSecureHash(remoteBareJidData, localBareJidData);
}

- (NSString *)conversationIDForRemoteJid:(XMPPJID *)remoteJID
{
	return [MessageStream conversationIDForLocalJid:localJID remoteJid:remoteJID];
}

/**
 * The conversationID is NOT a random UUID.
 * Instead its actually generated by hashing the threadID & localJID.
 *
 * Why do we do it this way?
 *
 * Because when the raw messages come in over the protocol (xmpp), we only have the threadID & localJID.
 * This way we can simply hash the existing information, and get the conversationID.
 * The alternative would require us to keep some kind of extra index in the database,
 * and use the index to do a lookup of the conversationID everytime. So our hashing technique is MUCH faster.
**/
+ (NSString *)conversationIDForLocalJid:(XMPPJID *)_localJid threadID:(NSString *)_threadID
{
	NSAssert(_localJid != nil, @"Bad param: localJid");
	NSAssert(_threadID != nil, @"Bad param: threadID");
	
	NSData *threadIdData = [_threadID dataUsingEncoding:NSUTF8StringEncoding];
	NSData *localBareJidData = [[_localJid bare] dataUsingEncoding:NSUTF8StringEncoding];
	
	NSData *nonce = [@"threadID:" dataUsingEncoding:NSUTF8StringEncoding];
	
	return MessageStreamSecureHashWithNonce(threadIdData, localBareJidData, nonce);
}

- (NSString *)conversationIDForThreadID:(NSString *)threadID
{
	return [MessageStream conversationIDForLocalJid:localJID threadID:threadID];
}

- (NSString *)messageIDCacheKeyForFullRemoteJID:(XMPPJID *)fullRemoteJID
{
	if (fullRemoteJID == nil) return nil;
	
	NSData *fullRemoteJidData = [[fullRemoteJID full] dataUsingEncoding:NSUTF8StringEncoding];
	NSData *bareLocalJidData  = [[localJID bare] dataUsingEncoding:NSUTF8StringEncoding];
	
	return MessageStreamSecureHash(fullRemoteJidData, bareLocalJidData);
}

- (XMPPMessage *)xmppMessageForMessage:(STMessage *)message withConversation:(STConversation *)conversation
{
	XMPPMessage *xmppMessage = nil;
	
	if (conversation.isMulticast)
	{
		// Sanity check on multicastJidSet (which shouldn't contain our JID, but we're being cautious)
		
		XMPPJIDSet *mcJids = conversation.multicastJidSet;
		mcJids = [mcJids setByRemovingJid:localJID options:XMPPJIDCompareBare];
		
		xmppMessage = [XMPPMessage multicastChatMessageWithSiren:message.siren
		                                                      to:[mcJids allJids]
		                                                threadID:conversation.threadID
		                                                  domain:localJID.domain
		                                               elementID:message.uuid];
	}
	else
	{
		xmppMessage = [XMPPMessage chatMessageWithSiren:message.siren
		                                             to:[conversation.remoteJid bareJID]
		                                      elementID:message.uuid
		                                           push:YES
		                                          badge:YES];
	}
	
	return xmppMessage;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Database Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Finds an object in the database when only its key is known (collection is unknown).
 *
 * The class must be specified as well, to guard cases where the item has related objects in the database.
 * (Such as an STImage with the same key).
**/
- (id)findObjectForKey:(NSString *)key withClass:(Class)class transaction:(YapDatabaseReadTransaction *)transaction
{
	__block id object = nil;
	[transaction enumerateCollectionsForKey:key usingBlock:^(NSString *collection, BOOL *stop) {
		
		id anObject = [transaction objectForKey:key inCollection:collection];
        if ([anObject isKindOfClass:class])
        {
            object = anObject;
            *stop = YES;
        }
	}];
	
	return object;
}

- (STUser *)findOrCreateUserWithJID:(XMPPJID *)jid
                        transaction:(YapDatabaseReadWriteTransaction *)transaction
                         wasCreated:(BOOL *)wasCreateadPtr
{
	if (jid == nil) {
		if (wasCreateadPtr) *wasCreateadPtr = NO;
		return nil;
	}
	
	BOOL wasCreated = NO;
	
	STUser *user = [STDatabaseManager findUserWithJID:jid transaction:transaction];
	if (user == nil)
	{
		NSString *uuid = [[NSUUID UUID] UUIDString];
		
		user = [[STUser alloc] initWithUUID:uuid networkID:networkID jid:jid];
		user.isSavedToSilentContacts = NO;
		
		[transaction setObject:user forKey:user.uuid inCollection:kSCCollection_STUsers];
		
		wasCreated = YES;
	}
	
	if (wasCreateadPtr) *wasCreateadPtr = wasCreated;
	return user;
}

- (STPublicKey *)publicKeyForRemoteJID:(XMPPJID *)remoteJID withTransaction:(YapDatabaseReadTransaction *)transaction
{
	STPublicKey *publicKey = nil;
	
	// Use the DatabaseManager's utility method to lookup the user.
	// It uses a secondary index on the JID, and is much faster than enumerating the collection.
	
	STUser *user = [STDatabaseManager findUserWithJID:remoteJID transaction:transaction];
	if (user && user.currentKeyID)
	{
		publicKey = [transaction objectForKey:user.currentKeyID inCollection:kSCCollection_STPublicKeys];
	}
	
	return publicKey;
}

/**
 * Returns the most current symmetric key for the given conversation.
**/
- (STSymmetricKey *)symmetricKeyForConversationID:(NSString *)conversationID
                                  withTransaction:(YapDatabaseReadTransaction *)transaction
{
	DDLogTrace(@"%@ <XMPPSilentCircleStorage>", THIS_METHOD);
	
	STSymmetricKey *result = nil;
	
	STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
	if (conversation && conversation.keyLocator)
	{
		result = [transaction objectForKey:conversation.keyLocator inCollection:kSCCollection_STSymmetricKeys];
	}
	
	return result;
}

/**
 * Returns the most recent symmetric key for the given threadID.
 * 
 * Symmetric keys may be added to the database before the corresponding conversation is created.
 * This method helps to locate the proper key once the conversation object comes about.
**/
- (STSymmetricKey *)symmetricKeyForThreadID:(NSString *)threadID
                            withTransaction:(YapDatabaseReadTransaction *)transaction
{
	__block STSymmetricKey *result = nil;
	__block NSDate *lastDate = [NSDate distantPast];
	
	// Todo: Need to use secondary index to make these lookups faster...
	
	[transaction enumerateKeysAndObjectsInCollection:kSCCollection_STSymmetricKeys
	                                      usingBlock:^(NSString *key, id object, BOOL *stop)
	{
		__unsafe_unretained STSymmetricKey *mcKey = (STSymmetricKey *)object;
		
		if ([mcKey.threadID isEqualToString:threadID])
		{
			if ([mcKey.lastUpdated isAfter:lastDate]) // What is the point of this check ???
			{
				lastDate = mcKey.lastUpdated;
				result = mcKey;
			}
		}
	}];
	
	return result;
}

/**
 * Performs the following related actions:
 * 
 * - Stores the new multicast key into the database
 * - Sets older keys to automatically expire
 * - Updates the corresponding conversation by setting it's multicastKey property
**/
- (void)saveMulticastKey:(STSymmetricKey *)newKey withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	NSString *threadID = newKey.threadID;
	
	// Create an array of existing keys that match this thread.
	
	NSMutableArray *mcKeys = [NSMutableArray array];
	
	[transaction enumerateKeysAndObjectsInCollection:kSCCollection_STSymmetricKeys
	                                      usingBlock:^(NSString *key, id object, BOOL *stop)
	{
		__unsafe_unretained STSymmetricKey *mcKey = (STSymmetricKey *)object;
		
		if ([mcKey.threadID isEqualToString:threadID])
		{
			[mcKeys addObject:mcKey];
		}
	}];
	
	[mcKeys sortUsingComparator:^NSComparisonResult(id a, id b) {
		
		__unsafe_unretained STSymmetricKey *itemA = (STSymmetricKey *)a;
		__unsafe_unretained STSymmetricKey *itemB = (STSymmetricKey *)b;
		
		return [itemB.lastUpdated compare: itemA.lastUpdated];
	}];
	
	// Store the new key.
	// Note that we do this after the search above to ensure the newly stored key isn't in the search results.
	
    [transaction setObject:newKey
                    forKey:newKey.uuid
              inCollection:kSCCollection_STSymmetricKeys];
 
    // Set an expire date for older keys
	
    NSInteger additionalKeystoKeep = [STPreferences multicastKeysToKeep];
    NSTimeInterval multiCastKeyLifespan = [STPreferences multicastKeyLifespan];
	
	NSDate *recycleDate = [NSDate dateWithTimeIntervalSinceNow:multiCastKeyLifespan];
    
	for (STSymmetricKey *key in mcKeys)
	{
		if((additionalKeystoKeep-- > 0)|| key.recycleDate)
            continue;
        
		STSymmetricKey *updatedKey = [key copy];
		updatedKey.recycleDate = recycleDate;
        
        [transaction setObject:updatedKey
                        forKey:updatedKey.uuid
                  inCollection:kSCCollection_STSymmetricKeys];
	}
	
	// Update the corresponding conversation
	
	NSString *conversationID = [self conversationIDForThreadID:threadID];
	
	STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
	if (conversation)
	{
		// If the conversation already exists we need to update a few things
		
		conversation = [conversation copy];
		conversation.keyLocator = newKey.uuid;
		
		[transaction setObject:conversation
						forKey:conversation.uuid
				  inCollection:localUserID];
	}
	else
	{
		// Should we create the conversation ?
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark SCimp
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This is the ONLY method that should be used to fetch a SCimpWrapper (for a p2p conversation).
 * The cache should NEVER be directly consulted.
 * The database should NEVER be directly consulted.
 *
 * This method automatically handles configuring the scimpCtx callback handler.
 * 
 * @param isIncoming
 *   Whether the remoteJID was extracted from an incoming xmpp stanza.
**/
- (SCimpWrapper *)scimpForRemoteJID:(XMPPJID *)remoteJID
                    withTransaction:(YapDatabaseReadWriteTransaction *)transaction
                         isIncoming:(BOOL)isIncoming
                              isNew:(BOOL *)isNewPtr
{
	DDLogAutoTrace();
	
	SCLError err = kSCLError_NoErr;
	
	SCimpWrapper *scimp = nil;
	BOOL isNew = NO;
	BOOL isCached = NO;
	
	// First check scimp cache (for FULL jid)
	
	if (remoteJID.resource)
	{
		scimp = [self __cachedScimpForRemoteJID:remoteJID];
		if (scimp) {
			isCached = YES;
		}
	}
	
	// Then check database (if needed) (for FULL jid)
	
	if (remoteJID.resource && scimp == nil)
	{
		scimp = [self __restoreScimpForRemoteJID:remoteJID withTransaction:transaction error:NULL];
	}
	
	// Then check scimp cache (if needed) (for BARE jid)
	
	if (scimp == nil)
	{
		scimp = [self __cachedScimpForRemoteJID:[remoteJID bareJID]];
		if (scimp) {
			isCached = YES;
		}
	}
	
	// Then check database (if needed) (for BARE jid)
	
	if (scimp == nil)
	{
		scimp = [self __restoreScimpForRemoteJID:[remoteJID bareJID] withTransaction:transaction error:NULL];
	}
	
	// Check to see if we're upgrading from a remoteBareJID to a remoteFullJID
	
	if (scimp && isIncoming && remoteJID.resource && !scimp.remoteJID.resource)
	{
		// Upgrade remoteJID, and change scimpID to match.
		
		NSString *oldScimpID = scimp.scimpID;
		NSString *newScimpID = [scimp updateRemoteJID:remoteJID];
		
		[transaction removeObjectForKey:oldScimpID inCollection:kSCCollection_STScimpState];
		[self saveScimp:scimp withTransaction:transaction];
		
		STConversation *conversation = [transaction objectForKey:scimp.conversationID inCollection:localUserID];
		if (conversation)
		{
			NSMutableSet *newScimpIDs = [conversation.scimpStateIDs mutableCopy];
			[newScimpIDs removeObject:oldScimpID];
			[newScimpIDs addObject:newScimpID];
			
			conversation = [conversation copy];
			conversation.scimpStateIDs = [newScimpIDs copy];
			
			[transaction setObject:conversation
			                forKey:conversation.uuid
			          inCollection:conversation.userId];
		}
	}
	
	// Create new SCimp instance (if needed)
	
	if (scimp == nil)
	{
		isNew = YES;
		
		SCimpContextRef ctx = kInvalidSCimpContextRef;
		
		err = SCimpNew([[localJID bare] UTF8String], [[remoteJID bare] UTF8String], &ctx);
		if (err != kSCLError_NoErr)
		{
			DDLogError(@"SCimpNew error [%@, %@]: %d", [localJID bare], [remoteJID bare], err);
			
			if (isNewPtr) *isNewPtr = NO;
			return nil;
		}
		
		SCimpCipherSuite cipherSuite = [STPreferences scimpCipherSuite];
		SCimpSAS sasMethod = [STPreferences scimpSASMethod];
		
		SCimpSetNumericProperty(ctx, kSCimpProperty_CipherSuite, cipherSuite);
		SCimpSetNumericProperty(ctx, kSCimpProperty_SASMethod, sasMethod);
		
		// This is ST-2 so we can always respond to DHv2
		SCimpSetNumericProperty(ctx, kSCimpProperty_SCIMPmethod, kSCimpMethod_DHv2);
		
		NSString *conversationID = [self conversationIDForRemoteJid:remoteJID];
		scimp = [[SCimpWrapper alloc] initWithSCimpCtx:ctx
		                                conversationID:conversationID
		                                      localJID:localJID
		                                     remoteJID:remoteJID];
	}
	
	// Configure the scimp instance properly (for this transaction)
	
	if (scimp)
	{
		if (!isCached) {
			[scimpCache addObject:scimp];
		}
		
		if (scimp->scimpCtx)
		{
			MessageStreamUserInfo *userInfo = [[MessageStreamUserInfo alloc] init];
			userInfo->ms = self;
			userInfo->transaction = transaction;
			
			scimp->temp_userInfo = userInfo; // strong reference (to prevent deallocation of userInfo)
			
			err = SCimpSetEventHandler(scimp->scimpCtx, MessageStreamSCimpEventHandler, (__bridge void *)userInfo);
			if (err != kSCLError_NoErr)
			{
				DDLogError(@"SCimpSetEventHandler error = %d", err);
			}
			
			SCimpEnableTransitionEvents(scimp->scimpCtx, true);
		}
	}
	
	if (isNewPtr) *isNewPtr = isNew;
	return scimp;
}

/**
 * This is the ONLY method that should be used to fetch a SCimpWrapper (for a multicast conversation).
 * The cache should NEVER be directly consulted.
 * The database should NEVER be directly consulted.
 * 
 * This method automatically handles configuring the scimpCtx callback handler.
**/
- (SCimpWrapper *)scimpForThreadID:(NSString *)threadID
                   withTransaction:(YapDatabaseReadWriteTransaction *)transaction
                             isNew:(BOOL *)isNewPtr
{
	DDLogAutoTrace();
	
	SCLError err = kSCLError_NoErr;
	
	SCimpWrapper *scimp = nil;
	BOOL isNew = NO;
	BOOL isCached = NO;
	
	// First check scimp cache
	
	scimp = [self __cachedScimpForThreadID:threadID];
	if (scimp) {
		isCached = YES;
	}
	
	// Then check database (if needed)
	
	if (scimp == nil)
	{
		scimp = [self __restoreScimpForThreadID:threadID withTransaction:transaction error:&err];
	}
	
	// Create new SCimp instance (if needed)
	
	if (scimp == nil)
	{
		isNew = YES;
		
		SCimpContextRef ctx = kInvalidSCimpContextRef;
		
		NSString *conversationID = [self conversationIDForThreadID:threadID];
		STSymmetricKey *symmetricKey = [self symmetricKeyForConversationID:conversationID withTransaction:transaction];
		
		if (symmetricKey == nil) // it might be a new conversation
		{
			symmetricKey = [self symmetricKeyForThreadID:threadID withTransaction:transaction];
		}
		
		if (symmetricKey)
		{
			SCKeyContextRef key = kInvalidSCKeyContextRef;
			err = SCKey_Deserialize(symmetricKey.keyJSON, &key);
			
			if ((err != kSCLError_NoErr) || !SCKeyContextRefIsValid(key))
			{
				DDLogError(@"SCKeyDeserialize error = %d", err);
				
				if (isNewPtr) *isNewPtr = NO;
				return nil;
			}
			
			err = SCimpNewSymmetric(key, [threadID UTF8String], &ctx);
			SCKeyFree(key);
			
			if (err != kSCLError_NoErr)
			{
				DDLogError(@"SCimpNewSymmetric(key, ..) error = %d", err);
				
				if (isNewPtr) *isNewPtr = NO;
				return nil;
			}
		}
		else
		{
			err = SCimpNewSymmetric(NULL, [threadID UTF8String], &ctx);
			if (err != kSCLError_NoErr)
			{
				DDLogError(@"SCimpNewSymmetric(NULL, ..) error = %d", err);
				
				if (isNewPtr) *isNewPtr = NO;
				return nil;
			}
		}
		
		// use PGP SAS for scimp Symmetric
		SCimpSetNumericProperty(ctx, kSCimpProperty_SASMethod, kSCimpSAS_PGP);
		
		scimp = [[SCimpWrapper alloc] initWithSCimpCtx:ctx
		                                conversationID:conversationID
		                                      localJID:localJID
		                                      threadID:threadID];
	}
	
	// Configure the scimp instance properly (for this transaction)
	
	if (scimp)
	{
		if (!isCached) {
			[scimpCache addObject:scimp];
		}
		
		if (scimp->scimpCtx)
		{
			MessageStreamUserInfo *userInfo = [[MessageStreamUserInfo alloc] init];
			userInfo->ms = self;
			userInfo->transaction = transaction;
			
			scimp->temp_userInfo = userInfo; // strong reference (to prevent deallocation of userInfo)
			
			err = SCimpSetEventHandler(scimp->scimpCtx, MessageStreamSCimpEventHandler, (__bridge void *)userInfo);
			if (err != kSCLError_NoErr)
			{
				DDLogError(@"SCimpSetEventHandler error = %d", err);
			}
			
			SCimpEnableTransitionEvents(scimp->scimpCtx, true);
		}
	}
	
	if (isNewPtr) *isNewPtr = isNew;
	return scimp;
}

/**
 * This is method may be used to fetch a SCimpWrapper, for a known scimpID, for an existing context.
 * The cache should NEVER be directly consulted.
 * The database should NEVER be directly consulted.
 *
 * This method automatically handles configuring the scimpCtx callback handler.
**/
- (SCimpWrapper *)existingScimpForScimpID:(NSString *)scimpID
                          withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	SCLError err = kSCLError_NoErr;
	
	SCimpWrapper *scimp = nil;
	BOOL isCached = NO;
	
	// First check scimp cache
	
	scimp = [self __cachedScimpForScimpID:scimpID];
	if (scimp) {
		isCached = YES;
	}
	
	// Then check database (if needed)
	
	if (scimp == nil)
	{
		scimp = [self __restoreScimpForScimpID:scimpID withTransaction:transaction error:NULL];
	}
	
	// Configure the scimp instance properly (for this transaction)
	
	if (scimp)
	{
		if (!isCached) {
			[scimpCache addObject:scimp];
		}
		
		if (scimp->scimpCtx)
		{
			MessageStreamUserInfo *userInfo = [[MessageStreamUserInfo alloc] init];
			userInfo->ms = self;
			userInfo->transaction = transaction;
			
			scimp->temp_userInfo = userInfo; // strong reference (to prevent deallocation of userInfo)
			
			err = SCimpSetEventHandler(scimp->scimpCtx, MessageStreamSCimpEventHandler, (__bridge void *)userInfo);
			if (err != kSCLError_NoErr)
			{
				DDLogError(@"SCimpSetEventHandler error = %d", err);
			}
			
			SCimpEnableTransitionEvents(scimp->scimpCtx, true);
		}
	}
	
	return scimp;
}

/**
 * NEVER invoke this method directly!
 * You MUST ALWAYS go thru scimpForRemoteJID:withTransaction:isNew.
**/
- (SCimpWrapper *)__cachedScimpForRemoteJID:(XMPPJID *)remoteJID
{
	// Do NOT modify this method!
	// See scimpForRemoteJID:withTransaction:isNew: for proper context.
	
	SCimpWrapper *matchingScimp = nil;
	
	for (SCimpWrapper *cachedScimp in scimpCache)
	{
		if ([cachedScimp.remoteJID isEqualToJID:remoteJID options:XMPPJIDCompareFull])
		{
			matchingScimp = cachedScimp;
			break;
		}
	}
	
	return matchingScimp;
}

/**
 * NEVER invoke this method directly!
 * You MUST ALWAYS go thru scimpForThreadID:withTransaction:isNew.
**/
- (SCimpWrapper *)__cachedScimpForThreadID:(NSString *)threadID
{
	// Do NOT modify this method!
	// See scimpForThreadID:withTransaction:isNew: for proper context.
	
	SCimpWrapper *matchingScimp = nil;
	
	for (SCimpWrapper *cachedScimp in scimpCache)
	{
		if ([cachedScimp.threadID isEqualToString:threadID])
		{
			matchingScimp = cachedScimp;
			break;
		}
	}
	
	return matchingScimp;
}

/**
 * NEVER invoke this method directly!
 * You MUST ALWAYS go thru scimpForRemoteJID:withTransaction:isNew.
**/
- (SCimpWrapper *)__cachedScimpForScimpID:(NSString *)scimpID
{
	// Do NOT modify this method!
	// See existingScimpForScimpID:withTransaction: for proper context.
	
	SCimpWrapper *matchingScimp = nil;
	
	for (SCimpWrapper *cachedScimp in scimpCache)
	{
		if ([cachedScimp.scimpID isEqualToString:scimpID])
		{
			matchingScimp = cachedScimp;
			break;
		}
	}
	
	return matchingScimp;
}

/**
 * NEVER invoke this method directly!
 * You MUST ALWAYS go thru scimpForRemoteJID:withTransaction:isNew.
**/
- (SCimpWrapper *)__restoreScimpForRemoteJID:(XMPPJID *)remoteJID
                             withTransaction:(YapDatabaseReadTransaction *)transaction
                                       error:(SCLError *)errPtr
{
	// Do NOT modify this method!
	// See scimpForRemoteJID:withTransaction:isNew: for proper context.
	
	SCimpWrapper *scimp = nil;
	SCLError err = kSCLError_NoErr;
	
	NSString *scimpID = [SCimpWrapper scimpIDForLocalJID:localJID remoteJID:remoteJID options:XMPPJIDCompareFull];
	SCimpSnapshot *scimpSnapshot = [transaction objectForKey:scimpID inCollection:kSCCollection_STScimpState];
	
	SCKeyContextRef storageKey = self.storageKey;
    if (scimpSnapshot && storageKey)
	{
		SCimpContextRef ctx = kInvalidSCimpContextRef;
		
		err = SCimpDecryptState(storageKey,                 // key
		                (void *)[scimpSnapshot.ctx bytes],  // blob
		                (size_t)[scimpSnapshot.ctx length], // blob length
		                        &ctx);                      // out context
		
		if (err == kSCLError_NoErr)
		{
			scimp = [[SCimpWrapper alloc] initWithSCimpCtx:ctx
			                                conversationID:scimpSnapshot.conversationID
			                                      localJID:localJID
			                                     remoteJID:remoteJID];
			
			scimp.scimpError       = scimpSnapshot.protocolError;
			scimp.isVerified       = scimpSnapshot.isVerified;
			scimp.awaitingReKeying = scimpSnapshot.awaitingReKeying;
		}
		else
		{
			DDLogWarn(@"SCimpDecryptState error [localJID=%@, remoteJID=%@]: %d", localJID, remoteJID, err);
		}
	}
	
	if (errPtr) *errPtr = err;
	return scimp;
}

/**
 * NEVER invoke this method directly!
 * You MUST ALWAYS go thru scimpForThreadID:withTransaction:isNew.
**/
- (SCimpWrapper *)__restoreScimpForThreadID:(NSString *)threadID
                            withTransaction:(YapDatabaseReadTransaction *)transaction
                                      error:(SCLError *)errPtr
{
	// Do NOT modify this method!
	// See scimpForThreadID:withTransaction:isNew: for proper context.
	
	SCimpWrapper *scimp = nil;
	SCLError err = kSCLError_NoErr;
	
	NSString *scimpID = [SCimpWrapper scimpIDForLocalJID:localJID threadID:threadID];
	SCimpSnapshot *scimpSnapshot = [transaction objectForKey:scimpID inCollection:kSCCollection_STScimpState];
	
	SCKeyContextRef storageKey = self.storageKey;
	if (scimpSnapshot && storageKey)
	{
		SCimpContextRef ctx = kInvalidSCimpContextRef;
		
		err = SCimpDecryptState(storageKey,                 // key
		                (void *)[scimpSnapshot.ctx bytes],  // blob
		                (size_t)[scimpSnapshot.ctx length], // blob length
		                        &ctx);                      // out context
		
		if (err == kSCLError_NoErr)
		{
			scimp = [[SCimpWrapper alloc] initWithSCimpCtx:ctx
			                                conversationID:scimpSnapshot.conversationID
			                                      localJID:localJID
			                                      threadID:threadID];
			
			scimp.scimpError       = scimpSnapshot.protocolError;
			scimp.isVerified       = scimpSnapshot.isVerified;
			scimp.awaitingReKeying = scimpSnapshot.awaitingReKeying;
		}
		else
		{
			DDLogWarn(@"SCimpDecryptState error [localJID=%@, threadID=%@]: %d", localJID, threadID, err);
		}
	}
	
	if (errPtr) *errPtr = err;
	return scimp;
}

/**
 * NEVER invoke this method directly!
 * You MUST ALWAYS go thru scimpForRemoteJID:withTransaction:isNew.
**/
- (SCimpWrapper *)__restoreScimpForScimpID:(NSString *)scimpID
                           withTransaction:(YapDatabaseReadTransaction *)transaction
                                     error:(SCLError *)errPtr
{
	// Do NOT modify this method!
	// See existingScimpForScimpID:withTransaction: for proper context.
	
	SCimpWrapper *scimp = nil;
	SCLError err = kSCLError_NoErr;
	
	SCimpSnapshot *scimpSnapshot = [transaction objectForKey:scimpID inCollection:kSCCollection_STScimpState];
	
	SCKeyContextRef storageKey = self.storageKey;
    if (scimpSnapshot && storageKey)
	{
		SCimpContextRef ctx = kInvalidSCimpContextRef;
		
		err = SCimpDecryptState(storageKey,                 // key
		                (void *)[scimpSnapshot.ctx bytes],  // blob
		                (size_t)[scimpSnapshot.ctx length], // blob length
		                        &ctx);                      // out context
		
		if (err == kSCLError_NoErr)
		{
			if (scimpSnapshot.remoteJID)
			{
				scimp = [[SCimpWrapper alloc] initWithSCimpCtx:ctx
				                                conversationID:scimpSnapshot.conversationID
				                                      localJID:scimpSnapshot.localJID
				                                     remoteJID:scimpSnapshot.remoteJID];
			}
			else
			{
				scimp = [[SCimpWrapper alloc] initWithSCimpCtx:ctx
				                                conversationID:scimpSnapshot.conversationID
				                                      localJID:scimpSnapshot.localJID
				                                      threadID:scimpSnapshot.threadID];
			}
			
			scimp.scimpError       = scimpSnapshot.protocolError;
			scimp.isVerified       = scimpSnapshot.isVerified;
			scimp.awaitingReKeying = scimpSnapshot.awaitingReKeying;
		}
		else
		{
			DDLogWarn(@"SCimpDecryptState error [scimpID=%@, localJID=%@]: %d", scimpID, [localJID bare], err);
		}
	}
	
	if (errPtr) *errPtr = err;
	return scimp;
}

- (void)flushScimpCache
{
	DDLogAutoTrace();
	
	// The scimpCache is ONLY safe to access / modify within a database transaction.
	
	[databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		for (SCimpWrapper *scimp in scimpCache)
		{
			SCimpFree(scimp->scimpCtx);
			scimp->scimpCtx = kInvalidSCimpContextRef;
		}
		
		[scimpCache removeAllObjects];
	}];
}

- (void)saveScimp:(SCimpWrapper *)scimp withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	if (scimp == nil) {
		DDLogWarn(@"%@ - scimp parameter is nil !", THIS_METHOD);
		return;
	}
	
	SCKeyContextRef storageKey = self.storageKey;
	if (storageKey == NULL) {
		DDLogWarn(@"%@ - missing storageKey !", THIS_METHOD);
		return;
	}
	
	void *blob = NULL;
	size_t blobLen = 0;
	
	SCLError err = SCimpEncryptState(scimp->scimpCtx, storageKey, &blob, &blobLen);
	if (err == kSCLError_NoErr)
	{
		NSData *ctx = [NSData dataWithBytesNoCopy:blob length:blobLen freeWhenDone:YES];
		SCimpSnapshot *snapshot = [[SCimpSnapshot alloc] initWithSCimpWrapper:scimp ctx:ctx];
		
		DDLogMagenta(@"Saving SCimpSnapshot: scimpID(%@), remoteJID(%@) SCimpMethod(%@), SCimpState(%@)",
					 snapshot.uuid,
					 snapshot.remoteJID,
					 snapshot.protocolMethodString,
					 snapshot.protocolStateString);
		
		[transaction setObject:snapshot forKey:snapshot.uuid inCollection:kSCCollection_STScimpState];
		
		// Add scimpID to conversation (if needed)
		
		STConversation *conversation = [transaction objectForKey:scimp.conversationID inCollection:localUserID];
		if (conversation && ![conversation.scimpStateIDs containsObject:scimp.scimpID])
		{
			conversation = [conversation copy];
			
			NSMutableSet *scimpStateIDs = [conversation.scimpStateIDs mutableCopy];
			if (scimpStateIDs == nil) {
				scimpStateIDs = [NSMutableSet set];
			}
			
			NSString *scimpID = scimp.scimpID;
			if (scimpID) {
				[scimpStateIDs addObject:scimpID];
			}
			
			conversation.scimpStateIDs = scimpStateIDs;
			
			[transaction setObject:conversation
							forKey:conversation.uuid
					  inCollection:conversation.userId];
		}
		else
		{
			// Touch the conversation so various UI components can be updated if needed.
			// E.g. the "yellow dots" button.
			[transaction touchObjectForKey:conversation.uuid inCollection:conversation.userId];
		}
	}
	else
	{
		DDLogError(@"%@ - SCLError: %d", THIS_METHOD, err);
	}
	
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Transaction Support
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)usingTransaction:(YapDatabaseReadWriteTransaction *)transaction pushCompletionBlock:(dispatch_block_t)block
{
	if (block == NULL) return;
	
	NSMutableArray *transactionCompletionBlocks = transaction.completionBlocks;
	if (transactionCompletionBlocks)
	{
		[transactionCompletionBlocks addObject:block];
	}
	else
	{
		[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
			
			// We're using this as a workaround.
			// Basically, the transaction doesn't have a configured completionBlocks setup.
			// So we go into the queue behind the current read-write transaction,
			// and use this completionBlock instead.
			
		} completionBlock:block]; // <- given completionBlock is here
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark SCimp Event Handler
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

SCimpEvent* FindSCimpEvent_First(SCimpResultBlock *results, SCimpEventType type)
{
	SCimpResultBlock *result = results;
	while (result)
	{
		if (result->event.type == type)
		{
			return &(result->event);
		}
		
		result = result->next;
	}
	
	return NULL;
}

SCimpEvent* FindSCimpEvent_First2(SCimpResultBlock *results, SCimpEventType type1, SCimpEventType type2)
{
	SCimpResultBlock *result = results;
	while (result)
	{
		if (result->event.type == type1 || result->event.type == type2)
		{
			return &(result->event);
		}
		
		result = result->next;
	}
	
	return NULL;
}

SCimpEvent* FindSCimpEvent_Last(SCimpResultBlock *results, SCimpEventType type)
{
	SCimpEvent *lastEvent = NULL;
	
	SCimpResultBlock *result = results;
	while (result)
	{
		if (result->event.type == type)
		{
			lastEvent = &(result->event);
		}
		
		result = result->next;
	}
	
	return lastEvent;
}

SCimpEvent* FindSCimpEvent_Last2(SCimpResultBlock *results, SCimpEventType type1, SCimpEventType type2)
{
	SCimpEvent *lastEvent = NULL;
	
	SCimpResultBlock *result = results;
	while (result)
	{
		if (result->event.type == type1 || result->event.type == type2)
		{
			lastEvent = &(result->event);
		}
		
		result = result->next;
	}
	
	return lastEvent;
}

SCimpEvent* FindSCimpEvent_Next(SCimpResultBlock *results, SCimpEventType type, SCimpEvent *prev)
{
	BOOL foundPrev = NO;
	
	SCimpResultBlock *result = results;
	while (result)
	{
		if (result->event.type == type)
		{
			if (foundPrev == NO)
				foundPrev = (&result->event == prev);
			else
				return &(result->event);
		}
		
		result = result->next;
	}
	
	return NULL;
}

SCimpEvent* FindSCimpEvent_Next2(SCimpResultBlock *results, SCimpEventType type1, SCimpEventType type2, SCimpEvent *prev)
{
	BOOL foundPrev = NO;
	
	SCimpResultBlock *result = results;
	while (result)
	{
		if (result->event.type == type1 || result->event.type == type2)
		{
			if (foundPrev == NO)
				foundPrev = (&result->event == prev);
			else
				return &(result->event);
		}
		
		result = result->next;
	}
	
	return NULL;
}

SCLError MessageStreamSCimpEventHandler(SCimpContextRef ctx, SCimpEvent *event, void *userInfo)
{
	__unsafe_unretained MessageStreamUserInfo *msUserInfo = (__bridge MessageStreamUserInfo *)userInfo;
	MessageStream *ms = msUserInfo->ms;
	YapDatabaseReadWriteTransaction *transaction = msUserInfo->transaction;
	
	NSCAssert(ms != nil, @"We forget to setup scimp somewhere....");
	NSCAssert(transaction != nil, @"We forget to setup scimp somewhere....");
	
	SCimpWrapper *scimp = nil;
	if (ctx == ms->pubScimp->scimpCtx)
	{
		scimp = ms->pubScimp;
	}
	else
	{
		for (SCimpWrapper *w in ms->scimpCache)
		{
			if (w->scimpCtx == ctx)
			{
				scimp = w;
				break;
			}
		}
	}
	
	if (scimp == nil)
	{
		DDLogCError(@"%s - Unknown scimp context", __FUNCTION__);
		
		// We don't know of an existing context for this callback.
		return kSCLError_UnknownRequest;
	}
	
	SCLError err = kSCLError_NoErr;
	
	switch (event->type)
	{
		case kSCimpEvent_Warning:
		{
			[ms handleSCimpEvent_Warning:event withSCimp:scimp transaction:transaction];
			break;
		}
		case kSCimpEvent_Error:
		{
			[ms handleSCimpEvent_Error:event withSCimp:scimp transaction:transaction];
			break;
		}
		case kSCimpEvent_Keyed:
		{
			[ms handleSCimpEvent_Keyed:event withSCimp:scimp transaction:transaction];
			break;
		}
		case kSCimpEvent_ReKeying:
		{
			[ms handleSCimpEvent_ReKeying:event withSCimp:scimp transaction:transaction];
			break;
		}
		case kSCimpEvent_SendPacket:
		{
			[ms handleSCimpEvent_SendPacket:event withSCimp:scimp transaction:transaction];
			break;
		}
		case kSCimpEvent_Decrypted:
		{
			[ms handleSCimpEvent_Decrypted:event withSCimp:scimp transaction:transaction];
			break;
		}
		case kSCimpEvent_ClearText:
		{
			[ms handleSCimpEvent_ClearText:event withSCimp:scimp transaction:transaction];
			break;
		}
		case kSCimpEvent_Transition:
		{
			[ms handleSCimpEvent_Transition:event withSCimp:scimp transaction:transaction];
			break;
		}
		case kSCimpEvent_AdviseSaveState:
		{
			[ms handleSCimpEvent_AdviseSaveState:event withSCimp:scimp transaction:transaction];
			break;
		}
		case kSCimpEvent_PubData:
		{
			[ms handleSCimpEvent_PubData:event withSCimp:scimp transaction:transaction];
			break;
		}
		case kSCimpEvent_NeedsPrivKey:
		{
			[ms handleSCimpEvent_NeedsPrivKey:event withSCimp:scimp transaction:transaction];
			break;
		}
		case kSCimpEvent_Shutdown:
		{
			[ms handleSCimpEvent_Shutdown:event withSCimp:scimp transaction:transaction];
			break;
		}
		case kSCimpEvent_LogMsg:
		{
			// Todo: Insert log messages into database (STMessage with special flag)
			break;
		}
		default:
		{
			NSCAssert(NO, @"Unhandled SCimpEvent: %d:", event->type);
			err = kSCLError_LazyProgrammer;
		}
	}
	
	return err;
}

- (void)handleSCimpEvent_Warning:(SCimpEvent *)event
                       withSCimp:(SCimpWrapper *)scimp
                     transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	NSAssert(event && event->type == kSCimpEvent_Warning, @"Oops");
	NSAssert(scimp != nil, @"Oops");
	
	SCLError warning = event->data.warningData.warning;
	DDLogWarn(@"kSCimpEvent_Warning - %d: %@", warning, [SCimpUtilities stringFromSCLError:warning]);
	
	if (scimp == pubScimp)
	{
		// Ignore warning coming from pubScimp->scimpCtx
		return;
	}
	
	scimp.scimpError = warning;
	
	// This is historical (saving the scimp state here).
	// Technically this probably shouldn't be required because the kSCimpEvent_AdviseSaveState should hit.
	// But we should test this, rather than assume it works.
	
	[self saveScimp:scimp withTransaction:transaction];
	
	if (warning == kSCLError_SecretsMismatch)
	{
		// We ignore the SAS warning here.
		// We'll pick it up once the connection is established.
		
		return;
	}
	else if (warning != kSCLError_ProtocolContention &&
	         warning != kSCLError_ProtocolError       )
	{
		NSAssert(NO, @"Unhandled kSCimpEvent_Warning: %d: %@s",
		               warning, [SCimpUtilities stringFromSCLError:warning]);
		return;
	}
	
	// This may be something like kSCLError_ProtocolContention.
	//
	// What we want to do here is refresh the userInfo for the remote user.
	// Here's an example of why:
	//
	// - We sent a PK_Commit message to the remote user.
	// - We either had an outdated public key for them, or they received the message after signing in on a new device.
	// - Either way, they could not decrypt the message, and fellback to scimp1 keying.
	// - After that eventually completes, they're going to finally send us a request_resend siren.
	// - When we receive this, we'll need to be able to verify the signature in order to
	//   accomodate an automatic resend of the message.
	// - Which we won't be able to do if we still have outdated public key(s) for the user.
	
	STConversation *conversation = [transaction objectForKey:scimp.conversationID inCollection:localUserID];
	if (conversation)
	{
		conversation = [conversation copy];
		conversation.lastUpdated = [NSDate date];
		
		[transaction setObject:conversation
		                forKey:conversation.uuid
		          inCollection:localUserID];
	}
	
	STUser *user = [STDatabaseManager findUserWithJID:scimp.remoteJID transaction:transaction];
	if (user)
	{
		[[STUserManager sharedInstance] refreshWebInfoForUser:user completionBlock:NULL];
	}
}

- (void)handleSCimpEvent_Error:(SCimpEvent *)event
                     withSCimp:(SCimpWrapper *)scimp
                   transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	NSAssert(event && event->type == kSCimpEvent_Error, @"Oops");
	NSAssert(scimp != nil, @"Oops");
	
	SCLError error = event->data.errorData.error;
	DDLogError(@"kSCimpEvent_Error - %d:  %@", error, [SCimpUtilities stringFromSCLError:error]);
	
	if (scimp == pubScimp)
	{
		// Ignore error coming from pubScimp->scimpCtx
		return;
	}
	
	scimp.scimpError = error;
	
	// This is historical (saving the scimp state here).
	// Technically this probably shouldn't be required because kSCimpEvent_AdviseSaveState should hit afterwards
	// But we should test this, rather than assume it works.
	
	[self saveScimp:scimp withTransaction:transaction];
	
	XMPPMessage *message = (__bridge XMPPMessage *)event->userRef;
	
	if ((error == kSCLError_PubPrivKeyNotFound || error == kSCLError_KeyNotFound) && message)
	{
		// Check message for id.
		// We could not decrypt this message, and might send a "resend request".
		
		NSString *messageID = [message elementID];
		
		DDLogVerbose(@"COULD NOT DECRYPT MESSAGE ID: %@", messageID);
        
        if (message.threadID)
		{
			// For group conversations, we have to pester for the sym key.
            
            NSString *conversationID = [self conversationIDForThreadID:message.threadID];
			
			Siren *siren = [Siren new];
			siren.requestResend = messageID;
			siren.requestThreadKey = message.threadID;
			
			[self sendSiren:siren forConversationID:conversationID
			                               withPush:NO
			                                  badge:NO
			                          createMessage:NO
			                             completion:NULL];
		}
        else
        {
        	// For P2P we will set a few flags to execute the following:
			//
			// - Refresh the webinfo for the user
			// - Rekey immediately after that completes
			//
			// We do this so that we can hopefully rekey using scimp v2 (pub key)
			
			[self rekeyScimpAfterRefreshingUserWebInfo:scimp withTransaction:transaction];
			
			// Send a resend request siren packet to ask the other side to resend its info.
			//
			// Important: The conversation may or may not exist at this point.
			// So we can NOT use sendSeire:forConversationID:.
			// We must instead use a method that will create the conversation for us automatically, if needed.

			if (messageID)
			{
				Siren *siren = [Siren new];
				siren.requestResend = messageID;
				
				[self sendSiren:siren toJID:scimp.remoteJID withPush:NO badge:NO createMessage:NO completion:NULL];
			}
		}
	}
}

/**
 * Invoked when scimpCtx.isReady becomes true:
 * 
 * - we started a new publicKey based context
 * - we finished the DH handshake
 * - we started a new symmetricKey based context
**/
- (void)handleSCimpEvent_Keyed:(SCimpEvent *)event
                     withSCimp:(SCimpWrapper *)scimp
                   transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	NSAssert(event && event->type == kSCimpEvent_Keyed, @"Oops");
	NSAssert(scimp != nil, @"Oops");
	
	NSString *conversationID = scimp.conversationID;
	BOOL isMulticast = ([scimp.threadID length] > 0) ? YES : NO;
	
	// STEP 1 of 3
	//
	// Update scimp.
	
	scimp.scimpError = kSCLError_NoErr;
	
	DDLogVerbose(@"SCimp keyed: %@", [scimp description]);
	
	SCimpMethod scimpMethod = scimp.protocolMethod;
	SCimpState  scimpState  = scimp.protocolState;
	
	BOOL hasSharedSecret     = scimp.hasSharedSecret;
	BOOL sharedSecretMatches = scimp.sharedSecretMatches;
	BOOL isInitiator         = scimp.isInitiator;
	
	if (!isMulticast)
	{
		if (!(hasSharedSecret && sharedSecretMatches))
		{
			scimp.isVerified = NO;
		}
	}
    
	if (scimpMethod == kSCimpMethod_DH || scimpMethod == kSCimpMethod_DHv2)
	{
		if (!hasSharedSecret)
		{
			// Always accept when we have no shared secret.
			//
			// What does this mean?
			// When would we not have a shared secret?
			
			SCimpAcceptSecret(scimp->scimpCtx);
		}
		else if (hasSharedSecret && !sharedSecretMatches)
		{
			// If we find that the cached shared secret doesn't match (what the other side thinks it is)
			// then we should inform the user that they should verify the Short Authentication String (SAS).
			//
			// This could be in the form of 4 nato words, 5 hex characters or 4 letters.
			// It depends on who initiated the call.
			
			SCimpAcceptSecret(scimp->scimpCtx);
		}
	}
	
	[self saveScimp:scimp withTransaction:transaction];
	
#if INJECT_STATUS_MESSAGES
	
	// STEP 2 of 3:
	//
	// Inject status message (if needed)
	//
	
	if (scimpKeyInfo)
	{
		STMessage *infoMessage = nil;
		NSDictionary *statusMessage = @{ @"keyInfo": scimpKeyInfo };
		
		if (isMulticast)
		{
			STSymmetricKey *mcKey = [transaction objectForKey:conversation.keyLocator
			                                     inCollection:kSCCollection_STSymmetricKeys];
			
			NSDictionary *keyDict = mcKey.keyDict;
			NSString *creator = [keyDict objectForKey:@"creator"];
			
			XMPPJID *creatorJID = [XMPPJID jidWithString:creator];
			
			BOOL isOutgoing = [creatorJID isEqualToJID:conversation.localJid options:XMPPJIDCompareBare];
			
			XMPPJID *from = isOutgoing ? [localJID bareJID] : creatorJID;
			XMPPJID *to   = isOutgoing ? creatorJID : [localJID bareJID];
			
			infoMessage = [[STMessage alloc] initWithUUID:[XMPPStream generateUUID]
			                               conversationId:conversation.uuid
			                                       userId:localUserID
			                                         from:from
			                                           to:to
			                                    withSiren:NULL
			                                    timestamp:now
			                                   isOutgoing:isOutgoing];
			
			infoMessage.isVerified = YES;
			
			infoMessage.statusMessage = statusMessage;
			infoMessage.isRead = YES;
			infoMessage.sendDate = now;
		}
		else if (scimpMethod == kSCimpMethod_DH    ||
		         scimpMethod == kSCimpMethod_DHv2  ||
		         scimpMethod == kSCimpMethod_PubKey )
		{
			BOOL isOutgoing = [[info objectForKey:kSCimpInfoIsInitiator] boolValue];
			
			XMPPJID *from = isOutgoing ? [localJID bareJID] : scimpStateObj.remoteJID;
			XMPPJID *to   = isOutgoing ? scimpStateObj.remoteJID : [localJID bareJID];
			
			infoMessage = [[STMessage alloc] initWithUUID:[XMPPStream generateUUID]
			                               conversationId:conversation.uuid
			                                       userId:localUserID
			                                         from:from
			                                           to:to
			                                    withSiren:NULL
			                                    timestamp:now
			                                   isOutgoing:isOutgoing];
			
			infoMessage.isVerified = YES;
			
			infoMessage.statusMessage = statusMessage;
			infoMessage.isRead = YES;
			infoMessage.sendDate = now;
           }
		
		if (infoMessage)
		{
			[transaction setObject:infoMessage
			                forKey:infoMessage.uuid
			          inCollection:infoMessage.conversationId];
		}
	}
	
#endif
		
	// STEP 3 of 3
	//
	// Resend messages that were filtered/queued while the secure context was being negotiated.
	
	STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
	
	NSOrderedSet *elementIdQueue = [[filteredMessageIds objectForKey:conversationID] copy];
	[filteredMessageIds removeObjectForKey:conversationID];
	
	if (transaction.requiredConnectionID == nil)
	{
		NSUInteger connectionID;
		[self getMessageStreamState:NULL errorString:NULL connectionID:&connectionID];
		
		transaction.requiredConnectionID = @(connectionID);
	}
	
	// IMPORTANT:
	// - FIRST we send keying messages.
	// - THEN we send other queued stanzas.
	
	for (NSString *elementID in elementIdQueue)
	{
		__block STXMPPElement *queuedElement = nil;
		
		[transaction enumerateCollectionsForKey:elementID usingBlock:^(NSString *collection, BOOL *stop) {
			
			id anObject = [transaction objectForKey:elementID inCollection:collection];
			if ([anObject isKindOfClass:[STXMPPElement class]])
			{
				queuedElement = (STXMPPElement *)anObject;
				*stop = YES;
			}
		}];
		
		if (queuedElement && queuedElement.isKeyingMessage)
		{
			XMPPElement *xmppStanza = queuedElement.element;
			
			DDLogVerbose(@"Re-sending filtered element (keyingMessage): %@", queuedElement.uuid);
			[self trySendXmppStanza:xmppStanza withTransaction:transaction];
		}
	}
	
	for (NSString *elementID in elementIdQueue)
	{
		__block STXMPPElement *queuedElement = nil;
		__block STMessage *queuedMessage = nil;
		
		[transaction enumerateCollectionsForKey:elementID usingBlock:^(NSString *collection, BOOL *stop) {
			
			id anObject = [transaction objectForKey:elementID inCollection:collection];
			if ([anObject isKindOfClass:[STMessage class]])
			{
				queuedMessage = (STMessage *)anObject;
				*stop = YES;
			}
			else if ([anObject isKindOfClass:[STXMPPElement class]])
			{
				queuedElement = (STXMPPElement *)anObject;
				*stop = YES;
			}
		}];
		
		if (queuedElement && !queuedElement.isKeyingMessage)
		{
			XMPPElement *xmppStanza = queuedElement.element;
			
			DDLogVerbose(@"Re-sending filtered element: %@", queuedElement.uuid);
			[self trySendXmppStanza:xmppStanza withTransaction:transaction];
		}
		else if (queuedMessage)
		{
			XMPPMessage *xmppMessage = [self xmppMessageForMessage:queuedMessage withConversation:conversation];
			
			DDLogVerbose(@"Re-sending filtered message: %@", queuedMessage.uuid);
			[self trySendXmppStanza:xmppMessage withTransaction:transaction];
		}
	}
	
	
	[self usingTransaction:transaction pushCompletionBlock:^{
		
		// Send a ping to get the other user's capabilities.
		
		BOOL shouldSendPing = NO;
		
		if (capabilitiesDict)
		{
			if (isInitiator && scimpMethod == kSCimpMethod_PubKey && scimpState == kSCimpState_PKCommit)
			{
				// SCimp v2 - the person starting the PubKey keying process
				shouldSendPing = YES;
			}
			else if (!isInitiator && scimpMethod == kSCimpMethod_DH && scimpState == kSCimpState_Ready)
			{
				// SCimp v1 - the person who first hits the Ready state
				shouldSendPing = YES;
			}
		}
		
		if (shouldSendPing)
		{
			NSData *capData = ([NSJSONSerialization  isValidJSONObject: capabilitiesDict] ?
			                   [NSJSONSerialization dataWithJSONObject: capabilitiesDict options: 0 error: nil] :
			                   nil);
            
			Siren *capSiren = [Siren new];
			capSiren.ping = kPingRequest;
			capSiren.capabilities = [[NSString alloc] initWithData:capData encoding:NSASCIIStringEncoding];

			[self sendSiren:capSiren forConversationID:conversationID
			                                  withPush:NO
			                                     badge:NO
			                             createMessage:NO
			                                completion:NULL];
		}

	}];
}

- (void)handleSCimpEvent_ReKeying:(SCimpEvent *)event
                        withSCimp:(SCimpWrapper *)scimp
                      transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	NSAssert(event && event->type == kSCimpEvent_ReKeying, @"Oops");
	
	DDLogVerbose(@"kSCimpEvent_ReKeying");
	
	// When is this invoked?
	// Under what circumstances?
	// Do we need to do anything here?
}

- (void)handleSCimpEvent_SendPacket:(SCimpEvent *)event
                          withSCimp:(SCimpWrapper *)scimp
                        transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	NSAssert(event && event->type == kSCimpEvent_SendPacket, @"Oops");
	
	DDLogVerbose(@"kSCimpEvent_SendPacket");
	
	// SCimp is handing us encrypted data to send.
	// This may be:
	// - data we asked it to encrypt (for an outgoing message)
	// - handshake related information
	
	NSString *scimpOut = [[NSString alloc] initWithBytes:event->data.sendData.data
	                                              length:event->data.sendData.length
	                                            encoding:NSUTF8StringEncoding];
	
	BOOL shouldPush = event->data.sendData.shouldPush;
	
	// if the kSCimpEvent_SendPacket event has a userRef, it means that this was the result
	//  of calling  SCimpSendMsg and not a scimp doing protocol keying stuff.
	
	XMPPMessage *message = (__bridge XMPPMessage *)event->userRef;
	if (message)
	{
		DDLogInfo(@"%@ - injecting encrypted info into message", THIS_METHOD);
		
		if (event->data.sendData.isPKdata)
		{
			// Add the encrypted body.
			// Result should look like this:
			//
			// <message to=remoteJid">
			//   <body></body>
			//   <x xmlns="http://silentcircle.com/protocol/scimp#public-key>scimp-encrypted-data</x>
			// </message>
			
			NSXMLElement *x = [message elementForName:@"x" xmlns:kSCPublicKeyNameSpace];
			
			if (!x)
			{
				x = [NSXMLElement elementWithName:@"x" xmlns:kSCPublicKeyNameSpace];
				[message addChild:x];
			}
			
			if (!shouldPush)
			{
				[x addAttributeWithName:kXMPPNotifiable stringValue:@"false"];
				[x addAttributeWithName:kXMPPBadge      stringValue:@"false"];
			}
			
			NSString *messageID = [message elementID];
			if (!messageID)
				[message addAttributeWithName:kXMPPID stringValue:[XMPPStream generateUUID]];
			
			[x setStringValue:scimpOut];
		}
		else
		{
			// Add the encrypted body.
			// Result should look like this:
			//
			// <message to=remoteJid">
			//   <body></body>
			//   <x xmlns="http://silentcircle.com">scimp-encrypted-data</x>
			// </message>
			
			NSXMLElement *x = [message elementForName:@"x" xmlns:kSCNameSpace];
			
			if (!x)
			{
				x = [NSXMLElement elementWithName:@"x" xmlns:kSCNameSpace];
				[message addChild:x];
			}
			
			if (!shouldPush)
			{
				[x addAttributeWithName:kXMPPNotifiable stringValue:@"false"];
				[x addAttributeWithName:kXMPPBadge      stringValue:@"false"];
			}
			
			[x setStringValue:scimpOut];
		}
	}
	else
	{
		NSString *uuid = [[NSUUID UUID] UUIDString];
		
		DDLogInfo(@"%@ - sending keying message with id: %@", THIS_METHOD, uuid);
		
		// SCimp is asking us to send a keying message.
		//
		// <message to='remote@domain.com' type='chat'>
		//   <body>
		//     robbie has requested a private conversation protected by Silent Circle Instant Message Protocol.
		//     See http://silentcircle.com for more information.
		//   </body>
		//   <x xmlns="http://silentcircle.com">scimp-encoded-data</x>
		// </message>
		
		message = [XMPPMessage message];
		[message addAttributeWithName:@"to"   stringValue:[scimp.remoteJID bare]];
		[message addAttributeWithName:@"type" stringValue:@"chat"];
		[message addAttributeWithName:@"id"   stringValue:uuid];
		
		NSXMLElement *bodyElement = [NSXMLElement elementWithName:@"body"];
		[message addChild:bodyElement];
		[bodyElement setStringValue:[NSString stringWithFormat:kSCPPBodyTextFormat, [localJID bare]]];
		
		NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:kSCNameSpace];
		[message addChild:x];
		[x setStringValue:scimpOut];
		
		if (!shouldPush)
		{
			[x addAttributeWithName:kXMPPNotifiable stringValue:@"false"];
			[x addAttributeWithName:kXMPPBadge      stringValue:@"false"];
		}
		
		STXMPPElement *element = [[STXMPPElement alloc] initWithKeyingMessage:message
		                                                          localUserID:localUserID
		                                                       conversationID:scimp.conversationID];
		
		[transaction setObject:element
		                forKey:element.uuid
		          inCollection:element.conversationID];
	}
	
	[self __sendMessageIfPossibleAndAllowed:message withTransaction:transaction];
}

- (void)handleSCimpEvent_Decrypted:(SCimpEvent *)event
                         withSCimp:(SCimpWrapper *)scimp
                       transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	NSAssert(event && event->type == kSCimpEvent_Decrypted, @"Oops");
	
	DDLogVerbose(@"kSCimpEvent_Decrypted");
	
	XMPPMessage *message = (__bridge XMPPMessage *)event->userRef;
	NSAssert(message != nil, @"Oops");

	NSString *decryptedBody = [[NSString alloc] initWithBytes:event->data.decryptData.data
	                                                   length:event->data.decryptData.length
	                                                 encoding:NSUTF8StringEncoding];
	
	NSXMLElement *sirenElement = [NSXMLElement elementWithName:kSCPPSiren xmlns:kSCNameSpace];
	[sirenElement setStringValue:decryptedBody];
	[message addChild:sirenElement];
}

/**
 *
**/
- (void)handleSCimpEvent_ClearText:(SCimpEvent *)event
                         withSCimp:(SCimpWrapper *)scimp
                       transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	NSAssert(event && event->type == kSCimpEvent_ClearText, @"Oops");
	
	DDLogError(@"kSCimpEvent_ClearText - this should never happen !!!");
}

/**
 *
**/
- (void)handleSCimpEvent_Transition:(SCimpEvent *)event
                          withSCimp:(SCimpWrapper *)scimp
                        transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	NSAssert(event && event->type == kSCimpEvent_Transition, @"Oops");
	
	DDLogVerbose(@"kSCimpEvent_Transition");
	
	DDLogPurple(@"SCimpStateChange: RemoteJID(%@), SCimpMethod(%@), SCimpState(%@)",
	           scimp.remoteJID, scimp.protocolMethodString, scimp.protocolStateString);
	
#if INJECT_STATUS_MESSAGES
	
	// Filter out the states we're not interested in.
	
	SCimpMethod protocolMethod = scimp.protocolMethod;
	SCimpState protocolState = scimp.protocolState;
	
	BOOL ignore = YES;
	if (protocolMethod == kSCimpMethod_PubKey)
	{
		if (protocolState == kSCimpState_PKCommit)
		{
			ignore = NO;
		}
	}
	else if (protocolMethod == kSCimpMethod_DH)
	{
		if (protocolState == kSCimpState_Commit ||
		    protocolState == kSCimpState_DH1    ||
			protocolState == kSCimpState_DH2     )
		{
			ignore = NO;
		}
	}
	
	if (ignore) return;
	
	NSString *conversationID = scimp->conversationID;
	
	STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
	if (conversation)
	{
		NSDate *now = [NSDate date];
		
		BOOL isOutgoing = (protocolState == kSCimpState_DH1) ? NO : YES;
		XMPPJID *remoteJID = scimp->remoteJid;
		
		STMessage *message = [[STMessage alloc] initWithUUID:[XMPPStream generateUUID]
		                                      conversationId:conversation.uuid
		                                              userId:localUserID
		                                                from:(isOutgoing ? [localJID bareJID] : remoteJID)
		                                                  to:(isOutgoing ? remoteJID : [localJID bareJID])
		                                           withSiren:NULL
		                                           timestamp:now
		                                          isOutgoing:isOutgoing];
		
		message.isVerified = YES;
		message.statusMessage = @{ @"keyState": @(protocolState)};
		message.isRead = YES;
		message.sendDate = now;
		
		[transaction setObject:message
		                forKey:message.uuid
		          inCollection:message.conversationId];
	}
	
#endif
}

/**
 * Invoked anytime the scimpCtx has changed its state in someway.
 * This is a notification to us that we need to save a snapshot of the scimp context to the database.
**/
- (void)handleSCimpEvent_AdviseSaveState:(SCimpEvent *)event
                               withSCimp:(SCimpWrapper *)scimp
                             transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	NSAssert(event && event->type == kSCimpEvent_AdviseSaveState, @"Oops");
	
	DDLogVerbose(@"kSCimpEvent_AdviseSaveState");
	
	if (scimp)
	{
		[self saveScimp:scimp withTransaction:transaction];
	}
}

/**
 *
**/
- (void)handleSCimpEvent_PubData:(SCimpEvent *)event
                       withSCimp:(SCimpWrapper *)scimp
                     transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	NSAssert(event && event->type == kSCimpEvent_PubData, @"Oops");
	
	DDLogVerbose(@"kSCimpEvent_PubData");
	
	XMPPMessage *message = (__bridge XMPPMessage *)event->userRef;
	NSAssert(message != nil, @"Oops");
	
	NSString *decryptedBody = [[NSString alloc] initWithBytes:event->data.pubData.data
	                                               length:event->data.pubData.length
	                                             encoding:NSUTF8StringEncoding];
	
	// <message type='chat' to='jid' id='uuid'>
	//   <pubSiren xmlns='http://silentcircle.com'>siren_as_json</pubSiren>
	// </message>
	
	NSXMLElement *pubSirenElement = [NSXMLElement elementWithName:kSCPPPubSiren xmlns:kSCNameSpace];
	[pubSirenElement setStringValue:decryptedBody];
	[message addChild:pubSirenElement];
}

/**
 * Invoked when scimpCtx needs a private key, indicated by a specific key locator.
 * We need to fetch the private key from the database, unlock it, and insert it into the given event data reference.
**/
- (void)handleSCimpEvent_NeedsPrivKey:(SCimpEvent *)event
                            withSCimp:(SCimpWrapper *)scimp
                          transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	NSAssert(event && event->type == kSCimpEvent_NeedsPrivKey, @"Oops");
	
	DDLogVerbose(@"kSCimpEvent_NeedsPrivKey");
	
	// Put the private key into this thing:
	SCimpEventNeedsPrivKeyData *d = &event->data.needsKeyData;
	
	// It's better for us to not specify the public key ahead of time and allow the remote
	// to ask us for the public key they want to start a conversation with.
	
	NSString *locator = [NSString stringWithUTF8String:d->locator];
	
	STPublicKey *publicKey = [transaction objectForKey:locator inCollection:kSCCollection_STPublicKeys];
	if (publicKey && publicKey.isPrivateKey)
	{
		SCKeyContextRef privKey = kInvalidSCKeyContextRef;
		SCLError err = SCKey_Deserialize(publicKey.keyJSON, &privKey);
		
		if ((err == kSCLError_NoErr) && SCKeyContextRefIsValid(privKey))
		{
			// Private key should be locked by storage Key
			
			bool isLocked = true;
			SCKeyIsLocked(privKey, &isLocked);
			
			if (isLocked)
			{
				SCKeyContextRef storageKey = self.storageKey;
				err = SCKeyUnlockWithSCKey(privKey, storageKey);
				
				if (err != kSCLError_NoErr)
				{
					DDLogError(@"SCKeyUnlock error = %d", err);
				}
			}
			
			if (err == kSCLError_NoErr)
			{
				// Hand responsibility for privKey to library.
				
				*(d->privKey) = privKey;
			}
			
			if (!SCKeyContextRefIsValid(*(d->privKey)))
			{
				DDLogError(@"%@: kSCimpEvent_NeedsPrivKey : %s\n", THIS_METHOD, d->locator);
			}
		}
		
		// Important: Do NOT free the privKey !!
		// We handed it over to sccrypto, who is now responsible for it !!
	//
	//	if (SCKeyContextRefIsValid(privKey))
	//	{
	//		SCKeyFree(privKey);
	//		privKey = kInvalidSCKeyContextRef;
	//	}
	}
	
	// Note: This method used to return an error back via the SCimpEventHandler (if an error occurred).
	// I'm not sure if this is a requirement or not.
	// If so we can change all these handleSCimpEvent method to return an SCLError...
}

- (void)handleSCimpEvent_Shutdown:(SCimpEvent *)event
                        withSCimp:(SCimpWrapper *)scimp
                      transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	NSAssert(event && event->type == kSCimpEvent_Shutdown, @"Oops");
	
	DDLogVerbose(@"kSCimpEvent_Shutdown");
	
	// This is called if we invoke SCimpResetKeys()
	//
	// It means any data/state within the scimpCtx was erased,
	// and the scimpCtx was reset (same state as SCimpNew).
	
	if (scimp)
	{
		// This is historical (saving the scimp state here).
		// Technically this probably shouldn't be required because the kSCimpEvent_AdviseSaveState should hit.
		// But we should test this, rather than assume it works.
		
		[self saveScimp:scimp withTransaction:transaction];
	}
}

- (void)processSCimpResults:(SCimpResultBlock *)results
                  withSCimp:(SCimpWrapper *)scimp
                transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	NSParameterAssert(scimp != nil);
	NSParameterAssert(transaction != nil);
	
	#if DEBUG
	SCimpResultBlock *result = results;
	while (result)
	{
		DDLogPurple(@"result->event.type = %@", [SCimpUtilities stringFromSCimpEventType:result->event.type]);
		result = result->next;
	}
	#endif
	
	// 1. kSCimpEvent_Transition
	//
	// Always process this event first.
	// Only process the last transition in the result list.
	
	SCimpEvent *transitionEvent = FindSCimpEvent_Last(results, kSCimpEvent_Transition);
	if (transitionEvent)
	{
		[self handleSCimpEvent_Transition:transitionEvent withSCimp:scimp transaction:transaction];
	}
	
	// 2. kSCimpEvent_SendPacket
	//
	// Always process this event before kSCimpEventKeyed.
	// Process each
	
	SCimpEvent *sendPacketEvent = FindSCimpEvent_First(results, kSCimpEvent_SendPacket);
	while (sendPacketEvent)
	{
		[self handleSCimpEvent_SendPacket:sendPacketEvent withSCimp:scimp transaction:transaction];
		
		sendPacketEvent = FindSCimpEvent_Next(results, kSCimpEvent_SendPacket, sendPacketEvent);
	}
	
	// 3. kSCimpEvent_Decrypted &&
	//    kSCimpEvent_PubData
	//
	// Always process this event before kSCimpEventKeyed.
	// Process every event in the order they appear in the result list.
	//
	// (kSCimpEvent_PubData just means we decrypted data that was encrypted using our public key.)
	
	SCimpEvent *decryptedEvent = FindSCimpEvent_First2(results, kSCimpEvent_Decrypted, kSCimpEvent_PubData);
	while (decryptedEvent)
	{
		if (decryptedEvent->type == kSCimpEvent_Decrypted)
			[self handleSCimpEvent_Decrypted:decryptedEvent withSCimp:scimp transaction:transaction];
		else
			[self handleSCimpEvent_PubData:decryptedEvent withSCimp:scimp transaction:transaction];
		
		decryptedEvent = FindSCimpEvent_Next2(results, kSCimpEvent_Decrypted, kSCimpEvent_PubData, decryptedEvent);
	}
	
	// 4. kSCimpEvent_LogMsg
	//
	// Always process this event before kSCimpEventKeyed.
	// Process every event in the order they appear in the result list.
	
	// 5. kSCimpEvent_Warning &&
	//    kSCimpEvent_Error
	//
	// Process every event in the order they appear in the result list.
	
	SCimpEvent *warningErrorEvent = FindSCimpEvent_First2(results, kSCimpEvent_Warning, kSCimpEvent_Error);
	if (warningErrorEvent)
	{
		if (warningErrorEvent->type == kSCimpEvent_Warning)
			[self handleSCimpEvent_Warning:warningErrorEvent withSCimp:scimp transaction:transaction];
		else
			[self handleSCimpEvent_Error:warningErrorEvent withSCimp:scimp transaction:transaction];
		
		warningErrorEvent = FindSCimpEvent_Next2(results, kSCimpEvent_Warning, kSCimpEvent_Error, warningErrorEvent);
	}
		
	// 6.kSCimpEvent_Keyed
	//
	// Always process this event second to last.
	// Only process one in the result list.
	
	SCimpEvent *keyedEvent = FindSCimpEvent_Last(results, kSCimpEvent_Keyed);
	if (keyedEvent)
	{
		[self handleSCimpEvent_Keyed:keyedEvent withSCimp:scimp transaction:transaction];
	}
	
	// 7. kSCimpEvent_AdviseSaveState &&
	//    kSCimpEvent_Shutdown
	//
	// Always process this event last.
	// We only need to process one in the result list.
	//
	// (Both events are handled the same way - we simply save the scimp state.)
	
	SCimpEvent *saveEvent = FindSCimpEvent_Last2(results, kSCimpEvent_AdviseSaveState, kSCimpEvent_Shutdown);
	if (saveEvent)
	{
		if (saveEvent->type == kSCimpEvent_AdviseSaveState)
			[self handleSCimpEvent_AdviseSaveState:saveEvent withSCimp:scimp transaction:transaction];
		else
			[self handleSCimpEvent_Shutdown:saveEvent withSCimp:scimp transaction:transaction];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Processing - Outgoing
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method MUST be used to send all XMPP elements.
 * 
 * It is required to be invoked from within [database asyncReadWriteTransaction:^{ here }];
**/
- (BOOL)trySendXmppStanza:(XMPPElement *)stanza
          withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	NSAssert(transaction != nil, @"This is REQUIRED in order to guarantee in-order delivery.");
	
	// Check to see if we can use the xmppStream right now
	
	if (![self __canSendXmppStanzaWithTransaction:transaction])
	{
		return NO;
	}
	
	// Try to encrypt the outgoing message
	
	return [self __encryptAndSendXmppStanza:stanza withTransaction:transaction];
}

- (BOOL)__canSendXmppStanzaWithTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	// IMPORTANT: Order matters.
	//
	// We MUST check the messageStreamState BEFORE we check hasPendingQueuedElements.
	// @see xmppStreamDidAuthenticate:
	
	// First check the stream state
	
	MessageStream_State state;
	NSUInteger connectionID;
	[self getMessageStreamState:&state errorString:NULL connectionID:&connectionID];
	
	if (transaction.isReKeying)
	{
		// We can ignore the state for now.
		// During re-keying, we need to go through the encryption process to update the scimp state.
	}
	else if (state != MessageStream_State_Connected)
	{
		DDLogTrace(@"%@ = NO (not connected)", THIS_METHOD);
		return NO;
	}
	
	NSNumber *requiredConnectionID = transaction.requiredConnectionID;
	if (requiredConnectionID)
	{
		if (connectionID != [requiredConnectionID unsignedIntegerValue])
		{
			DDLogTrace(@"%@ = NO (old connectionID)", THIS_METHOD);
			return NO;
		}
	}
	
	// Then check to see if there's anything still queued up for the user...
	
	if (transaction.isSendQueuedItemsLoop)
	{
		// We can ignore self.hasPendingQueuedElements
		// as we're currently processing the pendingQueuedElements.
	}
	else if (transaction.isReKeying)
	{
		// We can ignore self.hasPendingQueuedElements for now.
		// During re-keying, we need to go through the encryption process to update the scimp state.
	}
	else
	{
		if (self.hasPendingQueuedKeyingMessages || self.hasPendingQueuedDataStanzas)
		{
			DDLogTrace(@"%@ = NO (hasPendingQueuedKeyingMessages || hasPendingQueuedDataStanzas)", THIS_METHOD);
			return NO;
		}
	}
	
	// Otherwise we're good to continue.
	
	if (requiredConnectionID == nil) {
		transaction.requiredConnectionID = @(connectionID);
	}
	
	DDLogTrace(@"%@ = YES", THIS_METHOD);
	return YES;
}

/**
 * Don't call this method directly
 *  (unless your name is sendQueuedItemsLoop:::)
**/
- (BOOL)__encryptAndSendXmppStanza:(XMPPElement *)stanza withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	BOOL didEncryptAndSend;
	
	if ([stanza isKindOfClass:[XMPPMessage class]])
	{
		__unsafe_unretained XMPPMessage *message = (XMPPMessage *)stanza;
		
		didEncryptAndSend = [self __encryptAndSendMessage:message withTransaction:transaction];
	}
	else
	{
		// Stanza is IQ or Presence.
		// Nothing to encrypt.
		//
		// So just send as is.
		
		[xmppStream sendElement:stanza];
		didEncryptAndSend = YES;
	}
	
	if (!didEncryptAndSend)
	{
		[self didFilterOutgoingMessage:(XMPPMessage *)stanza];
	}
	
	return didEncryptAndSend;
}

- (BOOL)__encryptAndSendMessage:(XMPPMessage *)message withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	NSAssert(transaction != nil, @"This is REQUIRED in order to guarantee in-order delivery.");
	
	BOOL didEncryptAndSendMessage = YES;
	
	if ([message elementForName:kSCPPPubSiren])
	{
		// Encrypt the outgoing message using the recipient's public key.
		
		XMPPJID *remoteJID = [message to];
		if (remoteJID == nil)
		{
			// If there is no explicit 'to' attribute,
			// then the xmpp stanza is implicitly being sent to the server.
			//
			// The XMPPJID of the server is simply the domain (no user or resource)
			
			remoteJID = [localJID domainJID];
		}
		
		STPublicKey *pubKey = [self publicKeyForRemoteJID:remoteJID withTransaction:transaction];
		if (pubKey)
		{
			SCLError err = [self __encryptAndSendMessage:message withPubKey:pubKey transaction:transaction];
			if (err != kSCLError_NoErr)
			{
				didEncryptAndSendMessage = NO;
			}
		}
		else
		{
			didEncryptAndSendMessage = NO;
		}
		
	}
	else if ([message elementForName:kSCPPSiren])
	{
		if ([message isMulticast]) // Group message
		{
			NSString *threadID = [message threadID];
			
			BOOL isNewScimp = NO;
			SCimpWrapper *scimp = [self scimpForThreadID:threadID withTransaction:transaction isNew:&isNewScimp];
			
			if (scimp == nil)
			{
				// Some error occurred while creating a scimp context.
				// The error was logged in scimpForThread.
				// But since this message is expected to be encrypted,
				// it's better to drop it than send it in plain text.
				
				didEncryptAndSendMessage = NO;
			}
			else
			{
				SCLError err = [self __encryptAndSendMessage:message withScimp:scimp transaction:transaction];
				if (err != kSCLError_NoErr)
				{
					didEncryptAndSendMessage = NO;
				}
			}
			
		}
		else // P2P message
		{
			// We need to get the most recent remoteFullJID that we've communicated with.
			// This is stored in the STConversation.remoteJid property.
			//
			// We need this in order to properly fetch the most recently used SCimpWrapper.
			
			XMPPJID *remoteBareJID = [message to];
			if (remoteBareJID == nil)
			{
				// If there is no explicit 'to' attribute,
				// then the xmpp stanza is implicitly being sent to the server.
				//
				// The XMPPJID of the server is simply the domain (no user or resource)
				
				remoteBareJID = [localJID domainJID];
			}
			
			XMPPJID *remoteFullJID = nil;
			
			NSString *conversationID = [self conversationIDForRemoteJid:remoteBareJID];
			STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
			if (conversation) {
				remoteFullJID = conversation.remoteJid;
			}
			
			BOOL isNewScimp = NO;
			SCimpWrapper *scimp = nil;
			
			scimp = [self scimpForRemoteJID:(remoteFullJID ?: remoteBareJID)
			                withTransaction:transaction
			                     isIncoming:NO
			                          isNew:&isNewScimp];
			
			if (scimp == nil)
			{
				// Some error occurred while creating a scimp context.
				// The error was logged in scimpForThread.
				// But since this message is expected to be encrypted,
				// it's better to drop it than send it in plain text.
				
				didEncryptAndSendMessage = NO;
			}
			else if (isNewScimp || scimp->temp_forceReKey)
			{
				// We need to initiate keying procedure.
				
				scimp->temp_forceReKey = NO;
				
				BOOL didPkStart = NO;
				
				STPublicKey *pubKey = [self publicKeyForRemoteJID:remoteBareJID withTransaction:transaction];
				if (pubKey)
				{
					SCLError err = [self __encryptAndSendPKStartMessage:message
									                          withScimp:scimp
															  publicKey:pubKey
					                                        transaction:transaction];
					
					if (err == kSCLError_NoErr)
					{
						didPkStart = YES;
					}
				}
				
				if (!didPkStart)
				{
					// PK start wasn't available, or failed for some reason.
					// In this case we need to fallback to the appropriate DH method.
					
					DDLogVerbose(@"%@ - DH Start (v1)...", THIS_METHOD);
					
					// SCimp context was just created.
					// We need to start the key exchange.
					
					SCimpSetNumericProperty(scimp->scimpCtx, kSCimpProperty_SCIMPmethod, kSCimpMethod_DH);
				
				//	SCLError err = SCimpStartDH(scimp->scimpCtx);
				//
				//	if (err != kSCLError_NoErr) {
				//		DDLogError(@"%@ - SCimpStartDH err: %d", THIS_METHOD, err);
				//	}
					
					SCimpResultBlock *results = NULL;
					SCLError err = SCimpStartDHSync(scimp->scimpCtx, &results);
					
					if (err != kSCLError_NoErr) {
						DDLogError(@"%@ - SCimpStartDHSync err: %d", THIS_METHOD, err);
					}
					
					if (results)
					{
						[self processSCimpResults:results withSCimp:scimp transaction:transaction];
						
						SCimpFreeEventBlock(results);
						results = NULL;
					}
					
					didEncryptAndSendMessage = NO;
				}
			}
			else if ([scimp isReady] == NO)
			{
				// SCimp stack isn't ready:
				//
				// - v1 key exchange is in progress
				// - we're awaiting a user webInfo refresh so we can do a v2 re-key
				
				didEncryptAndSendMessage = NO;
			}
			else
			{
				SCLError err = [self __encryptAndSendMessage:message withScimp:scimp transaction:transaction];
				if (err != kSCLError_NoErr)
				{
					didEncryptAndSendMessage = NO;
				}
			}
			
		} // end P2P message
		
	} // end if ([message elementForName:kSCPPSiren])
	else // queued keying message (already encrypted)
	{
		[self __sendMessageIfPossibleAndAllowed:message withTransaction:transaction];
	}
	
	return didEncryptAndSendMessage;
}

- (SCLError)__encryptAndSendMessage:(XMPPMessage *)message
                         withPubKey:(STPublicKey *)pubKey
                        transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
    NSString *pubSiren = [[message elementForName:kSCPPPubSiren] stringValue];
	if ([pubSiren length] == 0)
	{
		return kSCLError_NoErr;
	}
	
	SCKeyContextRef key = kInvalidSCKeyContextRef;
	SCLError err = SCKey_Deserialize(pubKey.keyJSON, &key);
	
	if ((err == kSCLError_NoErr) && SCKeyContextRefIsValid(key))
	{
		NSData *pubSirenData = [pubSiren dataUsingEncoding:NSUTF8StringEncoding];
		NSString *notifyValue = [[message elementForName:kSCPPSiren] attributeStringValueForName:kXMPPNotifiable];
		NSString *badgeValue  = [[message elementForName:kSCPPSiren] attributeStringValueForName:kXMPPBadge];
		
		if (notifyValue || badgeValue)
		{
			NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:kSCNameSpace];
			
			if (notifyValue) [x addAttributeWithName:kXMPPNotifiable stringValue:notifyValue];
			if (badgeValue)  [x addAttributeWithName:kXMPPBadge      stringValue:badgeValue];
			
			[message addChild:x];
		}
		
		// < I don't think this is needed any longer >
		
		__attribute__((objc_precise_lifetime)) MessageStreamUserInfo *userInfo;
		userInfo = [[MessageStreamUserInfo alloc] init];
		userInfo->ms = self;
		userInfo->transaction = transaction;
		
		SCimpSetEventHandler(pubScimp->scimpCtx, MessageStreamSCimpEventHandler, (__bridge void *)userInfo);
		
		// </ I don't think this is needed any longer >
		
		SCimpResultBlock *results = NULL;
		err = SCimpSendPublicSync(pubScimp->scimpCtx,  // SCimpContextRef
		                          key,                 // SCKeyContextRef
		                  (void *)pubSirenData.bytes,  // data to process / encrypt
		                  (size_t)pubSirenData.length, // data length
		         (__bridge void *)message,             // used by handleSCimpEvent_X methods
		                         &results);            // linked-list of events
		
		if (err != kSCLError_NoErr) {
			DDLogError(@"%@ - SCimpSendPublic err = %d", THIS_METHOD, err);
		}
		
		if (results)
		{
			[self processSCimpResults:results withSCimp:pubScimp transaction:transaction];
			
			SCimpFreeEventBlock(results);
			results = NULL;
		}
		
		SCimpSetEventHandler(pubScimp->scimpCtx, NULL, NULL);
		userInfo = nil;
	}
	
	if (SCKeyContextRefIsValid(key)) {
		SCKeyFree(key);
		key = kInvalidSCKeyContextRef;
	}
	
	return err;
}

- (SCLError)__encryptAndSendPKStartMessage:(XMPPMessage *)message
                                 withScimp:(SCimpWrapper *)scimp
                                 publicKey:(STPublicKey *)publicKeyForRemoteJID
                               transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	NSParameterAssert(message != nil);
	NSParameterAssert(scimp != nil);
	
	if (publicKeyForRemoteJID == nil)
	{
		return kSCLError_BadParams;
	}
	
	NSString *siren = [[message elementForName:kSCPPSiren] stringValue];
	if ([siren length] == 0)
	{
		DDLogWarn(@"%@ - No siren element to encrypt", THIS_METHOD);
		
		// In this case (sending a pk_start message), it's an error if we don't invoke SCimpSendPKStartMsgSync.
		return kSCLError_BadParams;
	}
	
	NSData *sirenData = [siren dataUsingEncoding:NSUTF8StringEncoding];
	NSString *notifyValue = [[message elementForName:kSCPPSiren] attributeStringValueForName:kXMPPNotifiable];
	NSString *badgeValue  = [[message elementForName:kSCPPSiren] attributeStringValueForName:kXMPPBadge];
	
	NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:kSCNameSpace];
	
	if (notifyValue) [x addAttributeWithName:kXMPPNotifiable stringValue:notifyValue];
	if (badgeValue)  [x addAttributeWithName:kXMPPBadge      stringValue:badgeValue];
	
	[message addChild:x];
	
	SCLError err = kSCLError_NoErr;
	SCKeyContextRef pubKey = kInvalidSCKeyContextRef;
	
	err = SCKey_Deserialize(publicKeyForRemoteJID.keyJSON, &pubKey);
	
	if ((err == kSCLError_NoErr) && SCKeyContextRefIsValid(pubKey))
	{
		DDLogVerbose(@"%@ - PK Start (v2)...", THIS_METHOD);
		
		SCimpResultBlock *results;
		err = SCimpSendPKStartMsgSync(scimp->scimpCtx,  // SCimpContextRef
		                              pubKey,           // SCKeyContextRef for remote JID
		                      (void *)sirenData.bytes,  // data to process / encrypt
		                      (size_t)sirenData.length, // data length
		             (__bridge void *)message,          // used by handleSCimpEvent_X methods
		                             &results);         // linked-list of events
		
		if (err != kSCLError_NoErr) {
			DDLogError(@"%@ - SCimpSendPKStartMsgSync err = %d", THIS_METHOD, err);
		}
		
		if (results)
		{
			[self processSCimpResults:results withSCimp:scimp transaction:transaction];
			
			SCimpFreeEventBlock(results);
			results = NULL;
		}
	}
	
	if (SCKeyContextRefIsValid(pubKey))
	{
		SCKeyFree(pubKey);
		pubKey = kInvalidSCKeyContextRef;
	}
	
	return err;
}

- (SCLError)__encryptAndSendMessage:(XMPPMessage *)message
                          withScimp:(SCimpWrapper *)scimp
                        transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	NSParameterAssert(message != nil);
	NSParameterAssert(scimp != nil);
	
	NSString *siren = [[message elementForName:kSCPPSiren] stringValue];
	if ([siren length] == 0)
	{
		DDLogWarn(@"%@ - No siren element to encrypt", THIS_METHOD);
		
		// In this case (sending a regular message), it should be ok if we don't invoke SCimpSendMsgSync.
		return kSCLError_NoErr;
	}
	
	NSData *sirenData = [siren dataUsingEncoding:NSUTF8StringEncoding];
	NSString *notifyValue = [[message elementForName:kSCPPSiren] attributeStringValueForName:kXMPPNotifiable];
	NSString *badgeValue  = [[message elementForName:kSCPPSiren] attributeStringValueForName:kXMPPBadge];
	
	NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:kSCNameSpace];
	
	if (notifyValue) [x addAttributeWithName:kXMPPNotifiable stringValue:notifyValue];
	if (badgeValue)  [x addAttributeWithName:kXMPPBadge      stringValue:badgeValue];
	
	[message addChild:x];
		
	SCimpResultBlock *results;
	SCLError err = SCimpSendMsgSync(scimp->scimpCtx,  // SCimpContextRef
	                        (void *)sirenData.bytes,  // data to process / encrypt
	                        (size_t)sirenData.length, // data length
	               (__bridge void *)message,          // used by handleSCimpEvent_X methods
	                               &results);         // linked-list of events
		
	if (err != kSCLError_NoErr) {
		DDLogError(@"%@ - SCimpSendMsgSync err = %d", THIS_METHOD, err);
	}
	
	if (results)
	{
		[self processSCimpResults:results withSCimp:scimp transaction:transaction];
		
		SCimpFreeEventBlock(results);
		results = NULL;
	}
	
	return err;
}

- (void)__sendMessageIfPossibleAndAllowed:(XMPPMessage *)message
                          withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	MessageStream_State state;
	NSUInteger connectionID;
	[self getMessageStreamState:&state errorString:NULL connectionID:&connectionID];
	
	BOOL canSendElement = (state == MessageStream_State_Connected);
	if (!canSendElement) {
		DDLogPurple(@"!canSendElement : state == %ld", state);
	}
 
	NSNumber *requiredConnectionID = transaction.requiredConnectionID;
	if (requiredConnectionID)
	{
		if (connectionID != [requiredConnectionID unsignedIntegerValue])
		{
			canSendElement = NO;
			DDLogPurple(@"!canSendElement : connectionID(%lu) != requiredConnectionID(%@)",
						connectionID, requiredConnectionID);
		}
	}
	
	if (transaction.isSendQueuedItemsLoop)
	{
		// OK to send
	}
	else if (transaction.isReKeying)
	{
		// OK to send so long as there aren't pendingQueuedKeyingMessages
		
		if (self.hasPendingQueuedKeyingMessages)
		{
			canSendElement = NO;
			DDLogPurple(@"!canSendElement : hasPendingQueuedKeyingMessages");
		}
	}
	else
	{
		// OK to send if there aren't any pendingQueuedMessage (of either type)
		
		if (self.hasPendingQueuedKeyingMessages || self.hasPendingQueuedDataStanzas)
		{
			canSendElement = NO;
			DDLogPurple(@"!canSendElement : hasPendingQueuedKeyingMessages || hasPendingQueuedDataStanzas");
		}
	}
	
	if (canSendElement) {
		[xmppStream sendElement:message];
	}
	else {
		DDLogInfo(@"queueing message with id: %@", [message elementID]);
	}
}

/**
 * This method is invoked when the message is unable to be sent because the SCimp context isn't ready.
 * The delegate should maintain a list of elements that were filtered,
 * and should automatically resend them when the SCimp context becomes ready.
**/
- (void)didFilterOutgoingMessage:(XMPPMessage *)message
{
	DDLogAutoTrace();
	
	NSString *elementID = [message elementID];
	if (elementID == nil)
	{
		DDLogError(@"%@ - message has no elementID, will be unable to send after keying", THIS_METHOD);
		return;
	}
	
	XMPPJID *remoteJID = [message to];
	NSString *threadID = [message threadID];
	
	NSString *conversationID = nil;
	if (threadID)
		conversationID = [self conversationIDForThreadID:threadID];
	else
		conversationID = [self conversationIDForRemoteJid:remoteJID];
	
	NSMutableOrderedSet *elementIDs = [filteredMessageIds objectForKey:conversationID];
	if (elementIDs == nil)
	{
		elementIDs = [NSMutableOrderedSet orderedSetWithCapacity:1];
		filteredMessageIds[conversationID] = elementIDs;
	}
	
	[elementIDs addObject:elementID];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Processing - Incoming
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)processReceivedErrorMessage:(XMPPMessage *)xmppMessage
                    withTransaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	NSString *messageID = [xmppMessage elementID];
	if (messageID == nil)
	{
		DDLogWarn(@"Received error message without elementID. Unable to process.");
		return;
	}
	
	NSError *error = xmppMessage.errorMessage;
	DDLogVerbose(@"Error message recieved from XMPP: %@", error);
	
	STMessage *message = [self findObjectForKey:messageID withClass:[STMessage class] transaction:transaction];
	if (message)
	{
		message = [message copy];
		message.needsReSend = YES;
		message.errorInfo = error;
		
		[transaction setObject:message
		                forKey:message.uuid
		          inCollection:message.conversationId];
		
		[transaction touchObjectForKey:message.conversationId inCollection:localUserID];
	}
}

- (void)processReceivedMessage:(XMPPMessage *)xmppMessage
               withPublicSiren:(Siren *)siren
                     timestamp:(NSDate *)timestamp
                   transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	if (siren.isVoicemail)
    {
		XMPPJID *remoteJID = [AppConstants ocaVoicemailJID];
		NSDate *recordedTime = siren.recordedTime ?: timestamp;
		
		STUser *localUser = [transaction objectForKey:localUserID inCollection:kSCCollection_STUsers];
		if (localUser == nil)
		{
			DDLogWarn(@"%@ - localUser == nil", THIS_METHOD);
			return;
		}
		
		NSDate *now = [NSDate date];
		
		// Update STConversation
		
		NSString *conversationID = [self conversationIDForRemoteJid:remoteJID];
		
		STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
		if (conversation == nil)
		{
			conversation = [[STConversation alloc] initWithUUID:conversationID
			                                        localUserID:localUserID
			                                           localJID:[localJID bareJID]
			                                          remoteJID:remoteJID];
			
			conversation.isFakeStream = YES; // <- Voicemail (no responding)
			conversation.sendReceipts = NO;
			conversation.shouldBurn   = NO;
			conversation.shredAfter   = kShredAfterNever;
			
			conversation.hidden = NO;
			
			[transaction setObject:conversation
			                forKey:conversation.uuid
			          inCollection:conversation.userId];
		}
		else if (conversation.hidden)
		{
			conversation = [conversation copy];
			conversation.hidden = NO;
			
			// conversation.lastUpdated is updated automatically by YapDatabaseHooks extension when
			// a message is added to the conversation
			
			[transaction setObject:conversation
			                forKey:conversation.uuid
			          inCollection:conversation.userId];
		}
		
		// Insert STMessage
		
		NSString *messageID = [xmppMessage elementID];
		
		STMessage *message = [[STMessage alloc] initWithUUID:(messageID ?: [XMPPStream generateUUID])
		                                      conversationId:conversation.uuid
		                                              userId:localUserID
		                                                from:conversation.remoteJid
		                                                  to:conversation.localJid
		                                           withSiren:siren
		                                           timestamp:recordedTime
		                                          isOutgoing:NO];
		
		message.isVerified = YES;
		
		// We're not actually sending these messages,
		// so we can fake the timestamps.
		message.sendDate = now;
		message.serverAckDate = now;
		
		[transaction setObject:message
						forKey:message.uuid
				  inCollection:message.conversationId];

    }
	else if (siren.multicastKey)
	{
		// We need to store the multicast key in the database.
		// And create the corresponding conversation ?
		
		STSymmetricKey *multicastKey = [STSymmetricKey keyWithString:siren.multicastKey];
		
		if (multicastKey && multicastKey.threadID)
		{
			[self saveMulticastKey:multicastKey withTransaction:transaction];
			
			SCimpWrapper *scimp = [self scimpForThreadID:multicastKey.threadID withTransaction:transaction isNew:NULL];
			if (scimp)
			{
				SCKeyContextRef scKey = kInvalidSCKeyContextRef;
				SCLError err = SCKey_Deserialize(multicastKey.keyJSON, &scKey);
				
				if ((err == kSCLError_NoErr) && SCKeyContextRefIsValid(scKey))
				{
					// This call is re-entrant,
					// and should call back into XMPPSCimpEventHandler to store the updated scimp state
					
					SCimpUpdateSymmetricKey(scimp->scimpCtx, [multicastKey.threadID UTF8String], scKey);
				}
				
				if (SCKeyContextRefIsValid(scKey))
				{
					SCKeyFree(scKey);
					scKey = kInvalidSCKeyContextRef;
				}
			}
		}
	}
	
    else
    {
        DDLogWarn(@"Public siren received: unhandled");
    }
}


- (void)processReceivedMessage:(XMPPMessage *)xmppMessage
                     withSiren:(Siren *)inSiren
                conversationID:(NSString *)conversationID
                     timestamp:(NSDate *)timestamp
                   transaction:(YapDatabaseReadWriteTransaction *)transaction
{
	DDLogAutoTrace();
	
	NSAssert(conversationID != nil, @"Bad parameter: conversationID is nil");
	
	// Check for message signature
	
	BOOL sig_keyFound = NO;
	BOOL sig_valid    = NO;
	
	NSDictionary *signatureInfo = [self signatureInfoFromSiren:inSiren withTransaction:transaction];
	if (signatureInfo)
	{
		sig_keyFound = [[signatureInfo objectForKey:kSigInfo_keyFound] boolValue];
		
		NSString *owner = [signatureInfo objectForKey:kSigInfo_owner];
		NSString *from = [[xmppMessage from] bare];
		
		if ([owner isEqualToString:from])
		{
			NSDate *expireDate = [signatureInfo objectForKey:kSigInfo_expireDate];
			if ([expireDate timeIntervalSinceDate:timestamp] > 0)
			{
				sig_valid = [[signatureInfo objectForKey:kSigInfo_valid] boolValue];
			}
		}
	}
	
	if (signatureInfo && !sig_valid && (inSiren.receivedID || inSiren.requestBurn))
	{
		// Received command with bad signature.
		// Ignore (maybe flag user in the future).
        return;
	}
	
	//
	/******************** Request Resend ********************/
	//
	if (inSiren.requestResend)
	{
		NSString *messageID = inSiren.requestResend;
		
		id obj = [transaction objectForKey:messageID inCollection:conversationID];
		if (!obj || ![obj isKindOfClass:[STMessage class]])
		{
			// obj could possibly be STXMPPElement instance
			return;
		}
		
		STMessage *message = (STMessage *)obj;
		
		// Guard code.
		if (!message.isOutgoing)
		{
			// You want me to resend a message I never sent in the first place?
			
			DDLogWarn(@"%@ - Ignoring requestResend for non-outgoing message.", THIS_METHOD);
			return;
		}
		if (message.rcvDate)
		{
			// You want me to resend a message that you've already told me you received?
			
			DDLogWarn(@"%@ - Ignoring requestResend for message with rcvDate.", THIS_METHOD);
			return;
		}
		
		// If it's a valid signature, then we're going to automatically resend the message.
		if (sig_valid)
		{
			// copy the message siren
			Siren *sirenToResend = [message.siren copy];
			sirenToResend.signature = NULL;
			
			// delete the old message
			[transaction removeObjectForKey:message.uuid inCollection:message.conversationId];
			
			// Touch the conversation
			[[transaction ext:Ext_View_Order] touchRowForKey:message.conversationId
			                                    inCollection:message.userId];
			
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
			
			// Resend the siren
			STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
			
			[self sendSiren:sirenToResend forConversation:conversation
			                                     withPush:YES
			                                        badge:YES
			                                createMessage:YES
			                                  transaction:transaction];
		}
		else // if (!sig_valid)
		{
			// if the request is not signed then flag it as "needs resend" ("not received")
			
			message = [message copy];
			message.needsReSend = YES;
			message.shredDate = NULL; // requesting resend resets the burn time
			
			[transaction setObject:message
			                forKey:message.uuid
			          inCollection:message.conversationId];
			
			[transaction touchObjectForKey:message.conversationId inCollection:localUserID];
			
			// It's possible we just need to refresh the user's webInfo.
			// After which, we'll discover the signature is valid, and we were just out of date.
			
			[self reverifyRequestResendSiren:inSiren from:[message from]];
		}
	}
	//
	/******************** Message Receipt ********************/
	//
	else if (inSiren.receivedID)
	{
		NSString *messageID = inSiren.receivedID;
		
		// Update STMessage
		
		id obj = [transaction objectForKey:messageID inCollection:conversationID];
		if (!obj || ![obj isKindOfClass:[STMessage class]])
		{
			// obj could possibly be STXMPPElement instance
			return;
		}
		
		STMessage *message = (STMessage *)obj;
		
		message = [message copy];
		message.rcvDate = inSiren.receivedTime;
		
		[transaction setObject:message
		                forKey:message.uuid
		          inCollection:message.conversationId];
		
		// Update STConversation
		
		STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
		
		if (conversation.mostRecentDeliveredTimestamp == nil ||
			[conversation.mostRecentDeliveredTimestamp isBefore:message.timestamp])
		{
			if (conversation.mostRecentDeliveredMessageID)
			{
				// Touch the last mostRecentDeliveredMessageID.
				// This allows the corresponding message cell to get properly updated (if on-screen).
				
				[[transaction ext:Ext_View_Order] touchRowForKey:conversation.mostRecentDeliveredMessageID
				                                    inCollection:conversation.uuid];
			}
			
			conversation = [conversation copy];
			conversation.mostRecentDeliveredTimestamp = message.timestamp;
			conversation.mostRecentDeliveredMessageID = message.uuid;
			
			[transaction setObject:conversation
			                forKey:conversation.uuid
			          inCollection:localUserID];
		}
	}
	//
	//
	/******************** Burn Request ********************/
	//
	else if (inSiren.requestBurn)
	{
		NSString *messageID = inSiren.requestBurn;
		
		id obj = [transaction objectForKey:messageID inCollection:conversationID];
		if (!obj || ![obj isKindOfClass:[STMessage class]])
		{
			// obj could possibly be STXMPPElement instance
			return;
		}
		
		STMessage *message = (STMessage *)obj;
		
		XMPPJID *stMsgFrom = message.from;
		XMPPJID *xmppMsgFrom = [xmppMessage from];
		
		if ([stMsgFrom isEqualToJID:xmppMsgFrom options:XMPPJIDCompareBare])
		{
			// Fetch the scloud item (if it exists) and delete the corresponding files from disk
			NSString *scloudId = message.siren.cloudLocator;
			if (scloudId)
			{
				STSCloud *scl = [transaction objectForKey:scloudId inCollection:kSCCollection_STSCloud];
				
				[scl removeFromCache];
			}
			
			// Delete the message
			[transaction removeObjectForKey:message.uuid inCollection:message.conversationId];
			
			// Notes:
			//
			// - The relationship extension will automatically remove the thumbnail (if needed)
			// - The relationship extension will automatically remove the scloud item (if needed)
			// - The hooks extension will automatically update the conversation item (if needed)
		}
	}
	//
	//
	/******************** Ping ********************/
	//
    else if (inSiren.ping)
	{
		STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
		
		if (inSiren.capabilities)
		{
			NSData *capData = [inSiren.capabilities dataUsingEncoding:NSUTF8StringEncoding];
			
			NSMutableDictionary *capInfo = nil;
			capInfo = [NSJSONSerialization JSONObjectWithData:capData
			                                          options:NSJSONReadingMutableContainers
			                                            error:NULL];
			
			// Update the conversation capabilities
			
			conversation = [conversation copy];
			conversation.capabilities = capInfo ? capInfo : [NSDictionary dictionary];
			
			[transaction setObject:conversation
			                forKey:conversation.uuid
			          inCollection:localUserID];
		}
		
		if ([inSiren.ping isEqualToString:kPingRequest]) // kPingRequest || kPingResponse
		{
			Siren *pongSiren = [Siren new];
			pongSiren.ping = kPingResponse;
			
			if (capabilitiesDict)
			{
				NSData *capData = nil;
				capData = ([NSJSONSerialization isValidJSONObject:capabilitiesDict] ?
				           [NSJSONSerialization dataWithJSONObject:capabilitiesDict options:0 error:NULL] :
				           nil);
				
				pongSiren.capabilities = [[NSString alloc] initWithData:capData encoding:NSASCIIStringEncoding];
			}
			
			[self sendSiren:pongSiren forConversation:conversation
			                                 withPush:NO
			                                    badge:NO
			                            createMessage:NO
			                              transaction:transaction];
		}
		
    }
	//
	//
	/******************** Normal Message ********************/
	//
	else
	{
		NSDate *now = [NSDate date];
		
		STMessage * message = nil;
        Siren     * siren = nil;
		STImage   * thumbnail = nil;
        OSImage   * thumbnailImage = nil;
		
		NSString *messageID = [xmppMessage elementID];
		XMPPJID *senderJID = [xmppMessage from];
      
		// What happens here is tricky:
		//
		// inSiren has information derived from "chatMessage" like "from" and "to" .
		// The Siren object typically only carried the JSON info itself.
		// So what we do is to copy just the JSON info and create a new Siren object for database storage.
		// If that Siren has a thumbnail, we decode it and create a STImage object in the database with the
		// same uuid as the message itself.  We then remove the thumbnail from the new  Siren.
		// This allows  us to not fetch the 4K or so bytes from the thumbnail everytime we fetch the message.
		// If we want the thumbnail image we can explicitly ask for it.
		//
		// The only issue is that we need to check message signatures now, if there is one,
		// since the orginal thumbnail will be removed.
		
		if (inSiren.thumbnail)
		{
		#if TARGET_OS_IPHONE
			thumbnailImage = [UIImage imageWithData:inSiren.thumbnail scale:[[UIScreen mainScreen] scale]];
		#else
			thumbnailImage = [NSImage imageWithData:inSiren.thumbnail];
		#endif
			thumbnail = [[STImage alloc] initWithImage:thumbnailImage
			                                 parentKey:messageID
			                                collection:conversationID];
			
			// Note: The thumbnail, when added to the database, will create a graph edge pointing to the message
			// with a nodeDeleteRule so that the thumbnail is automatically deleted when the message is deleted.
			
			siren = [inSiren copy];
			siren.thumbnail = NULL;
		}
		else
		{
			siren = [inSiren copy];
		}
		
		if (siren.testTimestamp)
		{
			// This is a test message.
			//
			// We should decode the test time and calculate how long it took
			// for us to get it and append this to the message string.
			
			NSDate *sentTime = siren.testTimestamp;
			NSTimeInterval transitInterval = [now timeIntervalSinceDate:sentTime];
			NSDate *transitDuration = [NSDate dateWithTimeIntervalSinceReferenceDate:transitInterval];
			
			NSDateFormatter *durationFormatter = [SCDateFormatter localizedDateFormatterFromTemplate:@"mmssS"];
			NSString *transitTimeString = [durationFormatter stringFromDate:transitDuration];
			
			siren.message = [NSString stringWithFormat:@"%@\ndelay: %@", siren.message, transitTimeString];
		}
		
		// Update the conversation (if needed)
		
		STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
		BOOL conversationUpdated = NO;
		
		if (conversation.hidden)
		{
			if (!conversationUpdated) {
				conversation = [conversation copy];
			}
			
			conversation.hidden = NO;
			conversationUpdated = YES;
		}
		
		// conversation.lastUpdated is updated automatically by YapDatabaseHooks extension when
		// a message is added to the conversation
		
		if (siren.threadName) /*** rename thread ***/
		{
			if (!conversationUpdated) {
				conversation = [conversation copy];
			}
			
			if (siren.threadName.length > 0)
				conversation.title = siren.threadName;
			else
				conversation.title = nil;
			
			conversationUpdated = YES;
		}
		
		if (conversationUpdated)
		{
			[transaction setObject:conversation
			                forKey:conversation.uuid
			          inCollection:localUserID];
		}
		
		// Create the message
		
		message = [[STMessage alloc] initWithUUID:messageID
		                           conversationId:conversationID
		                                   userId:localUserID
		                                     from:senderJID
		                                       to:[xmppMessage to]
		                                withSiren:siren
		                                timestamp:timestamp
		                               isOutgoing:NO];
		
		message.isVerified = sig_valid;
		message.signatureInfo = signatureInfo;
	
		message.hasThumbnail = (thumbnail != nil);
		
		// Check siren for scloud component
		
		if (siren.cloudLocator && siren.cloudKey)
		{
			STSCloud *scl = [transaction objectForKey:siren.cloudLocator inCollection:kSCCollection_STSCloud];
			if (scl == nil)
			{
				message.needsDownload = YES;
			}
			else
			{
				// Create a relationship between the STMessage and STSCloud object.
				//
				// YDB_DeleteDestinationIfAllSourcesDeleted:
				//   When the every last message that points to this particular STSCloud has been deleted,
				//   then the database will automatically delete this STSCloud object.
				//
				// Further, the STSCloud object uses the YapDatabaseRelationshipNode protocol so that
				// when the STSCloud object is deleted, the database automatically deletes the folder
				// where it stores all its segments.
				
				YapDatabaseRelationshipEdge *edge =
				  [YapDatabaseRelationshipEdge edgeWithName:@"scloud"
				                                  sourceKey:message.uuid
				                                 collection:message.conversationId
				                             destinationKey:siren.cloudLocator
				                                 collection:kSCCollection_STSCloud
				                            nodeDeleteRules:YDB_DeleteDestinationIfAllSourcesDeleted];
				
				[[transaction ext:Ext_Relationship] addEdge:edge];
			}
		}
		
		// Save the message, thumbnail & conversation
                
		[transaction setObject:message
		                forKey:message.uuid
		          inCollection:message.conversationId];
 
		if (thumbnail)
		{
			[transaction setObject:thumbnail
			                forKey:thumbnail.parentKey
			          inCollection:kSCCollection_STImage_Message];
		}
	
		// Update sender's lastLocation (if siren includes location)
	
		if (inSiren.location)
		{
			NSData *locData = [inSiren.location dataUsingEncoding:NSUTF8StringEncoding];
			
			NSDictionary *locInfo = nil;
			NSError *jsonError = nil;
			
			locInfo = [NSJSONSerialization JSONObjectWithData:locData options:0 error:&jsonError];
			
			if (jsonError == nil)
			{
				CLLocation *location = [[CLLocation alloc] initWithDictionary:locInfo];
				
				STUser *sender = [STDatabaseManager findUserWithJID:senderJID transaction:transaction];
				if (sender)
				{
					sender = [sender copy];
					sender.lastLocation = location;
					
					[transaction setObject:sender
					                forKey:sender.uuid
					          inCollection:kSCCollection_STUsers];
				}
			}
		}
            

		[self usingTransaction:transaction pushCompletionBlock:^{
			
			// Did this message include some media ?
			if (message.needsDownload)
			{
				[self downloadSCloudForMessage:message withThumbnail:thumbnailImage completionBlock:NULL];
			}
			
			// Was the message signed by a key we dont have ?
			// If so, then we probably need to update the senders key info.
			
			if (signatureInfo && !sig_keyFound && messageID)
			{
				// The reverifySignatureForMessage method automatically refreshes the user info,
				// and then rechecks the message signature.
				
				[self reverifySignatureForMessage:message completionBlock:NULL];
			}
		
			// Play received message sound.
			//
			// IMPORTANT:
			//   This is done within the completionBlock,
			//   because only then do we know the message might have reached the main thread.
			//   Anytime before the completionBlocks hits might mean we play the sound before
			//   the UI has a chance to start updating.
			//
			[[STSoundManager sharedInstance] playMessageInSound];
			
		}];
		
	} // end: *** Normal Message ***
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket
{
	DDLogAutoTrace();
	
#if DEBUG
	_tempAsyncSocket = socket;
#endif
	
	NSString *host = nil;
	uint16_t port = 0;
	[GCDAsyncSocket getHost:&host port:&port fromAddress:[socket connectedAddress]];
	
	connectedHostName = host;
	connectedHostPort = port;
}

- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings
{
	DDLogAutoTrace();
	
	// This is proper kCFStreamSSL setting to allow us to check the cert.
	[settings setObject:@"" forKey:GCDAsyncSocketSSLPeerName];
	
	// Turn on manual trust evaluation so we can compare the certs ourself
	[settings setObject:@(YES) forKey:GCDAsyncSocketManuallyEvaluateTrust];
	
	// The peerID is used for TLS session resumption.
	// The peerID is applied to every TLS sesssion,
	// and SecureTransport uses it as a key to lookup previous session info within an internal key/value store.
	//
	// Note: SecureTransport's internal store is not persistent.
	// So TLS session resumption only applies to subsequent connections during the lifetime of the the app launch.
	
	NSString *peerID = [NSString stringWithFormat:@"%@:%@:%hu", [localJID bare], connectedHostName, connectedHostPort];
	NSData *peerIDBlob = [peerID dataUsingEncoding:NSUTF8StringEncoding];
	
	[settings setObject:peerIDBlob forKey:GCDAsyncSocketSSLPeerID];
}

- (void)xmppStream:(XMPPStream *)sender didReceiveTrust:(SecTrustRef)trust
                                      completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler
{
	DDLogAutoTrace();
	
	// Get the embedded / expected keyHash info
  
	NSDictionary *networkInfo = [[AppConstants SilentCircleNetworkInfo] objectForKey:networkID];
	NSArray *expectedKeyHashArray = [networkInfo objectForKey:@"xmppSHA256"];
    
	if ([expectedKeyHashArray count] == 0)
	{
		completionHandler(NO);
		return;
	}
    
	// Now get the keyHash info from the connection
	
	NSData *serverKeyHash = nil;
	
	if (SecTrustGetCertificateCount(trust) > 0)
	{
		SecCertificateRef certificate = SecTrustGetCertificateAtIndex(trust, 0);
		NSData *serverCertificateData = (__bridge_transfer NSData *)SecCertificateCopyData(certificate);
		
		serverKeyHash = [STAppDelegate getPubKeyHashForCertificate:serverCertificateData];
	}
	
	if (serverKeyHash == nil)
	{
		completionHandler(NO);
		return;
	}
	
	// And compare them
	
	BOOL hash_matches = NO;
	for (NSData *expectedKeyHash in expectedKeyHashArray)
	{
		if ((expectedKeyHash.length == serverKeyHash.length) &&
		    CMP(expectedKeyHash.bytes, serverKeyHash.bytes, serverKeyHash.length))
		{
			hash_matches = YES;
			break;
		}
    }
    
	completionHandler(hash_matches);
}

/**
 * This method is called after the XML stream has been fully opened.
 * More precisely, this method is called after an opening <xml/> and <stream:stream/> tag have been sent and received,
 * and after the stream features have been received, and any required features have been fullfilled.
 * At this point it's safe to begin communication with the server.
**/
- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
    DDLogAutoTrace();
    
#if DEBUG
	[_tempAsyncSocket performBlock:^{ @autoreleasepool {
		
		SSLContextRef ssl = [_tempAsyncSocket sslContext];
		if (ssl)
		{
			OSStatus status;
			
			SSLCipherSuite cipherSuite = SSL_NULL_WITH_NULL_NULL;
			status = SSLGetNegotiatedCipher(ssl, &cipherSuite);
			
			DDLogPink(@"status:%d cipherSuite: %x", (int)status, cipherSuite);
		}
	}}];
	
	_tempAsyncSocket = nil;
#endif
	
	// Todo: authenticateWithPassword is technically deprecated.
	// Let's switch to using an explicit list of supported authentication schemes (in order).
	
	NSError *error = nil;
	if (![xmppStream authenticateWithPassword:xmppPassword error:&error])
	{
		DDLogError(@"Error authenticating: %@", error);
	}
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
	DDLogAutoTrace();
	
	NSString *requestedResource = localJID.resource;
	NSString *assignedResource = sender.myJID.resource;
	
	if (![requestedResource isEqualToString:assignedResource])
	{
		DDLogError(@"The XMPP server gave us a different JID.resource !!! "
		           @"This is going to cause massive problems !!!");
		
		localJID = sender.myJID;
	}
	
	// Check to see if we resumed a previous session
	NSArray *stanzaIds = nil;
	if ([xmppStreamManagement didResumeWithAckedStanzaIds:&stanzaIds serverResponse:NULL])
	{
		// Process the newly acked stanzaIds (if necessary)
		[self xmppStreamManagement:nil didReceiveAckForStanzaIds:stanzaIds];
	}
	else
	{
		NSTimeInterval maxTimeout = 0; // Use default (server specified) timeout, which is normally 5 minutes
		[xmppStreamManagement enableStreamManagementWithResumption:YES maxTimeout:maxTimeout];
	}
	
	// Send available presence
	//
	// Note: We do this everytime, even if we don't technically need to.
	// This is because we use the server's response to our presence stanza to detect
	// when we've read all the offline messages.
	//
	XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
	[xmppStream sendElement:presence];
	
	replacedByNewConnection = NO;
	
	// First, make sure nothing gets sent until all queued items have been popped.
	self.hasPendingQueuedKeyingMessages = YES;
	self.hasPendingQueuedDataStanzas = YES;
	
	// Update state
	NSUInteger connectionID = [self setMessageStreamState:MessageStream_State_Connected errorString:nil];
	
	// Drain queue (if needed)
	[self sendQueuedItems:connectionID];
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
#if DEBUG
	NSString *msg = [NSString stringWithFormat:@"xmppStream:didNotAuthenticate: %@", error];
	[MessageStream sendInfoMessage:msg toUser:localUserID];
#endif
	
	DDLogTrace(@"xmppStream:didNotAuthenticate: %@", error);
	
	[self setMessageStreamState:MessageStream_State_Error errorString:nil];
	
	// This may be an indication that the active_st_device has changed.
	// Post notification so we can check.
	
	[self notifyLocalUserActiveDeviceMayHaveChanged];
}

/**
 * From XMPPStream documentation:
 *
 * These methods are called before their respective XML elements are broadcast as received to the rest of the stack.
 * These methods can be used to modify elements on the fly.
 * (E.g. perform custom decryption so the rest of the stack sees readable text.)
 *
 * You may also filter incoming elements by returning nil.
 *
 * When implementing these methods to modify the element, you do not need to copy the given element.
 * You can simply edit the given element, and return it.
 * The reason these methods return an element, instead of void, is to allow filtering.
 *
 * Concerning thread-safety, delegates implementing the method are invoked one-at-a-time to
 * allow thread-safe modification of the given elements.
 *
 * You should NOT implement these methods unless you have good reason to do so.
 * For general processing and notification of received elements, please use xmppStream:didReceiveX: methods.
 *
 * @see xmppStream:didReceiveIQ:
 * @see xmppStream:didReceiveMessage:
 * @see xmppStream:didReceivePresence:
**/
- (XMPPMessage *)xmppStream:(XMPPStream *)sender willSendMessage:(XMPPMessage *)message
{
	// Strip any and all plaintext data (if needed)
	[message stripSilentCirclePlaintextDataForOutgoingStanza];
	
	return message;
}

- (void)xmppStream:(XMPPStream *)sender didSendMessage:(XMPPMessage *)xmppMessage
{
	DDLogAutoTrace();
	
	NSString *messageID = [xmppMessage elementID];
	if (messageID == nil) return;
	
	__block STMessage *message;
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        
        message = [self findObjectForKey:messageID withClass:[STMessage class] transaction:transaction];
        
	} completionBlock:^{
		
		if (message)
		{
			[[STSoundManager sharedInstance] playMessageOutSound];
		}
	}];
}

- (XMPPMessage *)xmppStream:(XMPPStream *)sender willReceiveMessage:(XMPPMessage *)message
{
	NSString *messageID = [message elementID];
	if (messageID == nil)
	{
		// Inject messageID, to ensure everybody else gets a valid one.
		
		DDLogWarn(@"%@ - Received message with no id: %@", THIS_METHOD, message);
		
		messageID = [[NSUUID UUID] UUIDString];
		[message addAttributeWithName:@"id" stringValue:messageID];
	}
	
	// Strip out any existing internal silent circle notations to prevent counterfeiting (if needed)
	[message stripSilentCirclePlaintextDataForIncomingStanza];
	
	return message;
}

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)inMessage
{
	DDLogAutoTrace();
	
	// Our decryption routine modifies the message element (by injecting the decrypted siren).
	// We don't want this to interfere with other xmpp extensions that may be processing the same message
	// in another thread/queue, so we create our own (thread-safe) copy
	//
	XMPPMessage *message = [inMessage copy];
	NSString *messageID = [message elementID];
	
	NSMutableArray *transactionCompletionBlocks = [[NSMutableArray alloc] init];
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		transaction.completionBlocks = transactionCompletionBlocks;
		
		// Check for duplicate message (Reliable Message Delivery)
		
		BOOL isDuplicateMessageID = NO;
		if (messageID)
		{
			XMPPJID *remoteJID = [message from];
			NSString *cacheKey = [self messageIDCacheKeyForFullRemoteJID:remoteJID];
			
			STMessageIDCache *cache = [transaction objectForKey:cacheKey inCollection:kSCCollection_STMessageIDCache];
			
			if ([cache containsMessageID:messageID])
			{
				isDuplicateMessageID = YES;
			}
			else
			{
				if (cache)
					cache = [cache copy];
				else
					cache = [[STMessageIDCache alloc] init];
				
				[cache addMessageID:messageID];
				[transaction setObject:cache forKey:cacheKey inCollection:kSCCollection_STMessageIDCache];
			}
		}
		
		if (isDuplicateMessageID)
		{
			// Ignore message. We already processed it in the past.
			// It's just that our ACK never reached the server, so it's re-sending it just in case.
			
			DDLogPink(@"Ignoring duplicate messageID: %@", messageID);
			return;
		}
		
		if (message.isErrorMessage)
		{
			// An error message is generally something from the server,
			// telling us the message was not deliverable.
			
			[self processReceivedErrorMessage:message withTransaction:transaction];
			
			return;
		}
		
		// Decrypt pubsiren (if present)
		
		NSXMLElement *xPubKey = [message elementForName:@"x" xmlns:kSCPublicKeyNameSpace];
		if (xPubKey)
		{
			NSString *encrypted = [xPubKey stringValue];
			
			const char *utf8 = [encrypted UTF8String];
			NSUInteger utf8Len = [encrypted lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
			
			__attribute__((objc_precise_lifetime)) MessageStreamUserInfo *userInfo;
			userInfo = [[MessageStreamUserInfo alloc] init];
			userInfo->ms = self;
			userInfo->transaction = transaction;
			
			SCimpSetEventHandler(pubScimp->scimpCtx, MessageStreamSCimpEventHandler, (__bridge void *)userInfo);
			
		//	// Here's how this works:
		//	//
		//	// We invoke SCimpProcessPacket, which immediately invokes our MessageStreamSCimpEventHandler.
		//	// The event handler is given the decrypted data, which it will inject into the message.
		//
		//	SCLError err = SCimpProcessPacket(pubScimp->scimpCtx, // SCimpContextRef
		//	                       (uint8_t *)utf8,               // data to process / decrypt
		//	                          (size_t)utf8Len,            // data length
		//	                 (__bridge void *)message);           // used by MessageStreamSCimpEventHandler
		//
		//	if (err != kSCLError_NoErr) {
		//		DDLogError(@"%@ - SCimpProcessPacket(pubScimpCtx, ...) err: %d", THIS_METHOD, err);
		//	}
			
			SCimpResultBlock *results = NULL;
			SCLError err = SCimpProcessPacketSync(pubScimp->scimpCtx, // SCimpContextRef
			                           (uint8_t *)utf8,               // data to process / decrypt
			                              (size_t)utf8Len,            // data length
			                     (__bridge void *)message,            // used by handleSCimpEvent_X methods
			                                     &results);           // linked-list of events
			
			if (err != kSCLError_NoErr) {
				DDLogError(@"%@ - SCimpProcessPacketSync(pubScimpCtx, ...) err: %d", THIS_METHOD, err);
			}
			
			if (results)
			{
				[self processSCimpResults:results withSCimp:pubScimp transaction:transaction];
				
				SCimpFreeEventBlock(results);
				results = NULL;
			}
			
			#if DEBUG
			// Don't include decrypted material in production debug logs !!!
			if (err == kSCLError_NoErr) {
				DDLogOrange(@"Decrypted message:\n%@", [message prettyXMLString]);
			}
			#endif
			
			SCimpSetEventHandler(pubScimp->scimpCtx, NULL, NULL);
			userInfo = nil;
		}
		
		// Decrypt siren (if present)
		
		NSString *conversationID = nil;
		
		NSXMLElement *x = [message elementForName:@"x" xmlns:kSCNameSpace];
		if (x)
		{
			XMPPJID *remoteJID = [message from];
			NSString *threadID = message.threadID;
			
			if (threadID)
				conversationID = [self conversationIDForThreadID:threadID];
			else
				conversationID = [self conversationIDForRemoteJid:remoteJID];
			
			// Create or update the conversation (if needed)
			
			BOOL needsRefreshUserWebInfo = NO;
			
			STConversation *conversation = [transaction objectForKey:conversationID inCollection:localUserID];
			if (conversation)
			{
				if (!conversation.isMulticast && ![conversation.remoteJid isEqualToJID:remoteJID])
				{
					if (conversation.remoteJid.resource)
					{
						// The user's resource changed, so they must have switched devices.
						needsRefreshUserWebInfo = YES;
					}
					
					conversation = [conversation copy];
					conversation.remoteJid = remoteJID;
					
					[transaction setObject:conversation
					                forKey:conversation.uuid
					          inCollection:conversation.userId];
				}
			}
			else // if (conversation == nil)
			{
				if (threadID)
				{
					conversation = [[STConversation alloc] initWithUUID:conversationID
					                                        localUserID:localUserID
					                                           localJID:[localJID bareJID]
					                                           threadID:threadID];
					
					STSymmetricKey *mcKey = [self symmetricKeyForThreadID:threadID withTransaction:transaction];
					conversation.keyLocator = mcKey.uuid;
					
					XMPPJIDMutableSet *jidSet = [[XMPPJIDMutableSet alloc] initWithJids:[message jids]];
					[jidSet removeJid:localJID options:XMPPJIDCompareBare];
                    [jidSet addJid:remoteJID.bareJID options:XMPPJIDCompareBare];
					
					conversation.multicastJidSet = jidSet;
					
					conversation.sendReceipts = NO; // never for multicast
					conversation.shouldBurn   = [STPreferences defaultShouldBurn];
					conversation.shredAfter   = [STPreferences defaultBurnTime];
				}
				else
				{
					conversation = [[STConversation alloc] initWithUUID:conversationID
					                                        localUserID:localUserID
					                                           localJID:[localJID bareJID]
					                                          remoteJID:remoteJID];
					
					conversation.sendReceipts = [STPreferences defaultSendReceipts];
					conversation.shouldBurn   = [STPreferences defaultShouldBurn];
					conversation.shredAfter   = [STPreferences defaultBurnTime];
				}
				
				conversation.hidden = YES; // will be marked NO if we receive an actual message
				
				[transaction setObject:conversation
				                forKey:conversation.uuid
				          inCollection:conversation.userId];
			}
			
			// Create user (if needed)
			
			BOOL isNewUser;
			STUser *user = [self findOrCreateUserWithJID:remoteJID transaction:transaction wasCreated:&isNewUser];
			
			if (user && !isNewUser && needsRefreshUserWebInfo)
			{
				[[STUserManager sharedInstance] refreshWebInfoForUser:user completionBlock:NULL];
			}
			
			// Fetch scimp and decrypt message
			
			SCimpWrapper *scimp = nil;
			BOOL isNewScimp = NO;
			
			if (threadID) // multicast conversation
			{
				scimp = [self scimpForThreadID:threadID withTransaction:transaction isNew:&isNewScimp];
			}
			else // p2p conversation
			{
				scimp = [self scimpForRemoteJID:remoteJID withTransaction:transaction isIncoming:YES isNew:&isNewScimp];
			}
			
			if (scimp == nil)
			{
				DDLogVerbose(@"%@ - scimp == nil", THIS_METHOD);
				
				// Some error occurred while restoring / creating the scimp context.
				// The error was logged in the corresponding method.
			}
			else // if (scimp)
			{
				NSString *encrypted = [x stringValue];
				
				const char *utf8 = [encrypted UTF8String];
				NSUInteger utf8Len = [encrypted lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
				
		//		// Here's how this works:
		//		//
		//		// We invoke SCimpProcessPacket, which immediately invokes our MessageStreamSCimpEventHandler.
		//		// The event handler is given the decrypted data, which it will inject into the message.
		//
		//		SCLError err = SCimpProcessPacket(scimp->scimpCtx, // SCimpContextRef
		//		                       (uint8_t *)utf8,            // data to process / decrypt
		//		                          (size_t)utf8Len,         // data length
		//		                 (__bridge void *)message);        // used by MessageStreamSCimpEventHandler
		//
		//		if (err != kSCLError_NoErr) {
		//			DDLogError(@"%@ - SCimpProcessPacket err: %d", THIS_METHOD, err);
		//		}
				
				SCimpResultBlock *results = NULL;
				SCLError err = SCimpProcessPacketSync(scimp->scimpCtx, // SCimpContextRef
				                           (uint8_t *)utf8,            // data to process / decrypt
				                              (size_t)utf8Len,         // data length
				                     (__bridge void *)message,         // used by handleSCimpEvent_X methods
				                                     &results);        // linked-list of events
				
				if (err != kSCLError_NoErr) {
					DDLogError(@"%@ - SCimpProcessPacketSync err: %d", THIS_METHOD, err);
				}
				
				if (results)
				{
					[self processSCimpResults:results withSCimp:scimp transaction:transaction];
					
					SCimpFreeEventBlock(results);
					results = NULL;
				}
				
				#if DEBUG
				// Don't include decrypted material in production debug logs !!!
				if (err == kSCLError_NoErr) {
					DDLogOrange(@"Decrypted message:\n%@", [message prettyXMLString]);
				}
				#endif
			}
		}
		
		// Now that the message has been decrypted we can process it
		
		if (message.isChatMessageWithSiren)
		{
			NSDate *timestamp = message.timestamp;
			if (!timestamp) timestamp = [NSDate date];
			
			NSString *json = [[message elementForName:kSCPPSiren xmlns:kSCNameSpace] stringValue];
			Siren *siren = [Siren sirenWithJSON:json];
			
			[self processReceivedMessage:message
			                   withSiren:siren
			              conversationID:conversationID
			                   timestamp:timestamp
			                 transaction:transaction];
		}
		
		if (message.isChatMessageWithPubSiren)
		{
			NSDate *timestamp = message.timestamp;
			if (!timestamp) timestamp = [NSDate date];
			
			NSString *json = [[message elementForName:kSCPPPubSiren xmlns:kSCNameSpace] stringValue];
			Siren *siren = [Siren sirenWithJSON:json];
			
			[self processReceivedMessage:message
			             withPublicSiren:siren
			                   timestamp:timestamp
			                 transaction:transaction];
		}
		
	} completionBlock:^{
		
		[xmppStreamManagement markHandledStanzaId:messageID];
		
		for (dispatch_block_t block in transactionCompletionBlocks) {
			block();
		}
	}];
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	XMPPJID *from = [presence from];
	
	if ([localJID isEqualToJID:from options:XMPPJIDCompareFull])
	{
		// When we connect to the xmpp server it immediately dumps the offline queue at us.
		// This is followed up by the server's response to our announced presence stanza.
		//
		// Thus, after we receive the presence stanza, we know we've drained the offline queue.
		// We use this information for various purposes.
		
		hasReceivedPresence = YES;
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error
{
	DDLogTrace(@"xmppStream:didReceiveError: %@", error);
	
	NSString *errorElement = [error name];
 	
	if ([errorElement isEqualToString:@"stream:error"] || [errorElement isEqualToString:@"error"])
	{
        NSXMLElement *reason = [error elementForName:@"text" xmlns:@"urn:ietf:params:xml:ns:xmpp-streams"];
        NSString *errorText = reason?[reason stringValue]:NULL;

		NSXMLElement *conflict = [error elementForName:@"conflict" xmlns:@"urn:ietf:params:xml:ns:xmpp-streams"];
		if (conflict && errorText)
		{
			// XMPP server booted our connection because the same user/resource logged in somewhere else.
            replacedByNewConnection = YES;
            
			// Set the errorString, but don't change the state yet.
			// The xmppStream will disconnect immediately after, and we'll set the state there.
			
			MessageStream_State state;
			[self getMessageStreamState:&state errorString:NULL connectionID:NULL];
			[self setMessageStreamState:state errorString:errorText];
			
			// This may be an indication that the active_st_device has changed.
			// Post notification so we can check.
			
			[self notifyLocalUserActiveDeviceMayHaveChanged];
		}
	}
}

/**
 * This method is called after the stream is closed.
 *
 * The given error parameter will be non-nil if the error was due to something outside the general xmpp realm.
 * Some examples:
 * - The TCP socket was unexpectedly disconnected.
 * - The SRV resolution of the domain failed.
 * - Error parsing xml sent from server.
 *
 * @see xmppStreamConnectDidTimeout:
**/
- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
    DDLogTrace(@"xmppStreamDidDisconnect:withError: %@ ", error.localizedDescription);
    
#if DEBUG
	_tempAsyncSocket = nil;
#endif
	
	connectedHostName = nil;
	connectedHostPort = 0;
	
	MessageStream_State state;
	NSString *errorString = nil;
	[self getMessageStreamState:&state errorString:&errorString connectionID:NULL];
	
	if (error || errorString)
		state = MessageStream_State_Error;
	else
		state = MessageStream_State_Disconnected;
	
	if (errorString == nil) {
		errorString = error ? error.localizedDescription : nil;
	}
	
	[self setMessageStreamState:state errorString:errorString];

    if (!replacedByNewConnection)
    {
		// Sometimes we're unable to connect when the app launches,
		// or when the app returns from the background.
		// This is because the network isn't available.
		// And in the case of returning from background, the network stack may not be back up yet.
		//
		// So when this happens, we need to manually start the reconnect module.
		// This is because the reconnect module only kicks in automatically when it detects an accidental disconnect.
		// But when the app transitions to background mode, it purposefully disconnects the xmppStream.
		// And since this is a non-accidental disconnection, the reconnect module goes into disabled mode.
		//
		// So we manually turn it back on in this circumstance.
		
	#if TARGET_OS_IPHONE
	
		UIApplicationState appState = [[UIApplication sharedApplication] applicationState];
		if (appState == UIApplicationStateActive)
		{
			[xmppReconnect manualStart];
		}
		
	#else
		
		[xmppReconnect manualStart];
		
    #endif
    }
	
	// Dump the secure context information from RAM
	[self flushScimpCache];
	
	if (self.isKilled)
	{
		// Break retain loop (xmppStreamManagement retains self as storage property)
		
		[xmppReconnect deactivate];
		[xmppStreamManagement deactivate];
		
		xmppReconnect = nil;
		xmppStreamManagement = nil;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPReconnect Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)xmppReconnect:(XMPPReconnect *)sender shouldAttemptAutoReconnect:(SCNetworkReachabilityFlags)reachabilityFlags
{
    DDLogAutoTrace();
    
	// We handle reconnecting ourself, so we can go through the SRV manager properly.
	//
	// Note: In the future I plan on expanding XMPPStream's SRV algorithm.
	//       This is part of ST-716.
	//       And in doing so, our own SRV manage will become integrated into XMPPStream,
	//       and hopefully we won't have to rely upon this hack anymore.
	
	if (!self.isKilled)
	{
		MessageStream_State state;
		[self getMessageStreamState:&state errorString:NULL connectionID:NULL];
		
		if (state == MessageStream_State_Disconnected ||
		    state == MessageStream_State_Error         )
		{
			[self connect];
		}
	}
	
    return NO;
}

- (void)xmppReconnect:(XMPPReconnect *)sender didDetectAccidentalDisconnect:(SCNetworkReachabilityFlags)connectionFlags
{
	DDLogAutoTrace();
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark XMPPStreamManagement Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Notifies delegate(s) of the server's response from sending the <enable> stanza.
**/
- (void)xmppStreamManagement:(XMPPStreamManagement *)sender wasEnabled:(NSXMLElement *)enabled
{
	DDLogAutoTrace();
}

/**
 * Notifies delegate(s) of the server's response from sending the <enable> stanza.
**/
- (void)xmppStreamManagement:(XMPPStreamManagement *)sender wasNotEnabled:(NSXMLElement *)failed
{
	DDLogAutoTrace();
	
	DDLogError(@"Unable to enable stream management: %@", failed);
}

/**
 * Invoked when an ack is received from the server, and new stanzas have been acked.
 * 
 * @param stanzaIds
 *   Includes all "stanzaIds" of sent elements that were just acked.
 *
 * What is a "stanzaId" ?
 * 
 * A stanzaId is a unique identifier that ** YOU can provide ** in order to track an element.
 * It could simply be the elementId of the sent element. Or,
 * it could be something custom that you provide in order to properly lookup a message in your data store.
 * 
 * For more information, see the delegate method xmppStreamManagement:stanzaIdForSentElement:
**/
- (void)xmppStreamManagement:(XMPPStreamManagement *)sender didReceiveAckForStanzaIds:(NSArray *)stanzaIds
{
	DDLogAutoTrace();
	
	if ([stanzaIds count] == 0) return;
	
	DDLogPink(@"didReceiveAckForStanzaIds: %@", stanzaIds);
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		NSDate *now = [NSDate date];
		
		for (id stanzaId in stanzaIds)
		{
			__block id object = nil;
			__block NSString *key = nil;
			__block NSString *collection = nil;
			
			if ([stanzaId isKindOfClass:[YapCollectionKey class]])
			{
				// We can do a quick lookup using the collection/key tuple
				
				__unsafe_unretained YapCollectionKey *ck = (YapCollectionKey *)stanzaId;
				
				object = [transaction objectForKey:ck.key inCollection:ck.collection];
				key = ck.key;
				collection = ck.collection;
			}
			else if ([stanzaId isKindOfClass:[NSString class]])
			{
				// Slower lookup using only a known key
				
				__unsafe_unretained NSString *elementId = (NSString *)stanzaId;
				
				[transaction enumerateCollectionsForKey:elementId usingBlock:^(NSString *aCollection, BOOL *stop) {
					
					id anObject = [transaction objectForKey:elementId inCollection:aCollection];
					if ([anObject isKindOfClass:[STMessage class]] ||
					    [anObject isKindOfClass:[STXMPPElement class]])
					{
						object = anObject;
						key = elementId;
						collection = collection;
						
						*stop = YES;
					}
				}];
			}
			
			if ([object isKindOfClass:[STMessage class]])
			{
				STMessage *message = [(STMessage *)object copy];
				
				DDLogPink(@"Marking ack for message: %@", message.uuid);
				
				message.serverAckDate = now;
				
				if (message.sendDate == nil)
					message.sendDate = now;
				
				[transaction setObject:message
				                forKey:message.uuid
				          inCollection:message.conversationId];
			}
			else if ([object isKindOfClass:[STXMPPElement class]])
			{
				__unsafe_unretained STXMPPElement *element = (STXMPPElement *)object;
				
				DDLogPink(@"Marking ack for stanza: elementID = %@", element.uuid);
				
				[transaction removeObjectForKey:key
				                   inCollection:collection]; // <-- STXMPPElement used to use a custom collection
			}
		}
	}];
}

/**
 * XEP-0198 reports the following regarding duplicate stanzas:
 *
 *     Because unacknowledged stanzas might have been received by the other party,
 *     resending them might result in duplicates; there is no way to prevent such a
 *     result in this protocol, although use of the XMPP 'id' attribute on all stanzas
 *     can at least assist the intended recipients in weeding out duplicate stanzas.
 * 
 * In other words, there are edge cases in which you might receive duplicates.
 * And the proper way to fix this is to use some kind of identifier in order to detect duplicates.
 * 
 * What kind of identifier to use is up to you. (It's app specific.)
 * The XEP notes that you might use the 'id' attribute for this purpose. And this is certainly the most common case.
 * However, you may have an alternative scheme that works better for your purposes.
 * In which case you can use this delegate method to opt-in.
 * 
 * For example:
 *   You store all your messages in YapDatabase, which is a collection/key/value storage system.
 *   Perhaps the collection is the conversationId, and the key is a messageId.
 *   Therefore, to efficiently lookup a message in your datastore you'd prefer a collection/key tuple.
 *
 *   To achieve this, you would implement this method, and return a YapCollectionKey object for message elements.
 *   This way, when the xmppStreamManagement:didReceiveAckForStanzaIds: method is invoked,
 *   you'll get a list that contains your collection/key tuple objects. And then you can quickly and efficiently
 *   fetch and update your message objects.
 * 
 * If there are no delegates that implement this method,
 * or all delegates return nil, then the stanza's elementId is used.
 *
 * If the stanza isn't assigned a stanzaId (via a delegate method),
 * and it doesn't have an elementId, then it isn't reported in the acked stanzaIds array.
**/
- (id)xmppStreamManagement:(XMPPStreamManagement *)sender stanzaIdForSentElement:(XMPPElement *)element
{
	DDLogAutoTrace();
	
	// When we send an xmpp element,
	// we can associate the elementID with a full YapCollectionKey.
	//
	// This can then be used as the stanzaId, which will make database lookups faster in
	// xmppStreamManagement:didReceiveAckForStanzaIds:
	//
	// Note: This is an optimization ONLY. It is NOT a requirement.
	
	NSString *messageID = [element elementID];
	if (messageID)
	{
		NSString *threadID = nil;
		if ([element isKindOfClass:[XMPPMessage class]])
		{
			threadID = [(XMPPMessage *)element threadID];
		}
		
		NSString *conversationID = nil;
		if (threadID)
		{
			conversationID = [self conversationIDForThreadID:threadID];
		}
		else
		{
			XMPPJID *to = [element to];
			if (to)
			{
				conversationID = [self conversationIDForRemoteJid:to];
			}
		}
		
		if (conversationID)
		{
			return YapCollectionKeyCreate(conversationID, messageID);
		}
	}
	
	return nil;
}

/**
 * It's critically important to understand what an ACK means.
 *
 * Every ACK contains an 'h' attribute, which stands for "handled".
 * To paraphrase XEP-0198 (in client-side terminology):
 *
 *   Acknowledging a previously ­received element indicates that the stanza has been "handled" by the client.
 *   By "handled" we mean that the client has successfully processed the stanza
 *   (including possibly saving the item to the database if needed);
 *   Until a stanza has been affirmed as handled by the client, that stanza is the responsibility of the server
 *   (e.g., to resend it or generate an error if it is never affirmed as handled by the client).
 *
 * This means that if your processing of certain elements includes saving them to a database,
 * then you should not mark those elements as handled until after your database has confirmed the data is on disk.
 *
 * You should note that this is a critical component of any networking app that claims to have "reliable messaging".
 *
 * By default, all elements will be marked as handled as soon as they arrive.
 * You'll want to override the default behavior for important elements that require proper handling by your app.
 * For example, messages that need to be saved to the database.
 * Here's how to do so:
 *
 * - Implement the delegate method xmppStreamManagement:getIsHandled:stanzaId:forReceivedElement:
 *
 *   This method is invoked for all received elements.
 *   You can inspect the element, and if it is important and requires special handling by the app,
 *   then flag the element as NOT handled (overriding the default).
 *   Also assign the element a "stanzaId". This can be anything you want, such as the elementID,
 *   or maybe something more app-specific (e.g. something you already use that's associated with the message).
 *
 * - Handle the important element however you need to
 *
 *   If you're saving something to the database,
 *   then wait until after the database commit has completed successfully.
 *
 * - Notify the module that the element has been handled via the method markHandledStanzaId:
 *
 *   You must pass the stanzaId that you returned from the delegate method.
 *
 *
 * @see markHandledStanzaId:
**/
- (void)xmppStreamManagement:(XMPPStreamManagement *)sender
                getIsHandled:(BOOL *)isHandledPtr
                    stanzaId:(id *)stanzaIdPtr
          forReceivedElement:(XMPPElement *)element
{
	DDLogAutoTrace();
	
	if ([element isKindOfClass:[XMPPMessage class]])
	{
		// Will be marked as handled via [MessageStream xmppStream:didReceiveMessage:]
		*isHandledPtr = NO;
		*stanzaIdPtr = [element elementID];
	}
	else
	{
		*isHandledPtr = YES;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStreamManagementStorage Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Configures the storage class, passing it's parent and the parent's dispatch queue.
 *
 * This method is called by the init methods of the XMPPStreamManagement class.
 * This method is designed to inform the storage class of it's parent
 * and of the dispatch queue the parent will be operating on.
 *
 * A storage class may choose to operate on the same queue as it's parent,
 * as the majority of the time it will be getting called by the parent.
 * If both are operating on the same queue, the combination may run faster.
 *
 * Some storage classes support multiple xmppStreams,
 * and may choose to operate on their own internal queue.
 *
 * This method should return YES if it was configured properly.
 * It should return NO only if configuration failed.
 * For example, a storage class designed to be used only with a single xmppStream is being added to a second stream.
**/
- (BOOL)configureWithParent:(XMPPStreamManagement *)parent queue:(dispatch_queue_t)queue
{
	return YES;
}

/**
 * Invoked after we receive <enabled/> from the server.
 * 
 * @param resumptionId
 *   The ID required to resume the session, given to us by the server.
 *   
 * @param timeout
 *   The timeout in seconds.
 *   After a disconnect, the server will maintain our state for this long.
 *   If we attempt to resume the session after this timeout it likely won't work.
 * 
 * @param lastDisconnect
 *   Used to reset the lastDisconnect value.
 *   This value is often updated during the session, to ensure it closely resemble the date the server will use.
 *   That is, if the client application is killed (or crashes) we want a relatively accurate lastDisconnect date.
 * 
 * @param stream
 *   The associated xmppStream (standard parameter for storage classes)
 * 
 * This method should also nil out the following values (if needed) associated with the account:
 * - lastHandledByClient
 * - lastHandledByServer
 * - pendingOutgoingStanzas
**/
- (void)setResumptionId:(NSString *)resumptionId
                timeout:(uint32_t)timeout
         lastDisconnect:(NSDate *)date
              forStream:(XMPPStream *)stream;
{
	DDLogTrace(@"%@ <XMPPStreamManagementStorage>", THIS_METHOD);
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STStreamManagement *sm = [transaction objectForKey:localUserID inCollection:kSCCollection_STStreamManagement];
		if (sm == nil)
			sm = [[STStreamManagement alloc] init];
		else
			sm = [sm copy];
		
		sm.resumptionId = resumptionId;
		sm.timeout = timeout;
		sm.lastDisconnect = date;
		
		sm.lastHandledByClient = 0;
		sm.lastHandledByServer = 0;
		sm.pendingOutgoingStanzas = nil;
		
		[transaction setObject:sm forKey:localUserID inCollection:kSCCollection_STStreamManagement];
	}];
}

/**
 * This method is invoked ** often ** during stream operation.
 * It is not invoked when the xmppStream is disconnected.
 *
 * Important: See the note [in XMPPStreamManagement.h]: "Optimizing storage demands during active stream usage"
 * 
 * @param date
 *   Updates the previous lastDisconnect value.
 *
 * @param lastHandledByClient
 *   The most recent 'h' value we can safely send to the server.
 * 
 * @param stream
 *   The associated xmppStream (standard parameter for storage classes)
**/
- (void)setLastDisconnect:(NSDate *)date
      lastHandledByClient:(uint32_t)lastHandledByClient
                forStream:(XMPPStream *)stream
{
	DDLogTrace(@"%@ <XMPPStreamManagementStorage>", THIS_METHOD);
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STStreamManagement *sm = [transaction objectForKey:localUserID inCollection:kSCCollection_STStreamManagement];
		if (sm == nil)
			sm = [[STStreamManagement alloc] init];
		else
			sm = [sm copy];
		
		sm.lastDisconnect = date;
		sm.lastHandledByClient = lastHandledByClient;
		
		[transaction setObject:sm forKey:localUserID inCollection:kSCCollection_STStreamManagement];
	}];
}

/**
 * This method is invoked ** often ** during stream operation.
 * It is not invoked when the xmppStream is disconnected.
 * 
 * Important: See the note [in XMPPStreamManagement.h]: "Optimizing storage demands during active stream usage"
 *
 * @param date
 *   Updates the previous lastDisconnect value.
 *
 * @param lastHandledByServer
 *   The most recent 'h' value we've received from the server.
 *
 * @param pendingOutgoingStanzas
 *   An array of XMPPStreamManagementOutgoingStanza objects.
 *   The storage layer is in charge of properly persisting this array, including:
 *   - the array count
 *   - the stanzaId of each element, including those that are nil
 * 
 * @param stream
 *   The associated xmppStream (standard parameter for storage classes)
**/
- (void)setLastDisconnect:(NSDate *)date
      lastHandledByServer:(uint32_t)lastHandledByServer
   pendingOutgoingStanzas:(NSArray *)pendingOutgoingStanzas
                forStream:(XMPPStream *)stream
{
	DDLogTrace(@"%@ <XMPPStreamManagementStorage>", THIS_METHOD);
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STStreamManagement *sm = [transaction objectForKey:localUserID inCollection:kSCCollection_STStreamManagement];
		if (sm == nil)
			sm = [[STStreamManagement alloc] init];
		else
			sm = [sm copy];
		
		sm.lastHandledByServer = lastHandledByServer;
		sm.pendingOutgoingStanzas = pendingOutgoingStanzas;
		
		[transaction setObject:sm forKey:localUserID inCollection:kSCCollection_STStreamManagement];
	}];
}

/**
 * This method is invoked immediately after an accidental disconnect.
 * And may be invoked post-disconnect if the state changes, such as for the following edge cases:
 * 
 * - due to continued processing of stanzas received pre-disconnect,
 *   that are just now being marked as handled by the delegate(s)
 * - due to a delayed response from the delegate(s),
 *   such that we didn't receive the stanzaId for an outgoing stanza until after the disconnect occurred.
 * 
 * This method is not invoked if stream management is started on a connected xmppStream.
 *
 * @param date
 *   This value will be the actual disconnect date.
 * 
 * @param lastHandledByClient
 *   The most recent 'h' value we can safely send to the server.
 * 
 * @param lastHandledByServer
 *   The most recent 'h' value we've received from the server.
 * 
 * @param pendingOutgoingStanzas
 *   An array of XMPPStreamManagementOutgoingStanza objects.
 *   The storage layer is in charge of properly persisting this array, including:
 *   - the array count
 *   - the stanzaId of each element, including those that are nil
 * 
 * @param stream
 *   The associated xmppStream (standard parameter for storage classes)
**/
- (void)setLastDisconnect:(NSDate *)date
      lastHandledByClient:(uint32_t)lastHandledByClient
      lastHandledByServer:(uint32_t)lastHandledByServer
   pendingOutgoingStanzas:(NSArray *)pendingOutgoingStanzas
                forStream:(XMPPStream *)stream
{
	DDLogTrace(@"%@ <XMPPStreamManagementStorage>", THIS_METHOD);
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STStreamManagement *sm = [transaction objectForKey:localUserID inCollection:kSCCollection_STStreamManagement];
		if (sm == nil)
			sm = [[STStreamManagement alloc] init];
		else
			sm = [sm copy];
		
		sm.lastDisconnect = date;
		sm.lastHandledByClient = lastHandledByClient;
		sm.lastHandledByServer = lastHandledByServer;
		sm.pendingOutgoingStanzas = pendingOutgoingStanzas;
		
		[transaction setObject:sm forKey:localUserID inCollection:kSCCollection_STStreamManagement];
	}];
}

/**
 * Invoked when the extension needs values from a previous session.
 * This method is used to get values needed in order to determine if it can resume a previous stream.
**/
- (void)getResumptionId:(NSString **)resumptionIdPtr
                timeout:(uint32_t *)timeoutPtr
         lastDisconnect:(NSDate **)lastDisconnectPtr
              forStream:(XMPPStream *)stream
{
	DDLogTrace(@"%@ <XMPPStreamManagementStorage>", THIS_METHOD);
	
	__block STStreamManagement *sm = nil;
	
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		sm = [transaction objectForKey:localUserID inCollection:kSCCollection_STStreamManagement];
	}];
	
	if (resumptionIdPtr)  *resumptionIdPtr    = sm.resumptionId;
	if (timeoutPtr)        *timeoutPtr        = sm.timeout;
	if (lastDisconnectPtr) *lastDisconnectPtr = sm.lastDisconnect;
}

/**
 * Invoked when the extension needs values from a previous session.
 * This method is used to get values needed in order to resume a previous stream.
**/
- (void)getLastHandledByClient:(uint32_t *)lastHandledByClientPtr
           lastHandledByServer:(uint32_t *)lastHandledByServerPtr
        pendingOutgoingStanzas:(NSArray **)pendingOutgoingStanzasPtr
                     forStream:(XMPPStream *)stream
{
	DDLogTrace(@"%@ <XMPPStreamManagementStorage>", THIS_METHOD);
	
	__block STStreamManagement *sm = nil;
	
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		sm = [transaction objectForKey:localUserID inCollection:kSCCollection_STStreamManagement];
	}];
	
	if (lastHandledByClientPtr)    *lastHandledByClientPtr    = sm.lastHandledByClient;
	if (lastHandledByServerPtr)    *lastHandledByServerPtr    = sm.lastHandledByServer;
	if (pendingOutgoingStanzasPtr) *pendingOutgoingStanzasPtr = sm.pendingOutgoingStanzas;
}

/**
 * Instructs the storage layer to remove all values stored for the given stream.
 * This occurs after the extension detects a "cleanly closed stream",
 * in which case the stream cannot be resumed next time.
**/
- (void)removeAllForStream:(XMPPStream *)stream
{
	DDLogTrace(@"%@ <XMPPStreamManagementStorage>", THIS_METHOD);
	
	[databaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		[transaction removeObjectForKey:localUserID inCollection:kSCCollection_STStreamManagement];
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Siren Security
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method decodes, processes & returns the siren.signature information.
 * The returned dictionary is designed to be stored in the STMessage.signatureInfo property.
 *
 * The keys for the dictionary are listed in STMessage.h:
 * - kSigInfo_keyFound
 * - kSigInfo_owner
 * - kSigInfo_expireDate
 * - kSigInfo_calculatedHash
 * - kSigInfo_valid
 *
 * There are other key/value pairs in the dictionary too.
 * But they appear to be undocumented...
**/
- (NSDictionary *)signatureInfoFromSiren:(Siren *)siren withTransaction:(YapDatabaseReadTransaction *)transaction
{
	if (siren.signature == nil) return nil;
    
    NSData *signatureData = [siren.signature dataUsingEncoding:NSUTF8StringEncoding];
	
	NSError *error = nil;
	NSMutableDictionary *signatureInfo = [NSJSONSerialization JSONObjectWithData:signatureData
	                                                                     options:NSJSONReadingMutableContainers
	                                                                       error:&error];
	
	if (signatureInfo && !error)
	{
		[signatureInfo removeObjectForKey:kSigInfo_calculatedHash];   // dont allow any hacking here..
        
        NSString *signingKeyID = [signatureInfo objectForKey:@"signed_by"];
	//	NSString *signature    = [signatureInfo objectForKey:@"signature"];
		
		STPublicKey *signingKey = [transaction objectForKey:signingKeyID inCollection:kSCCollection_STPublicKeys];
		
		[signatureInfo setObject:(signingKey ? @(YES) : @(NO)) forKey:kSigInfo_keyFound];
		
		NSData *hashData = [siren sigSHA256Hash];
		[signatureInfo setObject:hashData forKey:kSigInfo_calculatedHash];
		
		SCKeyContextRef signCtx = kInvalidSCKeyContextRef;
		SCKey_Deserialize(signingKey.keyJSON, &signCtx);
		
		if (SCKeyContextRefIsValid(signCtx))
        {
            [signatureInfo setObject:signingKey.owner forKey:kSigInfo_owner];
			
			NSDate *expireDate = signingKey.expireDate;
			if (expireDate)
			{
				[signatureInfo setObject:expireDate forKey:kSigInfo_expireDate];
			}
 
			SCLError err = SCKeyVerify(signCtx, (uint8_t *)hashData.bytes, hashData.length,
			                                    (uint8_t *)signatureData.bytes, signatureData.length);
			
			[signatureInfo setObject:(IsSCLError(err) ? @(FALSE) : @(TRUE)) forKey:kSigInfo_valid];
			
			SCKeyFree(signCtx);
		}
	}

	return signatureInfo;
}

/**
 * 
**/
- (NSString *)signSiren:(Siren *)siren withPublicKey:(STPublicKey *)publicKey
{
	NSString * sigString = nil;
    SCLError   err       = kSCLError_NoErr;
	
	SCKeyContextRef key = kInvalidSCKeyContextRef;
	err = SCKey_Deserialize(publicKey.keyJSON, &key); CKERR;
	
	if (SCKeyContextRefIsValid(key))
	{
		bool isLocked = true;
        uint8_t* sigData = NULL;
        size_t   sigDataLen = 0;
        
        err = SCKeyIsLocked(key,&isLocked);
        if (isLocked)
		{
			err = SCKeyUnlockWithSCKey(key, STAppDelegate.storageKey); CKERR;
		}
        
        NSData *hashData = siren.sigSHA256Hash;
        
        err = SCKeySign(key, (void *)hashData.bytes, hashData.length, &sigData, &sigDataLen); CKERR;
		
        sigString = [[NSString alloc] initWithBytesNoCopy:sigData
		                                           length:sigDataLen
		                                         encoding:NSUTF8StringEncoding
		                                     freeWhenDone:YES];
	}
    
done:
	
	if (SCKeyContextRefIsValid(key))
	{
		SCKeyFree(key);
		key = kInvalidSCKeyContextRef;
	}
	
    return sigString;
}

@end
