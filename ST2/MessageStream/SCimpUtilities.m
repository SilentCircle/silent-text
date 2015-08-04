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
#import "SCimpUtilities.h"
#import "AppDelegate.h"
#import "AppConstants.h"


@implementation SCimpUtilities

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Key Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

SCLError SCKey_Deserialize(NSString *keyJSON, SCKeyContextRef *keyContextPtr)
{
	if ([keyJSON length] == 0)
	{
		if (keyContextPtr) *keyContextPtr = kInvalidSCKeyContextRef;
		return kSCLError_BadParams;
	}
	
	NSUInteger jsonLen_utf8 = [keyJSON lengthOfBytesUsingEncoding:NSUTF8StringEncoding]; // utf8Len != strLen
	const char *json_utf8 = [keyJSON UTF8String];
	
	SCLError err = SCKeyDeserialize((uint8_t *)json_utf8, jsonLen_utf8, keyContextPtr);
	return err;
}

/**
 * Returns the keyJSON string. (e.g. STPublicKey.keyJSON)
 *
 * Regardless of whether or not the given keyContext is a private or public key,
 * the exported keyJSON will ONLY contain the public key information.
**/
SCLError SCKey_SerializePublic(SCKeyContextRef keyContext, NSString **keyJsonPtr)
{
	if (keyContext == NULL)
	{
		if (keyJsonPtr) *keyJsonPtr = nil;
		return kSCLError_BadParams;
	}
	
	NSString * keyString = nil;
	uint8_t  * keyData = NULL;
	size_t     keyDataLen = 0;
	
	SCLError err = SCKeySerialize(keyContext, &keyData, &keyDataLen);
	
	if (err == kSCLError_NoErr)
	{
		keyString = [[NSString alloc] initWithBytesNoCopy:keyData
		                                           length:keyDataLen
		                                         encoding:NSUTF8StringEncoding
		                                     freeWhenDone:YES];
	}
	
	if (keyJsonPtr) *keyJsonPtr = keyString;
	return err;
}

/**
 * Returns the keyJSON string. (e.g. STPublicKey.keyJSON)
 *
 * The exported keyJSON will contain both the private & public key information.
**/
SCLError SCKey_SerializePrivate(SCKeyContextRef keyContext, NSString **keyJsonPtr)
{
	if (keyContext == NULL)
	{
		if (keyJsonPtr) *keyJsonPtr = nil;
		return kSCLError_BadParams;
	}
	
	SCLError err = kSCLError_NoErr;
	NSString * keyString = nil;
	uint8_t  * keyData = NULL;
	size_t     keyDataLen = 0;
	
	bool locked = TRUE;
	err = SCKeyIsLocked(keyContext, &locked); CKERR;
	
	if (locked)
	{
		err = SCKeyUnlockWithSCKey(keyContext, STAppDelegate.storageKey); CKERR;
	}
	
	err = SCKeySerializePrivateWithSCKey(keyContext, STAppDelegate.storageKey, &keyData, &keyDataLen);
	
	if (err == kSCLError_NoErr)
	{
		keyString = [[NSString alloc] initWithBytesNoCopy:keyData
		                                           length:keyDataLen
		                                         encoding:NSUTF8StringEncoding
		                                     freeWhenDone:YES];
	}
	
done:
	
	if (keyJsonPtr) *keyJsonPtr = keyString;
	return err;
}

