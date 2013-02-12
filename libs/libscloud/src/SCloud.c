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

#include <tomcrypt.h>
#include "yajl_parse.h"
#include <yajl_gen.h>


#include "SCpubTypes.h"
#include "SCutilities.h"

#include "cryptowrappers.h"
#include "SCloud.h"
#include "SCloudPriv.h"
 
#define	roundup(x, y)	((((x)+((y)-1))/(y))*(y))

static void dumpHex(  uint8_t* buffer, int length, int offset)
{
	char hexDigit[] = "0123456789ABCDEF";
	register int			i;
	int						lineStart;
	int						lineLength;
	short					c;
	const unsigned char	  *bufferPtr = buffer;
#define kLineSize	16
	for (lineStart = 0; lineStart < length; lineStart += lineLength) {
		lineLength = kLineSize;
		if (lineStart + lineLength > length)
			lineLength = length - lineStart;
        
		printf("%6d: ", lineStart+offset);
		for (i = 0; i < lineLength; i++){
			printf("%c", hexDigit[ bufferPtr[lineStart+i] >>4]);
			printf("%c", hexDigit[ bufferPtr[lineStart+i] &0xF]);
			if((lineStart+i) &0x01) printf("%c", ' ');
		}
		for (; i < kLineSize; i++)
			printf("   ");
		printf("  ");
		for (i = 0; i < lineLength; i++) {
			c = bufferPtr[lineStart + i] & 0xFF;
			if (c > ' ' && c < '~')
				printf("%c", c);
			else {
				printf(".");
			}
		}
		printf("\n");
	}
#undef kLineSize
}


#define SCLOUD_HEADER_PAD   20


// the SCLOUD_HEADER_SIZE needs to be a multiple of 16
#define SCLOUD_HEADER_SIZE  (sizeof(uint32_t) + sizeof(uint32_t) +  sizeof(uint32_t) + SCLOUD_HEADER_PAD)


/*____________________________________________________________________________
 validity test  
 ____________________________________________________________________________*/

static bool scloudContextIsValid( const SCloudContext * ref)
{
	bool	valid	= false;
	
	valid	= IsntNull( ref ) && ref->magic	 == kSCloudContextMagic;
	
	return( valid );
}




static SCLError  sComputeKDF(uint8_t*        K,
                             unsigned long   Klen,
                             char*           label,
                             uint8_t*        context,
                             unsigned long   contextLen,
                             uint32_t        hashLen,
                             unsigned long   outLen,
                             uint8_t         *out)
{
    SCLError             err = kSCLError_NoErr;
    MAC_ContextRef  macRef = kInvalidMAC_ContextRef;
    uint8_t            L[4];
    unsigned long   resultLen = 0;
    
    L[0] = (hashLen >> 24) & 0xff;
    L[1] = (hashLen >> 16) & 0xff;
    L[2] = (hashLen >> 8) & 0xff;
    L[3] = hashLen & 0xff;
    
    err  = MAC_Init( kMAC_Algorithm_HMAC,
                     kHASH_Algorithm_SHA256,
                    K, Klen, &macRef); CKERR;
    
    MAC_Update(macRef,  "\x00\x00\x00\x01",  4);
    MAC_Update(macRef,  label,  strlen(label));
    MAC_Update(macRef,  "\x00",  1);
    MAC_Update(macRef,  context, contextLen);
    MAC_Update(macRef,  L,  4);
    
    resultLen = outLen;
    MAC_Final( macRef, out, &resultLen);
    
done:
    
    if(IsntNull(macRef))
        MAC_Free(macRef);
    
    return err;
}

static SCLError scEventError(
                             SCloudContextRef   ctx,
                             SCLError          error
                             )
{
    SCLError             err         = kSCLError_NoErr;
 	SCloudEvent          event;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    event.type							= kSCloudEvent_Error;
 	event.data.errorData.error        = error;
    
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}



static SCLError scEventInit(
                            SCloudContextRef   ctx )
{
    SCLError             err         = kSCLError_NoErr;
 	SCloudEvent          event;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    event.type							= kSCloudEvent_Init;
    
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}


static SCLError scEventDone(
                            SCloudContextRef   ctx )
{
    SCLError             err         = kSCLError_NoErr;
 	SCloudEvent          event;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    event.type							= kSCloudEvent_Done;
    
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}


