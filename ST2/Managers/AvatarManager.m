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
#import <MobileCoreServices/MobileCoreServices.h>
#import <SCCrypto/SCcrypto.h> 

#import "AddressBookManager.h"
#import "AppConstants.h"
#import "AvatarManager.h"
#import "AppDelegate.h"
#import "DatabaseManager.h"
#import "SCimpUtilities.h"
#import "SCWebDownloadManager.h"
#import "STConversation.h"
#import "STImage.h"
#import "STLogging.h"
#import "STUser.h"
#import "YapCache.h"

// Categories
#import "UIImage+Thumbnail.h"


// Log levels: off, error, warn, info, verbose
#if DEBUG && eric_turner
static const int ddLogLevel = LOG_LEVEL_INFO; // | LOG_LEVEL_WARN | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)

static NSString *const kDefaultAvatarIcon = @"silhouette.png";
static NSString *const kDefaultSilentTextInfoUserIcon = @"AppIcon76x76";
static NSString *const kDefaultOCAUserIcon = @"voiceMailIcon76x76";
static NSString *const kDefaultAudioIcon = @"default_audio";
static NSString *const kDefaultvCardIcon = @"vcard";
static NSString *const kDefaultvCalIcon = @"calendar";
static NSString *const kDefaultFolderIcon = @"directory";
static NSString *const kDefaultAndroidFileIcon = @"android";
static NSString *const kDefaultDocumentIcon = @"default-document";
static NSString *const kDefaultMapIcon = @"default-map";
static NSString *const kDefaultMultiAvatarIcon = @"avatar_multi";

@implementation AvatarManager
{
	YapDatabaseConnection *_mustUseSelfDot_databaseConnection;
	
	dispatch_queue_t asyncQueue;
	dispatch_queue_t cacheQueue;
	dispatch_queue_t transformQueue;
	
	void *IsOnAsyncQueueKey;
	void *IsOnCacheQueueKey;
	void *IsOnTransformQueueKey;
	
	YapCache *defaultCache;              // must be accessed from within cacheQueue
	
	YapCache *localAvatarCache;          // must be accessed from within cacheQueue
	YapCache *localAvatarTimestampCache; // must be accessed from within cacheQueue
	
	YapCache *downloadedAvatarCache;     // must be accessed from within cacheQueue
}

static AvatarManager *sharedInstance;

+ (void)initialize
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		sharedInstance = [[AvatarManager alloc] init];
	});
}

+ (instancetype)sharedInstance
{
	return sharedInstance;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Instance
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)init
{
	if ((self = [super init]))
	{
		asyncQueue     = dispatch_queue_create("AvatarManager.asyncQueue", DISPATCH_QUEUE_SERIAL);
		cacheQueue     = dispatch_queue_create("AvatarManager.cacheQueue", DISPATCH_QUEUE_SERIAL);
		transformQueue = dispatch_queue_create("AvatarManager.transformQueue", DISPATCH_QUEUE_SERIAL);
		
		IsOnAsyncQueueKey = &IsOnAsyncQueueKey;
		dispatch_queue_set_specific(asyncQueue, IsOnAsyncQueueKey, IsOnAsyncQueueKey, NULL);
		
		IsOnCacheQueueKey = &IsOnCacheQueueKey;
		dispatch_queue_set_specific(cacheQueue, IsOnCacheQueueKey, IsOnCacheQueueKey, NULL);
		
		IsOnTransformQueueKey = &IsOnTransformQueueKey;
		dispatch_queue_set_specific(transformQueue, IsOnTransformQueueKey, IsOnTransformQueueKey, NULL);
		
		NSUInteger defaultCacheSize = 60;
		NSUInteger localAvatarCacheSize = 80;
		NSUInteger downloadedAvatarCacheSize = 80;
		
		defaultCache = [[YapCache alloc] initWithCountLimit:defaultCacheSize];
		defaultCache.allowedKeyClasses = [NSSet setWithObject:[NSString class]];
		defaultCache.allowedObjectClasses = [NSSet setWithObject:[UIImage class]];
		
		localAvatarCache = [[YapCache alloc] initWithCountLimit:localAvatarCacheSize];
		localAvatarCache.allowedKeyClasses = [NSSet setWithObject:[NSString class]];
		localAvatarCache.allowedObjectClasses = [NSSet setWithObject:[UIImage class]];
		
		localAvatarTimestampCache = [[YapCache alloc] initWithCountLimit:localAvatarCacheSize];
		localAvatarTimestampCache.allowedKeyClasses = [NSSet setWithObject:[NSString class]];
		localAvatarTimestampCache.allowedObjectClasses = [NSSet setWithObject:[NSDate class]];
		
		downloadedAvatarCache = [[YapCache alloc] initWithCountLimit:downloadedAvatarCacheSize];
		downloadedAvatarCache.allowedKeyClasses = [NSSet setWithObject:[NSString class]];
		downloadedAvatarCache.allowedObjectClasses = [NSSet setWithObject:[UIImage class]];
		
		#if TARGET_OS_IPHONE
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(didReceiveMemoryWarning:)
		                                             name:UIApplicationDidReceiveMemoryWarningNotification
		                                           object:nil];
		#endif
	}
	return self;
}

#if TARGET_OS_IPHONE
- (void)didReceiveMemoryWarning:(NSNotification *)notification
{
	dispatch_async(cacheQueue, ^{
		
		[defaultCache removeAllObjects];
		
		[localAvatarCache removeAllObjects];
		[localAvatarTimestampCache removeAllObjects];
	});
}
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Database
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (YapDatabaseConnection *)databaseConnection
{
	if (_mustUseSelfDot_databaseConnection)
		return _mustUseSelfDot_databaseConnection;
	
	YapDatabase *database = STDatabaseManager.database;
	
	if (database == nil)
		return nil;
	
	static dispatch_once_t onceToken; // static? yes -> singleton
	dispatch_once(&onceToken, ^{
		
		_mustUseSelfDot_databaseConnection = [database newConnection];
		
		_mustUseSelfDot_databaseConnection.objectCacheLimit = 45;
		_mustUseSelfDot_databaseConnection.metadataCacheLimit = 45;
		
		[self asyncUpgradeDatabaseIfNeeded];
		
		#if DEBUG
		{
			// This code can be used to test performance of smaller/bigger images on the device
		//	[self asyncForceReDownsample];
		}
		#endif
	});
	
	return _mustUseSelfDot_databaseConnection;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utility Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method converts user avatars that are in the database (as STImage objects),
 * into proper encrypted avatar blobs on the file system.
**/
- (void)asyncUpgradeDatabaseIfNeeded
{
	NSString *const kSCCollection_STImage_User = @"userThumbnails";
	
	YapDatabaseConnection *upgradeConnection = [STDatabaseManager.database newConnection];
	
	dispatch_queue_t upgradeQueue = dispatch_queue_create("AvatarManager-upgrade", DISPATCH_QUEUE_SERIAL);
	dispatch_async(upgradeQueue, ^{ @autoreleasepool{
		
		NSUInteger upgradeCount = 0;
		
		while (YES) // uses break to stop
		{
			__block NSString *userId = nil;
			__block STImage *dbImage = nil;
			
			[upgradeConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
				
				[transaction enumerateKeysInCollection:kSCCollection_STImage_User
											usingBlock:^(NSString *key, BOOL *stop)
				{
					userId = key;
					dbImage = [transaction objectForKey:key inCollection:kSCCollection_STImage_User];
					
					*stop = YES;
				}];
			}];
			
			if (dbImage == nil)
			{
				// Done !
				break;
			}
			
			NSString *fileName = [[NSUUID UUID] UUIDString];
			
			UIImage *image = [self downscaleImage:dbImage.image];
			BOOL success = [self writeImage:image withName:fileName];
		
			[upgradeConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
			
				// remove STImage
				[transaction removeObjectForKey:userId inCollection:kSCCollection_STImage_User];
				
				// update user
				if (success)
				{
					STUser *updatedUser = [transaction objectForKey:userId inCollection:kSCCollection_STUsers];
					updatedUser = [updatedUser copy];
					
					[updatedUser setAvatarFileName:fileName avatarSource:kAvatarSource_SilentContacts];

					[transaction setObject:updatedUser
					                forKey:updatedUser.uuid
					          inCollection:kSCCollection_STUsers];

					DDLogInfo(@"Updating avatar for: %@", updatedUser.displayName);
				}
			}];
			
			upgradeCount++;
			
		} // end while (YES)
		
		if (upgradeCount > 0)
		{
			DDLogInfo(@"Upgraded %lu avatars", (unsigned long)upgradeCount);
		}
	}});
}

