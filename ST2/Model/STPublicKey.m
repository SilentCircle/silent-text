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
#import "STPublicKey.h"
#import "NSDate+SCDate.h"

static int const kSTPublicKeyCurrentVersion = 1;

/**
 * Keys for encoding / decoding (to avoid typos)
**/
static NSString *const k_version             = @"version";
static NSString *const k_uuid                = @"uuid";
static NSString *const k_userID              = @"userUUID";
static NSString *const k_deprecated_infoData = @"infoData";
static NSString *const k_keyJSON             = @"keyJSON";
static NSString *const k_isExpired           = @"isExpired";
static NSString *const k_continuityVerified  = @"continuityVerified";
static NSString *const k_isPrivateKey        = @"isPrivateKey";
static NSString *const k_serverUploadDate    = @"serverUploadDate";
static NSString *const k_serverDeleteDate    = @"serverDeleteDate";
static NSString *const k_needsServerDelete   = @"needsServerDelete";

@interface STPublicKey ()

@property (atomic, strong, readwrite) NSDictionary *cachedKeyDict;

@end

@implementation STPublicKey

@synthesize uuid   = uuid;
@synthesize userID = userID;
@synthesize keyJSON = keyJSON;
@synthesize isPrivateKey = isPrivateKey;

@synthesize isExpired = isExpired;
@synthesize continuityVerified = continuityVerified;

@synthesize serverUploadDate = serverUploadDate;
@synthesize serverDeleteDate = serverDeleteDate;
@synthesize needsServerDelete = needsServerDelete;

@synthesize cachedKeyDict = _cachedKeyDict_atomic_property_must_use_selfDot_syntax;

@dynamic keyDict;
@dynamic owner;
@dynamic startDate;
@dynamic expireDate;

