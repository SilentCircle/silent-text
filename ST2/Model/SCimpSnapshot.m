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
#import <SCCrypto/SCcrypto.h>

#import "SCimpSnapshot.h"
#import "SCimpWrapper.h"
#import "SCimpUtilities.h"

/**
 * Keys for encoding / decoding (to avoid typos)
**/
static NSString *const k_version          = @"version";
static NSString *const k_uuid             = @"uuid";
static NSString *const k_conversationID   = @"conversationID";
static NSString *const k_threadID         = @"threadID";
static NSString *const k_remoteJID        = @"remoteJID";
static NSString *const k_localJID         = @"localJID";
static NSString *const k_protocolError    = @"protocolError";
static NSString *const k_isVerified       = @"isVerified";
static NSString *const k_awaitingReKeying = @"awaitingReKeying";
static NSString *const k_ctx              = @"state";
static NSString *const k_ctxInfo          = @"keyInfo";
static NSString *const k_lastUpdated      = @"lastUpdated";

// Older versions
static NSString *const k_v2_threadElement = @"threadElement";
static NSString *const k_v2_remoteJid     = @"remoteJid"; // NSString
static NSString *const k_v2_localJid      = @"localJid";  // NSString
static NSString *const k_v3_protocolState = @"protocolState";

@implementation SCimpSnapshot

@synthesize uuid = uuid;
@synthesize conversationID = conversationID;
@synthesize threadID = threadID;
@synthesize localJID = localJID;
@synthesize remoteJID = remoteJID;
@synthesize protocolError = protocolError;
@synthesize isVerified = isVerified;
@synthesize awaitingReKeying = awaitingReKeying;
@synthesize ctx = ctx;
@synthesize ctxInfo = ctxInfo;
@synthesize lastUpdated = lastUpdated;

- (id)initWithSCimpWrapper:(SCimpWrapper *)scimp ctx:(NSData *)ctxSnapshotData
{
	if (scimp == nil) return nil;
	
	if ((self = [super init]))
	{
		uuid = [scimp.scimpID copy];
		
		conversationID = [scimp.conversationID copy];
		threadID  = [scimp.threadID copy];
		localJID  = [scimp.localJID bareJID];
		remoteJID = [scimp.remoteJID copy];
		
		protocolError = scimp.scimpError;
		isVerified = scimp.isVerified;
		awaitingReKeying = scimp.awaitingReKeying;
		
		ctx = [ctxSnapshotData copy];
		ctxInfo = [SCimpWrapper secureContextInfoForScimp:scimp];
		
		lastUpdated = [NSDate date];
	}
	return self;
}

#pragma mark NSCoding

