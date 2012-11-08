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


#include <limits.h>
#include <stdio.h>
#include "optest.h"

#include "cryptowrappers.h"
#include "KAPS.h"

#define DEBUG_KAPS 1
/*____________________________________________________________________________
 General data types used by Silent Circle Code
 ____________________________________________________________________________*/

const BYTE kKapsProtocolVersion  = 0x01;


#pragma mark

#pragma mark KAPS Context

/*____________________________________________________________________________
 KAPS Context	
 ____________________________________________________________________________*/

enum KAPSstate_
{
    kKAPSstate_Init             = 0,
    kKAPSstate_Ready            = 1,
    
    /* Initiator State */
    kKAPSstate_Rekey            = 10,
    kKAPSstate_Commit           = 11,
    kKAPSstate_DH2              = 12,

    /* Responder State */
    kKAPSstate_Uncommited       = 20,
    kKAPSstate_DH1              = 21,
    kKAPSstate_Confirmed        = 22,

     ENUM_FORCE( KAPSstate_ )
};

ENUM_TYPEDEF( KAPSstate_, KAPSstate  );


#define KAPS_KEY_LEN  64
typedef struct SCKAPSContext    SCKAPSContext;

struct SCKAPSContext 
{
 #define kSCKAPSContextMagic		0x4B415053 
	UInt32                  magic;
    KAPSstate               state;          /* State of this end */

    BYTE                    version;        /* KAPS version */
    KAPSPublicKeyAlgorithm  pkAlg;
    KAPSMACAlgorithm        macAlg;
    KAPSHashAlgorithm       hashAlg;
    KAPSsas                 sasMethod;
    KAPSCipherAlgorithm     cipherAlg;
    KAPSAuthTag             authTag;
      
    Boolean                 isInitiator;    /* this is the initiator */
    Boolean                 hasCs;          /* has existing shared secret */
    Boolean                 csMatches;      /* hashes of cached shared secret match */
    
    Boolean                 hasKeys;          /* calculated new keys */
      
    char*                   meStr;          /* My identifying Info String*/
    char*                   youStr;
   
    ECC_ContextRef          privKey;        /* our private key */
    ECC_ContextRef          pubKey;         /* other party public key */
          
    BYTE                    Cs[KAPS_KEY_LEN];   /* Cached shared secret */
    BYTE                    Cs1[KAPS_KEY_LEN];  /* possible  next  shared secret */
    
    UInt32                  SAS ;                   /* Short Auth String  20 bits */

    BYTE                    KItoR[KAPS_KEY_LEN];    /* Key used for Initiator to Responder */
    BYTE                    KRtoI[KAPS_KEY_LEN];    /* Key used for Responder to Initiator */
    
    HASH_ContextRef         HtotalState;    /* hash context of KAPS packets */
    BYTE                    Hcs[8];         /* Hash commitment from other party */
    BYTE                    Hpki[8];        /* MAC of secret from other party */
    BYTE                    MACi[8];       /* MAC of Initiator  */
    BYTE                    MACr[8];       /* MAC of REsponder  */

};

 
/* Message Formats */
typedef struct  {
    BYTE    cookie[8];
    BYTE    msgType;
} KAPSMsgHdr;
 
typedef struct  {
    KAPSMsgHdr  hdr;
    BYTE        version;
    BYTE        pkAlg;
    BYTE        macAlg;
    BYTE        hashAlg;
    BYTE        sasMethod;
    BYTE        cipherAlg;
    BYTE        authTag;
    BYTE        Hpki[8];
    BYTE        Hcs[8];
} KAPSMsg_Commit;

 
static const char *kKAPSstr_Cookie = "KAPS MSG";
static const char *kKAPSstr_Initiator = "Initiator";
static const char *kKAPSstr_Responder = "Responder";

#pragma mark


static void B32encode(UInt32 in, char * out)
{
      int i, n, shift;
     
     for (i=0,shift=15; i!=4; ++i,shift-=5)
     {   n = (in>>shift) & 31;
         out[i] = "ybndrfg8ejkmcpqxot1uwisza345h769"[n];
     }
    out[i++] = '\0';
    
}
#pragma mark
/*____________________________________________________________________________
 validity test  
 ____________________________________________________________________________*/

static Boolean
scKAPSContextIsValid( const SCKAPSContext * ref)
{
	Boolean	valid	= FALSE;
	
	valid	= IsntNull( ref ) && ref->magic	 == kSCKAPSContextMagic;
	
	return( valid );
}

#define validateKAPSContext( s )		\
ValidateParam( scKAPSContextIsValid( s ) )

 static HASH_Algorithm sKAPStoWrapperHASH(KAPSHashAlgorithm algor)
{
    switch(algor)
    {
        case kKAPSHashAlgorithm_Skein512: return(kHASH_Algorithm_SKEIN512);
        case kKAPSHashAlgorithm_SHA512:     return(kHASH_Algorithm_SHA512);
        default: return kHASH_Algorithm_Invalid;
        
    }
}

static MAC_Algorithm sKAPStoWrapperMAC(KAPSMACAlgorithm algor)
{
    switch(algor)
    {
        case kKAPSMACAlgorithm_HMAC512: return(kMAC_Algorithm_HMAC);
        case kKAPSMACAlgorithm_Skein512:     return(kMAC_Algorithm_SKEIN);
        default: return kMAC_Algorithm_Invalid;
            
    }
}


/*____________________________________________________________________________
 Setup and Teardown 
 ____________________________________________________________________________*/


static void scInitKAPSContext(SCKAPSContext *ctx, Boolean isInitiator, char* me, char* you)
{
    ZERO(ctx, sizeof(SCKAPSContext));
    ctx->magic = kSCKAPSContextMagic;

    ctx->isInitiator = isInitiator;
    ctx->state = kKAPSstate_Init;
    
    if(!IsNull(me))
    {
        
        ctx->meStr = XMALLOC( strlen(me)+1 );
        strcpy(ctx->meStr, me);
    }
  
    if(!IsNull(you))
    {
        
        ctx->youStr = XMALLOC( strlen(you)+1 );
        strcpy(ctx->youStr, you);
    }

 }

