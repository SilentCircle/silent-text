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
#include "SCcrypto.h"
#include "SCimp.h"
#include "SCimpPriv.h"
#include "SCutilities.h"
#include "SCkeys.h"

/*____________________________________________________________________________
 validity test  
 ____________________________________________________________________________*/

bool scimpContextIsValid( const SCimpContext * ref)
{
	bool	valid	= false;
	
	valid	= IsntNull( ref ) && ref->magic	 == kSCimpContextMagic;
	
	return( valid );
}

/*____________________________________________________________________________
 Public Functions
 ____________________________________________________________________________*/



/**
 <A short one line description>
 
 <Longer description>
 <May span multiple lines or paragraphs as needed>
 
 @param  Description of method's or function's input parameter
 @param  ...
 @return Description of the return value
 */

SCLError SCimpNew(
           const char*              meStr, 
           const char*              youStr,
           SCimpContextRef *       outscimp 
           )
{
    SCLError                 err = kSCLError_NoErr;
    
    SCimpContext*      ctx = NULL;
    
    ValidateParam(outscimp);
      
    ctx = XMALLOC(sizeof (SCimpContext)); CKNULL(ctx);
    
    ZERO(ctx, sizeof(SCimpContext));
    ctx->magic = kSCimpContextMagic;
    ctx->method = kSCimpMethod_DH;
      
    ctx->transQueue.first = 0;
    ctx->transQueue.last = TRANS_QUEUESIZE-1;
    ctx->transQueue.count = 0;
 
    scResetSCimpContext(ctx, true);
    
    pthread_mutex_init(&ctx->mp , NULL);
    
    if(meStr)
    {
        ctx->meStr = XMALLOC( strlen(meStr)+1 ); CKNULL(ctx->meStr);
        strcpy(ctx->meStr, meStr);
    }
    
    if(youStr)
    {
        ctx->youStr = XMALLOC( strlen(youStr)+1 ); CKNULL(ctx->youStr);
        strcpy(ctx->youStr, youStr);
    }
    *outscimp = ctx; 
    
  //  scEventAdviseSaveState(ctx);
done:
    return err;
}

SCLError SCimpStartDH(SCimpContextRef ctx)
{
    SCLError err = kSCLError_NoErr;
    
    validateSCimpContext(ctx);
    
    
    ctx->isInitiator   = true;
    
    err = scTriggerSCimpTransition(ctx, kSCimpTrans_StartDH, NULL); CKERR;
  
    
done:
    return err;
    
}

SCLError SCimpResetKeys(SCimpContextRef ctx)
{
    SCLError err = kSCLError_NoErr;
    
    validateSCimpContext(ctx);
     
    ctx->isInitiator   = true;
    
    err = scTriggerSCimpTransition(ctx, kSCimpTrans_Reset, NULL); CKERR;
    
    
done:
    return err;
    
}

SCLError SCimpSetPrivateKey(SCimpContextRef    scimp,
                            SCKeyContextRef    privKey )
{
    SCLError                 err = kSCLError_NoErr;
    SCKeyType  keyType;
    time_t     expireDate;
    time_t     now;
    double      diff_t;
    bool        isLocked = true;

    validateSCimpContext(scimp);
    ValidateParam(privKey);
    
    // check params
    err = SCKeyGetProperty(privKey, kSCKeyProp_SCKeyType,   NULL,  &keyType, sizeof(SCKeyType),  NULL); CKERR;
    ASSERTERR(keyType != kSCKeyType_Private, kSCLError_BadParams);
     
    // check keydates
    time(&now);
   
    err = SCKeyGetProperty(privKey, kSCKeyProp_ExpireDate,  NULL,  &expireDate, sizeof(time_t),  NULL); CKERR;
    diff_t = difftime(now, expireDate);
    ASSERTERR(diff_t>0, kSCLError_KeyExpired);
 
    // cant be locked
    err = SCKeyIsLocked(privKey,&isLocked); CKERR;
    ASSERTERR(isLocked, kSCLError_KeyLocked);

    // if we already had a private key set, then free it
    if ( (scimp->scKey) && (scimp->scKey != privKey) )
        SCKeyFree(scimp->scKey);

    scimp->scKey = privKey;
    
done:
    return err;

 }

