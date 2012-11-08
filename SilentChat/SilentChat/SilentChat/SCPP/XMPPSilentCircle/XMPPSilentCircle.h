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


#import <Foundation/Foundation.h>
#import "XMPP.h"
#import "AppConstants.h"
#import <SCimp.h>


@protocol XMPPSilentCircleStorage;

#define _XMPP_SILENT_CIRCLE_H


/**
 * This module implements the Silent Circle Instant Messaging Protocol (SCimp).
 * It can automatically encrypt / decrypt messages between peers.
**/
@interface XMPPSilentCircle : XMPPModule


- (id)initWithStorage:(id <XMPPSilentCircleStorage>)storage;
- (id)initWithStorage:(id <XMPPSilentCircleStorage>)storage dispatchQueue:(dispatch_queue_t)queue;

@property (nonatomic, strong, readonly) id <XMPPSilentCircleStorage> storage;


@property (nonatomic) SCimpCipherSuite scimpCipherSuite;
@property (nonatomic) SCimpSAS scimpSASMethod;

/**
 * A set of JIDs, for which outgoing messages targeted at JIDs within this set will be encrypted.
 * This is the "whitelist" set for encryption.
 *
 * The following rules apply when matching JIDs:
 * 
 * 1. If the JID is of the form <user@domain.tld/resource>, only this particular JID matches.
 * 2. If the JID is of the form <user@domain.tld>, any resource matches.
 * 3. If the JID is of the form <domain.tld>, any user or resource matches.
 * 4. If the JID is of the form <wildcard>, anything matches.
 * 
 * For example:
 *
 * If the set was {"alice@domain.com/home"}, then "alice@domain.com/work" would not match.
 * If the set was {"alice@domain.com"}, then "alice@domain.com/work" would match.
 * If the set was {"domain.com"}, then "alice@domain.com/work" would match.
 * If the set was {"*"}, then "alice@domain.com/work" would match.
 *
 * 
 * Use [XMPPSilentCirle wildcardJID] to obtain the special wildcard "JID".
 * For example, if you want to encrypt all outgoing messages, then do this:
 *
 * xmppSilentCircle.jidsToEncrypt = [NSSet setWithObject:[XMPPSilentCircle wildcardJID]];
 * 
 * Obviously the two sets jidsToEncrypt and jidsNotToEncrypt should not intersect.
 * If you set this property, and an object in this set intersects with the current jidsNotToEncrypt set,
 * then the intersection is automatically removed from jidsNotToEncrypt.
 * In other words, in the event of a conflict, the most recent operation takes precedence.
 *
 * When matching, the strongest match takes precedence.
 * That is, if a match is found in both jidsToEncrypt and jidsNotToEncrypt, the strongest match wins.
 * 
 * Example 1:
 * 
 * jidsToEncrypt    = {"alice@domain.com/home"}
 * jidsNotToEncrypt = {"alice@domain.com"}
 * 
 * A message to "alice@domain.com/home" would be encrypted.
 * A message to "alice@domain.com/work" would not be encrypted.
 * 
 * Example 2:
 * 
 * jidsToEncrypt    = {"*"}
 * jidsNotToEncrypt = {"domain.com"}
 * 
 * A message to "alice@domain.com/home" would not be encrypted.
 * A message to "bob@company.com/work" would be encrypted.
 * 
 * Example 3:
 * 
 * jidsToEncrypt    = {"*", "bob@company.com"}
 * jidsNotToEncrypt = {"company.com"}
 * 
 * A message to "alice@domain.com/home" would be encrypted.
 * A message to "bob@company.com/work" would be encrypted.
 * A message to "sue@company.com/work" would not be encrypted.
 * 
 * If a match is not found in either jidsToEncrypt or jidsNotToEncrypt, it is not encrypted.
 * It is recommended you use the wildcard in one of the sets to explicitly specify your desired default operation.
 * 
 * @see jidsNotToEncrypt
**/
@property (atomic, copy, readwrite) NSSet *jidsToEncrypt;

/**
 * A set of JIDs, for which outgoing messages targeted at JIDs within this set will not be encrypted.
 * This is the "blacklist" set for encryption.
 *
 * See the documentation for jidsToEncrypt for a full discussion.
 * 
 * @see jidsToEncrypt
**/
@property (atomic, copy, readwrite) NSSet *jidsNotToEncrypt;