static void scZeroKAPSContext(SCKAPSContext *ctx)
{
    if(ctx->meStr)
        XFREE(ctx->meStr);
    if(ctx->youStr)
        XFREE(ctx->youStr);
       
    ZERO(ctx, sizeof(SCKAPSContext));
    
}

static int sECCDH_Bits(KAPSPublicKeyAlgorithm pkAlg)
{
    int  ecc_size  = 0;
    
    switch( pkAlg )
    {
        case kKAPSPublicKeyAlgorithm_ECDH_P256: ecc_size = 256; break;
        case kKAPSPublicKeyAlgorithm_ECDH_P384: ecc_size = 384; break;
        default:
            break;
    }
    
    return ecc_size;
}


static int sMakeHash(KAPSHashAlgorithm algor, const unsigned char *in, unsigned long inlen, unsigned long outLen, BYTE *out)
{
    int             err         = CRYPT_OK;
    HASH_ContextRef hashRef     = kInvalidHASH_ContextRef;
 	BYTE            hashBuf[64];	
    BYTE            *p = (outLen < sizeof(hashBuf))?hashBuf:out;
       
    err = HASH_init( sKAPStoWrapperHASH(algor), & hashRef); CKERR;
    err = HASH_update( hashRef, in,  inlen); CKERR;
    err = HASH_final( hashRef, p); CKERR;
        
    if((err == CRYPT_OK) & (p!= out))
            COPY(hashBuf, out, outLen);
      
done:   
    if(!IsNull(hashRef)) 
        HASH_free(hashRef);

    return err;
}

static int sComputeSSmac(KAPSHashAlgorithm hashAlgor, 
                  KAPSMACAlgorithm  macAlgor,
                  BYTE *cs, 
                  BYTE* pk, int pkLen, 
                  const char *str, BYTE *out)
{
    int             err = CRYPT_OK;
    HASH_ContextRef hashRef     = kInvalidHASH_ContextRef;
    MAC_ContextRef  macRef      = kInvalidMAC_ContextRef;
    BYTE            hashBuf [64];	
    unsigned long   resultLen;
    
    err = HASH_init( sKAPStoWrapperHASH(hashAlgor), & hashRef); CKERR;
    err = HASH_update( hashRef,  pk,  pkLen); CKERR;
    err = HASH_update( hashRef,  str,  strlen(str)); CKERR;
    err = HASH_final( hashRef, hashBuf); CKERR;
     
    err = MAC_init( sKAPStoWrapperMAC(macAlgor), sKAPStoWrapperHASH(hashAlgor), cs, 64, &macRef); CKERR;
    err = MAC_update(macRef,  hashBuf,  sizeof(hashBuf));
    
   resultLen = 8;
    err = MAC_final( macRef, out, &resultLen); CKERR;

done:
    
    if(!IsNull(hashRef)) 
        HASH_free(hashRef);

    if(!IsNull(macRef)) 
        MAC_free(macRef);
    
    return err;
}



 
static BYTE* sMakeContextString(const char *initStr, const char* respStr, BYTE *hTotal, unsigned long *outLen)
{
    int len = 0;
    BYTE *contextStr = NULL;
    BYTE *p;
      
    len += (initStr?strlen(initStr):0) +1;
    len +=(respStr?strlen(respStr):0) +1;
    len += 64;
    p = contextStr = XMALLOC(len);
    
    *p++ = initStr?strlen(initStr):0 ;
    if(initStr)
    {  
        int len = strlen(initStr);
        memcpy(p, initStr, len);
        p+=len;
    }
 
    *p++ = respStr?strlen(respStr):0 ;
    if(respStr)
    {  
        int len = strlen(respStr);
        memcpy(p, respStr, len);
        p+=len;
    }

    memcpy(p, hTotal, 64);
    *outLen = p-contextStr+64;
    
    return contextStr;
}