SCLError SCimpStartPublicKey(SCimpContextRef    ctx,
                             SCKeyContextRef    pubKey,
                             time_t             expireDate )
{
    SCLError        err         = kSCLError_NoErr;
    SCKeyType       keyType;
    SCKeySuite      keySuite    = kSCKeySuite_Invalid;
    int             keyBits     = 384;
    time_t          pubExpire;
    time_t          now;
    double          diff_t;
    
    uint8_t*        keyData = NULL;
      
    ValidateParam(pubKey);
     
    ctx->state          = kSCimpState_Init;
    ctx->isInitiator    = true;
    ctx->version        = kSCimpProtocolVersion2;
    ctx->method         = kSCimpMethod_PubKey;
    
    ctx->hasKeys            = false;
    ctx->csMatches          = false;
    
    
    if(ctx->privKeyDH)
    {
        ECC_Free(ctx->privKeyDH);
        ctx->privKeyDH = kInvalidECC_ContextRef;
    }

    if(ctx->privKey0)
    {
        ECC_Free(ctx->privKey0);
        ctx->privKey0 = kInvalidECC_ContextRef;
    }

    if(ctx->pubKey)
    {
        ECC_Free(ctx->pubKey);
        ctx->pubKey = kInvalidECC_ContextRef;
    }
    
    if(ctx->HtotalState)
    {
        HASH_Free(ctx->HtotalState);
        ctx->HtotalState = kInvalidHASH_ContextRef;
    }
    
    if(ctx->pubKeyLocator)
    {
        XFREE(ctx->pubKeyLocator);
        ctx->pubKeyLocator = NULL;
    }
    
    ZERO(ctx->Cs1,  SCIMP_KEY_LEN);
    
    ZERO(ctx->Rcv,  sizeof(ctx->Rcv));
    ctx->rcvIndex = 0;
    
    ZERO(ctx->Ksnd, SCIMP_KEY_LEN);
    ZERO(ctx->Hcs,  SCIMP_MAC_LEN);
    ZERO(ctx->Hpki, SCIMP_HASH_LEN);
    ZERO(ctx->MACi, SCIMP_MAC_LEN);
    ZERO(ctx->MACr, SCIMP_MAC_LEN);

     err = SCKeyGetProperty(pubKey, kSCKeyProp_SCKeyType,   NULL,  &keyType, sizeof(SCKeyType),  NULL); CKERR;
    ASSERTERR((keyType != kSCKeyType_Public) && (keyType != kSCKeyType_Private), kSCLError_BadParams);
    
    // create proper keytype to remote with
    err =  SCKeyGetProperty(pubKey, kSCKeyProp_SCKeySuite, NULL,  &keySuite, sizeof(SCKeySuite),  NULL); CKERR;
    keyBits = keySuite == kSCKeySuite_ECC414?414:384;
    
    // correct for downgrading ciphers.
    if(ctx->cipherSuite == kSCimpCipherSuite_SKEIN_2FISH_ECC414 && keySuite == kSCKeySuite_ECC384)
        ctx->cipherSuite = kSCimpCipherSuite_SKEIN_AES256_ECC384;
    // EA: also test upgrading ciphers from 384 to 414
    else if ( (keySuite == kSCKeySuite_ECC414) &&
   			 ((ctx->cipherSuite == kSCimpCipherSuite_SKEIN_AES256_ECC384) || (ctx->cipherSuite == kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384)) )
   		ctx->cipherSuite = kSCimpCipherSuite_SKEIN_2FISH_ECC414;

    // check pub key dates
    time(&now);
    err = SCKeyGetProperty(pubKey, kSCKeyProp_ExpireDate,  NULL,  &pubExpire, sizeof(time_t),  NULL); CKERR;
    if(pubExpire)
    {
        diff_t = difftime(now, pubExpire);
        ASSERTERR(diff_t>0, kSCLError_KeyExpired);
    }
    
    // copy the the public key
    err = SCKeyExport_ECC(pubKey,  &ctx->pubKey ); CKERR;

    // copy the key locator
    err = SCKeyGetAllocatedProperty(pubKey, kSCKeyProp_Locator,NULL,  (void*)&keyData , NULL); CKERR;
    ctx->pubKeyLocator = (char *)keyData;
    
    /* create privkey to initiate  with */
    err = ECC_Init(&ctx->privKey0); CKERR;
    err = ECC_Generate(ctx->privKey0,keyBits ); CKERR;
  
    /* create privkey to DH  with LATER */
    err = ECC_Init(&ctx->privKeyDH); CKERR;
    err = ECC_Generate(ctx->privKeyDH, keyBits); CKERR;
   
     ctx->state  = kSCimpState_PKInit;
    
    scEventAdviseSaveState(ctx);
 
done:
    return err;

}


SCLError SCimpNewSymmetric( SCKeyContextRef      key,
                            const char*          threadStr,
                            SCimpContextRef *    outScimp
                           ) 
{
    SCLError                 err = kSCLError_NoErr;
    
    SCimpContext*      ctx = NULL;
 
    ValidateParam(outScimp);
    
    ctx = XMALLOC(sizeof (SCimpContext)); CKNULL(ctx);
    
    ZERO(ctx, sizeof(SCimpContext));
    ctx->magic = kSCimpContextMagic;
    ctx->method = kSCimpMethod_Symmetric;
    
    ctx->transQueue.first = 0;
    ctx->transQueue.last = TRANS_QUEUESIZE-1;
    ctx->transQueue.count = 0;
    
    scResetSCimpContext(ctx, true);
    
    pthread_mutex_init(&ctx->mp , NULL);
  
    if(key)
    {
        err = sComputeKeysSymmetric(ctx, threadStr, key); CKERR;
        
        ctx->state = kSCimpState_Ready;
 
        scEventAdviseSaveState(ctx);
        
        err = scEventKeyed(ctx, NULL);  CKERR;

    }
    else
    {
        ctx->method = kSCimpMethod_Symmetric;

    }
    
    *outScimp = ctx;
    
done:
    

    return err;
}

SCLError SCimpUpdateSymmetricKey( SCimpContextRef       ctx,
                                   const char*          threadStr,
                                    SCKeyContextRef      key  )
{
    SCLError                 err = kSCLError_NoErr;
    
    
    validateSCimpContext(ctx);
    ValidateParam(key);
    ValidateParam(isScimpSymmetric(ctx));
    
    err = sComputeKeysSymmetric(ctx, threadStr, key); CKERR;
    
     scEventAdviseSaveState(ctx);
    
    err = scEventKeyed(ctx, NULL);  CKERR;
    
done:
    
    
    return err;

}

#define MAX_SCIMP_BLOB_SIZE 4096
#define STORAGEKEY_LEN 32
#define MAX_SEED_KEYS_TO_STORE 8	// NOTE: 16 overloads the buffer blob size 4096

