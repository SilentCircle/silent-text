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
#import "MessageStream.h"
#import "STLocalUser.h"


@interface MessageStreamManager : NSObject

/**
 * Returns the MessageStream instance for the given local user.
 * The MessageStream instance is normally pre-existing, and is simply fetched from a dictionary.
 * Otherwise the MessageStream instance is created, stored in the dictionary, and returned.
 *
 * This method is thread-safe.
**/
+ (MessageStream *)messageStreamForUser:(STLocalUser *)localUser;

/**
 * Returns the MessageStream instance for the given local user (if and only if the instance is pre-existing).
 *
 * This method is thread-safe.
**/
+ (MessageStream *)existingMessageStreamForUser:(STLocalUser *)localUser;

/**
 * Experimental API.
 * Attempts to deallocate the given MessageStream instance, and remove it from the "cache".
 *
 * This method is thread-safe.
**/
+ (void)removeMessageStreamForUser:(STLocalUser *)localUser;

/**
 * Enumerates the existing MessageStream instances, and invokes the disconnect method on all of them.
**/
+ (void)disconnectAllMessageStreams;

@end