#if DEBUG
#if 0
- (void)asyncForceReDownsample
{
	YapDatabaseConnection *upgradeConnection = [STDatabaseManager.database newConnection];
	
	dispatch_queue_t upgradeQueue = dispatch_queue_create("AvatarManager-upgrade", DISPATCH_QUEUE_SERIAL);
	dispatch_async(upgradeQueue, ^{ @autoreleasepool{
		
		NSDate *now = [NSDate date];
		NSUInteger upgradeCount = 0;
		
		while (YES) // uses break to stop
		{
			__block STUser *user = nil;
			
			[upgradeConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
				
				[transaction enumerateKeysAndObjectsInCollection:kSCCollection_STUsers
											          usingBlock:^(NSString *key, STUser *aUser, BOOL *stop)
				{
					if (aUser.avatarFileName && (now == [now laterDate:aUser.avatarLastUpdated]))
					{
						user = aUser;
						*stop = YES;
					}
				}];
			}];
			
			if (user == nil)
			{
				// Done !
				break;
			}
			
			NSLog(@"Downscaling avatar for: %@", user.displayName);
			
			UIImage *oldImage = [self imageWithName:user.avatarFileName error:NULL];
			UIImage *newImage = [self downscaleImage:oldImage];
			
			NSString *newFileName = [[NSUUID UUID] UUIDString];
			
			BOOL success = [self writeImage:newImage withName:newFileName];
		
			[upgradeConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
			
				// update user
				if (success)
				{
					STUser *updatedUser = [transaction objectForKey:user.uuid inCollection:kSCCollection_STUsers];
				
					updatedUser = [updatedUser copy];
					updatedUser.avatarFileName = newFileName;
					updatedUser.lastUpdated = [NSDate date];
					
					[transaction setObject:updatedUser
					                forKey:updatedUser.uuid
					          inCollection:kSCCollection_STUsers];
				}
			}];
			
			upgradeCount++;
			
		} // end while (YES)
		
		if (upgradeCount > 0)
		{
			NSLog(@"Downsampled %lu avatars", (unsigned long)upgradeCount);
		}
	}});
}
#endif
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utility Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Converts parameters into key for defaultCache.
**/

- (NSString *)keyForImageNamed:(NSString *)name withDiameter:(CGFloat)diameter
{
	// Note: Key is for defaultCache
	
	return [NSString stringWithFormat:@"%@, diameter=%.0f", name, diameter];
}

- (NSString *)keyForImageNamed:(NSString *)name scaledToHeight:(CGFloat)height
{
	// Note: Key is for defaultCache
	
	return [NSString stringWithFormat:@"%@, scale=%.0f", name, height];
}

- (NSString *)keyForImageNamed:(NSString *)name scaledToHeight:(CGFloat)height withCornerRadius:(CGFloat)cornerRadius
{
	// Note: Key is for defaultCache
	
	return [NSString stringWithFormat:@"%@ scale=%.0f, cornerRadius=%.0f", name, height, cornerRadius];
}


/**
 * Converts parameters into key for avatarCache & avatarTimestampCache.
**/

- (NSString *)keyPrefixForUserId:(NSString *)userId
{
	return [NSString stringWithFormat:@"st-%@", userId];
}

- (NSString *)keyPrefixForRecordId:(ABRecordID)recordID
{
	return [NSString stringWithFormat:@"ab-%d", recordID];
}

- (NSString *)keyPrefixForUrl:(NSString *)url networkID:(NSString *)networkID
{
	return [NSString stringWithFormat:@"url-%@, networkID=%@", url, networkID];
}

- (NSString *)keyForUserId:(NSString *)userId scaledToHeight:(CGFloat)height withCornerRadius:(CGFloat)cornerRadius
{
	// Note: Key is for localAvatarCache & localAvatarTimestampCache
	
	if (userId == nil)
		return nil;
	
	return [NSString stringWithFormat:@"%@, scale=%.0f, cornerRadius=%.0f",
	         [self keyPrefixForUserId:userId], height, cornerRadius];
}

- (NSString *)keyForRecordId:(ABRecordID)recordID scaledToHeight:(CGFloat)height withCornerRadius:(CGFloat)cornerRadius
{
	// Note: Key is for localAvatarCache & localAvatarTimestampCache
	
	if (recordID == kABRecordInvalidID)
		return nil;
	
	return [NSString stringWithFormat:@"%@, scale=%.0f, cornerRadius=%.0f",
			[self keyPrefixForRecordId:recordID], height, cornerRadius];
}

- (NSString *)keyForUserId:(NSString *)userId withDiameter:(CGFloat)diameter
{
	// Note: Key is for localAvatarCache & localAvatarTimestampCache
	
	if (userId == nil)
		return nil;
	
	return [NSString stringWithFormat:@"%@, diameter=%.0f", [self keyPrefixForUserId:userId], diameter];
}

- (NSString *)keyForRecordId:(ABRecordID)recordID withDiameter:(CGFloat)diameter
{
	// Note: Key is for localAvatarCache & localAvatarTimestampCache
	
	if (recordID == kABRecordInvalidID)
		return nil;
	
	return [NSString stringWithFormat:@"%@, diameter=%.0f", [self keyPrefixForRecordId:recordID], diameter];
}

- (NSString *)keyForUrl:(NSString *)url networkID:(NSString *)networkID withDiameter:(CGFloat)diameter
{
	// Note: Key is for downloadedAvatarCache
	
	if (url == nil)
		return nil;
	
	return [NSString stringWithFormat:@"%@, diameter=%.0f", [self keyPrefixForUrl:url networkID:networkID], diameter];
}

/**
 * Combines theme and usage to get proper ring color for avatar.
**/
- (UIColor *)ringColorForTheme:(AppTheme *)theme usage:(AvatarUsage)usage
{
	switch (usage)
	{
		case kAvatarUsage_Incoming : return theme.otherAvatarBorderColor;
		case kAvatarUsage_Outgoing : return theme.selfAvatarBorderColor;
		case kAvatarUsage_None     : return theme.appTintColor;
		default                    : return [UIColor whiteColor];
	}
}

- (UIImage *)imageWithName:(NSString *)fileName error:(NSError **)errorOut
{
    NSError* error          = nil;
   	NSData *unencryptedData = nil;
	
	uint8_t *blob       = NULL;
	size_t blobSize     = 0;
	SCLError err        = kSCLError_NoErr;

	
    if (fileName == nil) {
		DDLogWarn(@"%@ - Invalid parameter: fileName is nil", THIS_METHOD);
		return nil;
	}
	
 	// Read the encrypted data
	NSString *filePath = [[DatabaseManager blobDirectory] stringByAppendingPathComponent:fileName];
	NSData *encryptedData = [NSData dataWithContentsOfFile:filePath
                                                   options:0
                                                     error:&error];
    
    if (error)
    {
        DDLogWarn(@"%@ - Invalid parameter: encryptedData file error: error %@",
		          THIS_METHOD, error.localizedDescription);
		goto exit;
    }
       
 	if (!encryptedData)
    {
		DDLogWarn(@"%@ - Invalid parameter: encryptedData returns nil: error %@",
		          THIS_METHOD, error.localizedDescription);
		
        error = [STAppDelegate otherError: @"imageWithName encryptedData returns nil"];
        goto exit;
    }
    
  	// Decrypt the data
     err = SCKeyStorageDecrypt(STAppDelegate.storageKey,
	                                   encryptedData.bytes, encryptedData.length,
                               &blob, &blobSize);
    if(IsSCLError(err))
    {
        error = [SCimpUtilities errorWithSCLError:err];
        goto exit;
    }
	
	if (IsntNull(blob))
	{
		unencryptedData = [[NSData alloc] initWithBytesNoCopy:(void *)blob
		                                               length:blobSize
		                                         freeWhenDone:YES];
	}
	
	// Create image from decrypted data
	
	return [UIImage imageWithData:unencryptedData];
    
exit:
    
	if(errorOut) *errorOut = error;
    return nil;
}

