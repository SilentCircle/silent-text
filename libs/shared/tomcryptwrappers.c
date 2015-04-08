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
#include "SCpubTypes.h"
#include "cryptowrappers.h"

#define CKSTAT {if (status != CRYPT_OK)  goto done; }

typedef struct {
    int 		code;
    SCLError     err;
    const char *msg;
} error_map_entry;

static const error_map_entry error_map_table[] = 
{
    { CRYPT_OK,     		kSCLError_NoErr,         "Successful" },
    { CRYPT_ERROR,  		kSCLError_UnknownError,  "Generic Error" },
    { CRYPT_NOP,    		kSCLError_NOP,         	"Non-fatal 'no-operation' requested."},
    { CRYPT_INVALID_ARG, 	kSCLError_BadParams,    	"Invalid argument provided."},
    
    
    { CRYPT_MEM,  			 kSCLError_OutOfMemory,          "Out of memory"},
    { CRYPT_BUFFER_OVERFLOW, kSCLError_BufferTooSmall,       "Not enough space for output"},
    
    { -1, 					kSCLError_UserAbort,             "User Abort"},
    { -1, 					kSCLError_UnknownRequest,        "Unknown Request"},
    { -1,					kSCLError_LazyProgrammer,        "Feature incomplete"},
    
    { -1,                     	kSCLError_FeatureNotAvailable,  "Feature not available" },
    { -1,                       kSCLError_ResourceUnavailable,  "Resource not available" },
    { -1,                       kSCLError_NotConnected,         "Not connected" },
    { -1,                       kSCLError_ImproperInitialization,  "Not Initialized" },
    { CRYPT_INVALID_PACKET,     kSCLError_CorruptData,           "Corrupt Data" },
    { CRYPT_FAIL_TESTVECTOR,    kSCLError_SelfTestFailed,        "Self Test Failed" },
    { -1, 						kSCLError_BadIntegrity,  		"Bad Integrity" },
    { CRYPT_INVALID_HASH, 		kSCLError_BadHashNumber,         "Invalid hash specified" },
    { CRYPT_INVALID_CIPHER, 	kSCLError_BadCipherNumber,       "Invalid cipher specified" },
    { CRYPT_INVALID_PRNG, 		kSCLError_BadPRNGNumber,  		"Invalid PRNG specified" },
    { -1            ,           kSCLError_SecretsMismatch,       "Shared Secret Mismatch" },
    { -1            ,           kSCLError_KeyNotFound,           "Key Not Found" },
    { -1            ,           kSCLError_ProtocolError,        "Protocol Error" },
    { -1            ,           kSCLError_ProtocolContention,        "Protocol Contention" },
    
    
    
};


typedef struct HASH_Context    HASH_Context;

 struct HASH_Context 
{
    #define kHASH_ContextMagic		0x48415348  
	uint32_t                magic;
    HASH_Algorithm          algor;
    hash_state              state; 
};


/*____________________________________________________________________________
 validity test  
 ____________________________________________________________________________*/

static bool
sHASH_ContextIsValid( const HASH_ContextRef  ref)
{
	bool	valid	= false;
	
	valid	= IsntNull( ref ) && ref->magic	 == kHASH_ContextMagic;
	
	return( valid );
}

#define validateHASHContext( s )		\
ValidateParam( sHASH_ContextIsValid( s ) )


#define ERROR_MAP_TABLE_SIZE (sizeof(error_map_table) / sizeof(error_map_entry))

SCLError sCrypt2SCLError(int t_err)
{
    int i;
    
    for(i = 0; i< ERROR_MAP_TABLE_SIZE; i++)
        if(error_map_table[i].code == t_err) return(error_map_table[i].err);
    
    return kSCLError_UnknownError;
 }


SCLError  SCLGetErrorString( SCLError err,  size_t	bufSize, char *outString)
 {
    int i;
     *outString = 0;
     
    for(i = 0; i< ERROR_MAP_TABLE_SIZE; i++)
        if(error_map_table[i].err == err)
         {
            if(strlen(error_map_table[i].msg) +1 > bufSize)
                return (kSCLError_BufferTooSmall);
             strcpy(outString, error_map_table[i].msg);
             return kSCLError_NoErr;
           }
    
    return kSCLError_UnknownError;
}

