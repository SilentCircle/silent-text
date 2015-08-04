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
/**
 @file SCimpProtocol.c 
 SCIMP Protocol specific code 
 */

#include <stdio.h>
#include <errno.h>

#include "SCcrypto.h"

#include "SCimp.h"
#include "SCimpPriv.h"

#ifdef ANDROID
#include "ntohl.c"
#endif

#ifdef __clang__
 #include <TargetConditionals.h>
#endif
/*____________________________________________________________________________
 General data types used by Silent Circle Code
 ____________________________________________________________________________*/


#define HIuint8_t(n) ((n >> 8) & 0xff)
#define LOuint8_t(n) (n & 0xff)

static const uint8_t *kSCimpstr_Initiator = (uint8_t *)"Initiator";
static const uint8_t *kSCimpstr_Responder = (uint8_t *)"Responder";
  
typedef SCLError (*SCstateHandler)(SCimpContextRef ctx,  SCimpMsg* msg);


typedef struct  state_table_type
{
    SCimpState              current;
    SCimpTransition         trans;
    SCimpState              next;
    SCstateHandler          func;
    
}state_table_type;

/*____________________________________________________________________________
 Forward Declaration
 ____________________________________________________________________________*/

static SCLError sSyncEventHandler(SCimpContextRef ctx, SCimpEvent* event);

#ifdef __clang__
#pragma mark
#pragma mark utility 
#endif

bool isValidSASMethod( SCimpSAS method )
{
    return ( method >= kSCimpSAS_ZJC11 && method <= kSCimpSAS_PGP);
}

bool isScimpSymmetric(SCimpContext* ctx)
{
    if(ctx->method == kSCimpMethod_Symmetric)
        return true;
    
    return false;
}

bool isValidScimpMethod( SCimpMethod method )
{
    return ( method >= kSCimpMethod_DH && method <= kSCimpMethod_DHv2);
}

bool isValidCipherSuite(SCimpContext* ctx, SCimpCipherSuite suite )
{
    if(isScimpSymmetric(ctx))
    {
        return ( suite == kSCimpCipherSuite_Symmetric_AES128
                ||  suite <= kSCimpCipherSuite_Symmetric_AES256);
  
    }
    else
    {
        return (    suite == kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384
                ||  suite == kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384
                ||  suite == kSCimpCipherSuite_SKEIN_AES256_ECC384
                ||  suite == kSCimpCipherSuite_SKEIN_2FISH_ECC414);
    
    }
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

#ifdef __clang__
#pragma mark
#pragma mark debuging
#endif

#if  DEBUG_PROTOCOL || DEBUG_STATES || DEBUG_CRYPTO
static void dumpHex(  uint8_t* buffer, int length, int offset);


#if TARGET_OS_IPHONE
#define HAS_XCODE_COLORS 1
#endif


#if HAS_XCODE_COLORS

#define XCODE_COLORS_ESCAPE_MAC "\033["
#define XCODE_COLORS_ESCAPE_IOS "\xC2\xA0["

#if TARGET_OS_IPHONE && !TARGET_IPHONE_SIMULATOR
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

#else  // no HAS_XCODE_COLORS

#define XCODE_COLORS_ESCAPE ""
#define XCODE_COLORS_RESET_FG   "" // Clear any foreground color
#define XCODE_COLORS_RESET_BG  "" // Clear any background color
#define XCODE_COLORS_RESET     ""   // Clear any foreground or background color
#define XCODE_COLORS_BLUE_TXT  ""
#define XCODE_COLORS_RED_TXT  ""
#define XCODE_COLORS_GREEN_TXT  ""

#endif


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

static  char*  methodText( SCimpMethod method )
{
    static struct
    {
        SCimpMethod      method;
        char*           txt;
    }method_txt[] =
    {
        { kSCimpMethod_Invalid,		"Invalid"},
        { kSCimpMethod_DH,          "DH"},
        { kSCimpMethod_DHv2,        "DHv2"},
        { kSCimpMethod_Symmetric,   "Symmetric"},
        { kSCimpMethod_PubKey,		"Public Key"},
        {0,NULL}
    };
    
    int i;
    
    for(i = 0; method_txt[i].txt; i++)
        if(method_txt[i].method == method) return(method_txt[i].txt);
    
    return "Invalid";
    
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
        { kSCimpState_PKInit,   "PKInit"},
        { kSCimpState_PKStart,  "PKstart"},
         {NO_NEW_STATE,         "NO_NEW_STATE"},
        {0,NULL}
    };
    
    int i;
    
    for(i = 0; state_txt[i].txt; i++)
        if(state_txt[i].state == state) return(state_txt[i].txt);
    
    return "Invalid";
    
}

#endif

#ifdef __clang__
#pragma mark
#pragma mark  Setup and Teardown 
#endif

/*____________________________________________________________________________
 Setup and Teardown 
 ____________________________________________________________________________*/

static void sResetFromAbort(SCimpContext* ctx)
{
    ctx->state          = kSCimpState_Init;
    ctx->isInitiator    = false;
    ctx->version        = kSCimpProtocolVersion1;
    ctx->method         = kSCimpMethod_DH;
    
    ctx->hasKeys            = false;
    ctx->csMatches          = false;
    
    if(ctx->privKey0)
    {
        ECC_Free(ctx->privKey0);
        ctx->privKey0 = kInvalidECC_ContextRef;
    }
    
    if(ctx->privKeyDH)
    {
        ECC_Free(ctx->privKeyDH);
        ctx->privKeyDH = kInvalidECC_ContextRef;
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

    // EA: added free pubKeyLocator
    // TODO: confirm this goes here
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
    
    ctx->hasCs              = false;
    ZERO(ctx->Cs,   SCIMP_KEY_LEN);
    
    ZERO(ctx->Kdk2, sizeof(ctx->Kdk2));
    ctx->KdkLen = 0;
    
    if(ctx->ctxStr)
        XFREE(ctx->ctxStr);
    ctx->ctxStr = NULL;
    
    ctx->ctxStrLen = 0;

}


void scResetSCimpContext(SCimpContext *ctx, bool resetAll)
{ 
  
    sResetFromAbort(ctx);
    scEventTransition(ctx, kSCimpState_Init);
  
    if(resetAll)
    {
        ctx->msgFormat          = kSCimpMsgFormat_JSON;
        ctx->cipherSuite        = kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384;
        ctx->sasMethod          = kSCimpSAS_ZJC11;
        ctx->serializeHandler   = scimpSerializeMessageJSON;
        ctx->deserializeHandler = scimpDeserializeMessageJSON;
    }

}


#ifdef __clang__
#pragma mark
#pragma mark  crypto helpers 
#endif
 
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

/* obsolete:
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
*/

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

        case kSCimpCipherSuite_SKEIN_2FISH_ECC414:
            alg =  (hashSize > 256) ?kHASH_Algorithm_SKEIN512 : kHASH_Algorithm_SKEIN256;
            break;

        case kSCimpCipherSuite_Symmetric_AES128:
            alg =  kHASH_Algorithm_SHA256;
            break;
            
         case kSCimpCipherSuite_Symmetric_AES256:
            alg =  kHASH_Algorithm_SHA256;
            break;

            
        default: break;            
    }
    return alg;
}



int scSCimpCipherBits(SCimpCipherSuite  suite)
{
    switch(suite)
    {
        case kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384:       return(128);
        case kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384:    return(256);
        case kSCimpCipherSuite_SKEIN_2FISH_ECC414:             return(256);
            
        case kSCimpCipherSuite_SKEIN_AES256_ECC384:             return(256);
        case kSCimpCipherSuite_Symmetric_AES128:                return 128;
        case kSCimpCipherSuite_Symmetric_AES256:                return 256;
        default: return 0;
            
    }
}

 
Cipher_Algorithm scSCimpCipherAlgorithm(SCimpCipherSuite  suite)
{
    Cipher_Algorithm algorithm = kCipher_Algorithm_Invalid;
    
    switch(suite)
    {
        case kSCimpCipherSuite_SKEIN_2FISH_ECC414:
            algorithm = kCipher_Algorithm_2FISH256;
            break;
            
        case kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384:
        case kSCimpCipherSuite_Symmetric_AES128:
            algorithm = kCipher_Algorithm_AES128;
            break;
            
        case kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384:
        case kSCimpCipherSuite_SKEIN_AES256_ECC384:
        case kSCimpCipherSuite_Symmetric_AES256:
            algorithm = kCipher_Algorithm_AES256;
            break;
            
        default:
            break;
            
    }
    
    return algorithm;
}



 

 
static MAC_Algorithm sSCimptoWrapperMAC(SCimpCipherSuite  suite)
{
    switch(suite)
    {
        case kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384:       return(kMAC_Algorithm_HMAC);
        case kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384:    return(kMAC_Algorithm_HMAC);
        case kSCimpCipherSuite_SKEIN_AES256_ECC384:             return(kMAC_Algorithm_SKEIN);
        case kSCimpCipherSuite_SKEIN_2FISH_ECC414:             return(kMAC_Algorithm_SKEIN);
        case kSCimpCipherSuite_Symmetric_AES128:                return(kMAC_Algorithm_HMAC);
        case kSCimpCipherSuite_Symmetric_AES256:                return(kMAC_Algorithm_HMAC);

        default: return kMAC_Algorithm_Invalid;
            
    }
    
}

static SCKeySuite sECCDH_SCKeySuite (SCimpCipherSuite  suite)
{
    SCKeySuite  keySuite  = kSCKeySuite_ECC384;
    
    switch(suite)
    {
        case kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384:        keySuite = kSCKeySuite_ECC384; break;
        case kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384:     keySuite = kSCKeySuite_ECC384; break;
        case kSCimpCipherSuite_SKEIN_AES256_ECC384:              keySuite = kSCKeySuite_ECC384; break;
        case kSCimpCipherSuite_SKEIN_2FISH_ECC414:              keySuite = kSCKeySuite_ECC414; break;
            
            
        default:
            break;
    }
    
    return keySuite;
}

int sECCDH_Bits(SCimpCipherSuite  suite)
{
    int  ecc_size  = 0;
    
    switch(suite)
    {
        case kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384:        ecc_size = 384; break;
        case kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384:     ecc_size = 384; break;
        case kSCimpCipherSuite_SKEIN_AES256_ECC384:              ecc_size = 384; break;
        case kSCimpCipherSuite_SKEIN_2FISH_ECC414:              ecc_size = 414; break;
            
            
   default:
            break;
    }
    
    return ecc_size;
}

static  SCLError sECCDH_SCKeySuiteFromECC(ECC_ContextRef eccCtx, SCKeySuite* suiteOut)
{
    SCLError        err         = kSCLError_NoErr;
    SCKeySuite      keySuite    = kSCKeySuite_Invalid;
    
    char curveName[64];
    
    err =  ECC_CurveName(eccCtx,curveName, sizeof(curveName),NULL); CKERR;
    
    if(strncmp(curveName, "ECC-384", 7) == 0) keySuite = kSCKeySuite_ECC384;
    else if(strncmp(curveName, "Curve3617", 9) == 0) keySuite = kSCKeySuite_ECC414;
    
    *suiteOut = keySuite;
    
    
done:
    
    return err;
    
}

SCLError sMakeHash(SCimpCipherSuite suite, const unsigned char *in, unsigned long inlen, unsigned long outLen, uint8_t *out)
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
    SCLError           err = kSCLError_NoErr;
    HASH_ContextRef    hashRef     = kInvalidHASH_ContextRef;
    MAC_ContextRef     macRef      = kInvalidMAC_ContextRef;
    uint8_t            hashBuf [32];
    size_t             resultLen;
    
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
    
      err = sMakeHash(ctx->cipherSuite,sIDStr, p-sIDStr, sizeof(ctx->SessionID),  ctx->SessionID); CKERR;
    
     
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
    
    SCLError err = MAC_ComputeKDF( sSCimptoWrapperMAC(ctx->cipherSuite),
                   sSCimptoWrapperHASH(ctx->cipherSuite, hashLen),
                   K,Klen, label,context, contextLen,hashLen,outLen,out);
    return err;
}


