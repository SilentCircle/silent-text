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
//
//  SCkeys.h
 
#include "SCpubTypes.h"
#include "SCcrypto.h"

#ifndef Included_scckeys_h 	/* [ */
#define Included_scckeys_h

#define PUBKEY_HASH_LEN             32
#define SCKEY_LOCATOR_BYTES         20

// we need to do this to get tm_gmtoff
#ifndef __USE_BSD
#define __USE_BSD
#include <time.h>
#undef __USE_BSD
#endif


enum SCKeyType_
{
    kSCKeyType_Invalid           = 0,
    kSCKeyType_Symmetric,
    kSCKeyType_Public,
    kSCKeyType_Private, 
    kSCKeyType_Signature,
    kSCKeyType_PassPhrase,
    kSCKeyType_HMACcode,
    
    ENUM_FORCE( SCKeyType_ )
};
 
ENUM_TYPEDEF( SCKeyType_, SCKeyType   );
 
enum SCKeySuite_
{
    kSCKeySuite_AES128           = 0,
    kSCKeySuite_AES256           = 1,
    kSCKeySuite_ECC384           = 2,
    kSCKeySuite_ECC414           = 3, /*  Dan Bernstein Curve3617  */
 
    kSCKeySuite_2FISH256         = 4,  
    
    kSCKeySuite_Invalid           =  kEnumMaxValue,
    
    ENUM_FORCE( SCKeySuite_ )
};


ENUM_TYPEDEF( SCKeySuite_, SCKeySuite   );

typedef struct SCKey_Context *      SCKeyContextRef;

#define	kInvalidSCKeyContextRef		((SCKeyContextRef) NULL)

#define SCKeyContextRefIsValid( ref )		( (ref) != kInvalidSCKeyContextRef )

SCLError SCKeyNew(SCKeySuite         keySuite,
                  const uint8_t      *nonce, size_t nonceLen,
                  SCKeyContextRef   *ctx);

SCLError SCKeyCipherForKeySuite(SCKeySuite keySuite,
                                Cipher_Algorithm *algorithm,
                                size_t *keyLen);


SCLError SCKeyEncryptToPassPhrase(SCKeyContextRef   symCtx,
                            const uint8_t           *passphrase,
                            size_t                  passphraseLen,
                            SCKeyContextRef         *ctx);

SCLError SCKeyDecryptFromPassPhrase(SCKeyContextRef   passCtx,
                                  const uint8_t         *passphrase,
                                  size_t                passphraseLen,
                                  SCKeyContextRef       *symCtx);
 
SCLError SCKeyImport_ECC( ECC_ContextRef  ecc,
                         uint8_t          *nonce, unsigned long nonceLen,
                         SCKeyContextRef *ctx);

SCLError SCKeyExport_ECC(SCKeyContextRef  keyCTX,  ECC_ContextRef *ecc );

SCLError SCKeyExport_ANSI_X963(SCKeyContextRef  keyCTX, void *outData, size_t bufSize, size_t *datSize);

SCLError SCKeyImport_Symmetric(SCKeySuite         keySuite,
                               const void         *key,
                               const uint8_t      *nonce, size_t nonceLen,
                               SCKeyContextRef   *ctx);


SCLError SCKeyDeserialize( uint8_t *inData, size_t inLen, SCKeyContextRef *ctx);

DEPRECATED (SCLError SCKeySerializePrivate( SCKeyContextRef ctx,
                               uint8_t *encryptKey, size_t encryptKeyLen,
                               uint8_t **outData, size_t *outSize));


SCLError SCKeySerializePrivateWithSCKey(    SCKeyContextRef    ctx,
                                            SCKeyContextRef     storageKeyCtx,
                                            uint8_t **outData, size_t *outSize);

SCLError SCKeyIsLocked( SCKeyContextRef ctx, bool *locked);

DEPRECATED (SCLError SCKeyUnlock( SCKeyContextRef ctx, uint8_t *encryptKey, size_t encryptKeyLen) );

SCLError SCKeyUnlockWithSCKey( SCKeyContextRef ctx, SCKeyContextRef   storageKeyCtx);

SCLError SCKeySerialize( SCKeyContextRef ctx, uint8_t **outData, size_t *outSize);

SCLError SCKeySerialize_Fingerprint( SCKeyContextRef keyCtx, uint8_t **outData, size_t *outSize);

SCLError SCKeyDeserialize_Fingerprint( uint8_t *inData, size_t inLen,
                                      uint8_t **locatorDataOut, uint8_t **fpOut,
                                      uint8_t **ownerDataOut, size_t *ownDataLenOut,
                                      uint8_t **hashWordsOut, size_t *hashWordsLengthOut);

