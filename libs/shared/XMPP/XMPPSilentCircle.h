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

#import <Foundation/Foundation.h>
#import "XMPP.h"
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
- (void) clearCaches;
 
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
