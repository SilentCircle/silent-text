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
//  PKtest.c
//  tomcrypt
//

#include <stdio.h>
#include <tomcrypt.h>
#include "optest.h"

#define PTsize 32

int TestPK(prng_state * PRNG)
{
    int     err = CRYPT_OK;
    int     i;
    
    ecc_key     eccKey;
    uint8_t        PT[PTsize];
    uint8_t        CT[256];
    uint8_t        DT[PTsize];
    unsigned long   z,w;
    
 
    uint8_t        PrivKey[256];
    uint8_t        PubKey[256];
   
 //   uint8_t             tempBuf[256];
 //   unsigned long       tempLen;

    
    printf("\nTesting PK\n");
   
    // fill PT
    for(i = 0; i< PTsize; i++) PT[i]= i;
      
    DO( ecc_make_key(PRNG, find_prng ("yarrow"),  384/8, &eccKey));
  
    z = sizeof(PubKey);
     DO( ecc_export(PubKey, &z, PK_PUBLIC, &eccKey));
    printf("\tPub Key (%ld bytes)\n", z);
    dumpHex(PubKey,  z, 8);
     
    z = sizeof(PrivKey);
   DO( ecc_export(PrivKey, &z, PK_PRIVATE, &eccKey));
    printf("\n\tPriv Key (%ld bytes)\n", z);
    dumpHex(PrivKey,  z, 8);
     
    z = 384; 
    DO( ecc_encrypt_key(PT, PTsize, CT, &z, 
                        PRNG, 
                        find_prng("yarrow"), 
                        find_hash("sha256"),
                        &eccKey));
 
    printf("\n\tEncrypted message (%ld bytes)\n", z);
    dumpHex(CT,  z, 0);
    
    DO( ecc_decrypt_key(CT, z, DT, &w, &eccKey));
      
    /* check against know-answer */
    DO(compareResults( DT, PT, PTsize , kResultFormat_Byte, "ECC Decrypt"));
    printf("\n\tDecrypted OK\n");
    dumpHex(DT,  w, 0);
 
      ecc_free(&eccKey);
    
    return err;
    
}



int TestECC_DH()
{
    int     err = CRYPT_OK;
    
    ECC_ContextRef  key1 = NULL;
    ECC_ContextRef  key2 = NULL;
  
    uint8_t        keyBuf[512];
    unsigned long  keyLen = 0;

    uint8_t         Z       [256];
    unsigned long   x;
    int i;

#define ECC_KEY_SIZE 384
    
    printf("\nTesting ECC-DH (%d)\n\n", ECC_KEY_SIZE);

    for(i = 0; i <1; i++)
    {
        printf("----------Key Set %d ----------\n\n", i);
        /* create keys   */
        err = ECC_Init(&key1); CKERR;
        err = ECC_Generate(key1, ECC_KEY_SIZE ); CKERR;
        
        err = ECC_Init(&key2); CKERR;
        err = ECC_Generate(key2, ECC_KEY_SIZE ); CKERR;
        
        
        printf("Key1  \n");
        err = ECC_Export(key1, false, keyBuf, sizeof(keyBuf), &keyLen); CKERR;
        printf("\tPub Key (%ld bytes)\n", keyLen);
        dumpHex(keyBuf,  keyLen,0);
        
        err = ECC_Export(key1, true, keyBuf, sizeof(keyBuf), &keyLen); CKERR;
        printf("\n\tPriv Key (%ld bytes)\n", keyLen);
        dumpHex(keyBuf,  keyLen,0);
        
        printf("\nKey2  \n");
        err = ECC_Export(key2, false, keyBuf, sizeof(keyBuf), &keyLen); CKERR;
        printf("\tPub Key (%ld bytes)\n", keyLen);
        dumpHex(keyBuf,  keyLen,0);
        
        /* Kdk = MAC(Htotal,Z)    where Z is the DH of Pki and PKr */
        x = sizeof(Z); 
        
        err = ECC_SharedSecret(key1, key2, Z, sizeof(Z), &x);
        /* at this point we dont need the ECC keys anymore. Clear them */
        
        printf("\nECC Shared Secret (Z):  (%ld bytes)\n",x);
        dumpHex(Z,  x , 0);
        printf("\n");
        
        if(key1)
        {
            ECC_Free(key1);
            key1 = kInvalidECC_ContextRef;
        }
        
        if(key2)
        {
            ECC_Free(key2);
            key2 = kInvalidECC_ContextRef;
        }
        
    }
done:
    
    if(key1)
    {
        ECC_Free(key1);
        key1 = kInvalidECC_ContextRef;
    }
    
    if(key2)
    {
        ECC_Free(key2);
        key2 = kInvalidECC_ContextRef;
    }
    
    return err;
    
}
