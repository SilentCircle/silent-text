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

#import "XMPPStreamManagement.h"
#import "YapDatabase.h"
#import "STLocalUser.h"
#import "STConversation.h"
#import "STMessage.h"
#import "XplatformUI.h"


typedef NS_ENUM(NSInteger, MessageStream_State) {
	
    MessageStream_State_Disconnected = 0,
    MessageStream_State_Connecting,
    MessageStream_State_Connected,
    MessageStream_State_Error
};

extern NSString *const MessageStreamDidChangeStateNotification;
extern NSString *const kMessageStreamUserJidKey;
extern NSString *const kMessageStreamUserUUIDKey;
extern NSString *const kMessageStreamStateKey;
extern NSString *const kMessageStreamErrorKey;


@class Siren;
@class STMessage;
@class STUser;
@class XMPPJID;
@class XMPPJIDSet;

@interface MessageStream : NSObject <XMPPStreamManagementStorage>

- (id)initWithUser:(STLocalUser *)inUser;

@property (nonatomic, strong, readonly) XMPPJID *localJID;
@property (nonatomic, strong, readonly) NSString *localUserID;

@property (atomic, readonly) NSString *connectedHostName;
@property (atomic, readonly) uint16_t connectedHostPort;

@property (atomic, readonly) MessageStream_State state;

/**
 * If the state is MessageStream_State_Error,
 * then this string will contain a reason for the error.
**/
@property (atomic, readonly) NSString *errorString;

#pragma mark State

/**
 * Attempts to connect the message stream, if it is not already connected/connecting.
 * This method is thread-safe (as is the entire class).
**/
- (void)connect;

/**
 * Disconnects the message stream, if it is not already disconnected.
 * This method is thread-safe (as is the entire class).
**/
- (void)disconnect;

/**
 * Disconnects the message strea, and tears down everything internally to allow the instance to be deallocated.
 * Once killed, the instance ceases to function.
 * 
 * This method is thread-safe (as is the entire class).
**/
- (void)disconnectAndKill;

/**
 * Returns whether or not the message stream is currently connected.
 *
 * Connected means the xmppStream is connected & authenticated.
 * In other words, "connected" we're ready to send & receive stanzas over the communications channel (xmpp).
 * 
 * This method is thread-safe (as is the entire class).
**/
- (BOOL)isConnected;

/**
 * Returns whether or not the message stream is currently connecting.
 * 
 * Connected means the xmppStream is connected & authenticated.
 * In other words, "connected" we're ready to send & receive stanzas over the communications channel (xmpp).
 * 
 * So connecting is all the steps prior to this.
 * (SRV resolving, TCP handshake, XMPP handshake, XMPP authentication, stream management, etc)
 * 
 * This method is thread-safe (as is the entire class).
**/
- (BOOL)isConnecting;

#pragma mark Send Siren

/**
 * Use this method when creating a new conversation.
 * That is, when the user chooses to create a new conversation, and chooses a single recipient.
 *
 * This method will automatically create the conversation (if needed),
 * and then sends the given siren to the given jid.
 *
 * @param withPush
 *   The push attribute to specify in the XML for the server.
 *   (whether or not the server should send push notification)
 *
 * @param withBadge
 *   The badge attribute to specify in the XML for the server.
 *   (whether or not the server should include in badge count)
 *
 * @param createMessage
 *   If YES, then a corresponding STMessage is automatically created and added to the conversation.
 *   If NO, then a STMessage will not be created (send siren/xmpp only).
 *
 * @param completionBlock
 *   messageId         - The uuid of the corresponding STMessage that was created
 *   conversationId    - The uuid of the corresponding STConversation (which may have been created)
**/
- (void)sendSiren:(Siren *)siren
            toJID:(XMPPJID *)recipient
         withPush:(BOOL)withPush
            badge:(BOOL)withBadge
    createMessage:(BOOL)createMessage
       completion:(void (^)(NSString *messageId, NSString *conversationId))completionBlock;

