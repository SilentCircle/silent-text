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
#import "STLocalUser.h"
#import "STLogging.h"
#import "AppConstants.h"
#import "NSString+SCUtilities.h"

NSString *const kProvisionInfoKey_provisionCode = @"provisionCode";
NSString *const kProvisionInfoKey_deviceName    = @"deviceName";
NSString *const kProvisionInfoKey_receipt       = @"reciept"; // yes, spelled wrong :(

/**
 * Keys for encoding / decoding (to avoid typos)
**/
static NSString *const k_version                  = @"version"; // copied from STUser.m
static NSString *const k_notificationUUID         = @"notificationUUID";

static NSString *const k_xmppResource             = @"xmppResource";
static NSString *const k_xmppPassword             = @"password";
static NSString *const k_apiKey                   = @"apiKey";

static NSString *const k_provisonInfo             = @"provisonInfo";

static NSString *const k_pushToken                = @"pushToken";

static NSString *const k_isEnabled                = @"isEnabled";

static NSString *const k_oldApiKey                = @"oldApiKey";
static NSString *const k_oldDeviceID              = @"deviceID";

static NSString *const k_subscriptionExpireDate   = @"subscriptionExpireDate";
static NSString *const k_subscriptionHasExpired   = @"subscriptionHasExpired";
static NSString *const k_subscriptionAutoRenews   = @"autorenew";
static NSString *const k_handlesOwnBilling        = @"handlesOwnBilling";

static NSString *const k_nextKeyGeneration        = @"nextKeyGeneration";
static NSString *const k_needsKeyGeneration       = @"needsKeyGeneration";
static NSString *const k_needsRegisterPushToken   = @"needsRegisterPushToken";
static NSString *const k_needsDeprovisionUser     = @"needsDeprovisionUser";


@interface STUser (Protected)
- (void)copyIntoNewUser:(STUser *)copy;
@end


@implementation STLocalUser

@synthesize notificationUUID = notificationUUID;

@synthesize xmppResource = xmppResource;
@synthesize xmppPassword = xmppPassword;
@synthesize apiKey = apiKey;

@synthesize provisonInfo = provisonInfo;

@synthesize pushToken = pushToken;

@synthesize isEnabled = isEnabled;

@synthesize oldApiKey = oldApiKey;
@synthesize oldDeviceID = oldDeviceID;

@synthesize subscriptionExpireDate = subscriptionExpireDate;
@synthesize subscriptionHasExpired = subscriptionHasExpired;
@synthesize subscriptionAutoRenews = subscriptionAutoRenews;
@synthesize handlesOwnBilling = handlesOwnBilling;

@synthesize nextKeyGeneration = nextKeyGeneration;
@synthesize needsKeyGeneration = needsKeyGeneration;
@synthesize needsRegisterPushToken = needsRegisterPushToken;
@synthesize needsDeprovisionUser = needsDeprovisionUser;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Init - Standard
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)initWithUUID:(NSString *)inUUID
               jid:(XMPPJID *)inJid
         networkID:(NSString *)inNetworkID
      xmppResource:(NSString *)inXmppResource
      xmppPassword:(NSString *)inXmppPassword
            apiKey:(NSString *)inApiKey
      canSendMedia:(BOOL)inCanSendMedia
         isEnabled:(BOOL)inEnabled
{
 	if ((self = [super initWithUUID:inUUID networkID:inNetworkID jid:inJid]))
	{
		notificationUUID = [[NSUUID UUID] UUIDString]; // Should NEVER change
		
		xmppResource = [inXmppResource copy]; // Should NEVER change
		xmppPassword = [inXmppPassword copy];
		apiKey = [inApiKey copy];
		
		provisonInfo = nil;
		pushToken = nil;
		
		isEnabled = inEnabled;
		self.canSendMedia = inCanSendMedia;
		
		oldApiKey = nil;
		oldDeviceID = nil;
		
		subscriptionExpireDate = nil;
        subscriptionHasExpired = NO;
		subscriptionAutoRenews = NO;
        handlesOwnBilling = NO;
		
		nextKeyGeneration = nil;
		needsKeyGeneration = NO;
		needsRegisterPushToken = NO;
		needsDeprovisionUser = NO;
		
		// Sanity checks
		
		if (xmppResource.length == 0)
			xmppResource = [[NSUUID UUID] UUIDString];
	}
	return self;
}

