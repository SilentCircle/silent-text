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

#import <CommonCrypto/CommonKeyDerivation.h>


#if OPTEST_IOS_SPECIFIC
#import <UIKit/UIKit.h>
#else
#import <Foundation/Foundation.h>
#endif
#include <stdio.h>
#include <time.h>
#include "optest.h"
#include "cryptowrappers.h"

#define CKSTAT {if (status != CRYPT_OK)  goto done; }

SCLError PASS_TO_KEY_SETUP(
                     unsigned long  password_len,
                     unsigned long  key_len,
                     uint8_t        *salt,
                     unsigned long  salt_len,
                     uint32_t       *rounds_out)
{
    SCLError    err     = kSCLError_NoErr;
    int         status  = CRYPT_OK;
     
    sprng_read(salt,salt_len,NULL);
    
    // How many rounds to use so that it takes 0.1s ?
    uint rounds = CCCalibratePBKDF(kCCPBKDF2,
                                   password_len,
                                   salt_len,
                                   kCCPRFHmacAlgSHA256,
                                   key_len, 100);
    
     
    *rounds_out = rounds;
    
done:
    if(status != CRYPT_OK)
        err = sCrypt2SCLError(status);
    
    return err;
    
   
}

    


static char *Msgs[] = { 
    "Hello. My name is Inigo Montoya. You killed my father. Prepare to die.",
    " Finish him. Finish him, your way.",
    "Oh good, my way. Thank you Vizzini... what's my way?",
    " Pick up one of those rocks, get behind a boulder, in a few minutes the man in black will come running around the bend, the minute his head is in view, hit it with the rock.",
    "My way's not very sportsman-like. ",
    "Why do you wear a mask? Were you burned by acid, or something like that?",
    " Oh no, it's just that they're terribly comfortable. I think everyone will be wearing them in the future.",
    " I do not envy you the headache you will have when you awake. But for now, rest well and dream of large women.",
    " I just want you to feel you're doing well.",
    "That Vizzini, he can *fuss*." , 
    "Fuss, fuss... I think he like to scream at *us*.",
    "Probably he means no *harm*. ",
    "He's really very short on *charm*." ,
    "You have a great gift for rhyme." ,
    "Yes, yes, some of the time.",
    "Enough of that.",
    "Fezzik, are there rocks ahead? ",
    "If there are, we all be dead. ",
    "No more rhymes now, I mean it. ",
    "Anybody want a peanut?",
    "short",
    "no",
    "",
    NULL
};


#define MSG_KEY_BYTES 16


static SCLError sCreateMessageKey(int keyLen, uint8_t *key, uint8_t *iv)
{
    SCLError    err     = kSCLError_NoErr;
    HASH_ContextRef     hashRef      = kInvalidHASH_ContextRef;
 
    
    // generate a master key and IV for local  message storage encryption
    err = RNG_GetBytes(key, keyLen ); CKERR;
    
    err = HASH_Init( kHASH_Algorithm_SHA256, & hashRef); CKERR;
    err = HASH_Update( hashRef, key,  keyLen); CKERR;
    err = HASH_Final( hashRef, iv); CKERR;
 
    
done:
    
    return err;
   
}

 

typedef struct {
    uint8_t 	*data;
    size_t     len;
 }storage_entry;