static SCLError sAdvanceSendKey(SCimpContext* ctx )
{
    SCLError             err = kSCLError_NoErr;
    MAC_ContextRef      macRef = kInvalidMAC_ContextRef;
    const char          *label = "MessageKey";
    
    int                 keyBits     = scSCimpCipherBits(ctx->cipherSuite);
    size_t		        resultLen   = sizeof(ctx->Ksnd);
 
    if(isScimpSymmetric(ctx))
    {
        ctx->Ioffset +=1;
    }
    else
    {
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
        
    }
    
done:
    if(IsntNull(macRef))
        MAC_Free(macRef);
    
    return err;
}

#pragma mark - dormant seed keys (from previous successful keyings)
static SCLError sComputeNextCommKey(SCimpContext *ctx, CommKeyPair prevKeyPair, CommKeyPair *newKeyPair);

// move this to a better location
void _pushSeedKey(SCimpContext *ctx, void *data) {
	Stack *node = XMALLOC(sizeof(Stack));
	node->data = data;
	node->next = NULL;
	if (ctx->dormantSeedKeys) {
		Stack *root = ctx->dormantSeedKeys;
		node->data = root->data;
		node->next = root->next;
		root->data = data;
		root->next = node;
	} else
		ctx->dormantSeedKeys = node;
}

static void _saveSeedKey(SCimpContext *ctx) {
	// go through our existing keys to find the lowest index
	int i;
	uint64_t minIndex = 0;
    int dormantIdx = 0;

    for(i = 0; i< SCIMP_RCV_QUEUE_SIZE; i++) {
        if(isZeroBuff(ctx->Rcv[i].key, sizeof(ctx->Rcv[i].key)))
			continue;

		// TODO: will this fail if the unsigned long wraps?
		if ( (minIndex == 0) || (minIndex > ctx->Rcv[i].index) ) {
			minIndex = ctx->Rcv[i].index;
			dormantIdx = i;
		}
	}

	if (minIndex == 0)
		return; // nothing to save

	// alloc it
	CommKeyPair *dormantKeyPair = XMALLOC(sizeof(CommKeyPair));
	ZERO(dormantKeyPair, sizeof(CommKeyPair));

	// copy it
	dormantKeyPair->index = minIndex;
	COPY(ctx->Rcv[dormantIdx].key, dormantKeyPair->key, sizeof(ctx->Rcv[dormantIdx].key));

	// push it on the stack
	_pushSeedKey(ctx, dormantKeyPair);
}

#define MAX_KEY_INDEX_LOOKAHEAD		32	// how far we are willing to compute ahead

static SCLError _buildKeyForMessage(SCimpContextRef ctx, uint16_t msgSeqNum, uint8_t *keyOut, uint64_t  *msgIndexOut) {
	SCLError err = kSCLError_KeyNotFound;
	// look through our dormant seed keys for a close match
	Stack *stack = ctx->dormantSeedKeys;
    CommKeyPair *seedKey = NULL;
	while (stack != NULL) {
		seedKey = (CommKeyPair *)stack->data;
		// msgSeqNum coming in is only 16 bits - so we can only match to 16 bits...
		// TODO: will this fail if the unsigned long wraps?
		uint16_t matchIdx = seedKey->index & 0xffff;
		uint16_t deltaIdx = msgSeqNum - matchIdx;
		if ( (deltaIdx >= 0) && (deltaIdx < MAX_KEY_INDEX_LOOKAHEAD) )
			break; // looks like we found one in range

		// try the next one
		stack = stack->next;
	}
	if (stack == NULL)
		return kSCLError_KeyNotFound; // nothing found

	// now generate keys until we find the one we're looking for
	CommKeyPair matchKey;
	COPY(seedKey->key, matchKey.key, sizeof(seedKey->key));
	matchKey.index = seedKey->index;

	int safetyCount = 0;
	CommKeyPair nextKeyPair;
	while ((matchKey.index & 0xffff) != msgSeqNum) {
		err = sComputeNextCommKey(ctx, matchKey, &nextKeyPair); CKERR;

		COPY(nextKeyPair.key, matchKey.key, sizeof(nextKeyPair.key));
		matchKey.index = nextKeyPair.index;

		// EA: should be impossible to go into an infinite loop here, but I'm adding a secondary counter to be extra safe
		safetyCount++;
		if (safetyCount >= MAX_KEY_INDEX_LOOKAHEAD)
			return kSCLError_KeyNotFound; // nothing found
	}

	if ((seedKey->index & 0xffff) == msgSeqNum) {
		// the request matched our seed key - get rid of this seed key and generate the next one
		err = sComputeNextCommKey(ctx, *seedKey, &nextKeyPair); CKERR;
		COPY(nextKeyPair.key, seedKey->key, sizeof(nextKeyPair.key));
		seedKey->index = nextKeyPair.index;
	}

	// successfully generated a key pair
	COPY(matchKey.key, keyOut, sizeof(matchKey.key));
	*msgIndexOut = matchKey.index;
	err = kSCLError_NoErr;

done:
	return err; // nothing found
}

// method for computing a key from a previous key
static SCLError sComputeNextCommKey(SCimpContext *ctx, CommKeyPair prevKeyPair, CommKeyPair *newKeyPair) {
    SCLError             err = kSCLError_NoErr;
    MAC_ContextRef      macRef = kInvalidMAC_ContextRef;
    const char          *label = "MessageKey";
    int                 keyBits     = scSCimpCipherBits(ctx->cipherSuite);
    size_t		        resultLen   = sizeof(ctx->Ksnd);

    err  = MAC_Init( sSCimptoWrapperMAC(ctx->cipherSuite),
                    sSCimptoWrapperHASH(ctx->cipherSuite, keyBits*2),
                    prevKeyPair.key, keyBits/4,
                    &macRef); CKERR;
	MAC_Update(macRef,  "\x00\x00\x00\x01",  4);
    MAC_Update(macRef,  label,  strlen(label));
    MAC_Update(macRef,  "\x00",  1);
    MAC_Update(macRef,  ctx->SessionID, SCIMP_HASH_LEN);
    MAC_Update(macRef,  &prevKeyPair.index, sizeof(uint64_t));
    MAC_Update(macRef, (uint8_t*) "\x00\x00\x01\x00",  4);

	// finish up the new Key Pair
	MAC_Final( macRef, &newKeyPair->key, &resultLen);
    newKeyPair->index = prevKeyPair.index+1;

done:
    if(IsntNull(macRef))
        MAC_Free(macRef);
    
    return err;
}

static SCLError sAdvanceRcvKey(SCimpContext* ctx, uint8_t newIndex)
{
    uint8_t oldIndex = ctx->rcvIndex;
	SCLError err = sComputeNextCommKey(ctx, ctx->Rcv[oldIndex], &ctx->Rcv[newIndex]); CKERR;
	ctx->rcvIndex = newIndex;

done:
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
    
    if(isScimpSymmetric(ctx))
    {
        uint64_t seqNum = ctx->Isnd ^ msgSeqNum;
        ntoh64(seqNum,msgIndexOut);
        
        COPY(ctx->Ksnd, keyOut, scSCimpCipherBits(ctx->cipherSuite)/4);
        
        err = kSCLError_NoErr;
    }
    else {
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
					// older key, just zero for now
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
		if (err == kSCLError_KeyNotFound) {
			// not found - try any older seed keys
			CommKeyPair matchKeyPair;
			err = _buildKeyForMessage(ctx, msgSeqNum, matchKeyPair.key, &matchKeyPair.index); CKERR;

			// success! we generated a key for this index
			COPY(matchKeyPair.key, keyOut, scSCimpCipherBits(ctx->cipherSuite)/4);
			ntoh64(matchKeyPair.index, msgIndexOut);
		}
	}
done:
    
    return err;
}
 
SCLError  sComputeKeysSymmetric(SCimpContext* ctx, const char* threadStr, SCKeyContextRef key)
{
    SCLError        err = kSCLError_NoErr;
    int             keyLen;
  
    SCKeySuite      keySuite;
    uint8_t         symKey[64];
  
    union  {
        uint8_t     b [8];
        uint64_t    w;
    }Ksas;
 
    uint8_t* keyLocator = NULL;
    size_t  keyLocatorLen = 0;
      
    err = SCKeyGetProperty(key, kSCKeyProp_SCKeySuite,   NULL,  &keySuite, sizeof(SCKeySuite),  NULL); CKERR;
    err = SCKeyGetProperty(key, kSCKeyProp_SymmetricKey,   NULL,  &symKey, sizeof(symKey),  NULL); CKERR;
    err = SCKeyGetAllocatedProperty(key, kSCKeyProp_Locator,NULL,  (void*)&keyLocator ,  &keyLocatorLen); CKERR;

    switch(keySuite)
    {
        case kSCKeySuite_AES128:
            ctx->cipherSuite = kSCimpCipherSuite_Symmetric_AES128;
              break;
            
        case kSCKeySuite_AES256:
            ctx->cipherSuite = kSCimpCipherSuite_Symmetric_AES256;
            break;
            
        default:
        	RETERR(kSCLError_BadParams);
        	break;
    }

    keyLen = scSCimpCipherBits(ctx->cipherSuite);
    
    
    err = sComputeKDF(ctx, symKey, keyLen/8,  "SymmetricMasterKey", (uint8_t*) threadStr, threadStr?strlen(threadStr):0,
                      (uint32_t) keyLen * 2,  keyLen/8,
                      ctx->Ksnd); CKERR;
  
    
    err =  sComputeKDF(ctx, symKey, keyLen/8, "InitialIndex",  (uint8_t*) threadStr, threadStr?strlen(threadStr):0,
                       64,  sizeof(uint64_t),
                       (void*)  &ctx->Isnd );  CKERR;
 
    
    err = RNG_GetBytes((void*)  &ctx->Ioffset, sizeof(uint16_t)); CKERR;
    
    ctx->SAS = 0;
    
    err =  sComputeKDF(ctx, symKey, keyLen/8, "SAS", keyLocator, keyLocatorLen -1,  64, 8, &Ksas.b[0] );  CKERR;
    
    ntoh64(Ksas.w, &ctx->SAS);

    ctx->keyedTime = time(NULL);
    ctx->method = kSCimpMethod_Symmetric;
    ctx->hasKeys = true;
    
#if DEBUG_CRYPTO
    
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nKeyIn: (%d)\n",keyLen/8);
    dumpHex(symKey,  (int)keyLen/8 , 0);
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\n\n");
    
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nSymmetricMasterKey: (%d)\n",keyLen/8);
    dumpHex(ctx->Ksnd,  (int)keyLen/8 , 0);
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\n\n");

    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nInitialIndex: (%d)\n", (int)sizeof(uint64_t));
    dumpHex( (uint8_t*)  &ctx->Isnd ,  sizeof(uint64_t) , 0);
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\n\n");
 
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nIoffset: (%d)\n", (int)sizeof(uint16_t));
    dumpHex( (uint8_t*)  &ctx->Ioffset ,  sizeof(uint16_t) , 0);
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\n\n");
    
#endif
  
done:
    
    if(keyLocator) XFREE(keyLocator), keyLocator = NULL;

    ZERO(symKey, sizeof(symKey));
    return err;
    

}

 
static SCLError  sComputeKdk2(SCimpContext* ctx, ECC_ContextRef * privKey)
{
    SCLError             err = kSCLError_NoErr;
    MAC_ContextRef      macRef = kInvalidMAC_ContextRef;
    
 	uint8_t            Kdk     [SCIMP_HASH_PATH_BITS /8];
    uint8_t            Kdk2    [SCIMP_HASH_PATH_BITS / 8];
    uint8_t            hTotal  [SCIMP_HTOTAL_BITS / 8];
    uint8_t            Z       [256];
    
    
    uint8_t            *ctxStr = NULL;
    unsigned long       ctxStrLen = 0;
    size_t		        kdkLen;
    int                 keyLen = scSCimpCipherBits(ctx->cipherSuite);
    
    size_t   x;
    
    static const char *kSCimpstr_MasterSecret = "MasterSecret";
    static const char *kSCimpstr_Enhance = "SCimp-ENHANCE";
    
    
    /*  Htotal = H(commit || DH1 || Pki )  - SCIMP_HTOTAL_BITS bit hash */
    ZERO(hTotal, sizeof(hTotal));
    if(ctx->HtotalState)
        HASH_Final( ctx->HtotalState, hTotal);
    
    /* Kdk = MAC(Htotal,Z)    where Z is the DH of Pki and PKr */
    x = sizeof(Z);
    
    err = ECC_SharedSecret(*privKey, ctx->pubKey, Z, sizeof(Z), &x);
    /* at this point we dont need the ECC keys anymore. Clear them */
    
    // correct the error for keyMistmatch
    if(err == kSCLError_BadParams )
        err = kSCLError_FeatureNotAvailable;
    
    if(*privKey)
    {
        ECC_Free(*privKey);
        *privKey = kInvalidECC_ContextRef;
    }
    
    if(ctx->pubKey)
    {
        ECC_Free(ctx->pubKey);
        ctx->pubKey = kInvalidECC_ContextRef;
    }

    if(ctx->ctxStr)
    {
        XFREE(ctx->ctxStr);
        ctx->ctxStr = NULL;
    }
    ctx->ctxStrLen = 0;

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
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nKey Method: %s\n", methodText(ctx->method));
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
    
    if(((ctx->method == kSCimpMethod_DH) || (ctx->method == kSCimpMethod_DHv2))
       && ctx->hasCs && ctx->csMatches)
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
    
    ctx->ctxStr = ctxStr;
    ctx->ctxStrLen = ctxStrLen;
    COPY(Kdk2, ctx->Kdk2, sizeof(Kdk2));
    ctx->KdkLen = kdkLen;
    
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
    
    return err;
}

