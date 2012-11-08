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

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "AppConstants.h"
#import "Siren.h"

#import "StorageCipher.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

NSString *const kCloudKeyKey = @"cloud_key";
NSString *const kCloudURLKey = @"cloud_url";
NSString *const kConversationIDKey = @"conversation_id";
NSString *const kFYEOKey = @"fyeo";
NSString *const kMessageKey = @"message";
NSString *const kPlainTextKey = @"plain_text";
NSString *const kReceivedIDKey = @"received_id";
NSString *const kReceivedTimeKey = @"received_time";
NSString *const kRequestReceiptKey = @"request_receipt";
NSString *const kRequestResendKey = @"request_resend";
NSString *const kShredAfterKey = @"shred_after";
NSString *const kLocationKey = @"location";
NSString *const kPingKey = @"ping";

NSString *const kPingRequest = @"PING";
NSString *const kPingResponse = @"PONG";



@interface Siren ()

@property (strong, nonatomic, readwrite) NSString *json;
@property (strong, nonatomic, readwrite) NSData   *jsonData;
@property (strong, nonatomic, readwrite) XMPPMessage *chatMessage;
@property (strong, nonatomic) NSMutableDictionary *info;

@end

@implementation Siren

@synthesize json = _json;
@synthesize jsonData = _jsonData;

// XMPPMessage properties.
@synthesize chatMessage = _chatMessage;
@dynamic body;
@dynamic from, fromStr;
@dynamic scimp;
@dynamic to, toStr;
@dynamic chatMessageID;

@dynamic cloudKey;
@dynamic cloudURL;
@dynamic conversationID;
@dynamic fyeo;
@dynamic plainText;
@dynamic message;
@dynamic receivedID;
@dynamic receivedTime;
@dynamic requestResend;
@dynamic shredAfter;
@dynamic ping;
@dynamic location;


@synthesize info = _info;

NSString *const kZuluTimeFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"; // ISO 8601 time.
static const long kNumDateFormatters = 1l;
static dispatch_semaphore_t _siren_df_semaphore  = NULL;
static NSDateFormatter *    _siren_dateFormatter = nil;

+ (void) initialize {
	
	if (self == Siren.class) {
		
		_siren_df_semaphore = dispatch_semaphore_create(kNumDateFormatters);
		
        // Quinn "The Eskimo" pointed me to: 
        // <https://developer.apple.com/library/ios/#qa/qa1480/_index.html>.
        // The contained advice recommends all internet time formatting to use US POSIX standards.
        NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier: @"en_US_POSIX"];
        
		_siren_dateFormatter = NSDateFormatter.new;
        
        [_siren_dateFormatter setLocale: enUSPOSIXLocale];
        [_siren_dateFormatter setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
		[_siren_dateFormatter setDateFormat: kZuluTimeFormat];
    }
    
} // +initialize


#pragma mark - Accessor methods.


- (NSString *) json {
    
    DDGTrace();
    
    if (_json) { return _json; }
    
    NSData   *jsonData = self.jsonData;
    NSString *json     = [NSString.alloc initWithBytes: jsonData.bytes 
                                                length: jsonData.length 
                                              encoding: NSUTF8StringEncoding];
    self.json = json;
    
    return json;
    
} // -json


- (NSData *) jsonData {
    
    DDGTrace();
    
    if (_jsonData) { return _jsonData; }
    
    NSError *error = nil;
    
    NSData *data = ([NSJSONSerialization  isValidJSONObject: self.info] ? 
                    [NSJSONSerialization dataWithJSONObject: self.info options: 0UL error: &error] : 
                    nil);
    if (error) {
        
        DDGDesc(error.userInfo);
    }
    self.jsonData = data;
    self.json = nil;

    return data;
    
} // -jsonData


- (Siren *) nilJSON {
    
    self.json     = nil;
    self.jsonData = nil;
    self.chatMessage = nil;
    
    return self;
    
} // -nilJSON


#pragma mark XMPPMessage accessor methods.


- (NSString *) body {
    
    return [[self.chatMessage elementForName: kXMPPBody] stringValue];
    
} // -body


