/*
Copyright (C) 2014-2015, Silent Circle, LLC. All rights reserved.

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
#import "STDatabaseObject.h"


extern NSString *const kPingRequest;   // ping
extern NSString *const kPingResponse;  // pong


@interface Siren : STDatabaseObject <NSCopying>

+ (instancetype)sirenWithJSON:(NSString *)json;
+ (instancetype)sirenWithJSONData:(NSData *)jsonData;
+ (instancetype)sirenWithPlaintext:(NSString *)plaintext;

- (instancetype)initWithJSON:(NSString *)json;
- (instancetype)initWithJSONData:(NSData *)jsonData; // Designated initializer
- (instancetype)initWithPlaintext:(NSString *)plaintext;

#pragma mark JSON

// -jsonData and -json return canonical compact JSON as rendered by NSJSONSerialization.
@property (nonatomic, readonly) NSData   *jsonData;
@property (nonatomic, readonly) NSString *json;


#pragma mark Siren properties

@property (nonatomic, strong) NSString *message;

@property (nonatomic, assign) uint32_t shredAfter;
@property (nonatomic, strong) NSString *location;
@property (nonatomic, assign) BOOL fyeo;             // For Your Eyes Only (no screenshots, copying to the clipboard)

@property (nonatomic, strong) NSString *requestBurn;
@property (nonatomic, strong) NSString *requestResend;

@property (nonatomic, assign) BOOL requestReceipt;
@property (nonatomic, strong) NSString *receivedID;   // A UUID string associated with the received item
@property (nonatomic, strong) NSDate   *receivedTime; // The Zulu time when the item was received

@property (nonatomic, strong) NSString *cloudKey;
@property (nonatomic, strong) NSString *cloudLocator;
@property (nonatomic, strong) NSString *mimeType;
@property (nonatomic, strong) NSString *mediaType;
@property (nonatomic, strong) NSData   *thumbnail;
@property (nonatomic, strong) NSData   *preview;     // similar to thumbnail, but used for vcard and such
@property (nonatomic, strong) NSString *duration;    // %f in seconds
@property (nonatomic, strong) NSData   *waveform;    // string of hex digits for audio waveform display
@property (nonatomic, strong) NSString *vcard;

@property (nonatomic, strong) NSString *signature;

@property (nonatomic, strong) NSString *ping;
@property (nonatomic, strong) NSString *capabilities;

@property (nonatomic, strong) NSString *multicastKey;
@property (nonatomic, strong) NSString *requestThreadKey;
@property (nonatomic, strong) NSString *threadName;

@property (nonatomic, strong) NSString *callerIdName;
@property (nonatomic, strong) NSString *callerIdNumber;
@property (nonatomic, strong) NSString *callerIdUser;
@property (nonatomic, strong) NSDate   *recordedTime; // The Zulu time when the message was recorded by OCA

@property (nonatomic, assign) BOOL hasGPS;            // Scloud item has kSCloudMetaData_GPS
@property (nonatomic, assign) BOOL isMapCoordinate;   // Should be interpreted as a current location

@property (nonatomic, strong) NSDate *testTimestamp;  // For test packet, the time when siren was queued


#pragma mark Siren metadata

// Inidcates message was received as an unencrypted message (set by stream if message didn't have encryption)
@property (nonatomic, readonly) BOOL isPlainText;

// Set requiresLocation to indicate to messageStream that it should insert Location.
// That is, at the moment the Siren was sent the user requested it to include Location,
// however the Location wasn't available to be added at that moment.
@property (nonatomic, readwrite) BOOL requiresLocation;


#pragma mark Convenience properties

// YES if the JSON is valid
@property (nonatomic, readonly) BOOL isValid;

// YES if the mediaType or mimeType indicates a PDF
@property (nonatomic, readonly) BOOL isPDF;

// YES if the mediaType indicates audio, and it has a callerIdNumber or callerIdUser
@property (nonatomic, readonly) BOOL isVoicemail;


#pragma mark Signature

// Calculates & returns the proper SHA256 hash for the siren
- (NSData *)sigSHA256Hash;


@end
