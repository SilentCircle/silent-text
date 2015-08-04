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
//
//  P2Ktest.c
//  sccrypto
//
//  Created by vinnie on 10/16/14.
//
//


#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <string.h>
#include "SCcrypto.h"
#include "crypto_optest.h"


#define MSG_KEY_BYTES 32

typedef struct  {
    uint8_t *  passphrase;
    uint8_t     salt[64];
    size_t      saltLen;
    uint32_t    rounds;
    
    uint8_t     key[64];
    size_t		 keyLen;
}  p2k_kat_vector;



static SCLError RunP2K_KAT( p2k_kat_vector *kat)
{
    SCLError err = kSCLError_NoErr;

     uint8_t     key[128];
 
    
    err = PASS_TO_KEY(kat->passphrase, strlen((char*)kat->passphrase),
                      kat->salt, kat->saltLen ,
                      kat->rounds,
                      key, kat->keyLen); CKERR;
  
    err = compareResults( kat->key, key, kat->keyLen , kResultFormat_Byte, "PASS_TO_KEY"); CKERR;

done:
    return err;

};

 SCLError  TestP2K()
{
    SCLError     err = kSCLError_NoErr;
    
    
    p2k_kat_vector p2K_kat_vector_array[] =
    {
        {
       (uint8_t *)"Tant las fotei com auziretz",
        { 	0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, },
        8,
        1024,
        {
            0x66, 0xA4, 0x59, 0x7C, 0x73, 0x58, 0xFE, 0x57, 0xAE, 0xCE, 0x88, 0x68, 0x67, 0x58, 0xF6, 0x83
        },
       16
        },
        
        {
        (uint8_t *)"Hello. My name is Inigo Montoya. You killed my father. Prepare to die.",
        { 	0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, },
        8,
        1024,
        {
           0x26, 0xF5, 0x27, 0xAA, 0x36, 0xD0, 0xE9, 0xF8, 0x10, 0xA0, 0x27, 0xD7, 0x7C, 0xB4, 0xEC, 0x58
        },
        16
        }

     };
 
    OPTESTLogInfo("\nTesting Key Derivation\n");
    
    
    
    for (int i = 0; i < sizeof(p2K_kat_vector_array)/ sizeof(p2k_kat_vector) ; i++)
    {
        
        err = RunP2K_KAT( &p2K_kat_vector_array[i]); CKERR;
        
    }

    OPTESTLogInfo("\n ******* FINISH THIS CODE FOR  P2K ******* \n");

    
    uint8_t     passphrase[] = "Tant las fotei com auziretz";
    uint8_t     salt[8];
    uint32_t    rounds = 0;
    
    clock_t		start	= 0;
    double		elapsed	= 0;
    
    uint8_t     key[MSG_KEY_BYTES];

    // calculate how many rounds we need on this machine for passphrase hashing
    err = PASS_TO_KEY_SETUP(strlen((char*)passphrase),
                            MSG_KEY_BYTES, salt, sizeof(salt), &rounds); CKERR;
    OPTESTLogInfo("\t%d rounds on this device for 0.1s\n", rounds);
    
    start = clock();
    err = PASS_TO_KEY(passphrase, strlen((char*)passphrase),
                      salt, sizeof(salt),
                      rounds, key, sizeof(key)); CKERR;
    
    elapsed = ((double) (clock() - start)) / CLOCKS_PER_SEC;

    OPTESTLogInfo("\n");
    
done:
    return err;
    
}