- (BOOL)writeImage:(UIImage *)image withName:(NSString *)fileName
{
	if (image == nil) {
		DDLogWarn(@"%@ - Invalid parameter: image is nil", THIS_METHOD);
		return NO;
	}
	if (fileName == nil) {
		DDLogWarn(@"%@ - Invalid parameter: fileName is nil", THIS_METHOD);
		return NO;
	}
	
	BOOL result = NO;
	
	// Convert image to raw data
	NSData *unencryptedData = UIImageJPEGRepresentation(image, 1.0);
	
	// Encrypt the data
	
	NSData *encryptedData = nil;
	
	uint8_t *blob = NULL;
	size_t   blobSize = 0;
	SCLError err = SCKeyStorageEncrypt(STAppDelegate.storageKey,
	                                   unencryptedData.bytes, unencryptedData.length,
	                                   &blob, &blobSize);
	
	if (IsntSCLError(err) && IsntNull(blob))
	{
		encryptedData = [[NSData alloc] initWithBytesNoCopy:(void *)blob
		                                             length:blobSize
		                                       freeWhenDone:YES];
	}
	
	// Write to disk
	
	if (encryptedData)
	{
		NSString *filePath = [[DatabaseManager blobDirectory] stringByAppendingPathComponent:fileName];
		result = [encryptedData writeToFile:filePath atomically:NO];
	}
	
	return result;
}

/**
 * Downscales the image (if needed) to fit a target size.
**/
- (UIImage *)downscaleImage:(UIImage *)image
{
	CGFloat targetImageSize = 320 * [[UIScreen mainScreen] scale];
	
	CGSize imageSize = image.size;
	if (imageSize.width <= targetImageSize && imageSize.height <= targetImageSize)
	{
		return image;
	}
	else
	{
		CGFloat widthScale = targetImageSize / imageSize.width;
		CGFloat heightScale = targetImageSize / imageSize.height;
		
		CGFloat scale = MAX(widthScale, heightScale);
		
		return [image scaled:scale];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Square Images
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)hasImageForUser:(STUser *)user
{
	BOOL hasImage = (user.avatarFileName != nil);
	
	if (!hasImage && user && user.abRecordID != kABRecordInvalidID)
	{
		hasImage = [[AddressBookManager sharedInstance] hasImageForABRecordID:user.abRecordID];
	}
	
	return hasImage;
}

- (UIImage *)imageForUser:(STUser *)user
{
	if (user == nil) return nil;
	
	UIImage *image = nil;
	
	if (user && user.avatarFileName)
	{
		image = [self imageWithName:user.avatarFileName error:NULL];
	}
	
	if (!image && user && user.abRecordID != kABRecordInvalidID)
		image = [[AddressBookManager sharedInstance] imageForABRecordID:user.abRecordID];
	
	return image;
}

- (void)fetchImageForUser:(STUser *)user withCompletionBlock:(void (^)(UIImage*))completionBlock
{
	if (completionBlock == NULL) return;
	
	dispatch_async(asyncQueue, ^{ @autoreleasepool {
		
		UIImage *image = nil;
		
		if (user.avatarFileName)
		{
			image = [self imageWithName:user.avatarFileName error:NULL];
		}
		
		if (!image && user && user.abRecordID != kABRecordInvalidID)
		{
			image = [[AddressBookManager sharedInstance] imageForABRecordID:user.abRecordID];
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			completionBlock(image);
		});
	}});
}

/**
 * This method writes the image as an encrypted blob to the file-system (in the blobDirectory),
 * and then updates the corresponding STUser object.
 *
 * @param image
 *   The image to encrypt, and then write to the file system.
 *   This method doesn not perform any image manipulation.
 *   So if you want to do something like down-sampling the image,
 *   then you need to perform that work before passing it to this method.
 *
 * @param userID
 *   Corresponds to the STUser.uuid associated with the image.
 *   After the image has been saved to disk, this method updates the STUser.avatarFileName method to match.
 *   The STUser.avatarFileName will be a newly generated UUID.
 *
 * @param completionBlock (optional)
 *   The completionBlock to be invoked (on the main thread) after the read-write database transaction has completed.
**/
- (void)asyncSetImage:(UIImage *)fullImage
         avatarSource:(AvatarSource)avatarSource
            forUserID:(NSString *)userID
      completionBlock:(dispatch_block_t)completionBlock
{
	if (!fullImage || !userID)
	{
		DDLogWarn(@"%@ - Invalid parameter: nil image or userID", THIS_METHOD);
		return;
	}
	
	// Important: This method may be called BEFORE the readWriteTransaction has saved a new user to the database.
	// There used to be code here that ran a "sanity check" to ensure the user existed before it proceeded.
	// This sanity check broke the case of saving a new user with an image.
	// https://tickets.silentcircle.org/browse/ST-769
	
    dispatch_queue_t bgQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	dispatch_async(bgQueue, ^{
        
        NSString *fileName = [[NSUUID UUID] UUIDString];
        
        UIImage *image = [self downscaleImage:fullImage];
        BOOL success = [self writeImage:image withName:fileName];
        
        if (!success)
        {
            if (completionBlock)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionBlock();
                });
            }
            return;
        }
        
        __block BOOL didChangeImage = NO;
        
        YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
        [rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            
            STUser *user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
			
			if (!user || user.avatarSource > avatarSource)
			{
                didChangeImage = NO;
			}
			else
			{
				STUser *updatedUser = [user copy];
				[updatedUser setAvatarFileName:fileName avatarSource:avatarSource];
				
				[transaction setObject:updatedUser
				                forKey:updatedUser.uuid
				          inCollection:kSCCollection_STUsers];
				
				didChangeImage = YES;
			}
			
        }
		completionQueue:bgQueue
		completionBlock:^{
            
			// flush the cache of images that match this uuid
			if (didChangeImage)
			{
				// STUser keys start with a certain prefix
                
				NSString *keyPrefix = [self keyPrefixForUserId:userID];
				dispatch_sync(cacheQueue, ^{
					
					NSMutableArray *keysToRemove = [NSMutableArray array];
					
					[localAvatarCache enumerateKeysWithBlock:^(id key, BOOL *stop) {
						
						if ([key hasPrefix:keyPrefix]) {
							[keysToRemove addObject:key];
						}
					}];
                    
					[localAvatarCache removeObjectsForKeys:keysToRemove];
					[localAvatarTimestampCache removeObjectsForKeys:keysToRemove];
				});
			}
			
			if (completionBlock)
			{
				dispatch_async(dispatch_get_main_queue(), ^{
					completionBlock();
				});
			}
			
			if (!didChangeImage)
			{
				// Something unexpected happened to our user while we were trying to set its avatar.
				// So we need to delete the image from the filesystem.
				
				NSString *filePath = [[DatabaseManager blobDirectory] stringByAppendingPathComponent:fileName];
				[[NSFileManager defaultManager] removeItemAtPath:filePath error:NULL];
			}
		
		}]; // end asyncReadWriteWithBlock:completionQueue:completionBlock:
		
    });
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Default Avatars
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Fetches the default (from its specific cache), creating it on-the-fly if needed.
**/
- (UIImage *)defaultImageNamed:(NSString *)name withDiameter:(CGFloat)diameter
{
	NSString *key = [self keyForImageNamed:name withDiameter:diameter];
    
	__block UIImage *avatar = nil;
	dispatch_sync(cacheQueue, ^{ @autoreleasepool {
		
        avatar = [defaultCache objectForKey:key];
	}});
	
	if (avatar == nil)
	{
		UIImage *image = [UIImage imageNamed:name];
		avatar = [image scaledAvatarImageWithDiameter:diameter];
		
		dispatch_async(cacheQueue, ^{ @autoreleasepool {
			
			[defaultCache setObject:avatar forKey:key];
		}});
	}
	
	return avatar;
}

