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
//  StorageCipher.m
//  SilentText
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "StorageCipher.h"

#import <CommonCrypto/CommonKeyDerivation.h>

#include <tomcrypt.h>
#include "cryptowrappers.h"

#import "NSString+URLEncoding.h"

#define STORAGE_CIPHER_VERSION 1
#define STORAGE_KEY_BYTES 16
 

static SCLError PASS_TO_KEY_SETUP(
                           unsigned long  password_len,
                           unsigned long  key_len,
                           uint8_t        *salt,
                           unsigned long  salt_len,
                           uint32_t       *rounds_out)
{
    SCLError    err     = kSCLError_NoErr;
    int         status  = CRYPT_OK;
    
    err = RNG_GetBytes( salt, salt_len ); CKERR;
    
    // How many rounds to use so that it takes 0.1s ?
    uint rounds = CCCalibratePBKDF(kCCPBKDF2,
                                   password_len,
                                   salt_len,
                                   kCCPRFHmacAlgSHA256,
                                   key_len, 100);
    *rounds_out = rounds;
    
done:

    if(status != CRYPT_OK) {
        
        err = sCrypt2SCLError(status);
    }
    return err;
    
} // PASS_TO_KEY_SETUP()



static SCLError PASSPHRASE_HASH( const uint8_t  *key,
                                unsigned long  key_len,
                                uint8_t       *salt,
                                unsigned long  salt_len,
                                unsigned int   rounds,
                                uint8_t        *mac_buf,
                                unsigned long  mac_len)
{
    SCLError    err     = kSCLError_NoErr;
    int         status  = CRYPT_OK;
    
     MAC_ContextRef  macRef     = kInvalidMAC_ContextRef;
     
    err = MAC_Init(kMAC_Algorithm_HMAC, kHASH_Algorithm_SHA256, key, key_len, &macRef); CKERR
    err = MAC_Update( macRef, salt, salt_len); CKERR;
    err = MAC_Update( macRef, key, key_len); CKERR;
    err = MAC_Final( macRef, mac_buf, &mac_len); CKERR;
    
done:
    if(status != CRYPT_OK) {
        
        err = sCrypt2SCLError(status);
    }
    
     MAC_Free(macRef);
    
    return err;
}


typedef struct {
    uint8_t  version;
    uint8_t iv [STORAGE_KEY_BYTES];
    uint8_t key[STORAGE_KEY_BYTES];
} 
StorageKey;

#define SALT_BYTES 8

typedef struct {
    uint8_t  version;
    uint32_t rounds;
    uint8_t  salt[SALT_BYTES];
    uint8_t  hash [STORAGE_KEY_BYTES];
    
} 
PassphraseMetaData;


@implementation NSData (StorageCipher)

- (BOOL) isStorageItem
{
    BOOL OK = NO;
    
    StorageKey key;
    
    if(self.length == sizeof(StorageKey))
    {
        [self getBytes: &key length: sizeof(StorageKey)];
        if(key.version == STORAGE_CIPHER_VERSION)
            OK = YES;
    }
    
    return OK;
  
}
- (BOOL) isPassphraseItem
{
    
    BOOL OK = NO;
    
    PassphraseMetaData data;
    
    if(self.length == sizeof(PassphraseMetaData))
    {
        [self getBytes: &data length: sizeof(PassphraseMetaData)];
        if(data.version == STORAGE_CIPHER_VERSION)
            OK = YES;
    }
    
    return OK;
   
}

@end

@interface StorageCipher () {
    
@private
    
    uint8_t _passphraseKey[STORAGE_KEY_BYTES];
}

/* storageKey =  unlocked key & IV   STORAGE_KEY_BYTES */
@property (nonatomic) StorageKey storageKey;

/* passphraseMetaData   rounds and salt for passphrase */
@property (nonatomic) PassphraseMetaData passphraseMetaData;

@property (nonatomic, readwrite) BOOL isLocked;

@end

@implementation StorageCipher

@synthesize storageItem         = _storageItem;     // accessors for Encrypted form of the storageKey.
@synthesize storageKey          = _storageKey;
@synthesize passphraseMetaData = _passphraseMetaData;
@synthesize isLocked              = _isLocked;

- (id)init
{
	if ((self = [super init]))
	{
        ZERO(_storageKey.iv,  STORAGE_KEY_BYTES);
        ZERO(_storageKey.key, STORAGE_KEY_BYTES);
        
        _passphraseMetaData.rounds = 0;
        ZERO(_passphraseMetaData.salt, SALT_BYTES);
        
        ZERO(_passphraseKey, STORAGE_KEY_BYTES);
       _isLocked = YES;
        
 	}
	return self;
}

- (void) dealloc {
    
    ZERO(_storageKey.iv,  STORAGE_KEY_BYTES);
    ZERO(_storageKey.key, STORAGE_KEY_BYTES);

    _passphraseMetaData.rounds = 0;
    ZERO(_passphraseMetaData.salt, SALT_BYTES);
    
    ZERO(_passphraseKey, STORAGE_KEY_BYTES);
    _isLocked = YES;

} // -dealloc


