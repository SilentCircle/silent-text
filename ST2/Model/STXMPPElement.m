/*
Copyright (C) 2014-2015, Silent Circle, LLC. All rights reserved.

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
#import "STXMPPElement.h"
#import "AppConstants.h"

#import "NSXMLElement+XMPP.h"
#import "XMPPMessage+SilentCircle.h"

/**
 * Keys for encoding / decoding (to avoid typos)
**/
static NSString *const k_element         = @"element";
static NSString *const k_localUserID     = @"localUserId";
static NSString *const k_conversationID  = @"conversationId";
static NSString *const k_uuid            = @"uuid";
static NSString *const k_timestamp       = @"timestamp";
static NSString *const k_isKeyingMessage = @"isKeyingMessage";


@implementation STXMPPElement

@synthesize element = element;
@synthesize localUserID = localUserID;
@synthesize conversationID = conversationID;
@synthesize uuid = uuid;
@synthesize timestamp = timestamp;
@synthesize isKeyingMessage = isKeyingMessage;

+ (BOOL)hasEncryptedMaterial:(XMPPElement *)element
{
	NSXMLElement *x = nil;
	
	x = [element elementForName:@"x" xmlns:kSCNameSpace];
	if (x) return YES;
	
	x = [element elementForName:@"x" xmlns:kSCPublicKeyNameSpace];
	if (x) return YES;
	
	return NO;
}

+ (BOOL)hasPlaintextMaterial:(XMPPElement *)element
{
	NSXMLElement *x = nil;
	
	x = [element elementForName:kSCPPSiren];
	if (x) return YES;
	
	x = [element elementForName:kSCPPPubSiren];
	if (x) return YES;
	
	return NO;
}

- (instancetype)initWithElement:(XMPPElement *)inElement
                    localUserID:(NSString *)inLocalUserID
                 conversationID:(NSString *)inConversationID
{
	NSAssert(![STXMPPElement hasEncryptedMaterial:inElement],
	         @"Stored elements MUST NOT contain any pre-encrypted material. "
	         @"The encryption MUST occur immediately before the element goes over the xmpp stream, "
	         @"using the scimp state AT THAT PRECISE MOMENT.");
	
	if ((self = [super init]))
	{
		element = [inElement copy]; // <- The copy step is critical! The stored XMPPElement MUST remain immutable!
		localUserID = [inLocalUserID copy];
		conversationID = [inConversationID copy];
		
		uuid = [element elementID];
		if (uuid == nil)
			uuid = [[NSUUID new] UUIDString];
		
		timestamp = [NSDate date];
		isKeyingMessage = NO;
	}
	return self;
}

- (instancetype)initWithKeyingMessage:(XMPPMessage *)inMessage
                          localUserID:(NSString *)inLocalUserID
                       conversationID:(NSString *)inConversationID
{
	NSAssert(![STXMPPElement hasPlaintextMaterial:inMessage],
			 @"Stored keying messages MUST NOT contain any non-encrypted material.");
	
	if ((self = [super init]))
	{
		element = [inMessage copy]; // <- The copy step is critical! The stored XMPPElement MUST remain immutable!
		
		localUserID = [inLocalUserID copy];
		conversationID = [inConversationID copy];
		
		uuid = [element elementID];
		if (uuid == nil)
			uuid = [[NSUUID new] UUIDString];
		
		timestamp = [NSDate date];
		isKeyingMessage = YES;
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		element = [decoder decodeObjectForKey:k_element];
		localUserID = [decoder decodeObjectForKey:k_localUserID];
		conversationID = [decoder decodeObjectForKey:k_conversationID];
		
		uuid = [decoder decodeObjectForKey:k_uuid];
		timestamp = [decoder decodeObjectForKey:k_timestamp];
		isKeyingMessage = [decoder decodeBoolForKey:k_isKeyingMessage];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:element forKey:k_element];
	[coder encodeObject:localUserID forKey:k_localUserID];
	[coder encodeObject:conversationID forKey:k_conversationID];
	
	[coder encodeObject:uuid forKey:k_uuid];
	[coder encodeObject:timestamp forKey:k_timestamp];
	[coder encodeBool:isKeyingMessage forKey:k_isKeyingMessage];
}

- (XMPPElement *)element
{
	return [element copy]; // <- The copy step is critical! The stored XMPPElement MUST remain immutable!
}

@end
