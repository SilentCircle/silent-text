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

#import "STDatabaseObject.h"
#import "XMPPJID.h"
#import "XMPPJIDSet.h"
//#import "SCimp.h"


@interface STConversation : STDatabaseObject <NSCoding, NSCopying>

- (id)initAsNewMessageWithUUID:(NSString *)uuid userId:(NSString *)userId;

- (id)initWithUUID:(NSString *)uuid
       localUserID:(NSString *)userId
          localJID:(XMPPJID *)localJID
		 remoteJID:(XMPPJID *)remoteJID;

- (id)initWithUUID:(NSString *)uuid
       localUserID:(NSString *)localUserID
          localJID:(XMPPJID *)localJID
          threadID:(NSString *)threadID;

/**
 * To fetch the corresponding objects from the database:
 *
 * conversation = [transaction objectForKey:uuid
 *                             inCollection:userId];
 *
 * user = [transaction objectForKey:userId
 *                     inCollection:kSCCollection_STUsers];
**/

@property (nonatomic, copy, readonly) NSString *uuid;
@property (nonatomic, copy, readonly) NSString *userId;

@property (nonatomic, copy, readwrite) NSSet *scimpStateIDs;

// Basic State
@property (nonatomic, assign, readonly)  BOOL isMulticast;
@property (nonatomic, assign, readwrite) BOOL isNewMessage;
@property (nonatomic, assign, readwrite) BOOL isFakeStream;
@property (nonatomic, assign, readwrite) BOOL hidden;

// Configuration
@property (nonatomic, assign, readwrite) BOOL     fyeo;
@property (nonatomic, assign, readwrite) BOOL     shouldBurn;
@property (nonatomic, assign, readwrite) uint32_t shredAfter;
@property (nonatomic, assign, readwrite) BOOL     sendReceipts;
@property (nonatomic, strong, readwrite) NSDate * notificationDate;  // dont pester me with alerts till
@property (nonatomic, copy,   readwrite) NSDate * trackUntil;        // use this to set tracking

// For tracking delivered messages
@property (nonatomic, strong, readwrite) NSDate   * mostRecentDeliveredTimestamp;
@property (nonatomic, copy,   readwrite) NSString * mostRecentDeliveredMessageID;

// For standard messages
@property (nonatomic, copy, readwrite)  XMPPJID * remoteJid;
@property (nonatomic, copy, readwrite)  XMPPJID * localJid;

// For multicast messages
@property (nonatomic, copy, readwrite) XMPPJIDSet * multicastJidSet;
@property (nonatomic, copy, readwrite) NSString   * keyLocator;
@property (nonatomic, copy, readwrite) NSString   * threadID;
@property (nonatomic, copy, readwrite) NSString   * title;

// Conversation capabilities
@property (nonatomic, copy, readwrite) NSDictionary * capabilities; // ???

// This property is used to determine the sort order for the conversations in the tableView.
@property (nonatomic, strong, readwrite) NSDate *lastUpdated;

// Synthetic ivars
@property (nonatomic, assign, readonly) BOOL tracking;


- (NSComparisonResult)compareByLastUpdated:(STConversation *)another;

@end
