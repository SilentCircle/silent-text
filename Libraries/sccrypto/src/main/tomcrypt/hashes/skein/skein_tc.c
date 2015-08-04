//
//  skein_tc.c
//  tomcrypt
//
//  Created by Vinnie Moscaritolo on 4/16/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//
#include "tomcrypt.h"
#include <skeinApi.h>

 
#ifdef LTC_SKEIN256 

const struct ltc_hash_descriptor skein256_desc = {
    "skein256", 
    16,
    32, 
    64, 
    { 0 }, 0,
    &skein256_init,
    &skein256_process,
    &skein256_done,
    &skein256_test,
    NULL
};

 int skein256_init(hash_state * md)
{
    LTC_ARGCHK(md != NULL);
     
    skeinCtxPrepare(&md->skein, Skein256);
    skeinInit(&md->skein, 256);

    return CRYPT_OK;
}



int skein256_process(hash_state * md, const unsigned char *in, unsigned long inlen)
{
    
    skeinUpdate(&md->skein, in, inlen);
    
    return CRYPT_OK;
}


int skein256_done(hash_state * md, unsigned char *out)
{
    
    skeinFinal(&md->skein, out);

#ifdef LTC_CLEAN_STACK
    zeromem(md, sizeof(hash_state));
#endif

    return CRYPT_OK;
}


/**
 Self-test the hash
 @return CRYPT_OK if successful, CRYPT_NOP if self-tests have been disabled
 */  
int  skein256_test(void)
{
#ifndef LTC_TEST
    return CRYPT_NOP;
#else    
    
    return CRYPT_OK;
#endif
}

#endif

#ifdef LTC_SKEIN512

const struct ltc_hash_descriptor skein512_desc = {
    "skein512", 
    17,
    64, 
    128, 
    { 0 }, 0,
    &skein512_init,
    &skein512_process,
    &skein512_done,
    &skein512_test,
    NULL
};

int skein512_init(hash_state * md)
{
    LTC_ARGCHK(md != NULL);
    
    skeinCtxPrepare(&md->skein, Skein512);
    skeinInit(&md->skein, 512);
    
    return CRYPT_OK;
}



int skein512MAC_init(hash_state * md, const unsigned char *macKey, unsigned long macKeyLen)
{
    LTC_ARGCHK(md != NULL);
    
    skeinCtxPrepare(&md->skein, Skein512);
    skeinMacInit(&md->skein, macKey, macKeyLen, 512);
     
    return CRYPT_OK;
}



int skein512_process(hash_state * md, const unsigned char *in, unsigned long inlen)
{
    
    skeinUpdate(&md->skein, in, inlen);
    
    return CRYPT_OK;
}



int skein512_done(hash_state * md, unsigned char *out)
{
    
    skeinFinal(&md->skein, out);
    
#ifdef LTC_CLEAN_STACK
    zeromem(md, sizeof(hash_state));
#endif
    
    return CRYPT_OK;
}

#ifdef LTC_SKEINMAC

int skeinmac_init(skeinmac_state * mac, SkeinSize_t size, const unsigned char *macKey, unsigned long macKeyLen)
{
    LTC_ARGCHK(mac != NULL);
    
    skeinCtxPrepare(&mac->skein, size);
    skeinMacInit(&mac->skein, macKey, macKeyLen, 512);
    
    return CRYPT_OK;
}

int skeinmac_process(skeinmac_state * mac, const unsigned char *in, unsigned long inlen)
{
    
    skeinUpdate(&mac->skein, in, inlen);
    
    return CRYPT_OK;
}


int skeinmac_done(skeinmac_state * mac, unsigned char *out, unsigned long *outlen)
{
	u08b_t    macBuf[64];	
    u08b_t    *p = (*outlen < sizeof(macBuf))?macBuf:out;
    
    skeinFinal(&mac->skein, p);
    
    if(p!= out) 
        memcpy( out,macBuf, *outlen);
    
    
#ifdef LTC_CLEAN_STACK
    zeromem(mac, sizeof(hash_state));
    zeromem(macBuf, sizeof(macBuf));
#endif
    
   return CRYPT_OK;
}

#endif


/**
 Self-test the hash
 @return CRYPT_OK if successful, CRYPT_NOP if self-tests have been disabled
 */  
int  skein512_test(void)
{
#ifndef LTC_TEST
    return CRYPT_NOP;
#else    
    
    return CRYPT_OK;
#endif
}
#endif

#ifdef LTC_SKEIN1024

const struct ltc_hash_descriptor skein1024_desc = {
    "skein1024", 
    18,
    128, 
    256, 
    { 0 }, 0,
    &skein1024_init,
    &skein1024_process,
    &skein1024_done,
    &skein1024_test,
    NULL
};

int skein1024_init(hash_state * md)
{
    LTC_ARGCHK(md != NULL);
    
    skeinCtxPrepare(&md->skein, Skein1024);
    skeinInit(&md->skein, 1024);
    
    return CRYPT_OK;
}



int skein1024_process(hash_state * md, const unsigned char *in, unsigned long inlen)
{
    
    skeinUpdate(&md->skein, in, inlen);
    
    return CRYPT_OK;
}


int skein1024_done(hash_state * md, unsigned char *out)
{
    
    skeinFinal(&md->skein, out);
    
#ifdef LTC_CLEAN_STACK
    zeromem(md, sizeof(hash_state));
#endif
    
    return CRYPT_OK;
}


/**
 Self-test the hash
 @return CRYPT_OK if successful, CRYPT_NOP if self-tests have been disabled
 */  
int  skein1024_test(void)
{
#ifndef LTC_TEST
    return CRYPT_NOP;
#else    
    
    return CRYPT_OK;
#endif
}
#endif
 
 

 