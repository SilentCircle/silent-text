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


@interface STPublicKey : STDatabaseObject <NSCoding, NSCopying>
 
+ (id)privateKeyWithOwner:(NSString *)owner
                   userID:(NSString *)userID
               expireDate:(NSDate *)expireDate
               storageKey:(SCKeyContextRef)storageKey
                 keySuite:(SCKeySuite)keySuite;

+ (id)keyWithJSON:(NSString *)keyJSON
		   userID:(NSString *)userID; // Does this create a public or private key ?

- (id)initWithUUID:(NSString *)inUUID
            userID:(NSString *)inUserID
           keyJSON:(NSString *)inKeyJSON
      isPrivateKey:(BOOL)inPrivateKey;

@property (nonatomic, copy, readonly) NSString * uuid;
@property (nonatomic, copy, readonly) NSString * userID;

@property (nonatomic, copy, readonly) NSString * keyJSON;

@property (nonatomic, assign, readonly) BOOL isPrivateKey;

@property (nonatomic, assign, readwrite) BOOL isExpired;
@property (nonatomic, assign, readwrite) BOOL continuityVerified;

// Server sync properties

@property (nonatomic, strong, readwrite) NSDate *serverUploadDate;
@property (nonatomic, strong, readwrite) NSDate *serverDeleteDate;
@property (nonatomic, assign, readwrite) BOOL needsServerDelete;

// Extracted info from parsed keyJSON

@property (nonatomic, strong, readonly) NSDictionary *keyDict; // Parsed keyJSON

@property (nonatomic, readonly) NSString * owner;
@property (nonatomic, readonly) NSDate   * startDate;
@property (nonatomic, readonly) NSDate   * expireDate;

// Sorting

/**
 * Standard compare algorithm:
 * 
 * 1.) compare by start date
 * 2.) compare by end date
**/
- (NSComparisonResult)compare:(STPublicKey *)another;

/**
 * Use this method to determine the current key from a list of keys.
 * This method should be used EVERYWHERE when the currentKey is to be chosen.
 * 
 * It implements the "standard-agreed-upon-also-used-by-server-and-other-clients" algorithm.
**/
+ (STPublicKey *)currentKeyFromKeys:(NSArray *)keys;

@end