const struct ltc_hash_descriptor* sDescriptorForHash(HASH_Algorithm algorithm)
{
    const struct ltc_hash_descriptor* desc = NULL;
    
    switch(algorithm)
    {
        case  kHASH_Algorithm_MD5:
            desc = &md5_desc;
            break;
 
        case  kHASH_Algorithm_SHA1:
            desc = &sha1_desc;
            break;
 
        case  kHASH_Algorithm_SHA224:
            desc = &sha224_desc;
            break;
 
        case  kHASH_Algorithm_SHA256:
            desc = &sha256_desc;
            break;
             
        case  kHASH_Algorithm_SHA384:
            desc = &sha384_desc;
            break;
 
        case  kHASH_Algorithm_SHA512_256:
            desc = &sha512_256_desc;
            break;
  
        case  kHASH_Algorithm_SHA512:
            desc = &sha512_desc;
            break;
            
        case  kHASH_Algorithm_SKEIN256:
            desc = &skein256_desc;
            break;
 
        case  kHASH_Algorithm_SKEIN512:
            desc = &skein512_desc;
            break;

       case  kHASH_Algorithm_SKEIN1024:
            desc = &skein1024_desc;
           break;
 
            // want more... put more descriptors here,
        default:
            break;
           
    }
 
    return desc;
}

SCLError HASH_Import(void *inData, size_t bufSize, HASH_ContextRef * ctx)
{
    int             err = kSCLError_NoErr;
    HASH_Context*   hashCTX = NULL;
 
    ValidateParam(ctx);
    *ctx = NULL;
    
    
    if(sizeof(HASH_Context) != bufSize)
        RETERR( kSCLError_BadParams);
    
    hashCTX = XMALLOC(sizeof (HASH_Context)); CKNULL(hashCTX);
  
    COPY( inData, hashCTX, sizeof(HASH_Context));
    
    validateHASHContext(hashCTX);
    
    *ctx = hashCTX;
  
done:
      
    if(IsSCLError(err))
    {
        if(IsntNull(hashCTX))
        {
            XFREE(hashCTX);
        }
    }
    
    return err;
}

SCLError HASH_Export(HASH_ContextRef ctx, void *outData, size_t bufSize, size_t *datSize)
{
    int             err = kSCLError_NoErr;
    const struct    ltc_hash_descriptor* desc = NULL;
    
    validateHASHContext(ctx);
    ValidateParam(outData);
    ValidateParam(datSize);
    
    desc = sDescriptorForHash(ctx->algor);
    
    if(IsNull(desc))
        RETERR( kSCLError_BadHashNumber);
 
    if(sizeof(HASH_Context) > bufSize)
        RETERR( kSCLError_BufferTooSmall);
         
    COPY( ctx, outData, sizeof(HASH_Context));
    
    *datSize = sizeof(HASH_Context);
    
done:
    
    return err;

}



SCLError HASH_Init(HASH_Algorithm algorithm, HASH_ContextRef * ctx)
{
    int             err = kSCLError_NoErr;
    HASH_Context*   hashCTX = NULL;
    const struct ltc_hash_descriptor* desc = NULL;
   
    ValidateParam(ctx);
    *ctx = NULL;
    
    hashCTX = XMALLOC(sizeof (HASH_Context)); CKNULL(hashCTX);
  
    hashCTX->magic = kHASH_ContextMagic;
    hashCTX->algor = algorithm;

    desc = sDescriptorForHash(algorithm);
    
    if(IsNull(desc))
       RETERR( kSCLError_BadHashNumber); 
       
    if(desc->init) 
        err = (desc->init)(&hashCTX->state); 
    CKERR;
         
    *ctx = hashCTX;
    
done:
  
    
    if(IsSCLError(err))
    {
        if(IsntNull(hashCTX))
        {
            XFREE(hashCTX);
        }
    }

    return err;

}

SCLError HASH_Update(HASH_ContextRef ctx, const void *data, size_t dataLength)
{
    int             err = kSCLError_NoErr;
    const struct    ltc_hash_descriptor* desc = NULL;
    
    validateHASHContext(ctx);
    ValidateParam(data);
    
    desc = sDescriptorForHash(ctx->algor);
    
    if(IsNull(desc))
        RETERR( kSCLError_BadHashNumber); 
    
    if(desc->process) 
        err = (desc->process)(&ctx->state,data,  dataLength ); 
    CKERR;
  
done:
    
    return err;

}
 