static void  sComputeKDF(SCKAPSContext* ctx,
                        BYTE* K, char* label, 
                        BYTE*           context, 
                        unsigned long   contextLen, 
                        uint32_t        hashLen, 
                        unsigned long   outLen, 
                        BYTE            *out)
{
    MAC_ContextRef  macRef = kInvalidMAC_ContextRef;
    BYTE            L[4]; 
    unsigned long   resultLen = 0;
    
    L[0] = (hashLen >> 24) & 0xff;
    L[1] = (hashLen >> 16) & 0xff;
    L[2] = (hashLen >> 8) & 0xff;
    L[3] = hashLen & 0xff;
 
    MAC_init( sKAPStoWrapperMAC(ctx->macAlg), sKAPStoWrapperHASH(ctx->hashAlg), K, 64, &macRef);
    MAC_update(macRef,  "\x00\x00\x00\x01",  4);
    MAC_update(macRef,  label,  strlen(label));
    MAC_update(macRef,  "\x00",  1);
    MAC_update(macRef,  context, contextLen);
    MAC_update(macRef,  L,  4);
    
    resultLen = outLen;
    MAC_final( macRef, out, &resultLen);
    MAC_free(macRef);
  }

 static int  sComputeKeys(SCKAPSContext* ctx)
{
    int             err = CRYPT_OK;
    
 	BYTE            Kdk     [64];	
    BYTE            Kdk2    [64];	
    BYTE            hTotal  [64];
    BYTE            Z       [256];
    BYTE            Ksas    [3];	

    BYTE            *ctxStr = NULL;
    unsigned long   ctxStrLen = 0;
    
    unsigned long   x;
   
    hash_state      mac;

    static const char *kKAPSstr_MasterSecret = "MasterSecret";
    static const char *kKAPSstr_Enhance = "KAPS-ENHANCE";
  
    /*  Htotal = H(commit || DH1 || Pki )   */
    HASH_final( ctx->HtotalState, hTotal);
  
    /* Kdk = MAC(Htotal,Z)    where Z is the DH of Pki and PKr */
    x = sizeof(Z); 
    
    err = ECC_shared_secret(ctx->privKey, ctx->pubKey, Z, sizeof(Z), &x); CKERR;
    
    skein512MAC_init(&mac, hTotal, 64);
    skein512_process(&mac, Z, x);
    skein512_done(&mac, Kdk);
  
    ctxStr = sMakeContextString( ctx->isInitiator?ctx->meStr:ctx->youStr, 
                                !ctx->isInitiator?ctx->meStr:ctx->youStr, 
                                hTotal, 
                                &ctxStrLen);
    
    /* 
     Kdk2 =MAC(Kdk,0x00000001||“MasterSecret”||0x00
     ||"KAPS-ENHANCE"|| len(initID)InitID||len(respID)respID|| Htotal || len(cs)|| cs 
     ||0x00000200) 
     */
    skein512MAC_init(&mac, Kdk, 64);
    skein512_process(&mac, (BYTE*)"\x00\x00\x00\x01",  4);
    skein512_process(&mac, (BYTE*)kKAPSstr_MasterSecret,  strlen(kKAPSstr_MasterSecret)); 
    skein512_process(&mac, (BYTE*)"\x00",  1); 
    skein512_process(&mac, (BYTE*)kKAPSstr_Enhance,  strlen(kKAPSstr_Enhance));
    skein512_process(&mac, (BYTE*)ctxStr, ctxStrLen);
   
    if(ctx->hasCs && ctx->csMatches)
    {
        skein512_process(&mac, (BYTE*)"\x40",  1);
        skein512_process(&mac, ctx->Cs,  64 ) ;
    }
    else 
    {
        skein512_process(&mac, (BYTE*)"\x00",  1); 
    }
    skein512_process(&mac, (BYTE*) "\x00\x00\x02\x00",  4);
    skein512_done(&mac, Kdk2);
         
    sComputeKDF(ctx, Kdk2,"InitiatorMasterKey", ctxStr, ctxStrLen, 256, sizeof(ctx->KItoR), ctx->KItoR);  
    sComputeKDF(ctx, Kdk2,"ResponderMasterKey", ctxStr, ctxStrLen, 256, sizeof(ctx->KRtoI), ctx->KRtoI);  
    
    sComputeKDF(ctx, Kdk2,"InitiatorMACkey",    ctxStr, ctxStrLen, 512, sizeof(ctx->MACi), ctx->MACi);  
    sComputeKDF(ctx, Kdk2,"ResponderMACkey",    ctxStr, ctxStrLen, 512, sizeof(ctx->MACr), ctx->MACr);  
  
    sComputeKDF(ctx, Kdk2,"SAS",                ctxStr, ctxStrLen,  20, 3, Ksas);  
    ctx->SAS =  (Ksas[2] >> 4 & 0x0F) |((Ksas[1] << 4) & 0xFF0)  | ((Ksas[0] << 12) & 0xFF000);   
    
    /* rekey new cached secret */
    sComputeKDF(ctx, Kdk2,"RetainedSecret",     ctxStr, ctxStrLen, 512,  sizeof(ctx->Cs1), ctx->Cs1);  
    ctx->hasKeys = TRUE;
    
done:
    ZERO(Kdk, sizeof(Kdk));
    ZERO(Kdk2, sizeof(Kdk2));
    ZERO(hTotal, sizeof(hTotal));
    ZERO(Z, sizeof(Z)); 
        
    XFREE(ctxStr);
    
    return err;
    
}


int sCompleteKAPS(SCKAPSContext* ctx)
{
    int             err = CRYPT_OK;
    
    
    printf("\n\t%s Complete\n", ctx->isInitiator?kKAPSstr_Initiator:kKAPSstr_Responder);
     
    

    return err;
}

#pragma mark

/*____________________________________________________________________________
 Format Messages 
 ____________________________________________________________________________*/

static int sMakeKAPSmsg_Commit(SCKAPSContext *ctx, BYTE *out, size_t *outlen)
{
    int             err = CRYPT_OK;
    KAPSMsg_Commit *msg = (KAPSMsg_Commit*)out;
  
    BYTE            PK[128];
    unsigned long   PKlen = 0;
    
    validateKAPSContext(ctx);
    ValidateParam(*outlen >= sizeof(KAPSMsg_Commit));
    
    /* Make a new ECC key */
    err = ECC_generate(ctx->privKey, sECCDH_Bits( ctx->pkAlg) ); CKERR;
    
    /* get copy of public key */
    err = ECC_export(ctx->privKey, FALSE, PK, sizeof(PK), &PKlen); CKERR;
    
      ZERO(msg,sizeof(KAPSMsg_Commit));
    COPY(kKAPSstr_Cookie, &msg->hdr.cookie, 8);
    
    msg->hdr.msgType    = kKAPSMsg_Commit;
    msg->version        = kKapsProtocolVersion;
    msg->pkAlg          = ctx->pkAlg;
    msg->macAlg         = ctx->macAlg;
    msg->hashAlg        = ctx->hashAlg;   
    msg->sasMethod      = ctx->sasMethod;
    msg->cipherAlg      = ctx->cipherAlg;
    msg->authTag        = ctx->authTag;
 
    /* insert Hash of Initiators PK */
    sMakeHash(ctx->hashAlg, PK, PKlen, 8, msg->Hpki);

    /* insert Hash of initiators shared secret */
    sComputeSSmac(ctx->hashAlg, ctx->macAlg, ctx->Cs, PK, PKlen, kKAPSstr_Initiator, msg->Hcs);

    *outlen = sizeof(KAPSMsg_Commit);
       
    /* update Htotal */
    err = HASH_init( sKAPStoWrapperHASH(ctx->hashAlg), &ctx->HtotalState);  CKERR;
    HASH_update( ctx->HtotalState,  out,  *outlen);
       
done:
    return err;
}