SCLError saveStateInternal(SCimpContextRef ctx, uint8_t **outBlob, size_t *blobSize)
{
    SCLError             err         = kSCLError_NoErr;
 
    uint8_t* buffer = NULL;        // currently this is 2160 bytes
    size_t  bufLen = 0;
    
    uint8_t *p = NULL;
    uint8_t *lenP = NULL;
    int     i;
    
    size_t		           PKlen = PK_ALLOC_SIZE;
    uint8_t                *PK = NULL;
    
    uint8_t                 *hashState = NULL;
    size_t                  hashStateLen = kHASH_ContextAllocSize;
    
    uint8_t     storagekey[STORAGEKEY_LEN] ={0};
    uint8_t*    keyData = NULL;
    size_t      keyDataLen = 0;

    validateSCimpContext(ctx);
    ValidateParam(outBlob);
    ValidateParam(blobSize);
    
    buffer = XMALLOC(MAX_SCIMP_BLOB_SIZE); ; CKNULL(buffer);
     
    //must be in ready state
    
    p = buffer;
    
    sStore32( ctx->magic, &p);
    lenP = p;
    p+= sizeof(uint16_t); // skip 16 bits (we'll fill that in later)
    sStore8( kSCimpBlobVersion, &p);
    sStore8( ctx->version, &p);
    sStore8( ctx->method, &p);
    sStore8( ctx->state, &p);
    sStore8( ctx->cipherSuite, &p);
    sStore8( ctx->sasMethod, &p);
    sStore8( ctx->msgFormat, &p);

    // added the logging kevel for kScimpBlobVersion10 packets
    sStore8( ctx->loggingLevel, &p);
    
    sStoreArray(ctx->SessionID, sizeof(ctx->SessionID), &p );
    
    sStore8(ctx->rcvIndex, &p);
    
    for(i = 0; i< SCIMP_RCV_QUEUE_SIZE; i++)
    {
        sStoreArray(ctx->Rcv[i].key, SCIMP_KEY_LEN, &p );
        sStore64(ctx->Rcv[i].index, &p );
    }

	// count number of dormant seed keys
	uint16_t seedCount = 0;
	Stack *seedKey = ctx->dormantSeedKeys;
	while (seedKey) {
		seedCount++;
		if (seedCount >= MAX_SEED_KEYS_TO_STORE)
			break;
		seedKey = seedKey->next;
	}
	sStore16(seedCount, &p);
	// write the seed keys (up to seedCount)
	seedKey = ctx->dormantSeedKeys;
	uint16_t idx = 0;
	while (idx < seedCount) {
		CommKeyPair *keyPair = (CommKeyPair *)seedKey->data;
        sStoreArray(keyPair->key, SCIMP_KEY_LEN, &p );
        sStore64(keyPair->index, &p );
		seedKey = seedKey->next;
		idx++;
	}

    sStoreArray(ctx->Ksnd, sizeof(ctx->Ksnd), &p );
    sStore64(ctx->Isnd, &p );
    sStore16(ctx->Ioffset, &p );
    
    sStoreArray(ctx->Cs, sizeof(ctx->Cs), &p );
    sStoreArray(ctx->Cs1, sizeof(ctx->Cs1), &p );
    
    sStoreArray(ctx->Kdk2, sizeof(ctx->Kdk2), &p );
    sStore16(ctx->KdkLen, &p );

    if(ctx->ctxStrLen)
    {
        sStore16(ctx->ctxStrLen, &p);
        sStoreArray(ctx->ctxStr, ctx->ctxStrLen,&p);
    }
    else
    {
        sStore16(0, &p);
    }
    
    
    sStoreArray(ctx->Hcs, sizeof(ctx->Hcs), &p );
    sStoreArray(ctx->Hpki, sizeof(ctx->Hpki), &p );
    sStoreArray(ctx->MACi, sizeof(ctx->MACi), &p );
    sStoreArray(ctx->MACr, sizeof(ctx->MACr), &p );
    
    sStore8( ctx->isInitiator, &p);
    sStore8( ctx->hasCs, &p);
    sStore8( ctx->csMatches, &p);
    sStore8( ctx->hasKeys, &p);
    sStore64( ctx->SAS, &p);
    sStoreArray(&ctx->keyedTime, sizeof(ctx->keyedTime), &p );
    
    if(ctx->meStr)
    {
        sStore8( strlen(ctx->meStr)+1 , &p); // note: we store the null-termination byte
        sStoreArray(ctx->meStr, strlen(ctx->meStr) +1, &p); // note: we store the null-termination byte
    }
    else
        sStore8(0,&p);
    
    if(ctx->youStr)
    {
        sStore8( strlen(ctx->youStr)+1 , &p);
        sStoreArray(ctx->youStr, strlen(ctx->youStr) +1, &p);
    }
    else
        sStore8(0,&p);
    
    if(ctx->privKey0)
    {
        PK = XMALLOC(PK_ALLOC_SIZE); CKNULL(PK);
        err = ECC_Export(ctx->privKey0, true, PK, PK_ALLOC_SIZE, &PKlen); CKERR;
        sStore8(PKlen, &p);
        sStoreArray(PK, PKlen,&p);
        ZERO(PK, PK_ALLOC_SIZE);
        XFREE(PK);
        PK = NULL;
     }
    else
    {
        sStore8(0, &p);
    }

    if(ctx->privKeyDH)
    {
        PK = XMALLOC(PK_ALLOC_SIZE); CKNULL(PK);
        err = ECC_Export(ctx->privKeyDH, true, PK, PK_ALLOC_SIZE, &PKlen); CKERR;
        sStore8(PKlen, &p);
        sStoreArray(PK, PKlen,&p);
        ZERO(PK, PK_ALLOC_SIZE);
        XFREE(PK);
        PK = NULL;
    }
    else
    {
        sStore8(0, &p);
    }

     if(ctx->pubKey)
     {
        PK = XMALLOC(PK_ALLOC_SIZE); CKNULL(PK);
        err = ECC_Export(ctx->pubKey, false, PK, PK_ALLOC_SIZE, &PKlen); CKERR;
         
        sStore8(PKlen, &p);
        sStoreArray(PK, PKlen,&p);
         
        ZERO(PK, PK_ALLOC_SIZE);
        XFREE(PK);
        PK = NULL;
    }
    else
    {
        sStore8(0, &p);
    }
    
    if(ctx->pubKeyLocator)
    {
        sStore8( strlen(ctx->pubKeyLocator)+1 , &p);
        sStoreArray(ctx->pubKeyLocator, strlen(ctx->pubKeyLocator) +1, &p);
    }
    else
        sStore8(0,&p);

    
    if(ctx->HtotalState)
    {
        hashState = XMALLOC(kHASH_ContextAllocSize); CKNULL(hashState);
        err = HASH_Export(ctx->HtotalState, hashState, hashStateLen, &hashStateLen);CKERR;
        
        sStore16(hashStateLen, &p);
        sStoreArray(hashState, hashStateLen,&p);
    }
    else
    {
        sStore16(0, &p);
    }
    
 
    if(ctx->scKey)
    {
        err = SCKeySerializePrivate(ctx->scKey, storagekey, STORAGEKEY_LEN, &keyData, &keyDataLen); CKERR;
        
        sStore16(keyDataLen, &p);
        sStoreArray(keyData, keyDataLen,&p);
    }
    else
    {
        sStore16(0, &p);
    }

    
    bufLen = p - buffer;

    // NOTE: if this assert fails we have already corrupted memory by overwriting un-alloc'd space!!
    ASSERTERR((bufLen > MAX_SCIMP_BLOB_SIZE), kSCLError_BufferTooSmall);

    // record the buffer length back at the beginning of the blob
    sStore16( bufLen, &lenP);
    
    *outBlob = buffer;
    *blobSize =  p - buffer;
    
done:
    
    if(IsSCLError(err) && buffer)
    {
        ZERO(buffer, sizeof(buffer));
        XFREE  (buffer);
    }

    if(IsntNull(keyData))
    {
         XFREE(keyData);
    }

    if(IsntNull(PK))
    {
        ZERO(PK, PK_ALLOC_SIZE);
        XFREE(PK);
    }
    
    if(IsntNull(hashState))
    {
        ZERO(hashState, kHASH_ContextAllocSize);
        XFREE(hashState);
    }
     return err;
 
}


