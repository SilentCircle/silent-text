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
#import "SCimpWrapper.h"
#import "SCimpUtilities.h"

NSString *const kSCimpInfoVersion       = @"version";
NSString *const kSCimpInfoCipherSuite   = @"cipher_suite";
NSString *const kSCimpInfoSASMethod     = @"SAS_method";
NSString *const kSCimpInfoSAS           = @"SAS";
NSString *const kSCimpInfoMethod        = @"scimp_method";
NSString *const kSCimpInfoState         = @"scimp_state";
NSString *const kSCimpInfoIsReady       = @"is_ready";
NSString *const kSCimpInfoIsInitiator   = @"scimp_is_initiator";
NSString *const kSCimpInfoHasCS         = @"has_secret";
NSString *const kSCimpInfoCSMatch       = @"secrets_match";
NSString *const kSCimpInfoKeyedDate     = @"scimp_keyed_date";



@implementation SCimpWrapper

@synthesize scimpID = scimpID;

@synthesize conversationID = conversationID;
@synthesize threadID = threadID;

@synthesize localJID = localJID;
@synthesize remoteJID = remoteJID;

@synthesize scimpError = scimpError;
@synthesize isVerified = isVerified;
@synthesize awaitingReKeying = awaitingReKeying;


- (instancetype)initWithPubSCimpCtx:(SCimpContextRef)ctx
{
	NSParameterAssert(ctx != kInvalidSCimpContextRef);
	
	if ((self = [super init]))
	{
		scimpCtx = ctx;
		scimpError = kSCLError_NoErr;
	}
	return self;
}

- (instancetype)initWithSCimpCtx:(SCimpContextRef)ctx
                  conversationID:(NSString *)inConversationID
                        localJID:(XMPPJID *)inLocalJID
                       remoteJID:(XMPPJID *)inRemoteJID
{
	NSParameterAssert(ctx != kInvalidSCimpContextRef);
	NSParameterAssert(inConversationID != nil);
	NSParameterAssert(inLocalJID != nil);
	NSParameterAssert(inRemoteJID != nil);
	
	if ((self = [super init]))
	{
		scimpCtx = ctx;
		scimpError = kSCLError_NoErr;
		
		conversationID = [inConversationID copy];
		localJID = inLocalJID;
		remoteJID = inRemoteJID;
		
        [self updateScimpID];
	}
	return self;
}

- (instancetype)initWithSCimpCtx:(SCimpContextRef)ctx
                  conversationID:(NSString *)inConversationID
                        localJID:(XMPPJID *)inLocalJID
                        threadID:(NSString *)inThreadID
{
	NSParameterAssert(ctx != kInvalidSCimpContextRef);
	NSParameterAssert(inConversationID != nil);
	NSParameterAssert(inLocalJID != nil);
	NSParameterAssert(inThreadID != nil);
	
	if ((self = [super init]))
	{
		scimpCtx = ctx;
		scimpError = kSCLError_NoErr;
		
		conversationID = [inConversationID copy];
		localJID = inLocalJID;
		threadID = [inThreadID copy];
		
		[self updateScimpID];
	}
	return self;
}

- (void)dealloc
{
	if (scimpCtx) {
		SCimpFree(scimpCtx);
		scimpCtx = NULL;
	}
}

- (NSString *)description
{
	return [NSString stringWithFormat:
	  @"<SCimpWrapper %p: ctx=%p tuple=[%@, %@]>", self, scimpCtx, localJID.full, remoteJID.full];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark ScimpID
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString *)scimpIDForLocalJID:(XMPPJID *)localJID
                       remoteJID:(XMPPJID *)remoteJID
                         options:(XMPPJIDCompareOptions)options
{
	NSInteger hash = 0;
	NSString *localStr = localJID.bare;
	
	if (options == XMPPJIDCompareBare)
	{
		hash = [[localStr stringByAppendingString:remoteJID.bare] hash];
	}
	else
	{
		// Note: if remoteJID doesn't have a resource, then remoteJID.full == remoteJID.bare
		hash = [[localStr stringByAppendingString:remoteJID.full] hash];
	}
	
	return [NSString stringWithFormat:@"%lX", (long)hash];
}

+ (NSString *)scimpIDForLocalJID:(XMPPJID *)localJID threadID:(NSString *)threadID
{
	NSInteger hash1 = [threadID hash];
	NSInteger hash2 = [localJID.bare hash];
	
	NSString *encodedString = [NSString stringWithFormat:@"%lX%lX", (long)hash1, (long)hash2];
	return encodedString;
}

- (void)updateScimpID
{
	if (threadID)
		scimpID = [SCimpWrapper scimpIDForLocalJID:localJID threadID:threadID];
	else if (remoteJID)
		scimpID = [SCimpWrapper scimpIDForLocalJID:localJID remoteJID:remoteJID options:XMPPJIDCompareFull];
	else
		scimpID = nil;
}