/**
 * NSCoding Version History:
 * 
 * v2: Now storing metadata about scimp context (e.g. conversationID, etc)
 *
 * v3: Renamed threadElement to threadID (standardizing naming convention)
 *     Converted localJID & remoteJID to XMPPJID instances instead of strings
 * 
 * v4: protocolState is now stored within ctxInfo dictionary
 *
 * v5: Added isReady property
 * 
 * v6: Added awaitingReKeying property
 *
 * v7: Added isVerified property
**/

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
        int32_t version = [decoder decodeInt32ForKey:k_version];

        if (version == 1) // OLD version
		{
            uuid    = [decoder decodeObjectForKey:k_uuid];
            ctx     = [decoder decodeObjectForKey:k_ctx];
            ctxInfo = [decoder decodeObjectForKey:k_ctxInfo];
		}
		else // NEW-ISH versions
        {
			uuid           = [decoder decodeObjectForKey:k_uuid];
			conversationID = [decoder decodeObjectForKey:k_conversationID];
			
			if (version == 2)
				threadID   = [decoder decodeObjectForKey:k_v2_threadElement];
			else // >= 3
				threadID   = [decoder decodeObjectForKey:k_threadID];
			
			if (version == 2)
			{
				NSString *localJid  = [decoder decodeObjectForKey:k_v2_localJid];
				NSString *remoteJid = [decoder decodeObjectForKey:k_v2_remoteJid];
				
				localJID  = [XMPPJID jidWithString:localJid];
				remoteJID = [XMPPJID jidWithString:remoteJid];
			}
			else // >= 3
			{
				localJID   = [decoder decodeObjectForKey:k_localJID];
				remoteJID  = [decoder decodeObjectForKey:k_remoteJID];
			}
			
			protocolError    = [decoder decodeIntForKey:k_protocolError];
			isVerified       = [decoder decodeBoolForKey:k_isVerified];
			awaitingReKeying = [decoder decodeBoolForKey:k_awaitingReKeying];
			
			ctx     = [decoder decodeObjectForKey:k_ctx];
			ctxInfo = [decoder decodeObjectForKey:k_ctxInfo];
			
			if (version < 4)
			{
				SCimpState protocolState  = [decoder decodeIntForKey:k_v3_protocolState];
				
				NSMutableDictionary *newCtxInfo = [ctxInfo mutableCopy];
				newCtxInfo[kSCimpInfoState] = @(protocolState);
				
				ctxInfo = [newCtxInfo copy];
			}
			
			if (version < 5)
			{
				BOOL isReady = NO;
				
				SCimpMethod method = self.protocolMethod;
				SCimpState state = self.protocolState;
				
				if (method == kSCimpMethod_PubKey)
				{
					if (state != kSCimpState_Error)
						isReady = YES;
				}
				else if (state == kSCimpState_Ready)
				{
					isReady = YES;
				}
				
				NSMutableDictionary *newCtxInfo = [ctxInfo mutableCopy];
				newCtxInfo[kSCimpInfoIsReady] = @(isReady);
				
				ctxInfo = [newCtxInfo copy];
			}
			
			lastUpdated = [decoder decodeObjectForKey:k_lastUpdated];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt32:6 forKey:k_version];
	
	[coder encodeObject:uuid           forKey:k_uuid];
	[coder encodeObject:conversationID forKey:k_conversationID];
	[coder encodeObject:threadID       forKey:k_threadID];
	[coder encodeObject:remoteJID      forKey:k_remoteJID];
	[coder encodeObject:localJID       forKey:k_localJID];
	[coder encodeInt:protocolError     forKey:k_protocolError];
	[coder encodeBool:isVerified       forKey:k_isVerified];
	[coder encodeBool:awaitingReKeying forKey:k_awaitingReKeying];
	[coder encodeObject:ctx            forKey:k_ctx];
	[coder encodeObject:ctxInfo        forKey:k_ctxInfo];
	[coder encodeObject:lastUpdated    forKey:k_lastUpdated];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
	SCimpSnapshot *copy = [super copyWithZone:zone];

	copy->uuid             = uuid;
	copy->conversationID   = conversationID;
	copy->threadID         = threadID;
	copy->localJID         = localJID;
	copy->remoteJID        = remoteJID;
	copy->protocolError    = protocolError;
	copy->isVerified       = isVerified;
	copy->awaitingReKeying = awaitingReKeying;
	copy->ctx              = ctx;
	copy->ctxInfo          = ctxInfo;
	copy->lastUpdated      = lastUpdated;
	
	return copy;
}

#pragma mark Convenience

- (SCimpCipherSuite)cipherSuite
{
	NSNumber *num_cs = [ctxInfo objectForKey:kSCimpInfoCipherSuite];
	if (num_cs)
		return (SCimpCipherSuite)[num_cs intValue];
	else
		return kSCimpCipherSuite_Invalid;
}

- (SCimpSAS)sasMethod
{
	NSNumber *num_sas = [ctxInfo objectForKey:kSCimpInfoSASMethod];
	if (num_sas)
		return (SCimpSAS)[num_sas intValue];
	else
		return kSCimpSAS_Invalid;
}

- (SCimpMethod)protocolMethod
{
	NSNumber *num_method = [ctxInfo objectForKey:kSCimpInfoMethod];
	if (num_method)
		return (SCimpMethod)[num_method intValue];
	else
		return kSCimpMethod_Invalid;
}

- (SCimpState)protocolState
{
	NSNumber *num_state = [ctxInfo objectForKey:kSCimpInfoState];
	if (num_state)
		return (SCimpState)[num_state intValue];
	else
		return ANY_STATE;
}

- (NSString *)protocolMethodString
{
	return [SCimpUtilities stringFromSCimpMethod:self.protocolMethod];
}

- (NSString *)protocolStateString
{
	return [SCimpUtilities stringFromSCimpState:self.protocolState];
}

- (NSString *)sasPhrase
{
	return [ctxInfo objectForKey:kSCimpInfoSAS];
}

- (NSDate *)keyedDate
{
	return [ctxInfo objectForKey:kSCimpInfoKeyedDate];
}

- (BOOL)isReady
{
	return [[ctxInfo objectForKey:kSCimpInfoIsReady] boolValue];
}

- (NSString *)protocolErrorString
{
	return [SCimpUtilities stringFromSCLError:self.protocolError];
}

@end
