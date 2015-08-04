/*
Copyright (C) 2015, Silent Circle, LLC. All rights reserved.

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
#import <SCCrypto/SCcrypto.h>

#import "STPublicKey.h"


@interface SCimpUtilities : NSObject


#pragma mark Key Utilities

/**
 * This method creates (deserializes) the JSON into an actual key instance.
 *
 * IMPORTANT: You MUST free the returned key via SCKeyFree().
 * For example:
 * 
 * SCKeyContextRef key = kInvalidSCKeyContextRef;
 * SCLError err = SCKey_Deserialize(publicKey.keyJSON, &key);
 * 
 * if ((err = kSCLError_NoErr) && SCKeyContextRefIsValid(key)) {
 *     // Do stuff with 'key'
 * }
 * 
 * if (SCKeyContextRefIsValid(key)) {
 *     SCKeyFree(key);
 *     key = kInvalidSCKeyContextRef;
 * }
**/
SCLError SCKey_Deserialize(NSString *keyJSON, SCKeyContextRef *keyContextPtr);

/**
 * Returns the keyJSON string. (e.g. STPublicKey.keyJSON)
 *
 * Regardless of whether or not the given keyContext is a private or public key,
 * the exported keyJSON will ONLY contain the public key information.
**/
SCLError SCKey_SerializePublic(SCKeyContextRef keyContext, NSString **keyJsonPtr);

/**
 * Returns the keyJSON string. (e.g. STPublicKey.keyJSON)
 * 
 * The exported keyJSON will contain both the private & public key information.
**/
SCLError SCKey_SerializePrivate(SCKeyContextRef keyContext, NSString **keyJsonPtr);

/**
 * This method takes a private key, and another key that you want to sign (using the given private key).
 *
 * The "keyToSign" can be either a public or private key.
 * The resulting signed version of the key is returned via the "signed_keyToSign_ptr" parameter.
**/
SCLError SCKey_Sign(STPublicKey *privKey, STPublicKey *keyToSign, STPublicKey **signed_keyToSign_ptr);


#pragma mark NSString Utilities

+ (NSString *)stringFromSCLError:(SCLError)error;
+ (NSString *)stringFromSCimpState:(SCimpState)state;
+ (NSString *)stringFromSCimpMethod:(SCimpMethod)method;
+ (NSString *)stringFromSCimpEventType:(SCimpEventType)type;
+ (NSString *)stringFromSCimpCipherSuite:(SCimpCipherSuite)cipherSuite;

+ (NSString *)displayStringFromSCLError:(SCLError)protocolError;
+ (NSString *)displayStringFromSCimpCipherSuite:(SCimpCipherSuite)cipherSuite;

#pragma mark NSError Utilities

+ (NSError *)errorWithSCLError:(SCLError)err;

@end