/**
 * Allows you to change the remoteJID from a bareJID to a fullJID (or vice-versa).
 *
 * @return The new scimpID
**/
- (NSString *)updateRemoteJID:(XMPPJID *)newRemoteJID
{
	NSParameterAssert(newRemoteJID != nil);
	
	remoteJID = newRemoteJID;
	
	[self updateScimpID];
	return scimpID;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Secure Context Info
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (SCimpMethod)protocolMethod
{
	if (scimpCtx)
	{
		SCimpMethod method;
		SCLError err = SCimpGetNumericProperty(scimpCtx, kSCimpProperty_SCIMPmethod, &method);
	
		if (err == kSCLError_NoErr)
			return method;
	}
	
	return kSCimpMethod_Invalid;
}

- (SCimpState)protocolState
{
	if (scimpCtx)
	{
		SCimpState state;
		SCLError err = SCimpGetNumericProperty(scimpCtx, kSCimpProperty_SCIMPstate, &state);
		
		if (err == kSCLError_NoErr)
			return state;
	}
	
	return ANY_STATE; // <- We want this to be kSCimpState_Invalid, but it doesn't exist.
}

- (NSString *)protocolMethodString
{
	return [SCimpUtilities stringFromSCimpMethod:self.protocolMethod];
}

- (NSString *)protocolStateString
{
	return [SCimpUtilities stringFromSCimpState:self.protocolState];
}

- (SCimpCipherSuite)cipherSuite
{
	if (scimpCtx)
	{
		SCimpCipherSuite cipherSuite;
		SCLError err = SCimpGetNumericProperty(scimpCtx, kSCimpProperty_CipherSuite, &cipherSuite);
		
		if (err == kSCLError_NoErr)
			return cipherSuite;
	}
	
	return kSCimpCipherSuite_Invalid;
}

- (SCimpSAS)sasMethod
{
	if (scimpCtx)
	{
		SCimpSAS sas;
		SCLError err = SCimpGetNumericProperty(scimpCtx, kSCimpProperty_SASstring, &sas);
		
		if (err == kSCLError_NoErr)
			return sas;
	}
	
	return kSCimpSAS_Invalid;
}

- (BOOL)hasSharedSecret
{
	if (scimpCtx)
	{
		SCimpInfo info;
		SCLError err = SCimpGetInfo(scimpCtx, &info);
		
		if (err == kSCLError_NoErr)
			return info.hasCs;
	}
	
	return NO;
}

- (BOOL)sharedSecretMatches
{
	if (scimpCtx)
	{
		SCimpInfo info;
		SCLError err = SCimpGetInfo(scimpCtx, &info);
		
		if (err == kSCLError_NoErr)
			return info.csMatches;
	}
	
	return NO;
}

- (BOOL)isInitiator
{
	if (scimpCtx)
	{
		SCimpInfo info;
		SCLError err = SCimpGetInfo(scimpCtx, &info);
		
		if (err == kSCLError_NoErr)
			return info.isInitiator;
	}
	
	return NO;
}

- (BOOL)isReady
{
	if (scimpCtx)
	{
		SCimpInfo info;
		SCLError err = SCimpGetInfo(scimpCtx, &info);
		
		if (err == kSCLError_NoErr)
			return info.isReady;
	}
	
	return NO;
}

- (NSDictionary *)secureContextInfo;
{
	return [[self class] secureContextInfoForScimp:self];
}

+ (NSDictionary *)secureContextInfoForScimp:(SCimpWrapper *)scimp
{
	NSMutableDictionary *infoDict = nil;
    
	if (scimp && scimp->scimpCtx)
	{
		SCLError  err = kSCLError_NoErr;
		SCimpInfo info;
		
		err = SCimpGetInfo(scimp->scimpCtx, &info);
		if (err == kSCLError_NoErr)
		{
			infoDict = [NSMutableDictionary dictionaryWithCapacity:10];
			
			// Add number properties
			
			infoDict[kSCimpInfoVersion]     = @(info.version);
			infoDict[kSCimpInfoCipherSuite] = @(info.cipherSuite);
			infoDict[kSCimpInfoSASMethod]   = @(info.sasMethod);
			infoDict[kSCimpInfoMethod]      = @(info.scimpMethod);
			infoDict[kSCimpInfoState]       = @(info.state);
			infoDict[kSCimpInfoIsReady]     = @((info.isReady ? YES : NO));
			infoDict[kSCimpInfoIsInitiator] = @((info.isInitiator ? YES : NO));
			infoDict[kSCimpInfoHasCS]       = @((info.hasCs ? YES : NO));
			infoDict[kSCimpInfoCSMatch]     = @((info.csMatches ? YES : NO));
			
			if (info.keyedTime > 0)
				infoDict[kSCimpInfoKeyedDate] = [NSDate dateWithTimeIntervalSince1970:info.keyedTime];
			
			// Add data properties
			
			size_t length = 0;
			char *SASstr = NULL;
			
			err = SCimpGetAllocatedDataProperty(scimp->scimpCtx,
			                                    kSCimpProperty_SASstring,
			                            (void *)&SASstr,
			                                    &length);
			
			if (err == kSCLError_NoErr)
			{
				NSString *SAS = [[NSString alloc] initWithBytesNoCopy:SASstr
				                                               length:length
				                                             encoding:NSUTF8StringEncoding
				                                         freeWhenDone:YES];
				
				infoDict[kSCimpInfoSAS] = SAS;
			}
		}
    }
	
	if (infoDict.count == 0)
	{
		// At a mimimum, fill out the dictionary with proper values for any numeric fields.
		// Otherwise the caller might assume these values are 'zero', which may or may not be the right thing.
		//
		// E.g.: kSCimpInfoState == 0 => kSCimpState_Init
		
		infoDict[kSCimpInfoVersion]     = @(0);
		infoDict[kSCimpInfoCipherSuite] = @(kSCimpCipherSuite_Invalid);
		infoDict[kSCimpInfoSASMethod]   = @(kSCimpSAS_Invalid);
		infoDict[kSCimpInfoMethod]      = @(kSCimpMethod_Invalid);
		infoDict[kSCimpInfoState]       = @(ANY_STATE);
		infoDict[kSCimpInfoHasCS]       = @(NO);
		infoDict[kSCimpInfoCSMatch]     = @(NO);
		infoDict[kSCimpInfoIsInitiator] = @(NO);
	}
	
    return [infoDict copy];
}

@end