SCLError HASH_Final(HASH_ContextRef  ctx, void *hashOut)
{
    int             err = kSCLError_NoErr;
    const struct    ltc_hash_descriptor* desc = NULL;
    
    validateHASHContext(ctx);
     
    desc = sDescriptorForHash(ctx->algor);
    
    if(IsNull(desc))
        RETERR( kSCLError_BadHashNumber); 
    
    if(desc->done) 
        err = (desc->done)(&ctx->state, hashOut ); 
    CKERR;
        
done:
     
    return err;
 }

void HASH_Free(HASH_ContextRef  ctx)
{
    if(sHASH_ContextIsValid(ctx))
    {
        ZERO(ctx, sizeof(HASH_Context));
        XFREE(ctx);
     }
 }

SCLError HASH_GetSize(HASH_ContextRef  ctx, size_t *hashSize)
{
    int             err = kSCLError_NoErr;

    const struct    ltc_hash_descriptor* desc = NULL;
    
    validateHASHContext(ctx);
    
    desc = sDescriptorForHash(ctx->algor);
    
    if(IsNull(desc))
        RETERR( kSCLError_BadHashNumber); 

    *hashSize = desc->hashsize;
done:
        
    return err;
}


#pragma mark

typedef struct MAC_Context    MAC_Context;

struct MAC_Context 
{
#define kMAC_ContextMagic		0x4D414320   
	uint32_t                magic;
    MAC_Algorithm           macAlgor;
    size_t                  hashsize;
    
    union 
    {
        hmac_state              hmac; 
        skeinmac_state          skeinmac;
    }state;
    
    int (*process)(void *ctx, const unsigned char *in, unsigned long inlen);
 
    int (*done)(void *ctx, unsigned char *out, unsigned long *outlen);

 };


/*____________________________________________________________________________
 validity test  
 ____________________________________________________________________________*/

static bool
sMAC_ContextIsValid( const MAC_ContextRef  ref)
{
	bool	valid	= false;
	
	valid	= IsntNull( ref ) && ref->magic	 == kMAC_ContextMagic;
	
	return( valid );
}

#define validateMACContext( s )		\
ValidateParam( sMAC_ContextIsValid( s ) )




SCLError MAC_Init(MAC_Algorithm mac, HASH_Algorithm hash, const void *macKey, size_t macKeyLen, MAC_ContextRef * ctx)
{
    int             err = kSCLError_NoErr;
    const struct    ltc_hash_descriptor* hashDesc = NULL;
    MAC_Context*   macCTX = NULL;
   
    ValidateParam(ctx);
    *ctx = NULL;
    
    hashDesc = sDescriptorForHash(hash);
    
    if(IsNull(hashDesc))
        RETERR( kSCLError_BadHashNumber);
    
     
    macCTX = XMALLOC(sizeof (MAC_Context)); CKNULL(macCTX);
    
    macCTX->magic = kMAC_ContextMagic;
    macCTX->macAlgor = mac;
   
    switch(mac)
    {
        case  kMAC_Algorithm_HMAC:
            err = hmac_init(&macCTX->state.hmac,  find_hash_id(hashDesc->ID) , macKey, macKeyLen) ; CKERR;
            macCTX->process = (void*) hmac_process;
            macCTX->done = (void*) hmac_done;
            macCTX->hashsize = hashDesc->hashsize;
            
            break;
            
        case  kMAC_Algorithm_SKEIN:
        {
          switch(hash)
            {
           
                case kHASH_Algorithm_SKEIN256:
                    err = skeinmac_init(&macCTX->state.skeinmac, Skein256, macKey, macKeyLen);
                    macCTX->process = (void*) skeinmac_process;
                    macCTX->done = (void*) skeinmac_done;
                    macCTX->hashsize = 32;
                    break;

                case kHASH_Algorithm_SKEIN512:
                    err = skeinmac_init(&macCTX->state.skeinmac, Skein512, macKey, macKeyLen);
                    macCTX->process = (void*) skeinmac_process;
                    macCTX->done = (void*) skeinmac_done;
                    macCTX->hashsize = 64;
                   break;
                    
                default:
                     RETERR( kSCLError_BadHashNumber) ; 
               }
        }
             break;
            
        default:
            RETERR( kSCLError_BadHashNumber) ; 
    }
    
    *ctx = macCTX;
    
done:
    
    if(IsSCLError(err))
    {
        if(IsntNull(macCTX))
        {
            XFREE(macCTX);
        }
    }
    return err;
    
}


