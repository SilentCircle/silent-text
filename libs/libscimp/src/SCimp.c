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

#include "SCpubTypes.h"
#include "cryptowrappers.h"
#include "SCimp.h"
#include "SCimpPriv.h"
#include "SCutilities.h"
#include <tomcrypt.h>
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
    ValidateParam(meStr);
    ValidateParam(youStr);
    
    ctx = XMALLOC(sizeof (SCimpContext)); CKNULL(ctx);
    
    ZERO(ctx, sizeof(SCimpContext));
    ctx->magic = kSCimpContextMagic;
    
    ctx->transQueue.first = 0;
    ctx->transQueue.last = TRANS_QUEUESIZE-1;
    ctx->transQueue.count = 0;
 
    scResetSCimpContext(ctx, true);
    
    pthread_mutex_init(&ctx->mp , NULL);
    
    ctx->meStr = XMALLOC( strlen(meStr)+1 );
    strcpy(ctx->meStr, meStr);
    
    ctx->youStr = XMALLOC( strlen(youStr)+1 );
    strcpy(ctx->youStr, youStr);
        
    *outscimp = ctx; 
    
    scEventAdviseSaveState(ctx);
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


SCLError SCimpSaveState(SCimpContextRef ctx,  uint8_t *key, size_t  keyLen, void **outBlob, size_t *blobSize)
{
    SCLError             err         = kSCLError_NoErr;
     
    size_t              encodedLen  = 0;
    uint8_t             *encoded    = NULL;
    uint8_t             tag[SCIMP_STATE_TAG_LEN];
    size_t              tagLen      = sizeof(tag);
 
    uint8_t buffer[4096];        // currently this is 1474 bytes
    size_t  bufLen = 0;
      
    uint8_t *p = NULL;
    uint8_t *lenP = NULL;
    int     i;
    
    unsigned long           PKlen = PK_ALLOC_SIZE;
    uint8_t                *PK = NULL;
    
    uint8_t                 *hashState = NULL;
    size_t                  hashStateLen = kHASH_ContextAllocSize;

    validateSCimpContext(ctx);
    ValidateParam(key);
    ValidateParam(outBlob);
    ValidateParam(blobSize);
    
    //must be in ready state
       
    p = buffer;
    
    sStore32( ctx->magic, &p);
    lenP = p;
    p+= sizeof(uint16_t);
    sStore8( kSCimpBlobVersion, &p);
    sStore8( ctx->version, &p);
      
    sStore8( ctx->state, &p);
    sStore8( ctx->cipherSuite, &p);
    sStore8( ctx->sasMethod, &p);
    sStore8( ctx->msgFormat, &p);
    sStoreArray(ctx->SessionID, sizeof(ctx->SessionID), &p );
    
    sStore8(ctx->rcvIndex, &p);
 
    for(i = 0; i< SCIMP_RCV_QUEUE_SIZE; i++)
    {
        sStoreArray(ctx->Rcv[i].key, SCIMP_KEY_LEN, &p );
        sStore64(ctx->Rcv[i].index, &p );
    }
    sStoreArray(ctx->Ksnd, sizeof(ctx->Ksnd), &p );
    sStore64(ctx->Isnd, &p );
    sStoreArray(ctx->Cs, sizeof(ctx->Cs), &p );
    sStoreArray(ctx->Cs1, sizeof(ctx->Cs1), &p );
    
    sStoreArray(ctx->Hcs, sizeof(ctx->Hcs), &p );
    sStoreArray(ctx->Hpki, sizeof(ctx->Hpki), &p );
    sStoreArray(ctx->MACi, sizeof(ctx->MACi), &p );
    sStoreArray(ctx->MACr, sizeof(ctx->MACr), &p );
    
    sStore8( ctx->isInitiator, &p);
    sStore8( ctx->hasCs, &p);
    sStore8( ctx->csMatches, &p);
    sStore32( ctx->SAS, &p);
     
    sStore8( strlen(ctx->meStr)+1, &p);
    sStoreArray(ctx->meStr, strlen(ctx->meStr) +1, &p);
    sStore8( strlen(ctx->youStr)+1, &p);
    sStoreArray(ctx->youStr, strlen(ctx->youStr)+1, &p);
    
    if(ctx->privKey)
    {
        PK = XMALLOC(PK_ALLOC_SIZE); CKNULL(PK);
        err = ECC_Export(ctx->privKey, true, PK, PKlen, &PKlen); CKERR;
        sStore8(PKlen, &p);
        sStoreArray(PK, PKlen,&p);
   }
    else
    {
        sStore8(0, &p);
    }
  
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

    
    bufLen = p - buffer;
    sStore16( bufLen, &lenP);

    err = CCM_Encrypt(key,  keyLen, NULL, 0,  buffer, p - buffer, &encoded, &encodedLen,  tag, sizeof(tag)); CKERR;
     
    err = scimpSerializeStateJSON(encoded, encodedLen, tag, tagLen, (uint8_t**) outBlob, blobSize);CKERR;
        
done:
    
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

    if(IsntNull(encoded)) XFREE(encoded);
    ZERO(buffer, sizeof(buffer));
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
    uint8_t             *bufferEnd = NULL;
    size_t              bufLen;
   
    uint8_t             *p = NULL;
    size_t              len;
    size_t              blobLen = 0;
    
    uint8_t             *PK = NULL;
    size_t              PKLen = 0;
 
    uint8_t             *hashState = NULL;
    size_t              hashStateLen = 0;

    int             i;
   
    ValidateParam(blob);
    ValidateParam(outscimp);
    
    err = scimpDeserializeStateJSON(blob, blobSize, tag, &tagLen, &encoded, &encodedLen);CKERR;
  
    err = CCM_Decrypt(key,  keyLen, NULL, 0,  encoded, encodedLen,  tag, tagLen, &buffer, &bufLen  ); CKERR;
    
    p = buffer;
    bufferEnd = buffer + bufLen;
    
    // check blobsize here
    if((sLoad32(&p) != kSCimpContextMagic)) RETERR(kSCLError_CorruptData);
   
    blobLen = sLoad16(&p);
    if(blobLen != bufLen)  RETERR(kSCLError_CorruptData);

    if((sLoad8(&p) != kSCimpBlobVersion)) RETERR(kSCLError_CorruptData);
    if((sLoad8(&p) != kSCimpVersion)) RETERR(kSCLError_CorruptData);
      
    ctx = XMALLOC(sizeof (SCimpContext)); CKNULL(ctx);
    
    ZERO(ctx, sizeof(SCimpContext));
    ctx->magic  = kSCimpContextMagic;
    
    ctx->transQueue.first = 0;
    ctx->transQueue.last = TRANS_QUEUESIZE-1;
    ctx->transQueue.count = 0;
    
    pthread_mutex_init(&ctx->mp , NULL);
    
    scResetSCimpContext(ctx, true);
    
    ctx->version = kSCimpVersion;
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
    };

    err = sLoadArray(&ctx->SessionID, sizeof(ctx->SessionID), &p, bufferEnd ); CKERR;
    
    ctx->rcvIndex   =  sLoad8(&p);
    for(i = 0; i< SCIMP_RCV_QUEUE_SIZE; i++)
    {
        err = sLoadArray(&ctx->Rcv[i].key, SCIMP_KEY_LEN, &p, bufferEnd ); CKERR;
        ctx->Rcv[i].index   = sLoad64(&p);
    }
    err = sLoadArray(&ctx->Ksnd, sizeof(ctx->Ksnd), &p , bufferEnd ); CKERR;
    ctx->Isnd          = sLoad64(&p);
    err = sLoadArray(&ctx->Cs, sizeof(ctx->Cs), &p, bufferEnd ); CKERR;
    err = sLoadArray(&ctx->Cs1, sizeof(ctx->Cs1), &p, bufferEnd ); CKERR;
    
    err = sLoadArray(&ctx->Hcs, sizeof(ctx->Hcs), &p, bufferEnd ); CKERR;
    err = sLoadArray(&ctx->Hpki, sizeof(ctx->Hpki), &p, bufferEnd ); CKERR;
    err = sLoadArray(&ctx->MACi, sizeof(ctx->MACi), &p, bufferEnd ); CKERR;
    err = sLoadArray(&ctx->MACr, sizeof(ctx->MACr), &p, bufferEnd ); CKERR;
  
    ctx->isInitiator    = sLoad8(&p);
    ctx->hasCs          = sLoad8(&p);
    ctx->csMatches      = sLoad8(&p);
    ctx->SAS            = sLoad32(&p);

    len = sLoad8(&p);
    ctx->meStr = XMALLOC(len+1 );
    err = sLoadArray(ctx->meStr, len, &p, bufferEnd ); CKERR;
    
    len = sLoad8(&p);
    ctx->youStr = XMALLOC(len+1 );
    err = sLoadArray(ctx->youStr, len, &p, bufferEnd ); CKERR;
    
    PKLen = sLoad8(&p);
    if(PKLen)
    {
        PK = XMALLOC(PKLen); CKNULL(PK);
        err = sLoadArray(PK, PKLen, &p, bufferEnd ); CKERR;
        err = ECC_Init(&ctx->privKey); CKERR;
        err = ECC_Import(ctx->privKey,PK, PKLen); CKERR;
    }
 
    hashStateLen = sLoad16(&p);
    if(hashStateLen)
    {
        hashState = XMALLOC(hashStateLen); CKNULL(hashState);
        err =  sLoadArray(hashState, hashStateLen, &p, bufferEnd ); CKERR;
        err = HASH_Import(hashState, hashStateLen,&ctx->HtotalState); CKERR;
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
        
        if(ctx->privKey)
            ECC_Free(ctx->privKey);
        if(ctx->pubKey)
            ECC_Free(ctx->pubKey);
        if(ctx->meStr)
            XFREE(ctx->meStr);
        if(ctx->youStr)
            XFREE(ctx->youStr);
        if(ctx->HtotalState)
            HASH_Free(ctx->HtotalState);
        
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
  
    if(!ctx->hasKeys ||  ctx->state!=kSCimpState_Ready)
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


SCLError SCimpSendMsg(SCimpContextRef  ctx,
                      void*            data, 
                      size_t           dataLen,
                      void*            userRef)
{
    SCLError err = kSCLError_NoErr;
    
    validateSCimpContext(ctx);
    ValidateParam(data);
    
    err = scSendScimpDataInternal(ctx, data, dataLen, userRef);
    
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
    
    
done:
    return err;
    
}


SCLError SCimpGetInfo( SCimpContextRef scimp, SCimpInfo* info)
{
    int                 err = kSCLError_NoErr;
    
    validateSCimpContext(scimp);
    ValidateParam(info);
    
    info->version       = scimp->version;
    info->cipherSuite   = scimp->cipherSuite;
    info->sasMethod     = scimp->sasMethod;
    
    info->isReady       = scimp->state == kSCimpState_Ready;
    info->isInitiator   = scimp->isInitiator;
    info->hasCs         = scimp->hasCs;
    info->csMatches     = scimp->csMatches;
    
done:
    return err;
    
}

static void B32encode(uint32_t in, char * out)
{
    int i, n, shift;
    
    for (i=0,shift=15; i!=4; ++i,shift-=5)
    {   n = (in>>shift) & 31;
        out[i] = "ybndrfg8ejkmcpqxot1uwisza345h769"[n];
    }
    out[i++] = '\0';
    
}

static  struct  {
    char  alpha;
    char* word;
} nato_table[] =
{
    { 'a', "Alpha" },
    { 'b', "Bravo" },
    { 'c', "Charlie" },
    { 'd', "Delta" },
    { 'e', "Echo" },
    { 'f', "Foxtrot" },
    { 'g', "Golf" },
    { 'h', "Hotel" },
    { 'i', "India" },
    { 'j', "Juliet" },
    { 'k', "Kilo" },
    { 'l', "Lima" },
    { 'm', "Mike" },
    { 'n', "November" },
    { 'o', "Oscar" },
    { 'p', "Papa" },
    { 'q', "Quebec" },
    { 'r', "Romeo" },
    { 's', "Sierra" },
    { 't', "Tango" },
    { 'u', "Uniform" },
    { 'v', "Victor" },
    { 'w', "Whiskey" },
    { 'x', "X-Ray" },
    { 'y', "Yankee" },
    { 'z', "Zulu" },
    { '0', "Zero" },
    { '1', "One" },
    { '2', "Two" },
    { '3', "Three" },
    { '4', "Four" },
    { '5', "Five" },
    { '6', "Six" },
    { '7', "Seven" },
    { '8', "Eight" },
    { '9', "Nine" },
    { '-', "Dash" },
};

static char* sGetNATOword(char c)
{
    int i;
     
    for (i = 0; i < 37; i++)
    {
        if(nato_table[i].alpha == c)
            return ( nato_table[i].word);
    }
    return "ERROR";
 }


static void NATOencode(uint32_t in, char* out, size_t *outLen)
{
    char charBuf[5];
    
     B32encode(in, charBuf);
    
    *outLen =  snprintf(out, *outLen, "%s %s %s %s",
                         sGetNATOword(charBuf[0]),
                         sGetNATOword(charBuf[1]),
                         sGetNATOword(charBuf[2]),
                         sGetNATOword(charBuf[3]) );
    
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
                RETERR(CRYPT_PK_NOT_PRIVATE);
            actualLength = scSCimpCipherBits(ctx->cipherSuite) /4; //  twice the cipher bits in bytes.  AES-128 = 16, AES-256 = 32;
            break;
            
        case kSCimpProperty_SASstring:
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

            default:
                break;
        }
            break;
            
        default:
            RETERR(CRYPT_INVALID_ARG);
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
            switch(ctx->sasMethod)
        {
            case kSCimpSAS_ZJC11:
                B32encode(ctx->SAS,buffer);
                break;
            
            case kSCimpSAS_HEX:
                sprintf(buffer,"%05X", ctx->SAS);
                break;
                
            case kSCimpSAS_NATO:
                NATOencode(ctx->SAS, buffer, &actualLength);
                break;

            default:
                break;
        }

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
    
    err =  sGetSCimpDataPropertyInternal(scimp, whichProperty, outData, bufSize, datSize, false, NULL);
    
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
     
    err =  sGetSCimpDataPropertyInternal(scimp, whichProperty, NULL, 0, datSize, true, (uint8_t**) outData);
    
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
            RETERR(CRYPT_INVALID_ARG);
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
            
        default:
            RETERR(CRYPT_INVALID_ARG);
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
            if(!isValidCipherSuite(prop)) 
                    return kSCLError_BadParams;
            
            
            ctx->cipherSuite = prop;
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
            };
            break;
            
            
        default:
            RETERR(CRYPT_INVALID_ARG);
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
    
done:
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
 

                  