static int sMakeKAPSmsg_DH1(SCKAPSContext* ctx, BYTE *out, size_t *outlen)
{
    int                 err = CRYPT_OK;
    KAPSMsgHdr         *msg = (KAPSMsgHdr*)out;
    unsigned long       PKlen = 256;
    BYTE                *PK = NULL; 
    BYTE                *HCS = NULL;;
    
    validateKAPSContext(ctx);
    ValidateParam(*outlen >= sizeof(KAPSMsgHdr) +111);

    ZERO(msg,sizeof(KAPSMsgHdr));
    COPY(kKAPSstr_Cookie, &msg->cookie, 8);
    
    msg->msgType = kKAPSMsg_DH1;
    
    /* insert copy of public key */
    PK = out +sizeof(KAPSMsgHdr);
    err = ECC_export(ctx->privKey, FALSE, PK, PKlen, &PKlen); CKERR;
      
    /* insert Hash of recipient's shared secret */
    HCS = PK + PKlen;
    sComputeSSmac(ctx->hashAlg, ctx->macAlg, ctx->Cs, PK, PKlen, kKAPSstr_Responder, HCS);
     
    *outlen = sizeof(KAPSMsgHdr) + PKlen + 8;
    
    /* update Htotal */
    HASH_update( ctx->HtotalState,  out,  *outlen);
 
done:
    return err;
}

static int sMakeKAPSmsg_DH2(SCKAPSContext* ctx, BYTE *out, size_t *outlen)
{
    int                 err = CRYPT_OK;
    KAPSMsgHdr          *msg = (KAPSMsgHdr*)out;
    unsigned long       PKlen = 256;
    BYTE                *PK = NULL; 
    BYTE                *MAC = NULL;;
    
    validateKAPSContext(ctx);
    ValidateParam(*outlen >= sizeof(KAPSMsgHdr) +111 +8);
    
    ZERO(msg,sizeof(KAPSMsgHdr));
    COPY(kKAPSstr_Cookie, &msg->cookie, 8);
      
    msg->msgType = kKAPSMsg_DH2;
    
    /* insert copy of public key */
    PK = out +sizeof(KAPSMsgHdr);
    err = ECC_export(ctx->privKey, FALSE, PK, PKlen, &PKlen); CKERR;
        
    /* update Htotal */
    HASH_update( ctx->HtotalState,  PK,  PKlen);
       
    sComputeKeys(ctx);
    
    /* insert MAC of recipient's shared secret */
    MAC = PK + PKlen;
    
    /* calculate MAC */
    COPY(ctx->MACi, MAC,8);
    
    *outlen = sizeof(KAPSMsgHdr) + PKlen + 8;

done:
    return err;
}


static int sMakeKAPSmsg_Confirm(SCKAPSContext* ctx, BYTE *out, size_t *outlen)
{
    int                 err = CRYPT_OK;
  
    KAPSMsgHdr        *msg =    (KAPSMsgHdr*)out;
    BYTE             *MAC = out +sizeof(KAPSMsgHdr);
    
    validateKAPSContext(ctx);
    ValidateParam(*outlen >= sizeof(KAPSMsgHdr) +8);
    
    ZERO(msg,sizeof(KAPSMsgHdr));
    COPY(kKAPSstr_Cookie, &msg->cookie, 8);
    
    msg->msgType = kKAPSMsg_Confirm;
    
     /* calculate MAC */
    COPY(ctx->MACr, MAC,8);
    
    *outlen = sizeof(KAPSMsgHdr) + 8;
    
    sCompleteKAPS(ctx);

done:
    return err;
}

#pragma mark

static int sProcessKAPSmsg_Commit(SCKAPSContext* ctx, BYTE *in, size_t inLen, BYTE * rsp, size_t *rspLen)
{
    int     err = CRYPT_OK;
    KAPSMsg_Commit  *msg = (KAPSMsg_Commit*)in;
   
    ValidateParam(inLen == sizeof(KAPSMsg_Commit));
      
    /* save parameters */
    ctx->version    = msg->version;
    ctx->pkAlg      = msg->pkAlg;
    ctx->macAlg     = msg->macAlg;
    ctx->hashAlg    = msg->hashAlg;   
    ctx->sasMethod  = msg->sasMethod;
    ctx->cipherAlg  = msg->cipherAlg;
    ctx->authTag    = msg->authTag;
    
    /* Save Hash of Shared secret */
    COPY(msg->Hcs, &ctx->Hcs, 8);
    
    /* Save Hash of initiator's PK  */
    COPY(msg->Hpki, &ctx->Hpki, 8);
  
    /* update Htotal */
    err = HASH_init( sKAPStoWrapperHASH(ctx->hashAlg), &ctx->HtotalState); CKERR;
    HASH_update( ctx->HtotalState,  in, inLen);

    /* create key to reply with */
    err = ECC_generate(ctx->privKey, sECCDH_Bits( ctx->pkAlg) ); CKERR;
     
    /* create reply DH1 */
    sMakeKAPSmsg_DH1(ctx, rsp, rspLen);
    
done:
    return err;
}