SCLError MAC_HashSize( MAC_ContextRef  ctx, size_t * bytes)
{
    int  err = kSCLError_NoErr;
    
    validateMACContext(ctx);
      
    *bytes = ctx->hashsize;
    
done:
    
    return (err);
}

 
SCLError MAC_Update(MAC_ContextRef  ctx, const void *data, size_t dataLength)
{
    int             err = kSCLError_NoErr;
   
    validateMACContext(ctx);
      
    if(ctx->process) 
        err = (ctx->process)(&ctx->state,  data, dataLength ); 
    
    return (err); 
}

SCLError MAC_Final(MAC_ContextRef  ctx, void *macOut,  size_t *resultLen)
{
    int             err = kSCLError_NoErr;
    unsigned long  outlen = *resultLen;
    
    validateMACContext(ctx);
 
    if(ctx->done) 
        err = (ctx->done)(&ctx->state,  macOut, &outlen ); 
        
    return err;
 
}



void MAC_Free(MAC_ContextRef  ctx)
{
    
    if(sMAC_ContextIsValid(ctx))
    {
        ZERO(ctx, sizeof(MAC_Context));
        XFREE(ctx);
    }
}

/*____________________________________________________________________________
 ECC wrappers  
 ____________________________________________________________________________*/



typedef struct ECC_Context    ECC_Context;

struct ECC_Context 
{
#define kECC_ContextMagic		0x4543436B   
	uint32_t                  magic;
    ecc_key                 key;
    bool                 isInited;
  };


/*____________________________________________________________________________
 validity test  
 ____________________________________________________________________________*/

static bool
sECC_ContextIsValid( const ECC_ContextRef  ref)
{
	bool       valid	= false;
	
	valid	= IsntNull( ref ) && ref->magic	 == kECC_ContextMagic;
	
	return( valid );
}

#define validateECCContext( s )		\
ValidateParam( sECC_ContextIsValid( s ) )


SCLError ECC_Init(ECC_ContextRef * ctx)
{
    int             err = kSCLError_NoErr;
    ECC_Context*    eccCTX = kInvalidECC_ContextRef;
    
    ValidateParam(ctx);
     
    eccCTX = XMALLOC(sizeof (ECC_Context)); CKNULL(eccCTX);
    
    eccCTX->magic = kECC_ContextMagic;
      
    CKERR;
    
    *ctx = eccCTX;
    
done:
    
    return err;
    
}

SCLError ECC_Generate(ECC_ContextRef  ctx, int keysize )
{
    int             err = kSCLError_NoErr;
      
    validateECCContext(ctx);
     
    err = ecc_make_key(NULL, find_prng("sprng"),   keysize/8, &ctx->key);CKERR; 
    ctx->isInited = true;
    
done:
    
    return (err); 
    
}


void ECC_Free(ECC_ContextRef  ctx)
{
    
    if(sECC_ContextIsValid(ctx))
    {
        
        if(ctx->isInited) ecc_free( &ctx->key);
        ZERO(ctx, sizeof(ECC_Context));
        XFREE(ctx);
    }
}
 
SCLError ECC_Export_ANSI_X963(ECC_ContextRef  ctx, void *outData, size_t bufSize, size_t *datSize)
{
    int             err = kSCLError_NoErr;
    unsigned long   length = bufSize;
     
    validateECCContext(ctx);
    
    ValidateParam(ctx->isInited);
       
    err = ecc_ansi_x963_export(&ctx->key, outData, &length); CKERR;
    
    *datSize = length;
    
done:
    
    return (err); 
    
}


