//
//  threefish_tc.c
//  tomcrypt
//
//  Created by Vinnie Moscaritolo on 4/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#include "tomcrypt.h"
#include <threefishApi.h>


#ifdef LTC_THREEFISH



const struct ltc_cipher_descriptor threefish_desc =
{
    "threefish",
    33,
    32, 32, 128, 0,
    NULL,
    NULL,
    NULL,
    &threefish_test,
    &threefish_done,
    &threefish_keysize,
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
};

 
int threefish_setup_key(uint64_t *key, int keylen, uint64_t *tweak, symmetric_key *skey)
{
    
    threefishSetKey(&skey->threefish, keylen, key, tweak);
    return CRYPT_OK;   
}
 


int threefish_ecb_encrypt(const unsigned char *pt, unsigned char *ct, symmetric_key *skey)
{
    return CRYPT_OK;   

}


int threefish_ecb_decrypt(const unsigned char *ct, unsigned char *pt, symmetric_key *skey)
{
    return CRYPT_OK;   

}

int threefish_word_encrypt(uint64_t* in, uint64_t* out,symmetric_key *skey)
{
    threefishEncryptBlockWords(&skey->threefish, in, out);
    return CRYPT_OK;   
}


int threefish_word_decrypt(uint64_t* in, uint64_t* out,symmetric_key *skey)
{
    threefishDecryptBlockWords(&skey->threefish, in, out);
    return CRYPT_OK;   
}


void threefish_done(symmetric_key *skey)
{
}


int threefish_test(void)
{
#ifndef LTC_TEST
    return CRYPT_NOP;
#else
    return CRYPT_OK;   
#endif
}

int threefish_keysize(int *keysize)
{
    LTC_ARGCHK(keysize != NULL);
    
    if (*keysize < 8) {
        return CRYPT_INVALID_KEYSIZE;
    } else if (*keysize > 56) {
        *keysize = 56;
    }
    return CRYPT_OK;
}
    
#endif