static int sProcessKAPSmsg_DH1(SCKAPSContextRef ctx, BYTE *in, size_t inLen, BYTE * rsp, size_t *rspLen)
{
    int             err = CRYPT_OK;

    unsigned long   PKlen = inLen - sizeof(KAPSMsgHdr) - 8;
    BYTE            *PK = in +sizeof(KAPSMsgHdr); 
    BYTE            *HCS = NULL;;
    
    BYTE            HCS1[8];
    size_t          keySize;
    
    ValidateParam(inLen >= sizeof(KAPSMsgHdr) +78 +8);
    ValidateParam(inLen <= sizeof(KAPSMsgHdr) +111 +8);
    
    /* update Htotal */
    HASH_update( ctx->HtotalState,  in, inLen);

    /* save public key */
    err = ECC_import(ctx->pubKey,PK, PKlen); CKERR;
   
    /* check public key for validity */
     err = ECC_keysize(ctx->pubKey, &keySize); CKERR;
                
    if( sECCDH_Bits( ctx->pkAlg)  != keySize)
        err = CRYPT_INVALID_PACKET; CKERR;
    
    /* check secret commitment */
    HCS = PK + PKlen;
    
    /* insert Hash of initiators shared secret */
    sComputeSSmac(ctx->hashAlg, ctx->macAlg, ctx->Cs, PK, PKlen, kKAPSstr_Responder, HCS1);
    
    ctx->csMatches = CMP(HCS, HCS1, 8);
    
    sMakeKAPSmsg_DH2(ctx, rsp, rspLen);

done:
    return err;
}

static int sProcessKAPSmsg_DH2(SCKAPSContextRef ctx, BYTE *in, size_t inLen, BYTE * rsp, size_t *rspLen)
{
    int             err = CRYPT_OK;
    unsigned long   PKlen = inLen - sizeof(KAPSMsgHdr) - 8;
    BYTE            *PK = in +sizeof(KAPSMsgHdr); 
    BYTE            *MAC = NULL;;
    BYTE            HPKi[8];
    BYTE            HCS1[8];
    size_t          keySize;  

    ValidateParam(inLen >= sizeof(KAPSMsgHdr) +78 +8);
    ValidateParam(inLen <= sizeof(KAPSMsgHdr) +111 +8);
 
    /* save public key */
    err = ECC_import(ctx->pubKey,PK, PKlen); CKERR;
    MAC = PK + PKlen;
    
    /* check public key for validity */
    err = ECC_keysize(ctx->pubKey, &keySize); CKERR;
    if( sECCDH_Bits( ctx->pkAlg)  != keySize)
        err = CRYPT_INVALID_PACKET; CKERR;
    
    /* create Hash of Initiators PK */
      sMakeHash(ctx->hashAlg, PK, PKlen, 8, HPKi);
        
    /* check PKI hash */
      if(!CMP(ctx->Hpki, HPKi, 8))
        RETERR(CRYPT_INVALID_PACKET);
      
    /* check Hash of initiators shared secret */
    sComputeSSmac(ctx->hashAlg, ctx->macAlg, ctx->Cs, PK, PKlen, kKAPSstr_Initiator, HCS1);
 
    ctx->csMatches = CMP(ctx->Hcs, HCS1, 8);
    
   /* update Htotal */
    
    HASH_update( ctx->HtotalState,  PK, PKlen);
    sComputeKeys(ctx);
    
    /* check if Initiator's confirmation code matches */ 
    if(!CMP(ctx->MACi, MAC, 8))
        RETERR(CRYPT_PK_TYPE_MISMATCH);
      
    sMakeKAPSmsg_Confirm(ctx, rsp, rspLen);

done:
    return err;
}

static int sProcessKAPSmsg_Confirm(SCKAPSContextRef ctx, BYTE *in, size_t inLen)
{
    int             err = CRYPT_OK;
    
    BYTE           *MAC = in +sizeof(KAPSMsgHdr);
  
    /* check if Responder's confirmation code matches */ 
    if(!CMP(ctx->MACr, MAC, 8))
        RETERR(CRYPT_PK_TYPE_MISMATCH);
    
    sCompleteKAPS(ctx);
 
done:
    return err;
}



#pragma mark

int sProcessKAPSmsg(SCKAPSContextRef ctx, BYTE* in, size_t inLen, BYTE * rsp, size_t *rspLen)
{
    int err = CRYPT_OK;
    
     KAPSMsgHdr *msg = (KAPSMsgHdr*)in;
   
    validateKAPSContext(ctx);
    
    ValidateParam(inLen> sizeof(KAPSMsgHdr));
   
    if( !CMP(msg->cookie, kKAPSstr_Cookie, 8)) 
        return(CRYPT_INVALID_PACKET);
      
    switch(msg->msgType)
    {
        case kKAPSMsg_Commit:
            err = sProcessKAPSmsg_Commit(ctx, in, inLen, rsp, rspLen);
            break;
            
        case kKAPSMsg_DH1:
            err = sProcessKAPSmsg_DH1(ctx, in, inLen, rsp, rspLen);
            break;
            
        case kKAPSMsg_DH2:
            err = sProcessKAPSmsg_DH2(ctx, in, inLen, rsp, rspLen);
            break;
            
        case kKAPSMsg_Confirm:
            err = sProcessKAPSmsg_Confirm(ctx, in, inLen);
            rspLen = 0;
            break;
            
        default:
            return(CRYPT_INVALID_PACKET);
    }
 
done:
    return err;
}


#pragma mark
/*____________________________________________________________________________
Public Functions
 ____________________________________________________________________________*/

#if 0
 
 typedef enum _PGPskepEventType
 {
 kPGPskepEvent_NullEvent			= 0,	/*!< Nothing is happening */
kPGPskepEvent_ListenEvent		= 1,	/*!< Listening for data */
kPGPskepEvent_ConnectEvent		= 2,	/*!< Connection established */
kPGPskepEvent_AuthenticateEvent = 3,	/*!< Remote site authenticated */
kPGPskepEvent_ProgressEvent		= 4,	/*!< Data flow progress */
kPGPskepEvent_CloseEvent		= 5,	/*!< Connection closing */
kPGPskepEvent_ShareEvent		= 6,	/*!< Share received */
kPGPskepEvent_PassphraseEvent	= 7		/*!< Passphrase needed */
} PGPskepEventType;

 
 typedef union _PGPskepEventData
 {
 PGPskepEventAuthenticateData	ad;
 PGPskepEventProgressData		pd;
 PGPskepEventShareData			sd;
 PGPskepEventPassphraseData		ppd;
 } PGPskepEventData;
 
 typedef struct _PGPskepEvent
 {
 PGPskepEventType	type;
 PGPskepEventData	data;
 } PGPskepEvent;
 
 
 typedef PGPError (*PGPskepEventHandler)(PGPskepRef skep,
                                        PGPskepEvent *event, PGPUserValue userValue);

