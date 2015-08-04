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
#import "STConversation.h"
#import "AppConstants.h"
#import "NSDate+SCDate.h"

/**
 * Keys for encoding / decoding (to avoid typos)
**/
static NSString *const k_version                      = @"version";
static NSString *const k_uuid                         = @"uuid";
static NSString *const k_userId                       = @"userId";
static NSString *const k_scimpStateIDs                = @"scimpStateIDs";
static NSString *const k_isMulticast                  = @"isMultiCast";
static NSString *const k_isNewMessage                 = @"isNewMessage";
static NSString *const k_isFakeStream                 = @"isFakeStream";
static NSString *const k_hidden                       = @"hidden";
static NSString *const k_fyeo                         = @"fyeo";
static NSString *const k_shouldBurn                   = @"shouldBurn";
static NSString *const k_shredAfter                   = @"shredAfter";
static NSString *const k_sendReceipts                 = @"sendReceipts";
static NSString *const k_notificationDate             = @"notificationDate";
static NSString *const k_trackUntil                   = @"trackUntil";
static NSString *const k_mostRecentDeliveredTimestamp = @"mostRecentDeliveredTimestamp";
static NSString *const k_mostRecentDeliveredMessageID = @"mostRecentDeliveredMessageID";
static NSString *const k_remoteJID                    = @"remoteJID";
static NSString *const k_localJID                     = @"localJID";
static NSString *const k_multicastJidSet              = @"multicastJidSet";
static NSString *const k_keyLocator                   = @"keyLocator";
static NSString *const k_threadID                     = @"threadID";
static NSString *const k_title                        = @"title";
static NSString *const k_capabilities                 = @"capabilities";
static NSString *const k_lastUpdated                  = @"lastUpdated";

static NSString *const k_deprecated_tracking          = @"tracking";      // replaced by trackUntil
static NSString *const k_deprecated_remoteJidStr      = @"remoteJid";     // replaced by remoteJID (XMPPJID)
static NSString *const k_deprecated_localJidStr       = @"localJid";      // replaced by localJID  (XMPPJID)
static NSString *const k_deprecated_multicastJids     = @"multicastJids"; // replaced by multicastJidSet (XMPPJIDSet)


@implementation STConversation

@synthesize uuid = uuid;
@synthesize userId = userId;

@synthesize scimpStateIDs = scimpStateIDs;

@synthesize isMulticast = isMulticast;
@synthesize isNewMessage = isNewMessage;
@synthesize isFakeStream = isFakeStream;
@synthesize hidden = hidden;

@synthesize fyeo = fyeo;
@synthesize shouldBurn = shouldBurn;
@synthesize shredAfter = shredAfter;
@synthesize sendReceipts = sendReceipts;
@synthesize notificationDate = notificationDate;
@synthesize trackUntil = trackUntil;

@synthesize mostRecentDeliveredTimestamp = mostRecentDeliveredTimestamp;
@synthesize mostRecentDeliveredMessageID = mostRecentDeliveredMessageID;

@synthesize remoteJid = remoteJid;
@synthesize localJid = localJid;

@synthesize multicastJidSet = multicastJidSet;
@synthesize keyLocator = keyLocator;
@synthesize threadID = threadID;
@synthesize title = title;

@synthesize capabilities = capabilities;

@synthesize lastUpdated = lastUpdated;


#pragma mark Init

/**
 * Designated initializer
**/
- (id)initWithUUID:(NSString *)inUUID localUserID:(NSString *)inUserId
{
  	if ((self = [super init]))
	{
		uuid   = [inUUID copy];
		userId = [inUserId copy];
        
		scimpStateIDs = [[NSSet alloc] init];
		
		isMulticast  = NO;
        isNewMessage = NO;
        isFakeStream = NO;
		hidden       = NO;
		
		trackUntil       = [NSDate distantPast];
		fyeo             = NO;
		shouldBurn       = NO;
		shredAfter       = kShredAfterNever;
		sendReceipts     = YES;
		notificationDate = [NSDate distantPast];
		
        remoteJid = nil;
        localJid  = nil;
        
		multicastJidSet = nil;
		keyLocator      = nil;
		threadID        = nil;
        title           = nil;
		
		capabilities = [NSDictionary dictionary];
		
		lastUpdated = [NSDate date];
	}
	return self;
}

