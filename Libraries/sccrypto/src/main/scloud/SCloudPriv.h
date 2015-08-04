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
#ifndef Included_scloudpriv_h /* [ */
#define Included_scloudpriv_h


#include "SCloud.h"

#ifdef __clang__
#pragma mark
#pragma mark SCloud Private Defines
#endif

#define DEBUG_PROTOCOL 0
#define DEBUG_PACKETS 0
 

#define kSCloudProtocolVersion  0x02 


#define validateSCloudContext( s )		\
ValidateParam( scloudContextIsValid( s ) )



enum SCloudEncryptState_
{
    kSCloudState_Init        = 0,
    kSCloudState_Hashed,
    kSCloudState_Header,
    kSCloudState_Meta,
    kSCloudState_Data,
    kSCloudState_Pad,
    kSCloudState_Done,
    
    ENUM_FORCE( SCloudEncryptState_ )
};

ENUM_TYPEDEF( SCloudEncryptState_, SCloudEncryptState   );


enum SCloudKeySuite_
{
    kSCloudKeySuite_AES128           = 0,
    kSCloudKeySuite_AES256           = 1,
//    kSCloudKeySuite_3FISH256,        = 2,
    kSCloudKeySuite_ECC384           = 3,
     
    ENUM_FORCE( SCloudKeySuite_ )
};

ENUM_TYPEDEF( SCloudKeySuite_, SCloudKeySuite   );

typedef struct SCloudKey    SCloudKey;
struct SCloudKey
{
    SCloudKeySuite  keySuite;
    
    Cipher_Algorithm algorithm;
    size_t         symKeyLen;
    uint8_t        symKey[128];
    
    uint8_t        pubKey[256];
    
};


#define kSCloudContextMagic		0x53436C64
typedef struct SCloudContext        SCloudContext;
 
#define SCLOUD_TEMPBUF_LEN  (SCLOUD_BLOCK_LEN * 2)
struct SCloudContext 
{
    uint32_t                magic;
    SCloudEncryptState      state;
    CBC_ContextRef          cbc;
    
    bool                    bEncrypting;
    bool                    bJustDecryptMetaData;
    
    SCloudKey               key;
    uint8_t                locator[SCLOUD_LOCATOR_LEN];

    uint8_t                 *contextStr;
    size_t                  contextStrLen;

    uint8_t                 *dataBuffer;
    size_t                  dataLen;
    uint8_t                 *metaBuffer;
    size_t                  metaLen;
    
    /* for encrypting */
    uint8_t                 *buffPtr;
    size_t                  byteCount;
    
    /* for decrypting */
    uint8_t                 tmpBuf[SCLOUD_TEMPBUF_LEN];    /* for decrypting */
    size_t                 tmpCnt;
    
    
    size_t                  padLen;
         
    SCloudEventHandler      handler;        /* event callback handler */
    void*                   userValue;      
    
   
};

SCLError scloudDeserializeKey( uint8_t *inData, size_t inLen, SCloudKey *keyOut);

#endif       /* ] */