/**
 * Fetches the default (from its specific cache), creating it on-the-fly if needed.
**/
- (UIImage *)defaultImageNamed:(NSString *)name scaledToHeight:(CGFloat)height
{
	NSString *key = [self keyForImageNamed:name scaledToHeight:height];
	
	__block UIImage *avatar = nil;
	dispatch_sync(cacheQueue, ^{ @autoreleasepool {
		
        avatar = [defaultCache objectForKey:key];
	}});
	
	if (avatar == nil)
	{
		UIImage *image = [UIImage imageNamed:name];
		avatar = [image scaledToHeight:height];
		
		dispatch_async(cacheQueue, ^{ @autoreleasepool {
			
			[defaultCache setObject:avatar forKey:key];
		}});
	}
	
	return avatar;
}

/**
 * Fetches the default (from its specific cache), creating it on-the-fly if needed.
**/
- (UIImage *)defaultImageNamed:(NSString *)name scaledToHeight:(CGFloat)height withCornerRadius:(CGFloat)cornerRadius
{
	NSString *key = [self keyForImageNamed:name scaledToHeight:height withCornerRadius:cornerRadius];
	
	__block UIImage *avatar = nil;
	dispatch_sync(cacheQueue, ^{ @autoreleasepool {
		
		avatar = [defaultCache objectForKey:key];
	}});
	
	if (avatar == nil)
	{
		UIImage *image = [UIImage imageNamed:name];
		avatar = [[image scaledToHeight:height] roundedImageWithCornerRadius:cornerRadius];
		
		dispatch_async(cacheQueue, ^{ @autoreleasepool {
			
			[defaultCache setObject:avatar forKey:key];
		}});
	}
	
	return avatar;
}

- (UIImage *)defaultAvatarWithDiameter:(CGFloat)diameter
{
	UIImage *avatar = [self defaultImageNamed:kDefaultAvatarIcon withDiameter:diameter];
	return avatar;
}

- (UIImage *)defaultAvatarScaledToHeight:(CGFloat)height withCornerRadius:(CGFloat)cornerRadius
{
	UIImage *avatar = [self defaultImageNamed:kDefaultAvatarIcon scaledToHeight:height withCornerRadius:cornerRadius];
	return avatar;
}

- (UIImage *)defaultMultiAvatarImageWithDiameter:(CGFloat)diameter
{
	UIImage *avatar = [self defaultImageNamed:kDefaultMultiAvatarIcon withDiameter:diameter];
	return avatar;
}

- (UIImage *)defaultOCAUserAvatarWithDiameter:(CGFloat)diameter;
{
	UIImage *avatar = [self defaultImageNamed:kDefaultOCAUserIcon withDiameter:diameter];
	return avatar;
}

- (UIImage *)defaultSilentTextInfoUserAvatarWithDiameter:(CGFloat)diameter;
{
	UIImage *avatar = [self defaultImageNamed:kDefaultSilentTextInfoUserIcon withDiameter:diameter];
	return avatar;
}

- (UIImage *)defaultMapImageScaledToHeight:(CGFloat)height
{
	UIImage *image = [self defaultImageNamed:kDefaultMapIcon scaledToHeight:height];
	return image;
}

- (UIImage *)defaultAudioImageScaledToHeight:(CGFloat)height
{
	UIImage *image = [self defaultImageNamed:kDefaultAudioIcon scaledToHeight:height];
	return image;
}

- (UIImage *)defaultVCardImageScaledToHeight:(CGFloat)height
{
	UIImage *image = [self defaultImageNamed:kDefaultvCardIcon scaledToHeight:height];
	return image;
}

- (UIImage *)defaultVCalendarImageScaledToHeight:(CGFloat)height
{
	UIImage *image = [self defaultImageNamed:kDefaultvCalIcon scaledToHeight:height];
	return image;
}

- (UIImage *)defaultFolderImageScaledToHeight:(CGFloat)height
{
	UIImage *image = [self defaultImageNamed:kDefaultFolderIcon scaledToHeight:height];
	return image;
}

- (UIImage *)defaultAndroidFileImageScaledToHeight:(CGFloat)height
{
	UIImage *image = [self defaultImageNamed:kDefaultAndroidFileIcon scaledToHeight:height];
	return image;
}

- (UIImage *)defaultDocumentFileImageScaledToHeight:(CGFloat)height
{
	UIImage *image = [self defaultImageNamed:kDefaultDocumentIcon scaledToHeight:height];
	return image;
}