static SCLError  sComputeCommKeys(SCimpContext* ctx)
{
    SCLError             err = kSCLError_NoErr;
    MAC_ContextRef      macRef = kInvalidMAC_ContextRef;
    int                 keyLen = scSCimpCipherBits(ctx->cipherSuite);
    
    
    uint8_t            *ctxStr = ctx->ctxStr;
    unsigned long       ctxStrLen = ctx->ctxStrLen;
    unsigned long       kdkLen = ctx->KdkLen;
    
    
    union  {
        uint8_t     b [8];
        uint64_t    w;
    }Ksas;

    _saveSeedKey(ctx);

    ctx->rcvIndex = 0;
    ZERO(ctx->Rcv, sizeof(ctx->Rcv));
    
    // generate initial master key for initiator
    err = sComputeKDF(ctx, ctx->Kdk2, kdkLen,  "InitiatorMasterKey", ctxStr, ctxStrLen,
                      (uint32_t) keyLen * 2,  keyLen/4,
                      ctx->isInitiator?ctx->Ksnd:ctx->Rcv[0].key); CKERR;
    
    // generate initiator MAC key
    err =  sComputeKDF(ctx, ctx->Kdk2, kdkLen, "InitiatorMACkey",    ctxStr, ctxStrLen,
                       256, SCIMP_MAC_LEN, ctx->MACi); CKERR;
    
    // generate responder MAC key
    err =  sComputeKDF(ctx, ctx->Kdk2, kdkLen, "ResponderMACkey",    ctxStr, ctxStrLen,
                       256, SCIMP_MAC_LEN, ctx->MACr); CKERR;
    
    ctx->SAS = 0;
    if(ctx->method == kSCimpMethod_PubKey)
    {
        err =  sComputeKDF(ctx, ctx->Kdk2, kdkLen, "SAS",                ctxStr, ctxStrLen,
                           64, 8, &Ksas.b[0] );  CKERR;
        ntoh64(Ksas.w, &ctx->SAS);
        
    }
    else
    {
        err =  sComputeKDF(ctx, ctx->Kdk2, kdkLen, "SAS",                ctxStr, ctxStrLen,
                           20, 4, &Ksas.b[0] );  CKERR;
        ctx->SAS =   ( (ntohl(Ksas.w) >> 12) & (~0U >> 12));   // just 32-12 = 20 bits
        
    }
    
    
    /* rekey new cached secret */
    ZERO(ctx->Cs1,  SCIMP_KEY_LEN);
    err =  sComputeKDF(ctx, ctx->Kdk2, kdkLen, "RetainedSecret",     ctxStr, ctxStrLen,
                       (uint32_t) keyLen * 2, keyLen/4, ctx->Cs1);  CKERR;
    
    
    sComputeSessionID(ctx);
    
    // generate initial message index for initiator
    err =  sComputeKDF(ctx, ctx->Kdk2, kdkLen, "InitiatorInitialIndex",   ctx->SessionID , sizeof(ctx->SessionID),
                       64,  sizeof(uint64_t),
                       (void*) (ctx->isInitiator? &ctx->Isnd: &ctx->Rcv[0].index));  CKERR;
    
    // generate initial master key for responder
    err = sComputeKDF(ctx, ctx->Kdk2, kdkLen, "ResponderMasterKey", ctxStr, ctxStrLen,
                      (uint32_t) keyLen * 2,  keyLen/4,
                      ctx->isInitiator?ctx->Rcv[0].key:ctx->Ksnd); CKERR;
    
    
    // generate initial message index for responder
    err =  sComputeKDF(ctx, ctx->Kdk2, kdkLen, "ResponderInitialIndex",   ctx->SessionID , sizeof(ctx->SessionID),
                       64,  sizeof(uint64_t),
                       (void*) (!ctx->isInitiator? &ctx->Isnd: &ctx->Rcv[0].index)); CKERR;
    
#if DEBUG_CRYPTO
    
    DPRINTF(XCODE_COLORS_BLUE_TXT,"\nKdk2: (%d)\n",kdkLen);
    dumpHex(ctx->Kdk2,  (int)kdkLen , 0);
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
    
    if(ctx->method == kSCimpMethod_PubKey)
    {
          
        DPRINTF(XCODE_COLORS_BLUE_TXT,"\nSAS:  %016llX \n\n", ctx->SAS);
 
    }
    else
    {
        DPRINTF(XCODE_COLORS_BLUE_TXT,"\nSAS: %04X\n\n", ctx->SAS);
 
    }
    
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
    
    ctx->keyedTime = time(NULL);
    ctx->hasKeys = true;
    
done:
    
    if(ctx->HtotalState)
    {
        HASH_Free(ctx->HtotalState);
        ctx->HtotalState = kInvalidHASH_ContextRef;
    }
    
    
    if(IsntNull(macRef))
        MAC_Free(macRef);
    
    ZERO(ctx->Kdk2, sizeof(ctx->Kdk2));
    ctx->KdkLen = 0;
    
    
    if(ctx->ctxStr)
    {
        XFREE(ctx->ctxStr);
        ctx->ctxStr = NULL;
    }
    ctx->ctxStrLen = 0;
    
    return err;
    
}

 

#ifdef __clang__
#pragma mark
#pragma mark Callback handlers
#endif

static SCLError sInvokeEventHandler(SCimpContextRef   ctx, SCimpEvent* event)
{
 
    SCLError             err         = kSCLError_NoErr;
    if(ctx->inSyncMode)
    {
        err = sSyncEventHandler(ctx, event);
    }
    else
    {
        if( ctx->handler)
        {
            err = (ctx->handler)( ctx, event, ctx->userValue );
        }
    }
 
    return err;
}

SCLError scEventSendPacket(
                           SCimpContextRef   ctx,
                           uint8_t*          data, 
                           size_t            dataLen,
                           void*             userRef,
                           bool              shouldPush,
                           bool              isPKdata
                           )
{
    SCLError             err         = kSCLError_NoErr;
 	SCimpEvent      event;

    ZERO(&event, sizeof( event ));
    
  	event.type                      = kSCimpEvent_SendPacket;
  	event.userRef                   = userRef;
 	event.data.sendData.data        = data;
    event.data.sendData.length      = dataLen;
    event.data.sendData.shouldPush  = shouldPush;
    event.data.sendData.isPKdata    = isPKdata;
    
    err = sInvokeEventHandler(ctx, &event);
    
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

    ZERO(&event, sizeof( event ));
 
  	event.type                         = kSCimpEvent_Decrypted;
    event.userRef                      = userRef;
 	event.data.decryptData.data        = data;
    event.data.decryptData.length      = dataLen;
    
    err = sInvokeEventHandler(ctx, &event);
    
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
    

    ZERO(&event, sizeof( event ));

  	event.type                       = kSCimpEvent_ClearText;
    event.userRef                    = userRef;
 	event.data.clearText.data        = data;
    event.data.clearText.length      = dataLen;
    
    err = sInvokeEventHandler(ctx, &event);
    
	return err;
}

SCLError scEventPubData(
                          SCimpContextRef     ctx,
                          uint8_t*            data,
                          size_t              dataLen,
                          void*               userRef
                          )
{
    SCLError             err         = kSCLError_NoErr;
 	SCimpEvent      event;
    
    ZERO(&event, sizeof( event ));

    event.type                     = kSCimpEvent_PubData;
    event.userRef                  = userRef;
 	event.data.pubData.data        = data;
    event.data.pubData.length      = dataLen;
    
    err = sInvokeEventHandler(ctx, &event);
    
	return err;
}




SCLError scEventNull(
                        SCimpContextRef   ctx )
{
    SCLError             err         = kSCLError_NoErr;
 	SCimpEvent          event;

    ZERO(&event, sizeof( event ));
 
    event.type							= kSCimpEvent_NULL;
    
    err = sInvokeEventHandler(ctx, &event);
    
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
 
    ZERO(&event, sizeof( event ));

    event.type							= kSCimpEvent_Error;
    event.userRef                       = userRef;
  	event.data.errorData.error          = error;
    
    err = sInvokeEventHandler(ctx, &event);
    
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
 
    ZERO(&event, sizeof( event ));
 
    event.type							= kSCimpEvent_Warning;
    event.userRef                       = userRef;
	event.data.warningData.warning        = warning;
    
    err = sInvokeEventHandler(ctx, &event);
    
	return err;
}

SCLError scEventKeyed( SCimpContextRef   ctx, void* userRef )
{
    SCLError                 err         = kSCLError_NoErr;
 	SCimpEvent          event;
    SCimpInfo           info;
 
    ZERO(&event, sizeof( event ));
    ZERO(&info, sizeof( info ));
    
    SCimpGetInfo(ctx, &info);
    
  	event.type                      = kSCimpEvent_Keyed;
    event.userRef                    = userRef;
 	event.data.keyedData.info        = info;
    
    err = sInvokeEventHandler(ctx, &event);
    
	return err;
}
 
 
SCLError scEventReKeying( SCimpContextRef   ctx)
{
    SCLError                 err         = kSCLError_NoErr;
 	SCimpEvent          event;
    SCimpInfo           info;

    ZERO(&event, sizeof( event ));
    ZERO(&info, sizeof( info ));
    
    SCimpGetInfo(ctx, &info);
    
  	event.type                      = kSCimpEvent_ReKeying;
 	event.data.keyedData.info        = info;
    
    err = sInvokeEventHandler(ctx, &event);
    
	return err;
}

SCLError scEventShutdown(
                       SCimpContextRef   ctx )
{
    SCLError             err         = kSCLError_NoErr;
 	SCimpEvent          event;

    ZERO(&event, sizeof( event ));
    event.type			= kSCimpEvent_Shutdown;
     
    err = sInvokeEventHandler(ctx, &event);
    
	return err;
}


SCLError scEventTransition(
                         SCimpContextRef   ctx, SCimpState state )
{
    SCLError             err         = kSCLError_NoErr;
 	SCimpEvent          event;
    
	if(!ctx->wantsTransEvents)
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    event.type			= kSCimpEvent_Transition;
    event.data.transData.state = state;
    event.data.transData.method = ctx->method;
    
    err = sInvokeEventHandler(ctx, &event);
    
	return err;
}

SCLError scEventLogging(  SCimpContextRef ctx, SCimpMsg* msg, bool isOutgoing )
{
    SCLError             err         = kSCLError_NoErr;
    SCimpEvent          event;
    
    if(ctx->loggingLevel == kSCimpLogging_None)
        return kSCLError_NoErr;
    
    
    if((msg->msgType == kSCimpMsg_Data)
       && ((ctx->loggingLevel & kSCimpLogging_Data) == 0))
        return kSCLError_NoErr;
    
        
    ZERO(&event, sizeof( event ));
    event.type			= kSCimpEvent_LogMsg;
    event.data.loggingData.isOutgoing = isOutgoing;
    event.data.loggingData.msg = msg;
    
    err = sInvokeEventHandler(ctx, &event);
    
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


    ZERO(&event, sizeof( event ));
    event.type			= kSCimpEvent_AdviseSaveState;
     
    err = sInvokeEventHandler(ctx, &event);
    
	return err;
}