- (id)initWithUUID:(NSString *)inUUID
				jid:(XMPPJID *)inJid
         networkID:(NSString *)inNetworkID
      provisonInfo:(NSDictionary *)inProvisonInfo
{
    if ((self = [super initWithUUID:inUUID networkID:inNetworkID jid:inJid]))
	{
        notificationUUID = [[NSUUID UUID] UUIDString]; // Should NEVER change
		
        xmppResource = [[NSUUID UUID] UUIDString]; // Should NEVER change
		xmppPassword = nil;
		apiKey = nil;
		
        provisonInfo = inProvisonInfo;
		pushToken = nil;
		
		isEnabled = NO;
		
		oldApiKey = nil;
		oldDeviceID = nil;
		
		subscriptionExpireDate = nil;
#if SUPPORT_PURCHASE_ACCOUNT
		subscriptionHasExpired = YES;
#else
		subscriptionHasExpired = NO;
#endif
		subscriptionAutoRenews = NO;
        handlesOwnBilling = NO;

		nextKeyGeneration = nil;
		needsKeyGeneration = NO;
		needsRegisterPushToken = NO;
		needsDeprovisionUser = NO;
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Init - Upgrade
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (instancetype)initWithRemoteUser:(STUser *)remoteUser
                      xmppResource:(NSString *)inXmppResource
                      xmppPassword:(NSString *)inXmppPassword
                            apiKey:(NSString *)inApiKey
                      canSendMedia:(BOOL)inCanSendMedia
                         isEnabled:(BOOL)inEnabled
{
	NSParameterAssert(remoteUser.isRemote);
	
	self = [self initWithUUID:remoteUser.uuid
	                      jid:remoteUser.jid
	                networkID:remoteUser.networkID
	             xmppResource:inXmppResource
	             xmppPassword:inXmppPassword
	                   apiKey:inApiKey
	             canSendMedia:inCanSendMedia
	                isEnabled:inEnabled];
	
	if (self) {
		[remoteUser copyIntoNewUser:self];
	}
	return self;
}

- (instancetype)initWithRemoteUser:(STUser *)remoteUser
                      provisonInfo:(NSDictionary *)inProvisonInfo
{
	NSParameterAssert(remoteUser.isRemote);
	
	self = [self initWithUUID:remoteUser.uuid
	                      jid:remoteUser.jid
	                networkID:remoteUser.networkID
	             provisonInfo:inProvisonInfo];
	
	if (self) {
		[remoteUser copyIntoNewUser:self];
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSCoding
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]))
	{
		int32_t version = [decoder decodeInt32ForKey:k_version];
		
		if (version == 0) // OLD version
		{
			notificationUUID = [decoder decodeObjectForKey:k_notificationUUID];
			
			NSData *infoData = [decoder decodeObjectForKey:@"infoData"];
			NSDictionary *info = [NSPropertyListSerialization propertyListWithData:infoData
			                                                               options:0
			                                                                format:NULL
			                                                                 error:NULL];
			
			xmppResource = [info objectForKey:@"xmppResource"]; // Do not change - OLD version
			xmppPassword = [info objectForKey:@"password"];     // Do not change - OLD version
  			apiKey       = [info objectForKey:@"apiKey"];       // Do not change - OLD version
			
			pushToken = nil;
			isEnabled = [[info objectForKey:@"enabled"] boolValue];
			
			oldApiKey = nil;
			oldDeviceID  = [info objectForKey:@"deviceID"];     // Do not change - OLD version
			
			subscriptionExpireDate = nil;
			subscriptionHasExpired = NO;
			subscriptionAutoRenews = NO;
			handlesOwnBilling = NO;
			
			nextKeyGeneration = nil;
			needsKeyGeneration = NO;
			needsRegisterPushToken = NO;
			needsDeprovisionUser = NO;
		}
		else // if (version >= 1) // NEW version(s)
		{
			notificationUUID = [decoder decodeObjectForKey:k_notificationUUID];
			
			xmppResource = [decoder decodeObjectForKey:k_xmppResource];
			xmppPassword = [decoder decodeObjectForKey:k_xmppPassword];
			apiKey       = [decoder decodeObjectForKey:k_apiKey];
			
			provisonInfo = [decoder decodeObjectForKey:k_provisonInfo];
			pushToken = [decoder decodeObjectForKey:k_pushToken];
			
			isEnabled = [decoder decodeBoolForKey:k_isEnabled];
			
			oldApiKey   = [decoder decodeObjectForKey:k_oldApiKey];
			oldDeviceID = [decoder decodeObjectForKey:k_oldDeviceID];
			
			subscriptionExpireDate = [decoder decodeObjectForKey:k_subscriptionExpireDate];
			subscriptionHasExpired = [decoder decodeBoolForKey:k_subscriptionHasExpired];
			subscriptionAutoRenews = [decoder decodeBoolForKey:k_subscriptionAutoRenews];
			handlesOwnBilling = [decoder decodeBoolForKey:k_handlesOwnBilling];
			
			nextKeyGeneration = [decoder decodeObjectForKey:k_nextKeyGeneration];
			needsKeyGeneration = [decoder decodeBoolForKey:k_needsKeyGeneration];
			needsRegisterPushToken = [decoder decodeBoolForKey:k_needsRegisterPushToken];
			needsDeprovisionUser = [decoder decodeBoolForKey:k_needsDeprovisionUser];
		}
		
		// Sanitization
		
		if (![self.networkID isEqualToString:kNetworkID_Fake])
		{
			if (nextKeyGeneration == nil && !needsKeyGeneration)
				needsKeyGeneration = YES;
		}
	}
	return self;
}

- (id)awakeAfterUsingCoder:(NSCoder *)decoder
{
	// Overrides the awakeAfterUsingCoder method in STUser.m
	return self;
}