- (XMPPJID *) from {
    
    NSString *jidString = self.fromStr;
    
    return jidString ? [XMPPJID jidWithString: jidString] : nil;
    
} // -from


- (NSString *) fromStr {
    
    return [[self.chatMessage attributeForName: kXMPPFrom] stringValue];
    
} // -fromStr


- (NSString *) scimp {
    
    return [[self.chatMessage elementForName: kXMPPX xmlns: kSCPPNameSpace] stringValue];
    
} // -scimp


- (XMPPJID *) to {
    
    NSString *jidString = self.toStr;
    
    return jidString ? [XMPPJID jidWithString: jidString] : nil;
    
} // -to


- (NSString *) toStr {
    
    return [[self.chatMessage attributeForName: kXMPPTo] stringValue];
    
} // -toStr


- (NSString *) chatMessageID {
    
    return [[self.chatMessage attributeForName: kXMPPID] stringValue];
    
} // -chatMessageID


#pragma mark JSON accessor methods.


- (NSString *) cloudKey {
    
    NSString *cloudKey = [self.info valueForKey: kCloudKeyKey];
    
    return [cloudKey isKindOfClass: NSString.class] ? cloudKey : nil;
    
} // -cloudKey


- (void) setCloudKey: (NSString *) cloudKey {
    
    [self nilJSON];
    
    [self.info setValue: cloudKey forKey: kCloudKeyKey];
    
} // -setCloudKey:


- (NSString *) cloudURL {
    
    NSString *cloudURL = [self.info valueForKey: kCloudURLKey];
    
    return [cloudURL isKindOfClass: NSString.class] ? cloudURL : nil;
    
} // -cloudURL


- (void) setCloudURL: (NSString *) cloudURL {
    
    [self nilJSON];
    
    [self.info setValue: cloudURL forKey: kCloudURLKey];
    
} // -setCloudURL:


- (NSString *) conversationID {
    
    NSString *conversationID = [self.info valueForKey: kConversationIDKey];
    
    return [conversationID isKindOfClass: NSString.class] ? conversationID : nil;
    
} // -conversationID


- (void) setConversationID: (NSString *) conversationID {
    
    [self nilJSON];
    
    [self.info setValue: conversationID forKey: kConversationIDKey];
    
} // -setConversationID:



- (NSString *) ping {
    
    NSString *ping = [self.info valueForKey: kPingKey];
    
    return [ping isKindOfClass: NSString.class] ? ping : nil;
    
} // -ping


- (void) setPing: (NSString *) ping {
    
    [self nilJSON];
    
    [self.info setValue: ping forKey: kPingKey];
    
} // -setPing:


- (NSString *) location {
    
    NSString *location = [self.info valueForKey: kLocationKey];
    
    return [location isKindOfClass: NSString.class] ? location : nil;
    
} // -location


- (void) setLocation: (NSString *) location {
    
    [self nilJSON];
    
    [self.info setValue: location forKey: kLocationKey];
    
} // -setLocation:




 

- (BOOL) isFyeo {
    
    NSNumber *fyeo = [self.info valueForKey: kFYEOKey];
    
    return [fyeo isKindOfClass: NSNumber.class] ? fyeo.boolValue : NO;
    
} // -isFyeo


- (BOOL) fyeo {
    
    return self.isFyeo;
    
} // -fyeo


- (void) setFyeo: (BOOL) fyeo {
    
    [self nilJSON];
    
    if (fyeo) {
        
        [self.info setValue: [NSNumber numberWithBool: fyeo] 
                     forKey: kFYEOKey];
    }
    else {
        
        [self.info setValue: nil forKey: kFYEOKey];
    }
    
} // -setFyeo:


- (NSString *) message {
    
    NSString *message = [self.info valueForKey: kMessageKey];
    
    return [message isKindOfClass: NSString.class] ? message : nil;
    
} // -message


- (void) setMessage: (NSString *) message {
    
    [self nilJSON];
    
    [self.info setValue: message forKey: kMessageKey];
    
} // -setMessage:


- (BOOL) isPlainText {
    
    NSNumber *plainText = [self.info valueForKey: kPlainTextKey];
    
    return [plainText isKindOfClass: NSNumber.class] ? plainText.boolValue : NO;
    
} // -isPlainText


