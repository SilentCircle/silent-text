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
#import "STDatabaseObject.h"

@class XMPPJID;
@class SCimpWrapper;

@interface SCimpSnapshot : STDatabaseObject <NSCoding, NSCopying>

- (id)initWithSCimpWrapper:(SCimpWrapper *)scimpWrapper ctx:(NSData *)ctxSnapshotData;

// This is key you would use to fetch the object from the database.
@property (nonatomic, copy, readonly) NSString *uuid;

@property (nonatomic, copy, readonly) NSString *conversationID;
@property (nonatomic, copy, readonly) NSString *threadID;

@property (nonatomic, copy, readonly) XMPPJID *localJID;
@property (nonatomic, copy, readonly) XMPPJID *remoteJID;

@property (nonatomic, assign, readonly) SCLError protocolError;

@property (nonatomic, assign, readonly) BOOL isVerified;
@property (nonatomic, assign, readonly) BOOL awaitingReKeying;

@property (nonatomic, copy, readonly) NSData *ctx;           // Archived scimpCtx
@property (nonatomic, copy, readonly) NSDictionary *ctxInfo; // Uses keys kSCimpInfoX (see SCimpWrapper.h)

@property (nonatomic, strong, readonly) NSDate *lastUpdated;


// Convenience methods (extracted from ctxInfo)

@property (nonatomic, readonly) SCimpCipherSuite cipherSuite;
@property (nonatomic, readonly) SCimpSAS sasMethod;

@property (nonatomic, readonly) SCimpMethod protocolMethod;
@property (nonatomic, readonly) SCimpState protocolState;

@property (nonatomic, readonly) NSString *protocolMethodString;
@property (nonatomic, readonly) NSString *protocolStateString;

@property (nonatomic, readonly) NSString *sasPhrase;
@property (nonatomic, readonly) NSDate *keyedDate;

@property (nonatomic, readonly) BOOL isReady; // isKeyed

@property (nonatomic, readonly) NSString *protocolErrorString;

@end
 