SCLError TestKDF()
{
    SCLError    err     = kSCLError_NoErr;
     
// store this on keychain
    uint8_t     salt[8];
    uint32_t    rounds = 0;
    uint8_t     locked_key[MSG_KEY_BYTES];
    uint8_t     iv[MSG_KEY_BYTES];             // this can be hard coded to match real IV

 
// keep around when unlocked, erase on lock
    uint8_t     unlocking_key[MSG_KEY_BYTES];
    uint8_t     msg_key[MSG_KEY_BYTES];             
     
    
// erase after hashing
    uint8_t     passphrase[] = "Tant las fotei com auziretz";
  
  	clock_t		start	= 0;
	double		elapsed	= 0;
    int         i;
    
    int msg_count = ( sizeof(Msgs) / sizeof(char*)) -1;
    
    storage_entry *msg_store = NULL;
    
    msg_store = XMALLOC(sizeof(storage_entry) * msg_count);
      
    printf("\nTesting Key Derivation and Local Message Storage Encryption\n");
     
    err = sCreateMessageKey(MSG_KEY_BYTES, msg_key, iv); CKERR;
    
    // calculate how many rounds we need on this machine for passphrase hashing
    err = PASS_TO_KEY_SETUP(strlen(passphrase),
                      MSG_KEY_BYTES, salt, sizeof(salt), &rounds); CKERR;
      printf("%d rounds on this device for 0.1s\n", rounds);
    
     
    start = clock();
     err = PASS_TO_KEY(passphrase, strlen(passphrase),
                      salt, sizeof(salt),
                      rounds, unlocking_key, sizeof(unlocking_key)); CKERR;
       
    elapsed = ((double) (clock() - start)) / CLOCKS_PER_SEC;
   
    printf("\t%12s: ", "msg key" );
    dumpHex8 ( msg_key);  dumpHex8 ( msg_key+8);
    printf("\n" );
  
    printf("\t%12s: ", "unlocked key" );
    dumpHex8 ( unlocking_key);  dumpHex8 ( unlocking_key+8);
    printf("\n" );
    
   
    printf("\nencrypt the message key to passphrase\n"); 
    err =  ECB_Encrypt(kCipher_Algorithm_AES128, unlocking_key, msg_key, MSG_KEY_BYTES, locked_key); CKERR;

    ZERO(unlocking_key, MSG_KEY_BYTES);
    ZERO(msg_key, MSG_KEY_BYTES);
    
    printf("\nStore the following on keychain \n" );
   
   printf("\t%10s: %d\n", "rounds", rounds );
    
    printf("\t%10s: ", "salt" );
    dumpHex8 ( salt);
    printf("\n" );
    
    printf("\t%10s: ", "IV" );
    dumpHex8 ( iv);  dumpHex8 ( iv+8);
    printf("\n" );
  
    printf("\t%10s: ", "locked key" );
    dumpHex8 ( locked_key);  dumpHex8 ( locked_key+8);
    printf("\n" );
 
    
    printf("\nUnlock key with passphrase \n" );

    err = PASS_TO_KEY(passphrase, strlen(passphrase),
                      salt, sizeof(salt),
                      rounds, unlocking_key, sizeof(unlocking_key)); CKERR;

    err =  ECB_Decrypt(kCipher_Algorithm_AES128, unlocking_key, locked_key, MSG_KEY_BYTES, msg_key); CKERR;
   
    
    printf("\t%10s: ", "msg key" );
    dumpHex8 ( msg_key);  dumpHex8 ( msg_key+8);
    printf("\n" );
     
    printf("\nEncrypt %d Messages\n" , msg_count);
 
    for(i = 0; Msgs[i] != NULL; i++)
    {
         unsigned long msgLen;
           
        msgLen = strlen(Msgs[i]);
     
        printf("%3d - ", i);
        
        err = MSG_Encrypt(msg_key,     MSG_KEY_BYTES, iv,
                          Msgs[i], msgLen, 
                          &msg_store[i].data,   &msg_store[i].len); CKERR;
 
        printf("%3d bytes |%.*s|\n\n",  (int)msgLen,(int)msgLen, Msgs[i] );  
        dumpHex(msg_store[i].data, (int)msg_store[i].len, 0);
        printf("\n");
   
    }
    
    
    printf("\nDecrypt %d Messages\n" , msg_count);
    
    for(i = 0; Msgs[i] != NULL; i++)
    {
        unsigned long msgLen;
        
        uint8_t*    PT = NULL;
        size_t      PTLen = 0;
     
        msgLen = strlen(Msgs[i]);
        
         err = MSG_Decrypt(msg_key,     MSG_KEY_BYTES, iv, 
                          msg_store[i].data,   msg_store[i].len,
                          &PT,    &PTLen); CKERR;

        if(msgLen != PTLen)
        {
            printf("ERROR  MSG Decrypt: Expecting %d bytes, got %d\n", (int)msgLen, (int)PTLen );
            RETERR(kSCLError_SelfTestFailed);
        }
         if( compareResults( Msgs[i],  PT, msgLen , kResultFormat_Byte, "MSG Decrypt") != CRYPT_OK)
        {
            RETERR(kSCLError_SelfTestFailed);
        }
        
    }
   
    printf("OK\n");
    
    
    
    printf("\nChange key  passphrase to null\n" );
    
 /*   err = PASS_TO_KEY(passphrase1, strlen(passphrase1),
                      salt, sizeof(salt),
                      rounds, unlocking_key, sizeof(unlocking_key)); CKERR;
  
  */
    ZERO(unlocking_key, MSG_KEY_BYTES);
    rounds = 0;
    ZERO(salt, 8);
    
    printf("\nencrypt the message key to passphrase\n"); 
    err =  ECB_Encrypt(kCipher_Algorithm_AES128, unlocking_key, msg_key, MSG_KEY_BYTES, locked_key); CKERR;
    
    ZERO(unlocking_key, MSG_KEY_BYTES);
    ZERO(msg_key, MSG_KEY_BYTES);
    
    printf("\nStore the following on keychain \n" );
    
    printf("\t%10s: %d\n", "rounds", rounds );
    
    printf("\t%10s: ", "salt" );
    dumpHex8 ( salt);
    printf("\n" );
    
    printf("\t%10s: ", "IV" );
    dumpHex8 ( iv);  dumpHex8 ( iv+8);
    printf("\n" );
    
    printf("\t%10s: ", "locked key" );
    dumpHex8 ( locked_key);  dumpHex8 ( locked_key+8);
    printf("\n" );
    
    
    
    printf("\nUnlock key with null passphrase \n" );

    /*
    err = PASS_TO_KEY(passphrase, strlen(passphrase),
                      salt, sizeof(salt),
                      rounds, unlocking_key, sizeof(unlocking_key)); CKERR;
  
     */

    ZERO(unlocking_key, MSG_KEY_BYTES);

    err =  ECB_Decrypt(kCipher_Algorithm_AES128, unlocking_key, locked_key, MSG_KEY_BYTES, msg_key); CKERR;
    
    printf("\nDecrypt %d Messages\n" , msg_count);
    
    for(i = 0; Msgs[i] != NULL; i++)
    {
        unsigned long msgLen;
        
        uint8_t*    PT = NULL;
        size_t      PTLen = 0;
        
        msgLen = strlen(Msgs[i]);
        
        err = MSG_Decrypt(msg_key,     MSG_KEY_BYTES, iv, 
                          msg_store[i].data,   msg_store[i].len,
                          &PT,    &PTLen); CKERR;
        
        if(msgLen != PTLen)
        {
            printf("ERROR  MSG Decrypt: Expecting %d bytes, got %d\n", (int)msgLen, (int)PTLen );
            RETERR(kSCLError_SelfTestFailed);
        }
        if( compareResults( Msgs[i],  PT, msgLen , kResultFormat_Byte, "MSG Decrypt") != CRYPT_OK)
        {
            RETERR(kSCLError_SelfTestFailed);
        }
 
     }
    
    printf("OK\n");
    
    
done:
       
   
    for(i = 0; i < msg_count; i++)
    {
         if(msg_store[i].data )
        {
              XFREE(msg_store[i].data); 
        }
        
    }

    XFREE(msg_store);
    
    ZERO(locked_key, MSG_KEY_BYTES);
    ZERO(unlocking_key, MSG_KEY_BYTES);
    ZERO(msg_key, MSG_KEY_BYTES);
    
    return err;
    
    
}

 