- (UIImage *)defaultImageForMediaType:(NSString *)mediaType scaledToHeight:(CGFloat)height;
{
	
	// Apple doesnt show a good icon for RTFD, and yet they use it all the time.. sigh
	// So we do a substitution for it.
	if ([mediaType isEqualToString:(__bridge NSString *)kUTTypeRTFD])
	{
		mediaType = (__bridge NSString*)kUTTypeRTF;
	}
	
	NSString *key = [self keyForImageNamed:mediaType scaledToHeight:height];
	
	__block UIImage *avatar = nil;
	dispatch_sync(cacheQueue, ^{
		avatar = [defaultCache objectForKey:key];
	});
	
	if (avatar == nil)
	{
		UIImage *image = [UIImage defaultImageForMediaType:mediaType];
		avatar = [image scaledToHeight:height];
		
		dispatch_async(cacheQueue, ^{
			[defaultCache setObject:avatar forKey:key];
		});
	}
	
	return avatar;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark ScaledWithCornerRadius Avatar for User
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns whatever is in the cache, even if the item is slightly outdated.
 *
 * @param useDefaultIfUncached
 *   If YES, and there is nothing cached, then return a proper default image.
 *   If NO, then returns nil if nothing is cached.
 *
 * IMPORTANT :
 * The returned image is not guaranteed to be correct.
 * That is, it may be slightly outdated if user's image was recently changed.
 * You must still use the async (fetch) version below, even if this method returns a result.
**/
- (UIImage *)cachedAvatarForUser:(STUser *)inUser
                  scaledToHeight:(CGFloat)height
                withCornerRadius:(CGFloat)cornerRadius
                 defaultFallback:(BOOL)useDefaultIfUncached
{
	NSString *key = [self keyForUserId:inUser.uuid scaledToHeight:height withCornerRadius:cornerRadius];
	
	__block UIImage *avatar = nil;
	dispatch_sync(cacheQueue, ^{ @autoreleasepool {
		
		avatar = [localAvatarCache objectForKey:key];
	}});
    
	if (avatar == nil && useDefaultIfUncached)
	{
		avatar = [self defaultAvatarScaledToHeight:height withCornerRadius:cornerRadius];
	}
	
	return avatar;
	
}

/**
 * Async fetch routine.
 * This method should always be used, even if the cachedAvatar method returns a result.
**/
- (void)fetchAvatarForUser:(STUser *)inUser
            scaledToHeight:(CGFloat)height
          withCornerRadius:(CGFloat)cornerRadius
           completionBlock:(void (^)(UIImage*))completionBlock
{
	if (completionBlock == NULL) return;
	
	NSString *userID = inUser.uuid;
	NSString *userAvatarFileName = inUser.avatarFileName;
	NSDate   *userAvatarLastUpdated = inUser.avatarLastUpdated;
	ABRecordID userABRecordID = inUser ? inUser.abRecordID : kABRecordInvalidID;
	
	dispatch_block_t block = ^{ @autoreleasepool { // executed on asyncQueue
		
		__block NSString *key = nil;
		
		__block UIImage *avatar = nil;
		__block NSDate *avatarTimestamp = nil;
		
		__block UIImage *image = nil;
		__block NSDate *imageTimestamp = nil;
		
		if (userAvatarFileName)
		{
			key = [self keyForUserId:userID scaledToHeight:height withCornerRadius:cornerRadius];
			
			// Check the avatarCache to see if we have a pre-processed image available
			dispatch_sync(cacheQueue, ^{ @autoreleasepool {
				
				avatar          = [localAvatarCache objectForKey:key];
				avatarTimestamp = [localAvatarTimestampCache objectForKey:key];
			}});
			
			// If we have a pre-processed image, is it still valid?
			if (avatar && avatarTimestamp)
			{
				// Note that we are fetching the metadata for the object.
				// This is much less disk io than fetching an entire STImage.
				
				imageTimestamp = userAvatarLastUpdated;
				if (![imageTimestamp isEqualToDate:avatarTimestamp])
				{
					// Cached image is invalid.
					avatar = nil;
				}
			}
			
			NSError *error = nil;
			if (avatar == nil)
			{
				imageTimestamp = userAvatarLastUpdated;
				image = [self imageWithName:userAvatarFileName error:&error];
			}
            
            if (error)
            {
				DDLogWarn(@"%@ - image for userID %@ nil", THIS_METHOD, userID);
				
				// The avatarFileName for this user is broken,
				// so we should set it to nil and stop asking for it.
                
				YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
				[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
					
					STUser *updatedUser = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
					updatedUser = [updatedUser copy];
					
					[updatedUser setAvatarFileName:nil avatarSource:kAvatarSource_None];
					
					[transaction setObject:updatedUser
					                forKey:updatedUser.uuid
					          inCollection:kSCCollection_STUsers];
				}];
			}
			
		}
		else if (userABRecordID != kABRecordInvalidID)
		{
			key = [self keyForRecordId:userABRecordID scaledToHeight:height withCornerRadius:cornerRadius];

			// Check the avatarCache to see if we have a pre-processed image available
			dispatch_sync(cacheQueue, ^{ @autoreleasepool {
				
				avatar          = [localAvatarCache objectForKey:key];
				avatarTimestamp = [localAvatarTimestampCache objectForKey:key];
			}});
			
			if (avatar && avatarTimestamp)
			{
				// Verify that the image the avatar is from is still valid (using timestamps).
				
				imageTimestamp = [[AddressBookManager sharedInstance] lastUpdate];
				if (![imageTimestamp isEqualToDate:avatarTimestamp])
				{
					avatar = nil;
				}
			}
			
			if (avatar == nil)
			{
				imageTimestamp = [[AddressBookManager sharedInstance] lastUpdate];
				image = [[AddressBookManager sharedInstance] imageForABRecordID:userABRecordID];
			}
		}
		
		dispatch_async(transformQueue, ^{ @autoreleasepool {
			
			if (image)
			{
				// transform image into avatar
				avatar = [[image scaledToHeight:height] roundedImageWithCornerRadius:cornerRadius];
				
				// store in cache (async)
				if (avatar)
				{
					UIImage *avatarToCache = avatar; // because avatar is modified ahead
					dispatch_async(cacheQueue, ^{ @autoreleasepool {
						
						[localAvatarCache setObject:avatarToCache forKey:key];
						
						if (imageTimestamp)
							[localAvatarTimestampCache setObject:imageTimestamp forKey:key];
						else
							[localAvatarTimestampCache removeObjectForKey:key];
					}});
				}
			}
			
			if (avatar == nil)
				avatar = [self defaultAvatarScaledToHeight:height withCornerRadius:cornerRadius];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				
				if (completionBlock) {
					completionBlock(avatar);
				}
			});
		}});
		
	}};
	
	if (dispatch_get_specific(IsOnAsyncQueueKey))
		block();
	else
		dispatch_async(asyncQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Rounded Avatar for User
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns whatever is in the cache, even if the item is slightly outdated.
 *
 * @param useDefaultIfUncached
 *   If YES, and there is nothing cached, then return a proper default image.
 *   If NO, then returns nil if nothing is cached.
 *
 * IMPORTANT :
 * The returned image is not guaranteed to be correct.
 * That is, it may be slightly outdated if user's image was recently changed.
 * You must still use the async (fetch) version below, even if this method returns a result.
**/
- (UIImage *)cachedAvatarForUser:(STUser *)inUser
                    withDiameter:(CGFloat)diameter
                           theme:(AppTheme *)theme
                           usage:(AvatarUsage)usage
                 defaultFallback:(BOOL)useDefaultIfUncached
{
	NSString * userAvatarFileName = inUser.avatarFileName;
	ABRecordID userABRecordID = inUser ? inUser.abRecordID : kABRecordInvalidID;
	
	NSString *key = nil;
	if (userAvatarFileName)
	{
		key = [self keyForUserId:inUser.uuid withDiameter:diameter];
	}
	else if (userABRecordID != kABRecordInvalidID)
	{
		key = [self keyForRecordId:userABRecordID withDiameter:diameter];
	}
	
	__block UIImage *avatar = nil;
	if (key)
	{
		dispatch_sync(cacheQueue, ^{ @autoreleasepool {
			
			avatar = [localAvatarCache objectForKey:key];
		}});
	}
	
	if (avatar == nil && useDefaultIfUncached)
		avatar = [self defaultAvatarWithDiameter:diameter];
	
	if (avatar)
	{
		UIColor *ringColor = [self ringColorForTheme:theme usage:usage];
		avatar = [avatar avatarImageWithDiameter:diameter usingColor:ringColor];
	}
	
	return avatar;
}

/**
 * Async fetch routine.
 * This method should always be used, even if the cachedAvatar method returns a result.
 * 
 * The plan is for this method to replace fetchAvatarForUserID:...
**/
- (void)fetchAvatarForUser:(STUser *)inUser
              withDiameter:(CGFloat)diameter
                     theme:(AppTheme *)theme
                     usage:(AvatarUsage)usage
           completionBlock:(void (^)(UIImage*))completionBlock
{
	if (completionBlock == NULL) return;
	
	UIColor *ringColor = [self ringColorForTheme:theme usage:usage];
	
	NSString * userID = inUser.uuid;
	NSString * userAvatarFileName = inUser.avatarFileName;
	NSDate   * userAvatarLastUpdated = inUser.avatarLastUpdated;
	ABRecordID userABRecordID = inUser ? inUser.abRecordID : kABRecordInvalidID;
	
	dispatch_block_t block = ^{ @autoreleasepool { // executed on asyncQueue
		
		__block NSString *key = nil;
		
		__block UIImage *avatar = nil;
		__block NSDate *avatarTimestamp = nil;
		
		__block UIImage *image = nil;
		__block NSDate *imageTimestamp = nil;
		
		if (userAvatarFileName)
		{
            key = [self keyForUserId:userID withDiameter:diameter];
			
			// Check the avatarCache to see if we have a pre-processed image available
			dispatch_sync(cacheQueue, ^{ @autoreleasepool {
				
				avatar          = [localAvatarCache objectForKey:key];
				avatarTimestamp = [localAvatarTimestampCache objectForKey:key];
			}});
			
			// If we have a pre-processed image, is it still valid?
			if (avatar && avatarTimestamp)
			{
				// Note that we are fetching the metadata for the object.
				// This is much less disk io than fetching an entire STImage.
				
				imageTimestamp = userAvatarLastUpdated;
				if (![imageTimestamp isEqualToDate:avatarTimestamp])
				{
					// Cached image is invalid.
					avatar = nil;
				}
			}
			
			NSError *error = nil;
			if (avatar == nil)
			{
				imageTimestamp = userAvatarLastUpdated;
				image = [self imageWithName:userAvatarFileName error:&error];
			}
            
            if (error)
            {
				DDLogWarn(@"%@ - image for userID %@ nil", THIS_METHOD, userID);
				
				// The avatarFileName for this user is broken,
				// so we should set it to nil and stop asking for it.
                
				YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
				[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
					
					STUser *updatedUser = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
					updatedUser = [updatedUser copy];
					
					[updatedUser setAvatarFileName:nil avatarSource:kAvatarSource_None];
					
					[transaction setObject:updatedUser
					                forKey:updatedUser.uuid
					          inCollection:kSCCollection_STUsers];
				}];
			}
			
		}
		else if (userABRecordID != kABRecordInvalidID)
		{
			key = [self keyForRecordId:userABRecordID withDiameter:diameter];

			// Check the avatarCache to see if we have a pre-processed image available
			dispatch_sync(cacheQueue, ^{ @autoreleasepool {
				
				avatar          = [localAvatarCache objectForKey:key];
				avatarTimestamp = [localAvatarTimestampCache objectForKey:key];
			}});
			
			if (avatar && avatarTimestamp)
			{
				// Verify that the image the avatar is from is still valid (using timestamps).
				
				imageTimestamp = [[AddressBookManager sharedInstance] lastUpdate];
				if (![imageTimestamp isEqualToDate:avatarTimestamp])
				{
					avatar = nil;
				}
			}
			
			if (avatar == nil)
			{
				imageTimestamp = [[AddressBookManager sharedInstance] lastUpdate];
				image = [[AddressBookManager sharedInstance] imageForABRecordID:userABRecordID];
			}
		}
		
		dispatch_async(transformQueue, ^{ @autoreleasepool {
			
			if (image)
			{
				// transform image into avatar
				avatar = [image scaledAvatarImageWithDiameter:diameter];
				
				// store in cache (async)
				if (avatar)
				{
					UIImage *avatarToCache = avatar; // because avatar is modified ahead
					dispatch_async(cacheQueue, ^{ @autoreleasepool {
						
						[localAvatarCache setObject:avatarToCache forKey:key];
						
						if (imageTimestamp)
							[localAvatarTimestampCache setObject:imageTimestamp forKey:key];
						else
							[localAvatarTimestampCache removeObjectForKey:key];
					}});
				}
			}
			
			if (avatar == nil)
				avatar = [self defaultAvatarWithDiameter:diameter];
			
			avatar = [avatar avatarImageWithDiameter:diameter usingColor:ringColor];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				
				if (completionBlock) {
					completionBlock(avatar);
				}
			});
		}});
		
	}};
	
	if (dispatch_get_specific(IsOnAsyncQueueKey))
		block();
	else
		dispatch_async(asyncQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Rounded Avatar for UserID
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns whatever is in the cache, even if the item is slightly outdated.
 *
 * @param useDefaultIfUncached
 *   If YES, and there is nothing cached, then return a proper default image.
 *   If NO, then returns nil if nothing is cached.
 *
 * IMPORTANT :
 * The returned image is not guaranteed to be correct.
 * That is, it may be slightly outdated if user's image was recently changed.
 * You must still use the async (fetch) version below, even if this method returns a result.
**/
- (UIImage *)cachedAvatarForUserId:(NSString *)userId
                      withDiameter:(CGFloat)diameter
                             theme:(AppTheme *)theme
                             usage:(AvatarUsage)usage
                   defaultFallback:(BOOL)useDefaultIfUncached
{
	NSString *key = [self keyForUserId:userId withDiameter:diameter];
	
	__block UIImage *avatar = nil;
	dispatch_sync(cacheQueue, ^{ @autoreleasepool {
		
		avatar = [localAvatarCache objectForKey:key];
	}});
    
	if (avatar == nil && useDefaultIfUncached)
		avatar = [self defaultAvatarWithDiameter:diameter];
	
	if (avatar)
	{
		UIColor *ringColor = [self ringColorForTheme:theme usage:usage];
		avatar = [avatar avatarImageWithDiameter:diameter usingColor:ringColor];
	}
	
	return avatar;
}

/**
 * Async fetch routine.
 * This method should always be used, even if the cachedAvatar method returns a result.
**/
- (void)fetchAvatarForUserId:(NSString *)inUserId
                withDiameter:(CGFloat)diameter
                       theme:(AppTheme *)theme
                       usage:(AvatarUsage)usage
            completionBlock:(void (^)(UIImage*))completionBlock
{
	if (completionBlock == NULL) return;
	
	NSString *userId = [inUserId copy]; // mutable string protection (if immutable, copy == retain)
	
	__block STUser *user = nil;
	[self.databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		user = [transaction objectForKey:userId inCollection:kSCCollection_STUsers];
	}
	completionQueue:asyncQueue
	completionBlock:^{
		
		[self fetchAvatarForUser:user withDiameter:diameter theme:theme usage:usage completionBlock:completionBlock];
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Rounded Avatar for ABRecordID
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns whatever is in the cache, even if the item is slightly outdated.
 * 
 * @param useDefaultIfUncached
 *   If YES, and there is nothing cached, then return a proper default image.
 *   If NO, then returns nil if nothing is cached.
 *
 * IMPORTANT :
 * The returned image is not guaranteed to be correct.
 * That is, it may be slightly outdated if user's image was recently changed.
 * You must still use the async (fetch) version below, even if this method returns a result.
**/
- (UIImage *)cachedAvatarForABRecordID:(ABRecordID)abRecordID
                          withDiameter:(CGFloat)diameter
                                 theme:(AppTheme *)theme
                                 usage:(AvatarUsage)usage
                       defaultFallback:(BOOL)useDefaultIfUncached
{
	__block UIImage *avatar = nil;
	if (abRecordID != kABRecordInvalidID)
	{
		NSString *key = [self keyForRecordId:abRecordID withDiameter:diameter];
		dispatch_sync(cacheQueue, ^{ @autoreleasepool {
	 
			avatar = [localAvatarCache objectForKey:key];
		}});
	}
	
	if (avatar == nil && useDefaultIfUncached)
		avatar = [self defaultAvatarWithDiameter:diameter];
	
	if (avatar)
	{
		UIColor *ringColor = [self ringColorForTheme:theme usage:usage];
		avatar = [avatar avatarImageWithDiameter:diameter usingColor:ringColor];
	}
	
	return avatar;
}

/**
 * Async fetch routine.
 * This method should always be used, even if the cachedAvatar method returns a result.
**/
- (void)fetchAvatarForABRecordID:(ABRecordID)abRecordID
                    withDiameter:(CGFloat)diameter
                           theme:(AppTheme *)theme
                           usage:(AvatarUsage)usage
                 completionBlock:(void (^)(UIImage*))completionBlock
{
	if (completionBlock == NULL) return;
	
	UIColor *ringColor = [self ringColorForTheme:theme usage:usage];

	if (abRecordID == kABRecordInvalidID)
	{
		dispatch_async(transformQueue, ^{ @autoreleasepool {
			
			UIImage *avatar = [self defaultAvatarWithDiameter:diameter];
			avatar = [avatar avatarImageWithDiameter:diameter usingColor:ringColor];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				completionBlock(avatar);
			});
		}});
		
		return;
	}
  	
	dispatch_async(asyncQueue, ^{ @autoreleasepool {
		
        NSString *key = [self keyForRecordId:abRecordID withDiameter:diameter];
		
		__block UIImage *avatar = nil;
		__block NSDate *avatarTimestamp = nil;
		
		dispatch_sync(cacheQueue, ^{
			
			avatar          = [localAvatarCache objectForKey:key];
			avatarTimestamp = [localAvatarTimestampCache objectForKey:key];
		});
		
		UIImage *image = nil;
		NSDate *imageTimestamp = nil;
		
		if (avatar)
		{
			// Verify that the image the avatar is from is still valid (using timestamps).
			
			NSDate *imageTimestamp = [[AddressBookManager sharedInstance] lastUpdate];
			if (![imageTimestamp isEqualToDate:avatarTimestamp])
			{
				avatar = nil;
			}
		}
		
		if (avatar == nil)
		{
			imageTimestamp = [[AddressBookManager sharedInstance] lastUpdate];
			image = [[AddressBookManager sharedInstance] imageForABRecordID:abRecordID];
		}
		
		dispatch_async(transformQueue, ^{ @autoreleasepool {
			
			if (image)
			{
				// transform image into avatar
				avatar = [image scaledAvatarImageWithDiameter:diameter];
  				
				// store in cache (async)
				if (avatar)
				{
					UIImage *avatarToCache = avatar; // because avatar is modified ahead
					dispatch_async(cacheQueue, ^{
						
						[localAvatarCache setObject:avatarToCache forKey:key];
						
						if (imageTimestamp)
							[localAvatarTimestampCache setObject:imageTimestamp forKey:key];
						else
							[localAvatarTimestampCache removeObjectForKey:key];
					});
				}
			}
			
			if (avatar == nil)
				avatar = [self defaultAvatarWithDiameter:diameter];
			
			avatar = [avatar avatarImageWithDiameter:diameter usingColor:ringColor];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				completionBlock(avatar);
			});
		}});
	}});
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Rounded Avatar for URL
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the item if in the cache.
 *
 * @param useDefaultIfUncached
 *   If YES, and there is nothing cached, then return a proper default image.
 *   If NO, then returns nil if nothing is cached.
 *
 * NOTE : The avatar represented by an avatarURL shouldn't change.
 *        Thus this API differs from others in that, if there's a cached version,
 *        then there's no need to do an async fetch for an "up-to-date" version.
 *        Doing so would just cause unnecessary overhead.