SCLError SCKeyVerify_Fingerprint(SCKeyContextRef  ctx, uint8_t *inData, size_t inLen);

void SCKeyFree(SCKeyContextRef  ctx);


enum SCKeyPropertyType_
{
    SCKeyPropertyType_Invalid       = 0,
    SCKeyPropertyType_UTF8String    = 1,
    SCKeyPropertyType_Binary        = 2,
    SCKeyPropertyType_Time          = 3,
    SCKeyPropertyType_Numeric       = 4,
    
    ENUM_FORCE( SCKeyPropertyType_ )
};

ENUM_TYPEDEF( SCKeyPropertyType_, SCKeyPropertyType   );

extern char *const kSCKeyProp_SCKeyType;

extern char *const kSCKeyProp_SCKeySuite;
extern char *const kSCKeyProp_SymmetricKey;
extern char *const kSCKeyProp_StartDate;
extern char *const kSCKeyProp_ExpireDate;
extern char *const kSCKeyProp_Locator;
extern char *const kSCKeyProp_EncryptedTo;
extern char *const kSCKeyProp_SignedBy;
extern char *const kSCKeyProp_Owner;
extern char *const kSCKeyProp_IV;
extern char *const kSCKeyProp_KeyHash;
extern char *const kSCKeyProp_PubKeyANSI_X963;

extern char *const kSCKeyProp_HMACcode;
extern char *const kSCKeyProp_Signature;  // for signing context only


SCLError SCKeySetProperty( SCKeyContextRef ctx,
                          const char *propName,  SCKeyPropertyType propType,
                          void *data,  size_t  datSize);

SCLError SCKeyGetProperty( SCKeyContextRef ctx, const char *propName,
                          SCKeyPropertyType *outPropType,  void *buffer, size_t bufSize, size_t *datSize);

SCLError SCKeyGetAllocatedProperty( SCKeyContextRef ctx,    const char *propName,
                                   SCKeyPropertyType *outPropType, void **outData, size_t *datSize);


SCLError SCKeyPublicEncrypt(    SCKeyContextRef  pubCtx,
                                void *inData, size_t inDataLen,
                                void *outData, size_t bufSize, size_t *outDataLen);

SCLError SCKeyPublicDecrypt(    SCKeyContextRef  privCtx,
                                void *inData, size_t inDataLen,
                                void *outData, size_t bufSize, size_t *outDataLen);

SCLError SCKeySignHash( SCKeyContextRef  ctx,
                       void *hash, size_t hashLen,
                       void *outSig, size_t bufSize, size_t *outSigLen);

SCLError SCKeyVerifyHash( SCKeyContextRef  ctx,
                        void *hash, size_t hashLen,
                        void *sig,  size_t sigLen);

SCLError SCKeyPublicEncryptKey( SCKeyContextRef  pubCtx,
                                SCKeyContextRef  symCtx,
                               uint8_t **outData, size_t *outSize);

SCLError SCKeyPublicDecryptKey( SCKeyContextRef  pubCtx,
                               SCKeyContextRef  symCtx );


/*
 I am removing SCKeyMakeHMACcode, I dont belive it is being used anywhere
    -- Vinnie 27-Oct-14
 */
DEPRECATED( SCLError SCKeyMakeHMACcode(SCKeySuite keySuite, void *PK, size_t PKlen,
                             void *nonce,   size_t nonceLen,
                             time_t         expireDate,
                             SCKeyContextRef signCtx,
                             SCKeyContextRef   *outCtx));

SCLError SCKeySign( SCKeyContextRef  privCtx,
                   void *hash, size_t hashLen,
                   uint8_t **outData, size_t *outSize);

SCLError SCKeyVerify( SCKeyContextRef  privCtx,
                   void *hash, size_t hashLen,
                   uint8_t *sig,  size_t sigLen);

SCLError SCKeySignKey(  SCKeyContextRef  signingCtx, SCKeyContextRef  keyCtx,  char* signingList[]) ;


SCLError SCKeyStorageEncrypt(SCKeyContextRef  symCtx,
                     const uint8_t *in, size_t in_len,
                             uint8_t **outData, size_t *outSize);

SCLError SCKeyStorageDecrypt(SCKeyContextRef  symCtx,
                             const uint8_t *in, size_t in_len,
                             uint8_t **outData, size_t *outSize);

SCLError SCKeyVerifySig( SCKeyContextRef  keyCtx,  char* signingList[], SCKeyContextRef  signingKeyCtx, SCKeyContextRef  sigCtx );

#endif /* Included_scckeys_h */ /* ] */
