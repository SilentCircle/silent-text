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
#import "STUser.h"


extern NSString *const kProvisionInfoKey_provisionCode;
extern NSString *const kProvisionInfoKey_deviceName;
extern NSString *const kProvisionInfoKey_receipt;

@interface STLocalUser : STUser

//
// Standard init methods
//

- (instancetype)initWithUUID:(NSString *)uuid
                         jid:(XMPPJID *)jid
                   networkID:(NSString *)networkID
                xmppResource:(NSString *)xmppResource
                xmppPassword:(NSString *)xmppPassword
                      apiKey:(NSString *)apiKey
                canSendMedia:(BOOL)canSendMedia
                   isEnabled:(BOOL)isEnabled;

- (instancetype)initWithUUID:(NSString *)inUUID
                         jid:(XMPPJID *)inJid
                   networkID:(NSString *)inNetworkID
                provisonInfo:(NSDictionary *)inProvisonInfo;

//
// Init methods for upgrading an existing STUser to a STLocalUser
//

- (instancetype)initWithRemoteUser:(STUser *)remoteUser
                      xmppResource:(NSString *)xmppResource
                      xmppPassword:(NSString *)xmppPassword
                            apiKey:(NSString *)apiKey
                      canSendMedia:(BOOL)canSendMedia
                         isEnabled:(BOOL)isEnabled;

- (instancetype)initWithRemoteUser:(STUser *)remoteUser
                      provisonInfo:(NSDictionary *)inProvisonInfo;


// The notificationUUID is used for tracking local notifcations for our user accounts.
// We don't use the uuid beacuse we want to prevent leaking the uuid of our accounts out to the IOS world.
@property (nonatomic, copy, readwrite) NSString *notificationUUID;

@property (nonatomic, copy, readonly) NSString *xmppResource;  // for JID
@property (nonatomic, copy, readonly) NSString *xmppPassword;
@property (nonatomic, copy, readonly) NSString *apiKey;

@property (nonatomic, copy, readonly) NSDictionary *provisonInfo; // use until user has been setup

@property (nonatomic, copy, readwrite) NSString *pushToken;

@property (nonatomic, assign, readwrite) BOOL isEnabled;

@property (nonatomic, readonly) NSString *oldApiKey;
@property (nonatomic, readonly) NSString *oldDeviceID;

// Subscription info
@property (nonatomic, strong, readwrite) NSDate *subscriptionExpireDate;
@property (nonatomic, assign, readwrite) BOOL subscriptionHasExpired;
@property (nonatomic, assign, readwrite) BOOL subscriptionAutoRenews;
@property (nonatomic, assign, readwrite) BOOL handlesOwnBilling; // see WEB-1227

// Server sync properties
@property (nonatomic, strong, readwrite) NSDate *nextKeyGeneration;
@property (nonatomic, assign, readwrite) BOOL needsKeyGeneration;
@property (nonatomic, assign, readwrite) BOOL needsRegisterPushToken;
@property (nonatomic, assign, readwrite) BOOL needsDeprovisionUser;      // automatically unregisters push token

// Convenience properties
@property (nonatomic, readonly) NSString *deviceID; // same as xmppResource
@property (nonatomic, readonly) BOOL isActivated;


@property (nonatomic, readonly) NSString *appStoreHash; // hash of uuid

/**
 * For deactivating / reactivating.
**/
- (id)deactivatedCopy;
- (id)copyWithXmppPassword:(NSString *)xmppPassword
                    apiKey:(NSString *)apiKey
              canSendMedia:(BOOL)canSendMedia
                 isEnabled:(BOOL)isEnabled;

- (id)copyWithNewProvisionInfo:(NSDictionary *)inProvisonInfo;

@end