**/
- (UIImage *)cachedAvatarForURL:(NSString *)avatarUrl
                      networkID:(NSString *)networkID
                   withDiameter:(CGFloat)diameter
                          theme:(AppTheme *)theme
                          usage:(AvatarUsage)usage
                defaultFallback:(BOOL)useDefaultIfUncached
{
	__block UIImage *avatar = nil;
	if (avatarUrl && networkID)
	{
		NSString *key = [self keyForUrl:avatarUrl networkID:networkID withDiameter:diameter];
		dispatch_sync(cacheQueue, ^{ @autoreleasepool {
			
			avatar = [downloadedAvatarCache objectForKey:key];
		}});
	}
	
	if (avatar == nil && useDefaultIfUncached)
		avatar = [self defaultAvatarWithDiameter:diameter];
	
	if (avatar)
	{
		UIColor *ringColor = [self ringColorForTheme:theme usage:usage];
		avatar = [avatar avatarImageWithDiameter:diameter usingColor:ringColor];
	}
	
	return avatar;
}

/**
 * Only use this method if the avatar isn't already cached.
**/
- (void)downloadAvatarForURL:(NSString *)avatarUrl
                   networkID:(NSString *)networkID
                withDiameter:(CGFloat)diameter
                       theme:(AppTheme *)theme
                       usage:(AvatarUsage)usage
             completionBlock:(void (^)(UIImage*))completionBlock
{
	NSString *key = [self keyForUrl:avatarUrl networkID:networkID withDiameter:diameter];
	
	UIColor *ringColor = [self ringColorForTheme:theme usage:usage];
	
	[[SCWebDownloadManager sharedInstance] downloadAvatar:avatarUrl
	                                        withNetworkID:networkID
	                                      completionBlock:^(NSError *error, UIImage *image)
	{
		dispatch_async(transformQueue, ^{ @autoreleasepool {
			
			UIImage *avatar = nil;
			
			if (image)
			{
				// transform image into avatar
				avatar = [image scaledAvatarImageWithDiameter:diameter];
				
				// store in cache (async)
				if (avatar)
				{
					UIImage *avatarToCache = avatar; // because avatar is modified ahead
					dispatch_async(cacheQueue, ^{
						
						[downloadedAvatarCache setObject:avatarToCache forKey:key];
					});
				}
			}
			
			if (avatar == nil)
				avatar = [self defaultAvatarWithDiameter:diameter];
			
			avatar = [avatar avatarImageWithDiameter:diameter usingColor:ringColor];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				completionBlock(avatar);
			});
		}});
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Multi Avatar
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/** 08/15/14 DEPRECATED - refactored with RH into fetchMultiAvatarForUsers:withDiameter:theme:usage:completionBlock:
 * below.
 *
 * orig:
 * Use this method to aynchronously fetch a multi avatar.
 *
 * The front parameter can be either a userId (NSString) or an abRecordID (NSNumber).
 * The back parameter can be either a userId (NSString) or an abRecordID (NSNumber).
**/
- (void)fetchMultiAvatarForFront:(id)front // if NSString -> userId; if NSNumber -> abRecordID
                            back:(id)back  // if NSString -> userId; if NSNumber -> abRecordID
                    withDiameter:(CGFloat)diameter
                           theme:(AppTheme *)theme
                           usage:(AvatarUsage)usage
                 completionBlock:(void (^)(UIImage*))completionBlock
{
	if (completionBlock == NULL) return;
	
	NSString *frontUserId = nil;
	NSNumber *frontABRecordID = nil;
	
	if ([front isKindOfClass:[NSString class]]) {
		frontUserId = (NSString *)front;
	}
	else if ([front isKindOfClass:[NSNumber class]]) {
		frontABRecordID = (NSNumber *)front;
	}
	
	NSString *backUserId = nil;
	NSNumber *backABRecordID = nil;
	
	if ([back isKindOfClass:[NSString class]]) {
		backUserId = (NSString *)back;
	}
	else if ([back isKindOfClass:[NSNumber class]]) {
		backABRecordID = (NSNumber *)back;
	}
	
	BOOL hasFront = frontUserId || frontABRecordID;
	BOOL hasBack = backUserId || backABRecordID;
	
	if (!hasFront && !hasBack)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			completionBlock(nil);
		});
		
		return;
	}
	
	__block UIImage *frontImage = nil;
	__block UIImage *backImage = nil;
	
	__block STUser *frontUser = nil;
	__block STUser *backUser = nil;
	
	dispatch_block_t asyncBlock = ^{ @autoreleasepool {
		
		if (frontUser && frontUser.avatarFileName)
		{
			frontImage = [self imageWithName:frontUser.avatarFileName error:NULL];
		}
		else if (frontUser && frontUser.abRecordID != kABRecordInvalidID)
		{
			frontImage = [[AddressBookManager sharedInstance] imageForABRecordID:frontUser.abRecordID];
		}
		else if (frontABRecordID)
		{
			frontImage = [[AddressBookManager sharedInstance] imageForABRecordID:[frontABRecordID intValue]];
		}
		
		if (backUser && backUser.avatarFileName)
		{
			backImage = [self imageWithName:backUser.avatarFileName error:NULL];
		}
		else if (backUser && backUser.abRecordID != kABRecordInvalidID)
		{
			backImage = [[AddressBookManager sharedInstance] imageForABRecordID:backUser.abRecordID];
		}
		else if (backABRecordID)
		{
			backImage = [[AddressBookManager sharedInstance] imageForABRecordID:[backABRecordID intValue]];
		}
		
		if (frontImage || backImage)
		{
			if (frontImage == nil)
			{
				frontImage = [UIImage imageNamed:kDefaultAvatarIcon];
			}
			if (backImage == nil)
			{
				backImage = [UIImage imageNamed:kDefaultAvatarIcon];
			}
			
			dispatch_async(transformQueue, ^{
				
				UIImage *avatar = [UIImage multiAvatarImageWithFront:frontImage back:backImage diameter:diameter];
				
				dispatch_async(dispatch_get_main_queue(), ^{
					completionBlock(avatar);
				});
			});
		}
		else
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				completionBlock(nil);
			});
		}
	}};
	
	if (frontUserId || backUserId)
	{
		[self.databaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			frontUser = [transaction objectForKey:frontUserId inCollection:kSCCollection_STUsers];
			backUser = [transaction objectForKey:backUserId inCollection:kSCCollection_STUsers];
			
		} completionQueue:asyncQueue completionBlock:asyncBlock];
	}
	else
	{
		dispatch_async(asyncQueue, asyncBlock);
	}
}


