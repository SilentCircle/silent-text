/*
Copyright © 2012-2013, Silent Circle, LLC.  All rights reserved.

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
//
//  SCAccount.h
//  SilentChat
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "XMPPFramework.h"

@class ServiceCredential;

extern NSString *const kDefaultAccountDomain;

/*
 
 This Account object manages server information, usernames and secure keychain storage for passwords and 
 storage passphrase metadata.
 
 Currently, the default values for this class are:
 
 -username = @"silentcircle.org/" + Account.resource.
 -serverDomain = @"testfire.silentcircle.org"
 -serverPort = 0
 
 */

//@class ServiceServer;

extern NSString *const kSCAccountEntity;
extern NSString *const kUsername;
extern NSString *const kServerDomain;
extern NSString *const kServerPort;

@interface SCAccount : NSManagedObject

@property (strong, nonatomic) NSString * username;     // A canonical full JabberID string.
@property (strong, nonatomic) NSString * serverDomain; // A canonical server domain name.
@property (nonatomic) int32_t serverPort;

// Synthetic ivars.
@property (strong, nonatomic) NSString * password;
@property (strong, nonatomic) NSData   * passphraseMetaData;
@property (strong, nonatomic, readonly) NSString * accountDomain;
@property (strong, nonatomic, readonly) NSString * serviceName;
@property (strong, nonatomic, readonly) XMPPJID * jid;
@property (strong, nonatomic, readonly) XMPPJID * fullJID;

@property (strong, nonatomic)              ServiceCredential *credential;

+ (NSString *) resource;

- (BOOL) isEqualToAccount: (SCAccount *) account;

@end
