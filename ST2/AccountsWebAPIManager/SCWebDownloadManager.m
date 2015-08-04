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
#import "SCWebDownloadManager.h"
#import "SCWebAPIManager.h"
#import "AppDelegate.h"
#import "STLogging.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

/**
 * SCWebDownloadManager is an abstraction layer that sits above SCWebAPIManager.
 * For WebAPI's that may be invoked quite often,
 * this class provides a bit of consolidation in order to decrease network overhead.
 *
 * For example, there are database hooks that handle requesting an avatar download if the avatar is missing.
 * But if the database is getting hammered, then these hooks might end up requesting the avatar download 20 times.
 *
 * This method provides a convenient way to "fire and forget" a URL request,
 * and allows all URL download consolidation code to be handled by this class.
**/
@implementation SCWebDownloadManager
{
	NSLock *inFlightRequestsLock;
	NSMutableDictionary *inFlightRequests;
}

static SCWebDownloadManager *sharedInstance;

+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		initialized = YES;
		sharedInstance = [[SCWebDownloadManager alloc] init];
	}
}

+ (SCWebDownloadManager *)sharedInstance
{
	return sharedInstance;
}

- (instancetype)init
{
	NSAssert(sharedInstance == nil, @"You MUST used sharedInstance singleton.");
	
	if ((self = [super init]))
	{
		inFlightRequestsLock = [[NSLock alloc] init];
		inFlightRequests = [[NSMutableDictionary alloc] init];
	}
	return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * @return The total number of completionBlocks queued for the given {networkID, key} tuple.
**/
- (NSUInteger)addCompletionBlock:(id)completionBlock forKey:(NSString *)key inNetworkID:(NSString *)networkID
{
	NSUInteger result = 0;
	
	if (key == nil || networkID == nil)
	{
		DDLogWarn(@"%@ - Invalid parameter(s): key(%@), networkID(%@)", THIS_METHOD, key, networkID);
		return result;
	}
	
	[inFlightRequestsLock lock];
	@try {
		
		NSMutableDictionary *networkRequests = [inFlightRequests objectForKey:networkID];
		if (networkRequests == nil)
		{
			networkRequests = [[NSMutableDictionary alloc] init];
			[inFlightRequests setObject:networkRequests forKey:networkID];
		}
		
		NSMutableArray *completionBlocks = [networkRequests objectForKey:key];
		if (completionBlocks == nil)
		{
			completionBlocks = [[NSMutableArray alloc] init];
			[networkRequests setObject:completionBlocks forKey:key];
		}
		
		[completionBlocks addObject:completionBlock];
		result = completionBlocks.count;
	}
	@finally {
		[inFlightRequestsLock unlock];
	}
	
	return result;
}

/**
 * @return YES if there were no other completionBlocks (in which case the completionBlock was added).
 *          NO otherwise (in which case the completionBlock was not added).
**/
- (BOOL)maybeAddCompletionBlock:(id)completionBlock forKey:(NSString *)key inNetworkID:(NSString *)networkID
{
	BOOL result = NO;
	
	if (key == nil || networkID == nil)
	{
		DDLogWarn(@"%@ - Invalid parameter(s): key(%@), networkID(%@)", THIS_METHOD, key, networkID);
		return result;
	}
	
	[inFlightRequestsLock lock];
	@try {
		
		NSMutableDictionary *networkRequests = [inFlightRequests objectForKey:networkID];
		if (networkRequests == nil)
		{
			networkRequests = [[NSMutableDictionary alloc] init];
			[inFlightRequests setObject:networkRequests forKey:networkID];
		}
		
		NSMutableArray *completionBlocks = [networkRequests objectForKey:key];
		if (completionBlocks == nil)
		{
			completionBlocks = [[NSMutableArray alloc] init];
			[networkRequests setObject:completionBlocks forKey:key];
		}
		
		if (completionBlocks.count == 0)
		{
			[completionBlocks addObject:completionBlock];
			result = YES;
		}
	}
	@finally {
		[inFlightRequestsLock unlock];
	}
	
	return result;
}

- (NSArray *)drainCompletionBlocksForKey:(NSString *)key inNetworkID:(NSString *)networkID
{
	NSArray *result = nil;
	
	if (key == nil || networkID == nil)
	{
		DDLogWarn(@"%@ - Invalid parameter(s): key(%@), networkID(%@)", THIS_METHOD, key, networkID);
		return result;
	}
	
	[inFlightRequestsLock lock];
	@try {
		
		NSMutableDictionary *networkRequests = [inFlightRequests objectForKey:networkID];
		if (networkRequests)
		{
			NSMutableArray *completionBlocks = [networkRequests objectForKey:key];
			if (completionBlocks)
			{
				result = completionBlocks;
				[networkRequests removeObjectForKey:key];
			}
		}
	}
	@finally {
		[inFlightRequestsLock unlock];
	}
	
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Avatar
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Internal method to handle the actual URL request and subsequent completionBlock.
**/
- (void)_downloadAvatar:(NSString *)avatarURL withNetworkID:(NSString *)networkID
{
	[[SCWebAPIManager sharedInstance] getDataForNetworkID:networkID
	                                            urlString:avatarURL
	                                      completionBlock:^(NSError *error, NSData *data)
	{
		UIImage *image = nil;
		if (!error)
		{
			image = [UIImage imageWithData:data];
			if (!image)
			{
				NSString *str = [[NSString alloc] initWithBytes:[data bytes]
				                                         length:[data length]
				                                       encoding:NSUTF8StringEncoding];
				
				DDLogError(@"SCWebAPIManager getDataForNetworkID:\"%@\" urlString:\"%@\" returned non-image: %@",
				             networkID, avatarURL, str);
				
				// Some kind of server error occurred.
				// So we'll simulate a 500 error (internal server error).
				
				NSInteger statusCode = 500;
				
				NSString *statusCodeStr = [NSHTTPURLResponse localizedStringForStatusCode:statusCode];
				NSDictionary *details = @{ NSLocalizedDescriptionKey: statusCodeStr };
				
				error = [NSError errorWithDomain:NSURLErrorDomain code:statusCode userInfo:details];
			}
		}
		
		NSArray *completionBlocks = [self drainCompletionBlocksForKey:avatarURL inNetworkID:networkID];
		
		for (void (^completionBlock)(NSError *error, UIImage *image) in completionBlocks)
		{
			completionBlock(error, image);
		}
	}];
}

/**
 * Requests that the given avatar be downloaded.
 *
 * If a download for the requested avatar is already in progress,
 * then then given completionBlock is added to the list of completionBlocks
 * that will be invoked once the download completes.
**/
- (void)downloadAvatar:(NSString *)inAvatarURL
         withNetworkID:(NSString *)inNetworkID
       completionBlock:(void (^)(NSError *error, UIImage *image))completionBlock
{
	NSString *avatarURL = [inAvatarURL copy]; // mutable string protection
	NSString *networkID = [inNetworkID copy]; // mutable string protection
	
	if (avatarURL == nil || networkID == nil)
	{
		DDLogWarn(@"%@ - Invalid parameter(s): avatarURL(%@), networkID(%@)", THIS_METHOD, avatarURL, networkID);
		
		if (completionBlock) {
			NSError *error = [STAppDelegate otherError:@"Invalid parameter"];
			dispatch_async(dispatch_get_main_queue(), ^{
				completionBlock(error, nil);
			});
		}
		return;
	}
	
	// We support NULL completionBlocks for debug purposes (exercise the WebAPI)
	if (completionBlock == NULL) {
		completionBlock = ^(NSError *error, UIImage *image) {};
	}
	
	NSUInteger count = [self addCompletionBlock:completionBlock forKey:avatarURL inNetworkID:networkID];
	if (count == 1)
	{
		[self _downloadAvatar:avatarURL withNetworkID:networkID];
	}
}

/**
 * Requests that the given avatar be downloaded.
 * 
 * If a download for the requested avatar is already in progress,
 * then this method returns NO (and will NOT invoke the completionBlock).
 * 
 * Use this method if only a single completionBlock handler is needed,
 * and subsequent requests should be ignored.
**/
- (BOOL)maybeDownloadAvatar:(NSString *)inAvatarURL
              withNetworkID:(NSString *)inNetworkID
            completionBlock:(void (^)(NSError *error, UIImage *image))completionBlock
{
	NSString *avatarURL = [inAvatarURL copy]; // mutable string protection
	NSString *networkID = [inNetworkID copy]; // mutable string protection
	
	if (avatarURL == nil || networkID == nil)
	{
		DDLogWarn(@"%@ - Invalid parameter(s): avatarURL(%@), networkID(%@)", THIS_METHOD, avatarURL, networkID);
		
		return NO;
	}
	
	// We support NULL completionBlocks for debug purposes (exercise the WebAPI)
	if (completionBlock == NULL) {
		completionBlock = ^(NSError *error, UIImage *image) {};
	}
	
	BOOL result = [self maybeAddCompletionBlock:completionBlock forKey:avatarURL inNetworkID:networkID];
	if (result)
	{
		[self _downloadAvatar:avatarURL withNetworkID:networkID];
	}
	
	return result;
}

@end
