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
#import <SCCrypto/SCcrypto.h> 

#import "STDatabaseObject.h"


@interface STSymmetricKey : STDatabaseObject <NSCoding, NSCopying>

+ (id)keyWithThreadID:(NSString *)threadID
              creator:(NSString *)creator
           expireDate:(NSDate *)expireDate
           storageKey:(SCKeyContextRef)storageKey;

+ (id)keyWithString:(NSString *)inKeyJSON;

- (id)initWithUUID:(NSString *)inUUID
           keyJSON:(NSString *)inKeyJSON;


// This is key you would use to fetch the object from the database.
@property (nonatomic, copy, readonly) NSString * uuid;

@property (nonatomic, copy, readonly) NSString * keyJSON;

@property (nonatomic, assign, readwrite) BOOL isExpired;

@property (nonatomic, strong, readwrite) NSDate *lastUpdated;
@property (nonatomic, strong, readwrite) NSDate *recycleDate;   // local expire

// Convenience properties

@property (nonatomic, readonly) NSDictionary * keyDict; // parsed keyJSON (cached, thread-safe)

@property (nonatomic, readonly) NSString * threadID;   // extracted from keyJSON / keyDict
@property (nonatomic, readonly) NSDate   * startDate;  // extracted from keyJSON / keyDict
@property (nonatomic, readonly) NSDate   * expireDate; // extracted from keyJSON / keyDict

@end
