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


#import <Foundation/Foundation.h>


/*  StorageCipher *storageCipher = StorageCipher.new;

On first run:
 
  make a new storage key
  [storageCipher makeStorageKey];
 
  create a passphrase key
  [storageCipher makePassphraseKey: <your passphrase>];
 
  save encrypted version of storage key
 <keychain.storageKey> = storageCipher.storageItem;
 
  save passphrase rounds and salt
  <keychain.passMetaData> = storageCipher.passphraseItem;
 
To unlock
 
 restore passphrase rounds and salt
  storageCipher.passphraseItem =  <keychain.passMetaData> 

  load the passphrase key
  [storageCipher unlockWithPassphrase: <your passphrase>];
 
 load and decrypt the storage key
  storageCipher.storageItem = <keychain.storageKey> ;

To change Passphrase - assuming unlocked
 
 load the passphrase key
 [storageCipher makePassphraseKey: <your passphrase>];

 save encrypted version of storage key
 <keychain.storageKey> = storageCipher.storageItem;
 
 save passphrase rounds and salt
 <keychain.passMetaData> = storageCipher.passphraseItem;
 
 */

@interface StorageCipher : NSObject

@property (strong, nonatomic) NSData *storageItem;      // Encrypted form of the storageKey.
@property (strong, nonatomic) NSData *passphraseItem;   // passphrase meta data

@property (nonatomic, readonly) BOOL isLocked;

/* makeStorageKey is only called on first run to create a random key for encyption */
- (void) makeStorageKey;

/* update with a new passphase key to encrypt the storge key */
- (void) makePassphraseKey: (NSString *) passphrase;

/* unlockWithPassphrase is used to unlock the storageItem into a storage key */
- (BOOL) unlockWithPassphrase: (NSString *) passphrase;

/* lock locks out passphrase info. */
- (void) lock;

- (NSData *) encryptData: (NSData *) data;
- (NSData *) decryptData: (NSData *) data;

- (NSData *)   encryptedDataFromString: (NSString *) string;
- (NSString *) stringFromEncryptedData: (NSData *)   data;

+ (NSString *) uuid;
+ (NSData *) makeSCimpKey;

@end


@interface NSData (StorageCipher)

- (BOOL) isStorageItem;
- (BOOL) isPassphraseItem;

@end

