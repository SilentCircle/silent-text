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
#import "STSCloud.h"

#import "AppDelegate.h"
#import "SCloudObject.h"
#import "SCFileManager.h"

@implementation STSCloud
{
    UIImage *cachedThumbNail;
}

@synthesize uuid = uuid;
@synthesize keyString = keyString;
@synthesize userId = userId;
@synthesize isOwnedbyMe = isOwnedbyMe;
@synthesize timestamp = timestamp;
@synthesize mediaType = mediaType;
@synthesize metaData = metaData;
@synthesize segments = segments;
@synthesize dontExpire = dontExpire;
@synthesize lowRezThumbnail = lowRezThumbnail;
@synthesize unCacheDate = unCacheDate;
@synthesize preview = preview;
@synthesize fyeo = fyeo;
@synthesize displayname;

@dynamic thumbnail;
@dynamic thumbnailURL;

+ (NSMutableSet *)monitoredProperties
{
    NSMutableSet *result = [super monitoredProperties];
    [result removeObject:@"thumbnail"];
    
    return result;
}


- (id)initWithUUID:(NSString*)inUUID
         keyString:(NSString*)inKeyString
            userId:(NSString *)inUserId
         mediaType:(NSString *)inMediaType
          metaData:(NSDictionary*)inMetaData
          segments:(NSArray *)inSegments
         timestamp:(NSDate *)inTimestamp
   lowRezThumbnail:(UIImage*)inLowRezThumbnail
       isOwnedbyMe:(BOOL) inIsOwnedbyMe
        dontExpire:(BOOL)inDontExpire
              fyeo:(BOOL)inFYEO
{
	if ((self = [super init]))
	{
        uuid        = inUUID.copy;
        keyString   = inKeyString.copy;
        userId      = inUserId.copy;
        mediaType   = inMediaType.copy;
        metaData    = inMetaData.copy;
        segments    = inSegments.copy;
        lowRezThumbnail = inLowRezThumbnail.copy;
  		timestamp   = inTimestamp;
        isOwnedbyMe = inIsOwnedbyMe;
        dontExpire     = inDontExpire;
        fyeo           = inFYEO;
        cachedThumbNail = NULL;
        preview = NULL;
        
 	}
	return self;
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		int32_t version = [decoder decodeInt32ForKey:@"version"];
		
		if (version == 1)
		{
			uuid      = [decoder decodeObjectForKey:@"uuid"];
            keyString = [decoder decodeObjectForKey:@"keyString"];
			userId    = [decoder decodeObjectForKey:@"userId"];
			
            mediaType       = [decoder decodeObjectForKey:@"mediaType"];
            metaData        = [decoder decodeObjectForKey:@"metaData"];
            segments        = [decoder decodeObjectForKey:@"segments"];
			lowRezThumbnail = [decoder decodeObjectForKey:@"lowRezThumbnail"];
			
			timestamp = [decoder decodeObjectForKey:@"timestamp"];
			
			isOwnedbyMe = [decoder decodeBoolForKey:@"isOwnedbyMe"];
            dontExpire  = [decoder decodeBoolForKey:@"dontExpire"];
			fyeo        = [decoder decodeBoolForKey:@"fyeo"];
			
            displayname = [decoder decodeObjectForKey:@"displayname"];
            unCacheDate = [decoder decodeObjectForKey:@"unCacheDate"];
            preview     = [decoder decodeObjectForKey:@"preview"];
        }
		else
		{
			uuid      = [decoder decodeObjectForKey:@"uuid"];
			keyString = [decoder decodeObjectForKey:@"keyString"];
			userId    = [decoder decodeObjectForKey:@"userId"];
			
			mediaType       = [decoder decodeObjectForKey:@"mediaType"];
			metaData        = [decoder decodeObjectForKey:@"metaData"];
			segments        = [decoder decodeObjectForKey:@"segments"];
			lowRezThumbnail = [decoder decodeObjectForKey:@"lowRezThumbnail"];
			
			timestamp = [decoder decodeObjectForKey:@"timestamp"];
			
			isOwnedbyMe = [decoder decodeBoolForKey:@"isOwnedbyMe"];
            dontExpire  = [decoder decodeBoolForKey:@"dontExpire"];
			fyeo        = [decoder decodeBoolForKey:@"fyeo"];
			
			displayname = [decoder decodeObjectForKey:@"displayname"];
			unCacheDate = [decoder decodeObjectForKey:@"unCacheDate"];
			preview     = [decoder decodeObjectForKey:@"preview"];
 		}
        
        cachedThumbNail = NULL;
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt32:1 forKey:@"version"];
	
	[coder encodeObject:uuid            forKey:@"uuid"];
    [coder encodeObject:keyString       forKey:@"keyString"];
  	[coder encodeObject:userId          forKey:@"userId"];
	
 	[coder encodeObject:mediaType       forKey:@"mediaType"];
 	[coder encodeObject:metaData        forKey:@"metaData"];
 	[coder encodeObject:segments        forKey:@"segments"];
  	[coder encodeObject:lowRezThumbnail forKey:@"lowRezThumbnail"];
	
	[coder encodeObject:timestamp       forKey:@"timestamp"];
	
	[coder encodeBool:isOwnedbyMe       forKey:@"isOwnedbyMe"];
 	[coder encodeBool:dontExpire        forKey:@"dontExpire"];
	[coder encodeBool:fyeo              forKey:@"fyeo"];
 	
 	[coder encodeObject:displayname     forKey:@"displayname"];
    [coder encodeObject:unCacheDate     forKey:@"unCacheDate"];
    [coder encodeObject:preview         forKey:@"preview"];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
	STSCloud *copy = [super copyWithZone:zone];
	
	copy->uuid = uuid;
	copy->keyString = keyString;
 	copy->userId = userId;
	
 	copy->mediaType = mediaType;
	copy->metaData = metaData;
 	copy->segments = segments;
	copy->lowRezThumbnail = lowRezThumbnail;
	
	copy->timestamp = timestamp;
	
	copy->isOwnedbyMe = isOwnedbyMe;
	copy->dontExpire = dontExpire;
    copy->fyeo      = fyeo;
	
	copy->displayname = displayname;
    copy->unCacheDate = unCacheDate;
    copy->preview   = preview;
 	
    copy->cachedThumbNail = cachedThumbNail;
	
	return copy;
}