/**
 * This method takes a private key, and another key that you want to sign (using the given private key).
 *
 * The "keyToSign" can be either a public or private key.
 * The resulting signed version of the key is returned via the "signed_keyToSign_ptr" parameter.
**/
SCLError SCKey_Sign(STPublicKey *privKey, STPublicKey *keyToSign, STPublicKey **signed_keyToSign_ptr)
{
	if (!privKey.isPrivateKey)
	{
		if (signed_keyToSign_ptr) *signed_keyToSign_ptr = nil;
		return kSCLError_BadParams;
	}
	
	if (keyToSign == nil)
	{
		if (signed_keyToSign_ptr) *signed_keyToSign_ptr = nil;
		return kSCLError_BadParams;
	}
	
	SCLError err = kSCLError_NoErr;
	SCKeyContextRef privKeyContext = kInvalidSCKeyContextRef;
	SCKeyContextRef keyContext = kInvalidSCKeyContextRef;
	
	STPublicKey *signed_keyToSign = nil;
	NSString *updatedKeyJson = nil;
	
	err = SCKey_Deserialize(privKey.keyJSON, &privKeyContext); CKERR;
	
	bool locked = TRUE;
	err = SCKeyIsLocked(privKeyContext, &locked); CKERR;
	
	if (locked)
	{
		err = SCKeyUnlockWithSCKey(privKeyContext, STAppDelegate.storageKey); CKERR;
	}
	
	err = SCKey_Deserialize(keyToSign.keyJSON, &keyContext); CKERR;
	
	err = SCKeySignKey(privKeyContext, keyContext, NULL); CKERR;
	
	if (keyToSign.isPrivateKey)
	{
		err = SCKey_SerializePrivate(keyContext, &updatedKeyJson); CKERR;
	}
	else
	{
		err = SCKey_SerializePublic(keyContext, &updatedKeyJson); CKERR;
	}
	
	signed_keyToSign = [[STPublicKey alloc] initWithUUID:keyToSign.uuid
	                                              userID:keyToSign.userID
	                                             keyJSON:updatedKeyJson
	                                        isPrivateKey:keyToSign.isPrivateKey];

done:
	
	if (SCKeyContextRefIsValid(privKeyContext))
	{
		SCKeyFree(privKeyContext);
		privKeyContext = kInvalidSCKeyContextRef;
	}
	
	if (SCKeyContextRefIsValid(keyContext))
	{
		SCKeyFree(keyContext);
		keyContext = kInvalidSCKeyContextRef;
	}
	
	if (signed_keyToSign_ptr) *signed_keyToSign_ptr = signed_keyToSign;
	return err;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSString Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSString *)stringFromSCLError:(SCLError)protocolError
{
	switch (protocolError)
	{
		// See also: displayStringFromSCLError (for friendly strings)
			
		case kSCLError_NoErr                  : return @"kSCLError_NoErr";
		case kSCLError_NOP                    : return @"kSCLError_NOP";
		case kSCLError_UnknownError           : return @"kSCLError_UnknownError";
		case kSCLError_BadParams              : return @"kSCLError_BadParams";
		case kSCLError_OutOfMemory            : return @"kSCLError_OutOfMemory";
		case kSCLError_BufferTooSmall         : return @"kSCLError_BufferTooSmall";
			
		case kSCLError_UserAbort              : return @"kSCLError_UserAbort";
		case kSCLError_UnknownRequest         : return @"kSCLError_UnknownRequest";
		case kSCLError_LazyProgrammer         : return @"kSCLError_LazyProgrammer";
			
		case kSCLError_AssertFailed           : return @"kSCLError_AssertFailed";
		
		case kSCLError_FeatureNotAvailable    : return @"kSCLError_FeatureNotAvailable";
		case kSCLError_ResourceUnavailable    : return @"kSCLError_ResourceUnavailable";
		case kSCLError_NotConnected           : return @"kSCLError_NotConnected";
		case kSCLError_ImproperInitialization : return @"kSCLError_ImproperInitialization";
		case kSCLError_CorruptData            : return @"kSCLError_CorruptData";
		case kSCLError_SelfTestFailed         : return @"kSCLError_SelfTestFailed";
		case kSCLError_BadIntegrity           : return @"kSCLError_BadIntegrity";
		case kSCLError_BadHashNumber          : return @"kSCLError_BadHashNumber";
		case kSCLError_BadCipherNumber        : return @"kSCLError_BadCipherNumber";
		case kSCLError_BadPRNGNumber          : return @"kSCLError_BadPRNGNumber";
			
		case kSCLError_SecretsMismatch        : return @"kSCLError_SecretsMismatch";
		case kSCLError_KeyNotFound            : return @"kSCLError_KeyNotFound";
			
		case kSCLError_ProtocolError          : return @"kSCLError_ProtocolError";
		case kSCLError_ProtocolContention     : return @"kSCLError_ProtocolContention";
			
		case kSCLError_KeyLocked              : return @"kSCLError_KeyLocked";
		case kSCLError_KeyExpired             : return @"kSCLError_KeyExpired";
			
		case kSCLError_EndOfIteration         : return @"kSCLError_EndOfIteration";
		case kSCLError_OtherError             : return @"kSCLError_OtherError";
		case kSCLError_PubPrivKeyNotFound     : return @"kSCLError_PubPrivKeyNotFound";
			
		default                               : return @"kSCLError_Unknown";
	}
}

+ (NSString *)stringFromSCimpState:(SCimpState)state
{
	switch (state)
	{
		// Thinking about changing these values to make them "friendlier"?
		// Don't ! Instead, make another method named displayStringFromSCimpState.
			
		case kSCimpState_Init      : return @"kSCimpState_Init";
		case kSCimpState_Ready     : return @"kSCimpState_Ready";
		case kSCimpState_Error     : return @"kSCimpState_Error";
			
		case kSCimpState_Commit    : return @"kSCimpState_Commit";
		case kSCimpState_DH2       : return @"kSCimpState_DH2";
			
		case kSCimpState_PKInit    : return @"kSCimpState_PKInit";
		case kSCimpState_PKStart   : return @"kSCimpState_PKStart";
		case kSCimpState_PKCommit  : return @"kSCimpState_PKCommit";
			
		case kSCimpState_DH1       : return @"kSCimpState_DH1";
		case kSCimpState_Confirm   : return @"kSCimpState_Confirm";
			
		default                    : return @"kSCimpState_Invalid";
	}
}