static SCLError scEventProgress (SCloudContextRef   ctx,
                                size_t              bytesProcessed,
                                size_t              bytesTotal)
{
    SCLError             err         = kSCLError_NoErr;
 	SCloudEvent          event;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    event.type							= kSCloudEvent_Progress;
    event.data.progress.bytesProcessed       = bytesProcessed;
    event.data.progress.bytesTotal           = bytesTotal;
    
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
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

SCLError    SCloudEncryptNew (void *contextStr,     size_t contextStrLen,
                              void *data,           size_t dataLen,
                              void *metaData,       size_t metaDataLen,
                              SCloudEventHandler    handler,
                              void*                 userValue,
                              SCloudContextRef      *cloudRefOut)
{
    SCLError               err          = kSCLError_NoErr;
    SCloudContext*         ctx          = kInvalidSCloudContextRef;
    
    ValidateParam(cloudRefOut);
    
    ctx = XMALLOC(sizeof (SCloudContext)); CKNULL(ctx);
    
    ZERO(ctx, sizeof(SCloudContext));
    ctx->magic          = kSCloudContextMagic;
    ctx->state          = kSCloudState_Init;
    ctx->bEncrypting    = true;
    
    ctx->contextStr     = contextStr;
    ctx->contextStrLen  = contextStrLen;
    ctx->dataBuffer     = data;
    ctx->dataLen        = dataLen;
    ctx->metaBuffer     = metaData;
    ctx->metaLen        = metaDataLen;
    
    ctx->handler        = handler;
    ctx->userValue      = userValue;
          
    *cloudRefOut = ctx; 
    
done:
    
     return err;
}


SCLError	SCloudCalculateKey ( SCloudContextRef ctx, size_t blocksize)
{
    SCLError err = kSCLError_NoErr;
    HASH_ContextRef        hashRef      = kInvalidHASH_ContextRef;
    uint8_t                 symKey[64];
    size_t                  symKeyLen = 0;
    
    size_t                  totalBytes = ctx->metaLen + ctx->dataLen;
    size_t                  bytesProcessed = 0;
    
    uint8_t                 *p;
    size_t                  bytes_left;
     
    validateSCloudContext(ctx);
 
    err = scEventInit(ctx); CKERR;
    
    err = HASH_Init( kHASH_Algorithm_SKEIN256 , & hashRef); CKERR;
    err = HASH_GetSize(hashRef, &symKeyLen);
    
    if(ctx->metaBuffer && ctx->metaLen > 0)
    {
        err = HASH_Update( hashRef, ctx->metaBuffer,  ctx->metaLen); CKERR;
    }
    bytesProcessed+=ctx->metaLen;
    err =  scEventProgress(ctx, bytesProcessed, totalBytes );

    for(  p = ctx->dataBuffer, bytes_left = ctx->dataLen;
        bytes_left > 0;)
    {
        size_t bytes2Hash = blocksize < bytes_left?blocksize:bytes_left;
        
        err = HASH_Update( hashRef, p,  bytes2Hash); CKERR;
        
        bytes_left -=bytes2Hash;
        p+=bytes2Hash;
        err =  scEventProgress(ctx, totalBytes - bytes_left , totalBytes );
    }
      
    err = HASH_Final( hashRef, symKey); CKERR;
    
    HASH_Free(hashRef); hashRef = NULL;
    
#if 1
    
    err = sComputeKDF(symKey,  symKeyLen,
                      "ScloudLocator",
                      ctx->contextStr, ctx->contextStrLen,
                      SCLOUD_LOCATOR_LEN >> 3,
                      SCLOUD_LOCATOR_LEN,
                      ctx->locator); CKERR;
    
#else
    err = HASH_Init( kHASH_Algorithm_SKEIN256, & hashRef); CKERR;
    err = HASH_Update( hashRef, symKey,  symKeyLen); CKERR;
    err = HASH_Final( hashRef, ctx->locator); CKERR;
#endif
    
    ctx->key.keySuite = kSCloudKeySuite_AES128;
    ctx->key.algorithm = kCipher_Algorithm_AES128;
    ctx->key.symKeyLen = symKeyLen;
    COPY(symKey, ctx->key.symKey, symKeyLen);
     
    err = CBC_Init(ctx->key.algorithm, symKey, symKey + (symKeyLen>>1),  &ctx->cbc);CKERR;
       
    ctx->state = kSCloudState_Hashed;

done:
    
    err = scEventDone(ctx); CKERR;
    
    if(!IsNull(hashRef))
        HASH_Free(hashRef);
    
    ZERO(symKey, sizeof(symKey));
    
    return err;

}

void	SCloudFree (SCloudContextRef ctx  ) 
{
    
    if(scloudContextIsValid(ctx))
    {
         CBC_Free(ctx->cbc); 
        ZERO(ctx, sizeof(SCloudContext));
        XFREE(ctx);
    }
    
    
}



SCLError	SCloudEncryptGetKey ( SCloudContextRef ctx,
                                 uint8_t * buffer, size_t *bufferSize)
{
    SCLError err = kSCLError_NoErr;
    
    validateSCloudContext(ctx);
    ValidateParam(buffer);
    ValidateParam(bufferSize);
    
    if(ctx->state == kSCloudState_Init)
        RETERR(kSCLError_ImproperInitialization);
 
 //   if(*bufferSize < sizeof(ctx->key))
//         RETERR(kSCLError_BadParams);
    
    COPY(ctx->key.symKey, buffer, ctx->key.symKeyLen);
    *bufferSize = ctx->key.symKeyLen;
    
    
done:
    
    return err;
}


SCLError	SCloudEncryptGetKeyREST ( SCloudContextRef ctx,
                                         uint8_t * buffer, size_t *bufferSize)
{
    SCLError err = kSCLError_NoErr;
    size_t      outlen = 0;
    
    validateSCloudContext(ctx);
    ValidateParam(buffer);
    ValidateParam(bufferSize);
 
    if(ctx->state == kSCloudState_Init)
        RETERR(kSCLError_ImproperInitialization);

    outlen = URL64_encodeLength(ctx->key.symKeyLen);
    
    if(*bufferSize < outlen)
        RETERR(kSCLError_BadParams);
    
    err = URL64_encode(ctx->key.symKey, ctx->key.symKeyLen, buffer, &outlen);
    
    *bufferSize = outlen;
    
done:
    
    return err;
}



SCLError	SCloudEncryptGetLocator ( SCloudContextRef ctx,
                                     uint8_t * buffer, size_t *bufferSize)
{
    SCLError err = kSCLError_NoErr;
    
    validateSCloudContext(ctx);
    ValidateParam(buffer);
    ValidateParam(bufferSize);
    ValidateParam(*bufferSize  >= (TRUNCATED_LOCATOR_BITS >>3))
   
    if(ctx->state == kSCloudState_Init)
        RETERR(kSCLError_ImproperInitialization);

    if(*bufferSize < sizeof(ctx->locator))
        RETERR(kSCLError_BadParams);
    
    COPY(ctx->locator, buffer, TRUNCATED_LOCATOR_BITS >>3);
    *bufferSize = TRUNCATED_LOCATOR_BITS >>3;
    
done:
    
    return err;
}


SCLError	SCloudEncryptGetLocatorREST ( SCloudContextRef ctx, 
                                     uint8_t * buffer, size_t *bufferSize)
{
    SCLError err = kSCLError_NoErr;
    size_t      outlen = 0;
    
    validateSCloudContext(ctx);
    ValidateParam(buffer);
    ValidateParam(bufferSize);
    
    outlen = URL64_encodeLength(TRUNCATED_LOCATOR_BITS >>3);
    
    ValidateParam(*bufferSize  >= outlen)
     
    if(ctx->state == kSCloudState_Init)
        RETERR(kSCLError_ImproperInitialization);
    
    err = URL64_encode(ctx->locator, TRUNCATED_LOCATOR_BITS >>3, buffer, &outlen);
    
     *bufferSize = outlen;
    
done:
    
    return err;
}




static SCLError	sCloudEncryptNextInternal (
                                    SCloudContextRef ctx,
                                    uint8_t *buffer, size_t *bufferSize) 
{
    SCLError err = kSCLError_NoErr;
    
    uint8_t *p         = buffer;
    size_t  bufferLeft = *bufferSize;
    size_t  bytes2Copy = 0;
    size_t  bytesUsed  = 0;
    size_t  bytes2Pad  = 0; 
 
     do {
        switch(ctx->state)
        {
            case kSCloudState_Hashed:
                
                sStore32(ctx->magic, &p);
                sStore32((uint32_t)ctx->metaLen, &p);
                sStore32((uint32_t)ctx->dataLen, &p);
                
                sStorePad(SCLOUD_HEADER_PAD, SCLOUD_HEADER_PAD, &p);
    
                bufferLeft -= (p - buffer);
                
                if( ctx->metaLen)
                {
                    ctx->buffPtr = ctx->metaBuffer;
                    ctx->byteCount = ctx->metaLen;
                    ctx->state = kSCloudState_Meta;
                }
                else if(ctx->dataLen)
                {
                    ctx->buffPtr = ctx->dataBuffer;
                    ctx->byteCount = ctx->dataLen;
                    ctx->state = kSCloudState_Data;
                }
                else 
                {
                    ctx->state = kSCloudState_Pad;
                }
                
                break;
                
            case kSCloudState_Meta:
                
                if(ctx->byteCount == 0)
                {
                    ctx->buffPtr = ctx->dataBuffer;
                    ctx->byteCount = ctx->dataLen;
                    ctx->state = kSCloudState_Data;
                }
                
                break;
                
            case kSCloudState_Data:
                
                if(ctx->byteCount == 0)
                {
                    ctx->state = kSCloudState_Pad;
                }
                break;
                
            case kSCloudState_Pad:
                
                bytesUsed = *bufferSize - bufferLeft;
                bytes2Pad = roundup( bytesUsed, SCLOUD_BLOCK_LEN) - bytesUsed;
                
                 if( bytes2Pad )     
                {
                    // we need to pad to end of block
                    memset(p, bytes2Pad, bytes2Pad);
                    bytesUsed += bytes2Pad;
                    ctx->state = kSCloudState_Done;
                }
                else 
                {           
                    // we need to pad an entire block.
                    memset(p, SCLOUD_BLOCK_LEN, SCLOUD_BLOCK_LEN);
                    p+= SCLOUD_BLOCK_LEN;
                    bufferLeft -= SCLOUD_BLOCK_LEN;
                    bytesUsed += SCLOUD_BLOCK_LEN;
                    ctx->state = kSCloudState_Done;
                }
                break;
                
            case kSCloudState_Done:
                 err = kSCLError_EndOfIteration;
                break;
                
                
            default:
                err = kSCLError_ImproperInitialization;
                break;
        }
        
        bytes2Copy = MIN(bufferLeft, ctx->byteCount );
        
        if(bytes2Copy)
        {
            COPY(ctx->buffPtr,  p, bytes2Copy );
            ctx->byteCount -= bytes2Copy;
            ctx->buffPtr += bytes2Copy;
            p+= bytes2Copy;
            bufferLeft -= bytes2Copy;
            bytesUsed = *bufferSize - bufferLeft;
         }
        
    } while (bufferLeft && ctx->state != kSCloudState_Done);
     
    
    if(IsntSCLError(err) && bytesUsed)
    {
         err = CBC_Encrypt(ctx->cbc, buffer, bytesUsed, buffer); CKERR;
    }
    
    *bufferSize = bytesUsed;
    
done:
    
    return err;
    
}

SCLError	SCloudEncryptNext ( SCloudContextRef ctx,
                               uint8_t *buffer, size_t *bufferSize) 
{
    SCLError err = kSCLError_NoErr;
      
    validateSCloudContext(ctx);
    ValidateParam(buffer);
    ValidateParam(bufferSize);
   
    if(ctx->state == kSCloudState_Init)
        RETERR(kSCLError_ImproperInitialization);
 
    if(*bufferSize < SCLOUD_MIN_BUF_SIZE)
        RETERR(kSCLError_BadParams);
    
    if(*bufferSize % (SCLOUD_BLOCK_LEN) != 0)
        RETERR(kSCLError_BadParams);
    
    
    err = sCloudEncryptNextInternal(ctx, buffer, bufferSize);
       
done:
    
    return err;
}




static SCLError scEventDecryptData(
                        SCloudContextRef     ctx,
                        uint8_t*            data, 
                        size_t              dataLen
                        )
{
    SCLError             err         = kSCLError_NoErr;
 	SCloudEvent         event;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
     
  	event.type                         = kSCloudEvent_DecryptedData;
 	event.data.decryptData.data        = data;
    event.data.decryptData.length      = dataLen;
    
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}

static SCLError scEventDecryptMeta(
                               SCloudContextRef     ctx,
                               uint8_t*            data, 
                               size_t              dataLen
                               )
{
    SCLError             err         = kSCLError_NoErr;
 	SCloudEvent         event;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    
  	event.type                         = kSCloudEvent_DecryptedMetaData;
 	event.data.metaData.data        = data;
    event.data.metaData.length      = dataLen;
    
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}

static SCLError scEventDecryptMetaComplete(
                                   SCloudContextRef     ctx,
                                   size_t              metaDataTotalLen
                                   )
{
    SCLError             err         = kSCLError_NoErr;
 	SCloudEvent         event;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    
  	event.type                      = kSCloudEvent_DecryptedMetaDataComplete;
 	event.data.metaData.data        = 0;
    event.data.metaData.length      = metaDataTotalLen;
  	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}
 



SCLError    SCloudDecryptNew (uint8_t * key, size_t keyLen,
                              SCloudEventHandler    handler, 
                              void*                 userValue,
                              SCloudContextRef      *cloudRefOut)

{
    SCLError               err          = kSCLError_NoErr;
    SCloudContext*         ctx          = kInvalidSCloudContextRef;
    
    uint8_t             keyData[128] = {0};
    size_t              keyDataLen = sizeof(keyData);
    
    ValidateParam(cloudRefOut);
    ValidateParam(key);
    ValidateParam(keyLen > 31);
    
    // handle old keys
    if(keyLen == 32)
    {
        COPY(key, keyData, keyLen);
        keyDataLen = keyLen;
    }
    else if(key[0] != '{' )
    {
        err =  URL64_decode(key, keyLen, keyData, &keyDataLen); CKERR;
    }
 
    ctx = XMALLOC(sizeof (SCloudContext)); CKNULL(ctx);
    
    ZERO(ctx, sizeof(SCloudContext));
    ctx->magic          = kSCloudContextMagic;
    ctx->state          = kSCloudState_Init;
    ctx->bEncrypting    = false;
  
    ctx->tmpCnt      = 0;
    
    ctx->handler        = handler;
    ctx->userValue      = userValue;
    
     if(keyDataLen == 32)
    {
        //simple AES128 key
        
        ctx->key.keySuite = kSCloudKeySuite_AES128;
        ctx->key.algorithm = kCipher_Algorithm_AES128;
        ctx->key.symKeyLen = keyDataLen;
        COPY(keyData, ctx->key.symKey, keyDataLen);
     }
    else
    {
        // version 2 JSON key
         err =  scloudDeserializeKey( key, keyLen, &ctx->key); CKERR;
    }
 
      
    err = CBC_Init(ctx->key.algorithm, ctx->key.symKey, ctx->key.symKey + (ctx->key.symKeyLen >>1),  &ctx->cbc);CKERR;
    
    *cloudRefOut = ctx; 

done:
    
    ZERO(keyData, sizeof(keyData));
      return err;

}

#define SCLOUD_DECRYPT_BUF_SIZE 4096

SCLError	SCloudDecryptNext ( SCloudContextRef ctx,
                               uint8_t *in, size_t inSize)
{
    
    SCLError    err        = kSCLError_NoErr;
    
    uint8_t *p          = in;
    size_t  bytesLeft   = inSize;
     
    uint8_t ptBuf[SCLOUD_DECRYPT_BUF_SIZE];
    size_t  ptBufLen    = 0;
    size_t   metaDataTotalLen = 0;
       
    validateSCloudContext(ctx);
    ValidateParam(in);
    
    if(ctx->bEncrypting)
        RETERR(kSCLError_BadParams);
    
    
    if( inSize == 0 && ctx->state == kSCloudState_Done)
    {
        scEventDone(ctx);
        RETERR( kSCLError_EndOfIteration);
        
    }
    
    while(true)
    {
        uint8_t *p1 = ptBuf + ptBufLen;
 
        if((ctx->tmpCnt > 0) ||  ((bytesLeft > 0) &&  (bytesLeft < SCLOUD_HEADER_SIZE )))
        {
            size_t bytes2Store = (ctx->state == kSCloudState_Init)?SCLOUD_HEADER_SIZE : SCLOUD_BLOCK_LEN;
            size_t bytes2copy = MIN(bytes2Store - ctx->tmpCnt, bytesLeft);
            if(bytes2copy)
            {
                COPY(p, ctx->tmpBuf + ctx->tmpCnt, bytes2copy);
                p+= bytes2copy;
                bytesLeft -= bytes2copy;
                ctx->tmpCnt += bytes2copy;
            }
            
            if(ctx->tmpCnt == bytes2Store)
            {
                err = CBC_Decrypt(ctx->cbc, ctx->tmpBuf, bytes2Store, ptBuf); CKERR; 
                ptBufLen+=bytes2Store;
                ctx->tmpCnt= 0;
            }
        }
        
        if(bytesLeft)
        {
            size_t bytes2copy = MIN(SCLOUD_DECRYPT_BUF_SIZE - ptBufLen, bytesLeft);
            
            bytes2copy = (bytes2copy / SCLOUD_BLOCK_LEN) * SCLOUD_BLOCK_LEN;
            
            err = CBC_Decrypt(ctx->cbc, p, bytes2copy, ptBuf+ptBufLen); CKERR; 
            ptBufLen +=bytes2copy;
            p +=bytes2copy;
            bytesLeft -= bytes2copy;
        }
            
         if( ptBufLen == 0 ) break;
        
         while(ptBufLen) switch(ctx->state)
        {
            case kSCloudState_Init:
                
                scEventInit(ctx);
                ctx->state = kSCloudState_Header;
                break;
                
            case kSCloudState_Header:
                
                if(  sLoad32(&p1) != kSCloudContextMagic) 
                {
                    scEventError(ctx, kSCLError_CorruptData);
                    RETERR(kSCLError_CorruptData);
                }
                
                ctx->metaLen = sLoad32(&p1);
                ctx->dataLen = sLoad32(&p1);
                p1+=SCLOUD_HEADER_PAD;
                ptBufLen -= SCLOUD_HEADER_SIZE;
                ctx->state  = kSCloudState_Meta;
                break;
                
                
            case kSCloudState_Meta:
                
                if(ctx->metaLen)
                {
                    size_t metaBytes = MIN(ptBufLen, ctx->metaLen);
                    err = scEventDecryptMeta(ctx, p1, metaBytes); CKERR;
                    p1+= metaBytes;
                    metaDataTotalLen+=metaBytes;
                    ctx->metaLen -= metaBytes;
                    ptBufLen -= metaBytes;
                } 
                else
                {
                    err = scEventDecryptMetaComplete(ctx,metaDataTotalLen); CKERR;
                    ctx->state = kSCloudState_Data;
                }
                break;
                
            case kSCloudState_Data:
                
                if(ctx->dataLen)
                {
                    size_t dataBytes = MIN(ptBufLen, ctx->dataLen);
                    err = scEventDecryptData(ctx, p1, dataBytes); CKERR;
                    p1+= dataBytes;
                    ctx->dataLen -= dataBytes;
                    ptBufLen -= dataBytes;
                }
                else 
                {
                    ctx->state = kSCloudState_Pad;
                    ctx->padLen  = ptBufLen;
                    if(ctx->padLen == 0) ctx->padLen = SCLOUD_BLOCK_LEN;
                }
                break;
                
                
            case kSCloudState_Pad:
                
                if(ctx->padLen)
                {
                    size_t padBytes = MIN(ptBufLen, ctx->padLen);
                    p1+= padBytes;
                    ctx->padLen -= padBytes;
                    ptBufLen -= padBytes;
                }
                
                if(ctx->padLen == 0)
                {
                    ctx->state  = kSCloudState_Done;
                }
                 break;
                     
            default:
                err = kSCLError_UnknownError;
                break;
        }
     }
   
 
 done:
    if(inSize)  ZERO(ptBuf, SCLOUD_DECRYPT_BUF_SIZE);
    
    return err;
    
}



SCLError  SCloudGetVersionString(size_t	bufSize, char *outString)
{
    SCLError                 err = kSCLError_NoErr;
    
    ValidateParam(outString);
    *outString = 0;
    
    char version_string[32];
    
    sprintf(version_string, "%s (%03d)", SCLOUD_SHORT_VERSION_STRING, SCLOUD_BUILD_NUMBER);
   
    if(strlen(version_string) +1 > bufSize)
        RETERR (kSCLError_BufferTooSmall);
    
    strcpy(outString, version_string);
    
done:
    return err;
}