#pragma mark Convenience Properties

- (NSArray *)missingSegments
{
	NSError *error = nil;
	
	NSMutableArray *needSegs = [[NSMutableArray alloc] init];
	NSURL* baseURL =  [SCFileManager scloudCacheDirectoryURL];
    
    NSURL *url = [baseURL URLByAppendingPathComponent:uuid isDirectory:NO];
    
    BOOL exists = ([url checkResourceIsReachableAndReturnError:&error]
                   && !error
                   && [url isFileURL]);
    
    if(!exists)
        [needSegs addObject:uuid];
    
    for(NSArray * segment in segments)
    {
        NSString* locator = [segment objectAtIndex:1];
        
        url = [baseURL URLByAppendingPathComponent:locator isDirectory:NO];
        
        exists = ([url checkResourceIsReachableAndReturnError:&error]
                  && !error
                  && [url isFileURL]);
        
        if(!exists){
            [needSegs addObject:locator];
        }
    }
    
    return needSegs;
}

- (BOOL)isCached
{
	NSError *error = nil;
    
	NSURL *baseURL = [SCFileManager scloudCacheDirectoryURL];
	NSURL *url = [baseURL URLByAppendingPathComponent:uuid isDirectory:NO];
    
    BOOL exists = ([url checkResourceIsReachableAndReturnError:&error]
                   && !error
                   && [url isFileURL]);
    
    return(exists);
}


#pragma mark Compare

- (NSComparisonResult)compareByTimestamp:(STSCloud *)another
{
	NSDate *aTimestamp = self.timestamp;
	NSDate *bTimestamp = another.timestamp;
	
	NSAssert(aTimestamp && bTimestamp, @"STSCloud has nil timestamp!");
	
	return [aTimestamp compare:bTimestamp];
}

