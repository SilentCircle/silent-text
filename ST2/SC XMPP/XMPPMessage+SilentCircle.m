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
#import "AppConstants.h"
#import "XMPPMessage+SilentCircle.h"

#import "NSXMLElement+XMPP.h"
#import "NSXMLElement+XEP_0203.h"
#import "XMPPDateTimeProfiles.h"
#import "XMPPStream.h"

#import "STLogging.h"

#if DEBUG
  static const int ddLogLevel = LOG_LEVEL_WARN;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif


@implementation XMPPMessage (SilentCircle)

+ (XMPPMessage *)chatMessageWithSiren:(Siren *)siren to:(XMPPJID *)jid elementID:(NSString *)elementID
{
	return [self chatMessageWithSiren:siren to:jid elementID:elementID push:YES badge:YES];
}

+ (XMPPMessage *)chatMessageWithSiren:(Siren *)siren
                                   to:(XMPPJID *)jid
                            elementID:(NSString *)elementID
                                 push:(BOOL)push
                                badge:(BOOL)badge
{
	if ([jid isFull])
	{
		DDLogWarn(@"%@: Stripping resource from FULL jid (%@). Did you mean to send it to the full jid ?",
		          THIS_METHOD, jid);
	}
	
	XMPPMessage *message = [XMPPMessage messageWithType:kXMPPChat to:[jid bareJID]];
	
	if (elementID)
		[message addAttributeWithName:kXMPPID stringValue:elementID];
	else
		[message addAttributeWithName:kXMPPID stringValue:[XMPPStream generateUUID]];
	
	NSXMLElement *bodyElement = [[NSXMLElement alloc] initWithName:kXMPPBody];
	[message addChild:bodyElement];
	
	NSXMLElement *sirenElement = [[NSXMLElement alloc] initWithName:kSCPPSiren xmlns:kSCNameSpace];
	[sirenElement setStringValue:siren.json];
	
	// If push is YES, then we don't need to add the attribute
	if (!push)
		[sirenElement addAttributeWithName:kXMPPNotifiable stringValue:(push ? @"true" : @"false")];
	
	// If badge is YES, then we don't need to add the attribute
	if (!badge)
		[sirenElement addAttributeWithName:kXMPPBadge stringValue:(badge ? @"true" : @"false")];
	
	[message addChild:sirenElement];
	
	return message;
}

+ (XMPPMessage *)multicastChatMessageWithSiren:(Siren *)siren
                                            to:(NSArray *)jids
                                      threadID:(NSString *)threadID
                                        domain:(NSString *)domain
{
	return [self multicastChatMessageWithSiren:siren to:jids threadID:threadID domain:domain elementID:nil];
}

+ (XMPPMessage *)multicastChatMessageWithSiren:(Siren *)siren
                                            to:(NSArray *)jids
                                      threadID:(NSString *)threadID
                                        domain:(NSString *)domain
                                     elementID:(NSString *)elementID
{
	NSString *module = [NSString stringWithFormat:@"multicast.%@", (domain ? domain : @"silentcircle.com")];
	
	XMPPMessage *message = [XMPPMessage multicastMessageWithType:kXMPPChat jids:jids module:module];
	
	if (elementID)
		[message addAttributeWithName:kXMPPID stringValue:elementID];
	else
		[message addAttributeWithName:kXMPPID stringValue:[XMPPStream generateUUID]];
	
	NSXMLElement *bodyElement = [[NSXMLElement alloc] initWithName:kXMPPBody];
	[message addChild:bodyElement];
	
	if (threadID) {
		message.threadID = threadID;
	}
	
	NSXMLElement *sirenElement = [[NSXMLElement alloc] initWithName:kSCPPSiren xmlns:kSCNameSpace];
	sirenElement.stringValue = siren.json;
	[message addChild:sirenElement];
	
	return message;
}

- (NSString *)threadID
{
	return [[self elementForName:kXMPPThread] stringValue];
}

- (void)setThreadID:(NSString *)threadID
{
	NSXMLElement *thread = [[NSXMLElement alloc] initWithName:kXMPPThread stringValue:threadID];
	[self addChild:thread];
}
 
/**
 * The xmpp server adds a timestamp for every message.
 * Although we use a custom stanza for this, we still use the standard xmpp date/time profiles.
 * 
 * Related ticket: ST-209
**/
- (NSDate *)timestamp
{
	NSDate *date = nil;
	
	NSXMLElement *timestampElement = [self elementForName:@"time" xmlns: kSCTimestampNameSpace];
	if (timestampElement)
	{
		NSString *dateString = [timestampElement attributeStringValueForName:@"stamp"];
		if(dateString) {
			date = [XMPPDateTimeProfiles parseDateTime:dateString];
		}
	}
	
	return date;
}

- (BOOL)isChatMessageWithSiren
{
	if ([self isChatMessage])
	{
		return ([self elementForName:kSCPPSiren xmlns:kSCNameSpace] ? YES : NO);
	}
	
	return NO;
}

- (BOOL)isChatMessageWithPubSiren
{
	if ([self isChatMessage])
	{
		return ([self elementForName:kSCPPPubSiren xmlns:kSCNameSpace] ? YES : NO);
	}
	
	return NO;
}

- (void)stripSilentCirclePlaintextDataForIncomingStanza
{
	BOOL isIncomingStanza = YES;
	[self stripSilentCirclePlaintextData:isIncomingStanza];
}

- (void)stripSilentCirclePlaintextDataForOutgoingStanza
{
	BOOL isIncomingStanza = NO;
	[self stripSilentCirclePlaintextData:isIncomingStanza];
}

- (void)stripSilentCirclePlaintextData:(BOOL)isIncomingStanza
{
	for (NSUInteger index = [self childCount]; index > 0; index--)
	{
		NSXMLElement *element = (NSXMLElement *)[self childAtIndex:(index-1)];
		NSString *elementName = [element name];
		
        if ([elementName isEqualToString:kSCPPSiren]     ||
		    [elementName isEqualToString:kSCPPPubSiren]  ||
		   ([elementName isEqualToString:kSCPPTimestamp] && !isIncomingStanza))
		{
			[self removeChildAtIndex:(index-1)];
		}
	}
}

@end
