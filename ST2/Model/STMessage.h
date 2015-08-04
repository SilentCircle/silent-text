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
#import "Siren.h"

extern NSString *const kSigInfo_keyFound;
extern NSString *const kSigInfo_owner;
extern NSString *const kSigInfo_expireDate;
extern NSString *const kSigInfo_calculatedHash;
extern NSString *const kSigInfo_valid;



@interface STMessage : STDatabaseObject <NSCoding, NSCopying>

- (id)initWithUUID:(NSString *)uuid
    conversationId:(NSString *)conversationID
            userId:(NSString *)userId
              from:(XMPPJID *)from
                to:(XMPPJID *)to
         withSiren:(Siren *)siren
         timestamp:(NSDate *)timestamp
        isOutgoing:(BOOL)isOutgoing;

/**
 * To fetch the corresponding objects from the database:
 *
 * message = [transaction objectForKey:uuid
 *                        inCollection:conversationId
 *
 * conversation = [transaction objectForKey:conversationId
 *                             inCollection:userId];
 *
 * user = [transaction objectForKey:userId
 *                     inCollection:kSCCollection_STUsers];
**/

@property (nonatomic, copy, readonly) NSString * uuid;
@property (nonatomic, copy, readonly) NSString * conversationId;
@property (nonatomic, copy, readonly) NSString * userId;

@property (nonatomic, strong, readonly) Siren    * siren;
@property (nonatomic, strong, readonly) XMPPJID  * from;
@property (nonatomic, strong, readonly) XMPPJID  * to;
@property (nonatomic, strong, readonly) NSDate   * timestamp;
@property (nonatomic, assign, readonly) BOOL       isOutgoing;

@property (nonatomic, assign) BOOL hasThumbnail;
@property (nonatomic, assign) BOOL isRead;

@property (nonatomic, strong) NSDate  * sendDate;
@property (nonatomic, strong) NSDate  * rcvDate;
@property (nonatomic, strong) NSDate  * shredDate;
@property (nonatomic, strong) NSDate  * serverAckDate;

@property (nonatomic, assign) BOOL isVerified;
@property (nonatomic, assign) BOOL needsReSend;
@property (nonatomic, assign) BOOL needsUpload;
@property (nonatomic, assign) BOOL needsDownload;
@property (nonatomic, assign) BOOL needsEncrypting;
@property (nonatomic, assign) BOOL ignored;

@property (nonatomic, strong) NSError      * errorInfo;
@property (nonatomic, copy)   NSDictionary * signatureInfo;
@property (nonatomic, copy)   NSDictionary * statusMessage;

// Synthetic ivars

@property (nonatomic, readonly) NSString *scloudID;  // Same as siren.cloudLocator

@property (nonatomic, readonly) BOOL isStatusMessage;
@property (nonatomic, readonly) BOOL isShredable;
@property (nonatomic, readonly) BOOL hasGeo;

@property (nonatomic, readonly) BOOL isSpecialMessage;
@property (nonatomic, readonly) NSString * specialMessageText;

// Changing readonly properties

- (STMessage *)copyWithNewSiren:(Siren *)updatedSiren;

// Comparison

- (NSComparisonResult)compareByTimestamp:(STMessage *)another;

@end