#endif




    int 
SCNewKAPS(
      Boolean                   isInitiator, 
      char*                     initiatorStr, 
      char*                     responderStr,
       SCKAPSContextRef *       outKaps 
      )
{
    int                 err = CRYPT_OK;
    
    SCKAPSContext*      kaps = NULL;
    
    ValidateParam(outKaps);
    ValidateParam(initiatorStr);
    ValidateParam(responderStr);
    
    kaps = XMALLOC(sizeof (SCKAPSContext)); CKNULL(kaps);
   
    ZERO(kaps, sizeof(SCKAPSContext));
    kaps->magic = kSCKAPSContextMagic;
    
    kaps->isInitiator   = isInitiator;
    kaps->state         = kKAPSstate_Init;
    
    err = ECC_init(&kaps->privKey); CKERR;
    err = ECC_init(&kaps->pubKey); CKERR;
    
    kaps->meStr = XMALLOC( strlen(initiatorStr)+1 );
    strcpy(kaps->meStr, initiatorStr);
    
    kaps->youStr = XMALLOC( strlen(responderStr)+1 );
    strcpy(kaps->youStr, responderStr);
    
    /* set default values */
    kaps->pkAlg     = kKAPSPublicKeyAlgorithm_ECDH_P384;
    kaps->macAlg    = kKAPSMACAlgorithm_HMAC512;
    kaps->hashAlg   = kKAPSHashAlgorithm_SHA512;
    kaps->sasMethod = kKAPSSAS_ZJC11;
    kaps->cipherAlg = kKAPSCipherAlgorithm_AES256;
    kaps->authTag   = kKAPSAuthTag_OMAC32;
    
    *outKaps = kaps; 
    
done:
    return err;
}



int SCkapsSetEventHandler(SCKAPSContextRef kaps
// PGPskepEventHandler handler, PGPUserValue userValue);
                          )
{
    int err = CRYPT_OK;
   
    validateKAPSContext(kaps);
    
done:
    return err;
   
}


int SCGetKapsInfo( SCKAPSContextRef kaps, KAPSInfo* info)
{
    int                 err = CRYPT_OK;
   
   validateKAPSContext(kaps);
   ValidateParam(info);
  
    info->version   = kaps->version;
    info->pkAlg     = kaps->pkAlg;
    info->macAlg    = kaps->macAlg;
    info->hashAlg   = kaps->hashAlg;
    info->sasMethod = kaps->sasMethod;
    info->cipherAlg = kaps->cipherAlg;
    info->authTag   = kaps->authTag;
    
    info->isInitiator   = kaps->isInitiator;
    info->hasCs         = kaps->hasCs;
    info->csMatches     = kaps->csMatches;
       
done:
    return err;
  
}
 
