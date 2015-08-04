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
#import <Foundation/Foundation.h>
#import "XMPPJID.h"

/**
 * This class is a simple wrapper around NSSet.
 * It provides:
 *
 * - a typed set to ensure only proper JID instances are contained
 * - typed methods to add & remove only proper JID instances
 * - smart methods that support XMPPJIDCompareOptions
**/
@interface XMPPJIDSet : NSObject <NSCopying, NSMutableCopying, NSFastEnumeration, NSCoding>

+ (instancetype)setWithJid:(XMPPJID *)jid;
+ (instancetype)setWithJids:(NSArray *)jids;
+ (instancetype)setWithJidSet:(NSSet *)jids;

- (instancetype)init; // empty
- (instancetype)initWithJid:(XMPPJID *)jid;
- (instancetype)initWithJids:(NSArray *)jids; // supports both XMPPJID & NSString
- (instancetype)initWithJidSet:(NSSet *)jids; // supports both XMPPJID * NSString

- (BOOL)containsJid:(XMPPJID *)jid;
- (BOOL)containsJid:(XMPPJID *)jid options:(XMPPJIDCompareOptions)mask;

- (NSUInteger)count;

- (NSArray *)allJids;

- (XMPPJIDSet *)setByAddingJid:(XMPPJID *)jid;
- (XMPPJIDSet *)setByAddingJid:(XMPPJID *)jid options:(XMPPJIDCompareOptions)mask;

- (XMPPJIDSet *)setByRemovingJid:(XMPPJID *)jid;
- (XMPPJIDSet *)setByRemovingJid:(XMPPJID *)jid options:(XMPPJIDCompareOptions)mask;

@end

@interface XMPPJIDMutableSet : XMPPJIDSet <NSCopying, NSMutableCopying, NSCoding>

+ (instancetype)setWithCapacity:(NSUInteger)capacity;

- (instancetype)initWithCapacity:(NSUInteger)capacity;

- (void)addJid:(XMPPJID *)jid;
- (void)addJid:(XMPPJID *)jid options:(XMPPJIDCompareOptions)mask;

- (void)removeJid:(XMPPJID *)jid;
- (void)removeJid:(XMPPJID *)jid options:(XMPPJIDCompareOptions)mask;

- (void)removeAllJids;

@end
