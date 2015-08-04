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
#import "STMessage.h"
#import "AppConstants.h"

/**
 * Keys for encoding / decoding (to avoid typos)
**/
static NSString *const k_version         = @"version";
static NSString *const k_uuid            = @"uuid";
static NSString *const k_conversationId  = @"conversationId";
static NSString *const k_userId          = @"userId";
static NSString *const k_sirenJSON       = @"sirenJSON";
static NSString *const k_fromJID         = @"fromJID";
static NSString *const k_toJID           = @"toJID";
static NSString *const k_timestamp       = @"timestamp";
static NSString *const k_isOutgoing      = @"isOutgoing";
static NSString *const k_isVerified      = @"isVerified";
static NSString *const k_sendDate        = @"sendDate";
static NSString *const k_rcvDate         = @"rcvDate";
static NSString *const k_shredDate       = @"shredDate";
static NSString *const k_serverAckDate   = @"serverAckDate";
static NSString *const k_needsReSend     = @"needsReSend";
static NSString *const k_needsUpload     = @"needsUpload";
static NSString *const k_needsDownload   = @"needsDownload";
static NSString *const k_needsEncrypting = @"needsEncrypting";
static NSString *const k_ignored         = @"ignored";
static NSString *const k_isRead          = @"isRead";
static NSString *const k_hasThumbnail    = @"hasThumbnail";
static NSString *const k_errorInfo       = @"errorInfo";
static NSString *const k_signatureInfo   = @"signatureInfo";
static NSString *const k_statusMessage   = @"statusMessage";

static NSString *const k_deprecated_fromStr = @"from";
static NSString *const k_deprecated_toStr   = @"to";


/**
 * Keys for signatureInfo dictionary.
**/
NSString *const kSigInfo_keyFound       = @"keyFound";
NSString *const kSigInfo_owner          = @"owner";
NSString *const kSigInfo_expireDate     = @"expire_date";
NSString *const kSigInfo_calculatedHash = @"calculatedHash";
NSString *const kSigInfo_valid          = @"sig_valid";


@implementation STMessage

@synthesize uuid = uuid;
@synthesize conversationId = conversationId;
@synthesize userId = userId;

@synthesize siren = siren;
@synthesize from = from;
@synthesize to = to;

@synthesize timestamp = timestamp;

@synthesize isOutgoing = isOutgoing;
@synthesize hasThumbnail = hasThumbnail;

@synthesize sendDate = sendDate;
@synthesize rcvDate = rcvDate;
@synthesize shredDate = shredDate;
@synthesize serverAckDate = serverAckDate;

@synthesize isVerified = isVerified;
@synthesize needsReSend = needsReSend;
@synthesize needsUpload = needsUpload;
@synthesize needsDownload = needsDownload;
@synthesize needsEncrypting = needsEncrypting;

@synthesize errorInfo = errorInfo;
@synthesize ignored = ignored;
@synthesize isRead = isRead;

@synthesize signatureInfo = signatureInfo;
@synthesize statusMessage= statusMessage;