static int sGetKAPSDataPropertyInternal( SCKAPSContextRef kaps,
                          KAPSProperty whichProperty, 
                          void *outData, size_t bufSize, size_t *datSize, Boolean doAlloc,
                                        BYTE** allocBuffer)
{
    int                err = CRYPT_OK;
  
    size_t             actualLength = 0;
    void              *buffer = NULL;
    
    *datSize = 0;
    
    switch(whichProperty)
    {
        case kKAPSProperty_SharedSecret:
            actualLength = 64;
            break;
            
        case kKAPSProperty_NextSecret:
            if(!kaps->hasKeys) 
                    RETERR(CRYPT_PK_NOT_PRIVATE);
            actualLength = 64;
            break;
            
        case kKAPSProperty_SASstring:
            switch(kaps->sasMethod)
            {
                case kKAPSSAS_ZJC11:
                    actualLength = 5;
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
        case kKAPSProperty_SharedSecret:
            COPY(kaps->Cs,  buffer, actualLength);
            break;
            
        case kKAPSProperty_NextSecret:
            COPY(kaps->Cs1,  buffer, actualLength);
           break;

        default:
            break;
    }
    
    *datSize = actualLength;
    
    
done:
    return err;

}

int SCGetKAPSDataProperty( SCKAPSContextRef kaps,
                          KAPSProperty whichProperty, 
                          void *outData, size_t bufSize, size_t *datSize)
{
    int                 err = CRYPT_OK;
     
    validateKAPSContext(kaps);
    ValidateParam(outData);
    ValidateParam(datSize);
    
    if ( IsntNull( outData ) )
	{
		ZERO( outData, bufSize );
	}

   err =  sGetKAPSDataPropertyInternal(kaps, whichProperty, outData, bufSize, datSize, FALSE, NULL);
 
done:
    return err;

}

int SCGetKAPSAllocatedDataProperty( SCKAPSContextRef kaps,
                          KAPSProperty whichProperty, 
                          void **outData, size_t *datSize)
{
    int                 err = CRYPT_OK;
    
    validateKAPSContext(kaps);
    ValidateParam(outData);
    ValidateParam(datSize);
    
     err =  sGetKAPSDataPropertyInternal(kaps, whichProperty, NULL, 0, datSize, TRUE, (BYTE**) outData);
    
done:
    return err;
    
}


int SCSetKAPSDataProperty( SCKAPSContextRef kaps,
                          KAPSProperty whichProperty, 
                          void *data,  size_t  datSize)
{
    int                 err = CRYPT_OK;
    
    validateKAPSContext(kaps);
    ValidateParam(data);
     
    switch(whichProperty)
    {
        case kKAPSProperty_SharedSecret:
            ZERO(kaps->Cs, KAPS_KEY_LEN);
            COPY(data, kaps->Cs, datSize> KAPS_KEY_LEN?KAPS_KEY_LEN:datSize);
            kaps->hasCs = TRUE;
            break;
            
              
        default:
            RETERR(CRYPT_INVALID_ARG);
    }
     
done:
    return err;
    
}


int SCGetKAPSNumericProperty( SCKAPSContextRef kaps,
                             KAPSProperty whichProperty, 
                             UInt32 *prop)
{
    int                 err = CRYPT_OK;
    
    validateKAPSContext(kaps);
    ValidateParam(prop);
    
    switch(whichProperty)
    {
        case kKAPSProperty_PublicKeyAlgorithm:
            *prop = kaps->pkAlg;
            break;
            
        case kKAPSProperty_MACAlgorithm:
            *prop = kaps->macAlg;
           break;
            
        case kKAPSProperty_HASHAlgorithm:
            *prop = kaps->hashAlg;
            break;
            
        case kKAPSProperty_CipherAlgorithm:
            *prop = kaps->cipherAlg;
           break;
            
        case kKAPSProperty_SASMethod:
            *prop = kaps->sasMethod;
            break;
            
        case kKAPSProperty_AuthTagMethod:
            *prop = kaps->authTag;
          break;
            
            
        default:
            RETERR(CRYPT_INVALID_ARG);
    }
    
done:
    return err;
    
}

int SCSetKAPSNumericProperty( SCKAPSContextRef kaps,
                             KAPSProperty whichProperty, 
                             UInt32 prop)
{
    int                 err = CRYPT_OK;
    
    validateKAPSContext(kaps);
     
    switch(whichProperty)
    {
        case kKAPSProperty_PublicKeyAlgorithm:
            kaps->pkAlg = prop;
            break;
            
        case kKAPSProperty_MACAlgorithm:
            kaps->macAlg = prop;
           break;
            
        case kKAPSProperty_HASHAlgorithm:
            kaps->hashAlg = prop;
            break;
            
        case kKAPSProperty_CipherAlgorithm:
            kaps->cipherAlg = prop;
            break;
            
        case kKAPSProperty_SASMethod:
            kaps->sasMethod = prop;
            break;
            
        case kKAPSProperty_AuthTagMethod:
            kaps->authTag = prop;
           break;
  
            
        default:
            RETERR(CRYPT_INVALID_ARG);
    }
    
done:
    return err;
    
}



void SCFreeKAPS(SCKAPSContextRef kaps)
{
       
    if(scKAPSContextIsValid(kaps))
    {
        
        if(kaps->privKey)
           ECC_free(kaps->privKey); 
        if(kaps->pubKey)
            ECC_free(kaps->pubKey); 
        if(kaps->meStr)
            XFREE(kaps->meStr);
        if(kaps->youStr)
            XFREE(kaps->youStr);
        
        ZERO(kaps, sizeof(SCKAPSContext));
        XFREE(kaps);
    }

 
}



#pragma mark


#if DEBUG_KAPS /*[*/
/*____________________________________________________________________________
 Debug    
 ____________________________________________________________________________*/


static void displaySAS(UInt32 sas, KAPSsas method  )
{
      switch(method)
    {
        case kKAPSSAS_ZJC11:
        {
            char SASstr[6];
            B32encode(sas, SASstr);
            printf("\tSAS: %0000X \'%s\'\n", sas, SASstr);
            
        }
            break;
            
        case kKAPSSAS_NATO:
            
            printf("\tSAS: %0X\n", sas);
            
            break;
            
        default:;
    }
}


static void sDumpECCkey(ecc_key *k, char* str)
{
    BYTE            PKbuf[128];
    unsigned long   PKbufLen = 128;
    
    PKbufLen = sizeof(PKbuf);
    DO( ecc_export(PKbuf, &PKbufLen, PK_PUBLIC, k));
    
    printf("\t%s P-%d (%ld bytes)\n", str, k->dp->size *8 , PKbufLen);
    dumpHex(PKbuf,  PKbufLen, 8);
    printf("\n");
    
}


static char* sKAPS_Message_STR(int msgType)
{
    
    
    switch(msgType)
    {
        case kKAPSMsg_Commit:
            return("Commit");
            
        case kKAPSMsg_DH1:
            return("DH1");
            
        case kKAPSMsg_DH2:
            return("DH2");
            
        case kKAPSMsg_Confirm:
            return("Confirm");
            
        default:
            return("Invalid");
    }
    
    return("Invalid");
    
}


static void dumpKAPSmsg(BYTE* in, size_t inLen)
{
    KAPSMsgHdr *msg = (KAPSMsgHdr*)in;
    
    printf("%s Msg, %d Bytes\n",
           sKAPS_Message_STR(msg->msgType),  (int)inLen);

    printf("%10s: %.*s\n","Tag", 8, msg->cookie);
    printf("%10s: %s\n","Type", sKAPS_Message_STR(msg->msgType) );
    
    switch(msg->msgType)
    {
        case kKAPSMsg_Commit:
        {
            KAPSMsg_Commit* c =  (KAPSMsg_Commit*)in;
            printf("%10s: 0x%02x\n","Version", c->version);
            printf("%10s: %02x\n","Key", c->pkAlg);
            printf("%10s: %02x\n","MAC", c->macAlg);
            printf("%10s: %02x\n","Hash", c->hashAlg);
            printf("%10s: %02x\n","SAS", c->sasMethod);
            printf("%10s: %02x\n","Cipher", c->cipherAlg);
            printf("%10s: %02x\n","Auth", c->authTag);
            printf("%10s: ","H(Pki)"); dumpHex8(c->Hpki); printf("\n");         
            printf("%10s: ","H(cs)"); dumpHex8(c->Hcs); printf("\n");         
        }
            break;
            
        case kKAPSMsg_DH1:
        {
            unsigned long   PKlen = inLen - sizeof(KAPSMsgHdr) - 8;
            printf("%10s: %d Bytes\n","Pkr", (int)PKlen);
            //           dumpHex(in + sizeof(KAPSMsgHdr), PKlen,12);
            printf("%10s: ","H(cs)"); dumpHex8( in + sizeof(KAPSMsgHdr) +PKlen); printf("\n");         
            
        }
            break;
            
        case kKAPSMsg_DH2:
        {
            unsigned long   PKlen = inLen - sizeof(KAPSMsgHdr) - 8;
            printf("%10s: %d Bytes\n","Pki", (int)PKlen);
            //           dumpHex(in + sizeof(KAPSMsgHdr), PKlen,12);
            printf("%10s: ","MAC"); dumpHex8( in + sizeof(KAPSMsgHdr) +PKlen); printf("\n");         
            
        }
            break;
            
        case kKAPSMsg_Confirm:
        {
            printf("%10s: ","MAC"); dumpHex8( in + sizeof(KAPSMsgHdr)); printf("\n");         
            
        }
            break;
            
        default:
            break;
    }
    
    printf("\n");
}

/*____________________________________________________________________________
 Testing 
 ____________________________________________________________________________*/

int TestSCIP()
{
    int err = CRYPT_OK;

    SCKAPSContextRef   kapsI = NULL;
    SCKAPSContextRef   kapsR = NULL;
  
    char        *bobStr     = "bob@silentcircle.com";
    char        *aliceStr   = "alice@silentcircle.com";
    
    BYTE        secret[64];
    
    BYTE        secretI[64];
    BYTE        *secretR = NULL;;
      
    KAPSInfo    info;
    
    BYTE        msg[256];
    size_t      msgLenIn = 0;
    size_t      msgLenOut = 0;
    size_t       dataLen = 0;
    
    register_hash (&sha512_desc);
    register_hash (&skein512_desc);
    register_cipher (&aes_desc);
 
#define USE_SKEIN 1
    
    printf("\nKAPS test \n");
    
    printf("\tSetup KAPS context \n\n");
  /* Setup Initiator */  
    err = SCNewKAPS(TRUE, 
                    bobStr, 
                    aliceStr,
                    &kapsI); CKERR;
 
    
#if USE_SKEIN
    err = SCSetKAPSNumericProperty(kapsI, kKAPSProperty_MACAlgorithm, kKAPSMACAlgorithm_Skein512); CKERR;
    err = SCSetKAPSNumericProperty(kapsI, kKAPSProperty_HASHAlgorithm, kKAPSHashAlgorithm_Skein512); CKERR;
#endif
 
    /* Setup Responder */  
    err = SCNewKAPS(FALSE, 
                    aliceStr, 
                    bobStr,
                     &kapsR);CKERR;
  
    /* Fill Initiator shared secret with random number */
    sprng_read(secret,sizeof(secret),NULL);
    
    err = SCSetKAPSDataProperty(kapsI, kKAPSProperty_SharedSecret,  secret, sizeof(secret));

 //   secret[0] = secret[0]+1;
    err = SCSetKAPSDataProperty(kapsR, kKAPSProperty_SharedSecret,  secret, sizeof(secret));
   
#if 1
     msgLenIn = sizeof(msg);
    sMakeKAPSmsg_Commit(kapsI, msg, &msgLenIn);
  
    msgLenOut = sizeof(msg);
    dumpKAPSmsg(msg, msgLenIn);
    DO(sProcessKAPSmsg(kapsR, msg, msgLenIn, msg, &msgLenOut));
    
    msgLenIn = msgLenOut; 
    msgLenOut = sizeof(msg);
    dumpKAPSmsg(msg, msgLenIn);
    DO(sProcessKAPSmsg(kapsI, msg, msgLenIn, msg, &msgLenOut));
    
    msgLenIn = msgLenOut; 
    msgLenOut = sizeof(msg);
    dumpKAPSmsg(msg, msgLenIn);
    DO(sProcessKAPSmsg(kapsR, msg, msgLenIn, msg, &msgLenOut));
    
    msgLenIn = msgLenOut; 
    msgLenOut = sizeof(msg);
    dumpKAPSmsg(msg, msgLenIn);
   DO(sProcessKAPSmsg(kapsI, msg, msgLenIn, msg, &msgLenOut));
#endif
    
    err = SCGetKAPSDataProperty(kapsI,kKAPSProperty_NextSecret, secretI, sizeof(secretI), &dataLen); CKERR;
    err = SCGetKAPSAllocatedDataProperty(kapsR, kKAPSProperty_NextSecret, (void*) &secretR, &dataLen); CKERR;
     printf("\nNew Cached Secret %s match\n" , CMP(secretI, secretR, sizeof(secretR))?"DO":"DONT");
    
    err = SCGetKapsInfo(kapsR, &info); CKERR;
   
    printf("Responder Info\n");
    printf("%10s: %02x\n","Version", info.version);
    printf("%10s: %02x\n","Key", info.pkAlg);
    printf("%10s: %02x\n","MAC", info.macAlg);
    printf("%10s: %02x\n","Hash", info.hashAlg);
    printf("%10s: %02x\n","SAS", info.sasMethod);
    printf("%10s: %02x\n","Cipher", info.cipherAlg);
    printf("%10s: %02x\n","Auth", info.authTag);
    printf("%10s: %s\n","CS Matches", info.csMatches?"TRUE":"FALSE");
     
#if 0    
    
    displaySAS(CTXi.SAS, CTXi.sasMethod);
    
    // NOTE: dont save cached secret unless csMatches is set */

#endif
    
    
    printf("KAPS test OK \n");

done:
    if(err != CRYPT_OK)
        printf("\tERROR %d - %s\n", err, error_to_string(err)); 
        
    if(IsntNull(secretR))
        XFREE(secretR);
       
    if(IsntNull(kapsI))
        SCFreeKAPS(kapsI);
    
    if(IsntNull(kapsR))
        SCFreeKAPS(kapsR);
      
    printf("\tKAPS test Complete \n");

    return err;
}

#endif  /* DEBUG_KAPS ]*/