SCLError SCimpSaveState(SCimpContextRef ctx,  uint8_t *key, size_t  keyLen, void **outBlob, size_t *blobSize)
{
    SCLError             err         = kSCLError_NoErr;
     
    size_t              encodedLen  = 0;
    uint8_t             *encoded    = NULL;
    uint8_t             tag[SCIMP_STATE_TAG_LEN];
    size_t              tagLen      = sizeof(tag);
 
    uint8_t* buffer = NULL;
    size_t      bufLen = 0;
    Cipher_Algorithm    storageKeyalgorithm = kCipher_Algorithm_Invalid;
    
    validateSCimpContext(ctx);
    ValidateParam(key);
    ValidateParam(outBlob);
    ValidateParam(blobSize);
   
    switch(keyLen)
    {
        case 32: storageKeyalgorithm = kCipher_Algorithm_AES128; break;
        case 64: storageKeyalgorithm = kCipher_Algorithm_AES256; break;
        default:
            RETERR(kSCLError_BadParams) ;
    }

    
    err = saveStateInternal(ctx, &buffer, &bufLen); CKERR;
 
    err = CCM_Encrypt_Mem(storageKeyalgorithm, key,  keyLen, NULL, 0,  buffer,bufLen, &encoded, &encodedLen,  tag, sizeof(tag)); CKERR;
     
    err = scimpSerializeStateJSON(encoded, encodedLen, tag, tagLen, (uint8_t**) outBlob, blobSize);CKERR;
        
done:
    
    if(IsntNull(encoded)) XFREE(encoded);
    
    if(buffer)
    {
        ZERO(buffer, sizeof(buffer));
        XFREE(buffer);
    }

    return err;
}


SCLError SCimpEncryptState(SCimpContextRef ctx,  SCKeyContextRef storageKey, void **outBlob, size_t *blobSize)
{
    SCLError             err         = kSCLError_NoErr;
    
    size_t              encodedLen  = 0;
    uint8_t             *encoded    = NULL;
    uint8_t             tag[SCIMP_STATE_TAG_LEN];
    size_t              tagLen      = sizeof(tag);
    
    uint8_t* buffer = NULL;
    size_t      bufLen = 0;
    
    validateSCimpContext(ctx);
    ValidateParam(storageKey);
    ValidateParam(outBlob);
    ValidateParam(blobSize);
    
    err = saveStateInternal(ctx, &buffer, &bufLen); CKERR;
    
    sMakeHash(kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384, buffer, bufLen, SCIMP_STATE_TAG_LEN,  tag);
    
    err = SCKeyStorageEncrypt(storageKey, buffer,bufLen, &encoded, &encodedLen); CKERR;
    
    err = scimpSerializeStateJSON(encoded, encodedLen, tag, tagLen, (uint8_t**) outBlob, blobSize);CKERR;
    
done:
    
    if(IsntNull(encoded)) XFREE(encoded);
    
    if(buffer)
    {
        ZERO(buffer, sizeof(buffer));
        XFREE(buffer);
    }
    
    return err;
}