SCLError ECC_Import_ANSI_X963(ECC_ContextRef  ctx,   void *in, size_t inlen )
{
    int             err = kSCLError_NoErr;
    
    validateECCContext(ctx);
    
    err = ecc_ansi_x963_import(in, inlen, &ctx->key); CKERR;
    ctx->isInited = true;
    
    
done:
    
    return (err); 
    
}

 

SCLError ECC_Export(ECC_ContextRef  ctx, int exportPrivate, void *outData, size_t bufSize, size_t *datSize)
{
    int             err = kSCLError_NoErr;
    unsigned long   length = bufSize;
    int             keyType = PK_PUBLIC;
    
     validateECCContext(ctx);
    
    ValidateParam(ctx->isInited);
    
    keyType =  exportPrivate?PK_PRIVATE:PK_PUBLIC;
 
    err = ecc_export(outData, &length, keyType, &ctx->key); CKERR;
    
    *datSize = length;
                     
  done:
    
    return (err); 
   
}


SCLError ECC_Import(ECC_ContextRef  ctx,   void *in, size_t inlen )
{
    int             err = kSCLError_NoErr;
      
    validateECCContext(ctx);
    
    err = ecc_import(in, inlen, &ctx->key); CKERR;
    ctx->isInited = true;
    
      
done:
    
    return (err); 
    
}

 
SCLError ECC_SharedSecret(ECC_ContextRef  privCtx, ECC_ContextRef  pubCtx, void *outData, size_t bufSize, size_t *datSize)
{
    int             err = kSCLError_NoErr;
    unsigned long   length = bufSize;
     
    validateECCContext(privCtx);
    validateECCContext(pubCtx);
    
    ValidateParam(privCtx->isInited);
    ValidateParam(pubCtx->isInited);

    err = ecc_shared_secret(&privCtx->key, &pubCtx->key, outData, &length); 
     
    *datSize = length;
    
done:
    
    return (err); 
  }

SCLError ECC_KeySize( ECC_ContextRef  ctx, size_t * bits)
{
    int  err = kSCLError_NoErr;
    
    validateECCContext(ctx);
    ValidateParam(ctx->isInited);
    
    *bits = ctx->key.dp->size *8;
    
done:
    
    return (err);
}
 
 

typedef struct CBC_Context    CBC_Context;

struct CBC_Context 
{
#define kCBC_ContextMagic		0x43424320   
	uint32_t            magic;
    Cipher_Algorithm    algor;
    symmetric_CBC       state; 
};



static bool
sCBC_ContextIsValid( const CBC_ContextRef  ref)
{
	bool       valid	= false;
	
	valid	= IsntNull( ref ) && ref->magic	 == kCBC_ContextMagic;
	
	return( valid );
}


#define validateCBCContext( s )		\
ValidateParam( sCBC_ContextIsValid( s ) )


SCLError CBC_Init(Cipher_Algorithm algorithm,
                  const void *key, 
                  const void *iv, 
                  CBC_ContextRef * ctxOut)
{
    int             err     = kSCLError_NoErr;
    CBC_Context*    cbcCTX  = NULL;
    int             keylen  = 0;
    int             cipher  = -1;      
    int             status  =  CRYPT_OK;
    
    ValidateParam(ctxOut);
    
    switch(algorithm)
    {
        case kCipher_Algorithm_AES128:
            keylen = 128 >> 3;
            cipher = find_cipher("aes");
            
            break;
        case kCipher_Algorithm_AES192:
            keylen = 192 >> 3;
            cipher = find_cipher("aes");
           
            break;
        case kCipher_Algorithm_AES256:
            keylen = 256 >> 3;
            cipher = find_cipher("aes");
           
            break;
        default:
            RETERR(kSCLError_BadCipherNumber);
        }
    
    
    cbcCTX = XMALLOC(sizeof (CBC_Context)); CKNULL(cbcCTX);
    
    cbcCTX->magic = kCBC_ContextMagic;
    cbcCTX->algor = algorithm;
     
    status = cbc_start(cipher, iv, key, keylen, 0, &cbcCTX->state); CKSTAT;
      
    *ctxOut = cbcCTX;
    
done:
    
    if(status != CRYPT_OK)
    {
        if(cbcCTX)
        {
            memset(cbcCTX, sizeof (CBC_Context), 0);
            XFREE(cbcCTX);
        }
        err = sCrypt2SCLError(status);
    }

     return err;
}