#pragma mark - Accessor methods.



- (NSData *) storageItem {
    
    SCLError err = kSCLError_NoErr;
    uint8_t locked_key[STORAGE_KEY_BYTES];
    NSData *item = nil;
    
    err =  ECB_Encrypt(kCipher_Algorithm_AES128, 
                       _passphraseKey, _storageKey.key, STORAGE_KEY_BYTES, 
                       locked_key); CKERR;
    COPY(locked_key, _storageKey.key, STORAGE_KEY_BYTES);
    
    item = [NSData dataWithBytes: &_storageKey length: sizeof(StorageKey)];
    
    self.storageItem = item; // Decrypt the key.
    
done:
    
    ZERO(locked_key, STORAGE_KEY_BYTES);    

    return item;
    
} // -storageItem


- (void) setStorageItem: (NSData *)storageItem {
    
    _storageItem = storageItem;
    
    uint8_t unlocked_key[STORAGE_KEY_BYTES];

    if (storageItem) {
        
        [storageItem getBytes: &_storageKey length: sizeof(StorageKey)];
        
        SCLError err = kSCLError_NoErr;
        
        if(_storageKey.version != STORAGE_CIPHER_VERSION)
             RETERR(kSCLError_CorruptData);
         
        err =  ECB_Decrypt(kCipher_Algorithm_AES128, 
                           _passphraseKey, _storageKey.key, STORAGE_KEY_BYTES, 
                           unlocked_key); CKERR;
        COPY(unlocked_key, _storageKey.key, STORAGE_KEY_BYTES);
    }
done:
    
    ZERO(unlocked_key, STORAGE_KEY_BYTES);
    
} // -setStorageItem:


- (NSData *) passphraseItem {
    
    NSData *item = [NSData dataWithBytes: &_passphraseMetaData length: sizeof(PassphraseMetaData)];
     
    return item;
    
} // -passphraseItem


- (void) setPassphraseItem: (NSData *) passphraseItem {
    
    _storageItem = nil;

    [passphraseItem getBytes: &_passphraseMetaData length: sizeof(PassphraseMetaData)];
    
    if(_passphraseMetaData.version != STORAGE_CIPHER_VERSION)
    {
    // do something here 
    }
} // -setPassphraseItem:

#pragma mark - Instance methods.


- (void) makeStorageKey {
    
    SCLError        err  = kSCLError_NoErr;
    HASH_ContextRef hash = kInvalidHASH_ContextRef;

    // generate a master key and IV for local  message storage encryption
    err = RNG_GetBytes( _storageKey.key, STORAGE_KEY_BYTES ); CKERR;
    
    err = HASH_Init(  kHASH_Algorithm_SHA256, &hash ); CKERR;
    err = HASH_Update( hash, _storageKey.key, STORAGE_KEY_BYTES ); CKERR;
    err = HASH_Final(  hash, _storageKey.iv ); CKERR;
    
    _storageKey.version = STORAGE_CIPHER_VERSION;

done:
    
    if (IsSCLError(err)) {
        
        ZERO(_storageKey.iv,  STORAGE_KEY_BYTES);
        ZERO(_storageKey.key, STORAGE_KEY_BYTES);
    }
    HASH_Free(hash);
    
} // -makeStorageKey

- (void) lock
{
      
    ZERO(_passphraseKey, STORAGE_KEY_BYTES);
    _isLocked = YES;
    
}

- (BOOL) unlockWithPassphrase: (NSString *) passphrase
{
    SCLError    err     = kSCLError_NoErr;
    uint8_t     hash [STORAGE_KEY_BYTES];
   
    _isLocked = YES;
    ZERO(_passphraseKey, STORAGE_KEY_BYTES);
    
    if (_passphraseMetaData.rounds)
    {
         const char *utf8Str = passphrase.UTF8String;
 
        if( _passphraseMetaData.version != STORAGE_CIPHER_VERSION)
              RETERR( kSCLError_FeatureNotAvailable);
          
        // Derive a key from the passphrase.
        err = PASS_TO_KEY((uint8_t *)utf8Str, strlen(utf8Str),
                          _passphraseMetaData.salt, SALT_BYTES,
                          _passphraseMetaData.rounds,
                          _passphraseKey, STORAGE_KEY_BYTES); CKERR;
        
        // Derive passphrase hash from the passphrase.
        err = PASSPHRASE_HASH(_passphraseKey, STORAGE_KEY_BYTES,
                              _passphraseMetaData.salt, SALT_BYTES,
                              _passphraseMetaData.rounds,
                              hash, STORAGE_KEY_BYTES); CKERR;
        
        if(! CMP(hash, _passphraseMetaData.hash, STORAGE_KEY_BYTES))
           RETERR( kSCLError_SecretsMismatch);
        
        _isLocked = NO;
        };
    
done:
    return  (IsntSCLError(err));
    
}

