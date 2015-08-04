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
#import <AddressBook/ABPerson.h>

#import "STUser.h"
#import "STLocalUser.h"
#import "STLogging.h"
#import "AppConstants.h"
#import "DatabaseManager.h"
#import "NSString+SCUtilities.h"

/**
 * Keys for encoding / decoding (to avoid typos)
**/
static NSString *const k_version                = @"version";
static NSString *const k_uuid                   = @"uuid";

static NSString *const k_JID                    = @"JID";
static NSString *const k_jidStr_deprecated      = @"jid";
static NSString *const k_networkID              = @"networkID";

static NSString *const k_avatarFileName         = @"avatarFileName";
static NSString *const k_avatarSource           = @"avatarSource";
static NSString *const k_avatarLastUpdated      = @"avatarLastUpdated";

static NSString *const k_hasPhone               = @"hasPhone";
static NSString *const k_canSendMedia           = @"canSendMedia";
static NSString *const k_isSavedToSC            = @"isSavedToSC";

static NSString *const k_publicKeyIDs           = @"publicKeyIDs";
static NSString *const k_currentKeyID           = @"currentKeyID";

static NSString *const k_activeDeviceID         = @"activeDeviceID";

static NSString *const k_email                  = @"email";
static NSString *const k_spNumbers              = @"spNumbers";

static NSString *const k_abRecordID             = @"abRecordID";
static NSString *const k_isAutoLinkedToAB       = @"isLinkedByAB";

static NSString *const k_sc_firstName           = @"sc_firstName";
static NSString *const k_sc_lastName            = @"sc_lastName";
static NSString *const k_sc_compositeName       = @"sc_compositeName";
static NSString *const k_sc_organization        = @"sc_organization";
static NSString *const k_sc_notes               = @"sc_notes";

static NSString *const k_ab_firstName           = @"ab_firstName";
static NSString *const k_ab_lastName            = @"ab_lastName";
static NSString *const k_ab_compositeName       = @"ab_compositeName";
static NSString *const k_ab_organization        = @"ab_organization";
static NSString *const k_ab_notes               = @"ab_notes";

static NSString *const k_web_firstName          = @"web_firstName";
static NSString *const k_web_lastName           = @"web_lastName";
static NSString *const k_web_compositeName      = @"web_compositeName";
static NSString *const k_web_organization       = @"web_organization";
static NSString *const k_web_avatarURL          = @"web_web_avatarURL";
static NSString *const k_web_hash               = @"web_hash";

static NSString *const k_lastLocation           = @"lastLocation";

static NSString *const k_nextWebRefresh         = @"nextWebRefresh";
static NSString *const k_awaitingReKeying       = @"awaitingReKeying";

static NSString *const k_lastUpdated            = @"lastUpdated";

static NSString *const k_deprecated_isRemote    = @"isRemote";


@interface STUser ()
@property (nonatomic, copy, readwrite) XMPPJID  *jid;
@end

#pragma mark -

@implementation STUser

@synthesize uuid = uuid;

@synthesize jid = jid;
@synthesize networkID = networkID;

@synthesize avatarFileName = avatarFileName;
@synthesize avatarSource = avatarSource;
@synthesize avatarLastUpdated = avatarLastUpdated;

@synthesize hasPhone = hasPhone;
@synthesize canSendMedia = canSendMedia;
@synthesize isSavedToSilentContacts = isSavedToSilentContacts;

@synthesize currentKeyID = currentKeyID;
@synthesize publicKeyIDs = publicKeyIDs;

@synthesize activeDeviceID = activeDeviceID;

@synthesize email = email;
@synthesize spNumbers = spNumbers;

@synthesize abRecordID  = abRecordID;
@synthesize isAutomaticallyLinkedToAB = isAutomaticallyLinkedToAB;

@synthesize sc_firstName = sc_firstName;
@synthesize sc_lastName = sc_lastName;
@synthesize sc_compositeName = sc_compositeName;
@synthesize sc_organization = sc_organization;
@synthesize sc_notes = sc_notes;

