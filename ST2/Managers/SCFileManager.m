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
#import "SCFileManager.h"
#import "AppConstants.h"
#import "STLogging.h"

// Log Levels: off, error, warn, info, verbose
// Log Flags : trace
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_INFO;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_WARN;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

static NSString *const kDirectoryMediaCache     = @"MediaCache";
static NSString *const kDirectoryRecordingCache = @"RecordingCache";
static NSString *const kDirectorySCloudCache    = @"SCloudCache";


@implementation SCFileManager

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Directories
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSURL *)cacheDirectory
{
	NSError *error = nil;
	NSURL *caches = [[NSFileManager defaultManager] URLForDirectory: NSCachesDirectory
	                                                       inDomain: NSUserDomainMask
	                                              appropriateForURL: nil
	                                                         create: YES
	                                                          error: &error];
	if (error) {
		DDLogError(@"Error creating directory: %@", error);
	}
	
	return caches;
}

+ (NSURL *)mediaCacheDirectoryURL
{
	NSURL *cacheDirectory = [self cacheDirectory];
	NSURL *mediaCacheDirectory = [NSURL URLWithString:kDirectoryMediaCache relativeToURL:cacheDirectory];
	
	NSError *error = nil;
	[[NSFileManager defaultManager] createDirectoryAtURL: mediaCacheDirectory
	                         withIntermediateDirectories: YES
	                                          attributes: nil
	                                               error: &error];
	if (error) {
		DDLogError(@"Error creating directory (%@): %@", mediaCacheDirectory, error);
	}
	
    return error ? nil : mediaCacheDirectory;
}

+ (NSURL *)scloudCacheDirectoryURL
{
	NSURL *cacheDirectory = [self cacheDirectory];
    NSURL *scloudCacheDirectory = [NSURL URLWithString:kDirectorySCloudCache relativeToURL:cacheDirectory];
	
	NSError *error = nil;
	[[NSFileManager defaultManager] createDirectoryAtURL: scloudCacheDirectory
	                         withIntermediateDirectories: YES
	                                          attributes: nil
	                                               error: &error];
	if (error) {
		DDLogError(@"Error creating directory (%@): %@", scloudCacheDirectory, error);
	}
	
	return error ? nil : scloudCacheDirectory;
}

+ (NSURL *)recordingCacheDirectoryURL
{
	NSURL *cacheDirectory = [self cacheDirectory];
	NSURL *recordingCacheDirectory = [NSURL URLWithString:kDirectoryRecordingCache relativeToURL:cacheDirectory];
	
	NSError *error = nil;
	[[NSFileManager defaultManager] createDirectoryAtURL: recordingCacheDirectory
	                         withIntermediateDirectories: YES
	                                          attributes: nil
	                                               error: &error];
	if (error) {
		DDLogError(@"Error creating directory (%@): %@", recordingCacheDirectory, error);
	}
	
	return error ? nil : recordingCacheDirectory;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark File Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (void)cleanDirectoryAtURL:(NSURL *)url
{
	if (url == nil) return;
	
	NSFileManager *fm  = [NSFileManager defaultManager];
	
	NSError *fetchError = nil;
	NSArray *urls = [fm contentsOfDirectoryAtURL:url includingPropertiesForKeys:nil options:0 error:&fetchError];
	
	if (fetchError) {
		DDLogError(@"Error getting contents of director (%@): %@", url, fetchError);
	}
	
	for (NSURL *fileURL in urls)
	{
		NSError *removeError = nil;
		[fm removeItemAtURL:fileURL error:&removeError];
		
		if (removeError) {
			DDLogError(@"Error removing file (%@): %@", fileURL, removeError);
		}
	}
}

+ (void)cleanMediaCache
{
	[self cleanDirectoryAtURL:[self mediaCacheDirectoryURL]];
}

+ (void)calculateScloudCacheSizeWithCompletionBlock:(void (^)(NSError *error, NSNumber *totalSize))completionBlock
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ @autoreleasepool {
        
        size_t totalSize = 0;
        NSError *error     = nil;
        
		NSURL *scloudDirURL = [self scloudCacheDirectoryURL];
		NSString *dirPath = scloudDirURL.filePathURL.path;
		
		NSArray *fileNames = [NSFileManager.defaultManager contentsOfDirectoryAtPath:dirPath error:&error];
		if (!error)
        {
            
			for (NSString *filePath in fileNames)
			{
				NSString *fullPath = [dirPath stringByAppendingPathComponent: filePath];
                
                NSDictionary *attr = [NSFileManager.defaultManager attributesOfItemAtPath: fullPath error: &error];
                if(error) break;
                
                NSNumber* fileSize = [attr objectForKey:NSFileSize];
                totalSize += [fileSize unsignedLongValue];
            }
		}
        
        
        if (completionBlock)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(error, [NSNumber numberWithLongLong:totalSize] );
            });
        };
		
	}});
}

@end