#pragma mark displayName

-(NSString*)displayname
{
    NSString *name = displayname;
    
    if(!name)
        name = [metaData objectForKey:kSCloudMetaData_FileName];
    
    return  name;
}

#pragma mark thumbnail cache

- (NSURL *)thumbnailURL
{
	NSURL *baseURL = [[SCFileManager scloudCacheDirectoryURL] URLByAppendingPathComponent:uuid];
	NSURL *url = [baseURL URLByAppendingPathExtension:@"thm"];
	
	return url;
}


-(UIImage*) thumbnail
{
    if(!cachedThumbNail)
    {
        NSData* blob = [NSData dataWithContentsOfURL: self.thumbnailURL];
        
        if(blob)
        {
            SCLError  err      = kSCLError_NoErr;
            uint8_t * data     = NULL;
            size_t    dataSize = 0;
            
            err = SCKeyStorageDecrypt(STAppDelegate.storageKey,
                                      blob.bytes, blob.length,
                                      &data, &dataSize);
            
            if (IsntSCLError(err) && IsntNull(data) && dataSize)
            {
                NSData *pData = [[NSData alloc] initWithBytesNoCopy:(void *)data
                                                             length:dataSize
                                                       freeWhenDone:YES];
                
                cachedThumbNail = [UIImage imageWithData:pData scale:[[UIScreen mainScreen] scale]];
            }
            
        }
 
    }
    
    return cachedThumbNail;
}

- (void)setThumbnail:(UIImage *)thumbnail
{
    cachedThumbNail = thumbnail;
    
    if(thumbnail)
    {
        NSData* pData = UIImagePNGRepresentation(thumbnail);
        
        if(pData)
        {
            
            SCLError        err     = kSCLError_NoErr;
            uint8_t*        blob    = NULL;
            size_t          blobSize = 0;
            
            err = SCKeyStorageEncrypt(STAppDelegate.storageKey,
                                      pData.bytes, pData.length,
                                      &blob, &blobSize);
            
            if(IsntSCLError(err) && IsntNull(blob))
            {
                NSData* theData = NULL;
                
                theData = [[NSData alloc] initWithBytesNoCopy:(void *)blob
                                                       length:blobSize
                                                 freeWhenDone:YES];
                
                [theData writeToURL:self.thumbnailURL atomically:YES] ;
            }
            
        }
 
    }
}

#pragma mark - scloud cache ops

- (void)removeFromCache
{
	NSError *error = nil;
	
	NSMutableArray *deleteSegs = [[NSMutableArray alloc] init];
	
	NSURL *baseURL = [SCFileManager scloudCacheDirectoryURL];
	
    // check for base segment
    NSURL *url = [baseURL URLByAppendingPathComponent:uuid isDirectory:NO];
    
    BOOL exists = ([url checkResourceIsReachableAndReturnError:&error]
                   && !error
                   && [url isFileURL]);
    
    if(exists)
        [deleteSegs addObject:url.copy];
    
    error = NULL;
 
    // check for thumbnail
    url = [url URLByAppendingPathExtension:@"thm"];
    
    exists = ([url checkResourceIsReachableAndReturnError:&error]
                   && !error
                   && [url isFileURL]);
    
    if(exists)
        [deleteSegs addObject:url.copy];
   
    for(NSArray * segment in segments)
    {
        error = NULL;
        NSString* locator = [segment objectAtIndex:1];
        
        url = [baseURL URLByAppendingPathComponent:locator isDirectory:NO];
        
        exists = ([url checkResourceIsReachableAndReturnError:&error]
                  && !error
                  && [url isFileURL]);
        
        if(exists){
            [deleteSegs addObject:url.copy];
        }
    }
    
    if(deleteSegs.count)
    {
        dispatch_queue_t concurrentQ = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        
        dispatch_async(concurrentQ, ^{
            
            for(NSURL* segUrl in deleteSegs)
                [NSFileManager.defaultManager removeItemAtURL:segUrl error:NULL];
            
        });
	}
}

@end