@synthesize ab_firstName = ab_firstName;
@synthesize ab_lastName = ab_lastName;
@synthesize ab_compositeName = ab_compositeName;
@synthesize ab_organization = ab_organization;
@synthesize ab_notes = ab_notes;

@synthesize web_firstName = web_firstName;
@synthesize web_lastName = web_lastName;
@synthesize web_compositeName = web_compositeName;
@synthesize web_organization = web_organization;
@synthesize web_avatarURL = web_avatarURL;
@synthesize web_hash = web_hash;

@synthesize lastLocation = lastLocation;

@synthesize nextWebRefresh = nextWebRefresh;
@synthesize awaitingReKeying = awaitingReKeying;

@synthesize lastUpdated = lastUpdated;

@dynamic isLocal;
@dynamic isRemote;


#pragma mark Init

/**
 * Creates a basic STUser with the minimum required properties.
 * All other properties should be set manually.
**/
- (id)initWithUUID:(NSString *)inUUID
         networkID:(NSString *)inNetworkID
               jid:(XMPPJID *)inJid
{
    if ((self = [super init]))
    {
        uuid = [inUUID copy];
        
        jid = [inJid bareJID];
        networkID = [inNetworkID copy];
		
        avatarFileName = nil;
        avatarSource = kAvatarSource_None;
		avatarLastUpdated = nil;
        
        hasPhone = NO;
		canSendMedia = NO;
		isSavedToSilentContacts = NO;
        
        publicKeyIDs = [[NSSet alloc] init];
        currentKeyID = nil;
		
		activeDeviceID = nil;
		
		email = nil;
        spNumbers = nil;
        
        abRecordID = kABRecordInvalidID;
        isAutomaticallyLinkedToAB = NO;
		
		sc_firstName = nil;
		sc_lastName = nil;
		sc_compositeName = nil;
		sc_organization = nil;
		sc_notes = nil;
		
        ab_firstName = nil;
        ab_lastName = nil;
        ab_compositeName = nil;
        ab_organization = nil;
        ab_notes = nil;
        
        web_firstName = nil;
        web_lastName = nil;
        web_compositeName = nil;
		web_organization = nil;
        web_avatarURL = nil;
		web_hash = nil;
        
        lastLocation = nil;
		
		nextWebRefresh = [NSDate distantPast];
		awaitingReKeying = NO;
		
        lastUpdated = [NSDate date];
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark JSON Format
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)initWithJsonDictionary:(NSDictionary*)inJsonDict
                        UUID:(NSString *)inUUID
{
    if ((self = [super init]))
    {
        uuid = [inUUID copy];
        
        [inJsonDict enumerateKeysAndObjectsUsingBlock:^(id jsonKey, id jsonValue, BOOL *stop) {
            
            [self setLocalValueFromCloudValue:jsonValue forCloudKey:jsonKey];
        }];
        
        // Handle all other non-sync-stuff ivars
        
        // ...
        
        // Object sanitation & checking
        
        // ...
    }
    return self;
}

- (NSDictionary *)syncableJsonDictionary
{
	NSSet *allCloudProperties = self.allCloudProperties;
	NSMutableDictionary *jsonDict = [NSMutableDictionary dictionaryWithCapacity:allCloudProperties.count];
	
	for (NSString *cloudKey in allCloudProperties)
	{
		id cloudValue = [self cloudValueForCloudKey:cloudKey];
		if (cloudValue) {
			[jsonDict setObject:cloudValue forKey:cloudKey];
		}
	}
	
	return jsonDict;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSCoding
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// NSCoding version history:
//
// 0 : Every ivar (except uuuid) was stored in a "infoData" plist.
//     This was used back then because YapDatabase didn't have all the flexibility it has now.
//     So to get encryption without the serializer/deserializer block, we were planning on encrypting the plist data.
//
// 1 : Moved to modern architecture, where everything is stored directly in the coder.
//     We now get automatic object encryption via YapDatabase's serializer/deserializer block.
//
// 2 : We added all the sc_X, web_X & ab_X properties in order to keep everything straight,
//     and properly support overriding fields with levels of priority.
//
// 3 : Unknown. Version bump was possibly not demonstrably necessary.
//
// 4 : The jid property is now a proper XMPPJID.
// 4b: The STLocalUser class was added, that split out the local-specific properties into a subclass.
//
// 5 : Added isSavedToSilentContacts property.
//     Version bump required because we need this to default to YES from older versions.
// 5b: Added awaitingReKeying property.
// 5c: Added web_organization property.
//

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		int32_t version = [decoder decodeInt32ForKey:k_version];
		
		if (version == 0) // OLD version
		{
        	uuid = [decoder decodeObjectForKey:k_uuid];
 			
			NSData *infoData = [decoder decodeObjectForKey:@"infoData"];
			NSDictionary *info = [NSPropertyListSerialization propertyListWithData:infoData
			                                                               options:0
			                                                                format:NULL
			                                                                 error:NULL];
			NSString *jidStr = [info objectForKey:@"user"];
			jid = [[XMPPJID jidWithString:jidStr] bareJID];
			
			networkID = [info objectForKey:@"networkID"];    // Do not change - OLD version
			
			avatarFileName = nil;
			avatarSource = kAvatarSource_None;
			avatarLastUpdated = nil;
			
			hasPhone     = [[info objectForKey:@"hasPhone"] boolValue];
			canSendMedia = [[info objectForKey:@"canSendMedia"] boolValue];
			isSavedToSilentContacts = YES;
			
			NSArray *keyIds = [decoder decodeObjectForKey:@"publicKeyIDs"];
			publicKeyIDs = keyIds ? [NSSet setWithArray:keyIds] : [[NSSet alloc] init];
			currentKeyID = [info objectForKey:@"currentKeyID"];
			
			activeDeviceID = nil;
			
			email = nil;
			spNumbers = [info objectForKey:@"spNumbers"];
			
			NSNumber *_abRecordID = [info objectForKey:@"ABRecordID"];
			abRecordID = _abRecordID ? [_abRecordID intValue] : kABRecordInvalidID;
			
			sc_firstName = [info objectForKey:@"firstName"];
			sc_lastName  = [info objectForKey:@"lastName"];
			sc_compositeName = nil;
			sc_organization = nil;
			sc_notes = nil;
			
			ab_firstName     = nil;
			ab_lastName      = nil;
			ab_compositeName = nil;
			ab_organization  = nil;
			ab_notes         = nil;
			
            web_firstName = nil;
            web_lastName = nil;
            web_compositeName = nil;
			web_organization = nil;
            web_avatarURL = nil;
			web_hash = nil;

			nextWebRefresh = nil;
			awaitingReKeying = NO;
			
			lastUpdated = [info objectForKey:@"lastUpdated"];
		}
		else // if (version >= 1) // NEW version(s)
		{
			uuid = [decoder decodeObjectForKey:k_uuid];
			
			if (version <= 3)
			{
				NSString *jidStr = [decoder decodeObjectForKey:k_jidStr_deprecated];
				
				if ([jidStr isEqualToString:kSTInfoUsername_deprecated])
					jid = [AppConstants stInfoJID];
				else
					jid = [[XMPPJID jidWithString:jidStr] bareJID];
			}
			else // if (version >= 4)
			{
				jid = [decoder decodeObjectForKey:k_JID];
			}
			
            networkID = [decoder decodeObjectForKey:k_networkID];
			
			avatarFileName = [decoder decodeObjectForKey:k_avatarFileName];
			avatarLastUpdated = [decoder decodeObjectForKey:k_avatarLastUpdated];
            
            if ([decoder containsValueForKey:k_avatarSource])
                avatarSource =  [decoder decodeIntegerForKey:k_avatarSource];
            else
                avatarSource = kAvatarSource_None;
			
			hasPhone     = [decoder decodeBoolForKey:k_hasPhone];
			canSendMedia = [decoder decodeBoolForKey:k_canSendMedia];
			
			if (version <= 4)
				isSavedToSilentContacts = YES;
			else // (if version >= 5)
				isSavedToSilentContacts = [decoder decodeBoolForKey:k_isSavedToSC];
			
			publicKeyIDs = [decoder decodeObjectForKey:k_publicKeyIDs];
			currentKeyID = [decoder decodeObjectForKey:k_currentKeyID];
			
			activeDeviceID = [decoder decodeObjectForKey:k_activeDeviceID];
			
			email     = [decoder decodeObjectForKey:k_email];
			spNumbers = [decoder decodeObjectForKey:k_spNumbers];
			
			abRecordID = [decoder decodeInt32ForKey:k_abRecordID];
            isAutomaticallyLinkedToAB = [decoder decodeBoolForKey:k_isAutoLinkedToAB];
   
			if (version <= 1)
			{
				sc_firstName     = [decoder decodeObjectForKey:@"firstName"];
				sc_lastName      = [decoder decodeObjectForKey:@"lastName"];
				sc_compositeName = nil;
				sc_organization  = [decoder decodeObjectForKey:@"organization"];
				sc_notes         = [decoder decodeObjectForKey:@"notes"];
				
				ab_firstName     = [decoder decodeObjectForKey:k_ab_firstName];
				ab_lastName      = [decoder decodeObjectForKey:k_ab_lastName];
				ab_compositeName = [decoder decodeObjectForKey:@"compositeName"];
				ab_organization  = [decoder decodeObjectForKey:k_ab_organization];
				ab_notes         = [decoder decodeObjectForKey:k_ab_notes];
				
				web_firstName     = [decoder decodeObjectForKey:k_web_firstName];
				web_lastName      = [decoder decodeObjectForKey:k_web_lastName];
				web_compositeName = [decoder decodeObjectForKey:k_web_compositeName];
				web_avatarURL     = nil;
				web_hash          = nil;
			}
			else // if (version >= 2)
			{
				sc_firstName     = [decoder decodeObjectForKey:k_sc_firstName];
				sc_lastName      = [decoder decodeObjectForKey:k_sc_lastName];
				sc_compositeName = [decoder decodeObjectForKey:k_sc_compositeName];
				sc_organization  = [decoder decodeObjectForKey:k_sc_organization];
				sc_notes         = [decoder decodeObjectForKey:k_sc_notes];
				
				ab_firstName     = [decoder decodeObjectForKey:k_ab_firstName];
				ab_lastName      = [decoder decodeObjectForKey:k_ab_lastName];
				ab_compositeName = [decoder decodeObjectForKey:k_ab_compositeName];
				ab_organization  = [decoder decodeObjectForKey:k_ab_organization];
				ab_notes         = [decoder decodeObjectForKey:k_ab_notes];
				
				web_firstName     = [decoder decodeObjectForKey:k_web_firstName];
				web_lastName      = [decoder decodeObjectForKey:k_web_lastName];
				web_compositeName = [decoder decodeObjectForKey:k_web_compositeName];
				web_organization  = [decoder decodeObjectForKey:k_web_organization];
 				web_avatarURL     = [decoder decodeObjectForKey:k_web_avatarURL];
				web_hash          = [decoder decodeObjectForKey:k_web_hash];
  			}
			
            lastLocation =  [decoder decodeObjectForKey:k_lastLocation];
			
			nextWebRefresh = [decoder decodeObjectForKey:k_nextWebRefresh];
			awaitingReKeying = [decoder decodeBoolForKey:k_awaitingReKeying];
			
			lastUpdated = [decoder decodeObjectForKey:k_lastUpdated];
		}
		
		// Sanitization
		
        if (networkID == nil)
            networkID = kNetworkID_Production;
        
        if ([jid isKindOfClass:[NSString class]]) // oops, this was an old entry
        {
            NSDictionary *netInfo = [AppConstants.SilentCircleNetworkInfo objectForKey:networkID];
            NSString *domain = netInfo?[netInfo objectForKey:@"xmppDomain"]:kDefaultAccountDomain;

            NSString* jidStr = (NSString *)jid;
            
            NSRange range = [jidStr rangeOfString:@"@"];
            if (range.location == NSNotFound)
            {
                jid = [XMPPJID jidWithUser:jidStr domain:domain resource:nil];
            }
            else
            {
                jid = [XMPPJID jidWithString:jidStr];
            }
		}
        
		if (jid.user.length == 0)  // jid was screwed up from upgrade of STUser model
        {
            NSDictionary *netInfo = [AppConstants.SilentCircleNetworkInfo objectForKey:networkID];
            NSString *domain = netInfo?[netInfo objectForKey:@"xmppDomain"]:kDefaultAccountDomain;

			XMPPJID *newJid = [XMPPJID jidWithUser:jid.bare domain:domain resource:nil ];
			jid = newJid;
		}
 		
		if (avatarFileName != nil && avatarSource == kAvatarSource_None)
			avatarSource = kAvatarSource_SilentContacts;
		
		if (nextWebRefresh == nil)
			nextWebRefresh = [NSDate distantPast];
		
		if (lastUpdated == nil)
			lastUpdated = [NSDate distantPast];
	}
	return self;
}

