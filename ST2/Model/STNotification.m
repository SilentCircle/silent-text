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
#import "STNotification.h"


NSString *const kSTNotificationKey_Type = @"notificationTypeKey";
NSString *const kSTNotificationType_SubscriptionExpire  = @"SubscriptionExpire";

static int const kSTNotificationVersion = 1;

/**
 * Keys for encoding / decoding (to avoid typos)
**/
static NSString *const k_version  = @"version";
static NSString *const k_uuid     = @"uuid";
static NSString *const k_userID   = @"userUUID";
static NSString *const k_fireDate = @"fireDate";
static NSString *const k_userInfo = @"userInfo";

@implementation STNotification

@synthesize uuid = uuid;
@synthesize userID = userID;
@synthesize fireDate = fireDate;
@synthesize userInfo = userInfo;


- (id)initWithUUID:(NSString *)inUUID
            userID:(NSString *)inUserID
          fireDate:(NSDate *)inFireDate
          userInfo:(NSDictionary *)inUserInfo

{
	if ((self = [super init]))
	{
		uuid     = [inUUID copy];
		userID   = [inUserID copy];
		fireDate = [inFireDate copy];
		userInfo = [inUserInfo copy];
	}
	return self;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		uuid     = [decoder decodeObjectForKey:k_uuid];
		userID   = [decoder decodeObjectForKey:k_userID];
		fireDate = [decoder decodeObjectForKey:k_fireDate];
		userInfo = [decoder decodeObjectForKey:k_userInfo];
 	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt32:kSTNotificationVersion forKey:k_version];
	
	[coder encodeObject:uuid     forKey:k_uuid];
	[coder encodeObject:userID   forKey:k_userID];
	[coder encodeObject:fireDate forKey:k_fireDate];
	[coder encodeObject:userInfo forKey:k_userInfo];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
	STNotification *copy = [super copyWithZone:zone];
	
	copy->uuid = uuid;
	copy->userID = userID;
    copy->fireDate = fireDate;
    copy->userInfo = userInfo.copy;
    
 	return copy;
}

#pragma mark Compare

- (NSComparisonResult)compareByFireDate:(STNotification *)another
{
	NSDate *aLastFire = self.fireDate;
	NSDate *bLastFire = another.fireDate;
	
	NSAssert(aLastFire && bLastFire, @"STNotification has nil fireDate!");
	
	return [aLastFire compare:bLastFire];
}

@end