/**
 * These methods allow you to add or remove JIDs from the jidsToEncrypt set in one atomic operation.
**/
- (void)addToJidsToEncrypt:(NSSet *)unionSet;
- (void)removeFromJidsToEncrypt:(NSSet *)minusSet;

/**
 * These methods allow you to add or remove JIDs from the jidsNotToEncrypt set in one atomic operation.
**/
- (void)addToJidsNotToEncrypt:(NSSet *)unionSet;
- (void)removeFromJidsNotToEncrypt:(NSSet *)minusSet;

/**
 * Whether or not the module has an active secure context for communication with the remote jid.
 * If this method returns no, then a secure context will either need to be restored or
 * a new secure context will need to be negotiated.
 * 
 * The given remoteJid must be a full jid (i.e. jid must contain a resource).
**/
- (BOOL)hasSecureContextForJid:(XMPPJID *)remoteJid;
 
/* get keying information for the remote JID */

extern NSString  *const kSCIMPInfoCipherSuite;
extern NSString  *const kSCIMPInfoVersion;
extern NSString  *const kSCIMPInfoSASMethod;
extern NSString  *const kSCIMPInfoSAS;
extern NSString  *const kSCIMPInfoCSMatch;
extern NSString  *const kSCIMPInfoHasCS;

- (NSDictionary*)secureContextInfoForJid:(XMPPJID *)remoteJid;

/* Restart the keying process for the remote JID */
- (void)rekeySecureContextForJid:(XMPPJID *)remoteJid;

/* in reply to the  sharedSecretMismatch delagate we can make this call to update the shared secret for the remote JID */
- (void)acceptSharedSecretForJid:(XMPPJID *)remoteJid;

 
+ (void)removeSecureContextForJid:(XMPPJID *)remoteJid;

/**
 * Returns a special object that acts as a wildcard (catch all) for use in jidsToEncrypt or jidsNotToEncrypt.
**/
+ (id)wildcardJID;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPSilentCircleStorage
@required

/**
 * In order to save and restore state, a key is used to encrypt the saved state,
 * and later used to decrypt saved state in order to restore it.
 * 
 * If a key exists for this combination of JIDs, it should be returned.
 * Otherwise, a new key is to be generated, stored for this combination of JIDs, and then returned.
**/
- (NSData *)stateKeyForLocalJid:(XMPPJID *)myJid remoteJid:(XMPPJID *)theirJid;

/**
 * Instructs the storage protocol to save session state data.
 * This is data coming from SCimpSaveState.
**/
- (void)saveState:(NSData *)state forLocalJid:(XMPPJID *)myJid remoteJid:(XMPPJID *)theirJid;

/**
 * Instructs the storage protocol to retrieve previously saved state data.
 * This is data going to SCimpRestoreState.
**/
- (NSData *)restoreStateForLocalJid:(XMPPJID *)myJid remoteJid:(XMPPJID *)theirJid;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol XMPPSilentCircleDelegate
@optional

/**
 * 
**/
- (void)xmppSilentCircle:(XMPPSilentCircle *)sender willEstablishSecureContext:(XMPPJID *)remoteJid;

/**
 * This method is invoked after a secure context has been negotiated, or during rekeying.
 * It is also invoked after a stored secured context has been restored.
**/
- (void)xmppSilentCircle:(XMPPSilentCircle *)sender didEstablishSecureContext:(XMPPJID *)remoteJid;
 
/**
 * protocolWarning  indicates that the other side did not respond to estalishing secure context or the 
 other side responded out of order, depending on the error, the appropriate action is probably to rekey.
 **/

- (void)xmppSilentCircle:(XMPPSilentCircle *)sender protocolWarning:(XMPPJID *)remoteJid withMessage:(XMPPMessage *)message error:(SCLError)error;

/**
 * protocolError  indicates that the SCIMP was unable to make a secure context
 **/

- (void)xmppSilentCircle:(XMPPSilentCircle *)sender protocolError:(XMPPJID *)remoteJid withMessage:(XMPPMessage *)message error:(SCLError)error;

/**
 * protocolStateChange  used to track the state change in a secure context
 **/

- (void)xmppSilentCircle:(XMPPSilentCircle *)sender protocolDidChangeState:(XMPPJID *)remoteJid state:(SCimpState)state;


 

@end