SCLError  saveRestoreInternal( uint8_t * buffer, size_t bufLen, SCimpContextRef *outscimp)
{
    SCLError            err = kSCLError_NoErr;
    SCimpContext*      ctx = NULL;
    
    uint8_t             *bufferEnd = NULL;
    
    uint8_t             *p = NULL;
    size_t              len;
    size_t              blobLen = 0;
	uint8_t				blobVersion = 0;

    uint8_t             *PK = NULL;
    size_t              PKLen = 0;
    
    uint8_t             *hashState = NULL;
    size_t              hashStateLen = 0;

    uint8_t             storagekey[STORAGEKEY_LEN] ={0};
    size_t              keyDataLen = 0;

    int             i;
    
    ValidateParam(buffer);
    ValidateParam(outscimp);
    
    p = buffer;
    bufferEnd = buffer + bufLen;
    
    // check blobsize here
    if((sLoad32(&p) != kSCimpContextMagic)) RETERR(kSCLError_CorruptData);
    
    blobLen = sLoad16(&p);
    if(blobLen != bufLen)  RETERR(kSCLError_CorruptData);
    
	blobVersion = sLoad8(&p);
	if (!BLOB_VERSION_CAN_RESTORE(blobVersion, kSCimpBlobVersion))
		RETERR(kSCLError_CorruptData);
//    if((sLoad8(&p) != kSCimpBlobVersion)) RETERR(kSCLError_CorruptData);
      
    ctx = XMALLOC(sizeof (SCimpContext)); CKNULL(ctx);
    
    ZERO(ctx, sizeof(SCimpContext));
    ctx->magic  = kSCimpContextMagic;
    
    ctx->transQueue.first = 0;
    ctx->transQueue.last = TRANS_QUEUESIZE-1;
    ctx->transQueue.count = 0;
    
    pthread_mutex_init(&ctx->mp , NULL);
    
    scResetSCimpContext(ctx, true);
    
    ctx->version    =   sLoad8(&p);
    ctx->method        = sLoad8(&p);
    ctx->state         = sLoad8(&p);
    ctx->cipherSuite   = sLoad8(&p);
    ctx->sasMethod     = sLoad8(&p);
    ctx->msgFormat     = sLoad8(&p);
    
    switch(ctx->msgFormat)
    {
#if SUPPORT_XML_MESSAGE_FORMAT
        case kSCimpMsgFormat_XML:
            ctx->serializeHandler = scimpSerializeMessageXML;
            ctx->deserializeHandler = scimpDeserializeMessageXML;
            break;
#endif
        case kSCimpMsgFormat_JSON:
            ctx->serializeHandler = scimpSerializeMessageJSON;
            ctx->deserializeHandler = scimpDeserializeMessageJSON;
            break;
            
        default:
            RETERR(kSCLError_FeatureNotAvailable);
            break;
    };
    
    if (blobVersion >= kScimpBlobVersion10) {
        ctx->loggingLevel = sLoad8(&p);
    }
    
    err = sLoadArray(&ctx->SessionID, sizeof(ctx->SessionID), &p, bufferEnd ); CKERR;
    
    ctx->rcvIndex   =  sLoad8(&p);
    for(i = 0; i< SCIMP_RCV_QUEUE_SIZE; i++)
    {
        err = sLoadArray(&ctx->Rcv[i].key, SCIMP_KEY_LEN, &p, bufferEnd ); CKERR;
        ctx->Rcv[i].index   = sLoad64(&p);
    }

	ctx->dormantSeedKeys = NULL;
	if (blobVersion >= kScimpBlobVersion9) {
		uint16_t seedCount = sLoad16(&p);
		Stack *lastNode = NULL;
		for (i=0; i<seedCount; i++) {
			// we build our own stack here (rather than calling pushStack() to handle re-ordering properly
			CommKeyPair *keyPair = XMALLOC(sizeof(CommKeyPair)); CKNULL(keyPair);
			err = sLoadArray(&keyPair->key, SCIMP_KEY_LEN, &p, bufferEnd); CKERR;
			keyPair->index = sLoad64(&p);

			Stack *node = XMALLOC(sizeof(Stack)); CKNULL(node);
			node->data = keyPair;
			node->next = NULL;

			if (ctx->dormantSeedKeys == NULL)
				ctx->dormantSeedKeys = node;

			if (lastNode)
				lastNode->next = node;
			lastNode = node;
		}
	}

    err = sLoadArray(&ctx->Ksnd, sizeof(ctx->Ksnd), &p , bufferEnd ); CKERR;
    ctx->Isnd          = sLoad64(&p);
    ctx->Ioffset       = sLoad16(&p);
    err = sLoadArray(&ctx->Cs, sizeof(ctx->Cs), &p, bufferEnd ); CKERR;
    err = sLoadArray(&ctx->Cs1, sizeof(ctx->Cs1), &p, bufferEnd ); CKERR;
    
    err = sLoadArray(&ctx->Kdk2, sizeof(ctx->Kdk2), &p, bufferEnd ); CKERR;
    ctx->KdkLen = sLoad16(&p);
     
    ctx->ctxStrLen = len = sLoad16(&p);
    if(len)
    {
        ctx->ctxStr = XMALLOC(len); CKNULL(ctx->ctxStr); // note: binary buffer, *does not* include null-terminator
        err = sLoadArray(ctx->ctxStr, len, &p, bufferEnd ); CKERR;
    }
     
    err = sLoadArray(&ctx->Hcs, sizeof(ctx->Hcs), &p, bufferEnd ); CKERR;
    err = sLoadArray(&ctx->Hpki, sizeof(ctx->Hpki), &p, bufferEnd ); CKERR;
    err = sLoadArray(&ctx->MACi, sizeof(ctx->MACi), &p, bufferEnd ); CKERR;
    err = sLoadArray(&ctx->MACr, sizeof(ctx->MACr), &p, bufferEnd ); CKERR;
    
    ctx->isInitiator    = sLoad8(&p);
    ctx->hasCs          = sLoad8(&p);
    ctx->csMatches      = sLoad8(&p);
    ctx->hasKeys        = sLoad8(&p);
    ctx->SAS            = sLoad64(&p);
  
    err = sLoadArray(&ctx->keyedTime,  sizeof(ctx->keyedTime), &p, bufferEnd ); CKERR;
    
    len = sLoad8(&p);
    if(len)
    {
        ctx->meStr = XMALLOC(len); CKNULL(ctx->meStr); // note: null-termination byte included in buffer
        err = sLoadArray(ctx->meStr, len, &p, bufferEnd ); CKERR;
    }
    
    len = sLoad8(&p);
    if(len)
    {
        ctx->youStr = XMALLOC(len); CKNULL(ctx->youStr); // note: null-termination byte included in buffer
        err = sLoadArray(ctx->youStr, len, &p, bufferEnd ); CKERR;
    }
    
    PKLen = sLoad8(&p);
    if(PKLen)
    {
        PK = XMALLOC(PKLen); CKNULL(PK);
        err = sLoadArray(PK, PKLen, &p, bufferEnd ); CKERR;
        err = ECC_Init(&ctx->privKey0); CKERR;
        err = ECC_Import(ctx->privKey0,PK, PKLen); CKERR;
        ZERO(PK, PKLen);
        XFREE(PK);
        PK = NULL;
     }
 
    PKLen = sLoad8(&p);
    if(PKLen)
    {
        PK = XMALLOC(PKLen); CKNULL(PK);
        err = sLoadArray(PK, PKLen, &p, bufferEnd ); CKERR;
        err = ECC_Init(&ctx->privKeyDH); CKERR;
        err = ECC_Import(ctx->privKeyDH,PK, PKLen); CKERR;
        ZERO(PK, PKLen);
        XFREE(PK);
        PK = NULL;
    }
    
    PKLen = sLoad8(&p);
    if(PKLen)
    {
        PK = XMALLOC(PKLen); CKNULL(PK);
        err = sLoadArray(PK, PKLen, &p, bufferEnd ); CKERR;
        err = ECC_Init(&ctx->pubKey); CKERR;
        err = ECC_Import(ctx->pubKey,PK, PKLen); CKERR;
        ZERO(PK, PKLen);
        XFREE(PK);
        PK = NULL;
    }

    len = sLoad8(&p);
    if(len)
    {
        ctx->pubKeyLocator = XMALLOC(len+1); CKNULL(ctx->pubKeyLocator);
        err = sLoadArray(ctx->pubKeyLocator, len, &p, bufferEnd ); CKERR;
    }

    hashStateLen = sLoad16(&p);
    if(hashStateLen)
    {
        hashState = XMALLOC(hashStateLen); CKNULL(hashState);
        err =  sLoadArray(hashState, hashStateLen, &p, bufferEnd ); CKERR;
        err = HASH_Import(hashState, hashStateLen,&ctx->HtotalState); CKERR;
    }
 
     
    keyDataLen =  sLoad16(&p);
    if(keyDataLen)
    {
        err = SCKeyDeserialize(p,  keyDataLen, &ctx->scKey);CKERR;
        p+= keyDataLen;
        err = SCKeyUnlock(ctx->scKey, storagekey, STORAGEKEY_LEN); CKERR;
     }
    
    *outscimp = ctx;
    
done:
    
    if(IsntNull(PK))
    {
        ZERO(PK, PKLen);
        XFREE(PK);
    }
    
    if(IsntNull(hashState))
    {
        ZERO(hashState, hashStateLen);
        XFREE(hashState);
    }
    
    return err;
}


