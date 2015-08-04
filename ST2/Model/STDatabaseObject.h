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

/**
 * STDatabaseObject is the base class for all model objects in Silent Text.
 * That is, it's the base class for all objects that get stored in the database.
 * 
 * It adds the ability to make any object immutable, accomplished via the makeImmutable method.
 * We invoke this method automatically when:
 * - we put an object into the database
 * - we deserialize an object from the database
 * 
 * In other words, when an object goes into the databse it becomes immutable.
 * And any object fetched from the database is immutable.
 * 
 * We do this for a variety of reasons.
 * Thread safety is the primary reason:
 * https://github.com/yapstudios/YapDatabase/wiki/Thread-Safety
 *
 * But YapDatabase also supports some cool performance improvements if one uses immutable objects:
 * https://github.com/yapstudios/YapDatabase/wiki/Object-Policy
 * 
 * In addition to this, STDatabaseObject supports monitoring what properties on an object have been changed.
 * We hook into this mechanism for various purposes, often to simplify change tracking.
**/



@interface STDatabaseObject : NSObject <NSCopying>

#pragma mark Class configuration

+ (NSMutableSet *)monitoredProperties;
@property (nonatomic, readonly) NSSet *monitoredProperties;

+ (NSMutableDictionary *)mappings_localKeyToCloudKey;
@property (nonatomic, readonly) NSDictionary *mappings_localKeyToCloudKey;

+ (NSMutableDictionary *)mappings_cloudKeyToLocalKey;
@property (nonatomic, readonly) NSDictionary *mappings_cloudKeyToLocalKey;

+ (BOOL)storesOriginalCloudValues;


#pragma mark Immutability

@property (nonatomic, readonly) BOOL isImmutable;

- (void)makeImmutable;

- (NSException *)immutableExceptionForKey:(NSString *)key;


#pragma mark Monitoring (local)

@property (nonatomic, readonly) NSSet *changedProperties;
@property (nonatomic, readonly) BOOL hasChangedProperties;

- (void)clearChangedProperties;


#pragma mark Monitoring (cloud)

@property (nonatomic, readonly) NSSet *allCloudProperties;

@property (nonatomic, readonly) NSSet *changedCloudProperties;
@property (nonatomic, readonly) BOOL hasChangedCloudProperties;

@property (nonatomic, readonly) NSDictionary *originalCloudValues;


#pragma mark Getters & Setters (cloud)

- (NSString *)cloudKeyForLocalKey:(NSString *)localKey;
- (NSString *)localKeyForCloudKey:(NSString *)cloudKey;

- (id)cloudValueForCloudKey:(NSString *)key;
- (id)cloudValueForLocalKey:(NSString *)key;

- (id)localValueForCloudKey:(NSString *)key;
- (id)localValueForLocalKey:(NSString *)key;

- (void)setLocalValueFromCloudValue:(id)cloudValue forCloudKey:(NSString *)cloudKey;

/**
 * You can use this macro WITHIN SUBCLASSES to fetch the CloudKey for a given property.
 * For example, say your class is configured with the following mappings_localKeyToCloudKey:
 * @{ @"uuid" : @"uuid"
 *    @"foo"  : @"bar"
 * }
 *
 * Then:
 * - CloudKey(uuid) => [self.mappings_localKeyToCloudKey objectForKey:@"uuid"] => @"uuid"
 * - CloudKey(foo)  => [self.mappings_localKeyToCloudKey objectForKey:@"foo"]  => @"bar"
 *
 * If using Apple's CloudKit framework,
 * then this macro returns the name of the corresponding property within the CKRecord.
**/
#define CloudKey(ivar) [self.mappings_localKeyToCloudKey objectForKey:@"" # ivar]
//    translation  ==> [self.mappings_localKeyToCloudKey objectForKey:@"ivar"]

@end
