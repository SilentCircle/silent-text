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
#import "STSymmetricKey.h"
#import "NSDate+SCDate.h"

/**
 * Keys for encoding / decoding (to avoid typos)
**/
static NSString *const k_version     = @"version";
static NSString *const k_uuid        = @"uuid";
static NSString *const k_keyJSON     = @"keyJSON";
static NSString *const k_isExpired   = @"isExpired";
static NSString *const k_lastUpdated = @"lastUpdated";
static NSString *const k_recycleDate = @"recycleDate";

static NSString *const k_deprecated_infoData = @"infoData";

// The methods SCKeySetProperty & SCKeyGetProperty allow us to insert properties with names of our own choosing.
//
// That is, there is a set of dedicated property names with kSCKeyProp_X that are pre-supported.
// But those methods actually take a char* parameter, not an enum.
// Meaning they allow us to set our own custom property names.
// So we're going to be adding our own threadID property.
//
static char *const kSCKeyProp_ThreadID = "threadID";


@interface STSymmetricKey ()
@property (atomic, readwrite) NSDictionary *cachedKeyDict;
@end


@implementation STSymmetricKey

@synthesize uuid    = uuid;
@synthesize keyJSON = keyJSON;

@synthesize isExpired = isExpired;
@synthesize lastUpdated = lastUpdated;
@synthesize recycleDate = recycleDate;

@synthesize cachedKeyDict = _cachedKeyDict_atomic_property_must_use_selfDot_syntax;


static BOOL MakeSymmmetricKey(NSString       * threadStr,
                              NSString       * creator,
                              SCKeyContextRef  storageKey,
                              NSDate         * expireDate,
                              NSString      ** keyStringOut,
                              NSString      ** locatorOut)
{
    BOOL success = NO;
    SCLError     err = kSCLError_NoErr;

    NSString* privKey = NULL;
    NSString* locator = NULL;
    
    SCKeyContextRef newKey = kInvalidSCKeyContextRef;
    time_t startTime  = [[NSDate date] timeIntervalSince1970];
    
    char* keyLocatorString = NULL;
    uint8_t* keyData = NULL;
    size_t  keyDataLen = 0;
    
    uint8_t symKey[64];
    size_t  symKeyLen = 0;
    
    err = SCKeyGetProperty(storageKey, kSCKeyProp_SymmetricKey, NULL,  symKey , sizeof(symKey), &symKeyLen); CKERR;
    
    err = SCKeyNew(kSCKeySuite_AES256, symKey, symKeyLen,  &newKey); CKERR;
    err = SCKeySetProperty(newKey, kSCKeyProp_StartDate,  SCKeyPropertyType_Time ,  &startTime, sizeof(time_t)); CKERR;
    
    if(expireDate)
    {
        time_t expireTime = [expireDate timeIntervalSince1970];
        err = SCKeySetProperty(newKey, kSCKeyProp_ExpireDate,  SCKeyPropertyType_Time ,  &expireTime, sizeof(time_t)); CKERR;
        
    }
    err = SCKeySetProperty(newKey, kSCKeyProp_ThreadID, SCKeyPropertyType_UTF8String, (void*) threadStr.UTF8String, threadStr.length); CKERR;

    if(creator && creator.length)
    {
        err = SCKeySetProperty (newKey, "creator", SCKeyPropertyType_UTF8String, (void*) creator.UTF8String, creator.length); CKERR;
    }
    
    err = SCKeyGetAllocatedProperty(newKey, kSCKeyProp_Locator,NULL,  (void*)&keyLocatorString ,  NULL); CKERR;
    locator = [NSString stringWithUTF8String:keyLocatorString];
    
    /* store priv key */
    err = SCKeySerializePrivateWithSCKey(newKey, storageKey, &keyData, &keyDataLen); CKERR;
    privKey = [[NSString alloc]initWithBytesNoCopy:keyData length:keyDataLen encoding:NSUTF8StringEncoding freeWhenDone:YES];
    
    if(keyStringOut) *keyStringOut = privKey;
    if(locatorOut) *locatorOut = locator;
    
    SCKeyFree(newKey); newKey =  kInvalidSCKeyContextRef;
    success = YES;
    
done:
    
    ZERO(symKey, sizeof(symKey));
    
    if(keyLocatorString)
        XFREE(keyLocatorString);

    if(SCKeyContextRefIsValid(newKey))
        SCKeyFree(newKey);
    
    return success;

}