- (id)initWithUUID:(NSString *)inUUID
    conversationId:(NSString *)inConversationID
            userId:(NSString *)inUserId
              from:(NSString *)inFrom
                to:(NSString *)inTo
         withSiren:(Siren *)inSiren
         timestamp:(NSDate *)inTimestamp
        isOutgoing:(BOOL)inIsOutgoing
{
	if ((self = [super init]))
	{
		uuid = [inUUID copy];
        conversationId = [inConversationID copy];
		userId = [inUserId copy];
		
		siren = inSiren;
		from = [inFrom copy];
		to = [inTo copy];
		timestamp = inTimestamp;
		isOutgoing = inIsOutgoing;
		
		hasThumbnail = inSiren.thumbnail ? YES : NO;
		isRead = inIsOutgoing ? YES : NO;
		
		isVerified = inIsOutgoing ? YES : NO;
		needsReSend = NO;
		needsUpload = NO;
		needsDownload = NO;
		needsEncrypting = NO;
		ignored = NO;
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
 * - added serverAckDate (needs to be set to distantPast if coming from older version)
 *
 * Version 3:
 * - converted 'from' ivar from NSString to XMPPJID
 * - converted 'to'   ivar from NSString to XMPPJID
**/

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		int32_t version = [decoder decodeInt32ForKey:k_version];
		
        if (version == 0) // OLD version
        {
            uuid           = [decoder decodeObjectForKey:k_uuid];
			conversationId = [decoder decodeObjectForKey:k_conversationId];
			userId         = [decoder decodeObjectForKey:k_userId];

			NSData *infoData = [decoder decodeObjectForKey:@"infoData"];
			NSDictionary *info = [NSPropertyListSerialization propertyListWithData:infoData
			                                                               options:0 format:NULL error:NULL];
			
			NSString *sirenJSON = [info objectForKey:@"siren"];
			if (sirenJSON)
				siren = [[Siren alloc] initWithJSON:sirenJSON];

			NSString *fromStr = [info objectForKey:k_deprecated_fromStr];
			NSString *toStr = [info objectForKey:k_deprecated_toStr];
			
			from = [XMPPJID jidWithString:fromStr];
			to   = [XMPPJID jidWithString:toStr];
			
			timestamp = [info objectForKey:k_timestamp];
			isOutgoing = [[info objectForKey:k_isOutgoing] boolValue];
			
            hasThumbnail = [[info objectForKey:k_hasThumbnail] boolValue];
			isRead       = [[info objectForKey:k_isRead] boolValue];
			
			sendDate  = [info objectForKey:k_sendDate];
			rcvDate   = [info objectForKey:k_rcvDate];
			shredDate = [info objectForKey:k_shredDate];
			
			isVerified      = [[info objectForKey:k_isVerified] boolValue];
			needsReSend     = [[info objectForKey:k_needsReSend] boolValue];
            needsUpload     = [[info objectForKey:k_needsUpload] boolValue];
            needsDownload   = [[info objectForKey:k_needsDownload] boolValue];
            needsEncrypting = [[info objectForKey:k_needsEncrypting] boolValue];
 			ignored         = [[info objectForKey:k_ignored] boolValue];
			
			errorInfo     = [info objectForKey:k_errorInfo];
            signatureInfo = [info objectForKey:k_signatureInfo];
            statusMessage = [info objectForKey:k_statusMessage];
        }
		else // NEW'ish version
		{
			uuid           = [decoder decodeObjectForKey:k_uuid];
			conversationId = [decoder decodeObjectForKey:k_conversationId];
			userId         = [decoder decodeObjectForKey:k_userId];
			
			NSString *sirenJSON = [decoder decodeObjectForKey:k_sirenJSON];
			if (sirenJSON)
				siren = [[Siren alloc] initWithJSON:sirenJSON];
			
			if (version >= 3)
			{
				from = [decoder decodeObjectForKey:k_fromJID];
				to   = [decoder decodeObjectForKey:k_toJID];
			}
			else
			{
				NSString *fromStr = [decoder decodeObjectForKey:k_deprecated_fromStr];
				NSString *toStr   = [decoder decodeObjectForKey:k_deprecated_toStr];
				
				if (IsSTInfoJidStr(fromStr))
					from = [AppConstants stInfoJID];
				else if (IsOCAVoicemailJidStr(fromStr))
					from = [AppConstants ocaVoicemailJID];
				else
					from = [XMPPJID jidWithString:fromStr];
				
				if (IsSTInfoJidStr(toStr))
					to = [AppConstants stInfoJID];
				else if (IsOCAVoicemailJidStr(toStr))
					to = [AppConstants ocaVoicemailJID];
				else
					to = [XMPPJID jidWithString:toStr];
			}
			
			timestamp  = [decoder decodeObjectForKey:k_timestamp];
			isOutgoing = [decoder decodeBoolForKey:k_isOutgoing];
			
			hasThumbnail = [decoder decodeBoolForKey:k_hasThumbnail];
			isRead       = [decoder decodeBoolForKey:k_isRead];
			
			sendDate      = [decoder decodeObjectForKey:k_sendDate];
			rcvDate       = [decoder decodeObjectForKey:k_rcvDate];
			shredDate     = [decoder decodeObjectForKey:k_shredDate];
			serverAckDate = [decoder decodeObjectForKey:k_serverAckDate];
            
			isVerified      = [decoder decodeBoolForKey:k_isVerified];
			needsReSend     = [decoder decodeBoolForKey:k_needsReSend];
            needsUpload     = [decoder decodeBoolForKey:k_needsUpload];
            needsDownload   = [decoder decodeBoolForKey:k_needsDownload];
            needsEncrypting = [decoder decodeBoolForKey:k_needsEncrypting];
			ignored         = [decoder decodeBoolForKey:k_ignored];
            
			errorInfo     = [decoder decodeObjectForKey:k_errorInfo];
			signatureInfo = [decoder decodeObjectForKey:k_signatureInfo];
            statusMessage = [decoder decodeObjectForKey:k_statusMessage];
		}
		
		// Sanity checks
		
		if (serverAckDate == nil && version < 2)
		{
			// If serverAckDate is nil, then the RMD re-send architecture
			// will think it needs to resend the message.
			// So for pre RMD messages, we need to make this non-nil.
			serverAckDate = [NSDate distantPast];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt32:3 forKey:k_version];
	
	[coder encodeObject:uuid           forKey:k_uuid];
	[coder encodeObject:conversationId forKey:k_conversationId];
	[coder encodeObject:userId         forKey:k_userId];
    
 	[coder encodeObject:[siren json]   forKey:k_sirenJSON];
	[coder encodeObject:from           forKey:k_fromJID];
	[coder encodeObject:to             forKey:k_toJID];
	[coder encodeObject:timestamp      forKey:k_timestamp];
	[coder encodeBool:isOutgoing       forKey:k_isOutgoing];
	
	[coder encodeBool:hasThumbnail     forKey:k_hasThumbnail];
	[coder encodeBool:isRead           forKey:k_isRead];
	
	[coder encodeObject:sendDate       forKey:k_sendDate];
	[coder encodeObject:rcvDate        forKey:k_rcvDate];
	[coder encodeObject:shredDate      forKey:k_shredDate];
	[coder encodeObject:serverAckDate  forKey:k_serverAckDate];
	
	[coder encodeBool:isVerified       forKey:k_isVerified];
	[coder encodeBool:needsReSend      forKey:k_needsReSend];
	[coder encodeBool:needsUpload      forKey:k_needsUpload];
 	[coder encodeBool:needsDownload    forKey:k_needsDownload];
 	[coder encodeBool:needsEncrypting  forKey:k_needsEncrypting];
	[coder encodeBool:ignored          forKey:k_ignored];
	
	[coder encodeObject:errorInfo      forKey:k_errorInfo];
	[coder encodeObject:signatureInfo  forKey:k_signatureInfo];
	[coder encodeObject:statusMessage  forKey:k_statusMessage];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSCopying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
{
	STMessage *copy = [super copyWithZone:zone];
	
	copy->uuid = uuid;
	copy->conversationId = conversationId;
	copy->userId = userId;
	
	copy->siren = [siren copy];
	copy->from = from;
	copy->to = to;
	copy->timestamp = timestamp;
	copy->isOutgoing = isOutgoing;
	
    copy->hasThumbnail = hasThumbnail;
	copy->isRead = isRead;
	
	copy->sendDate = sendDate;
	copy->rcvDate = rcvDate;
	copy->shredDate = shredDate;
	copy->serverAckDate = serverAckDate;
	
	copy->isVerified = isVerified;
	copy->needsReSend = needsReSend;
    copy->needsUpload = needsUpload;
    copy->needsDownload = needsDownload;
    copy->needsEncrypting = needsEncrypting;
    copy->ignored = ignored;

    copy->errorInfo = errorInfo;
    copy->signatureInfo = signatureInfo;
    copy->statusMessage = statusMessage;
	
	return copy;
}

- (STMessage *)copyWithNewSiren:(Siren *)updatedSiren
{
	STMessage *copy = [self copy];
	copy->siren =  updatedSiren;
	
	return copy;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark STDatabaseObject overrides
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)makeImmutable
{
	[super makeImmutable];
	[siren makeImmutable];
}

- (void)clearChangedProperties
{
	[super clearChangedProperties];
	[siren clearChangedProperties];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Convenience Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)scloudID
{
	return siren.cloudLocator;
}

- (BOOL)isStatusMessage
{
	if (statusMessage)
		return YES;
 	else
		return NO;
}

- (BOOL)isShredable
{
	if (shredDate) return YES;
	if (siren.shredAfter) return YES;
	
	return NO;
}

- (BOOL)hasGeo
{
	return siren.location != nil;
}

- (BOOL)isSpecialMessage
{
	if (siren.threadName)
		return YES;
 	else
		return NO;
}

- (NSString *)specialMessageText
{
    if (siren.threadName)
    {
        if (siren.threadName.length)
        {
			NSString *frmt = NSLocalizedString(@"Renamed conversation:\n  \"%@\"", @"Renamed conversation:\n  \"%@\"");
            return [NSString stringWithFormat:frmt, siren.threadName];
        }
		else
		{
			return NSLocalizedString(@"Cleared conversation name\n  ", @"Cleared conversation name");
		}

    }
    else  //  add other kinds here
    {
        
    }
    
    return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Compare
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSComparisonResult)compareByTimestamp:(STMessage *)another
{
	NSDate *aTimestamp = self.timestamp;
	NSDate *bTimestamp = another.timestamp;
    
    // use the send date if it's available for outgoing messages
    if(self.isOutgoing && self.sendDate) aTimestamp = self.sendDate;
    if(another.isOutgoing && another.sendDate) bTimestamp = another.sendDate;

	NSAssert(aTimestamp && bTimestamp, @"STMessage has nil timestamp!");
	
	return [aTimestamp compare:bTimestamp];
}

@end