- (BOOL) plainText {
    
    return self.isPlainText;
    
} // -plainText


- (void) setPlainText: (BOOL) plainText {
    
    [self nilJSON];
    
    [self.info setValue: [NSNumber numberWithBool: plainText] 
                 forKey: kPlainTextKey];
    
} // -setPlainText:


- (NSString *) receivedID {
    
    NSString *receivedID = [self.info valueForKey: kReceivedIDKey];
    
    return [receivedID isKindOfClass: NSString.class] ? receivedID : nil;
    
} // -receivedID


- (void) setReceivedID: (NSString *) receivedID {
    
    [self nilJSON];
    
    [self.info setValue: receivedID forKey: kReceivedIDKey];
    
} // -setReceivedID:


- (NSDate *) receivedTime {
    
    NSString *receivedTime = [self.info valueForKey: kReceivedTimeKey];

    if ([receivedTime isKindOfClass: NSString.class]) {
        
        NSDate *date = nil;
        
        dispatch_semaphore_wait(_siren_df_semaphore, DISPATCH_TIME_FOREVER); {
            
            date = [_siren_dateFormatter dateFromString: receivedTime];
        }
        dispatch_semaphore_signal(_siren_df_semaphore);
        
        return date;
    }
    return nil;
    
} // -receivedTime


- (void) setReceivedTime: (NSDate *) receivedTime {
    
    [self nilJSON];
    
    NSString *receivedString = nil;

    if (receivedTime) {
        
        dispatch_semaphore_wait(_siren_df_semaphore, DISPATCH_TIME_FOREVER); {
            
            receivedString = [_siren_dateFormatter stringFromDate: receivedTime];
        }
        dispatch_semaphore_signal(_siren_df_semaphore);
    }
    [self.info setValue: receivedString forKey: kReceivedTimeKey];
    
} // -setReceivedTime:


- (BOOL) isRequestReceipt {
    
    NSNumber *requestReceipt = [self.info valueForKey: kRequestReceiptKey];
    
    return [requestReceipt isKindOfClass: NSNumber.class] ? requestReceipt.boolValue : NO;
    
} // -isRequestReceipt


- (BOOL) requestReceipt {
    
    return self.isRequestReceipt;
    
} // -requestReceipt


- (void) setRequestReceipt: (BOOL) requestReceipt {
    
    [self nilJSON];
    
    [self.info setValue: [NSNumber numberWithBool: requestReceipt] 
                 forKey: kRequestReceiptKey];
    
} // -setRequestReceipt:


- (NSString *) requestResend {
    
    NSString *requestResend = [self.info valueForKey: kRequestResendKey];
    
    return [requestResend isKindOfClass: NSString.class] ? requestResend : nil;
    
} // -requestResend


- (void) setRequestResend: (NSString *) requestResend {
    
    [self nilJSON];
    
    [self.info setValue: requestResend forKey: kRequestResendKey];
    
} // -setRequestResend:


- (uint32_t) shredAfter {
    
    NSNumber *timeInterval = [self.info valueForKey: kShredAfterKey];
    
    return [timeInterval isKindOfClass: NSNumber.class] ? timeInterval.unsignedIntValue : 0;
    
} // -shredAfter


- (void) setShredAfter: (uint32_t) shredAfter {
    
    [self nilJSON];
    
    if (shredAfter > 0) {
        
        [self.info setValue: [NSNumber numberWithUnsignedInt: shredAfter] 
                     forKey: kShredAfterKey];
    }
    else if (shredAfter <= 0) {
        
        [self.info setValue: nil forKey: kShredAfterKey];
    }
    
} // -setShredAfter:


#pragma mark - Initializer methods.


+ (Siren *) sirenWithJSONData: (NSData *) jsonData {
    
    return [self.class.alloc initWithJSONData: jsonData];
    
} // +sirenWithJSONData:


+ (Siren *) sirenWithJSON: (NSString *) json {
    
    return [self.class.alloc initWithJSON: json];
    
} // +sirenWithJSON:


+ (Siren *) sirenWithChatMessage: (XMPPMessage *) message {
    
    return [self.class.alloc initWithChatMessage: message];
    
} // +sirenWithChatMessage:


- (Siren *) initWithJSONData: (NSData *) jsonData {
    
    DDGTrace();
    
    self = [super init];
    
    if (self) {
        
        if (jsonData) {
            
            self.jsonData = jsonData;
            
            NSError *error = nil;
            NSMutableDictionary *info = nil;
            
            info = [NSJSONSerialization JSONObjectWithData: jsonData 
                                                   options: NSJSONReadingMutableContainers 
                                                     error: &error];
            if (error) {
                
                DDGDesc(error.userInfo);
                
                info = nil;
                [self nilJSON];
            }
            self.info = info ? info : [NSMutableDictionary dictionaryWithCapacity: 6];
        }
        else {
            
            self.info = [NSMutableDictionary dictionaryWithCapacity: 6]; // The number of different JSON keys.
        }
    }
    return self;
    
} // -initWithJSONData:


- (BOOL) mayContainJSON: (NSString *) json {
    
    json = [json stringByTrimmingCharactersInSet: NSCharacterSet.whitespaceAndNewlineCharacterSet];
    
    if (json.length > 2) { // There must be something in between the [] or {}.
        
        unichar firstChar = [json characterAtIndex: 0];
        unichar  lastChar = [json characterAtIndex: json.length - 1];
        
        return (firstChar == '{' && lastChar == '}') || (firstChar == '[' && lastChar == ']');
    }
    return NO;
    
} // -mayContainJSON:


- (Siren *) initWithJSON: (NSString *) json {
    
    DDGTrace();
    
    if (json) {
        
        if ([self mayContainJSON: json]) {
            
            const char *utf8String = json.UTF8String;
            
            NSData *data = [NSData dataWithBytesNoCopy: (void *)utf8String 
                                                length: strlen( utf8String) 
                                          freeWhenDone: NO];
            
            Siren *siren = [self initWithJSONData: data];
            
            _json     = json; // Assign the ivar directly; i.e. don't force a reparse of the string.
            _jsonData = nil;  // As the data actually belongs to the string, release the NSData shell.
            
            return siren;
        }
        else {
            
            // Convert the string into proper JSON.
            return [self initWithJSON: [NSString stringWithFormat: 
                                        @"{\"%@\":\"%@\",\"%@\":true}", 
                                        kMessageKey, json, kPlainTextKey]];
        }
    }
    return [self initWithJSONData: nil];
    
} // -initWithJSON:


- (Siren *) initWithChatMessage:  (XMPPMessage *) message {
    
    self.chatMessage = message;
    
    NSString *json = [[message elementForName: kSCPPSiren xmlns: kSCPPNameSpace] stringValue];
    
    return [self initWithJSON: json ? json : [[message elementForName: kXMPPBody] stringValue]];
    
} // -initWithChatMessage:


- (Siren *) init {
    
    DDGTrace();
    
    return [self initWithJSONData: nil];
    
} // -init


#pragma mark - Instance methods.


- (NSString *) description {
    
    if (self.chatMessage) {
        
        return [NSString stringWithFormat: 
                @"Dictionary: %@; \n\tChat Message:\n%@", 
                self.info.description, self.chatMessage.compactXMLString];
    }
    return self.info.description;
    
} // -description


- (XMPPMessage *) chatMessageToJID: (XMPPJID *) jid {
    
    DDGDesc(jid);
    
    XMPPMessage  *message = [XMPPMessage messageWithType: kXMPPChat to: jid];
    
    [message addAttributeWithName: kXMPPID stringValue: [XMPPStream generateUUID]];

#ifdef SIREN_DEBUG
    NSXMLElement * bodyElement = [NSXMLElement.alloc initWithName: kXMPPBody stringValue: self.json];
#else
    NSXMLElement * bodyElement = [NSXMLElement.alloc initWithName: kXMPPBody];
#endif
    [message addChild: bodyElement];
    
    NSXMLElement *sirenElement = [NSXMLElement.alloc initWithName: kSCPPSiren URI: kSCPPNameSpace];
    sirenElement.stringValue = self.json;
    [message addChild: sirenElement];
    
    self.chatMessage = message;
    
    return message;
    
} // -chatMessageToJID

@end
