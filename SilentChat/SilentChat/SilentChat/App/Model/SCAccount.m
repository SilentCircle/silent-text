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

#import "AppConstants.h"

#import "SCAccount.h"

#import "SCPPServer.h"

#import "ServiceCredential.h"
#import "ServiceServer.h"
#import "NSString+URLEncoding.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

NSString *const kSCAccountEntity = @"SCAccount";
NSString *const kUsername      = @"username";
NSString *const kServerDomain  = @"serverDomain";
NSString *const kServerPort  = @"serverPort";
 




@interface SCAccount (PrimitiveAccessors)

- (NSString *) primitiveUsername;
- (void)    setPrimitiveUsername: (NSString *) username;

- (NSString *) primitiveServerDomain;
- (void)    setPrimitiveServerDomain: (NSString *) serverDomain;

- (int32_t)    primitiveServerPort;
- (void)    setPrimitiveServerPort: (int32_t) serverPort;

@end

@implementation SCAccount

@dynamic username;
@dynamic serverDomain;
@dynamic serverPort;

@dynamic password;
@dynamic passphraseMetaData;
@dynamic serviceName;
@dynamic serviceServer;
@dynamic jid;
@dynamic fullJID;
@dynamic accountDomain;

- (NSString *) debugDescription {
    
    NSString *description = [self description];
    NSString *ivars       = [NSString stringWithFormat: @"\n\tPassword: %@", self.password];
    
    return [description stringByAppendingString: ivars];
    
} // -debugDescription


- (void) setUsername: (NSString *) username {
    
    [self willChangeValueForKey: kUsername]; {
        
        XMPPJID *jid = [XMPPJID jidWithString: username];
        
        if (!jid.resource) {
            
            jid = [XMPPJID jidWithString: username resource: UIDevice.currentDevice.name];
        }
        self.primitiveUsername = jid.full;
    }
    [self  didChangeValueForKey: kUsername];
    
} // -setUsername:


- (void) setServerDomain: (NSString *) serverDomain {
    
    [self willChangeValueForKey: kServerDomain]; {
        
        // Repurposing the JID code to internationally canonicalize the server domain.
        // This should change to use the ICU StringPrep.
        XMPPJID *jid = [XMPPJID jidWithString: serverDomain];
        
        self.primitiveServerDomain = jid.domain;
    }
    [self  didChangeValueForKey: kServerDomain];
    
} // -setServerDomain::


- (NSString *) password {
    
    DDGTrace();
    
    ServiceCredential *sc = [ServiceCredential.alloc initWithService: self.serviceName];
    
    return sc.password;
    
} // -password


- (void) setPassword: (NSString *) password {
    
    DDGDesc(password);
    
    ServiceCredential *sc = [ServiceCredential.alloc initWithService: self.serviceName];

    [sc setUsername: self.username password: password];
    
} // -setPassword:


NSString *const kAccountPassphraseMetaDataFormat = @"%@.passphraseMetaData";

- (NSData *) passphraseMetaData {
    
    DDGTrace();
    
    ServiceCredential *sc = [ServiceCredential.alloc initWithService: 
                             [NSString stringWithFormat: kAccountPassphraseMetaDataFormat, self.serviceName]];
    return sc.data;
    
} // -passphraseMetaData


- (void) setPassphraseMetaData: (NSData *) passphraseMetaData {
    
    ServiceCredential *sc = [ServiceCredential.alloc initWithService: 
                             [NSString stringWithFormat: kAccountPassphraseMetaDataFormat, self.serviceName]];
    sc.data = passphraseMetaData;
    
} // -setPassphraseMetaData:


- (NSString *) serviceName {
    
    NSString *name = [[XMPPJID jidWithString: self.username] bare]; // Strip the JID resource.
    
    name = (self.serverDomain ?
            [NSString stringWithFormat: @"%@@%@", [name URLEncodedString], self.serverDomain] :
            [name URLEncodedString]);
    DDGDesc(name);
    
    return name;
    
} // -serviceName


- (ServiceServer *) serviceServer {
    
    ServiceServer *server = ServiceServer.new;
    
//    server.domain = self.serverDomain;
 //   server.port   = self.serverPort ? self.serverPort : kXMPPDefaultPort;
    server.credential = [ServiceCredential.alloc initWithService: self.serviceName];
    
    return server;
    
} // -serviceServer


- (XMPPJID *) jid {
    
    return [XMPPJID jidWithString: self.username];
    
} // -jid


- (XMPPJID *) fullJID {
    
    XMPPJID *jid = self.jid;
    
    if (jid.resource) {
        
        return jid;
    }
    return [XMPPJID jidWithString: jid.bare resource: UIDevice.currentDevice.name];
    
} // -fullJID


+ (NSString *) resource {
    
    return UIDevice.currentDevice.name;
    
} // +resource


- (NSString *) accountDomain {
    
    return kDefaultAccountDomain;
    
} // +accountDomain



- (BOOL) isEqualToAccount: (SCAccount *) account {
    
    BOOL notEqual = NO;
    
    notEqual |= ![[XMPPJID jidWithString: self.username] isEqualToJID: account.jid];
    
    if (self.serverDomain && ![self.serverDomain isEqualToString: kEmptyString]) {
        
        NSString *domain = [[XMPPJID jidWithString: self.serverDomain] domain]; // Returns the canonical domain name.
        
        notEqual |= domain ? ![domain isEqualToString: account.serverDomain] : (BOOL)account.serverDomain;
    }
    else {
        
        notEqual |= (BOOL)account.serverDomain;
    }
    if (self.serverPort && self.serverPort != account.serverPort) {
        
        notEqual |= self.serverPort != account.serverPort;
    }
    else {
        
        notEqual |= account.serverPort && account.serverPort != kXMPPDefaultPort;
    }
    return !notEqual;
    
} // -isEqualToAccount:


#pragma mark - NSManagedObject methods.


- (void) awakeFromInsert {
    
    [self setPrimitiveUsername:    [kDefaultAccountDomain stringByAppendingPathComponent: SCAccount.resource]];
    [self setPrimitiveServerDomain: kDefaultServerDomain];
    [self setPrimitiveServerPort: 0];
    
} // -awakeFromInsert


- (void) prepareForDeletion {
    
    ServiceCredential *sc = nil;

    sc = [ServiceCredential.alloc initWithService: 
          [NSString stringWithFormat: kAccountPassphraseMetaDataFormat, self.serviceName]];
    [sc deleteCredential];
    
    sc = [ServiceCredential.alloc initWithService: self.serviceName];
    [sc deleteCredential];

} // -prepareForDeletion

@end