SCLError SCimpRestoreState( uint8_t *key, size_t  keyLen, void *blob, size_t blobSize, SCimpContextRef *outscimp)
{
    SCLError            err = kSCLError_NoErr;
    SCimpContext*      ctx = NULL;
  
    uint8_t             tag[SCIMP_STATE_TAG_LEN];
    size_t              tagLen      = sizeof(tag);

    size_t              encodedLen  = 0;
    uint8_t             *encoded    = NULL;

    uint8_t             *buffer = NULL;        // currently this is 898 bytes 
    size_t              bufLen = 0;
   
    Cipher_Algorithm    storageKeyalgorithm = kCipher_Algorithm_Invalid;
    
    ValidateParam(blob);
    ValidateParam(outscimp);
    
    
    switch(keyLen)
    {
        case 32: storageKeyalgorithm = kCipher_Algorithm_AES128; break;
        case 64: storageKeyalgorithm = kCipher_Algorithm_AES256; break;
        default:
            RETERR(kSCLError_BadParams) ;
    }

    err = scimpDeserializeStateJSON(blob, blobSize, tag, &tagLen, &encoded, &encodedLen);CKERR;
  
    err = CCM_Decrypt_Mem(storageKeyalgorithm, key,  keyLen, NULL, 0,  encoded, encodedLen,  tag, tagLen, &buffer, &bufLen  ); CKERR;
      
    err = saveRestoreInternal(buffer, bufLen, &ctx); CKERR;

     *outscimp = ctx;
  
done:

    if(IsntNull(encoded)) XFREE(encoded);
    
    if(IsntNull(buffer))
    {
        ZERO(buffer, bufLen);
        XFREE(buffer);
    }

     return err;
}

SCLError SCimpDecryptState(SCKeyContextRef storageKey, void *blob, size_t blobSize,  SCimpContextRef *outscimp)
{
    SCLError            err = kSCLError_NoErr;
    SCimpContext*      ctx = NULL;
    
    uint8_t             tag[SCIMP_STATE_TAG_LEN];
    size_t              tagLen      = sizeof(tag);
 
    uint8_t             tag1[SCIMP_STATE_TAG_LEN];

    size_t              encodedLen  = 0;
    uint8_t             *encoded    = NULL;
    
    uint8_t             *buffer = NULL;        // currently this is 898 bytes
    size_t              bufLen  = 0;
    
    
    ValidateParam(blob);
    ValidateParam(outscimp);
    
    err = scimpDeserializeStateJSON(blob, blobSize, tag, &tagLen, &encoded, &encodedLen);CKERR;
    
    err = SCKeyStorageDecrypt(storageKey, encoded,  encodedLen,  &buffer, &bufLen); CKERR;
 
    err = sMakeHash(kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384, buffer, bufLen, SCIMP_STATE_TAG_LEN,  tag1);CKERR;

    ASSERTERR(!CMP(tag, tag1, tagLen), kSCLError_CorruptData) ; CKERR;
     
    err = saveRestoreInternal(buffer, bufLen, &ctx); CKERR;
    
    *outscimp = ctx;
    
done:
    
    if(IsntNull(encoded)) XFREE(encoded);
    
    if(IsntNull(buffer))
    {
        ZERO(buffer, bufLen);
        XFREE(buffer);
    }
    
    return err;
   
}



void SCimpFree(SCimpContextRef ctx)
{
    
    if(scimpContextIsValid(ctx))
    {
        pthread_mutex_destroy(&ctx->mp);
        
        if(ctx->scKey)
            SCKeyFree(ctx->scKey);
        
		if (ctx->ctxStr)
			XFREE(ctx->ctxStr);

          if(ctx->privKey0)
            ECC_Free(ctx->privKey0);
        if(ctx->privKeyDH)
            ECC_Free(ctx->privKeyDH);
        if(ctx->pubKey)
            ECC_Free(ctx->pubKey);
        if(ctx->pubKeyLocator)
            XFREE(ctx->pubKeyLocator);
        if(ctx->meStr)
            XFREE(ctx->meStr);
        if(ctx->youStr)
            XFREE(ctx->youStr);
        if(ctx->HtotalState)
            HASH_Free(ctx->HtotalState);
        
		Stack *stack = ctx->dormantSeedKeys;
		while (stack != NULL) {
			Stack *next = stack->next;
			XFREE(stack->data);
			XFREE(stack);
			stack = next;
		}

        ZERO(ctx, sizeof(SCimpContext));
        XFREE(ctx);
    }
    
    
}


SCLError SCimpAcceptSecret(SCimpContextRef ctx)
{
    SCLError err = kSCLError_NoErr;
    uint8_t CS[SCIMP_KEY_LEN];
    size_t       dataLen = 0;
    validateSCimpContext(ctx);
  
    ZERO(CS,sizeof(CS));
  
    if(!ctx->hasKeys)
        RETERR(kSCLError_NotConnected);
         
    err = SCimpGetDataProperty(ctx,kSCimpProperty_NextSecret,
                               CS, scSCimpCipherBits(ctx->cipherSuite) /4,  //  twice the cipher bits in bytes.  AES-128 = 16, AES-256 = 32,
                               &dataLen); CKERR;
    err = SCimpSetDataProperty(ctx, kSCimpProperty_SharedSecret,  CS, dataLen); CKERR;
    
    scEventAdviseSaveState(ctx);

done:
    
    ZERO(CS,sizeof(CS));
   
    return err;
    
}

SCLError SCimpSendPublic(SCimpContextRef  ctx,
                         SCKeyContextRef  pubKey,
                         void*            data,
                         size_t           dataLen,
                         void*            userRef )
{
    SCLError err = kSCLError_NoErr;
    SCKeyType  keyType;
    time_t      pubExpire;
    time_t      now;
    double      diff_t;
   
    validateSCimpContext(ctx);
    ValidateParam(data);
    ValidateParam(pubKey);
    
    err = SCKeyGetProperty(pubKey, kSCKeyProp_SCKeyType,   NULL,  &keyType, sizeof(SCKeyType),  NULL); CKERR;
    ASSERTERR((keyType != kSCKeyType_Public) && (keyType != kSCKeyType_Private), kSCLError_BadParams);
    
    // check pub key dates
    time(&now);
    err = SCKeyGetProperty(pubKey, kSCKeyProp_ExpireDate,  NULL,  &pubExpire, sizeof(time_t),  NULL); CKERR;
    if(pubExpire)
    {
        diff_t = difftime(now, pubExpire);
        ASSERTERR(diff_t>0, kSCLError_KeyExpired);
    }

    err = scSendPublicDataInternal(ctx, pubKey, data, dataLen, userRef);
    
done:
    return err;
   
}



