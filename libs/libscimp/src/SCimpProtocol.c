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

/**
 @file SCimpProtocol.c 
 SCIMP Protocol specific code 
 */


#include "SCpubTypes.h"
#include "cryptowrappers.h"
#include "SCimp.h"
#include "SCimpPriv.h"
#include <stdio.h>
#include <errno.h>
 #include <tomcrypt.h>


/*____________________________________________________________________________
 General data types used by Silent Circle Code
 ____________________________________________________________________________*/


#define HIuint8_t(n) ((n >> 8) & 0xff)
#define LOuint8_t(n) (n & 0xff)

static const uint8_t *kSCimpstr_Initiator = "Initiator";
static const uint8_t *kSCimpstr_Responder = "Responder";
  
typedef SCLError (*SCstateHandler)(SCimpContextRef ctx,  SCimpMsg* msg);


typedef struct  state_table_type
{
    SCimpState              current;
    SCimpTransition         trans;
    SCimpState              next;
    SCstateHandler          func;
    
}state_table_type;


#pragma mark
#pragma mark debuging 


#pragma mark
#pragma mark utility 

bool isValidSASMethod( SCimpSAS method )
{
    return ( method >= kSCimpSAS_ZJC11 && method <= kSCimpSAS_HEX); 
}

bool isValidCipherSuite( SCimpCipherSuite suite )
{
    return ( suite >= kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384 && suite <= kSCimpCipherSuite_SKEIN_AES256_ECC384); 
}

static bool isZeroBuff(uint8_t * p, size_t len)
{
    for( ; len > 0; len--)
        if(*p++ != 0) return(false);
    return true;
}

static uint64_t mod_diff(uint64_t a, uint64_t b,  uint64_t max_num )
{
    
    uint64_t  c = a + ((b > a) ? ( UINT64_MAX - b) + 1: - b);
    return c;
}

#pragma mark
#pragma mark debuging

#if  DEBUG_PROTOCOL || DEBUG_STATES || DEBUG_CRYPTO
static void dumpHex(  uint8_t* buffer, int length, int offset);


#define XCODE_COLORS_ESCAPE_MAC "\033["
#define XCODE_COLORS_ESCAPE_IOS "\xC2\xA0["

#if TARGET_OS_IPHONE
#define XCODE_COLORS_ESCAPE  XCODE_COLORS_ESCAPE_IOS
#else
#define XCODE_COLORS_ESCAPE  XCODE_COLORS_ESCAPE_MAC
#endif

#define XCODE_COLORS_RESET_FG   "fg;" // Clear any foreground color
#define XCODE_COLORS_RESET_BG  "bg;" // Clear any background color
#define XCODE_COLORS_RESET     ";"   // Clear any foreground or background color

#define XCODE_COLORS_BLUE_TXT  "fg0,0,255;"
#define XCODE_COLORS_RED_TXT  "fg255,0,0;" 
#define XCODE_COLORS_GREEN_TXT  "fg0,128,0;" 


static int DPRINTF(const char *color, const char *fmt, ...)
{
	va_list marker;
	char s[8096];
	int len;
	
	va_start( marker, fmt );     
	len = vsnprintf( s, sizeof(s), fmt, marker );
	va_end( marker ); 
    
    if(color)  printf("%s%s",  XCODE_COLORS_ESCAPE, color);
    
    printf( "%s",s);
 
    if(color)  printf("%s%s",  XCODE_COLORS_ESCAPE, XCODE_COLORS_RESET);

    fflush(stdout);
    
	
	return 0;
}

#endif

#if  DEBUG_STATES

static  char*  stateText( SCimpState state )
{
    static struct
    {
        SCimpState      state;
        char*           txt;
    }state_txt[] =
    {
        { kSCimpState_Init,		"Init"},
        { kSCimpState_Ready,	"Ready"},
        { kSCimpState_Commit,	"Commit"},
        { kSCimpState_DH2,		"DH2"},
        { kSCimpState_DH1,		"DH1"},
        { kSCimpState_Confirm,	"Confirm"},
        {NO_NEW_STATE,         "NO_NEW_STATE"},
        {0,NULL}
    };
    
    int i;
    
    for(i = 0; state_txt[i].txt; i++)
        if(state_txt[i].state == state) return(state_txt[i].txt);
    
    return "Invalid";
    
}

#endif

#pragma mark
#pragma mark  Setup and Teardown 

/*____________________________________________________________________________
 Setup and Teardown 
 ____________________________________________________________________________*/
 