static BOOL MakeSigningKey(SCKeySuite        keySuite,
                           NSString        * jidStr,
                           SCKeyContextRef   storageKey,
                           NSDate          * expireDate,
                           NSString       ** keyStringOut,
                           NSString       ** locatorOut)
{
    BOOL success = NO;
    SCLError     err = kSCLError_NoErr;
    
    NSString* privKey = NULL;
    NSString* locator = NULL;
    
    SCKeyContextRef ecKey = kInvalidSCKeyContextRef;
    time_t startTime  = [[NSDate date] timeIntervalSince1970];
     
    char* keyLocatorString = NULL;
   
    uint8_t*  keyData = NULL;
    size_t  keyDataLen = 0;
    
    uint8_t symKey[64];
    size_t  symKeyLen = 0;
      
    err = SCKeyGetProperty(storageKey, kSCKeyProp_SymmetricKey, NULL,  symKey , sizeof(symKey), &symKeyLen); CKERR;
     
    err = SCKeyNew(keySuite, symKey, symKeyLen,  &ecKey); CKERR;
    err = SCKeySetProperty(ecKey, kSCKeyProp_StartDate,  SCKeyPropertyType_Time ,  &startTime, sizeof(time_t)); CKERR;
    
    if(expireDate)
    {
        time_t expireTime = [expireDate timeIntervalSince1970];
        err = SCKeySetProperty(ecKey, kSCKeyProp_ExpireDate, SCKeyPropertyType_Time, &expireTime, sizeof(time_t)); CKERR;
      
    }
    err = SCKeySetProperty(ecKey, kSCKeyProp_Owner, SCKeyPropertyType_UTF8String, (void*) jidStr.UTF8String, jidStr.length); CKERR;
    
    err = SCKeyGetAllocatedProperty(ecKey, kSCKeyProp_Locator,NULL,  (void*)&keyLocatorString ,  NULL); CKERR;
    locator = [NSString stringWithUTF8String:keyLocatorString];
    
    /* store priv key */
    err = SCKeySerializePrivateWithSCKey(ecKey, storageKey, &keyData, &keyDataLen); CKERR;
    privKey = [[NSString alloc]initWithBytesNoCopy:keyData length:keyDataLen encoding:NSUTF8StringEncoding freeWhenDone:YES];
    
    if(keyStringOut) *keyStringOut = privKey;
    if(locatorOut) *locatorOut = locator;
    
    SCKeyFree(ecKey); ecKey =  kInvalidSCKeyContextRef;
    success = YES;
    
done:
  
    if(keyLocatorString)
        XFREE(keyLocatorString);


    ZERO(symKey, sizeof(symKey));
    
    if(SCKeyContextRefIsValid(ecKey))
        SCKeyFree(ecKey);
    
    return success;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Init & Dealloc
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (id)privateKeyWithOwner:(NSString *)owner
                   userID:(NSString *)userID
               expireDate:(NSDate *)expireDate
               storageKey:(SCKeyContextRef)storageKey
                 keySuite:(SCKeySuite)keySuite
{
	NSString *keyString = nil;
	NSString *locator = nil;
  
	if (MakeSigningKey(keySuite, owner, storageKey, expireDate, &keyString, &locator))
	{
		return [[STPublicKey alloc] initWithUUID:locator
		                                  userID:userID
		                                 keyJSON:keyString
		                            isPrivateKey:YES];
	}
	else
	{
		return nil;
	}
}


+ (id)keyWithJSON:(NSString *)inKeyJSON
           userID:(NSString *)inUserID
{
	if (inKeyJSON == nil) return nil;
	
	STPublicKey * key = nil;
	NSString    * locator = nil;
	
	SCLError err = kSCLError_NoErr;
    SCKeyContextRef pubKey = kInvalidSCKeyContextRef;
	char *locatorStr = NULL;
	
	NSUInteger jsonLen_utf8 = [inKeyJSON lengthOfBytesUsingEncoding:NSUTF8StringEncoding]; // utf8Len != strLen
	const char *json_utf8 = [inKeyJSON UTF8String];
	
	err = SCKeyDeserialize((uint8_t *)json_utf8, (size_t)jsonLen_utf8, &pubKey); CKERR;
	
	err = SCKeyGetAllocatedProperty(pubKey, kSCKeyProp_Locator, NULL, (void *)&locatorStr, NULL);
	if (locatorStr) {
		// [NSString stringWithUTF8String] -> throws an exception if param is NULL
		locator = [NSString stringWithUTF8String:locatorStr];
	}
 
done:

	if (locatorStr)
		XFREE(locatorStr);

	if (SCKeyContextRefIsValid(pubKey))
		SCKeyFree(pubKey);

	if (locator)
	{
		key = [[STPublicKey alloc] initWithUUID:locator
		                                 userID:inUserID
		                                keyJSON:inKeyJSON
		                           isPrivateKey:YES];
	}
	
    return key;
}

- (id)initWithUUID:(NSString *)inUUID
            userID:(NSString *)inUserID
           keyJSON:(NSString *)inKeyJSON
      isPrivateKey:(BOOL)inPrivateKey
{
	if ((self = [super init]))
	{
		uuid = [inUUID copy];
		userID = [inUserID copy];
		keyJSON = [inKeyJSON copy];
		isPrivateKey = inPrivateKey;
		
		isExpired = NO;
		continuityVerified = NO;
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSCoding
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Version History:
 * 
 * - v0 : The following were stored in a NSDictionary, which was serialized using a plist:
 *        - keyJSON
 *        - isPrivateKey
 *        - isExpired
 *        - continuityVerified
 * 
 * - v1 : Updated to modern coding style. (dropped info dictionary wrapper)
**/

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		int version = [decoder decodeIntForKey:k_version];
		
		uuid = [decoder decodeObjectForKey:k_uuid];
		userID = [decoder decodeObjectForKey:k_userID];
		
		if (version == 0) // OLD version
		{
			// Version 0 put the following ivars in a dictionary:
			// - keyJSON
			// - isExpired
			// - isPrivateKey
			// - continuityVerified
			//
			// And it serialzed the dictionary via NSPropertyListSerialization.
			
			NSData *infoData = [decoder decodeObjectForKey:k_deprecated_infoData];
			NSDictionary *info =
			  [NSPropertyListSerialization propertyListWithData:infoData options:0 format:NULL error:NULL];
			
			keyJSON            = [info objectForKey:k_keyJSON];
			isPrivateKey       = [[info objectForKey:k_isPrivateKey] boolValue];
			isExpired          = [[info objectForKey:k_isExpired] boolValue];
			continuityVerified = [[info objectForKey:k_continuityVerified] boolValue];
			
			serverUploadDate  = [NSDate distantPast];
			serverDeleteDate  = nil;
			needsServerDelete = NO;
		}
		else // NEW(ish) version(s)
		{
			keyJSON            = [decoder decodeObjectForKey:k_keyJSON];
			isPrivateKey       = [decoder decodeBoolForKey:k_isPrivateKey];
			isExpired          = [decoder decodeBoolForKey:k_isExpired];
			continuityVerified = [decoder decodeBoolForKey:k_continuityVerified];
			
			serverUploadDate  = [decoder decodeObjectForKey:k_serverUploadDate];
			serverDeleteDate  = [decoder decodeObjectForKey:k_serverDeleteDate];
			needsServerDelete = [decoder decodeBoolForKey:k_needsServerDelete];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt:kSTPublicKeyCurrentVersion forKey:k_version];
	
    [coder encodeObject:uuid       forKey:k_uuid];
    [coder encodeObject:userID     forKey:k_userID];
	[coder encodeObject:keyJSON    forKey:k_keyJSON];
	[coder encodeBool:isPrivateKey forKey:k_isPrivateKey];
	
	[coder encodeBool:isExpired          forKey:k_isExpired];
	[coder encodeBool:continuityVerified forKey:k_continuityVerified];
	
	[coder encodeObject:serverUploadDate forKey:k_serverUploadDate];
	[coder encodeObject:serverDeleteDate forKey:k_serverDeleteDate];
	[coder encodeBool:needsServerDelete  forKey:k_needsServerDelete];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSCopying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
{
	STPublicKey *copy = [super copyWithZone:zone];
	
	copy->uuid = uuid;
	copy->userID = userID;
	copy->keyJSON = keyJSON;
	copy->isPrivateKey = isPrivateKey;
	
	copy->isExpired = isExpired;
	copy->continuityVerified = continuityVerified;
	
	copy->serverUploadDate = serverUploadDate;
	copy->serverDeleteDate = serverDeleteDate;
	copy->needsServerDelete = needsServerDelete;
	
	return copy;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark STDatabaseObject
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Overrides STDatabaseObject.
 * Allows us to specify our atomic cachedX properties as ignored (for immutability purposes).
**/
+ (NSMutableSet *)monitoredProperties
{
	NSMutableSet *result = [super monitoredProperties];
	[result removeObject:@"cachedKeyDict"];
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark KeyDict Values
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSDictionary *)keyDict
{
	// Note: We MUST use atomic getter & setter (to be thread-safe)
	
	NSDictionary *keyDict = self.cachedKeyDict;
	if (keyDict == nil)
	{
		NSData *jsonData = [keyJSON dataUsingEncoding:NSUTF8StringEncoding];
		keyDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:NULL];
		
		self.cachedKeyDict = keyDict;
	}
	
	return keyDict;
}

- (NSString *)owner
{
	NSString *key = [NSString stringWithUTF8String:kSCKeyProp_Owner];
	id value = [[self keyDict] objectForKey:key];
	
	if ([key isKindOfClass:[NSString class]])
		return (NSString *)value;
	else
		return nil;
}

- (NSDate *)startDate
{
	NSString *key = [NSString stringWithUTF8String:kSCKeyProp_StartDate];
	id value = [[self keyDict] objectForKey:key];
	
	if ([value isKindOfClass:[NSString class]])
		return [NSDate dateFromRfc3339String:(NSString *)value];
	else
		return nil;
}

- (NSDate *)expireDate
{
	NSString *key = [NSString stringWithUTF8String:kSCKeyProp_ExpireDate];
	id value = [[self keyDict] objectForKey:key];

	if ([value isKindOfClass:[NSString class]])
		return [NSDate dateFromRfc3339String:(NSString *)value];
	else
		return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Comparison
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSComparisonResult)compare:(STPublicKey *)another
{
	NSDate *startDate1 = self.startDate;
	NSDate *startDate2 = another.startDate;
	
	NSAssert(startDate1 && startDate2, @"STPublicKey has nil startDate !");
	
	NSComparisonResult result = [startDate1 compare:startDate2];
	
	if (result == NSOrderedSame)
	{
		NSDate *expireDate1 = self.expireDate;
		NSDate *expireDate2 = another.expireDate;
		
		NSAssert(expireDate1 && expireDate2, @"STPublicKey has nil expireDate !");
		
		result = [expireDate1 compare:expireDate2];
	}
	
	return result;
}

/**
 * Use this method to determine the current key from a list of keys.
 * This method should be used EVERYWHERE when the currentKey is to be chosen.
 *
 * It implements the "standard-agreed-upon-also-used-by-server-and-other-clients" algorithm:
 * 
 * > Pick the latest start date such that start_date <= now < end_date.
**/
+ (STPublicKey *)currentKeyFromKeys:(NSArray *)keys
{
	NSDate *now = [NSDate date];
	STPublicKey *currentKey = nil;
	
	for (STPublicKey *key in keys)
	{
		if (!key.isExpired &&
		    [key.startDate isBeforeOrEqual:now] && // start_date <= now
		    [key.expireDate isAfter:now])          //               now > end_date
		{
			if (currentKey == nil || [key.startDate isAfter:currentKey.startDate])
			{
				currentKey = key;
			}
		}
	}
	
	return currentKey;
}

 
@end
