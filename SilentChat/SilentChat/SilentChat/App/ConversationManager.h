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
//  ConversationManager.h
//  SilentText
//

#import <Foundation/Foundation.h>

#import "Conversation.h"

#import "XMPPFramework.h"
#import "XMPPSilentCircle.h"

@class StorageCipher;
@class Siren;
@class Missive;
@protocol ConversationManagerDelegate ;

@interface ConversationManager : NSObject 
<ConversationDelegate, 
XMPPSilentCircleDelegate, XMPPSilentCircleStorage,
XMPPStreamDelegate>

@property (strong,  nonatomic) id<ConversationManagerDelegate> delegate;
 
@property (strong, nonatomic) StorageCipher *storageCipher;
@property (strong, nonatomic, readonly) NSArray *conversations;

@property (strong, nonatomic, readonly) NSString *pushIQid;
@property (strong, nonatomic, readonly) NSString *timeIQid;

@property (atomic, readonly) int totalUnread;


- (Conversation *) conversationForLocalJid: (XMPPJID *) myJid remoteJid: (XMPPJID *) theirJid;

-(void)sendPingSirenMessageToRemoteJID: (XMPPJID *) remoteJID;

-(void)sendRequestBurnMessageToRemoteJID: (XMPPJID *) remoteJID forMessage:(NSString*) messageID;

-(void)sendReKeyToRemoteJID: (XMPPJID *) remoteJID;

-(NSDictionary*)secureContextInfoForJid: (XMPPJID *) remoteJID;

- (BOOL) conversationForLocalJidExists: (XMPPJID *) myJid remoteJid: (XMPPJID *) theirJid;

- (void) resetScimpState:(XMPPJID *) myJid remoteJid: (XMPPJID *) theirJid;

- (void) clearConversation:(XMPPJID *) myJid remoteJid: (XMPPJID *) theirJid;

- (void) deleteMissiveFromConversation:(XMPPJID *) myJid remoteJid: (XMPPJID *) theirJid missive:(Missive*) missive;

- (void) deleteCachedScloudObjects:(Conversation *)conversation;

- (void) deleteState:  (XMPPJID *) myJid remoteJid: (XMPPJID *) theirJid;

-(NSArray*) missivesWithScloud:(Conversation *)conversation;

- (NSArray *) JIDs;

- (int) totalMessagesNotFrom:(XMPPJID *) remoteJid;

/**
 * ConversationManager uses a multicast delegate.
 * This allows one to add multiple delegates to a single XMPPStream instance,
 * which makes it easier to separate various components and extensions.
 *
 * For example, if you were implementing two different custom extensions on top of XMPP,
 * you could put them in separate classes, and simply add each as a delegate.
 **/
- (void)addDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate delegateQueue:(dispatch_queue_t)delegateQueue;
- (void)removeDelegate:(id)delegate;

@end

@protocol ConversationManagerDelegate <NSObject>
@optional

- (void)conversationmanager:(ConversationManager *)sender didUpdateRemoteJID:(XMPPJID *)remoteJID;

- (void)conversationmanager:(ConversationManager *)sender didReceiveSirenFrom:(XMPPJID *)from siren:(Siren *)siren;

- (void)conversationmanager:(ConversationManager *)sender
             didChangeState:(XMPPJID *)theirJid
                   newState:(ConversationState) state;

@end
