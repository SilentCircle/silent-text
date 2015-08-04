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
#import <AddressBook/ABRecord.h>

#import "XMPPJID.h"

extern NSString *const NOTIFICATION_ADDRESSBOOK_UPDATED;

extern NSString *const kABInfoKey_abRecordID;
extern NSString *const kABInfoKey_firstName;
extern NSString *const kABInfoKey_lastName;
extern NSString *const kABInfoKey_compositeName;
extern NSString *const kABInfoKey_organization;
extern NSString *const kABInfoKey_displayName;
extern NSString *const kABInfoKey_notes;
extern NSString *const kABInfoKey_modDate;
extern NSString *const kABInfoKey_jid;


@interface AddressBookManager : NSObject

+ (instancetype)sharedInstance;

- (void)updateAddressBookUsers;

// Represents the last time updateAddressBookUsers was run
- (NSDate *)lastUpdate;

- (void)updateUser:(NSString *)userId withABRecordID:(ABRecordID)abRecordID isLinkedByAB:(BOOL)isLinkedByAB;

- (UIImage *)imageForJID:(XMPPJID *)jid;
- (UIImage *)imageForJidStr:(NSString *)jidStr;
- (UIImage *)imageForABRecordID:(ABRecordID)abRecordID;

- (BOOL)hasImageForJID:(XMPPJID *)jid;
- (BOOL)hasImageForJidStr:(NSString *)jidStr;
- (BOOL)hasImageForABRecordID:(ABRecordID)abRecordID;

/**
 * Returns an NSDictionary with info from the Address Book for the given abRecordID.
 * 
 * Use the constants defined at the top of AddressBookManager.h for the dictionary keys.
 * They all start with "kABInfoKey_".
**/
- (NSDictionary *)infoForABRecordID:(ABRecordID)abRecordID;

/**
 * Returns an NSDictionary with info from the Address Book for the given jid.
 *
 * Use the constants defined at the top of AddressBookManager.h for the dictionary keys.
 * They all start with "kABInfoKey_".
**/
- (NSDictionary *)infoForSilentCircleJID:(XMPPJID *)jid;
- (NSDictionary *)infoForSilentCircleJidStr:(NSString *)jid;

/**
 * Returns an array of XMPPJID instances.
**/
- (NSArray *)SilentCircleJids;
- (NSArray *)SilentCircleJidsForCurrentUser;

- (NSArray *)allEntries; // array of ABEntry items

- (NSData *)vCardDataForABRecordID:(ABRecordID)abRecordID;
- (void)addvCardToAddressBook:(NSData *)vCard completion:(void (^)(BOOL success))completionBlock;

@end

#pragma mark -

@interface ABEntry : NSObject

@property (nonatomic, assign, readonly) ABRecordID abRecordID;
@property (nonatomic, strong, readonly) NSString *name;

@end

#pragma mark -

@interface ABInfoEntry : NSObject

- (id)initWithABRecordID:(ABRecordID)inAbRecordID name:(NSString *)inName jidStr:(NSString *)inJidStr;

@property (nonatomic, assign, readonly) ABRecordID abRecordID;
@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, strong, readonly) NSString *jidStr;

@end