static BOOL ImportSymmmetricKey(NSString  * keyStringIn,
                                NSString ** locatorOut,
                                NSString ** threadIDOut)
{
    BOOL success = NO;
    SCLError err = kSCLError_NoErr;
    
	NSString *locator = nil;
    NSString *threadID = nil;
    char *locatorStr = NULL;
    
    SCKeyContextRef newKey = kInvalidSCKeyContextRef;
    uint8_t* keyData = NULL;
    size_t  keyDataLen = 0;
	
	if (keyStringIn)
	{
		const char *key_utf8 = [keyStringIn UTF8String];
		NSUInteger keyLen_utf8 = [keyStringIn lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
		
		err = SCKeyDeserialize((uint8_t *)key_utf8, (size_t)keyLen_utf8, &newKey); CKERR;
		
		err = SCKeyGetAllocatedProperty(newKey, kSCKeyProp_Locator, NULL, (void *)&locatorStr, NULL); CKERR;
		if (locatorStr) {
			// [NSString stringWithUTF8String:] -> throws an exception if param is NULL
			locator = [NSString stringWithUTF8String:locatorStr];
		}
		
        err = SCKeyGetAllocatedProperty(newKey, kSCKeyProp_ThreadID, NULL, (void *)&keyData, &keyDataLen); CKERR;
		
		threadID = [[NSString alloc] initWithBytesNoCopy:keyData
		                                          length:keyDataLen
		                                        encoding:NSUTF8StringEncoding
		                                    freeWhenDone:YES];
	}
	
	if (threadIDOut) *threadIDOut = threadID;
	if (locatorOut) *locatorOut = locator;
    
    SCKeyFree(newKey); newKey = kInvalidSCKeyContextRef;
    success = YES;
    
done:
   
	if (locatorStr)
		XFREE(locatorStr);

	if (SCKeyContextRefIsValid(newKey))
		SCKeyFree(newKey);
    
    return success;
}


+ (id)keyWithThreadID:(NSString *)threadID
              creator:(NSString *)creator
           expireDate:(NSDate *)expireDate
           storageKey:(SCKeyContextRef)storageKey
{
	STSymmetricKey *key = nil;
	NSString *keyString = nil;
	NSString *locator = nil;
	
	if (MakeSymmmetricKey(threadID, creator, storageKey, expireDate, &keyString, &locator))
    {
        key =  [[STSymmetricKey alloc] initWithUUID:locator
                                           threadID:threadID 
                                            keyJSON:keyString];
    }
    
    return key;
}


+ (id)keyWithString:(NSString *)inKeyJSON
{
    STSymmetricKey *key = nil;
	
	NSString *threadID = nil;
	NSString *locator = nil;
	
	if (ImportSymmmetricKey(inKeyJSON, &locator, &threadID))
	{
		key = [[STSymmetricKey alloc] initWithUUID:locator
		                                  threadID:threadID
		                                   keyJSON:inKeyJSON];
	}
	
	return key;
}

- (id)initWithUUID:(NSString *)inUUID
           threadID:(NSString *)inThreadID
           keyJSON:(NSString *)inKeyJSON
{
 	if ((self = [super init]))
	{
		uuid = [inUUID copy];
		keyJSON = [inKeyJSON copy];
		
  		isExpired = NO;
		
		lastUpdated = [NSDate date];
		recycleDate = nil;
	}
	return self;
}

- (id)initWithUUID:(NSString *)inUUID
           keyJSON:(NSString *)inKeyJSON 
{
	if ((self = [super init]))
	{
		uuid = [inUUID copy];
		keyJSON = [inKeyJSON copy];
		
		isExpired = NO;
		
		lastUpdated = [NSDate date];
		recycleDate = nil;
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSCoding
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Version History:
 * 
 * v0 : The following were stored in a NSDictionary, which was serialized using a plist:
 *      - k_keyJSON
 *      - k_isExpired
 * 
 * v1 : Updated to modern coding style. (dropped info dictionary wrapper)
**/

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		int version = [decoder decodeIntForKey:k_version];
		
		if (version == 0) // OLD version
		{
			uuid = [decoder decodeObjectForKey:k_uuid];
			
			NSData *infoData = [decoder decodeObjectForKey:k_deprecated_infoData];
			NSDictionary *info =
			  [NSPropertyListSerialization propertyListWithData:infoData options:0 format:NULL error:NULL];
			
			keyJSON = [info objectForKey:k_keyJSON];
			isExpired = [[info objectForKey:k_isExpired] boolValue];
			
			lastUpdated = [decoder decodeObjectForKey:k_lastUpdated];
			recycleDate = [decoder decodeObjectForKey:k_recycleDate];
		}
		else // NEW(ish) version(s)
		{
			uuid = [decoder decodeObjectForKey:k_uuid];
			keyJSON = [decoder decodeObjectForKey:k_keyJSON];
			
			isExpired = [decoder decodeBoolForKey:k_isExpired];
			
			lastUpdated = [decoder decodeObjectForKey:k_lastUpdated];
			recycleDate = [decoder decodeObjectForKey:k_recycleDate];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt:1 forKey:k_version];
	
    [coder encodeObject:uuid        forKey:k_uuid];
	[coder encodeObject:keyJSON     forKey:k_keyJSON];
	[coder encodeBool:isExpired     forKey:k_isExpired];
	[coder encodeObject:lastUpdated forKey:k_lastUpdated];
    [coder encodeObject:recycleDate forKey:k_recycleDate];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSCopying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
{
	STSymmetricKey *copy = [[[self class] alloc] init]; // <- To support subclassing
    
    copy->uuid = uuid;
	copy->keyJSON = keyJSON;
	copy->isExpired = isExpired;
    copy->lastUpdated = lastUpdated;
    copy->recycleDate = recycleDate;
	
	return copy;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Convenience Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSDictionary *)keyDict
{
	NSDictionary *keyDict = self.cachedKeyDict;
	if (keyDict == nil)
	{
		NSData *jsonData = [keyJSON dataUsingEncoding:NSUTF8StringEncoding];
		keyDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:NULL];
		
		self.cachedKeyDict = keyDict;
	}
	
	return keyDict;
}

- (NSString *)threadID
{
	NSString *key = [NSString stringWithUTF8String:kSCKeyProp_ThreadID];
	id value = [[self keyDict] objectForKey:key];
	
	if ([value isKindOfClass:[NSString class]])
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
#pragma mark STDatabaseObject Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSMutableSet *)monitoredProperties
{
	NSMutableSet *monitoredProperties = [super monitoredProperties];
	[monitoredProperties removeObject:@"cachedKeyDict"];
	
	return monitoredProperties;
}

@end