- (id)awakeAfterUsingCoder:(NSCoder *)decoder
{
	BOOL isRemote = YES;
	
	int32_t version = [decoder decodeInt32ForKey:k_version];
	if (version == 0) // REALLY OLD version
	{
		NSData *infoData = [decoder decodeObjectForKey:@"infoData"];
		NSDictionary *info = [NSPropertyListSerialization propertyListWithData:infoData
		                                                               options:0
		                                                                format:NULL
		                                                                 error:NULL];
		
		isRemote = [[info objectForKey:@"isRemote"] boolValue];
	}
	else if (version < 5) // OLD version(s) prior to 'isSavedToSilentContacts'
	{
		isRemote = [decoder decodeBoolForKey:k_deprecated_isRemote];
	}
	
	if (isRemote)
	{
		return self;
	}
	else
	{
		STLocalUser *localUser = [[STLocalUser alloc] initWithCoder:decoder];
		return localUser;
	}
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt32:kSTUserVersion forKey:k_version];
	
    [coder encodeObject:uuid forKey:k_uuid];
    
	[coder encodeObject:jid          forKey:k_JID];
	[coder encodeObject:networkID    forKey:k_networkID];
	
	[coder encodeObject:avatarFileName    forKey:k_avatarFileName];
	[coder encodeInteger:avatarSource     forKey:k_avatarSource];
	[coder encodeObject:avatarLastUpdated forKey:k_avatarLastUpdated];
	
	[coder encodeBool:hasPhone      forKey:k_hasPhone];
	[coder encodeBool:canSendMedia  forKey:k_canSendMedia];
	[coder encodeBool:isSavedToSilentContacts forKey:k_isSavedToSC];
  
	[coder encodeObject:publicKeyIDs forKey:k_publicKeyIDs];
	[coder encodeObject:currentKeyID forKey:k_currentKeyID];
	
	[coder encodeObject:activeDeviceID forKey:k_activeDeviceID];
	
	[coder encodeObject:email     forKey:k_email];
	[coder encodeObject:spNumbers forKey:k_spNumbers];
  	
	[coder encodeInt32:abRecordID forKey:k_abRecordID];
	[coder encodeBool:isAutomaticallyLinkedToAB forKey:k_isAutoLinkedToAB];

	[coder encodeObject:sc_firstName     forKey:k_sc_firstName];
	[coder encodeObject:sc_lastName      forKey:k_sc_lastName];
	[coder encodeObject:sc_compositeName forKey:k_sc_compositeName];
	[coder encodeObject:sc_organization  forKey:k_sc_organization];
	[coder encodeObject:sc_notes         forKey:k_sc_notes];
	
    [coder encodeObject:ab_firstName     forKey:k_ab_firstName];
	[coder encodeObject:ab_lastName      forKey:k_ab_lastName];
	[coder encodeObject:ab_compositeName forKey:k_ab_compositeName];
	[coder encodeObject:ab_organization  forKey:k_ab_organization];
	[coder encodeObject:ab_notes         forKey:k_ab_notes];
	
	[coder encodeObject:web_firstName     forKey:k_web_firstName];
	[coder encodeObject:web_lastName      forKey:k_web_lastName];
	[coder encodeObject:web_compositeName forKey:k_web_compositeName];
	[coder encodeObject:web_organization  forKey:k_web_organization];
 	[coder encodeObject:web_avatarURL     forKey:k_web_avatarURL];
	[coder encodeObject:web_hash          forKey:k_web_hash];
    
	[coder encodeObject:lastLocation forKey:k_lastLocation];
	
	[coder encodeObject:nextWebRefresh forKey:k_nextWebRefresh];
	[coder encodeBool:awaitingReKeying forKey:k_awaitingReKeying];
	
	[coder encodeObject:lastUpdated forKey:k_lastUpdated];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSCopying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is also used to upgrade a STUser into a STLocalUser.
