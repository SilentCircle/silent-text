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
//
//  XMPPJIDSet.m
//  ST2
//
//  Created by Robbie Hanson on 9/5/14.
//

#import "XMPPJIDSet.h"

@interface XMPPJIDSet () {
@protected
	NSSet *set;
}
@end

@implementation XMPPJIDSet

+ (instancetype)setWithJid:(XMPPJID *)jid
{
	return [[self alloc] initWithJid:jid];
}

+ (instancetype)setWithJids:(NSArray *)jids
{
	return [[self alloc] initWithJids:jids];
}

+ (instancetype)setWithJidSet:(NSSet *)jids
{
	return [[self alloc] initWithJidSet:jids];
}

#pragma mark Init

- (instancetype)init
{
	if ((self = [super init]))
	{
		set = [[[self setClass] alloc] init];
	}
	return self;
}

- (instancetype)initForCopying
{
	self = [super init];
	return self;
}

- (instancetype)initWithJid:(XMPPJID *)jid
{
	NSAssert([jid isKindOfClass:[XMPPJID class]], @"Invalid parameter - not a XMPPJID");
	
	if ((self = [super init]))
	{
		if (jid)
			set = [[[self setClass] alloc] initWithObjects:jid, nil];
		else
			set = [[[self setClass] alloc] init];
	}
	return self;
}

- (instancetype)initWithJids:(NSArray *)jids
{
	if ((self = [super init]))
	{
		if ([self containsOnlyXMPPJIDs:jids])
		{
			if (jids)
				set = [[[self setClass] alloc] initWithArray:jids];
			else
				set = [[[self setClass] alloc] init];
		}
		else
		{
			set = [self setFromMixed:jids withCount:[jids count]];
		}
	}
	return self;
}

- (instancetype)initWithJidSet:(NSSet *)jids
{
	if ((self = [super init]))
	{
		if ([self containsOnlyXMPPJIDs:jids])
		{
			if (jids)
				set = [[[self setClass] alloc] initWithSet:jids];
			else
				set = [[[self setClass] alloc] init];
		}
		else
		{
			set = [self setFromMixed:jids withCount:[jids count]];
		}
	}
	return self;
}

#pragma mark Init Utilities

- (BOOL)containsOnlyXMPPJIDs:(id <NSFastEnumeration>)arrayOrSet
{
	for (id jidItem in arrayOrSet)
	{
		if (![jidItem isKindOfClass:[XMPPJID class]])
			return NO;
	}
	
	return YES;
}

- (NSSet *)setFromMixed:(id <NSFastEnumeration>)arrayOrSet withCount:(NSUInteger)count
{
	NSMutableSet *mSet = [NSMutableSet setWithCapacity:count];
	
	for (id jidItem in arrayOrSet)
	{
		XMPPJID *jid = nil;
		
		if ([jidItem isKindOfClass:[XMPPJID class]])
			jid = (XMPPJID *)jidItem;
		else if ([jidItem isKindOfClass:[NSString class]])
			jid = [XMPPJID jidWithString:(NSString *)jidItem];
		
		if (jid)
			[mSet addObject:jid];
	}
	
	return [mSet copy];
}

#pragma mark Subclassing

- (Class)setClass
{
	return [NSSet class];
}

#pragma mark NSCoding

- (instancetype)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super init]))
	{
		set = [decoder decodeObjectForKey:@"set"];
	}
	return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:set forKey:@"set"];
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone
{
	if ([self isKindOfClass:[XMPPJIDMutableSet class]])
	{
		XMPPJIDSet *copy = [[XMPPJIDSet alloc] initForCopying];
		copy->set = [set copy];
		
		return copy;
	}
	else // immutable
	{
		return self;
	}
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
	XMPPJIDMutableSet *mutableCopy = [[XMPPJIDMutableSet alloc] initForCopying];
	((XMPPJIDSet *)mutableCopy)->set = [set mutableCopy];
	
	return mutableCopy;
}

#pragma mark NSFastEnumeration

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id __unsafe_unretained [])stackbuf
                                    count:(NSUInteger)len
{
	return [set countByEnumeratingWithState:state objects:stackbuf count:len];
}

#pragma mark Methods