SCLError CBC_Encrypt(CBC_ContextRef ctx,
                     const void *	in,
                     size_t         bytesIn,
                     void *         out )
{
    int             err = kSCLError_NoErr;
    int             status  =  CRYPT_OK;
    
    validateCBCContext(ctx);
    
       
    status = cbc_encrypt(in, out, bytesIn, &ctx->state);
    
    err = sCrypt2SCLError(status);
    
    return (err); 

}

SCLError CBC_Decrypt(CBC_ContextRef ctx,
                     const void *	in,
                     size_t         bytesIn,
                     void *         out )
{
    int             err = kSCLError_NoErr;
    int             status  =  CRYPT_OK;
    
    validateCBCContext(ctx);
    
    
    status = cbc_decrypt(in, out, bytesIn, &ctx->state);
    
    err = sCrypt2SCLError(status);
    
    return (err); 

}

void CBC_Free(CBC_ContextRef  ctx)
{
    
    if(sCBC_ContextIsValid(ctx))
    {
        cbc_done(&ctx->state);
        ZERO(ctx, sizeof(CBC_Context));
        XFREE(ctx);
    }
}


#define	roundup(x, y)	((((x)+((y)-1))/(y))*(y))
#define MIN_MSG_BLOCKSIZE   32
#define MSG_BLOCKSIZE   16
 
SCLError MSG_Encrypt(uint8_t *key, size_t key_len,
                     const uint8_t *iv,
                     const uint8_t *in, size_t in_len,
                     uint8_t **outData, size_t *outSize) 
{
    SCLError    err     = kSCLError_NoErr;
    
    Cipher_Algorithm    algorithm = kCipher_Algorithm_Invalid;
    CBC_ContextRef      cbc = kInvalidCBC_ContextRef;
    
    uint8_t     bytes2Pad;
    uint8_t     *buffer = NULL;
    size_t      buffLen = 0;
    
    switch (key_len)
    {
        case 16:
            algorithm = kCipher_Algorithm_AES128;
            break;
        case 32:
            algorithm = kCipher_Algorithm_AES256;
            break;
            
        default:
            RETERR(kSCLError_BadParams);
            
            break;
    }
    
    /* calclulate Pad byte */
    if(in_len < MIN_MSG_BLOCKSIZE)
    {
        bytes2Pad =  MIN_MSG_BLOCKSIZE - in_len;
    }
    else
    {
        bytes2Pad =  roundup(in_len, MSG_BLOCKSIZE) +  MSG_BLOCKSIZE - in_len;
    };
    
    buffLen = in_len + bytes2Pad;
    buffer = XMALLOC(buffLen);
    CKNULL(buffer);
    
    memcpy(buffer, in, in_len);
    memset(buffer+in_len, bytes2Pad, bytes2Pad);
     
    err = CBC_Init(algorithm, key, iv,  &cbc);CKERR;
    
    err = CBC_Encrypt(cbc, buffer, buffLen, buffer); CKERR;
    
    
    *outData = buffer;
    *outSize = buffLen;
    
done:
    
    if(IsSCLError(err))
    {
        if(buffer)
        {
            memset(buffer, buffLen, 0);
            XFREE(buffer);
        }
    }
    
    CBC_Free(cbc);
    
    return err;
}



SCLError MSG_Decrypt(uint8_t *key, size_t key_len,
                     const uint8_t *iv,
                     const uint8_t *in, size_t in_len,
                     uint8_t **outData, size_t *outSize)