**/
- (void)copyIntoNewUser:(STUser *)copy
{
	copy->uuid = uuid;
	
	copy->jid = jid;
	copy->networkID = networkID;
	
	copy->avatarFileName = avatarFileName;
	copy->avatarLastUpdated = avatarLastUpdated;
	copy->avatarSource = avatarSource;
	
	copy->hasPhone = hasPhone;
	copy->canSendMedia = canSendMedia;
	copy->isSavedToSilentContacts = isSavedToSilentContacts;
	
	copy->publicKeyIDs = publicKeyIDs;
	copy->currentKeyID = currentKeyID;
	
	copy->activeDeviceID = activeDeviceID;
	
	copy->email = email;
	copy->spNumbers = spNumbers;
	
	copy->abRecordID = abRecordID;
	copy->isAutomaticallyLinkedToAB = isAutomaticallyLinkedToAB;
	
	copy->sc_firstName = sc_firstName;
	copy->sc_lastName = sc_lastName;
	copy->sc_compositeName = sc_compositeName;
	copy->sc_organization = sc_organization;
	copy->sc_notes = sc_notes;
	
	copy->ab_firstName = ab_firstName;
	copy->ab_lastName = ab_lastName;
	copy->ab_compositeName = ab_compositeName;
	copy->ab_organization = ab_organization;
	copy->ab_notes = ab_notes;
	
	copy->web_firstName = web_firstName;
	copy->web_lastName = web_lastName;
	copy->web_compositeName = web_compositeName;
	copy->web_organization = web_organization;
	copy->web_avatarURL = web_avatarURL;
	copy->web_hash = web_hash;
	
	copy->lastLocation = lastLocation;
	
	copy->nextWebRefresh = nextWebRefresh;
	copy->awaitingReKeying = awaitingReKeying;
	
	copy->lastUpdated = lastUpdated;
}