//- (Class)classForCoder
//{
//	if (xmppResource && xmppPassword) {
//		DDLogOrange(@"classForCoder: %@ -> STLocalUser", self.jid);
//		return [STLocalUser class];
//	}
//	else {
//		DDLogOrange(@"classForCoder: %@ -> STUser", self.jid);
//		return [STUser class];
//	}
//}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[super encodeWithCoder:coder];
	
	[coder encodeObject:notificationUUID forKey:k_notificationUUID];
	
	[coder encodeObject:xmppResource forKey:k_xmppResource];
	[coder encodeObject:xmppPassword forKey:k_xmppPassword];
	[coder encodeObject:apiKey       forKey:k_apiKey];
	
	[coder encodeObject:provisonInfo forKey:k_provisonInfo];
	[coder encodeObject:pushToken forKey:k_pushToken];
	
	[coder encodeBool:isEnabled forKey:k_isEnabled];
	
	[coder encodeObject:oldApiKey   forKey:k_oldApiKey];
	[coder encodeObject:oldDeviceID forKey:k_oldDeviceID];
	
	[coder encodeObject:subscriptionExpireDate forKey:k_subscriptionExpireDate];
	[coder encodeBool:subscriptionHasExpired   forKey:k_subscriptionHasExpired];
	[coder encodeBool:subscriptionAutoRenews   forKey:k_subscriptionAutoRenews];
	[coder encodeBool:handlesOwnBilling        forKey:k_handlesOwnBilling];
	
	[coder encodeObject:nextKeyGeneration      forKey:k_nextKeyGeneration];
	[coder encodeBool:needsKeyGeneration       forKey:k_needsKeyGeneration];
	[coder encodeBool:needsRegisterPushToken   forKey:k_needsRegisterPushToken];
	[coder encodeBool:needsDeprovisionUser     forKey:k_needsDeprovisionUser];
	
//	if (xmppResource && xmppPassword)
//		[coder encodeBool:NO forKey:@"isRemote"];
//	else
//		[coder encodeBool:YES forKey:@"isRemote"];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSCopying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
{
	STLocalUser *copy = [super copyWithZone:zone];
	
	copy->notificationUUID = notificationUUID;
	
	copy->xmppResource = xmppResource;
	copy->xmppPassword = xmppPassword;
	copy->apiKey = apiKey;
	
	copy->provisonInfo = provisonInfo;
	copy->pushToken = pushToken;
	
	copy->isEnabled = isEnabled;
	
	copy->oldApiKey = oldApiKey;
	copy->oldDeviceID = oldDeviceID;
	
	copy->subscriptionExpireDate = subscriptionExpireDate;
	copy->subscriptionHasExpired = subscriptionHasExpired;
	copy->subscriptionAutoRenews = subscriptionAutoRenews;
	copy->handlesOwnBilling      = handlesOwnBilling;
	
	copy->nextKeyGeneration = nextKeyGeneration;
	copy->needsKeyGeneration = needsKeyGeneration;
	copy->needsRegisterPushToken = needsRegisterPushToken;
	copy->needsDeprovisionUser = needsDeprovisionUser;
	
	return copy;
}

/**
 * For deactivating / reactivating.
**/
- (id)deactivatedCopy
{
	STLocalUser *copy = [self copy];
	
	// Important: Do NOT change the xmppResource/deviceID !!!
	
	copy->oldApiKey = apiKey;
	
	copy->xmppPassword = nil;
	copy->apiKey = nil;
	copy->isEnabled = NO;
	
	copy.lastUpdated = [NSDate date];
	
	return copy;
}

- (id)copyWithXmppPassword:(NSString *)inXmppPassword
                    apiKey:(NSString *)inApiKey
              canSendMedia:(BOOL)inCanSendMedia
                 isEnabled:(BOOL)inEnabled
{
   	STLocalUser *copy = [self copy];
	
	copy->xmppPassword = [inXmppPassword copy];
	copy->apiKey = [inApiKey copy];
    
	copy->isEnabled = inEnabled;
	
	copy.canSendMedia = inCanSendMedia;
	copy.lastUpdated = [NSDate date];
	
	// Sanitization (for old versions that nil'd the xmppResource using this method)
	if (copy->xmppResource == nil)
		copy->xmppResource = [[NSUUID UUID] UUIDString];
	
    return copy;
}

- (id)copyWithNewProvisionInfo:(NSDictionary *)inProvisonInfo
{
	STLocalUser *copy = [self copy];
	
	copy->provisonInfo = inProvisonInfo ? [inProvisonInfo copy] : nil;
	
	copy.lastUpdated = [NSDate date];
	
	// Sanitization (for old versions that nil'd the xmppResource using this method)
	if (copy->xmppResource == nil)
		copy->xmppResource = [[NSUUID UUID] UUIDString];
	
	return copy;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Convenience Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isLocal
{
	// Overrides method in STUser
	return YES;
}

- (BOOL)isRemote
{
	// Overrides method in STUser
	return NO;
}

- (BOOL)isActivated
{
	return (apiKey.length > 0 && xmppResource.length > 0);
}

- (NSString *)deviceID
{
	return xmppResource; // deviceID == xmppResource
}

- (NSString *)appStoreHash
{
	return [self.uuid sha1String];
}

@end
