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


//
//  Sirens try to capture JSON and the Argonauts.
//

#import <Foundation/Foundation.h>
#import "XMPPFramework.h"

extern NSString *const kCloudKeyKey; // Value is a string.
extern NSString *const kCloudURLKey; // Value is a string.
extern NSString *const kConversationIDKey; // Value is a string, a conversation UUID.
extern NSString *const kFYEOKey; // Value is a boolean.
extern NSString *const kMessageKey; // Value is a string.
extern NSString *const kPlainTextKey; // Value is a boolean.
extern NSString *const kReceivedIDKey; // Value is a string, a missive or conversation UUID.
extern NSString *const kReceivedTimeKey; // Value is a string with Zulu time (ISO 8601, e.g. 2012-08-22T04:06:31Z).
extern NSString *const kRequestReceiptKey; // Value is a boolean.
extern NSString *const kRequestResendKey; // Value is a string.
extern NSString *const kShredAfterKey; // Value is the integral number of seconds after receiving the message to destroy it.
extern NSString *const kPingKey;        // just a ping,   value is kPingRequest or  kPingResponse
extern NSString *const kPingRequest;    // ping
extern NSString *const kPingResponse;   // pong
extern NSString *const kLocationKey; // Value is a string.


/*
 Sample Siren JSON using the above keys (The below examples are pretty printed.):
 
 {
     "message" : "Hello. My name is Inigo Montoya. You killed my father. Prepare to die.",
     "fyeo" : true,
     "shred_after" : 120
 }
 
 {
     "cloud_url": "https://cloud.silentcircle.com/6473649",
     "cloud_key": "8IDCiIM1oR7pwhElTLyjs62oeLvEtIfhv75PPeK-JHE"
 }
 
 {
     "request_resend": "0bfb71a4-d8fd-4410-b119-199c3596f296"
 }

 When communicating with a normal XMPP client, the unencrypted <body/> is converted into this JSON:
 {
     "message" : "Hello. My name is Inigo Montoya. You killed my father. Prepare to die.",
     "plain_text" : true
 }
 
*/

@interface Siren : NSObject

// -json and -jsonData return canonical compact JSON as rendered by NSJSONSerialization.
@property (strong, nonatomic, readonly) NSString *json;
@property (strong, nonatomic, readonly) NSData   *jsonData;

// If the Siren JSON has been embedded in a chat message, here are other properties.
@property (strong, nonatomic, readonly) XMPPMessage *chatMessage;
@property (strong, nonatomic, readonly) NSString *body;
@property (strong, nonatomic, readonly) XMPPJID  *from;
@property (strong, nonatomic, readonly) NSString *fromStr;
@property (strong, nonatomic, readonly) NSString *scimp;
@property (strong, nonatomic, readonly) XMPPJID  *to;
@property (strong, nonatomic, readonly) NSString *toStr;
@property (strong, nonatomic, readonly) NSString *chatMessageID;

// Siren properties.
@property (strong, nonatomic) NSString *cloudKey;
@property (strong, nonatomic) NSString *cloudURL;
@property (strong, nonatomic) NSString *conversationID;
@property (strong, nonatomic) NSString *ping;
@property (strong, nonatomic) NSString *location;

@property (nonatomic, getter = isFyeo) BOOL fyeo; // For Your Eyes Only. I.e. no copying text to the clipboard.
@property (strong, nonatomic) NSString *message;
@property (nonatomic, getter = isPlainText) BOOL plainText; // An unencrypted message
@property (strong, nonatomic) NSString *receivedID; // A UUID string associated with the received item.
@property (strong, nonatomic) NSDate   *receivedTime; // The Zulu time when the item was received.
@property (nonatomic, getter = isRequestReceipt) BOOL requestReceipt; // Request a return receipt.
@property (strong, nonatomic) NSString *requestResend;
@property (nonatomic) uint32_t shredAfter;

+ (Siren *) sirenWithJSONData: (NSData *)   jsonData;
+ (Siren *) sirenWithJSON:     (NSString *) json;
+ (Siren *) sirenWithChatMessage: (XMPPMessage *) message;

- (Siren *) initWithJSONData: (NSData *)   jsonData; // Designated initializer. 
- (Siren *) initWithJSON:     (NSString *) json;
- (Siren *) initWithChatMessage: (XMPPMessage *) message;

- (XMPPMessage *) chatMessageToJID: (XMPPJID *) jid;

@end
