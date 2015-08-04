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
#import "STStreamManagement.h"

static NSString *const k_version                = @"version";
static NSString *const k_resumptionId           = @"resumptionId";
static NSString *const k_timeout                = @"timeout";
static NSString *const k_lastDisconnect         = @"lastDisconnect";
static NSString *const k_lastHandledByClient    = @"lastHandledByClient";
static NSString *const k_lastHandledByServer    = @"lastHandledByServer";
static NSString *const k_pendingOutgoingStanzas = @"pendingOutgoingStanzas";


@implementation STStreamManagement

@synthesize resumptionId           = resumptionId;           // NSString
@synthesize timeout                = timeout;                // uint32_t
@synthesize lastDisconnect         = lastDisconnect;         // NSDate
@synthesize lastHandledByClient    = lastHandledByClient;    // uint32_t
@synthesize lastHandledByServer    = lastHandledByServer;    // uint32_t
@synthesize pendingOutgoingStanzas = pendingOutgoingStanzas; // NSArray (of XMPPStreamManagementOutgoingStanza)

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		resumptionId = [decoder decodeObjectForKey:k_resumptionId];
		timeout = (uint32_t)[decoder decodeInt32ForKey:k_timeout];
		lastDisconnect = [decoder decodeObjectForKey:k_lastDisconnect];
		lastHandledByClient = (uint32_t)[decoder decodeInt32ForKey:k_lastHandledByClient];
		lastHandledByServer = (uint32_t)[decoder decodeInt32ForKey:k_lastHandledByServer];
		pendingOutgoingStanzas = [decoder decodeObjectForKey:k_pendingOutgoingStanzas];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt32:1 forKey:k_version];
	
	[coder encodeObject:resumptionId forKey:k_resumptionId];
	[coder encodeInt32:(int32_t)timeout forKey:k_timeout];
	[coder encodeObject:lastDisconnect forKey:k_lastDisconnect];
	[coder encodeInt32:(int32_t)lastHandledByClient forKey:k_lastHandledByClient];
	[coder encodeInt32:(int32_t)lastHandledByServer forKey:k_lastHandledByServer];
	[coder encodeObject:pendingOutgoingStanzas forKey:k_pendingOutgoingStanzas];
}

- (id)copyWithZone:(NSZone *)zone
{
	STStreamManagement *copy = [super copyWithZone:zone];
	
	copy->resumptionId = resumptionId;
	copy->timeout = timeout;
	copy->lastDisconnect = lastDisconnect;
	copy->lastHandledByClient = lastHandledByClient;
	copy->lastHandledByServer = lastHandledByServer;
	copy->pendingOutgoingStanzas = pendingOutgoingStanzas;
	
	return copy;
}

@end
