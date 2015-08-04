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
#import <Foundation/Foundation.h>

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
@interface SCWebDownloadManager : NSObject

/**
 * Standard singleton.
**/
+ (SCWebDownloadManager *)sharedInstance;

/**
 * Requests that the given avatar be downloaded.
 *
 * If a download for the requested avatar is already in progress,
 * then then given completionBlock is added to the list of completionBlocks
 * that will be invoked once the download completes.
**/
- (void)downloadAvatar:(NSString *)relativeAvatarURL
         withNetworkID:(NSString *)networkID
       completionBlock:(void (^)(NSError *error, UIImage *image))completion;

/**
 * Requests that the given avatar be downloaded.
 * 
 * If a download for the requested avatar is already in progress,
 * then this method returns NO (and will NOT invoke the completionBlock).
 * 
 * Use this method if only a single completionBlock handler is needed,
 * and subsequent requests should be ignored.
**/
- (BOOL)maybeDownloadAvatar:(NSString *)relativeAvatarURL
              withNetworkID:(NSString *)networkID
            completionBlock:(void (^)(NSError *error, UIImage *image))completion;

@end