/**
 * Use this method when creating a new conversation.
 * That is, when the user chooses to create a new conversation, and chooses multiple recipients.
 * 
 * This method will automatically create the conversation (if needed),
 * and then sends the given siren to the given jids.
 * 
 * @param withPush
 *   The push attribute to specify in the XML for the server.
 *   (whether or not the server should send push notification)
 *
 * @param withBadge
 *   The badge attribute to specify in the XML for the server.
 *   (whether or not the server should include in badge count)
 *
 * @param createMessage
 *   If YES, then a corresponding STMessage is automatically created and added to the conversation.
 *   If NO, then a STMessage will not be created (send siren/xmpp only).
 *
 * @param completionBlock
 *   messageId         - The uuid of the corresponding STMessage that was created
 *   conversationId    - The uuid of the corresponding STConversation (which may have been created)
**/
- (void)sendSiren:(Siren *)siren
         toJidSet:(XMPPJIDSet *)recipients
         withPush:(BOOL)withPush
            badge:(BOOL)withBadge
    createMessage:(BOOL)createMessage
       completion:(void (^)(NSString *messageId, NSString *conversationId))completionBlock;

/**
 * Use this method when the conversationID is already known.
 * That is, the STConversation already exists.
 * 
 * @param withPush
 *   The push attribute to specify in the XML for the server.
 *   (whether or not the server should send push notification)
 * 
 * @param withBadge
 *   The badge attribute to specify in the XML for the server.
 *   (whether or not the server should include in badge count)
 *
 * @param createMessage
 *   If YES, then a corresponding STMessage is automatically created and added to the conversation.
 *   If NO, then a STMessage will not be created (send siren/xmpp only).
 *
 * @param completionBlock
 *   messageId - The uuid of the corresponding STMessage that was created
**/
- (void)sendSiren:(Siren *)siren forConversationID:(NSString *)conversationId
                                          withPush:(BOOL)withPush
                                             badge:(BOOL)withBadge
                                     createMessage:(BOOL)createMessage
                                        completion:(void (^)(NSString *messageId))completionBlock;


#pragma mark Send Pub Siren

/**
 * Currently in beta status.
**/
- (void)sendPubSiren:(Siren *)siren forConversationID:(NSString *)conversationId
                                             withPush:(BOOL)withPush
                                                badge:(BOOL)withBadge
                                        createMessage:(BOOL)createMessage
                                           completion:(void (^)(NSString *messageId))completionBlock;


#pragma mark Send Other

/**
 * Creates a "fake" conversation object (if needed),
 * and adds the given message to the conversation.
**/
+ (void)sendInfoMessage:(NSString *)messageText toUser:(NSString *)userID;

/**
 * Burns the given message by performing the following actions:
 *
 * - deletes the message from the local device
 * - sends an IQ to delete it from the xmpp server's offline storage (if needed)
 * - sends a siren to delete it from the remote device (if needed)
**/
- (void)burnMessage:(NSString *)messageId inConversation:(NSString *)conversationId;


#pragma mark SCloud

/**
 * Use this method when creating a new conversation.
 * That is, when the user chooses to create a new conversation, and chooses a single recipient.
 *
 * This method will automatically create the conversation (if needed),
 * and then queue the given siren to be sent automatically after the SCloud upload completes.
 *
 * @param completionBlock
 *   messageId         - The uuid of the corresponding STMessage that was created
 *   conversationId    - The uuid of the corresponding STConversation (which may have been created)
**/
- (void)sendScloudWithSiren:(Siren *)siren
                      toJID:(XMPPJID *)recipient
                 completion:(void (^)(NSString *messageId, NSString *conversationId))completionBlock;

/**
 * Use this method when creating a new conversation.
 * That is, when the user chooses to create a new conversation, and chooses multiple recipients.
 *
 * This method will automatically create the conversation (if needed),
 * and then queue the given siren to be sent automatically after the SCloud upload completes.
 *
 * @param completionBlock
 *   messageId         - The uuid of the corresponding STMessage that was created
 *   conversationId    - The uuid of the corresponding STConversation (which may have been created)
**/
- (void)sendScloudWithSiren:(Siren *)siren
                   toJidSet:(XMPPJIDSet *)recipients
                 completion:(void (^)(NSString *messageId, NSString *conversationId))completionBlock;