SCLError scEventNeedsKey(
                     SCimpContextRef   ctx,
                      char*             locator,
                      SCKeyContextRef   *privKey,
                      SCKeySuite        expectingKeySuite )
{
    SCLError             err         = kSCLError_NoErr;
 	SCimpEvent          event;
    
	if( IsNull( ctx->handler ) )
		return kSCLError_NoErr;
    
    ZERO(&event, sizeof( event ));
    event.type							= kSCimpEvent_NeedsPrivKey;
    event.data.needsKeyData.locator         = locator;
    event.data.needsKeyData.privKey         = privKey;
    event.data.needsKeyData.expectingKeySuite   = expectingKeySuite;
      
	err = (ctx->handler)( ctx, &event, ctx->userValue );
    
	return err;
}


#ifdef __clang__
#pragma mark
#pragma mark format packets
#endif

 
/*____________________________________________________________________________
 Format Messages 
 ____________________________________________________________________________*/

SCLError sSendSCimpmsg_Commit(SCimpContext *ctx)
{
    SCLError           err = kSCLError_NoErr;
    SCimpMsg           msg;
   
    uint8_t     *buffer = NULL;
    size_t      bufLen = 0;
    
    uint8_t            PK[128];
    size_t			   PKlen = 0;
    
    validateSCimpContext(ctx);
     ValidateParam(ctx->youStr);
    ValidateParam(ctx->meStr);
    
    bool use384Only = true;
    bool shouldPush = !((ctx->method == kSCimpMethod_PubKey) && ctx->hasKeys);
     
    if(ctx->method == kSCimpMethod_DHv2 || ctx->method == kSCimpMethod_PubKey)
        use384Only = false;
    
  // for compatibility with ST-1
    ctx->cipherSuite = use384Only? kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384 :ctx->cipherSuite;
  
    ctx->isInitiator = true;
    
    /* delete old ECC pub key */
   if(ctx->pubKey)
    {
        ECC_Free(ctx->pubKey);
        ctx->pubKey = kInvalidECC_ContextRef;
    }

      /* Make a new ECC key */
   if (ctx->privKeyDH != kInvalidECC_ContextRef)
	   ECC_Free(ctx->privKeyDH);
    err = ECC_Init(&ctx->privKeyDH); CKERR;
    err = ECC_Generate(ctx->privKeyDH, sECCDH_Bits( ctx->cipherSuite) ); CKERR;
    
    /* get copy of public key */
    err = ECC_Export(ctx->privKeyDH, false, PK, sizeof(PK), &PKlen); CKERR;
    
    ZERO(&msg, sizeof(SCimpMsg));
     
    msg.msgType               = kSCimpMsg_Commit;
    msg.commit.version        = ctx->version;
    msg.commit.cipherSuite    = ctx->cipherSuite;
    msg.commit.sasMethod      = ctx->sasMethod;
      
    /* insert Hash of Initiators PK */
    sMakeHash(ctx->cipherSuite, PK, PKlen, SCIMP_HASH_LEN,  msg.commit.Hpki);
    
    /* insert Hash of initiators shared secret */
    err = sComputeSSmac(ctx, PK, PKlen, (char *)kSCimpstr_Initiator, msg.commit.Hcs); CKERR;
    
    err = SERIALIZE_SCIMP(ctx, &msg, &buffer, &bufLen); CKERR;

    err = LOG_SCIMP(ctx, &msg, MSG_OUTGOING); CKERR;

    /* update Htotal */
    if(ctx->HtotalState != kInvalidHASH_ContextRef)
        HASH_Free(ctx->HtotalState);
    err = HASH_Init( sSCimptoWrapperHASH(ctx->cipherSuite, SCIMP_HTOTAL_BITS), &ctx->HtotalState);  CKERR;
    
    HASH_Update( ctx->HtotalState,  &msg.commit,  sizeof(SCimpMsg_Commit));
    
    err = scEventSendPacket(ctx, buffer, bufLen, NULL, shouldPush, false);
    
 done:
    
    if(buffer) { XFREE(buffer); buffer = NULL; }

    return err;
}



static SCLError sMakeSCimpmsg_DH1(SCimpContext* ctx, uint8_t **out, size_t *outlen)
{
    SCLError                 err = kSCLError_NoErr;
    SCimpMsg                msg;
            
    size_t		           PKlen = PK_ALLOC_SIZE;
    uint8_t                *PK = NULL; 
      
    validateSCimpContext(ctx);
    ValidateParam(out);
    ValidateParam(outlen);
    
    ZERO(&msg, sizeof(SCimpMsg));
    PK = XMALLOC(PKlen); CKNULL(PK);
    
    msg.msgType = kSCimpMsg_DH1;
    
     /* insert copy of public key */
    err = ECC_Export(ctx->privKeyDH, false, PK, PKlen, &PKlen); CKERR;
    msg.dh1.pk = PK;
    msg.dh1.pkLen = PKlen;
    
    if((ctx->method == kSCimpMethod_DH) || (ctx->method == kSCimpMethod_DHv2))     // PK has no shared secret
    {
        /* insert Hash of recipient's shared secret */
        sComputeSSmac(ctx, PK, PKlen, (char *)kSCimpstr_Responder, msg.dh1.Hcs);
    }
  
    err = SERIALIZE_SCIMP(ctx, &msg, out, outlen); CKERR;
    
    err = LOG_SCIMP(ctx, &msg, MSG_OUTGOING); CKERR;
    
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
    
    size_t		           PKlen = PK_ALLOC_SIZE;
    uint8_t                *PK = NULL; 
    
    validateSCimpContext(ctx);
    ValidateParam(out);
    ValidateParam(outlen);
    
    ZERO(&msg, sizeof(SCimpMsg));
    PK = XMALLOC(PKlen); CKNULL(PK);
    
    msg.msgType = kSCimpMsg_DH2;
    
    /* insert copy of public key */
    err = ECC_Export(ctx->privKeyDH, false, PK, PKlen, &PKlen); CKERR;
    msg.dh2.pk = PK;
    msg.dh2.pkLen = PKlen;
      
    /* update Htotal */
    HASH_Update( ctx->HtotalState,  PK,  PKlen);
    
     err = sComputeKdk2(ctx, & ctx->privKeyDH); CKERR;
      
    err =  sComputeKDF(ctx, ctx->Kdk2, ctx->KdkLen, "InitiatorMACkey",    ctx->ctxStr, ctx->ctxStrLen,
                       256, SCIMP_MAC_LEN, ctx->MACi); CKERR;
 
 
    /* insert MAC of recipient's shared secret */
    COPY(ctx->MACi, msg.dh2.Maci,SCIMP_MAC_LEN);
    
    err = SERIALIZE_SCIMP(ctx, &msg, out, outlen); CKERR;
    
    err = LOG_SCIMP(ctx, &msg, MSG_OUTGOING); CKERR;

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
    
    err = LOG_SCIMP(ctx, &msg, MSG_OUTGOING); CKERR;

   
done:
    return err;
}


#ifdef __clang__
#pragma mark
#pragma mark process packets
#endif

static SCLError sProcessSCimpMsg_PKstart(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError             err = kSCLError_NoErr;
    SCimpMsg_PKstart*    m =  &msg->pkstart;
    uint8_t             msgKey[SCIMP_KEY_LEN];
    uint8_t             msgIndex[8];
    uint8_t             *PT = NULL;
    size_t              PTLen = 0;
    SCKeySuite          iCurveSuite = kSCKeySuite_Invalid;
    SCKeySuite          rCurveSuite = kSCKeySuite_Invalid;
    
    uint8_t     *buffer = NULL;
    size_t      bufLen = 0;
 
    uint8_t* keyLocator = NULL;
    size_t  keyLocatorLen = 0;
    
    if((m->version != kSCimpProtocolVersion2)
       || !isValidSASMethod(m->sasMethod)
       || !isValidCipherSuite(ctx, m->cipherSuite)  )
    {
        scEventError(ctx, kSCLError_FeatureNotAvailable, NULL);
        RETERR(kSCLError_CorruptData);
    }
    
    
    if(SCKeyContextRefIsValid(ctx->scKey))
    {
        err = SCKeyGetAllocatedProperty(ctx->scKey, kSCKeyProp_Locator,NULL,  (void*)&keyLocator ,  &keyLocatorLen); CKERR;
    }
    
    if( !keyLocator || (strncmp((char *)keyLocator, m->locator, keyLocatorLen -1) != 0))
    {
        SCKeyContextRef newPrivkey = kInvalidSCKeyContextRef;
        bool            isLocked = true;
 
        err = scEventNeedsKey(ctx, m->locator, &newPrivkey, sECCDH_SCKeySuite( m->cipherSuite)); CKERR;
        
        if(SCKeyContextRefIsValid(newPrivkey))
        {
            if(keyLocator) XFREE(keyLocator), keyLocator = NULL;
            
            err = SCKeyGetAllocatedProperty(newPrivkey, kSCKeyProp_Locator,NULL,  (void*)&keyLocator ,  &keyLocatorLen); CKERR;
        }

        if( !keyLocator || (strncmp((char *)keyLocator, (char *)(m->locator), keyLocatorLen -1) != 0))
        {
			if (keyLocator) XFREE(keyLocator), keyLocator = NULL;
            RETERR(kSCLError_KeyNotFound);
        }
        
        // cant be locked
        err = SCKeyIsLocked(newPrivkey,&isLocked); CKERR;
        ASSERTERR(isLocked, kSCLError_KeyLocked);
       
        ctx->scKey = newPrivkey;
    }
    
    /* save parameters */
    ctx->version    = m->version;
    ctx->cipherSuite    = m->cipherSuite;
    ctx->sasMethod      = m->sasMethod;
    ctx->method         = kSCimpMethod_PubKey;
    ctx->isInitiator    = false;
    
    /* my secret always matches */
    ctx->csMatches = ctx->hasCs = false;
    ZERO(ctx->Cs,  SCIMP_KEY_LEN);
    ZERO(ctx->Cs1,  SCIMP_KEY_LEN);

    /* save public key */
    err = ECC_Init(&ctx->pubKey); CKERR;
    err = ECC_Import(ctx->pubKey,m->pk, m->pkLen); CKERR;
    
    /* check public key for validity */
    iCurveSuite = sECCDH_SCKeySuite( ctx->cipherSuite);
    err = sECCDH_SCKeySuiteFromECC(ctx->pubKey, &rCurveSuite); CKERR;
    
    if(iCurveSuite != rCurveSuite)
        RETERR(kSCLError_CorruptData);

    // NOTE: no check for expired key here, we assume it's checked before calling this
 
    /* copy our Private key over */
    err = SCKeyExport_ECC(ctx->scKey,  &ctx->privKey0); CKERR;
    
    /* Save Hash of initiator's PK  */
    COPY(m->Hpki, &ctx->Hpki, SCIMP_HASH_LEN);
    
    err = sComputeKdk2(ctx, &ctx->privKey0); CKERR;
    err = sComputeCommKeys(ctx); CKERR;
  
    // set the state ready before notifying the user of keyed
    scEventTransition(ctx, kSCimpState_PKStart);
    
    ntoh64(ctx->Rcv[0].index, msgIndex);
    err = sGetKeyforMessage(ctx, (uint16_t) (ctx->Rcv[0].index & 0xFFFF) , msgKey, msgIndex); CKERR;
 
    err = CCM_Decrypt_Mem( scSCimpCipherAlgorithm(ctx->cipherSuite),
                        msgKey,         scSCimpCipherBits(ctx->cipherSuite)/4,
                        msgIndex,       sizeof(msgIndex),
                        m->msg,         m->msgLen,
                        m->tag,         sizeof(m->tag),
                        &PT,            &PTLen); CKERR;
    
    err = scEventDecrypt(ctx, PT, PTLen, msg->userRef) ; CKERR;

    /* start a new Htotal */
    err = HASH_Init( sSCimptoWrapperHASH(ctx->cipherSuite, SCIMP_HTOTAL_BITS), &ctx->HtotalState);  CKERR;
    
    /* update Htotal */
    HASH_Update( ctx->HtotalState,  msg->pkstart.locator, strlen(msg->pkstart.locator));
    HASH_Update( ctx->HtotalState,  msg->pkstart.pk, msg->pkstart.pkLen);
    HASH_Update( ctx->HtotalState,  msg->pkstart.Hpki,  sizeof(msg->pkstart.Hpki));
    HASH_Update( ctx->HtotalState,  msg->pkstart.msg, msg->pkstart.msgLen);
    HASH_Update( ctx->HtotalState,  msg->pkstart.tag, sizeof(msg->pkstart.tag));

      /* Make a new ECC key */
    err = ECC_Init(&ctx->privKeyDH); CKERR;
    err = ECC_Generate(ctx->privKeyDH, sECCDH_Bits( ctx->cipherSuite) ); CKERR;
   
      /* create reply PK-DH1 */
    sMakeSCimpmsg_DH1(ctx, &buffer, &bufLen);

    ctx->state = kSCimpState_DH1;      //setting this here to help with optest loopback

    err = scEventSendPacket(ctx, buffer, bufLen, NULL, false, false);
   
    scEventKeyed(ctx, NULL);

done:
   
    scEventAdviseSaveState(ctx);
    
    if(buffer)
    {
        XFREE(buffer);
        buffer = NULL;
    }

    if(IsSCLError(err))
    {
        scEventError(ctx, err,msg->userRef);
        sResetFromAbort(ctx);
     }
    
    ZERO(msgKey, sizeof(msgKey));
    
     if(keyLocator)
         XFREE(keyLocator);
         
    if(PT)
    {
        ZERO(PT,PTLen);
        XFREE(PT);
    }
    
    scimpFreeMessageContent(msg);
    XFREE(msg);
 
    return err;
}



