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


#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "RosterManager.h"

#import "XMPPJID.h"
#import "XMPPUserCoreDataStorageObject.h"
#import "SCPPServer.h"
#import "App.h"

#import "SCAccount.h"

#import "NSManagedObjectContext+DDGManagedObjectContext.h"
#import "XMPPJID+AddressBook.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

@implementation RosterManager

+ (XMPPJID *) jidForUsername: (NSString *) username {
    
    return [XMPPJID jidWithUser: username domain: kDefaultAccountDomain resource: nil];
    
} // +jidForUsername:


+ (id<XMPPUser>) userForJIDStr: (NSString *) jidStr {
    
    if (jidStr) {
        
        NSArray *users = nil;
        NSManagedObjectContext *moc = App.sharedApp.xmppServer.mocRoster;
        
        NSPredicate *p = [NSPredicate predicateWithFormat: @"%K == %@", 
                          @"jidStr", [[XMPPJID jidWithString: jidStr] bare]];
        
        users = [moc fetchObjectsForEntity: @"XMPPUserCoreDataStorageObject" predicate: p];
        
        DDGDesc(users);
        
        return users.lastObject;
    }
    return nil;
    
} // +userForJIDStr:


+ (NSString *) displayNameForJID: (NSString *) jid {
    
    NSString *displayName =  [[XMPPJID jidWithString: jid] addressBookName];

    if (!displayName || [displayName isEqualToString: kEmptyString]) {

        id<XMPPUser> xmppUser = [self userForJIDStr: jid];
        
        displayName = xmppUser.nickname;
        displayName = displayName && ![displayName isEqualToString: kEmptyString] ? displayName : [xmppUser.jid user];
        displayName = displayName && ![displayName isEqualToString: kEmptyString] ? displayName : [[XMPPJID jidWithString: jid] user];
    }
    return displayName;
    
} // +displayNameForJID:

@end
