/*
Copyright (C) 2014-2015, Silent Circle, LLC. All rights reserved.

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
#import "STMessageIDCache.h"

/**
 * Keys for encoding / decoding (to avoid typos)
**/
static NSString *const k_version    = @"version";
static NSString *const k_orderedSet = @"orderedSet";


#define STMessageIDCache_Limit 32


@implementation STMessageIDCache
{
	NSOrderedSet *orderedSet;
}

/**
 * Overrides [STDatabaseObject monitoredProperties].
**/
+ (NSMutableSet *)monitoredProperties
{
	NSMutableSet *monitoredProperties = [super monitoredProperties];
	[monitoredProperties addObject:@"orderedSet"];
	
	return monitoredProperties;
}

- (id)init
{
	if ((self = [super init]))
	{
		orderedSet = [[NSOrderedSet alloc] init];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		orderedSet = [decoder decodeObjectForKey:k_orderedSet];
		
		// Sanity checks
		
		if (orderedSet == nil) {
			orderedSet = [[NSOrderedSet alloc] init];
		}
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeInt:1 forKey:k_version];
	[coder encodeObject:orderedSet forKey:k_orderedSet];
}

- (id)copyWithZone:(NSZone *)zone
{
	STMessageIDCache *copy = [super copyWithZone:zone];
	copy->orderedSet = [orderedSet copy];
	
	return copy;
}

- (void)addMessageID:(NSString *)messageID
{
	NSMutableOrderedSet *mOrderedSet = [orderedSet mutableCopy];
	[mOrderedSet addObject:messageID];
	
	while ([mOrderedSet count] > STMessageIDCache_Limit)
	{
		[mOrderedSet removeObjectAtIndex:0];
	}
	
	[self willChangeValueForKey:@"orderedSet"];
	orderedSet = [mOrderedSet copy];
	[self didChangeValueForKey:@"orderedSet"];
}

- (BOOL)containsMessageID:(NSString *)messageID
{
	return [orderedSet containsObject:messageID];
}

- (NSString *)description
{
    NSMutableString *desc = [NSMutableString stringWithCapacity:100];
    [desc appendFormat:@"<STMessageIDCache[%p]: count=%lu (most recent to least recent)\n",
	  self, (unsigned long)orderedSet.count];
    
    [orderedSet enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [desc appendFormat:@"  %@\n",obj];
    }];
	
	[desc appendString:@">"];
    return desc;
}

@end