/** ET 08/15/14 (refactored with RH from fetchMultiAvatarForFront:back:withDiameter:theme:usage:completionBlock:)
 * Use this method to aynchronously fetch a composite multiAvatar image for the given multiCast users array.
 *
 * Note: the `[DatabaseManager multiCastUsersForConversation:withTransaction:]` method, which initializes an array of
 * Silent Contacts users or temporary pseudo-users for a given multiCast conversation, may be used as the "users"
 * argument to return a composite avatar image in the given completion block.
 *
 * This method is used by ConversationDetailsVC, ConversationDetailsSecurityVC, and GroupUserInfoVC classes to display
 * a multiCast conversation avatar image.
 *
 * @param users An array of users, some of which may not be database users, with which to derive 
 *  front and back avatar images for the return composite image.
 * @param diameter The diameter of the return image
 * @param theme The them from which to derive the tintColor for image border
 * @param usage A usage enum value (ET: I don't know what this is yet...)
 * @param completionBlock An objective-C block to execute with the return image
 */
- (void)fetchMultiAvatarForUsers:(NSArray *)users 
                    withDiameter:(CGFloat)diameter
                           theme:(AppTheme *)theme
                           usage:(AvatarUsage)usage
                 completionBlock:(void (^)(UIImage *))completionBlock
{

    if (completionBlock == nil) return;
	
	STUser *frontUser = nil;
	STUser *backUser = nil;
    
    if (users.count > 0)
    {
        frontUser = users[0];
    }
    
    if (users.count > 1)
    {
        backUser = [users lastObject];
    }
	
	if (!frontUser && !backUser)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			completionBlock(nil);
		});
		
		return;
	}
	
	__block UIImage *frontImage = nil;
	__block UIImage *backImage = nil;
	
	dispatch_async(asyncQueue, ^{ @autoreleasepool {
		
		if (frontUser && frontUser.avatarFileName)
		{
			frontImage = [self imageWithName:frontUser.avatarFileName error:NULL];
		}
		else if (frontUser && frontUser.abRecordID != kABRecordInvalidID)
		{
			frontImage = [[AddressBookManager sharedInstance] imageForABRecordID:frontUser.abRecordID];
		}
		
		if (backUser && backUser.avatarFileName)
		{
			backImage = [self imageWithName:backUser.avatarFileName error:NULL];
		}
		else if (backUser && backUser.abRecordID != kABRecordInvalidID)
		{
			backImage = [[AddressBookManager sharedInstance] imageForABRecordID:backUser.abRecordID];
		}
		
		if (frontImage || backImage)
		{
			if (frontImage == nil)
			{
				frontImage = [UIImage imageNamed:kDefaultAvatarIcon];
			}
			if (backImage == nil)
			{
				backImage = [UIImage imageNamed:kDefaultAvatarIcon];
			}
			
			dispatch_async(transformQueue, ^{
				
				UIImage *avatar = [UIImage multiAvatarImageWithFront:frontImage back:backImage diameter:diameter];
				
				dispatch_async(dispatch_get_main_queue(), ^{
					completionBlock(avatar);
				});
			});
		}
		else
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				completionBlock(nil);
			});
		}
	}});
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Conversation Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (UIImage *)cachedOrDefaultAvatarForConversation:(STConversation *)convo
                                             user:(STUser *)user
                                         diameter:(CGFloat)diameter
                                            theme:(AppTheme *)theme
                                            usage:(AvatarUsage)usage
{
    NSAssert(convo != nil, @"This method must not be called with nil conversation");
//    UIImage *img = [[AvatarManager sharedInstance] defaultMultiAvatarImageWithDiameter:diameter];
//    // Best-effort generic single-user default avatar
//    if (nil == convo) return img;
    
    AvatarManager *sharedInstance = [AvatarManager sharedInstance];
    UIImage *img = nil;
    
    if (convo.isMulticast)
    {
        img = [sharedInstance defaultMultiAvatarImageWithDiameter:diameter];
        img = [img avatarImageWithDiameter:diameter usingColor:theme.appTintColor];
        
//        DDLogGreen(@"Return cached or default MULTICAST AVATAR");
        return img;
    }
    else 
    {
        if (IsSTInfoJID(convo.remoteJid) || IsOCAVoicemailJID(convo.remoteJid))
        {
            if (IsSTInfoJID(convo.remoteJid))
            {
//                DDLogGreen(@"Return defaultSilentTextInfoUser AVATAR");
                img = [sharedInstance defaultSilentTextInfoUserAvatarWithDiameter:diameter];
            }
            else if (IsOCAVoicemailJID(convo.remoteJid))
            {
//                DDLogGreen(@"Return defaultOCAUserAvatar AVATAR");
                img = [sharedInstance defaultOCAUserAvatarWithDiameter:diameter];
            }
            // Return avatar without ring color
            return img;
        }
        else 
        {
//            if (nil == user) {
//                // leave img nil / configure at exit
//            }
            
            id identifier = [sharedInstance avatarIdForUser:user];
            
            if ([identifier isKindOfClass:[NSString class]])
            {
			//	DDLogGreen(@"Return cached or default for UserId AVATAR");
				
				img = [sharedInstance cachedAvatarForUserId:user.uuid
				                               withDiameter:diameter
				                                      theme:theme
				                                      usage:usage
				                            defaultFallback:YES];
			}
			else if ([identifier isKindOfClass:[NSNumber class]])
			{
			//	DDLogGreen(@"Return cached or default for abRecordId AVATAR");
				
				int abRecordId = [(NSNumber *)identifier intValue];
				img = [sharedInstance cachedAvatarForABRecordID:abRecordId
				                                   withDiameter:diameter
				                                          theme:theme
				                                          usage:usage
				                                defaultFallback:YES];
			}
			// error or user is nil
			else
			{
                DDLogError(@"%s user is NIL or error has occurred.", __PRETTY_FUNCTION__);
                // edge case, remote user doesn't have user record in DB, (probably deleted)
                
                // leave img nil / configure at exit
            }
        }
    }
    
    // If nil, return configured default image
    if (nil == img)
    {
//        DDLogGreen(@"Return DEFAULT AVATAR");
        img = [[AvatarManager sharedInstance] defaultAvatarWithDiameter:diameter];
        img = [img avatarImageWithDiameter:diameter usingColor:theme.appTintColor];
    }
        
    return img;
}
 

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns an avatar identifier for the given user.
 *
 * If the given user is a non-temp user, then user.uuid is returned;
 * Otherwise, user.abRecordId is returned, boxed in an NSNumber.
 *
 * Note: This method is used as a helper for the `fetchMultiAvatarForUsers:withDiameter:theme:usage:completionBlock:`
 * method, and by `[SCTAvatarView updateUserAvatar]`.
 *
 * @param aUser A user instance for which to return an avatarId
 * @return An identifier for an avatar image for the given user; may be a string or NSNumber.
**/
- (id)avatarIdForUser:(STUser *)user
{
	// RH - 29 Oct, 2014
	//
	// We used to check the database to ensure the user actually existed.
	// This is no longer needed.
	// If the user is a temp user, it has a nil uuid.
	// In fact, there is even a simple user.isTempUser method now.
	
    if (!user.isTempUser) 
    {
		return user.uuid;
    }
    else if (user == nil)
	{
		return @(kABRecordInvalidID);
	}
    else 
    {
		return @(user.abRecordID);
    }
}

@end
