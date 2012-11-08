/*
Copyright © 2012, Silent Circle
All rights reserved.

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
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import <UIKit/UIKit.h>
#import "DDGApp+Block.h"

#import "SilentTextStrings.h"

@class SCAccount;
@class Preferences;
@class XMPPServer;
@class StorageCipher;
@class ConversationManager;
@class DDGQueue;
@class ConversationViewController;
@class GeoTracking;
@class SCAddressBook;
@class SCPasscodeManager;
@class Reachability;
@class XMPPJID;

// Error Domain
extern NSString *const kSCErrorDomain;

@interface App : DDGApp <App>

@property (strong, nonatomic) IBOutlet UIWindow *window;
@property (strong, nonatomic) IBOutlet UIViewController *rootViewController;

@property (strong, nonatomic, readonly) SCAccount *currentAccount;
@property (strong, nonatomic, readonly) XMPPJID *currentJID;
@property (strong, nonatomic) NSManagedObjectID *currentAccountID;
@property (strong, nonatomic) Preferences *preferences;
@property (strong, nonatomic) XMPPServer *xmppServer;
@property (strong, nonatomic) ConversationManager *conversationManager;
@property (strong, nonatomic) DDGQueue *heartbeatQueue;
 
@property (strong, nonatomic) ConversationViewController *conversationViewController;

@property (strong, nonatomic) NSString *pushToken;

@property (strong, nonatomic) GeoTracking *geoTracking;
@property (strong, nonatomic) SCAddressBook *addressBook;
@property (strong, nonatomic) SCPasscodeManager *passcodeManager;
@property (strong, nonatomic) Reachability* reachability;

- (SCAccount *) useNewAccount: (SCAccount *) account;
- (void) deleteCurrentAccount;
 
- (NSData *) provisonCert;
- (NSData *) xmppCert;

// <App> methods.
@property (getter = isQueueEmpty, readonly) BOOL queueEmpty;

+ (App *) sharedApp;

- (void) resetAccounts;

@end