- (id)initAsNewMessageWithUUID:(NSString *)inUUID userId:(NSString *)inLocalUserID
{
	if ((self = [self initWithUUID:inUUID localUserID:inLocalUserID])) // invoke designated initializer
	{
		isNewMessage = YES;
		lastUpdated = [NSDate distantFuture]; // Always at top of conversations list
    }
    return self;
}

- (id)initWithUUID:(NSString *)inUUID
       localUserID:(NSString *)inLocalUserID
          localJID:(XMPPJID *)inLocalJID
		 remoteJID:(XMPPJID *)inRemoteJID
{
	if ((self = [self initWithUUID:inUUID localUserID:inLocalUserID])) // invoke designated initializer
	{
		localJid = [inLocalJID bareJID];
		remoteJid = inRemoteJID;
	}
	return self;
}

- (id)initWithUUID:(NSString *)inUUID
       localUserID:(NSString *)inLocalUserID
          localJID:(XMPPJID *)inLocalJID
          threadID:(NSString *)inThreadID
{
	if ((self = [self initWithUUID:inUUID localUserID:inLocalUserID])) // invoke designated initializer
	{
		localJid = [inLocalJID bareJID];
		threadID = [inThreadID copy];
		isMulticast = YES;
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSCoding
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * NSCoding Change Log:
 * 
 * Version 1:
 * - Modernization: directly store primitives instead of wrapping in NSNumber
 *
 * Version 2:
 * - changed from tracking (YES/NO) to trackUntil (NSDate)
 *
 * Version 3:
 * - converted remoteJid from NSString to XMPPJID
 * - converted localJid from NSString to XMPPJID
 * 
 * Version 4:
 * - converted (NSSet)multicastJids to (XMPPJIDSet)multicastJidSet
**/

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		int32_t version = [decoder decodeInt32ForKey:@"version"];
	
		if (version >= 1)
		{
			uuid   = [decoder decodeObjectForKey:k_uuid];
			userId = [decoder decodeObjectForKey:k_userId];
			
			scimpStateIDs = [decoder decodeObjectForKey:k_scimpStateIDs];
			
			isMulticast  = [decoder decodeBoolForKey:k_isMulticast];
			isNewMessage = [decoder decodeBoolForKey:k_isNewMessage];
			isFakeStream = [decoder decodeBoolForKey:k_isFakeStream];
			hidden       = [decoder decodeBoolForKey:k_hidden];
			
			fyeo             = [decoder decodeBoolForKey:k_fyeo];
			shouldBurn       = [decoder decodeBoolForKey:k_shouldBurn];
			shredAfter       = [decoder decodeInt32ForKey:k_shredAfter];
			sendReceipts     = [decoder decodeBoolForKey:k_sendReceipts];
			notificationDate = [decoder decodeObjectForKey:k_notificationDate];
			
			if (version == 1)
			{
				BOOL tracking = [[decoder decodeObjectForKey:k_deprecated_tracking] boolValue];
				trackUntil = tracking ? [NSDate distantFuture] : [NSDate distantPast];
			}
			else // if (version >= 2)
			{
				trackUntil  = [decoder decodeObjectForKey:k_trackUntil];
			}
			
			mostRecentDeliveredTimestamp = [decoder decodeObjectForKey:k_mostRecentDeliveredTimestamp];
			mostRecentDeliveredMessageID = [decoder decodeObjectForKey:k_mostRecentDeliveredMessageID];
			
			if (version >= 3)
			{
				remoteJid = [decoder decodeObjectForKey:k_remoteJID];
				localJid  = [decoder decodeObjectForKey:k_localJID];
			}
			else // if (version <= 2)
			{
				NSString *remoteJidStr = [decoder decodeObjectForKey:k_deprecated_remoteJidStr];
				NSString *localJidStr  = [decoder decodeObjectForKey:k_deprecated_localJidStr];
				
				if (IsSTInfoJidStr(remoteJidStr))
					remoteJid = [AppConstants stInfoJID];
				else if (IsOCAVoicemailJidStr(remoteJidStr))
					remoteJid = [AppConstants ocaVoicemailJID];
				else
					remoteJid = [XMPPJID jidWithString:remoteJidStr];
				
				if (IsSTInfoJidStr(localJidStr))
					localJid = [AppConstants stInfoJID];
				else if (IsOCAVoicemailJidStr(localJidStr))
					localJid = [AppConstants ocaVoicemailJID];
				else
					localJid = [XMPPJID jidWithString:localJidStr];
			}
			
			if (version >= 4)
			{
				multicastJidSet = [decoder decodeObjectForKey:k_multicastJidSet];
			}
			else // if (version <= 3)
			{
				NSSet *multicastJids = [decoder decodeObjectForKey:k_deprecated_multicastJids];
				if ([multicastJids isKindOfClass:[NSArray class]])
					multicastJidSet = [[XMPPJIDSet alloc] initWithJids:(NSArray *)multicastJids];
				else if ([multicastJids isKindOfClass:[NSSet class]])
					multicastJidSet = [[XMPPJIDSet alloc] initWithJidSet:(NSSet *)multicastJids];
				else
					multicastJidSet = nil;
			}
			
			keyLocator    = [decoder decodeObjectForKey:k_keyLocator];
			threadID      = [decoder decodeObjectForKey:k_threadID];
            title      = [decoder decodeObjectForKey:k_title];
		
			capabilities = [decoder decodeObjectForKey:k_capabilities];
			
			lastUpdated = [decoder decodeObjectForKey:k_lastUpdated];
		}
		else  // version 0
		{
			// Do Not Change - Version 0 decoding must match whatever version 0 encoding was.
			// >>
			
			uuid   = [decoder decodeObjectForKey:k_uuid];
			userId = [decoder decodeObjectForKey:k_userId];
 			
			NSArray *scimpIds = [decoder decodeObjectForKey:k_scimpStateIDs];        // v0 stored as array
			scimpStateIDs = [NSSet setWithArray:scimpIds];
			
			isMulticast  = [[decoder decodeObjectForKey:k_isMulticast] boolValue];   // v0 stored as NSNumber
            isNewMessage = [[decoder decodeObjectForKey:k_isNewMessage] boolValue];  // v0 stored as NSNumber
            isFakeStream = [[decoder decodeObjectForKey:k_isFakeStream] boolValue];  // v0 stored as NSNumber
			
            BOOL tracking = [[decoder decodeObjectForKey:k_deprecated_tracking] boolValue];
			trackUntil = tracking ? [NSDate distantFuture] : [NSDate distantPast];

			fyeo             = [[decoder decodeObjectForKey:k_fyeo] boolValue];               // v0 stored as NSNumber
			shouldBurn       = [[decoder decodeObjectForKey:k_shouldBurn] boolValue];         // v0 stored as NSNumber
			shredAfter       = [[decoder decodeObjectForKey:k_shredAfter] unsignedIntValue];  // v0 stored as NSNumber
			sendReceipts     = [decoder decodeBoolForKey:k_sendReceipts];        // was this changed ?
            notificationDate = [decoder decodeObjectForKey:k_notificationDate];
			
			NSString *remoteJidStr = [decoder decodeObjectForKey:k_deprecated_remoteJidStr];
			NSString *localJidStr = [decoder decodeObjectForKey:k_deprecated_localJidStr];
			
			remoteJid = [XMPPJID jidWithString:remoteJidStr];
			localJid  = [XMPPJID jidWithString:localJidStr];
			
			id multicastJids = [decoder decodeObjectForKey:k_deprecated_multicastJids];
			if ([multicastJids isKindOfClass:[NSArray class]])
				multicastJidSet = [[XMPPJIDSet alloc] initWithJids:(NSArray *)multicastJids];
			else if ([multicastJids isKindOfClass:[NSSet class]])
				multicastJidSet = [[XMPPJIDSet alloc] initWithJidSet:(NSSet *)multicastJids];
			else
				multicastJidSet = nil;
			
			keyLocator    = [decoder decodeObjectForKey:k_keyLocator];
			threadID      = [decoder decodeObjectForKey:k_threadID];
            title         = [decoder decodeObjectForKey:k_title];
			
            capabilities = [decoder decodeObjectForKey:k_capabilities];
			
			lastUpdated = [decoder decodeObjectForKey:k_lastUpdated];
			
			// <<
			// Do Not Change - Version 0 decoding must match whatever version 0 encoding was.
		}
		
		// Sanity checks
		
		if (keyLocator == nil) keyLocator = @"";
		if (threadID == nil) threadID = @"";
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	// Changes:
	
	[coder encodeInt32:4 forKey:k_version];

	[coder encodeObject:uuid   forKey:k_uuid];
	[coder encodeObject:userId forKey:k_userId];
	
    [coder encodeObject:scimpStateIDs forKey:k_scimpStateIDs];
	
	[coder encodeBool:isMulticast  forKey:k_isMulticast];
	[coder encodeBool:isNewMessage forKey:k_isNewMessage];
	[coder encodeBool:isFakeStream forKey:k_isFakeStream];
	[coder encodeBool:hidden       forKey:k_hidden];
	
	[coder encodeBool:fyeo               forKey:k_fyeo];
	[coder encodeBool:shouldBurn         forKey:k_shouldBurn];
	[coder encodeInt32:shredAfter        forKey:k_shredAfter];
	[coder encodeBool:sendReceipts       forKey:k_sendReceipts];
	[coder encodeObject:notificationDate forKey:k_notificationDate];
    [coder encodeObject:trackUntil       forKey:k_trackUntil];
	
 	[coder encodeObject:mostRecentDeliveredTimestamp forKey:k_mostRecentDeliveredTimestamp];
    [coder encodeObject:mostRecentDeliveredMessageID forKey:k_mostRecentDeliveredMessageID];
    
    [coder encodeObject:remoteJid  forKey:k_remoteJID];
	[coder encodeObject:localJid   forKey:k_localJID];

	[coder encodeObject:multicastJidSet forKey:k_multicastJidSet];
	[coder encodeObject:keyLocator      forKey:k_keyLocator];
    [coder encodeObject:threadID        forKey:k_threadID];
	[coder encodeObject:title           forKey:k_title];
	
 	[coder encodeObject:capabilities forKey:k_capabilities];

	[coder encodeObject:lastUpdated forKey:k_lastUpdated];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSCopying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
{
	STConversation *copy = [super copyWithZone:zone];
	
	copy->uuid   = uuid;
	copy->userId = userId;
	
	copy->scimpStateIDs = [scimpStateIDs copy];
	
	copy->isMulticast   = isMulticast;
    copy->isNewMessage  = isNewMessage;
    copy->isFakeStream  = isFakeStream;
	copy->hidden        = hidden;
	
    copy->fyeo             = fyeo;
    copy->shredAfter       = shredAfter;
    copy->shouldBurn       = shouldBurn;
	copy->sendReceipts     = sendReceipts;
    copy->notificationDate = notificationDate;
	copy->trackUntil       = trackUntil;
	
	copy->mostRecentDeliveredTimestamp = mostRecentDeliveredTimestamp;
    copy->mostRecentDeliveredMessageID = mostRecentDeliveredMessageID;
	
	copy->remoteJid = remoteJid;
	copy->localJid  = localJid;
    
	copy->multicastJidSet = multicastJidSet;
	copy->keyLocator      = keyLocator;
    copy->threadID        = threadID;
	copy->title           = title;
	
	copy->capabilities = [capabilities copy];

	copy->lastUpdated = lastUpdated;
	
	return copy;
}

#pragma mark Dynamic Properties

- (BOOL)tracking
{
	BOOL isTracking = [trackUntil isAfter:[NSDate date]];
	return isTracking;
}

#pragma mark Compare

- (NSComparisonResult)compareByLastUpdated:(STConversation *)another
{
	NSDate *aLastUpdated = self.lastUpdated;
	NSDate *bLastUpdated = another.lastUpdated;
	
#if !defined(NS_BLOCK_ASSERTIONS)
	NSAssert(aLastUpdated && bLastUpdated, @"STConversation has nil lastUpdated!");
#else
	if (aLastUpdated == nil)
		aLastUpdated = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
	
	if (bLastUpdated == nil)
		bLastUpdated = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
#endif
	
	return [aLastUpdated compare:bLastUpdated];
}

@end