- (BOOL)containsJid:(XMPPJID *)jid
{
	return [set containsObject:jid];
}

- (BOOL)containsJid:(XMPPJID *)jid options:(XMPPJIDCompareOptions)mask
{
	if (mask == XMPPJIDCompareFull)
	{
		return [set containsObject:jid];
	}
	else
	{
		for (XMPPJID *aJid in set)
		{
			if ([aJid isEqualToJID:jid options:mask])
				return YES;
		}
		
		return NO;
	}
}

- (NSUInteger)count
{
	return [set count];
}

- (NSArray *)allJids
{
	return [set allObjects];
}

- (XMPPJIDSet *)setByAddingJid:(XMPPJID *)jid
{
	if (jid == nil || [self containsJid:jid])
	{
		return [self copy];
	}
	else
	{
		XMPPJIDSet *copy = [[XMPPJIDSet alloc] initForCopying];
		copy->set = [set setByAddingObject:jid];
		
		return copy;
	}
}

- (XMPPJIDSet *)setByAddingJid:(XMPPJID *)jid options:(XMPPJIDCompareOptions)mask
{
	if (jid == nil || [self containsJid:jid options:mask])
	{
		return [self copy];
	}
	else
	{
		XMPPJIDSet *copy = [[XMPPJIDSet alloc] initForCopying];
		copy->set = [set setByAddingObject:jid];
		
		return copy;
	}
}

- (XMPPJIDSet *)setByRemovingJid:(XMPPJID *)jid
{
	if (jid == nil || ![self containsJid:jid])
	{
		return [self copy];
	}
	else
	{
		XMPPJIDMutableSet *mutableCopy = [[XMPPJIDMutableSet alloc] initForCopying];
		[mutableCopy removeJid:jid];
		
		return [mutableCopy copy];
	}
}

- (XMPPJIDSet *)setByRemovingJid:(XMPPJID *)jid options:(XMPPJIDCompareOptions)mask
{
	if (jid == nil || ![self containsJid:jid options:mask])
	{
		return [self copy];
	}
	else
	{
		XMPPJIDMutableSet *mutableCopy = [[XMPPJIDMutableSet alloc] initForCopying];
		[mutableCopy removeJid:jid options:mask];
		
		return [mutableCopy copy];
	}
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPJIDMutableSet

+ (instancetype)setWithCapacity:(NSUInteger)capacity
{
	return [[self alloc] initWithCapacity:capacity];
}

- (instancetype)initWithCapacity:(NSUInteger)capacity
{
	if ((self = [super init]))
	{
		set = [[[self setClass] alloc] initWithCapacity:capacity];
	}
	return self;
}

- (Class)setClass
{
	return [NSMutableSet class];
}

- (void)addJid:(XMPPJID *)jid
{
	[(NSMutableSet *)set addObject:jid];
}

- (void)addJid:(XMPPJID *)jid options:(XMPPJIDCompareOptions)mask
{
	if (jid == nil) return;
	
	if (mask == XMPPJIDCompareFull)
	{
		[(NSMutableSet *)set addObject:jid];
	}
	else
	{
		BOOL found = NO;
		for (XMPPJID *aJid in set)
		{
			if ([aJid isEqualToJID:jid options:mask])
			{
				found = YES;
				break;
			}
		}
		if (!found)
		{
			[(NSMutableSet *)set addObject:jid];
		}
	}
}

- (void)removeJid:(XMPPJID *)jid
{
	[(NSMutableSet *)set removeObject:jid];
}

- (void)removeJid:(XMPPJID *)jid options:(XMPPJIDCompareOptions)mask
{
	if (mask == XMPPJIDCompareFull)
	{
		[(NSMutableSet *)set removeObject:jid];
	}
	else
	{
		[(NSMutableSet *)set filterUsingPredicate:[NSPredicate predicateWithBlock:
		    ^BOOL(XMPPJID *aJid, NSDictionary *bindings)
		{
			if ([aJid isEqualToJID:jid options:mask])
				return NO;  // remove from set
			else
				return YES; // keep
		}]];
	}
}

- (void)removeAllJids;
{
	[(NSMutableSet *)set removeAllObjects];
}

@end