static SCLError sProcessSCimpmsg_Commit(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError             err = kSCLError_NoErr;
    SCimpMsg_Commit*    m =  &msg->commit;
    
    uint8_t             *buffer = NULL;
    size_t              bufLen = 0;
    
    bool shouldPush = !((ctx->method == kSCimpMethod_PubKey) && ctx->hasKeys);

    if(  !((m->version == kSCimpProtocolVersion1) || (m->version == kSCimpProtocolVersion2))
       || !isValidSASMethod(m->sasMethod) 
       || !isValidCipherSuite(ctx, m->cipherSuite))
    {
        scEventError(ctx, kSCLError_FeatureNotAvailable, NULL);
        RETERR(kSCLError_CorruptData);
   }
    
    /* are we an aborted Pubkey start? */
     if(ctx->method == kSCimpMethod_PubKey)
    {
        sResetFromAbort(ctx);
        err = scEventReKeying(ctx); CKERR;

    }
    
    /* correction if being keyed by older version */
    if(m->version == kSCimpProtocolVersion1 &&  ctx->method == kSCimpMethod_DHv2)
        ctx->method = kSCimpMethod_DH;
    
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
    err = ECC_Init(&ctx->privKeyDH); CKERR;
    err = ECC_Generate(ctx->privKeyDH, sECCDH_Bits( ctx->cipherSuite) ); CKERR;
    
    /* create reply DH1 */
    sMakeSCimpmsg_DH1(ctx, &buffer, &bufLen);
    
    err = scEventSendPacket(ctx, buffer, bufLen, NULL, shouldPush, false);
    
done:
    if(buffer)
    {
        XFREE(buffer);
        buffer = NULL;
    }
   
    scimpFreeMessageContent(msg);
    XFREE(msg);
    
    return err;
}

static SCLError sProcessSCimpmsg_DH1(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError        err = kSCLError_NoErr;
    SCimpMsg_DH1*   m =  &msg->dh1;
  
    uint8_t         *buffer = NULL;
    size_t          bufLen = 0;
    bool            shouldPush = false;

    uint8_t         HCS1[SCIMP_MAC_LEN];
  
    SCKeySuite      iCurveSuite = kSCKeySuite_Invalid;
    SCKeySuite      rCurveSuite = kSCKeySuite_Invalid;
    
    ValidateParam(m->pk);

    /* update Htotal */
    HASH_Update( ctx->HtotalState,  m->pk, m->pkLen);
    HASH_Update( ctx->HtotalState,  m->Hcs,  sizeof(m->Hcs));

    /* save public key */
    err = ECC_Init(&ctx->pubKey); CKERR;
    err = ECC_Import(ctx->pubKey,m->pk, m->pkLen); CKERR;
    
    /* check public key for validity */
    iCurveSuite = sECCDH_SCKeySuite( ctx->cipherSuite);
    err = sECCDH_SCKeySuiteFromECC(ctx->pubKey, &rCurveSuite); CKERR;
    
    if(iCurveSuite != rCurveSuite)
        RETERR(kSCLError_CorruptData);
    
    /* check secret commitment */
    
    if((ctx->method == kSCimpMethod_DH) || (ctx->method == kSCimpMethod_DHv2))      // PK has no shared secret
    {
        /* compare Hash of initiators shared secret */
        err = sComputeSSmac(ctx, m->pk, m->pkLen, (char *)kSCimpstr_Responder, HCS1); CKERR;
        
        ctx->csMatches = CMP(m->Hcs, HCS1, SCIMP_MAC_LEN);
        if(!ctx->csMatches)
        {
            scEventWarning(ctx, kSCLError_SecretsMismatch,NULL);
        }
    }
      
    /* create reply DH2 */
    sMakeSCimpmsg_DH2(ctx, &buffer, &bufLen);
    
    shouldPush = !((ctx->method == kSCimpMethod_PubKey) && ctx->hasKeys);
    
    err = scEventSendPacket(ctx, buffer, bufLen, NULL , shouldPush ,false);
    
done:
    if(buffer)
    {
        XFREE(buffer);
        buffer = NULL;
    }

    scimpFreeMessageContent(msg);
    XFREE(msg);
   return err;
}

static SCLError sProcessSCimpmsg_DH2(SCimpContextRef ctx, SCimpMsg* msg)
{
    SCLError             err = kSCLError_NoErr;
    SCimpMsg_DH2*       m =  &msg->dh2;
    
    uint8_t             *buffer = NULL;
    size_t              bufLen = 0;
    bool                shouldPush = false;
    
    uint8_t             HPKi[SCIMP_HASH_LEN];
    uint8_t             HCS1[SCIMP_MAC_LEN];
  
    SCKeySuite      iCurveSuite = kSCKeySuite_Invalid;
    SCKeySuite      rCurveSuite = kSCKeySuite_Invalid;

    ValidateParam(m->pk);
       
    /* save public key */
    err = ECC_Init(&ctx->pubKey); CKERR;
    err = ECC_Import(ctx->pubKey, m->pk, m->pkLen); CKERR;
      
    /* check public key for validity */
    iCurveSuite = sECCDH_SCKeySuite( ctx->cipherSuite);
    err = sECCDH_SCKeySuiteFromECC(ctx->pubKey, &rCurveSuite); CKERR;
    
    if(iCurveSuite != rCurveSuite)
        RETERR(kSCLError_CorruptData);

    /* create Hash of Initiators PK */
    sMakeHash(ctx->cipherSuite,  m->pk, m->pkLen, SCIMP_HASH_LEN, HPKi);
    
    /* check PKI hash */
    if(!CMP(ctx->Hpki, HPKi, SCIMP_HASH_LEN))
        RETERR(kSCLError_CorruptData);
    
    /* check Hash of initiators shared secret */
    err = sComputeSSmac(ctx,  m->pk, m->pkLen, (char *)kSCimpstr_Initiator, HCS1);CKERR;
    
    ctx->csMatches = CMP(ctx->Hcs, HCS1, SCIMP_MAC_LEN);
    if( ctx->hasCs && !ctx->csMatches)
    {
        scEventWarning(ctx, kSCLError_SecretsMismatch, NULL);
    }

    /* update Htotal */
    HASH_Update( ctx->HtotalState,  m->pk, m->pkLen);

    shouldPush = !((ctx->method == kSCimpMethod_PubKey) && ctx->hasKeys);

    if(ctx->method == kSCimpMethod_PubKey)
        ctx->method  = kSCimpMethod_DHv2;

    err = sComputeKdk2(ctx, & ctx->privKeyDH); CKERR;
    err = sComputeCommKeys(ctx); CKERR;
    
    /* check if Initiator's confirmation code matches */ 
    if(!CMP(ctx->MACi, m->Maci, SCIMP_MAC_LEN))
    {
        scEventError(ctx, kSCLError_BadIntegrity, NULL);
        RETERR(kSCLError_BadIntegrity);
    }
    /* create reply Confirm */
    sMakeSCimpmsg_Confirm(ctx, &buffer, &bufLen);

    err = scEventSendPacket(ctx, buffer, bufLen, NULL , shouldPush ,false);

 
  done:
    
    if(buffer)
    {
        XFREE(buffer);
        buffer = NULL;
    }

    scimpFreeMessageContent(msg);
    XFREE(msg);
   return err;
}

static SCLError sProcessSCimpmsg_Confirm(SCimpContextRef ctx, SCimpMsg* msg)
{
    SCLError             err = kSCLError_NoErr;
    SCimpMsg_Confirm*   m =  &msg->confirm;    
    
    if(ctx->method == kSCimpMethod_PubKey)
        ctx->method  = kSCimpMethod_DHv2;
    
   err = sComputeCommKeys(ctx); CKERR;
    
    /* check if Responder's confirmation code matches */ 
    if(!CMP(ctx->MACr, m->Macr, 8))
    {
        scEventError(ctx, kSCLError_BadIntegrity, NULL);
        RETERR(kSCLError_BadIntegrity);
    }
    
    // set the state ready before notifying the user of keyed
    ctx->state = kSCimpState_Ready;
  
    scEventTransition(ctx, kSCimpState_Ready);
    scEventKeyed(ctx, NULL);
 
done:
    scimpFreeMessageContent(msg);
    XFREE(msg);
    return err;
}




