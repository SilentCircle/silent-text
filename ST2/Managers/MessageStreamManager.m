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
#import "MessageStreamManager.h"
#import "STLogging.h"

#import <libkern/OSAtomic.h>

// Log levels: off, error, warn, info, verbose
#if DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif


@implementation MessageStreamManager

static OSSpinLock messageStreamsLock;
static NSMutableDictionary *messageStreams;

+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		initialized = YES;
		
		messageStreamsLock = OS_SPINLOCK_INIT;
		messageStreams = [[NSMutableDictionary alloc] init];
	}
}

+ (MessageStream *)messageStreamForUser:(STLocalUser *)localUser
{
	return [self messageStreamForUser:localUser createIfNeeded:YES];
}

+ (MessageStream *)existingMessageStreamForUser:(STLocalUser *)localUser
{
	return [self messageStreamForUser:localUser createIfNeeded:NO];
}

+ (MessageStream *)messageStreamForUser:(STLocalUser *)localUser createIfNeeded:(BOOL)shouldCreate
{
    if (localUser == nil) return nil;
    if (!localUser.isLocal)
    {
        DDLogWarn(@"Requested MessageStream for non-local user");
        return nil;
    }
    
    NSString *userID = localUser.uuid;
    MessageStream *messageStream = nil;
    
    OSSpinLockLock(&messageStreamsLock);
    @try
	{
        messageStream = [messageStreams objectForKey:userID];
        if (messageStream == nil && shouldCreate)
        {
            messageStream = [[MessageStream alloc] initWithUser:localUser];
            [messageStreams setObject:messageStream forKey:userID];
        }
    }
	@finally
	{
    	OSSpinLockUnlock(&messageStreamsLock);
	}
	
    return messageStream;
}

+ (void)removeMessageStreamForUser:(STLocalUser *)localUser
{
    if (localUser == nil) return;
    if (!localUser.isLocal)
    {
        DDLogWarn(@"Attempting to remove MessageStream for non-local user");
        return;
    }
    
    NSString *userID = localUser.uuid;
    
    OSSpinLockLock(&messageStreamsLock);
	@try
	{
        MessageStream *ms = [messageStreams objectForKey:userID];
        if (ms)
        {
            [ms disconnectAndKill];
            [messageStreams removeObjectForKey:userID];
        }
    }
	@finally
	{
    	OSSpinLockUnlock(&messageStreamsLock);
	}
}

+ (void)disconnectAllMessageStreams
{
	OSSpinLockLock(&messageStreamsLock);
	@try
	{
		[messageStreams enumerateKeysAndObjectsUsingBlock:^(NSString *userID, MessageStream *ms, BOOL *stop) {
			
			[ms disconnect];
		}];
	}
	@finally
	{
		OSSpinLockUnlock(&messageStreamsLock);
	}
}

@end