/**
 * Use this method when the conversationID is already known.
 * That is, the STConversation already exists.
 *
 * @param completionBlock
 *   messageId - The uuid of the corresponding STMessage that was created
**/
- (void)sendScloudWithSiren:(Siren *)siren
          forConversationID:(NSString *)conversationId
                 completion:(void (^)(NSString *messageId))completionBlock;

/**
 * Attempts to download (in the background) all the SCloud segments.
**/
- (void)downloadSCloudForMessage:(STMessage *)message
                   withThumbnail:(OSImage *)thumbnail
                 completionBlock:(void (^)(STMessage *message, NSError *error))completionBlock;


#pragma mark Assets

/**
 * Use this method when creating a new conversation.
 * That is, when the user chooses to create a new conversation, and chooses a single recipient.
 *
 * This method will automatically create the conversation (if needed),
 * and then queue the given asset to be sent automatically after the upload completes.
 *
 * @param completionBlock
 *   messageId         - The uuid of the corresponding STMessage that was created
 *   conversationId    - The uuid of the corresponding STConversation (which may have been created)
**/
- (void)sendAssetWithInfo:(NSDictionary *)assetInfo
                    toJID:(XMPPJID *)recipient
               completion:(void (^)(NSString *messageId, NSString *conversationId))completionBlock;

/**
 * Use this method when creating a new conversation.
 * That is, when the user chooses to create a new conversation, and chooses multiple recipients.
 *
 * This method will automatically create the conversation (if needed),
 * and then queue the given asset to be sent automatically after the upload completes.
 *
 * @param completionBlock
 *   messageId         - The uuid of the corresponding STMessage that was created
 *   conversationId    - The uuid of the corresponding STConversation (which may have been created)
**/
- (void)sendAssetWithInfo:(NSDictionary *)assetInfo
                 toJidSet:(XMPPJIDSet *)recipients
               completion:(void (^)(NSString *messageId, NSString *conversationId))completionBlock;

/**
 * Use this method when the conversationID is already known.
 * That is, the STConversation already exists.
 *
 * This method will queue the given asset to be sent automatically after the upload completes.
 *
 * @param completionBlock
 *   messageId - The uuid of the corresponding STMessage that was created
**/
- (void)sendAssetWithInfo:(NSDictionary *)assetInfo
        forConversationID:(NSString *)conversationId
               completion:(void (^)(NSString *messageId))completionBlock;


#pragma mark Reverify

/**
 * Tries to verify the message again.
 * This is done via:
 * - refreshing the user's web info
 * - then re-checking the message signature against the user's listed public key(s)
**/
- (void)reverifySignatureForMessage:(STMessage *)message completionBlock:(void (^)(NSError *error))completionBlock;

#pragma mark Rekey

/**
 * This method will re-key the conversation.
 * For multicast conversations, this means creating a new symmetric key, and broadcasting it to the participants.
 * For p2p conversations, this means resetting the secure context, and re-keying (using scimp v2 if possible).
**/
- (void)forceRekeyConversationID:(NSString *)conversationID completionBlock:(void (^)(NSError *error))completion;

/**
 * Used by STUserManager after refreshing a user's web info.
**/
- (void)rekeyConversationIfAwaitingReKeying:(STConversation *)conversation
                            withTransaction:(YapDatabaseReadWriteTransaction *)transaction;

#pragma mark IsVerified

/**
 * Use this when the user flips the "SAS verified" switch.
**/
- (void)setScimpID:(NSString *)scimpID isVerified:(BOOL)isVerifiedFlag;

#pragma mark ConversationID Generation

/**
 * Hashes the two strings together to get a conversationId.
 * Thus the conversationId can always be calculated given the proper JIDs.
**/
+ (NSString *)conversationIDForLocalJid:(XMPPJID *)myJid remoteJid:(XMPPJID *)remoteJid;

/**
 * Hashes the two strings together to get a conversationId.
 * Thus the conversationId can always be calculated given the proper strings.
**/
+ (NSString *)conversationIDForLocalJid:(XMPPJID *)myJid threadID:(NSString *)threadID;

@end