static SCLError sProcessSCimpmsg_Data(SCimpContextRef ctx, SCimpMsg* msg)
{
    SCLError            err = kSCLError_NoErr;
    
    SCimpMsg_Data*     m =  &msg->data;
    uint8_t          *PT = NULL;
    size_t            PTLen = 0;
    uint8_t           key[SCIMP_KEY_LEN];
    uint8_t           msgIndex[8];
    
    ValidateParam(m->msg);

    err = sGetKeyforMessage(ctx, m->seqNum, key, msgIndex); CKERR;

    err = CCM_Decrypt_Mem(       scSCimpCipherAlgorithm(ctx->cipherSuite),
                       key,      scSCimpCipherBits(ctx->cipherSuite)/4,
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
 



static SCLError sProcessSCimpmsg_ClearText(SCimpContextRef ctx, SCimpMsg* msg)
{
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


static SCLError sProcessSCimpmsg_PubData(SCimpContextRef ctx, SCimpMsg* msg)
{
    SCLError            err = kSCLError_NoErr;
    
    SCimpMsg_PubData*   m =  &msg->pubData;
    
    uint8_t             msgIndex[8];
    uint8_t             Ksession[SCIMP_KEY_LEN];
    size_t              KsessionLen;
  
    uint8_t*            keyLocator = NULL;
    size_t              keyLocatorLen = 0;
    
    uint8_t             pk[128];
    size_t              pkLen = sizeof (pk);

    uint8_t             *PT = NULL;
    size_t              PTLen = 0;
    
    if((m->version != kSCimpProtocolVersion2)
       || !isValidCipherSuite(ctx, m->cipherSuite)  )
    {
        scEventError(ctx, kSCLError_FeatureNotAvailable, NULL);
        RETERR(kSCLError_CorruptData);
    }
      
    if(SCKeyContextRefIsValid(ctx->scKey))
    {
        err = SCKeyGetAllocatedProperty(ctx->scKey, kSCKeyProp_Locator,NULL,  (void*)&keyLocator ,  &keyLocatorLen); CKERR;
    }

    
    if( !keyLocator || (strncmp((char *)keyLocator, m->locator, keyLocatorLen -1) != 0))
    {
        SCKeyContextRef newPrivkey = kInvalidSCKeyContextRef;
        bool            isLocked = true;
        
        err = scEventNeedsKey(ctx, m->locator, &newPrivkey, sECCDH_SCKeySuite( m->cipherSuite)); CKERR;
        
        if(SCKeyContextRefIsValid(newPrivkey))
        {
            if(keyLocator) XFREE(keyLocator), keyLocator = NULL;
            
            err = SCKeyGetAllocatedProperty(newPrivkey, kSCKeyProp_Locator,NULL,  (void*)&keyLocator ,  &keyLocatorLen); CKERR;
        }
        
        if( !keyLocator || (strncmp((char *)keyLocator, m->locator, keyLocatorLen -1) != 0))
            RETERR(kSCLError_KeyNotFound);
        
        // cant be locked
        err = SCKeyIsLocked(newPrivkey,&isLocked); CKERR;
        ASSERTERR(isLocked, kSCLError_KeyLocked);
        
        ctx->scKey = newPrivkey;
    }
    
    // copy the the public key
    err = SCKeyExport_ANSI_X963(ctx->scKey,pk, pkLen, &pkLen); CKERR;
    err = sMakeHash(m->cipherSuite,  pk, pkLen, 8, msgIndex);

    err = SCKeyPublicDecrypt(ctx->scKey, m->esk, m->eskLen,Ksession, sizeof(Ksession), &KsessionLen);
    
    if(KsessionLen != scSCimpCipherBits(m->cipherSuite)/4)
        RETERR(kSCLError_CorruptData);
   
    err = CCM_Decrypt_Mem(scSCimpCipherAlgorithm(m->cipherSuite ),
                     Ksession,      KsessionLen,
                      msgIndex,       sizeof(msgIndex),
                      m->msg,         m->msgLen,
                      m->tag,         sizeof(m->tag),
                      &PT,            &PTLen); CKERR;
    
    
    err = scEventPubData(ctx, PT, PTLen, msg->userRef) ; CKERR;
    
    scEventAdviseSaveState(ctx);
    
done:
    
    ZERO(Ksession, sizeof(Ksession));
        
    if(PT)
    {
        ZERO(PT,PTLen);
        XFREE(PT);
    }

    if(IsSCLError(err))
    {
        scEventError(ctx, err, msg->userRef);
    }
    
    scimpFreeMessageContent(msg);
    XFREE(msg);
    
    return err;
}





#ifdef __clang__
#pragma mark
#pragma mark State Handlers
#endif




static SCLError sDoNull(SCimpContext* ctx, SCimpMsg* msg )
{
    (void) msg;
    
    scEventNull(ctx);
      
    return kSCLError_NoErr;
}

static SCLError sDoReset(SCimpContext* ctx, SCimpMsg* msg )
{
    (void) msg;
      
    scEventShutdown(ctx);
    scResetSCimpContext(ctx,false);
     
    return kSCLError_NoErr;
}

static SCLError sDoStartDH(SCimpContext* ctx, SCimpMsg* msg )
{
    (void) msg;
    SCLError     err = kSCLError_NoErr;
 
    sSendSCimpmsg_Commit(ctx); CKERR;
    
done:   
    
    return err;   
}


static SCLError sDoRcv_PKstart(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;

    err = sProcessSCimpMsg_PKstart(ctx, msg); CKERR;
 
done:
    return err;
}

static SCLError sDoRcv_Commit(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
  
    err = sProcessSCimpmsg_Commit(ctx, msg); CKERR;
    
done:
  
    return err;
}

static SCLError sImproperRekey(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
     
    err =  scEventWarning(ctx, kSCLError_ProtocolError, NULL); CKERR;
    
    scResetSCimpContext(ctx,false);
    scEventAdviseSaveState(ctx);

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

static SCLError sDoPKStartContention(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;

    scResetSCimpContext(ctx,false);

    err =  scEventWarning(ctx, kSCLError_ProtocolContention, NULL); CKERR;

    err = sDoRcv_PKstart(ctx, msg);

    ctx->state = kSCimpState_DH1;

done:
    scEventAdviseSaveState(ctx);
    return err;
}

static SCLError sDoCommitContention(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
    
    scResetSCimpContext(ctx,false);
    
    err =  scEventWarning(ctx, kSCLError_ProtocolContention, NULL); CKERR;
    
    err = sDoRcv_Commit(ctx, msg);
    
    ctx->state = kSCimpState_DH1;
    
done:
    
    scEventAdviseSaveState(ctx);
    
    
    return err;
    
}


static SCLError sDoRcv_DH1(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
   
    err = sProcessSCimpmsg_DH1(ctx, msg); CKERR;
    
done:   
    
    return err;   
}

static SCLError sDoRcv_DH2(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
  
    err = sProcessSCimpmsg_DH2(ctx, msg); CKERR;
    
    if(ctx->method == kSCimpMethod_PubKey)
        ctx->method  = kSCimpMethod_DHv2;
 
    // after receiving a DH2 the responder should be in a confirm state,
    // we will bump it to a ready state now that the confirm has been sent.
    
    err = scTriggerSCimpTransition(ctx, kSCimpTrans_SND_Confirm, NULL); CKERR;
done:   
    
    return err;   
}

static SCLError sDoRcv_Confirm(SCimpContext* ctx, SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
  
    err = sProcessSCimpmsg_Confirm(ctx, msg); CKERR;
    
    scEventAdviseSaveState(ctx);

done:
    return err;   
}

// this is a psuedo state used to inform the user of ckeying once we hit the ready state.
static SCLError sDoSent_Confirm(SCimpContext* ctx,   SCimpMsg* msg)
{
    // set the state ready before notifying the user of keyed
    ctx->state = kSCimpState_Ready;
    
    if(ctx->method == kSCimpMethod_PubKey)
        ctx->method  = kSCimpMethod_DHv2;
 
    scEventTransition(ctx, kSCimpState_Ready);
    scEventAdviseSaveState(ctx);

    scEventKeyed(ctx, NULL);
      
    return kSCLError_NoErr;
}


static SCLError sDoRcv_Data(SCimpContext* ctx,   SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
    if(ctx->hasKeys)
        err = sProcessSCimpmsg_Data(ctx, msg);
    else
        err = sNotKeyed(ctx, msg);
    CKERR;
   
done:   
     return err;   
}

static SCLError sDoRcv_ClearText(SCimpContext* ctx,   SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
    
     err = sProcessSCimpmsg_ClearText(ctx, msg); CKERR;
    
done:   
    return err;   
}




static SCLError sDoRcv_PubData(SCimpContext* ctx,   SCimpMsg* msg)
{
    SCLError     err = kSCLError_NoErr;
    
    err = sProcessSCimpmsg_PubData(ctx, msg); CKERR;
    
done:
    return err;
}

#ifdef __clang__
#pragma mark
#pragma mark Sync API calls
#endif

static SCLError sSyncEventHandler(SCimpContextRef ctx, SCimpEvent* event)
{
    SCLError     err  = kSCLError_NoErr;
    
    ValidateParam(ctx->syncResultList);
    ValidateParam(event->type != kSCimpEvent_NeedsPrivKey);
    
    SCimpResultBlock* newResult = XMALLOC(sizeof (SCimpResultBlock));
    ZERO(newResult, sizeof (SCimpResultBlock));
   
    COPY(event, &newResult->event, sizeof(SCimpEvent));
    
    // handle events with pointers to data
    // we need to clone those pointers
    switch (event->type)
    {
        case kSCimpEvent_SendPacket:
        {
            uint8_t* copyData = XMALLOC(event->data.sendData.length);
            COPY(event->data.sendData.data, copyData, event->data.sendData.length);
            newResult->event.data.sendData.data = copyData;
         }
            break;

            
        case kSCimpEvent_PubData:
        {
            uint8_t* copyData = XMALLOC(event->data.pubData.length);
            COPY(event->data.pubData.data, copyData, event->data.pubData.length);
            newResult->event.data.pubData.data = copyData;
        }
            break;

        case kSCimpEvent_Decrypted:
        {
            uint8_t* copyData = XMALLOC(event->data.decryptData.length);
            COPY(event->data.decryptData.data, copyData, event->data.decryptData.length);
            newResult->event.data.decryptData.data = copyData;
        }
            break;

        case kSCimpEvent_ClearText:

        {
            uint8_t* copyData = XMALLOC(event->data.clearText.length);
            COPY(event->data.clearText.data, copyData, event->data.clearText.length);
            newResult->event.data.clearText.data = copyData;
        }
            break;

        
        case kSCimpEvent_LogMsg:
        {
            SCimpMsg* msgData =  XMALLOC(sizeof(SCimpMsg) );
            ZERO(msgData,sizeof(SCimpMsg));
            COPY(event->data.loggingData.msg , msgData, sizeof(SCimpMsg));
   
            newResult->event.data.loggingData.msg = msgData ;
            
            switch (msgData->msgType)
            {
                case kSCimpMsg_DH1:
                {
                    uint8_t* copyData = XMALLOC(event->data.loggingData.msg->dh1.pkLen);
                    COPY(event->data.loggingData.msg->dh1.pk, copyData, event->data.loggingData.msg->dh1.pkLen);
                    newResult->event.data.loggingData.msg->dh1.pk = copyData;
                    
                }
                    break;
                    
                case kSCimpMsg_DH2:
                {
                    uint8_t* copyData = XMALLOC(event->data.loggingData.msg->dh2.pkLen);
                    COPY(event->data.loggingData.msg->dh2.pk, copyData, event->data.loggingData.msg->dh2.pkLen);
                    newResult->event.data.loggingData.msg->dh2.pk = copyData;
                    
                }
                    break;
                    
                case kSCimpMsg_Data:
                {
                    uint8_t* copyData = XMALLOC(event->data.loggingData.msg->data.msgLen);
                    COPY(event->data.loggingData.msg->data.msg, copyData, event->data.loggingData.msg->data.msgLen);
                    newResult->event.data.loggingData.msg->data.msg = copyData;
                    
                }
                    break;

                case kSCimpMsg_PKstart:
                {
                    uint8_t* copyData = NULL;
                    
                    copyData = XMALLOC(event->data.loggingData.msg->pkstart.pkLen);
                    COPY(event->data.loggingData.msg->pkstart.pk, copyData, event->data.loggingData.msg->pkstart.pkLen);
                    newResult->event.data.loggingData.msg->pkstart.pk = copyData;

                    copyData = XMALLOC(event->data.loggingData.msg->pkstart.msgLen);
                    COPY(event->data.loggingData.msg->pkstart.msg, copyData, event->data.loggingData.msg->pkstart.msgLen);
                    newResult->event.data.loggingData.msg->pkstart.msg = copyData;
                    
                    if(event->data.loggingData.msg->pkstart.locator)
                    {
                        char* locator  = strdup(event->data.loggingData.msg->pkstart.locator);
                        newResult->event.data.loggingData.msg->pkstart.locator = locator;

                    }
                 }
                    break;
                    
                case kSCimpMsg_PubData:
                {
                    uint8_t* copyData = NULL;
    
                    copyData = XMALLOC(event->data.loggingData.msg->pubData.msgLen);
                    COPY(event->data.loggingData.msg->pubData.msg, copyData, event->data.loggingData.msg->pubData.msgLen);
                    newResult->event.data.loggingData.msg->pubData.msg = copyData;
                    
                    copyData = XMALLOC(event->data.loggingData.msg->pubData.eskLen);
                    COPY(event->data.loggingData.msg->pubData.esk, copyData, event->data.loggingData.msg->pubData.eskLen);
                    newResult->event.data.loggingData.msg->pubData.esk = copyData;
                  
                    if(event->data.loggingData.msg->pkstart.locator)
                    {
                        char* locator  = strdup(event->data.loggingData.msg->pkstart.locator);
                        newResult->event.data.loggingData.msg->pkstart.locator = locator;
                        
                    }
                }
                    break;
                    
                default:
                    break;
            }
            
            
           
        }
            break;

         default:
            break;
    }
   
    // add this result to the chain
    SCimpResultBlock* lastBlock = *ctx->syncResultList;
    if(!lastBlock)
    {
        *ctx->syncResultList = newResult;
    }
    else
    {
        // We don't Coalescing events with pointers
        bool canCoalesceEvent =
                newResult->event.type == kSCimpEvent_AdviseSaveState
             || newResult->event.type == kSCimpEvent_Transition;
        
        // either replace the event on the list or add it to the end
        while(true)
        {
            if(canCoalesceEvent && lastBlock->event.type == newResult->event.type)
            {
                COPY(&newResult->event, &lastBlock->event, sizeof(SCimpEvent));
                ZERO(newResult, sizeof (SCimpResultBlock));
                XFREE(newResult); newResult = NULL;
                break;
            }
            else
            {
                if(lastBlock->next != NULL)
                {
                    lastBlock = lastBlock->next;
                }
                else
                {
                     lastBlock->next = newResult;
                    break;
                }
            }
         }
        
    }
     
    return err;
}



SCLError SCimpFreeEventBlock(SCimpResultBlock *resultsIn )
{
    SCLError     err = kSCLError_NoErr;
    
    
    ValidateParam(resultsIn);
    
    // remove all sub entries
    
    //
    
    SCimpResultBlock* result = resultsIn;
    
    while (result)
    {
        SCimpResultBlock* nextResult = result->next;
        SCimpEvent  *event = &result->event;
        
        // handle events with pointers to data
        switch (event->type)
        {
            case kSCimpEvent_SendPacket:
            {
                if(event->data.sendData.data)
                {
                    ZERO(event->data.sendData.data, event->data.sendData.length);
                    XFREE(event->data.sendData.data);
                    event->data.sendData.data = NULL;
                }
            }
                break;
                
                
            case kSCimpEvent_PubData:
            {
                if(event->data.pubData.data)
                {
                    ZERO(event->data.pubData.data, event->data.pubData.length);
                    XFREE(event->data.pubData.data);
                    event->data.pubData.data = NULL;
                }
            }
                break;
                
            case kSCimpEvent_Decrypted:
            {
                if(event->data.decryptData.data)
                {
                    ZERO(event->data.decryptData.data, event->data.decryptData.length);
                    XFREE(event->data.decryptData.data);
                    event->data.decryptData.data = NULL;
                }
            }
                break;
                
            case kSCimpEvent_ClearText:
                
                if(event->data.clearText.data)
                {
                    ZERO(event->data.clearText.data, event->data.clearText.length);
                    XFREE(event->data.clearText.data);
                    event->data.clearText.data = NULL;
                }
                break;
                
 
            case kSCimpEvent_LogMsg:
            {
                if(event->data.loggingData.msg)
                {
                    SCimpMsg* msgData = event->data.loggingData.msg;
                    
                   switch (msgData->msgType)
                    {
                        case kSCimpMsg_DH1:
                            ZERO(msgData->dh1.pk, msgData->dh1.pkLen);
                            XFREE(msgData->dh1.pk);
                            msgData->dh1.pk = NULL;
                            break;
                            
                      case kSCimpMsg_DH2:
                            ZERO(msgData->dh2.pk, msgData->dh2.pkLen);
                            XFREE(msgData->dh2.pk);
                            msgData->dh2.pk = NULL;
                            break;
                            
                        case kSCimpMsg_Data:
                            ZERO(msgData->data.msg, msgData->data.msgLen);
                            XFREE(msgData->data.msg);
                            msgData->data.msg = NULL;
                            break;
 
                        case kSCimpMsg_PKstart:
                            ZERO(msgData->pkstart.msg, msgData->pkstart.msgLen);
                            XFREE(msgData->pkstart.msg);
                            msgData->pkstart.msg = NULL;
                            
                            ZERO(msgData->pkstart.pk, msgData->pkstart.pkLen);
                            XFREE(msgData->pkstart.pk);
                            msgData->pkstart.pk = NULL;

                            XFREE(msgData->pkstart.locator);
                            msgData->pkstart.locator = NULL;
                            break;
                            
                        case kSCimpMsg_PubData:
                            ZERO(msgData->pubData.msg, msgData->pubData.msgLen);
                            XFREE(msgData->pubData.msg);
                            msgData->pubData.msg = NULL;
                            
                            ZERO(msgData->pubData.esk, msgData->pubData.eskLen);
                            XFREE(msgData->pubData.esk);
                            msgData->pubData.esk= NULL;
                            
                            XFREE(msgData->pubData.locator);
                            msgData->pubData.locator = NULL;
                            break;
                           
 
                        default:  ;
                    }
                    
                    ZERO(msgData, sizeof(SCimpMsg));
                    XFREE(msgData);
                    event->data.loggingData.msg = NULL;
                  }
            }
                break;
                
                
            default:
                break;
        }
        
        ZERO(result, sizeof(SCimpResultBlock));
        XFREE(result);
        
        result = nextResult;
    }
    
    return err;
    
}



SCLError SCimpStartDHSync(SCimpContextRef scimp,
                          SCimpResultBlock **resultsOut)

{
    SCLError           err = kSCLError_NoErr;
    
    SCimpResultBlock*    results = NULL;
    
    validateSCimpContext(scimp);
    
    // PUSH EVENT MGR
    scimp->inSyncMode = true;
    scimp->syncResultList = &results;
  
    scimp->isInitiator   = true;
    
    err = scTriggerSCimpTransition(scimp, kSCimpTrans_StartDH, NULL); CKERR;
     
done:
    
    scimp->inSyncMode = false;
    scimp->syncResultList = NULL;
    
    
    if(resultsOut)
    {
        *resultsOut = results;
    }
    else
    {
        SCimpFreeEventBlock(results);
    }
    
    return err;
    
}

SCLError SCimpProcessPacketSync(
                                SCimpContextRef         scimp,
                                uint8_t*                data,
                                size_t                  dataLen,
                                void*                   userRef,
                                SCimpResultBlock        **resultsOut)
{
    SCLError           err = kSCLError_NoErr;
    
    SCimpResultBlock*    results = NULL;
    
    validateSCimpContext(scimp);
    
    // PUSH EVENT MGR
    scimp->inSyncMode = true;
    scimp->syncResultList = &results;
    
    err = SCimpProcessPacket(scimp, data, dataLen, userRef); CKERR;
    
done:
    
    scimp->inSyncMode = false;
    scimp->syncResultList = NULL;
    
    
    if(resultsOut)
    {
        *resultsOut = results;
    }
    else
    {
        SCimpFreeEventBlock(results);
    }
    
    return err;
 
}


SCLError SCimpSendMsgSync(SCimpContextRef  scimp,
                          void*                 data,
                          size_t                dataLen,
                          void*                   userRef,
                          SCimpResultBlock      **resultsOut )
{
    SCLError           err = kSCLError_NoErr;
    
    SCimpResultBlock*    results = NULL;
    
    validateSCimpContext(scimp);
    
    // PUSH EVENT MGR
    scimp->inSyncMode = true;
    scimp->syncResultList = &results;
    
    
    if(scimp->state == kSCimpState_PKInit)
    {
        err = scSendScimpPKstartInternal(scimp, data, dataLen, userRef); CKERR;
    }
    else
    {
        err = scSendScimpDataInternal(scimp, data, dataLen, userRef); CKERR;
    }
    
done:
    
    scimp->inSyncMode = false;
    scimp->syncResultList = NULL;
    
    
    if(resultsOut)
    {
        *resultsOut = results;
    }
    else
    {
        SCimpFreeEventBlock(results);
    }
    
    return err;
 
}

SCLError SCimpSendPublicSync(SCimpContextRef    scimp,
                             SCKeyContextRef        pubKey,
                             void*                  data,
                             size_t                 dataLen,
                             void*                   userRef,
                             SCimpResultBlock       **resultsOut )
{
    SCLError     err = kSCLError_NoErr;
    
    SCimpResultBlock*    results = NULL;
    
    validateSCimpContext(scimp);
  
    // PUSH EVENT MGR
    scimp->inSyncMode = true;
    scimp->syncResultList = &results;
    
    err = SCimpSendPublic(scimp, pubKey, data, dataLen, userRef); CKERR;
    
done:
    
    scimp->inSyncMode = false;
    scimp->syncResultList = NULL;
    
    
    if(resultsOut)
    {
        *resultsOut = results;
    }
    else
    {
        SCimpFreeEventBlock(results);
    }
    
    return err;
}

SCLError SCimpSendPKStartMsgSync(SCimpContextRef      scimp,
                                 SCKeyContextRef      pubKey,
                                 void *               data,
                                 size_t               dataLen,
                                 void *               userRef,
                                 SCimpResultBlock ** resultsOut )
{
    SCLError     err = kSCLError_NoErr;
    
    SCimpResultBlock*    results = NULL;
    
    validateSCimpContext(scimp);
    
    // PUSH EVENT MGR
    scimp->inSyncMode = true;
    scimp->syncResultList = &results;
    
    err = SCimpStartPublicKey(scimp, pubKey, 0); CKERR;
    err = scSendScimpPKstartInternal(scimp, data, dataLen, userRef); CKERR;

    
done:
    
    scimp->inSyncMode = false;
    scimp->syncResultList = NULL;
    
    
    if(resultsOut)
    {
        *resultsOut = results;
    }
    else
    {
        SCimpFreeEventBlock(results);
    }
    
    return err;

}


#ifdef __clang__
#pragma mark
#pragma mark State machine
#endif

static const state_table_type SCIMP_state_table[]=
{
    { ANY_STATE,            kSCimpTrans_NULL,           NO_NEW_STATE,           sDoNull             },
    { ANY_STATE,            kSCimpTrans_Reset,       kSCimpState_Init,       sDoReset         },
    
    // run states
    { ANY_STATE,            kSCimpTrans_RCV_Data,       NO_NEW_STATE,           sDoRcv_Data         },
    { ANY_STATE,            kSCimpTrans_RCV_ClearText,  NO_NEW_STATE,           sDoRcv_ClearText    },  
    { ANY_STATE,            kSCimpTrans_RCV_PubData ,   NO_NEW_STATE,           sDoRcv_PubData      },
    
    // keying states
    { kSCimpState_Init,     kSCimpTrans_StartDH,        kSCimpState_Commit,     sDoStartDH          },
     
    { kSCimpState_Init,     kSCimpTrans_RCV_Commit,     kSCimpState_DH1,        sDoRcv_Commit       },
    { kSCimpState_Commit,   kSCimpTrans_RCV_DH1,        kSCimpState_DH2,        sDoRcv_DH1          },
    { kSCimpState_DH1,      kSCimpTrans_RCV_DH2,        kSCimpState_Ready,      sDoRcv_DH2          },
    { kSCimpState_DH2,      kSCimpTrans_RCV_Confirm,    kSCimpState_Ready,      sDoRcv_Confirm      },
    { ANY_STATE,            kSCimpTrans_SND_Confirm,    kSCimpState_Ready,      sDoSent_Confirm     },

   // scimp 2 keying
    { kSCimpState_PKCommit,	kSCimpTrans_RCV_PKStart,	NO_NEW_STATE,			sDoPKStartContention },
    { ANY_STATE,            kSCimpTrans_RCV_PKStart,    kSCimpState_DH1,        sDoRcv_PKstart      },
    { kSCimpState_PKCommit, kSCimpTrans_RCV_DH1,        kSCimpState_DH2,        sDoRcv_DH1          },
    
    // edge cases
    /* client does rekey after established */
    { ANY_STATE,            kSCimpTrans_StartDH,        kSCimpState_Commit,     sDoStartDH          },
    
    /* responder gets rekeyed after established */
    { kSCimpState_Ready,    kSCimpTrans_RCV_Commit,     kSCimpState_DH1,        sDoRcv_Commit       },  
    { kSCimpState_PKStart,  kSCimpTrans_RCV_Commit,     kSCimpState_DH1,        sDoRcv_Commit       },
 
    // out of sequence messages
    { ANY_STATE,            kSCimpTrans_RCV_Commit,     NO_NEW_STATE,         sDoCommitContention },
    
    { ANY_STATE,            kSCimpTrans_RCV_DH1,        NO_NEW_STATE,      sImproperRekey      },
   { ANY_STATE,             kSCimpTrans_RCV_DH2,        NO_NEW_STATE,      sImproperRekey,     },
    { ANY_STATE,            kSCimpTrans_RCV_Confirm,    NO_NEW_STATE,      sImproperRekey,     },

    
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
        {kSCimpTrans_RCV_PubData    ,"RCV_PubData"},
        {kSCimpTrans_Complete,     "Complete"},
        {kSCimpTrans_Reset,         "Reset"},
        {0,NULL}
    };
    
    int i;
    
    for(i = 0; trans_txt[i].txt; i++)
        if(trans_txt[i].trans == trans) return(trans_txt[i].txt);
    
    return "Invalid";
    
}


#endif

#define FIX_43133a6 1


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
            
            if(IsntSCLError(err) && (table->next != NO_NEW_STATE))
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


#ifdef __clang__
#pragma mark
#pragma mark Private Entry points 
#endif

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



SCLError scSendScimpPKstartInternal(SCimpContext* ctx,
                                 uint8_t     *in,
                                 size_t     inLen,
                                 void*      userRef)
{
    SCLError         err         = kSCLError_NoErr;
    SCimpMsg        msg;
    
    uint8_t         msgIndex[8];
    
     uint8_t         *buffer = NULL;
    size_t          bufLen = 0;
    
    uint8_t         PK0[256];
    size_t          PK0len  = 0;
 
    uint8_t         PKDH[256];
    size_t          PKDHlen  = 0;

    ZERO(&msg, sizeof(SCimpMsg));
    
    if(ctx->state != kSCimpState_PKInit)
        RETERR(kSCLError_ImproperInitialization);

    // NOTE: no check for expired key here, we assume it's checked before calling this

    /* get copy of public key 0 */
    err = ECC_Export(ctx->privKey0, false, PK0, sizeof(PK0), &PK0len); CKERR;

    /* get copy of public  DH key*/
    err = ECC_Export(ctx->privKeyDH, false, PKDH, sizeof(PKDH), &PKDHlen); CKERR;
      
    /* my secret always matches */
    ctx->csMatches = ctx->hasCs = false;
    ZERO(ctx->Cs,  SCIMP_KEY_LEN);
    ZERO(ctx->Cs1,  SCIMP_KEY_LEN);
 
    /* compute the keys */
    err = sComputeKdk2(ctx,&ctx->privKey0 ); CKERR;
    err = sComputeCommKeys(ctx); CKERR;
    
    // start message as pkstart
    msg.msgType                 = kSCimpMsg_PKstart;
    msg.pkstart.version         = ctx->version;
    msg.pkstart.cipherSuite     = ctx->cipherSuite;
    msg.pkstart.sasMethod       = ctx->sasMethod;

    // copy PK0 to allocated memory (free'd later by scimpFreeMessageContent)
    msg.pkstart.pk = XMALLOC(PK0len);
    COPY(PK0, msg.pkstart.pk, PK0len);
    msg.pkstart.pkLen           = PK0len;

    // copy locator to allocated memory (free'd later by scimpFreeMessageContent)
    msg.pkstart.locator = XMALLOC(strlen(ctx->pubKeyLocator)+1); // 1 more for null-terminator
    strcpy(msg.pkstart.locator, ctx->pubKeyLocator);
     
    /* insert Hash of Initiators  DH key */
    sMakeHash(ctx->cipherSuite, PKDH, PKDHlen, SCIMP_HASH_LEN,  msg.pkstart.Hpki);
     
    ntoh64(ctx->Isnd,msgIndex);
     
    err = CCM_Encrypt_Mem( scSCimpCipherAlgorithm(ctx->cipherSuite) ,
                       ctx->Ksnd,           scSCimpCipherBits(ctx->cipherSuite)/4,
                       msgIndex,            sizeof(msgIndex),
                       in,                  inLen,
                       &msg.pkstart.msg,    &msg.pkstart.msgLen,
                       msg.pkstart.tag,     sizeof(msg.pkstart.tag)); CKERR;

    err = SERIALIZE_SCIMP(ctx, &msg, &buffer, &bufLen); CKERR;
    
    err = LOG_SCIMP(ctx, &msg, MSG_OUTGOING); CKERR;

    err = sAdvanceSendKey(ctx); CKERR;
    
    /* start a new Htotal */
    err = HASH_Init( sSCimptoWrapperHASH(ctx->cipherSuite, SCIMP_HTOTAL_BITS), &ctx->HtotalState);  CKERR;

    /* update Htotal */
    HASH_Update( ctx->HtotalState,  msg.pkstart.locator, strlen(msg.pkstart.locator));
    HASH_Update( ctx->HtotalState,  PK0, PK0len);
    HASH_Update( ctx->HtotalState,  msg.pkstart.Hpki,  sizeof(msg.pkstart.Hpki));
    HASH_Update( ctx->HtotalState,  msg.pkstart.msg, msg.pkstart.msgLen);
    HASH_Update( ctx->HtotalState,  msg.pkstart.tag, sizeof(msg.pkstart.tag));

    ctx->state = kSCimpState_PKCommit;
    scEventTransition(ctx, kSCimpState_PKCommit);
   
    scEventAdviseSaveState(ctx);
    
    err = scEventSendPacket(ctx, buffer, bufLen, userRef, true,false);
 
    scEventKeyed(ctx, userRef);
   
done:
    if(buffer) { XFREE(buffer); buffer = NULL; }
    scimpFreeMessageContent(&msg);

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
    
    if(!ctx->hasKeys)
        RETERR(kSCLError_NotConnected);
    
     
   if(isScimpSymmetric(ctx))
    {
        uint64_t seqNum = ctx->Isnd ^ ctx->Ioffset;
        ntoh64(seqNum,msgIndex);
        
        msg.msgType         = kSCimpMsg_Data;
        msg.data.seqNum     = ctx->Ioffset;
        
    }
    else
    {
        ntoh64(ctx->Isnd,msgIndex);
        msg.msgType         = kSCimpMsg_Data;
        msg.data.seqNum     = (uint16_t) (ctx->Isnd & 0xFFFF);
    }
    
    err = CCM_Encrypt_Mem( scSCimpCipherAlgorithm(ctx->cipherSuite) ,
                       ctx->Ksnd,      scSCimpCipherBits(ctx->cipherSuite)/4,
                       msgIndex,       sizeof(msgIndex),
                       in,             inLen,
                       &msg.data.msg,  &msg.data.msgLen,
                       msg.data.tag,    sizeof(msg.data.tag)); CKERR;
    
    err = SERIALIZE_SCIMP(ctx, &msg, &buffer, &bufLen); CKERR;
    
    err = LOG_SCIMP(ctx, &msg, MSG_OUTGOING); CKERR;
   
    err = sAdvanceSendKey(ctx); CKERR;
    
    scEventAdviseSaveState(ctx);
    
    err = scEventSendPacket(ctx, buffer, bufLen, userRef, true,false);
    
    
done:
    if(buffer) { XFREE(buffer); buffer = NULL; }
    scimpFreeMessageContent(&msg);
    
    return err;
    
}

SCLError scSendPublicDataInternal(SCimpContext*     ctx,
                              SCKeyContextRef   pubKey,
                              uint8_t        *in,
                              size_t         inLen,
                              void*          userRef )
{
    SCLError         err         = kSCLError_NoErr;
    SCimpMsg        msg;
 
    uint8_t         msgIndex[8];
    uint8_t         Ksession[SCIMP_KEY_LEN];     
    size_t          KsessionLen = scSCimpCipherBits(ctx->cipherSuite)/4;
    uint8_t         *buffer = NULL;
    size_t          bufLen = 0;
 
    uint8_t         *locator = NULL;
    size_t          locatorLen = 0;
    
    uint8_t         pk[128];
    size_t          pkLen = sizeof (pk);
    
    uint8_t         esk[256];
    size_t          eskLen = sizeof (esk);
    
    err = RNG_GetBytes((void*) Ksession, KsessionLen); CKERR;

    // copy the key locator
    err = SCKeyGetAllocatedProperty(pubKey, kSCKeyProp_Locator,NULL,  (void*)&locator ,  &locatorLen); CKERR;
     
    // copy the the public key
    err = SCKeyExport_ANSI_X963(pubKey,pk, pkLen, &pkLen); CKERR;
    err = sMakeHash(ctx->cipherSuite,  pk, pkLen, 8, msgIndex);
   
    err = SCKeyPublicEncrypt(pubKey, Ksession, KsessionLen, esk, eskLen, &eskLen);
    
    ZERO(&msg, sizeof(SCimpMsg));
      
    msg.msgType                 = kSCimpMsg_PubData;
    msg.pubData.version         = kSCimpProtocolVersion2;
    msg.pubData.cipherSuite     = ctx->cipherSuite;
    msg.pubData.locator         = (char *)locator;
    msg.pubData.esk             = esk;
    msg.pubData.eskLen          = eskLen;
 
    err = CCM_Encrypt_Mem( scSCimpCipherAlgorithm(ctx->cipherSuite),
                      Ksession,       KsessionLen,
                      msgIndex,       sizeof(msgIndex),
                      in,              inLen,
                      &msg.pubData.msg,   &msg.pubData.msgLen,
                      msg.pubData.tag,    sizeof(msg.pubData.tag)); CKERR;

    err = SERIALIZE_SCIMP(ctx, &msg, &buffer, &bufLen); CKERR;
    
    err = LOG_SCIMP(ctx, &msg, MSG_OUTGOING); CKERR;
    
    err = scEventSendPacket(ctx, buffer, bufLen, userRef, true, true);
    
    
done:
    
    ZERO(Ksession, sizeof(Ksession));
    
    ZERO(pk, sizeof(pk));
    
    if(locator)
        XFREE(locator);
    
    if(buffer) { XFREE(buffer); buffer = NULL; }
    scimpFreeMessageContent(&msg);
    
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
            
		case kSCimpMsg_PubData:
			if(msg->pubData.msg) XFREE(msg->pubData.msg);
			break;

		case kSCimpMsg_PKstart:
			if (msg->pkstart.pk) XFREE(msg->pkstart.pk);
			if (msg->pkstart.locator) XFREE(msg->pkstart.locator);
			if (msg->pkstart.msg) XFREE(msg->pkstart.msg);
			break;

        default:
            break;
    };
       
    ZERO(msg, sizeof(SCimpMsg));
}



#ifdef __clang__
#pragma mark
#pragma mark Public Entry points 
#endif

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
  
        case kSCimpMsg_PKstart:
        {
            SCimpMsg_PKstart* c =  &msgP->pkstart;
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%-12s\n","PKSTART PACKET");
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: 0x%02x\n","Version", c->version);
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: %02x\n","CipherSuite", c->cipherSuite);
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: %02x\n","SAS", c->sasMethod);
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: %s\n","locator", c->locator);
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: %d bytes\n","Pk0", (int)c->pkLen);
            dumpHex(c->pk, (int)c->pkLen, 0);
             DPRINTF(XCODE_COLORS_BLUE_TXT, "\n%12s: ","H(DH-Pki)");  dumpHex8(c->Hpki);dumpHex8(c->Hpki+8);
        
            DPRINTF(XCODE_COLORS_BLUE_TXT, "\n%12s: ","Tag");  dumpHex8(c->tag);;
            DPRINTF(XCODE_COLORS_BLUE_TXT, "\n%12s: %d bytes\n","Data", (int)c->msgLen );
            dumpHex(c->msg, (int)c->msgLen, 0);
            
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
         
            
        case kSCimpMsg_PubData:
        {
            SCimpMsg_PubData* c =  &msgP->pubData;
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%-12s\n","PUB_DATA PACKET");
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: 0x%02x\n","Version", c->version);
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: %02x\n","CipherSuite", c->cipherSuite);
      
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: %s\n","locator", c->locator);
            DPRINTF(XCODE_COLORS_BLUE_TXT, "%12s: %d bytes\n","esk", (int)c->eskLen);
            dumpHex(c->esk, (int)c->eskLen, 0);
             DPRINTF(XCODE_COLORS_BLUE_TXT, "\n%12s: ","Tag");  dumpHex8(c->tag);;
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
    
    err = LOG_SCIMP(ctx, msg, MSG_INCOMING); CKERR;

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
 
        case kSCimpMsg_PKstart:
            err = scTriggerSCimpTransition(ctx, kSCimpTrans_RCV_PKStart, msg);
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

        case kSCimpMsg_PubData:
            err = scTriggerSCimpTransition(ctx, kSCimpTrans_RCV_PubData, msg);
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