SCLError SCimpSendMsg(SCimpContextRef  ctx,
                      void*            data, 
                      size_t           dataLen,
                      void*            userRef)
{
    SCLError err = kSCLError_NoErr;
    
    validateSCimpContext(ctx);
    ValidateParam(data);
    
    if(ctx->state == kSCimpState_PKInit)
    {
        err = scSendScimpPKstartInternal(ctx, data, dataLen, userRef); CKERR;
    }
    else
    {
        err = scSendScimpDataInternal(ctx, data, dataLen, userRef); CKERR;

    }
    
done:
    return err;
   
}


SCLError SCimpSetEventHandler(SCimpContextRef scimp, 
                           ScimpEventHandler handler, void* userValue) 
{
    int err = kSCLError_NoErr;
    
    validateSCimpContext(scimp);
    
    scimp->handler = handler;
    scimp->userValue = userValue;
    
    
//done:
    return err;
    
}


SCLError SCimpGetInfo( SCimpContextRef scimp, SCimpInfo* info)
{
    int                 err = kSCLError_NoErr;
   
    time_t     expireDate;
    time_t     now;
    double      diff_t;
    bool        canPKStart = false;
    
    validateSCimpContext(scimp);
    ValidateParam(info);
    
    
    // check keydates
    time(&now);
    
    if(scimp->scKey)
    {
        err = SCKeyGetProperty(scimp->scKey, kSCKeyProp_ExpireDate,  NULL,  &expireDate, sizeof(time_t),  NULL); CKERR;
        diff_t = difftime(expireDate , now  );
        canPKStart   =  (diff_t >0 );
     }
     
    info->version       = scimp->version;
    info->cipherSuite   = scimp->cipherSuite;
    info->sasMethod     = scimp->sasMethod;
    info->scimpMethod   = scimp->method;
    
    info->isReady       = scimp->hasKeys;
    info->isInitiator   = scimp->isInitiator;
    info->hasCs         = scimp->hasCs;
    info->csMatches     = scimp->csMatches;
    info->canPKstart    = canPKStart;
    info->keyedTime     = scimp->keyedTime;
    
    info->meStr         = scimp->meStr;
    info->youStr        = scimp->youStr;
    
    info->state         = scimp->state;
done:
    return err;
    
}

static SCLError sGetSCimpDataPropertyInternal( SCimpContextRef ctx,
                                         SCimpProperty whichProperty,
                                         void *outData, size_t bufSize, size_t *datSize, bool doAlloc,
                                         uint8_t** allocBuffer)
{
    int                err = kSCLError_NoErr;
    
    size_t             actualLength = 0;
    void              *buffer = NULL;
    
    if(datSize)
        *datSize = 0;
    
    switch(whichProperty)
    {
        case kSCimpProperty_SharedSecret:
            actualLength =  scSCimpCipherBits(ctx->cipherSuite) /4;  //  twice the cipher bits in bytes.  AES-128 = 16, AES-256 = 32;
            break;
            
        case kSCimpProperty_NextSecret:
            if(!ctx->hasKeys)
                RETERR(kSCLError_KeyNotFound);
            actualLength = scSCimpCipherBits(ctx->cipherSuite) /4; //  twice the cipher bits in bytes.  AES-128 = 16, AES-256 = 32;
            break;
            
        case kSCimpProperty_SASstring:
            
            if(ctx->method == kSCimpMethod_PubKey || ctx->method == kSCimpMethod_Symmetric)
            {
                switch(ctx->sasMethod)
                {
                       case kSCimpSAS_HEX:
                        actualLength = 33;
                        break;
                        
                        case kSCimpSAS_PGP:
                        actualLength = 64;
                        break;
                        
                        
                    default:
                        RETERR(kSCLError_BadParams);
                        
                        break;
                }
   
            }
            else
            {
                switch(ctx->sasMethod)
                {
                    case kSCimpSAS_ZJC11:
                        actualLength = 5;
                        break;
                        
                    case kSCimpSAS_HEX:
                        actualLength = 7;
                        break;
                        
                    case kSCimpSAS_NATO:
                        actualLength = 32;
                        break;
                        
                    case kSCimpSAS_PGP:
                        actualLength = 32;
                        break;
                        
                        
                    default:
                        break;
                }

            }
                 break;
            
        default:
            RETERR(kSCLError_BadParams);
            break;
    }
    
    if(!actualLength)
        goto done;
    
    
    if(doAlloc)
    {
        buffer = XMALLOC(actualLength); CKNULL(buffer);
        *allocBuffer = buffer;
    }
    else
    {
        actualLength = (actualLength < bufSize)?actualLength:bufSize;
        buffer = outData;
    }
    
    switch(whichProperty)
    {
        case kSCimpProperty_SharedSecret:
            COPY(ctx->Cs,  buffer, actualLength);
            break;
            
        case kSCimpProperty_NextSecret:
            COPY(ctx->Cs1,  buffer, actualLength);
            break;
       
        case kSCimpProperty_SASstring:
            if(ctx->method == kSCimpMethod_PubKey || ctx->method == kSCimpMethod_Symmetric)
            {
                switch(ctx->sasMethod)
                {
                         
                    case kSCimpSAS_HEX:
                        sprintf(buffer,"%016llX", ctx->SAS);
                         break;
                            
                    case kSCimpSAS_PGP:
                        PGPWordEncode64(ctx->SAS, buffer, &actualLength);
                        break;
                        
                    default:
                        break;
                }

                
            }
            else
            {
                switch(ctx->sasMethod)
                {
                    case kSCimpSAS_ZJC11:
                        ZB32encode(  (uint32_t)(ctx->SAS),buffer);
                        break;
                        
                    case kSCimpSAS_HEX:
                            sprintf(buffer,"%05X", (uint32_t)(ctx->SAS));
                          break;
                        
                    case kSCimpSAS_NATO:
                        NATOencode((uint32_t)(ctx->SAS), buffer, &actualLength);
                        break;
                        
                    case kSCimpSAS_PGP:
                        PGPWordEncode((uint32_t)(ctx->SAS), buffer, &actualLength);
                        break;
                        
                    default:
                        break;
                }
 
            }
            break;
        default:
            break;
    }
    
    if(datSize) 
        *datSize = actualLength;
    
    
done:
    return err;
    
}

