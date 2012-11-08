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


#ifndef Included_sccryptowrappers_h 	/* [ */
#define Included_sccryptowrappers_h

#include "SCpubTypes.h"


typedef struct HASH_Context *      HASH_ContextRef;
 
#define	kInvalidHASH_ContextRef		((HASH_ContextRef) NULL)
 
#define HASH_ContextRefIsValid( ref )		( (ref) != kInvalidHASH_ContextRef )
 
/* HASH function wrappers */

enum HASH_Algorithm
{
    kHASH_Algorithm_Invalid         = 0,
    kHASH_Algorithm_SHA1            = 1,
    kHASH_Algorithm_SHA224          = 2,
    kHASH_Algorithm_SHA256          = 3,
    kHASH_Algorithm_SHA384          = 4,
    kHASH_Algorithm_SHA512          = 5,
    kHASH_Algorithm_SKEIN256        = 6,
    kHASH_Algorithm_SKEIN512        = 7,
    kHASH_Algorithm_SKEIN1024       = 8,
    kHASH_Algorithm_SHA512_256      = 9,
};

typedef enum HASH_Algorithm HASH_Algorithm;

SCLError HASH_Init(HASH_Algorithm algorithm, HASH_ContextRef * ctx);

SCLError HASH_Update(HASH_ContextRef ctx, const void *data, size_t dataLength);

SCLError HASH_Final(HASH_ContextRef  ctx, void *hashOut);

SCLError HASH_GetSize(HASH_ContextRef  ctx, size_t *hashSize);

void HASH_Free(HASH_ContextRef  ctx);

/* Message  Authentication Code wrappers */
 
enum MAC_Algorithm
{
    kMAC_Algorithm_Invalid         = 0,
    kMAC_Algorithm_HMAC            = 1,
    kMAC_Algorithm_SKEIN          = 2,
};

typedef enum MAC_Algorithm MAC_Algorithm;

typedef struct MAC_Context *      MAC_ContextRef;

#define	kInvalidMAC_ContextRef		((MAC_ContextRef) NULL)

#define MAC_ContextRefIsValid( ref )		( (ref) != kInvalidMAC_ContextRef )

SCLError MAC_Init(MAC_Algorithm     mac,
                  HASH_Algorithm    hash, 
                  const void        *macKey, 
                  size_t            macKeyLen, 
                  MAC_ContextRef    *ctx);

SCLError MAC_Update(MAC_ContextRef  ctx,
                    const void      *data, 
                    size_t          dataLength);

SCLError MAC_Final(MAC_ContextRef   ctx,
                   void             *macOut,   
                   size_t           *resultLen);

void MAC_Free(MAC_ContextRef  ctx);

SCLError MAC_HashSize( MAC_ContextRef  ctx,
                        size_t         * bytes);

enum Cipher_Algorithm
{
    kCipher_Algorithm_Invalid        = 0,
    kCipher_Algorithm_AES128         = 1,
    kCipher_Algorithm_AES192         = 2,
    kCipher_Algorithm_AES256         = 3,
  };

typedef enum Cipher_Algorithm Cipher_Algorithm;

typedef struct CBC_Context *      CBC_ContextRef;

#define	kInvalidCBC_ContextRef		((CBC_ContextRef) NULL)

#define CBC_ContextRefIsValid( ref )		( (ref) != kInvalidCBC_ContextRef )


SCLError CBC_Init(Cipher_Algorithm cipher, 
                  const void *key, 
                  const void *iv, 
                  CBC_ContextRef * ctxOut);

SCLError CBC_Encrypt(CBC_ContextRef ctx,
                     const void *	in,
                     size_t         bytesIn,
                     void *         out );

SCLError CBC_Decrypt(CBC_ContextRef ctx,
                     const void *	in,
                     size_t         bytesIn,
                     void *         out );

void CBC_Free(CBC_ContextRef  ctx);

