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
#import "YapDatabaseTransaction+MessageStream.h"
#import <objc/runtime.h>


static char key_completionBlocks;
static char key_requiredConnectionID;
static char key_isSendQueuedItemsLoop;
static char key_isReKeying;

@implementation YapDatabaseReadWriteTransaction (MessageStream)

@dynamic completionBlocks;
@dynamic requiredConnectionID;
@dynamic isSendQueuedItemsLoop;
@dynamic isReKeying;


#pragma mark completionBlocks

- (NSMutableArray *)completionBlocks
{
	NSMutableArray *completionBlocks = objc_getAssociatedObject([self class], &key_completionBlocks);
	return completionBlocks;
}

- (void)setCompletionBlocks:(NSMutableArray *)completionBlocks
{
	objc_setAssociatedObject([self class], &key_completionBlocks, completionBlocks, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


#pragma mark requiredConnectionID

- (NSNumber *)requiredConnectionID
{
	NSNumber *connectionID = objc_getAssociatedObject([self class], &key_requiredConnectionID);
	return connectionID;
}

- (void)setRequiredConnectionID:(NSNumber *)connectionID
{
	objc_setAssociatedObject([self class], &key_requiredConnectionID, connectionID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


#pragma mark isSendQueuedItemsLoop

- (BOOL)isSendQueuedItemsLoop
{
	NSNumber *number = objc_getAssociatedObject([self class], &key_isSendQueuedItemsLoop);
	return [number boolValue];
}

- (void)setIsSendQueuedItemsLoop:(BOOL)flag
{
	NSNumber *number = @(flag);
	objc_setAssociatedObject([self class], &key_isSendQueuedItemsLoop, number, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


#pragma mark isReKeying

- (BOOL)isReKeying
{
	NSNumber *number = objc_getAssociatedObject([self class], &key_isReKeying);
	return [number boolValue];
}

- (void)setIsReKeying:(BOOL)flag
{
	NSNumber *number = @(flag);
	objc_setAssociatedObject([self class], &key_isReKeying, number, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