void scResetSCimpContext(SCimpContext *ctx, bool resetAll)
{ 
    ctx->state          = kSCimpState_Init;
    ctx->isInitiator    = false;
    ctx->version        = kSCimpProtocolVersion;
  
    ctx->hasKeys            = false;
    ctx->csMatches          = false;
    
    scEventTransition(ctx, kSCimpState_Init);
       
    if(ctx->privKey)
    {
        ECC_Free(ctx->privKey);
        ctx->privKey = kInvalidECC_ContextRef;
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
    
    ZERO(ctx->Cs1,  SCIMP_KEY_LEN);
    
    ZERO(ctx->Rcv,  sizeof(ctx->Rcv));
    ctx->rcvIndex = 0;
    
    ZERO(ctx->Ksnd, SCIMP_KEY_LEN);
    ZERO(ctx->Hcs,  SCIMP_MAC_LEN);
    ZERO(ctx->Hpki, SCIMP_HASH_LEN);
    ZERO(ctx->MACi, SCIMP_MAC_LEN);
    ZERO(ctx->MACr, SCIMP_MAC_LEN);
   
    
    if(resetAll)
    {
        ctx->hasCs              = false;
        ZERO(ctx->Cs,   SCIMP_KEY_LEN);
        ctx->msgFormat          = kSCimpMsgFormat_JSON;
        ctx->cipherSuite        = kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384;
        ctx->sasMethod          = kSCimpSAS_ZJC11;
        ctx->serializeHandler   = scimpSerializeMessageJSON;
        ctx->deserializeHandler = scimpDeserializeMessageJSON;
    }

}


#pragma mark
#pragma mark  crypto helpers 
 
static void ntoh64( uint64_t val, void *ptr )
{
    uint8_t *bptr = ptr;
    *bptr++ = (uint8_t)(val>>56);
    *bptr++ = (uint8_t)(val>>48);
    *bptr++ = (uint8_t)(val>>40);
    *bptr++ = (uint8_t)(val>>32);
    *bptr++ = (uint8_t)(val>>24);
    *bptr++ = (uint8_t)(val>>16);
    *bptr++ = (uint8_t)(val>> 8);
    *bptr++ = (uint8_t)val;
}


static  SCLError sGetNextFreeRcvKeyIndex(SCimpContextRef ctx, uint8_t *indexOut)
{
    SCLError err = kSCLError_ResourceUnavailable;
    uint8_t   i = 0;
    
    
    for(i = 0; i< SCIMP_RCV_QUEUE_SIZE; i++)
    {
        if(ctx->Rcv[i].index == 0)
        {
            *indexOut = i;
            RETERR( kSCLError_NoErr);
        }
    }
    
done:
    return err;
}

static HASH_Algorithm sSCimptoWrapperHASH(SCimpCipherSuite  suite, size_t hashSize)
{
    HASH_Algorithm alg = kHASH_Algorithm_Invalid;
    
    switch(suite)
    {
        case kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384:        
            alg = kHASH_Algorithm_SHA256; 
            break;
            
        case kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384:
            alg =  (hashSize > 256) ? kHASH_Algorithm_SHA512 : kHASH_Algorithm_SHA512_256;
            break;
           
        case kSCimpCipherSuite_SKEIN_AES256_ECC384: 
            alg =  (hashSize > 256) ?kHASH_Algorithm_SKEIN512 : kHASH_Algorithm_SKEIN256;
            break;
            
        default: break;            
    }
    return alg;
}



int scSCimpCipherBits(SCimpCipherSuite  suite)
{
    switch(suite)
    {
        case kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384:        return(128);
        case kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384:     return(256);
         case kSCimpCipherSuite_SKEIN_AES256_ECC384: return(256);
        default: return 0;
            
    }
}
 

 
static MAC_Algorithm sSCimptoWrapperMAC(SCimpCipherSuite  suite)
{
    switch(suite)
    {
        case kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384:            return(kMAC_Algorithm_HMAC);
        case kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384:         return(kMAC_Algorithm_HMAC);
        case kSCimpCipherSuite_SKEIN_AES256_ECC384:   return(kMAC_Algorithm_SKEIN);
        default: return kMAC_Algorithm_Invalid;
            
    }
    
}


static int sECCDH_Bits(SCimpCipherSuite  suite)
{
    int  ecc_size  = 0;
    
    switch(suite)
    {
        case kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384:        ecc_size = 384; break;
        case kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384:     ecc_size = 384; break;
        case kSCimpCipherSuite_SKEIN_AES256_ECC384: ecc_size = 384; break;
   default:
            break;
    }
    
    return ecc_size;
}


static SCLError sMakeHash(SCimpCipherSuite suite, const unsigned char *in, unsigned long inlen, unsigned long outLen, uint8_t *out)
{
    SCLError             err         = kSCLError_NoErr;
    HASH_ContextRef     hashRef     = kInvalidHASH_ContextRef;
 	uint8_t             hashBuf[SCIMP_HASH_LEN];	
    uint8_t             *p = (outLen < sizeof(hashBuf))?hashBuf:out;
    
    err = HASH_Init( sSCimptoWrapperHASH(suite, SCIMP_HASH_LEN * 8), & hashRef); CKERR;
    err = HASH_Update( hashRef, in,  inlen); CKERR;
    err = HASH_Final( hashRef, p); CKERR;
    
    if((err == kSCLError_NoErr) & (p!= out))
        COPY(hashBuf, out, outLen);
    
done:   
    if(!IsNull(hashRef))
        HASH_Free(hashRef);
    
    return err;
}

static SCLError sComputeSSmac(SCimpContext* ctx,
                         uint8_t* pk, unsigned long pkLen, 
                         const char *str, uint8_t *out)
{
    SCLError             err = kSCLError_NoErr;
    HASH_ContextRef hashRef     = kInvalidHASH_ContextRef;
    MAC_ContextRef  macRef      = kInvalidMAC_ContextRef;
    uint8_t            hashBuf [32];
    unsigned long   resultLen;
    
    err = HASH_Init( sSCimptoWrapperHASH(ctx->cipherSuite, 256), & hashRef); CKERR;
    err = HASH_Update( hashRef,  pk,  pkLen); CKERR;
    err = HASH_Update( hashRef,  str,  strlen(str)); CKERR;
    err = HASH_Final( hashRef, hashBuf); CKERR;
    
    err = MAC_Init( sSCimptoWrapperMAC(ctx->cipherSuite),
                   sSCimptoWrapperHASH(ctx->cipherSuite, 256),
                   ctx->Cs,
                   scSCimpCipherBits(ctx->cipherSuite) /4,  //  twice the cipher bits in bytes.  AES-128 = 16, AES-256 = 32
                   &macRef); CKERR;
    err = MAC_Update(macRef,  hashBuf,  sizeof(hashBuf)); CKERR;
    
    resultLen = SCIMP_MAC_LEN;
    err = MAC_Final( macRef, out, &resultLen); CKERR;
    
done:
    
    if(!IsNull(hashRef)) 
        HASH_Free(hashRef);
    
    if(!IsNull(macRef)) 
        MAC_Free(macRef);
    
    return err;
}


static SCLError sComputeSessionID(SCimpContext* ctx)
{
    SCLError     err = kSCLError_NoErr;
    const char *initStr =  ctx->isInitiator?ctx->meStr:ctx->youStr;
    const char* respStr  = !ctx->isInitiator?ctx->meStr:ctx->youStr; 
    size_t      len = 0;
    uint8_t     *sIDStr = NULL;
    uint8_t     *p;
    
    
    len += (initStr?strlen(initStr):0) +1;
    len +=(respStr?strlen(respStr):0) +1;
    p = sIDStr = XMALLOC(len);
    
    *p++ = initStr?strlen(initStr):0 ;
    if(initStr)
    {  
        len = strlen(initStr);
        memcpy(p, initStr, len);
        p+=len;
    }
    
    *p++ = respStr?strlen(respStr):0 ;
    if(respStr)
    {  
        len = strlen(respStr);
        memcpy(p, respStr, len);
        p+=len;
    }
    
      err = sMakeHash(ctx->cipherSuite,sIDStr, p-sIDStr, sizeof(ctx->SessionID),  ctx->SessionID);
    
     
done:
    
    if(IsntNull(sIDStr))
        XFREE(sIDStr);
  
    return err;
}



static uint8_t* sMakeContextString(const char *initStr, const char* respStr, uint8_t *hTotal, unsigned long *outLen)
{
    size_t len = 0;
    uint8_t *contextStr = NULL;
    uint8_t *p;
    
    len += (initStr?strlen(initStr):0) +1;
    len +=(respStr?strlen(respStr):0) +1;
    len += 64;
    p = contextStr = XMALLOC(len);
    
    *p++ = initStr?strlen(initStr):0 ;
    if(initStr)
    {  
        len = strlen(initStr);
        memcpy(p, initStr, len);
        p+=len;
    }
    
    *p++ = respStr?strlen(respStr):0 ;
    if(respStr)
    {  
        len = strlen(respStr);
        memcpy(p, respStr, len);
        p+=len;
    }
    
    memcpy(p, hTotal, SCIMP_HTOTAL_BITS/8);
    *outLen = p-contextStr+SCIMP_HTOTAL_BITS/8;
    
    return contextStr;
}


static SCLError  sComputeKDF(SCimpContext* ctx,
                            uint8_t*        K,
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

    err  = MAC_Init( sSCimptoWrapperMAC(ctx->cipherSuite),
             sSCimptoWrapperHASH(ctx->cipherSuite, hashLen), 
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


static SCLError sAdvanceSendKey(SCimpContext* ctx )
{
    SCLError             err = kSCLError_NoErr;
    MAC_ContextRef      macRef = kInvalidMAC_ContextRef;
    const char          *label = "MessageKey";
    
    int                 keyBits     = scSCimpCipherBits(ctx->cipherSuite);
    unsigned long       resultLen   = sizeof(ctx->Ksnd);
     
    err  = MAC_Init( sSCimptoWrapperMAC(ctx->cipherSuite),
                    sSCimptoWrapperHASH(ctx->cipherSuite, keyBits*2),
                    ctx->Ksnd, keyBits/4,
                    &macRef); CKERR;
    
    MAC_Update(macRef,  "\x00\x00\x00\x01",  4);
    MAC_Update(macRef,  label,  strlen(label));
    MAC_Update(macRef,  "\x00",  1);
    MAC_Update(macRef,  ctx->SessionID, SCIMP_HASH_LEN);
    MAC_Update(macRef,  &ctx->Isnd, sizeof(ctx->Isnd));
    MAC_Update(macRef, (uint8_t*) "\x00\x00\x01\x00",  4);
    
    MAC_Final( macRef, ctx->Ksnd, &resultLen);
    
    ctx->Isnd++;
    
done:
    if(IsntNull(macRef))
        MAC_Free(macRef);
    
    return err;
}

static SCLError sAdvanceRcvKey(SCimpContext* ctx, uint8_t newIndex)
{
    SCLError             err = kSCLError_NoErr;
    MAC_ContextRef      macRef = kInvalidMAC_ContextRef;
    const char          *label = "MessageKey";
    int                 keyBits     = scSCimpCipherBits(ctx->cipherSuite);
    unsigned long       resultLen   = sizeof(ctx->Ksnd);

    uint8_t             oldIndex = ctx->rcvIndex;
                              
    err  = MAC_Init( sSCimptoWrapperMAC(ctx->cipherSuite),
                    sSCimptoWrapperHASH(ctx->cipherSuite, keyBits*2), 
                    ctx->Rcv[oldIndex].key, keyBits/4,
                    &macRef); CKERR;
    
    MAC_Update(macRef,  "\x00\x00\x00\x01",  4);
    MAC_Update(macRef,  label,  strlen(label));
    MAC_Update(macRef,  "\x00",  1);
    MAC_Update(macRef,  ctx->SessionID, SCIMP_HASH_LEN);
    MAC_Update(macRef,  &ctx->Rcv[oldIndex].index, sizeof(uint64_t));
    MAC_Update(macRef, (uint8_t*) "\x00\x00\x01\x00",  4);
    
    MAC_Final( macRef,&ctx->Rcv[newIndex].key, &resultLen);

    ctx->Rcv[newIndex].index = ctx->Rcv[oldIndex].index+1;

    ctx->rcvIndex = newIndex;
    
done:
    if(IsntNull(macRef))
        MAC_Free(macRef);
    
     return err;
}

/**
 Count deleted keys in RCV Key Queue
 
 @param ctx SCimp Context  
 @return number of deleted keys
 */


static int sCountEmptyRcvKeys(SCimpContextRef ctx)
{
    int i ;
    int count = 0;
    
    for(i = 0; i< SCIMP_RCV_QUEUE_SIZE; i++)
    {
        if(isZeroBuff(ctx->Rcv[i].key, sizeof(ctx->Rcv[i].key) ))
            count++;
    }
    
    return count;
    
}


/**
 Remove outdated or deleted keys from RCV Key Queue
 
 @param ctx SCimp Context  
 @return kSCLError_NoErr if successful
 */

static SCLError sReapOldRcvKeys(SCimpContextRef ctx)
{
    SCLError err = kSCLError_NoErr;
    
    int i = 0;
    uint64_t cur =  ctx->Rcv[ctx->rcvIndex].index ;
    
    
    for(i = 0; i< SCIMP_RCV_QUEUE_SIZE; i++)
    {
        uint64_t age = mod_diff(cur,  ctx->Rcv[i].index, UINT64_MAX);
        
        
        if(isZeroBuff(ctx->Rcv[i].key, sizeof(ctx->Rcv[i].key) ))
        {
            err = sAdvanceRcvKey(ctx, i); CKERR;
            continue;
        }
        
        if(  age > SCIMP_RCV_QUEUE_SIZE  )
        {
            err = sAdvanceRcvKey(ctx, i); CKERR;
            continue;
        }
    }
done:
    return err;
}


/**
 Find Key and Message Index for Sequence number
 
 @param ctx SCimp Context  
 @param msgSeqNum  16 bit sequence number from message
 @param  keyOut pointer to where to return key pointer
 @param  msgIndexOut pointer to where to return 8 byte network ordered message index suitable for Hashing
 @return kSCLError_NoErr if successful
 */

static SCLError sGetKeyforMessage(SCimpContextRef ctx, uint16_t msgSeqNum, uint8_t *keyOut, uint8_t  *msgIndexOut)
{
    SCLError err = kSCLError_KeyNotFound;
    
    int     i = 0;
    
    for(i = 0; i< SCIMP_RCV_QUEUE_SIZE; i++)
    {
        if(!isZeroBuff(ctx->Rcv[i].key, sizeof(ctx->Rcv[i].key))
                       &&  msgSeqNum == (ctx->Rcv[i].index  & 0xFFFF)) 
        {
            COPY(ctx->Rcv[i].key, keyOut, scSCimpCipherBits(ctx->cipherSuite)/4);
            ntoh64(ctx->Rcv[i].index,msgIndexOut);
            
            // is this key the last one in sequence
            
            if(i == ctx->rcvIndex)
            {
                // write over this key with the next one in sequence
                err = sAdvanceRcvKey(ctx, i); CKERR;
            }
            else
            {
                // olser key, just zero for now
                ZERO(ctx->Rcv[i].key, sizeof(ctx->Rcv[i].key));
            }
            
            // Check if we nneed to garbage collect
            if(sCountEmptyRcvKeys(ctx) > SCIMP_RCV_QUEUE_GARBAGE_TOLERANCE)
            {
                err = sReapOldRcvKeys(ctx); CKERR;
            }
            
            err = kSCLError_NoErr;
            
            break;
        }
    }
done:
    
    return err;
}
 

static SCLError  sComputeKeys(SCimpContext* ctx)
{
    SCLError             err = kSCLError_NoErr;
    MAC_ContextRef      macRef = kInvalidMAC_ContextRef;
    
 	uint8_t            Kdk     [SCIMP_HASH_PATH_BITS /8];
    uint8_t            Kdk2    [SCIMP_HASH_PATH_BITS / 8];
    uint8_t            hTotal  [SCIMP_HTOTAL_BITS / 8];
    uint8_t            Z       [256];
    
    
    union  {
        uint8_t     b [4];
        uint32_t    w;
    }Ksas;
    
    uint8_t            *ctxStr = NULL;
    unsigned long       ctxStrLen = 0;
    unsigned long       kdkLen;
    int                 keyLen = scSCimpCipherBits(ctx->cipherSuite);
    
    unsigned long   x;
    
    static const char *kSCimpstr_MasterSecret = "MasterSecret";
    static const char *kSCimpstr_Enhance = "SCimp-ENHANCE";
    
    
    /*  Htotal = H(commit || DH1 || Pki )  - SCIMP_HTOTAL_BITS bit hash */
    HASH_Final( ctx->HtotalState, hTotal);
    
    /* Kdk = MAC(Htotal,Z)    where Z is the DH of Pki and PKr */
    x = sizeof(Z); 
    
    err = ECC_SharedSecret(ctx->privKey, ctx->pubKey, Z, sizeof(Z), &x);
    /* at this point we dont need the ECC keys anymore. Clear them */
    
    if(ctx->privKey)
    {
        ECC_Free(ctx->privKey);
        ctx->privKey = kInvalidECC_ContextRef;
    }
    
    if(ctx->pubKey)
    {
        ECC_Free(ctx->pubKey);
        ctx->pubKey = kInvalidECC_ContextRef;
    }
    CKERR;
    
    kdkLen = sizeof(Kdk);
    
    err = MAC_Init( sSCimptoWrapperMAC(ctx->cipherSuite),
                   sSCimptoWrapperHASH(ctx->cipherSuite, SCIMP_HASH_PATH_BITS),
                   hTotal, SCIMP_HTOTAL_BITS / 8 , &macRef); CKERR;
    
    err = MAC_Update(macRef,  Z, x); CKERR;
    
    err = MAC_Final( macRef, Kdk, &kdkLen); CKERR;
    
    MAC_Free(macRef);
    macRef = kInvalidMAC_ContextRef;
 
#if DEBUG_CRYPTO
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nComputing %s Keys: (%d bits)\n", ctx->isInitiator?"Initiator":"Responder", keyLen );
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nhTotal:\n");
    dumpHex(hTotal, sizeof(hTotal), 0);
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\n\n");
    
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nECC Shared Secret - Z: (%d)\n",x);
    dumpHex(Z,  (int)x , 0);
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\n\n");
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nKdk: (%d)\n", kdkLen);
    dumpHex(Kdk,  (int)kdkLen , 0);
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\n\n");
#endif

    
    ctxStr = sMakeContextString( ctx->isInitiator?ctx->meStr:ctx->youStr, 
                                !ctx->isInitiator?ctx->meStr:ctx->youStr, 
                                hTotal, 
                                &ctxStrLen);
    /* 
     Kdk2 =MAC(Kdk,0x00000001||“MasterSecret”||0x00
     ||"SCimp-ENHANCE"|| len(initID)InitID||len(respID)respID|| Htotal || len(cs)|| cs 
     ||0x00000100) 
     */
    
    err = MAC_Init(sSCimptoWrapperMAC(ctx->cipherSuite),
                   sSCimptoWrapperHASH(ctx->cipherSuite, SCIMP_HASH_PATH_BITS),
                   Kdk, kdkLen, &macRef); CKERR;
    
    err = MAC_Update(macRef,  Z, x); CKERR;
    
    
    err = MAC_Update(macRef,  (uint8_t*)"\x00\x00\x00\x01",  4); CKERR;
    err = MAC_Update(macRef,  (uint8_t*)kSCimpstr_MasterSecret,  strlen(kSCimpstr_MasterSecret)); CKERR;
    err = MAC_Update(macRef,  (uint8_t*)"\x00",  1); CKERR;
    err = MAC_Update(macRef,  (uint8_t*)kSCimpstr_Enhance,  strlen(kSCimpstr_Enhance));CKERR;
    
    err = MAC_Update(macRef,  (uint8_t*)ctxStr, ctxStrLen);CKERR;
    
    if(ctx->hasCs && ctx->csMatches)
    {
        uint8_t csbyte = keyLen/4;
         
        err = MAC_Update(macRef, (uint8_t*)&csbyte,  1);CKERR;
        err = MAC_Update(macRef, ctx->Cs,  csbyte ) ;CKERR;
    }
    else 
    {
        err = MAC_Update(macRef, (uint8_t*)"\x00",  1); CKERR;
    }
    
    err = MAC_Update(macRef, (uint8_t*) "\x00\x00\x01\x00",  4);CKERR;
    
    err = MAC_Final( macRef, Kdk2, &kdkLen); CKERR;
    
    MAC_Free(macRef);
    macRef = kInvalidMAC_ContextRef;
    
    ctx->rcvIndex = 0;
    ZERO(ctx->Rcv, sizeof(ctx->Rcv));
    
    err = sComputeKDF(ctx, Kdk2, kdkLen,  "InitiatorMasterKey", ctxStr, ctxStrLen,
                      (uint32_t) keyLen * 2,  keyLen/4,
                      ctx->isInitiator?ctx->Ksnd:ctx->Rcv[0].key); CKERR;
    

    err =  sComputeKDF(ctx, Kdk2, kdkLen, "InitiatorMACkey",    ctxStr, ctxStrLen,
                       256, SCIMP_MAC_LEN, ctx->MACi); CKERR;


    err =  sComputeKDF(ctx, Kdk2, kdkLen, "ResponderMACkey",    ctxStr, ctxStrLen,
                       256, SCIMP_MAC_LEN, ctx->MACr); CKERR;
 
    
    err =  sComputeKDF(ctx, Kdk2, kdkLen, "SAS",                ctxStr, ctxStrLen,
                       20, 4, &Ksas.b[0] );  CKERR;
    ctx->SAS =   ( (ntohl(Ksas.w) >> 12) & (~0U >> 12));   // just 32-12 = 20 bits
    
    
    /* rekey new cached secret */
    ZERO(ctx->Cs1,  SCIMP_KEY_LEN);
    err =  sComputeKDF(ctx, Kdk2, kdkLen, "RetainedSecret",     ctxStr, ctxStrLen,
                       (uint32_t) keyLen * 2, keyLen/4, ctx->Cs1);  CKERR;
    

    sComputeSessionID(ctx);
    
    err =  sComputeKDF(ctx, Kdk2, kdkLen, "InitiatorInitialIndex",   ctx->SessionID , sizeof(ctx->SessionID),
                       64,  sizeof(uint64_t),
                       (void*) (ctx->isInitiator? &ctx->Isnd: &ctx->Rcv[0].index));  CKERR;
    
    err = sComputeKDF(ctx, Kdk2, kdkLen, "ResponderMasterKey", ctxStr, ctxStrLen,
                      (uint32_t) keyLen * 2,  keyLen/4,
                      ctx->isInitiator?ctx->Rcv[0].key:ctx->Ksnd); CKERR;
    
 
    err =  sComputeKDF(ctx, Kdk2, kdkLen, "ResponderInitialIndex",   ctx->SessionID , sizeof(ctx->SessionID),
                       64,  sizeof(uint64_t),
                       (void*) (!ctx->isInitiator? &ctx->Isnd: &ctx->Rcv[0].index)); CKERR;
    
#if DEBUG_CRYPTO
    
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nKdk2: (%d)\n",kdkLen);
    dumpHex(Kdk2,  (int)kdkLen , 0);
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\n\n");

    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nInitiatorMasterKey: (%d)\n",keyLen/4);
    dumpHex(ctx->isInitiator?ctx->Ksnd:ctx->Rcv[0].key,  (int)keyLen/4 , 0);
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\n\n");

    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nInitiatorInitialIndex: (%d)\n", (int)sizeof(uint64_t));
    dumpHex( (uint8_t*) (ctx->isInitiator? &ctx->Isnd: &ctx->Rcv[0].index),  sizeof(uint64_t) , 0);
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\n\n");

    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nResponderMasterKey: (%d)\n",keyLen/4);
    dumpHex(!ctx->isInitiator?ctx->Ksnd:ctx->Rcv[0].key,  (int)keyLen/4 , 0);
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\n\n");
    
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nResponderInitialIndex: (%d)\n", (int)sizeof(uint64_t));
    dumpHex( (uint8_t*) (!ctx->isInitiator? &ctx->Isnd: &ctx->Rcv[0].index),  sizeof(uint64_t) , 0);
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\n\n");

    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nMACi: (%d)\n", SCIMP_MAC_LEN);
    dumpHex(ctx->MACi, SCIMP_MAC_LEN , 0);
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\n\n");
    
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nMACr: (%d)\n", SCIMP_MAC_LEN);
    dumpHex(ctx->MACr, SCIMP_MAC_LEN , 0);
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\n\n");
    
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nSAS: %04X\n\n", ctx->SAS);
    
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nCS1: (%d)\n", keyLen/4);
    dumpHex(ctx->Cs1, keyLen/4 , 0);
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\n\n");
    
#endif
    
   // calculate SCIMP_RCV_QUEUE_SIZE keys in advanced
    {
        int i = 0;
        
        for(i = 1; i< SCIMP_RCV_QUEUE_SIZE; i++)
        {
            sAdvanceRcvKey(ctx, i);
            ctx->rcvIndex  = i;
        };
        
    };
    
    ctx->hasKeys = true;
    
done:
    
    if(ctx->HtotalState)
    {
        HASH_Free(ctx->HtotalState);
        ctx->HtotalState = kInvalidHASH_ContextRef;
    }
    
    
    if(IsntNull(macRef))
        MAC_Free(macRef);
    
    ZERO(Kdk, sizeof(Kdk));
    ZERO(Kdk2, sizeof(Kdk2));
    ZERO(hTotal, sizeof(hTotal));
    ZERO(Z, sizeof(Z)); 
    
    XFREE(ctxStr);
    
    return err;
    
}

#pragma mark
#pragma mark Callback handlers

SCLError scEventSendPacket(
                           SCimpContextRef   ctx,
                           uint8_t*          data, 
                           size_t            dataLen,
                           void*             userRef
                           )
{
    SCLError             err         = kSCLError_NoErr;
 	SCimpEvent      event;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    
    
  	event.type                      = kSCimpEvent_SendPacket;
  	event.userRef                   = userRef;
 	event.data.sendData.data        = data;
    event.data.sendData.length      = dataLen;
    
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}


SCLError scEventDecrypt(
                       SCimpContextRef    ctx,
                        uint8_t*          data, 
                        size_t            dataLen,
                        void*             userRef
                        )
{
    SCLError             err         = kSCLError_NoErr;
 	SCimpEvent      event;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    
    
  	event.type                         = kSCimpEvent_Decrypted;
    event.userRef                      = userRef;
 	event.data.decryptData.data        = data;
    event.data.decryptData.length      = dataLen;
    
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}

SCLError scEventClearText(
                          SCimpContextRef     ctx,
                          uint8_t*            data, 
                          size_t              dataLen,
                          void*               userRef
                          )
{
    SCLError             err         = kSCLError_NoErr;
 	SCimpEvent      event;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    
    
  	event.type                       = kSCimpEvent_ClearText;
    event.userRef                    = userRef;
 	event.data.clearText.data        = data;
    event.data.clearText.length      = dataLen;
    
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}





SCLError scEventNull(
                        SCimpContextRef   ctx )
{
    SCLError             err         = kSCLError_NoErr;
 	SCimpEvent          event;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    event.type							= kSCimpEvent_NULL;
    
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}

SCLError scEventError(
                     SCimpContextRef   ctx,
                     SCLError          error,
                      void*            userRef
                      )
{
    SCLError             err         = kSCLError_NoErr;
 	SCimpEvent          event;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    event.type							= kSCimpEvent_Error;
    event.userRef                       = userRef;
  	event.data.errorData.error          = error;
    
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}


SCLError scEventWarning(
                       SCimpContextRef   ctx,
                       SCLError          warning,
                        void*             userRef
                       )
{
    SCLError             err         = kSCLError_NoErr;
 	SCimpEvent          event;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    event.type							= kSCimpEvent_Warning;
    event.userRef                       = userRef;
	event.data.warningData.warning        = warning;
    
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}

SCLError scEventKeyed( SCimpContextRef   ctx)
{
    SCLError                 err         = kSCLError_NoErr;
 	SCimpEvent          event;
    SCimpInfo           info;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    ZERO(&info, sizeof( info ));
    
    SCimpGetInfo(ctx, &info);
    
  	event.type                      = kSCimpEvent_Keyed;
 	event.data.keyedData.info        = info;
    
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}

SCLError scEventReKeying( SCimpContextRef   ctx)
{
    SCLError                 err         = kSCLError_NoErr;
 	SCimpEvent          event;
    SCimpInfo           info;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    ZERO(&info, sizeof( info ));
    
    SCimpGetInfo(ctx, &info);
    
  	event.type                      = kSCimpEvent_ReKeying;
 	event.data.keyedData.info        = info;
    
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}

SCLError scEventShutdown(
                       SCimpContextRef   ctx )
{
    SCLError             err         = kSCLError_NoErr;
 	SCimpEvent          event;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    event.type			= kSCimpEvent_Shutdown;
     
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}


SCLError scEventTransition(
                         SCimpContextRef   ctx, SCimpState state )
{
    SCLError             err         = kSCLError_NoErr;
 	SCimpEvent          event;
    
	if( IsNull( ctx->handler ) || !ctx->wantsTransEvents)
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    event.type			= kSCimpEvent_Transition;
    event.data.transData.state = state;
    
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}


 
SCLError scEventAdviseSaveState(
                           SCimpContextRef   ctx)
{
    SCLError             err         = kSCLError_NoErr;
 	SCimpEvent          event;
  
#if  DEBUG_STATES
    DPRINTF(XCODE_COLORS_GREEN_TXT, "scEventAdviseSaveState: %s\n",  stateText(ctx->state) );
#endif

    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    event.type			= kSCimpEvent_AdviseSaveState;
     
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}



#pragma mark
#pragma mark format packets

 
/*____________________________________________________________________________
 Format Messages 
 ____________________________________________________________________________*/

SCLError sMakeSCimpmsg_Commit(SCimpContext *ctx, uint8_t **out, size_t *outlen)
{
    SCLError             err = kSCLError_NoErr;
    SCimpMsg            msg;
        
    uint8_t            PK[128];
    unsigned long      PKlen = 0;
    
    validateSCimpContext(ctx);
    ValidateParam(out);
    ValidateParam(outlen);
    
    ctx->isInitiator = true;
    
    /* delete old ECC pub key */
   if(ctx->pubKey)
    {
        ECC_Free(ctx->pubKey);
        ctx->pubKey = kInvalidECC_ContextRef;
    }

      /* Make a new ECC key */
    err = ECC_Init(&ctx->privKey); CKERR;
    err = ECC_Generate(ctx->privKey, sECCDH_Bits( ctx->cipherSuite) ); CKERR;
    
    /* get copy of public key */
    err = ECC_Export(ctx->privKey, false, PK, sizeof(PK), &PKlen); CKERR;
    
    ZERO(&msg, sizeof(SCimpMsg));
     
    msg.msgType               = kSCimpMsg_Commit;
    msg.commit.version        = ctx->version;
    msg.commit.cipherSuite    = ctx->cipherSuite;
    msg.commit.sasMethod      = ctx->sasMethod;
      
    /* insert Hash of Initiators PK */
    sMakeHash(ctx->cipherSuite, PK, PKlen, SCIMP_HASH_LEN,  msg.commit.Hpki);
    
    /* insert Hash of initiators shared secret */
    err = sComputeSSmac(ctx, PK, PKlen, kSCimpstr_Initiator, msg.commit.Hcs); CKERR;
    
    err = SERIALIZE_SCIMP(ctx, &msg, out, outlen); CKERR;
     
    /* update Htotal */
    err = HASH_Init( sSCimptoWrapperHASH(ctx->cipherSuite, SCIMP_HTOTAL_BITS), &ctx->HtotalState);  CKERR;
    
    HASH_Update( ctx->HtotalState,  &msg.commit,  sizeof(SCimpMsg_Commit));
    
done:
    return err;
}

static SCLError sMakeSCimpmsg_DH1(SCimpContext* ctx, uint8_t **out, size_t *outlen)
{
    SCLError                 err = kSCLError_NoErr;
    SCimpMsg                msg;
            
    unsigned long           PKlen = PK_ALLOC_SIZE;
    uint8_t                *PK = NULL; 
      
    validateSCimpContext(ctx);
    ValidateParam(out);
    ValidateParam(outlen);
    
    ZERO(&msg, sizeof(SCimpMsg));
    PK = XMALLOC(PKlen); CKNULL(PK);
    
    msg.msgType = kSCimpMsg_DH1;
    
     /* insert copy of public key */
    err = ECC_Export(ctx->privKey, false, PK, PKlen, &PKlen); CKERR;
    msg.dh1.pk = PK;
    msg.dh1.pkLen = PKlen;
    
    /* insert Hash of recipient's shared secret */
    sComputeSSmac(ctx, PK, PKlen, kSCimpstr_Responder, msg.dh1.Hcs);
  
    err = SERIALIZE_SCIMP(ctx, &msg, out, outlen); CKERR;
    
    /* update Htotal */
     HASH_Update( ctx->HtotalState,  PK, PKlen);
     HASH_Update( ctx->HtotalState,  msg.dh1.Hcs,  sizeof(msg.dh1.Hcs));
 
    
done:
    if(IsntNull(PK)) XFREE(PK);
    
    return err;
}

static SCLError sMakeSCimpmsg_DH2(SCimpContext* ctx, uint8_t **out, size_t *outlen)
{
    SCLError                 err = kSCLError_NoErr;
    SCimpMsg                msg;
    
    unsigned long           PKlen = PK_ALLOC_SIZE;
    uint8_t                *PK = NULL; 
    
    validateSCimpContext(ctx);
    ValidateParam(out);
    ValidateParam(outlen);
    
    ZERO(&msg, sizeof(SCimpMsg));
    PK = XMALLOC(PKlen); CKNULL(PK);
    
    msg.msgType = kSCimpMsg_DH2;
    
    /* insert copy of public key */
    err = ECC_Export(ctx->privKey, false, PK, PKlen, &PKlen); CKERR;
    msg.dh2.pk = PK;
    msg.dh2.pkLen = PKlen;
      
    /* update Htotal */
    HASH_Update( ctx->HtotalState,  PK,  PKlen);
    
    err = sComputeKeys(ctx); CKERR;
    
    /* insert MAC of recipient's shared secret */
    COPY(ctx->MACi, msg.dh2.Maci,SCIMP_MAC_LEN);
    
    err = SERIALIZE_SCIMP(ctx, &msg, out, outlen); CKERR;
 
done:
    
    if(IsntNull(PK)) XFREE(PK);

    return err;
}


static SCLError sMakeSCimpmsg_Confirm(SCimpContext* ctx, uint8_t **out, size_t *outlen)
{
    SCLError                 err = kSCLError_NoErr;
    SCimpMsg                msg;
    
    validateSCimpContext(ctx);
    ValidateParam(out);
    ValidateParam(outlen);
    
    ZERO(&msg, sizeof(SCimpMsg));
    
    msg.msgType = kSCimpMsg_Confirm;
    
    /* insert MAC of recipient's shared secret */
    COPY(ctx->MACr, msg.confirm.Macr,SCIMP_MAC_LEN);
    
    err = SERIALIZE_SCIMP(ctx, &msg, out, outlen); CKERR;
   
done:
    return err;
}
 


 
#pragma mark
#pragma mark process packets


static SCLError sProcessSCimpmsg_Commit(SCimpContext* ctx, SCimpMsg* msg, uint8_t ** rsp, size_t *rspLen)
{
    SCLError             err = kSCLError_NoErr;
    SCimpMsg_Commit*    m =  &msg->commit;
    
    if((m->version != kSCimpVersion) 
       || !isValidSASMethod(m->sasMethod) 
       || !isValidCipherSuite(m->cipherSuite))
    {
        scEventError(ctx, kSCLError_FeatureNotAvailable, NULL);
        RETERR(kSCLError_CorruptData);
   }
    
    /* save parameters */
    ctx->cipherSuite    = m->cipherSuite;
    ctx->sasMethod      = m->sasMethod;
    
    /* Save Hash of Shared secret */
    COPY(m->Hcs, &ctx->Hcs, SCIMP_MAC_LEN);
    
    /* Save Hash of initiator's PK  */
    COPY(m->Hpki, &ctx->Hpki, SCIMP_HASH_LEN);
    
    /* are we being re-keyed ? */
    if (ctx->state == kSCimpState_Ready)
    {
        err = scEventReKeying(ctx); CKERR;
        ctx->isInitiator = false;
    }
    
    /* update Htotal */
    err = HASH_Init( sSCimptoWrapperHASH(ctx->cipherSuite, SCIMP_HTOTAL_BITS), &ctx->HtotalState); CKERR;
    HASH_Update( ctx->HtotalState,  m, sizeof(SCimpMsg_Commit));
    
    /* create key to reply with */
    err = ECC_Init(&ctx->privKey); CKERR;
    err = ECC_Generate(ctx->privKey, sECCDH_Bits( ctx->cipherSuite) ); CKERR;
    
    /* create reply DH1 */
    sMakeSCimpmsg_DH1(ctx, rsp, rspLen);
    
    
done:
    
    scimpFreeMessageContent(msg);
    XFREE(msg);
    
    return err;
}

static SCLError sProcessSCimpmsg_DH1(SCimpContext* ctx, SCimpMsg* msg, uint8_t ** rsp, size_t *rspLen)
{
    SCLError             err = kSCLError_NoErr;
    SCimpMsg_DH1*       m =  &msg->dh1;
       
    uint8_t            HCS1[SCIMP_MAC_LEN];
    size_t          keySize;
 
    ValidateParam(m->pk);

    /* update Htotal */
    HASH_Update( ctx->HtotalState,  m->pk, m->pkLen);
    HASH_Update( ctx->HtotalState,  m->Hcs,  sizeof(m->Hcs));

    /* save public key */
    err = ECC_Init(&ctx->pubKey); CKERR;
    err = ECC_Import(ctx->pubKey,m->pk, m->pkLen); CKERR;
    
    /* check public key for validity */
    err = ECC_KeySize(ctx->pubKey, &keySize); CKERR;
    
    if( sECCDH_Bits( ctx->cipherSuite)  != keySize)
        err = kSCLError_CorruptData; CKERR;
    
    /* check secret commitment */
    
    /* insert Hash of initiators shared secret */
    err = sComputeSSmac(ctx, m->pk, m->pkLen, kSCimpstr_Responder, HCS1); CKERR;
    
    ctx->csMatches = CMP(m->Hcs, HCS1, SCIMP_MAC_LEN);
    if(!ctx->csMatches)
    {
        scEventWarning(ctx, kSCLError_SecretsMismatch,NULL);
    }
    
    /* create reply DH2 */
    sMakeSCimpmsg_DH2(ctx, rsp, rspLen);
    
done:
    scimpFreeMessageContent(msg);
    XFREE(msg);
   return err;
}

static SCLError sProcessSCimpmsg_DH2(SCimpContextRef ctx, SCimpMsg* msg, uint8_t ** rsp, size_t *rspLen)
{
    SCLError             err = kSCLError_NoErr;
    SCimpMsg_DH2*       m =  &msg->dh2;
    uint8_t             HPKi[SCIMP_HASH_LEN];
    uint8_t             HCS1[SCIMP_MAC_LEN];
    size_t              keySize;  
    
    ValidateParam(m->pk);
       
    /* save public key */
    err = ECC_Init(&ctx->pubKey); CKERR;
    err = ECC_Import(ctx->pubKey, m->pk, m->pkLen); CKERR;
      
    /* check public key for validity */
    err = ECC_KeySize(ctx->pubKey, &keySize); CKERR;
    if( sECCDH_Bits( ctx->cipherSuite)  != keySize)
        err = kSCLError_CorruptData; CKERR;
    
    /* create Hash of Initiators PK */
    sMakeHash(ctx->cipherSuite,  m->pk, m->pkLen, SCIMP_HASH_LEN, HPKi);
    
    /* check PKI hash */
    if(!CMP(ctx->Hpki, HPKi, SCIMP_HASH_LEN))
        RETERR(kSCLError_CorruptData);
    
    /* check Hash of initiators shared secret */
    err = sComputeSSmac(ctx,  m->pk, m->pkLen, kSCimpstr_Initiator, HCS1);CKERR;
    
    ctx->csMatches = CMP(ctx->Hcs, HCS1, SCIMP_MAC_LEN);
    if( ctx->hasCs && !ctx->csMatches)
    {
        scEventWarning(ctx, kSCLError_SecretsMismatch, NULL);
    }

    /* update Htotal */
    HASH_Update( ctx->HtotalState,  m->pk, m->pkLen);
   
    err = sComputeKeys(ctx); CKERR;
    
    /* check if Initiator's confirmation code matches */ 
    if(!CMP(ctx->MACi, m->Maci, SCIMP_MAC_LEN))
    {
        scEventError(ctx, kSCLError_BadIntegrity, NULL);
        RETERR(kSCLError_BadIntegrity);
    }
    /* create reply Confirm */
    sMakeSCimpmsg_Confirm(ctx, rsp, rspLen);

  done:
    scimpFreeMessageContent(msg);
    XFREE(msg);
   return err;
}

static SCLError sProcessSCimpmsg_Confirm(SCimpContextRef ctx, SCimpMsg* msg, uint8_t ** rsp, size_t *rspLen)
{
    (void) rsp;
    (void) rspLen;
    SCLError             err = kSCLError_NoErr;
    SCimpMsg_Confirm*   m =  &msg->confirm;    
    
    
    /* check if Responder's confirmation code matches */ 
    if(!CMP(ctx->MACr, m->Macr, 8))
    {
        scEventError(ctx, kSCLError_BadIntegrity, NULL);
        RETERR(kSCLError_BadIntegrity);
    }
    
    // set the state ready before notifying the user of keyed
    ctx->state = kSCimpState_Ready;
    scEventTransition(ctx, kSCimpState_Ready);
    scEventKeyed(ctx);
 
done:
    scimpFreeMessageContent(msg);
    XFREE(msg);
    return err;
}




static SCLError sProcessSCimpmsg_Data(SCimpContextRef ctx, SCimpMsg* msg, uint8_t ** rsp, size_t *rspLen)
{
    (void) rsp;
    (void) rspLen;
    
    SCLError            err = kSCLError_NoErr;
    
    SCimpMsg_Data*     m =  &msg->data;
    uint8_t          *PT = NULL;
    size_t            PTLen = 0;
    uint8_t           key[SCIMP_KEY_LEN];
    uint8_t           msgIndex[8];
    
    ValidateParam(m->msg);

    err = sGetKeyforMessage(ctx, m->seqNum, key, msgIndex); CKERR;
        
    err = CCM_Decrypt( key,      scSCimpCipherBits(ctx->cipherSuite)/4, 
                       msgIndex,       sizeof(msgIndex), 
                       m->msg,         m->msgLen, 
                       m->tag,         sizeof(m->tag), 
                       &PT,            &PTLen); CKERR;
  
  
     err = scEventDecrypt(ctx, PT, PTLen, msg->userRef) ; CKERR;
    
    scEventAdviseSaveState(ctx);

done:
    
    if(IsSCLError(err))
    {
        scEventError(ctx, err,msg->userRef);
    }
    
    ZERO(key, sizeof(key));
 
    if(PT)
    {
        ZERO(PT,PTLen);
        XFREE(PT);
    }
    
     
    scimpFreeMessageContent(msg);
    XFREE(msg);
    return err;
}
 



static SCLError sProcessSCimpmsg_ClearText(SCimpContextRef ctx, SCimpMsg* msg, uint8_t ** rsp, size_t *rspLen)
{
    (void) rsp;
    (void) rspLen;
    
    SCLError            err = kSCLError_NoErr;
    
    SCimpMsg_ClearTxt*     m =  &msg->clearTxt;
     
    err = scEventClearText(ctx, m->msg, m->msgLen, msg->userRef) ; CKERR;
    
done:
    
    if(IsSCLError(err))
    {
        scEventError(ctx, err, msg->userRef);
    }
    
    scimpFreeMessageContent(msg);
    XFREE(msg);
    return err;
}




#pragma mark
#pragma mark State Handlers




static SCLError sDoNull(SCimpContext* ctx, SCimpMsg* msg )
{
    (void) msg;
    SCLError     err = kSCLError_NoErr;
    
    scEventNull(ctx);
      
done:   
    
    return err;   
}

static SCLError sDoShutdown(SCimpContext* ctx, SCimpMsg* msg )
{
    (void) msg;
    SCLError     err = kSCLError_NoErr;
      
    scEventShutdown(ctx);
    scResetSCimpContext(ctx,true);
       
done:   
     
    return err;   
}

static SCLError sDoStartDH(SCimpContext* ctx, SCimpMsg* msg )
{
    (void) msg;
    SCLError     err = kSCLError_NoErr;
    uint8_t     *buffer = NULL;
    size_t      bufLen = 0;
    
    sMakeSCimpmsg_Commit(ctx, &buffer, &bufLen);CKERR;
    
    err = scEventSendPacket(ctx, buffer, bufLen, NULL);
    
done:   
    if(buffer) XFREE(buffer),buffer = NULL;
    
    return err;   
}


static SCLError sDoRcv_Commit(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
    uint8_t     *buffer = NULL;
    size_t      bufLen = 0;
    
    err = sProcessSCimpmsg_Commit(ctx, msg, &buffer, &bufLen); CKERR;
    
    err = scEventSendPacket(ctx, buffer, bufLen, NULL);
    
done:   
    if(buffer)  XFREE(buffer);
  
    return err;   
}

static SCLError sImproperRekey(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
     
    err =  scEventWarning(ctx, kSCLError_ProtocolError, NULL); CKERR;
     
 //   err = sDoStartDH(ctx, msg);
 
done:
    
    return err;   
}


static SCLError sNotKeyed(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError     err = kSCLError_KeyNotFound;
    
    err =  scEventError(ctx, kSCLError_KeyNotFound, msg->userRef); CKERR;
      
done:
    
    return err;   
}

 
 
static SCLError sDoCommitContention(SCimpContext* ctx, SCimpMsg* msg)
{
    {
        SCLError     err = kSCLError_NoErr;
        
        
        err =  scEventWarning(ctx, kSCLError_ProtocolContention, NULL); CKERR;
        
        scResetSCimpContext(ctx,false);
        
        err = sDoRcv_Commit(ctx, msg);
        
    done:
        
        return err;   
  }
 
}


static SCLError sDoRcv_DH1(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
    uint8_t     *buffer = NULL;
    size_t      bufLen = 0;
    
    err = sProcessSCimpmsg_DH1(ctx, msg, &buffer, &bufLen); CKERR;
    
    err = scEventSendPacket(ctx, buffer, bufLen, NULL);
    
done:   
    if(buffer) XFREE(buffer),buffer = NULL;
     
    return err;   
}

static SCLError sDoRcv_DH2(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
    uint8_t     *buffer = NULL;
    size_t      bufLen = 0;
    
    err = sProcessSCimpmsg_DH2(ctx, msg, &buffer, &bufLen); CKERR;
    
    err = scEventSendPacket(ctx, buffer, bufLen, NULL); CKERR;
  
    // after recieving a DH2 the responder should be in a confrm state,
    // we will bump it to a ready state now that the confirm has been sent.
    
    err = scTriggerSCimpTransition(ctx, kSCimpTrans_SND_Confirm, NULL); CKERR;
 
done:   
    if(buffer) XFREE(buffer),buffer = NULL;
    
    return err;   
}

static SCLError sDoRcv_Confirm(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
  
    err = sProcessSCimpmsg_Confirm(ctx, msg, NULL, NULL); CKERR;
    
    scEventAdviseSaveState(ctx);

done:
    return err;   
}
 

// this is a psuedo state used to inform the user of ckeying once we hit the ready state.
static SCLError sDoSent_Confirm(SCimpContext* ctx,   SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
     
    // set the state ready before notifying the user of keyed
    ctx->state = kSCimpState_Ready;
    scEventTransition(ctx, kSCimpState_Ready);
    scEventAdviseSaveState(ctx);

    scEventKeyed(ctx);
      
done:   
    return err;   
}


static SCLError sDoRcv_Data(SCimpContext* ctx,   SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
      
    err = sProcessSCimpmsg_Data(ctx, msg, NULL, NULL); CKERR;
   
done:   
     return err;   
}

static SCLError sDoRcv_ClearText(SCimpContext* ctx,   SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
    
     err = sProcessSCimpmsg_ClearText(ctx, msg, NULL, NULL); CKERR;
    
done:   
    return err;   
}







#pragma mark
#pragma mark State machine
static const state_table_type SCIMP_state_table[]=
{
    { ANY_STATE,            kSCimpTrans_NULL,           NO_NEW_STATE,           sDoNull             },
    { ANY_STATE,            kSCimpTrans_Shutdown,       kSCimpState_Init,       sDoShutdown         },
    
    // run states
    { kSCimpState_Ready,    kSCimpTrans_RCV_Data,       NO_NEW_STATE,           sDoRcv_Data         },
    { ANY_STATE,            kSCimpTrans_RCV_ClearText,  NO_NEW_STATE,           sDoRcv_ClearText    },  
     
    // keying states
    { kSCimpState_Init,     kSCimpTrans_StartDH,        kSCimpState_Commit,     sDoStartDH          },  
    { kSCimpState_Init,     kSCimpTrans_RCV_Commit,     kSCimpState_DH1,        sDoRcv_Commit       },  
    { kSCimpState_Commit,   kSCimpTrans_RCV_DH1,        kSCimpState_DH2,        sDoRcv_DH1          },
    { kSCimpState_DH1,      kSCimpTrans_RCV_DH2,        kSCimpState_Confirm,    sDoRcv_DH2          },
    { kSCimpState_DH2,      kSCimpTrans_RCV_Confirm,    kSCimpState_Ready,      sDoRcv_Confirm      },
    { kSCimpState_Confirm,  kSCimpTrans_SND_Confirm,    kSCimpState_Ready,      sDoSent_Confirm     },
    
    // edge cases
    /* client does rekey after established */
    { ANY_STATE,            kSCimpTrans_StartDH,        kSCimpState_Commit,     sDoStartDH          },  
    
    /* responder gets rekeyed after established */
    { kSCimpState_Ready,    kSCimpTrans_RCV_Commit,     kSCimpState_DH1,        sDoRcv_Commit       },  
 
    // out of sequence messages
    { ANY_STATE,            kSCimpTrans_RCV_Commit,     kSCimpState_DH1,         sDoCommitContention },
    { ANY_STATE,            kSCimpTrans_RCV_Data,       NO_NEW_STATE,            sNotKeyed            },
    
    { ANY_STATE,            kSCimpTrans_RCV_DH1,        kSCimpState_Error,      sImproperRekey      },
   { ANY_STATE,             kSCimpTrans_RCV_DH2,        kSCimpState_Error,      sImproperRekey,     },
    { ANY_STATE,            kSCimpTrans_RCV_Confirm,    kSCimpState_Error,      sImproperRekey,     },

    
};

#define SCIMP_STATE_TABLE_SIZE (sizeof(SCIMP_state_table) / sizeof(state_table_type))
  
static SCLError sQueueTransition(TransQueue * q, 
                            SCimpTransition trans, 
                            SCimpMsg*       msg)
{
    SCLError     err         = kSCLError_NoErr;

    if (q->count >= TRANS_QUEUESIZE)
    {
        err= kSCLError_NOP ;
    }
    
    else 
    {
        TransItem *item = NULL;
        
        q->last = (q->last+1) % TRANS_QUEUESIZE;
        
        item = &q->q[ q->last ];
        
        item->trans = trans; 
        item->msg = msg;
        q->count = q->count + 1;
    }
    
    return err;
}

static SCLError sDeQueueTransition(TransQueue * q, TransItem *item)
{
    SCLError     err         = kSCLError_NoErr;

    if (q->count <= 0)
    {
        err= kSCLError_NOP ;

    }
    else 
    {
        *item = q->q[ q->first ];
        q->first = (q->first+1) % TRANS_QUEUESIZE;
        q->count = q->count - 1;
    }
    
    return(err);
}

#if  DEBUG_STATES

 
static  char*  transitionText( SCimpTransition trans )
{
    static struct
    {
        SCimpTransition      trans;
        char*           txt;
    }trans_txt[] =
    {
        {kSCimpTrans_NULL,          "NULL"},
        {kSCimpTrans_StartDH,       "StartDH"},
        {kSCimpTrans_RCV_Commit,    "RCV_Commit"},
        {kSCimpTrans_RCV_DH1,       "RCV_DH1"},
        {kSCimpTrans_RCV_DH2,       "RCV_DH2"},
        {kSCimpTrans_RCV_Confirm,	"RCV_Confirm"},
        {kSCimpTrans_SND_Confirm,	"SND_Confirm"},
        {kSCimpTrans_SND_Data,      "SND_Data"},
        {kSCimpTrans_RCV_Data,      "RCV_Data"},
        {kSCimpTrans_RCV_ClearText,	"RCV_ClearText"},
         {kSCimpTrans_Complete,     "Complete"},
        {kSCimpTrans_Shutdown,      "Shutdown"},
        {0,NULL}
    };
    
    int i;
    
    for(i = 0; trans_txt[i].txt; i++)
        if(trans_txt[i].trans == trans) return(trans_txt[i].txt);
    
    return "Invalid";
    
}


#endif


SCLError sProcessTransition(SCimpContextRef ctx, 
                       SCimpTransition trans, SCimpMsg* msg)
{
    SCLError     err         = kSCLError_NoErr;
    const state_table_type * table = SCIMP_state_table;
    int i;
    
    
#if  DEBUG_STATES
    DPRINTF(XCODE_COLORS_GREEN_TXT, "sProcessTransition: %s - %s -> ", transitionText(trans), stateText(ctx->state) );
#endif
    for(i=0; i < SCIMP_STATE_TABLE_SIZE; i++, table++)
    {
        if((trans == table->trans) 
           && ((ctx->state == table->current) || (table->current == ANY_STATE )))
        {
#if  DEBUG_STATES
            DPRINTF(XCODE_COLORS_GREEN_TXT, " %s\n\n" ,  stateText(table->next) );
            fflush(stdout);
#endif
            if(table->func)
                err = (*table->func)(ctx, msg);
            
            if(table->next != NO_NEW_STATE)
            {
                SCimpState last_state = ctx->state;
                
                ctx->state = table->next;
                
                if(last_state != ctx->state)
                {
                    scEventAdviseSaveState(ctx);
                    
                    scEventTransition(ctx, ctx->state);
                 }
             }
            return(err);
        }
        
    }
  
#if  DEBUG_STATES
   DPRINTF(XCODE_COLORS_GREEN_TXT, " NOT HANDLED\n\n" );
    fflush(stdout);
#endif
    
    return kSCLError_NOP;

}


#pragma mark
#pragma mark Private Entry points 

SCLError scTriggerSCimpTransition(SCimpContextRef ctx, 
                                 SCimpTransition trans, SCimpMsg* msg)
{
    SCLError     err         = kSCLError_NoErr;
    
    
    if(pthread_mutex_trylock(&ctx->mp) == EBUSY)
    {
        err = sQueueTransition(&ctx->transQueue, trans, msg);
        return err;
    }
    
    err = sProcessTransition(ctx, trans, msg);
    
    while(ctx->transQueue.count > 0)
    {
        TransItem  item;
        
        err = sDeQueueTransition(&ctx->transQueue, &item);
        if(err == kSCLError_NoErr)
        {
            sProcessTransition(ctx, item.trans, item.msg);
        }
    }
    
    pthread_mutex_unlock(&ctx->mp);
    
    return err;
}

 

SCLError scSendScimpDataInternal(SCimpContext* ctx, 
                                uint8_t     *in, 
                                 size_t     inLen,
                                 void*      userRef)


{
    SCLError         err         = kSCLError_NoErr;
    SCimpMsg        msg; 

    uint8_t         msgIndex[8];
  
    uint8_t         *buffer = NULL;
    size_t          bufLen = 0;

    ZERO(&msg, sizeof(SCimpMsg));
    
    if(ctx->state != kSCimpState_Ready)
        RETERR(kSCLError_NotConnected);
    
    ntoh64(ctx->Isnd,msgIndex);

    msg.msgType         = kSCimpMsg_Data;
    msg.data.seqNum     = (uint16_t) (ctx->Isnd & 0xFFFF);
      
    err = CCM_Encrypt(ctx->Ksnd,       scSCimpCipherBits(ctx->cipherSuite)/4,
                       msgIndex,       sizeof(msgIndex), 
                       in,              inLen, 
                       &msg.data.msg,   &msg.data.msgLen, 
                       msg.data.tag,    sizeof(msg.data.tag)); CKERR;
 
    err = SERIALIZE_SCIMP(ctx, &msg, &buffer, &bufLen); CKERR;
    
    err = sAdvanceSendKey(ctx); CKERR;
    
    scEventAdviseSaveState(ctx);
    
    err = scEventSendPacket(ctx, buffer, bufLen, userRef);
    
 
done:
    if(buffer) XFREE(buffer),buffer = NULL;
    
      
    return err;   

 }


void scimpFreeMessageContent(SCimpMsg *msg)
{
    switch(msg->msgType)
    {
        case kSCimpMsg_DH1:
            if(msg->dh1.pk) XFREE(msg->dh1.pk);
            break;
            
        case kSCimpMsg_DH2:;
            if(msg->dh2.pk) XFREE(msg->dh2.pk);
            break;
            
        case kSCimpMsg_Data:
            if(msg->data.msg) XFREE(msg->data.msg);
            break;
             
        case kSCimpMsg_ClearText:
            if(msg->clearTxt.msg) XFREE(msg->clearTxt.msg);
            break;
            

        default:
            break;
    };
       
    ZERO(msg, sizeof(SCimpMsg));
}



#pragma mark
#pragma mark Public Entry points 

#if  DEBUG_PROTOCOL || DEBUG_STATES || DEBUG_CRYPTO
 

static void dumpHex8(  uint8_t* buffer)
{
    char hexDigit[] = "0123456789ABCDEF";
	register int			i;
	const unsigned char	  *bufferPtr = buffer;
    
    for (i = 0; i < 8; i++){
        DPRINTF(XCODE_COLORS_BLUE_TXT, "%c",  hexDigit[ bufferPtr[i] >>4]);
        DPRINTF(XCODE_COLORS_BLUE_TXT, "%c",  hexDigit[ bufferPtr[i] &0xF]);
        if((i) &0x01) DPRINTF(XCODE_COLORS_BLUE_TXT, "%c", ' ');
    }
    
}

 
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
        
		DPRINTF(XCODE_COLORS_BLUE_TXT, "%6d: ", lineStart+offset);
		for (i = 0; i < lineLength; i++){
			DPRINTF(XCODE_COLORS_BLUE_TXT, "%c", hexDigit[ bufferPtr[lineStart+i] >>4]);
			DPRINTF(XCODE_COLORS_BLUE_TXT, "%c", hexDigit[ bufferPtr[lineStart+i] &0xF]);
			if((lineStart+i) &0x01) DPRINTF(XCODE_COLORS_BLUE_TXT, "%c", ' ');
		}
		for (; i < kLineSize; i++)
			DPRINTF(XCODE_COLORS_BLUE_TXT,"   ");
		DPRINTF(XCODE_COLORS_BLUE_TXT,"  ");
		for (i = 0; i < lineLength; i++) {
			c = bufferPtr[lineStart + i] & 0xFF;
			if (c > ' ' && c < '~')
				DPRINTF(XCODE_COLORS_BLUE_TXT,"%c", c);
			else {
				DPRINTF(XCODE_COLORS_BLUE_TXT,".");
			}
		}
		DPRINTF(XCODE_COLORS_BLUE_TXT,"\n");
	}
#undef kLineSize
}


static void dumpSCimpMsg(SCimpMsgPtr  msgP)
{
      
    switch(msgP->msgType)
    {
        case kSCimpMsg_Commit:
        {
            SCimpMsg_Commit* c =  &msgP->commit;
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%-12s\n","COMMIT PACKET");
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: 0x%02x\n","Version", c->version);
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: %02x\n","CipherSuite", c->cipherSuite);
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: %02x\n","SAS", c->sasMethod);
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: ","H(Pki)");  dumpHex8(c->Hpki);dumpHex8(c->Hpki+8);
            DPRINTF(XCODE_COLORS_BLUE_TXT, "\n%12s  ","");      dumpHex8(c->Hpki+16);dumpHex8(c->Hpki+24);DPRINTF(XCODE_COLORS_BLUE_TXT, "\n");
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: ","H(cs)");   dumpHex8(c->Hcs); ;DPRINTF(XCODE_COLORS_BLUE_TXT, "\n");
        }
            break;
            
        case kSCimpMsg_DH1:
        {
            SCimpMsg_DH1* c =  &msgP->dh1;
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s\n","DH1 PACKET");
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: %d bytes\n","Pkr", (int)c->pkLen);
            dumpHex(c->pk, (int)c->pkLen, 0);
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: ","H(cs)"); dumpHex8(c->Hcs);DPRINTF(XCODE_COLORS_BLUE_TXT, "\n");
        }
            break;
            
        case kSCimpMsg_DH2:
        {
            SCimpMsg_DH2* c =  &msgP->dh2;
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s\n","DH2 PACKET");
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: %d bytes\n","Pki", (int)c->pkLen);
            dumpHex(c->pk, (int)c->pkLen, 0);
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: ","MAC");   dumpHex8(c->Maci); ;DPRINTF(XCODE_COLORS_BLUE_TXT, "\n");
        }
            break;
            
        case kSCimpMsg_Confirm:
        {
            SCimpMsg_Confirm* c =  &msgP->confirm;
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s\n","CONFIRM PACKET");
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: ","MAC");   dumpHex8(c->Macr);   ;DPRINTF(XCODE_COLORS_BLUE_TXT, "\n");
            
        }
            break;
            
        case kSCimpMsg_Data:
        {
            SCimpMsg_Data* c =  &msgP->data;
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s\n","DATA PACKET");
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: %05d\n","seq", c->seqNum);
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: ","Tag");  dumpHex8(c->tag);;
            DPRINTF(XCODE_COLORS_BLUE_TXT, "\n%12s: %d bytes\n","Data", (int)c->msgLen );
            dumpHex(c->msg, (int)c->msgLen, 0);
        }
            break;
         
        case kSCimpMsg_ClearText:
        {
            SCimpMsg_ClearTxt* c =  &msgP->clearTxt;
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s\n","CLEAR TEXT");
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: %d bytes\n","Len", (int)c->msgLen );
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: |%*s|\n","Data",(int)c->msgLen, c->msg);
        }
            break;

        default:
            break;
    }
    
    DPRINTF(XCODE_COLORS_BLUE_TXT, "\n\n");

}
#endif

SCLError SCimpProcessPacket(
                            SCimpContextRef     ctx,
                            uint8_t*            data, 
                            size_t              dataLen,
                            void*               userRef )
{
    SCLError             err         = kSCLError_NoErr;
    SCimpMsg*           msg = NULL;;
    
    validateSCimpContext(ctx);
    ValidateParam(data);
    
    err = DESERIALIZE_SCIMP(ctx, data, dataLen, &msg); CKERR;
         
    if(IsNull(msg))
        RETERR(kSCLError_CorruptData);
    
    msg->userRef = userRef;
     
#if  DEBUG_PROTOCOL
    dumpSCimpMsg(msg);
#endif
    
    switch(msg->msgType)
    {
        case kSCimpMsg_Commit:
            err = scTriggerSCimpTransition(ctx, kSCimpTrans_RCV_Commit, msg);
            break;
            
        case kSCimpMsg_DH1:
            err = scTriggerSCimpTransition(ctx, kSCimpTrans_RCV_DH1, msg);
            break;
            
        case kSCimpMsg_DH2:
            err = scTriggerSCimpTransition(ctx, kSCimpTrans_RCV_DH2, msg);
            break;
            
        case kSCimpMsg_Confirm:
            err = scTriggerSCimpTransition(ctx, kSCimpTrans_RCV_Confirm, msg);
             break;
         
        case kSCimpMsg_Data:
            err = scTriggerSCimpTransition(ctx, kSCimpTrans_RCV_Data, msg);
            break;
 
        case kSCimpMsg_ClearText:
            err = scTriggerSCimpTransition(ctx, kSCimpTrans_RCV_ClearText, msg);
            break;

        default:
            
            if(msg)
            {
                scimpFreeMessageContent(msg);
                XFREE(msg);
            }
            return(kSCLError_CorruptData);
    }
 
done: 
 
    return err;
}