- (id)copyWithZone:(NSZone *)zone
{
	STUser *copy = [super copyWithZone:zone];
	[self copyIntoNewUser:copy];
	
	return copy;
}

- (id)copyWithNewUUID:(NSString *)inUuid
{
	STUser *copy = [self copy];
	
	copy->uuid = [inUuid copy];
	
	return copy;
}

- (id)copyWithNewJID:(XMPPJID *)inJid networkID:(NSString *)inNetworkID
{
	STUser *copy = [self copy];
	
	copy->jid = [inJid bareJID];
	copy->networkID = [inNetworkID copy];
    copy->lastUpdated = [NSDate date];

	return copy;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark YapDatabaseRelationshipNode Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray *)yapDatabaseRelationshipEdges
{
	if (avatarFileName == nil) return nil;
	
	NSString *avatarFilePath = [[DatabaseManager blobDirectory] stringByAppendingPathComponent:avatarFileName];
	
	YapDatabaseRelationshipEdge *edge =
	  [YapDatabaseRelationshipEdge edgeWithName:@"blob"
	                        destinationFilePath:avatarFilePath
	                            nodeDeleteRules:YDB_DeleteDestinationIfSourceDeleted];
	
	return @[ edge ];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark STDatabaseObject Protocol
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Overrides base version in STDatabaseObject.m
**/
+ (NSMutableDictionary *)mappings_localKeyToCloudKey
{
	NSMutableDictionary *mappings_localKeyToCloudKey = [NSMutableDictionary dictionaryWithCapacity:4];
	
	mappings_localKeyToCloudKey[@"jid"]             = @"jid";
	mappings_localKeyToCloudKey[@"sc_firstName"]    = @"firstName";
	mappings_localKeyToCloudKey[@"sc_lastName"]     = @"lastName";
	mappings_localKeyToCloudKey[@"sc_organization"] = @"organization";
	
	return mappings_localKeyToCloudKey;
}

/**
 * Overrides base version in STDatabaseObject.m
**/
- (id)cloudValueForCloudKey:(NSString *)cloudKey
{
	if ([cloudKey isEqualToString:@"jid"])
	{
		return [jid bare];
	}
	else
	{
		return [super cloudValueForCloudKey:cloudKey];
	}
}

/**
 * Overrides base version in STDatabaseObject.m
**/
- (void)setLocalValueFromCloudValue:(id)cloudValue forCloudKey:(NSString *)cloudKey
{
	if ([cloudKey isEqualToString:@"jid"])
	{
		self.jid = [XMPPJID jidWithString:(NSString *)cloudValue];
	}
	else
	{
		return [super setLocalValueFromCloudValue:cloudValue forCloudKey:cloudKey];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Custom Setters
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The avatarFileName & avatarSource must be set together.
 * This method enforces this rule.
**/
- (void)setAvatarFileName:(NSString *)inAvatarFileName
			 avatarSource:(AvatarSource)inAvatarSource
{
	[self willChangeValueForKey:@"avatarFileName"]; // KVO required for isImmutable (STDatabaseObject)
	[self willChangeValueForKey:@"avatarSource"];
	[self willChangeValueForKey:@"avatarLastUpdated"];
	
	avatarFileName = [inAvatarFileName copy];
	avatarSource = inAvatarSource;
	avatarLastUpdated = [NSDate date];
	
	[self didChangeValueForKey:@"avatarFileName"];
	[self didChangeValueForKey:@"avatarSource"];
	[self didChangeValueForKey:@"avatarLastUpdated"];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Traditional User Properites
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)firstName
{
	// Rules:
	// sc_firstName has highest priority if set (length > 0)
	// ab_firstName comes second if linked
	// web_firstName comes last
	//
	// Note:
	// A whitespace only sc_firstName must still override others
	
	NSString *value = nil;
	
	if (sc_firstName.length > 0) {
		value = sc_firstName;
	}
    else if (abRecordID != kABRecordInvalidID) {
		value = ab_firstName;
	}
	else {
		value = web_firstName;
	}
	
	return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)lastName
{
	// Rules:
	// sc_lastName has highest priority if set (length > 0)
	// ab_lastName comes second if linked
	// web_lastName comes last
	//
	// Note:
	// A whitespace only sc_lastName must still override others
	
	NSString *value = nil;
	
	if (sc_lastName.length > 0) {
		value = sc_lastName;
	}
	else if (abRecordID != kABRecordInvalidID) {
		value = ab_lastName;
	}
	else {
		value = web_lastName;
	}
	
	return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)compositeName
{
	NSString *value = nil;
	
	if (sc_compositeName.length > 0) {
		value = sc_compositeName;
	}
	else if (sc_firstName.length || sc_lastName.length) {
		// These values MUST override any composite name that may be set
		value = nil;
	}
	else if (abRecordID != kABRecordInvalidID) {
        value = ab_compositeName;
    }
	else if (web_compositeName.length > 0) {
		value = web_compositeName;
	}
	else if (web_firstName.length > 0 || web_lastName.length > 0) {
		value = [NSString stringWithFormat:@"%@ %@", web_firstName?: @"", web_lastName?: @""];
	}
	
	return value;
}

- (NSString *)organization
{
	// Rules:
	// sc_organization has highest priority if set (length > 0)
	// ab_organization comes second if linked
	// web_organization comes last
	//
	// Note:
	// A whitespace only sc_organization must still override others
	
	NSString *value = nil;
	
	if (sc_organization.length > 0) {
		value = sc_organization;
	}
	else if (abRecordID != kABRecordInvalidID) {
		value = ab_organization;
    }
	else {
		value = web_organization;
	}
	
	return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)notes
{
     NSString* value = sc_notes.length? sc_notes:NULL;
    
    if(!value && abRecordID != kABRecordInvalidID)
    {
        value = ab_notes;
    }
    
    return value;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Convenience Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isLocal
{
	// Overriden by STLocalUser
	return NO;
}

- (BOOL)isRemote
{
	// Overriden by STLocalUser
	return YES;
}

- (BOOL)isTempUser
{
    return (nil == self.uuid);
}

- (BOOL)hasExtendedDisplayName
{
	NSString *cName = self.compositeName;
	if ([cName length] > 0)
		return YES;
	
	NSString *fName = self.firstName;
	if (fName.length > 0)
		return YES;
	
	NSString *lName = self.lastName;
	if (lName.length > 0)
		return YES;
	
	return NO;
}

- (NSString *)displayName
{
	NSString *cName = self.compositeName;
	
	if (cName.length > 0)
		return cName;
	
	NSString *fName = self.firstName;
	NSString *lName = self.lastName;
	
	if ((fName.length > 0) && (lName.length > 0))
	{
		return [NSString stringWithFormat:@"%@ %@", fName, lName];
	}
	else if (fName.length > 0)
	{
		return fName;
	}
	else if (lName.length > 0)
	{
		return lName;
	}
	else
	{
		NSString *oName = self.organization;
		
		if (oName.length > 0)
			return oName;
		else
			return jid.user;
	}
}

- (NSString *)initials
{
    NSString* initials = NULL;
   
    BOOL  firstNameFirst = (ABPersonGetCompositeNameFormatForRecord(NULL)==kABPersonCompositeNameFormatFirstNameFirst);
    BOOL  useInitials = NO;
    
    NSString *fName = self.firstName;
	NSString *lName = self.lastName;
    
    NSString* first =  @"";
    NSString* second = @"";
    
 	if ((fName.length > 0) && (lName.length > 0))
    {
        first =  [fName substringToIndex:1];
        second =  [lName substringToIndex:1];
        useInitials = YES;
     }
  	else if (fName.length > 0)
	{
        first =  [fName substringToIndex:1];
        useInitials = YES;

 	}
	else if (lName.length > 0)
	{
        first =  [lName substringToIndex:1];
        useInitials = YES;
 	}
    else
	{
		NSString *oName = self.organization;
		
		if (oName.length > 0)
        {
            initials =  [oName substringToIndex:1];
        }
 		else
			initials = [jid.user substringToIndex:1];
	}

    if(useInitials)
    {
        if(firstNameFirst)
        {
            initials = [NSString stringWithFormat:@"%@%@", first, second];
        }
        else
        {
            initials = [NSString stringWithFormat:@"%@%@", second, first];
        }
    }
  
    initials = initials.uppercaseString;
    
    return  initials;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString *)displayNameForUsers:(NSArray *)users
                         maxWidth:(CGFloat)maxWidth
                   textAttributes:(NSDictionary *)textAttributes
{
	NSMutableArray *userNames = [NSMutableArray arrayWithCapacity:[users count]];
    
    NSString *mDisplayName = [NSString string];
    NSUInteger count = users.count;
    
    for (STUser *user in users)
    {
        NSString *userName = user.firstName;
        
        if(!userName
           || ([[userName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0))
            userName = user.displayName;
        
        [userNames addObject:userName];
    }
    
    BOOL firstTime = YES;
    for(NSString *name in userNames)
    {
		NSString *frmt = NSLocalizedString(@" & %lu more", " & %lu more");
        NSString *andMore = [NSString stringWithFormat:frmt, (unsigned long)count];
		
	//	CGFloat andMoreWidth = [andMore sizeWithAttributes:textAttributes].width;
        
        NSString* newString = firstTime
        ? name
        : [NSString stringWithFormat:@"%@%@%@", mDisplayName, (count - 1 )?@", ":@" & ", name];
        
        CGFloat newStringWidth = [newString sizeWithAttributes:textAttributes].width;
        
        if(newStringWidth > maxWidth && count > 1)
        {
            if(firstTime)
               mDisplayName = [NSString stringWithFormat:NSLocalizedString(@"You and %d others", @"You and %d others"), count];
             else
                mDisplayName = [NSString stringWithFormat:@"%@%@", mDisplayName,andMore];
            break;
        }
        else
        {
            mDisplayName = newString;
            count--;
        }
        firstTime = NO;
        
    }
    
    return mDisplayName;
}


@end
