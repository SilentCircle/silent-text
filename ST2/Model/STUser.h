/*
Copyright (C) 2013-2015, Silent Circle, LLC. All rights reserved.

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
#import <CoreLocation/CoreLocation.h>

#import "STDatabaseObject.h"
#import "YapDatabaseRelationshipNode.h"
#import "XMPPJID.h"


static int const kSTUserVersion = 5;

typedef NS_ENUM(NSInteger, AvatarSource) {
	kAvatarSource_None              = 0,
	kAvatarSource_Web               = 10,
	kAvatarSource_AddressBook       = 20,
    kAvatarSource_SilentContacts    = 30
};

@interface STUser : STDatabaseObject <NSCoding, NSCopying, YapDatabaseRelationshipNode>

/**
 * Creates a basic STUser with the minimum required properties.
 * All other properties should be set manually.
**/
- (id)initWithUUID:(NSString *)uuid
         networkID:(NSString *)networkID
               jid:(XMPPJID *)jid;

// This is key you would use to fetch the object from the database.
@property (nonatomic, copy, readonly) NSString *uuid;

@property (nonatomic, copy, readonly) XMPPJID  *jid;
@property (nonatomic, copy, readonly) NSString *networkID;     // index into SilentCircleNetworkInfo

@property (nonatomic, copy,   readonly) NSString   * avatarFileName;
@property (nonatomic, assign, readonly) AvatarSource avatarSource;      // @see setAvatarFileName:avatarSource:
@property (nonatomic, strong, readonly) NSDate     * avatarLastUpdated; // @see setAvatarFileName:avatarSource:

@property (nonatomic, assign, readwrite) BOOL hasPhone;
@property (nonatomic, assign, readwrite) BOOL canSendMedia;
@property (nonatomic, assign, readwrite) BOOL isSavedToSilentContacts;

@property (nonatomic, copy, readwrite) NSSet *publicKeyIDs;
@property (nonatomic, copy, readwrite) NSString *currentKeyID;

@property (nonatomic, copy, readwrite) NSString *activeDeviceID;

// Contact info
@property (nonatomic, copy, readwrite) NSString *email;
@property (nonatomic, copy, readwrite) NSArray *spNumbers;  // silent phone number(s)

// AB linking
@property (nonatomic, assign, readwrite) ABRecordID abRecordID;          // linked if not kABRecordInvalidID
@property (nonatomic, assign, readwrite) BOOL isAutomaticallyLinkedToAB; // our code created the link automatically

// SC version of properties
@property (nonatomic, copy, readwrite) NSString *sc_firstName;
@property (nonatomic, copy, readwrite) NSString *sc_lastName;
@property (nonatomic, copy, readwrite) NSString *sc_compositeName;
@property (nonatomic, copy, readwrite) NSString *sc_organization;
@property (nonatomic, copy, readwrite) NSString *sc_notes;

// AB version of properties
@property (nonatomic, copy, readwrite) NSString *ab_firstName;
@property (nonatomic, copy, readwrite) NSString *ab_lastName;
@property (nonatomic, copy, readwrite) NSString *ab_compositeName;
@property (nonatomic, copy, readwrite) NSString *ab_organization;
@property (nonatomic, copy, readwrite) NSString *ab_notes;

// webAPI version of properties
@property (nonatomic, copy, readwrite) NSString *web_firstName;
@property (nonatomic, copy, readwrite) NSString *web_lastName;
@property (nonatomic, copy, readwrite) NSString *web_compositeName;
@property (nonatomic, copy, readwrite) NSString *web_organization;
@property (nonatomic, copy, readwrite) NSString *web_avatarURL;
@property (nonatomic, copy, readwrite) NSString *web_hash;

// Location info
@property (nonatomic, strong, readwrite) CLLocation *lastLocation;

// Server sync properties
@property (nonatomic, strong, readwrite) NSDate *nextWebRefresh;
@property (nonatomic, assign, readwrite) BOOL awaitingReKeying;

// Timestamp
@property (nonatomic, strong, readwrite) NSDate *lastUpdated;

// Convenience properties
@property (nonatomic, readonly) BOOL isLocal;
@property (nonatomic, readonly) BOOL isRemote;
@property (nonatomic, readonly) BOOL isTempUser;          // returns uuid == nil

@property (nonatomic, readonly) NSString *firstName;      // extracted from sc, ab & web fields
@property (nonatomic, readonly) NSString *lastName;       // extracted from sc, ab & web fields
@property (nonatomic, readonly) NSString *compositeName;  // extracted from sc, ab & web fields
@property (nonatomic, readonly) NSString *organization;   // extracted from sc, ab & web fields
@property (nonatomic, readonly) NSString *notes;          // extracted from sc, ab & web fields

@property (nonatomic, readonly) NSString *initials;       // extracted from firstName & lastName
@property (nonatomic, readonly) NSString *displayName;    // extracted from firstName & lastName
@property (nonatomic, readonly) BOOL      hasExtendedDisplayName; // ?? what is this ??

// Atomic setters:

/**
 * The avatarFileName & avatarSource must be set together.
 * This method enforces this rule.
**/
- (void)setAvatarFileName:(NSString *)avatarFileName
             avatarSource:(AvatarSource)avatarSource;

// Copy methods:
// Use these to set otherwise readonly properties.

- (id)copyWithNewUUID:(NSString *)uuid;

- (id)copyWithNewJID:(XMPPJID *)jid networkID:(NSString *)networkID;

// JSON format

- (NSDictionary *)syncableJsonDictionary;

// Utility methods

+ (NSString *)displayNameForUsers:(NSArray *)users
                         maxWidth:(CGFloat)maxWidth
                   textAttributes:(NSDictionary *)textAttributes;

@end