SCLError SCimpGetDataProperty( SCimpContextRef scimp,
                           SCimpProperty whichProperty, 
                           void *outData, size_t bufSize, size_t *datSize)
{
    int                 err = kSCLError_NoErr;
    
    validateSCimpContext(scimp);
    ValidateParam(outData);
    ValidateParam(datSize);
    
    if ( IsntNull( outData ) )
	{
		ZERO( outData, bufSize );
	}
    
    err =  sGetSCimpDataPropertyInternal(scimp, whichProperty, outData, bufSize, datSize, false, NULL); CKERR;
    
done:
    return err;
    
}

SCLError SCimpGetAllocatedDataProperty( SCimpContextRef scimp,
                                    SCimpProperty whichProperty, 
                                    void **outData, size_t *datSize)
{
    int                 err = kSCLError_NoErr;
    
    validateSCimpContext(scimp);
    ValidateParam(outData);
     
    err =  sGetSCimpDataPropertyInternal(scimp, whichProperty, NULL, 0, datSize, true, (uint8_t**) outData); CKERR;
    
done:
    return err;
    
}




SCLError SCimpSetDataProperty( SCimpContextRef scimp,
                           SCimpProperty whichProperty, 
                           void *data,  size_t  datSize)
{
    int                 err = kSCLError_NoErr;
    
    validateSCimpContext(scimp);
    ValidateParam(data);
    
    switch(whichProperty)
    {
        case kSCimpProperty_SharedSecret:
            ZERO(scimp->Cs, SCIMP_KEY_LEN);
            COPY(data, scimp->Cs, datSize > SCIMP_KEY_LEN?SCIMP_KEY_LEN:datSize);
            scimp->hasCs = true;
            break;
            
            
        default:
            RETERR(kSCLError_BadParams);
            break;
    }
    
done:
    return err;
    
}


SCLError SCimpGetNumericProperty( SCimpContextRef scimp,
                              SCimpProperty whichProperty, 
                              uint32_t *prop)
{
    int                 err = kSCLError_NoErr;
    
    validateSCimpContext(scimp);
    ValidateParam(prop);
    
    switch(whichProperty)
    {
        case kSCimpProperty_CipherSuite:
            *prop = scimp->cipherSuite;
            break;
            
        case kSCimpProperty_SASMethod:
            *prop = scimp->sasMethod;
            break;
            
        case kSCimpProperty_MsgFormat:
            *prop = scimp->msgFormat;
            break;
            
        case kSCimpProperty_SCIMPstate:
            *prop = scimp->state;
            break;
        case kSCimpProperty_SCIMPmethod:
            *prop = scimp->method;
            break;
            
        default:
            RETERR(kSCLError_BadParams);
            break;
    }
    
done:
    return err;
    
}

SCLError SCimpGetTimeProperty( SCimpContextRef scimp,
                              SCimpProperty whichProperty,
                              time_t *prop)
{
    int                 err = kSCLError_NoErr;
    
    validateSCimpContext(scimp);
    ValidateParam(prop);
    
    switch(whichProperty)
    {
        case kSCimpProperty_KeyedTime:
            *prop = scimp->keyedTime;
            break;
            
            
        default:
            RETERR(kSCLError_BadParams);
            break;
    }
    
done:
    return err;
}


SCLError SCimpSetNumericProperty( SCimpContextRef ctx,
                              SCimpProperty whichProperty,
                              uint32_t prop)
{
    int                 err = kSCLError_NoErr;
    
    validateSCimpContext(ctx);
    
    switch(whichProperty)
    {
        case kSCimpProperty_CipherSuite:
            if(!isValidCipherSuite(ctx, prop))
                    return kSCLError_BadParams;
            
              ctx->cipherSuite = prop;
            break;
            
        case kSCimpProperty_SCIMPmethod:
            
            if(!isValidScimpMethod(prop))
                return kSCLError_BadParams;
            
             ctx->method = prop;
            break;
            
        case kSCimpProperty_SASMethod:
             if(!isValidSASMethod(prop)) 
                return kSCLError_BadParams;
            
            ctx->sasMethod = prop;
            break;
          
        case kSCimpProperty_MsgFormat:
            switch(prop)
            {
#if SUPPORT_XML_MESSAGE_FORMAT
                case kSCimpMsgFormat_XML: 
                    ctx->msgFormat = kSCimpMsgFormat_XML;
                    ctx->serializeHandler = scimpSerializeMessageXML;
                    ctx->deserializeHandler = scimpDeserializeMessageXML;
                    break;
#endif                    
                case kSCimpMsgFormat_JSON: 
                    ctx->msgFormat = kSCimpMsgFormat_JSON;
                    ctx->serializeHandler = scimpSerializeMessageJSON;
                    ctx->deserializeHandler = scimpDeserializeMessageJSON;
                    break;
                    
                default:
                    RETERR(kSCLError_FeatureNotAvailable);
                    break;
            };
            break;
            
            
        default:
            RETERR(kSCLError_BadParams);
            break;
    }
    
done:
    return err;
}
  

SCLError SCimpEnableTransitionEvents(SCimpContextRef  ctx, bool enable)
{
    SCLError err = kSCLError_NoErr;

    validateSCimpContext(ctx);
    
    ctx->wantsTransEvents = enable;
    
//    scEventTransition(ctx, ctx->state);

//done:
    return err;

}


SCLError SCimpSetLoggingEventLevel(SCimpContextRef  ctx, SCimpLogging level)
{
    SCLError err = kSCLError_NoErr;
   
    validateSCimpContext(ctx);
    
    ctx->loggingLevel = level;
    
     return err;
}


 
SCLError  SCimpGetVersionString(size_t	bufSize, char *outString)
{
      SCLError                 err = kSCLError_NoErr;
    
    ValidateParam(outString);
    *outString = 0;
    
    char version_string[32];
    
    sprintf(version_string, "%s (%03d)", SCIMP_SHORT_VERSION_STRING, SCIMP_BUILD_NUMBER);
    
    if(strlen(version_string) +1 > bufSize)
        RETERR (kSCLError_BufferTooSmall);
    
    strcpy(outString, version_string);
    
done:
    return err;
}
