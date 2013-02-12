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
//
//  main,c.c
//  tomcrypt
//

#include <stdio.h>
#include <tomcrypt.h>

#include "optest.h"
 
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#define OPTEST_IOS_SPECIFIC 1
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
#define OPTEST_OSX_SPECIFIC 1
#endif



 
int TestPRNG(prng_state * PRNG)
{
    #define kRandomBuffSize	 64
    
    int err = CRYPT_OK;
    uint8_t buffer[kRandomBuffSize];
  
    unsigned long x = 0;
      
    printf("Testing PRNG\n");
    
    x = yarrow_read(buffer,kRandomBuffSize,PRNG);
    
    dumpHex(buffer, (int)x, 0);
     
    return err;
}

#if 0
#ifdef USE_LTM
ltc_mp = ltm_desc;
#elif defined(USE_TFM)
ltc_mp = tfm_desc;
#elif defined(USE_GMP)
ltc_mp = gmp_desc;
#else
extern ltc_math_descriptor EXT_MATH_LIB;
ltc_mp = EXT_MATH_LIB;
#endif
#endif


ltc_math_descriptor ltc_mp;
 

int optest_main(int argc, char **arg)
{
    SCLError err = CRYPT_OK;
  
    printf("Test libtomcrypt\n");

    
    
    ltc_mp = ltm_desc;

    register_prng(&yarrow_desc);
    register_prng(&sprng_desc);
    register_hash (&sha1_desc);
    register_hash (&sha256_desc);
    register_hash (&sha384_desc);
    register_hash (&sha512_desc);
    register_hash (&sha224_desc);
    register_hash (&skein256_desc);
    register_hash (&skein512_desc);
    register_hash (&skein1024_desc);
    register_hash (&sha512_256_desc);
        
  
    prng_state PRNG;
     
    DO( rng_make_prng(128, find_prng("yarrow"), &PRNG, NULL));

    DO( TestPRNG( &PRNG));
    
    DO( TestHash());
    DO( TestHMAC());
    DO( TestCiphers());
    DO( TestCCM());
    DO( TestGCM());
    DO( TestKDF());
    DO( TestECC_DH());
    DO( TestStorageCiphers());
    
    DO( TestPK( &PRNG));
    DO(otrMathTest(&PRNG));
    
  
      
done:
    
    if(IsSCLError(err))
    {
        char errorBuf[256];
        
        if(IsntSCLError( SCLGetErrorString(err, sizeof(errorBuf), errorBuf)))
        {
               printf("\nError %d:  %s\n", err, errorBuf);
        }
        else
       {
           printf("\nError %d\n", err);
         
       }
         
    };
           
//    ctr_test();
    
    return 0;
}

#if OPTEST_IOS_SPECIFIC
int ios_main()
{
    int result = 0;
    
    result = optest_main(0,NULL);
    
    return (result);
}
#else


int main(int argc, char **argv)
{
    return(optest_main(argc, argv));
}
#endif