- (void) makePassphraseKey: (NSString *) passphrase {
    
    SCLError    err     = kSCLError_NoErr;

    const char *utf8Str = passphrase.UTF8String;
  
    _isLocked = YES;
    ZERO(_passphraseKey, STORAGE_KEY_BYTES);

    _passphraseMetaData.version = STORAGE_CIPHER_VERSION;
    
    // Calculate how many rounds we need on this machine for passphrase hashing.
    err = PASS_TO_KEY_SETUP(strlen(utf8Str), STORAGE_KEY_BYTES, 
                             _passphraseMetaData.salt, SALT_BYTES, 
                            &_passphraseMetaData.rounds); CKERR;

    // Derive a key from the passphrase.
    err = PASS_TO_KEY((uint8_t *)utf8Str, strlen(utf8Str),
                      _passphraseMetaData.salt, SALT_BYTES,
                      _passphraseMetaData.rounds,
                      _passphraseKey, STORAGE_KEY_BYTES); CKERR;
    
    // Derive passphrase hash from the passphrase.
    err = PASSPHRASE_HASH(_passphraseKey, STORAGE_KEY_BYTES,
                          _passphraseMetaData.salt, SALT_BYTES,
                          _passphraseMetaData.rounds,
                          _passphraseMetaData.hash, STORAGE_KEY_BYTES); CKERR;
 
    _isLocked = NO;
    
done:
    
    if (IsSCLError(err)) {
        
        _passphraseMetaData.rounds = 0;
        ZERO(_passphraseMetaData.salt, SALT_BYTES);
        ZERO(_passphraseKey, STORAGE_KEY_BYTES);
    }
    
} // -makePassphraseKey:
 

- (NSData *) encryptData: (NSData *) data {
    
    SCLError  err = kSCLError_NoErr;
    NSData   *encryptedData = nil;
    
    uint8_t *bytes  = NULL;
    size_t   length = 0;
    
    if (_passphraseMetaData.rounds) {
        
        err = MSG_Encrypt(_storageKey.key, STORAGE_KEY_BYTES, _storageKey.iv,
                          data.bytes, data.length,
                          &bytes, &length); CKERR;
        encryptedData = [NSData dataWithBytesNoCopy: bytes length: length freeWhenDone: YES];
    }
    else { encryptedData = data; }
    
done:
    
    return encryptedData;
    
} // -encryptData:


- (NSData *) decryptData: (NSData *) data {
    
    SCLError  err    = kSCLError_NoErr;
    NSData   *decryptedData = nil;
    
    uint8_t *bytes  = NULL;
    size_t   length = 0;
    
    if (_passphraseMetaData.rounds) {
        
        err = MSG_Decrypt(_storageKey.key, STORAGE_KEY_BYTES, _storageKey.iv, 
                          data.bytes, data.length, &bytes, &length); CKERR;
        
        decryptedData = [NSData dataWithBytesNoCopy: bytes length: length freeWhenDone: YES];
    }
    else { decryptedData = data; }

done:
    
    return decryptedData;
    
} // -decryptData:


- (NSData *) encryptedDataFromString: (NSString *) string {
    
    SCLError    err     = kSCLError_NoErr;
    const char *utf8Str = string.UTF8String;
    NSData *data = nil;

    uint8_t *bytes  = NULL;
    size_t   length = 0;
    
    err = MSG_Encrypt(_storageKey.key, STORAGE_KEY_BYTES, _storageKey.iv,
                      (uint8_t*)utf8Str, strlen(utf8Str),
                      &bytes, &length); CKERR;
    data = [NSData dataWithBytesNoCopy: bytes length: length freeWhenDone: YES];
    
done:
    
    return data;

} // -encryptedDataFromString:


- (NSString *) stringFromEncryptedData: (NSData *) data {
    
    SCLError  err    = kSCLError_NoErr;
    NSString *string = nil;

    uint8_t *bytes  = NULL;
    size_t   length = 0;
    
    err = MSG_Decrypt(_storageKey.key, STORAGE_KEY_BYTES, _storageKey.iv, 
                      data.bytes, data.length, &bytes, &length); CKERR;

    string = [NSString.alloc initWithBytesNoCopy: bytes 
                                          length: length 
                                        encoding: NSUTF8StringEncoding 
                                    freeWhenDone: YES];
done:
    
    return string;
    
} // -stringFromEncryptedData:


+ (NSString *) uuid {
    
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    
    NSString *uuidString = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    
    CFRelease(uuid);
    
    return uuidString;
    
} // +uuid


+ (NSData *) makeSCimpKey {
    
    SCLError err  = kSCLError_NoErr;

    size_t    keyLength = sizeof(StorageKey);
    uint8_t  _scimpKey[keyLength];
    NSData   *scimpKey = nil;
    
    err = RNG_GetBytes( _scimpKey, keyLength ); CKERR;
    
done:

    if (IsntSCLError(err)) {
        
        scimpKey = [NSData dataWithBytes: _scimpKey length: keyLength];
    }
    ZERO(_scimpKey, keyLength);
    
    return scimpKey;
    
} // -makeSCimpKey

@end