SCLError ECB_Encrypt(Cipher_Algorithm algorithm,
                     const void *	key,
                     const void *	in,
                     size_t         bytesIn,
                     void *         out );

SCLError ECB_Decrypt(Cipher_Algorithm algorithm,
                     const void *	key,
                     const void *	in,
                     size_t         bytesIn,
                     void *         out );


typedef struct ECC_Context *      ECC_ContextRef;

#define	kInvalidECC_ContextRef		((ECC_ContextRef) NULL)

#define ECC_ContextRefIsValid( ref )		( (ref) != kInvalidECC_ContextRef )

SCLError ECC_Init(ECC_ContextRef * ctx);

void ECC_Free(ECC_ContextRef  ctx);

SCLError ECC_Generate(ECC_ContextRef  ctx,
                      int           keysize );

SCLError ECC_Export(ECC_ContextRef  ctx,
                    int             exportPrivate, 
                    void            *outData, 
                    size_t          bufSize, 
                    size_t          *datSize);

SCLError ECC_Import(ECC_ContextRef  ctx,   void *in, size_t inlen );

SCLError ECC_Import_ANSI_X963(ECC_ContextRef  ctx,   void *in, size_t inlen );

SCLError ECC_Export_ANSI_X963(ECC_ContextRef  ctx, void *outData, size_t bufSize, size_t *datSize);

SCLError ECC_SharedSecret (ECC_ContextRef privCtx,
                           ECC_ContextRef  pubCtx, 
                           void *outZ, 
                           size_t bufSize, 
                           size_t *datSize);

SCLError ECC_KeySize( ECC_ContextRef  ctx, size_t * bits);
 
SCLError SCLGetErrorString( SCLError err,  size_t	bufSize, char *outString);

SCLError GCM_Encrypt(uint8_t *key, size_t keyLen, 
                     uint8_t *seq, size_t seqLen, 
                     const uint8_t *in, size_t inLen,
                     uint8_t **outData, size_t *outSize, 
                     uint8_t *outTag, size_t *outTagSize);

SCLError GCM_Decrypt(uint8_t *key,  size_t keyLen, 
                     uint8_t *seq,  size_t seqLen, 
                     uint8_t *in,   size_t inLen,
                     uint8_t *tag,      size_t tagSize, 
                     uint8_t **outData, size_t *outSize);

// CCM_Encrypt  need you to specify the tagSize in 

SCLError CCM_Encrypt(uint8_t *key, size_t keyLen,
                     uint8_t *seq, size_t seqLen, 
                     const uint8_t *in, size_t inLen,
                     uint8_t **outData, size_t *outSize, 
                     uint8_t *outTag,   size_t tagSize);

// CCM_Decrypt will only compare as many bytes of the tag as you specify in tagSize
// we need to be careful with CCM to not leak key information, an easy way to do
// that is to only export half the hash.


SCLError CCM_Decrypt(uint8_t *key,  size_t keyLen,
                     uint8_t *seq,  size_t seqLen, 
                     uint8_t *in,   size_t inLen,
                     uint8_t *tag,      size_t tagSize, 
                     uint8_t **outData, size_t *outSize);

SCLError MSG_Encrypt(uint8_t *key, size_t key_len,
                     const uint8_t *iv,
                     const uint8_t *in, size_t in_len,
                     uint8_t **outData, size_t *outSize);

SCLError MSG_Decrypt(uint8_t *key, size_t key_len,
                     const uint8_t *iv,
                     const uint8_t *in, size_t in_len,
                     uint8_t **outData, size_t *outSize);


SCLError PASS_TO_KEY(const uint8_t  *password,
                     unsigned long  password_len,
                     uint8_t       *salt,
                     unsigned long  salt_len,
                     unsigned int   rounds,
                     uint8_t        *key_buf,
                     unsigned long  key_len );

SCLError RNG_GetBytes(
                       void *         out,
                       size_t         outLen 
                       );


SCLError sCrypt2SCLError(int t_err);

 #endif /* Included_sccryptowrappers_h */ /* ] */