{
    SCLError err = kSCLError_NoErr;
    Cipher_Algorithm    algorithm = kCipher_Algorithm_Invalid;
    CBC_ContextRef      cbc = kInvalidCBC_ContextRef;
    
    uint8_t *buffer = NULL;
    size_t buffLen = in_len;
    uint8_t  bytes2Pad = 0;
    
    switch (key_len)
    {
        case 16:
            algorithm = kCipher_Algorithm_AES128;
            break;
        case 32:
            algorithm = kCipher_Algorithm_AES256;
            break;
            
        default:
            RETERR(kSCLError_BadParams);
            
            break;
    }
    
    
    buffer = XMALLOC(buffLen);
    CKNULL(buffer);
      
    err = CBC_Init(algorithm, key, iv,  &cbc);CKERR;
    
    err = CBC_Decrypt(cbc, in, buffLen, buffer); CKERR;
    
    bytes2Pad = *(buffer+buffLen-1);
    
    if(bytes2Pad > buffLen)
        RETERR(kSCLError_CorruptData);
    
    *outData = buffer;
    *outSize = buffLen- bytes2Pad;
    
    
done:
    if(IsSCLError(err))
    {
        if(buffer)
        {
            memset(buffer, buffLen, 0);
            XFREE(buffer);
        }
    }
    
    CBC_Free(cbc);
    
    return err;
    
}



SCLError PASS_TO_KEY (const uint8_t  *password,
                     unsigned long  password_len,
                     uint8_t       *salt,
                     unsigned long  salt_len,
                     unsigned int   rounds,
                     uint8_t        *key_buf,
                     unsigned long  key_len )

{
    SCLError    err     = kSCLError_NoErr;
    int         status  = CRYPT_OK;
    
    status = pkcs_5_alg2(password, password_len,
                         salt,      salt_len,
                         rounds,    find_hash("sha256"),
                         key_buf,   &key_len); CKSTAT;
    
    
done:
    if(status != CRYPT_OK)
        err = sCrypt2SCLError(status);
    
    return err;
    
    
}


SCLError RNG_GetBytes(
                       void *         out,
                       size_t         outLen 
                     )
{
    int             err = kSCLError_NoErr;
        
   unsigned long count  =  sprng_read(out,outLen,NULL);
 
    if(count != outLen)
        err =  kSCLError_ResourceUnavailable;
    
    return (err); 
    
}



SCLError ECB_Encrypt(Cipher_Algorithm algorithm,
                     const void *	key,
                     const void *	in,
                     size_t         bytesIn,
                     void *         out )
{
    int             err = kSCLError_NoErr;
    int             status  =  CRYPT_OK;
    symmetric_ECB   ECB;
     
    int             keylen  = 0;
    int             cipher  = -1;      
     
    switch(algorithm)
    {
        case kCipher_Algorithm_AES128:
            keylen = 128 >> 3;
            cipher = find_cipher("aes");
            
            break;
        case kCipher_Algorithm_AES192:
            keylen = 192 >> 3;
            cipher = find_cipher("aes");
            
            break;
        case kCipher_Algorithm_AES256:
            keylen = 256 >> 3;
            cipher = find_cipher("aes");
            
            break;
        default:
            RETERR(kSCLError_BadCipherNumber);
    }

    status  = ecb_start(cipher, key, keylen, 0, &ECB ); CKSTAT;

    status  = ecb_encrypt(in, out, bytesIn, &ECB); CKSTAT;


done:
    
    ecb_done(&ECB);
    
    if(status != CRYPT_OK)
        err = sCrypt2SCLError(status);
    
    return err;
    
}


SCLError ECB_Decrypt(Cipher_Algorithm algorithm,
                     const void *	key,
                     const void *	in,
                     size_t         bytesIn,
                     void *         out )
{
    int             err = kSCLError_NoErr;
    int             status  =  CRYPT_OK;
    symmetric_ECB   ECB;
    
    int             keylen  = 0;
    int             cipher  = -1;      
    
    switch(algorithm)
    {
        case kCipher_Algorithm_AES128:
            keylen = 128 >> 3;
            cipher = find_cipher("aes");
            
            break;
        case kCipher_Algorithm_AES192:
            keylen = 192 >> 3;
            cipher = find_cipher("aes");
            
            break;
        case kCipher_Algorithm_AES256:
            keylen = 256 >> 3;
            cipher = find_cipher("aes");
            
            break;
        default:
            RETERR(kSCLError_BadCipherNumber);
    }
    
    status  = ecb_start(cipher, key, keylen, 0, &ECB ); CKSTAT;
    
    status  = ecb_decrypt(in, out, bytesIn, &ECB); CKSTAT;
    
    
done:
    
    ecb_done(&ECB);
    
    if(status != CRYPT_OK)
        err = sCrypt2SCLError(status);
    
    return err;
}