+ (NSString *)stringFromSCimpMethod:(SCimpMethod)method
{
	switch (method)
	{
		// Thinking about changing these values to make them "friendlier"?
		// Don't ! Instead, make another method named displayStringFromSCimpMethod.
			
		case kSCimpMethod_DH         : return @"kSCimpMethod_DH";
		case kSCimpMethod_Symmetric  : return @"kSCimpMethod_Symmetric";
		case kSCimpMethod_PubKey     : return @"kSCimpMethod_PubKey";
		case kSCimpMethod_DHv2       : return @"kSCimpMethod_DHv2";
		case kSCimpMethod_Invalid    :
		default                      : return @"kSCimpMethod_Invalid";
	}
}

+ (NSString *)stringFromSCimpEventType:(SCimpEventType)type
{
	switch (type)
	{
		case kSCimpEvent_NULL            : return @"kSCimpEvent_NULL";
		case kSCimpEvent_Error           : return @"kSCimpEvent_Error";
		case kSCimpEvent_Warning         : return @"kSCimpEvent_Warning";
		case kSCimpEvent_SendPacket      : return @"kSCimpEvent_SendPacket";
		case kSCimpEvent_Keyed           : return @"kSCimpEvent_Keyed";
		case kSCimpEvent_ReKeying        : return @"kSCimpEvent_ReKeying";
		case kSCimpEvent_Decrypted       : return @"kSCimpEvent_Decrypted";
		case kSCimpEvent_ClearText       : return @"kSCimpEvent_ClearText";
		case kSCimpEvent_Shutdown        : return @"kSCimpEvent_Shutdown";
		case kSCimpEvent_Transition      : return @"kSCimpEvent_Transition";
		case kSCimpEvent_AdviseSaveState : return @"kSCimpEvent_AdviseSaveState";
		case kSCimpEvent_PubData         : return @"kSCimpEvent_PubData";
		case kSCimpEvent_NeedsPrivKey    : return @"kSCimpEvent_NeedsPrivKey";
		case kSCimpEvent_LogMsg          : return @"kSCimpEvent_LogMsg";
		default                          : return @"kSCimpEvent_Unknown";
	}
}

+ (NSString *)stringFromSCimpCipherSuite:(SCimpCipherSuite)cipherSuite
{
	switch (cipherSuite)
	{
		case kSCimpCipherSuite_SKEIN_AES256_ECC414          : return @"kSCimpCipherSuite_SKEIN_AES256_ECC414";
		case kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384    : return @"kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384";
		case kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384 : return @"kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384";
		case kSCimpCipherSuite_SKEIN_AES256_ECC384          : return @"kSCimpCipherSuite_SKEIN_AES256_ECC384";
		case kSCimpCipherSuite_Symmetric_AES128             : return @"kSCimpCipherSuite_Symmetric_AES128";
		case kSCimpCipherSuite_Symmetric_AES256             : return @"kSCimpCipherSuite_Symmetric_AES256";
		default                                             : return @"kSCimpCipherSuite_Invalid";
	}
}

+ (NSString *)displayStringFromSCLError:(SCLError)protocolError
{
	// See also: stringFromSCLError (for technical strings)
	
	SCLError err;
	
	char errorBuf[256];
	err = SCCrypto_GetErrorString(protocolError, sizeof(errorBuf), errorBuf);
	
	if (err == kSCLError_NoErr)
		return [NSString stringWithUTF8String:errorBuf];
	else
		return nil;
}

+ (NSString *)displayStringFromSCimpCipherSuite:(SCimpCipherSuite)cipherSuite
{
	switch (cipherSuite)
	{
		case kSCimpCipherSuite_SKEIN_AES256_ECC414          : return @"Non-NIST";
		case kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384    : return @"NIST/AES-128";
		case kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384 : return @"NIST/AES-256";
		case kSCimpCipherSuite_SKEIN_AES256_ECC384          : return @"SKEIN/AES-256";
		case kSCimpCipherSuite_Symmetric_AES128             : return @"AES-128";
		case kSCimpCipherSuite_Symmetric_AES256             : return @"AES-256";
		default                                             : return @"";
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark NSError Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (NSError *)errorWithSCLError:(SCLError)err
{
	NSString *errStr = [self displayStringFromSCLError:err];
	
	NSDictionary *details = nil;
	if (errStr) {
		details = @{ NSLocalizedDescriptionKey : errStr };
	}
	
	return [NSError errorWithDomain:kSCErrorDomain code:err userInfo:details];
}

@end
