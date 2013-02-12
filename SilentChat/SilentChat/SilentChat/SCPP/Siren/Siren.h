//
//  Siren.h
//  SilentText
//
//  Created by Andrew Donoho on 2012/07/23.
//  Copyright (c) 2012 Donoho Design Group, L.L.C. All rights reserved.
//
//  Sirens try to capture JSON and the Argonauts.
//

#import <Foundation/Foundation.h>
#import "XMPPFramework.h"

extern NSString *const kCloudKeyKey; // Value is a string.
extern NSString *const kCloudLocatorKey; // Value is a string.
extern NSString *const kConversationIDKey; // Value is a string, a conversation UUID.
extern NSString *const kFYEOKey; // Value is a boolean.
extern NSString *const kMessageKey; // Value is a string.
extern NSString *const kPlainTextKey; // Value is a boolean.
extern NSString *const kReceivedIDKey; // Value is a string, a missive or conversation UUID.
extern NSString *const kReceivedTimeKey; // Value is a string with Zulu time (ISO 8601, e.g. 2012-08-22T04:06:31Z).
extern NSString *const kRequestReceiptKey; // Value is a boolean.
extern NSString *const kRequestResendKey; // Value is a string.
extern NSString *const kRequestBurnKey; // Value is a string.
extern NSString *const kShredAfterKey; // Value is the integral number of seconds after receiving the message to destroy it.
extern NSString *const kPingKey;        // just a ping,   value is kPingRequest or  kPingResponse
extern NSString *const kPingRequest;    // ping
extern NSString *const kPingResponse;   // pong
extern NSString *const kLocationKey; // Value is a string.

extern NSString *const kThumbNailKey;  // Value is NSData encoded JPEG
extern NSString *const kMediaTypeKey;


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
@property (strong, nonatomic) NSString *cloudLocator;
@property (strong, nonatomic) NSString *conversationID;
@property (strong, nonatomic) NSString *ping;
@property (strong, nonatomic) NSString *location;
@property (strong, nonatomic) NSString *mediaType;
@property (strong, nonatomic) NSData    *thumbnail;
@property (strong, nonatomic) NSString  *vcard;
 
@property (nonatomic, getter = isFyeo) BOOL fyeo; // For Your Eyes Only. I.e. no copying text to the clipboard.
@property (strong, nonatomic) NSString *message;
@property (nonatomic, getter = isPlainText) BOOL plainText; // An unencrypted message
@property (strong, nonatomic) NSString *receivedID; // A UUID string associated with the received item.
@property (strong, nonatomic) NSDate   *receivedTime; // The Zulu time when the item was received.
@property (nonatomic, getter = isRequestReceipt) BOOL requestReceipt; // Request a return receipt.
@property (strong, nonatomic) NSString *requestResend;
@property (strong, nonatomic) NSString *requestBurn;
@property (nonatomic) uint32_t shredAfter;


+ (Siren *) sirenWithJSONData: (NSData *)   jsonData;
+ (Siren *) sirenWithJSON:     (NSString *) json;
+ (Siren *) sirenWithChatMessage: (XMPPMessage *) message;

- (Siren *) initWithJSONData: (NSData *)   jsonData; // Designated initializer. 
- (Siren *) initWithJSON:     (NSString *) json;
- (Siren *) initWithChatMessage: (XMPPMessage *) message;
- (BOOL) isValid;

- (XMPPMessage *) chatMessageToJID: (XMPPJID *) jid;

@end
