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


#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#define OPTEST_IOS_SPECIFIC 1
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
#define OPTEST_OSX_SPECIFIC 1
#endif

#include <tomcrypt.h>

 #include "cryptowrappers.h"
#include "SCloud.h"

static char *banter[] = { 
    "Hello. My name is Inigo Montoya. You killed my father. Prepare to die.12345",
    " Finish him. Finish him, your way.",
    "Oh good, my way. Thank you Vizzini... what's my way?",
    " Pick up one of those rocks, get behind a boulder, in a few minutes the man in black will come running around the bend, the minute his head is in view, hit it with the rock.",
    "My way's not very sportsman-like. ",
    "Why do you wear a mask? Were you burned by acid, or something like that?",
    " Oh no, it's just that they're terribly comfortable. I think everyone will be wearing them in the future.",
    " I do not envy you the headache you will have when you awake. But for now, rest well and dream of large women.",
    " I just want you to feel you're doing well.",
    "That Vizzini, he can *fuss*" , 
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

void dumpHex(  uint8_t* buffer, int length, int offset)
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
        
		printf("%6d: ", lineStart+offset);
		for (i = 0; i < lineLength; i++){
			printf("%c", hexDigit[ bufferPtr[lineStart+i] >>4]);
			printf("%c", hexDigit[ bufferPtr[lineStart+i] &0xF]);
			if((lineStart+i) &0x01) printf("%c", ' ');
		}
		for (; i < kLineSize; i++)
			printf("   ");
		printf("  ");
		for (i = 0; i < lineLength; i++) {
			c = bufferPtr[lineStart + i] & 0xFF;
			if (c > ' ' && c < '~')
				printf("%c", c);
			else {
				printf(".");
			}
		}
		printf("\n");
	}
#undef kLineSize
}




SCLError sEventHandler(SCloudContextRef ctx, SCloudEvent* event, void* uservalue)
{
    SCLError     err  = kSCLError_NoErr;
    
    
    printf("EVENT (%d) -  ", event->type);
    
    switch(event->type)
    {
         case kSCloudEvent_DecryptedData:
        {
            SCloudEventDecryptData  *d =    &event->data.decryptData;
            
            printf("DECRYPT DATA (%d)\n", (int)d->length);
            printf("\t|%.*s|\n\n", (int)d->length, d->data);
            
        }
            break;
            
        case kSCloudEvent_DecryptedMetaData:
        {
            SCloudEventDecryptMetaData  *d =    &event->data.metaData;
            
            printf("DECRYPT META (%d)\n", (int)d->length);
            printf("\t|%.*s|\n\n", (int)d->length, d->data);
            
        }
        break;
            
            
        case kSCloudEvent_Error:
        {    
            SCloudEventErrorData  *d =  &event->data.errorData;
            char errorBuf[256];
            
            printf("ERROR: %d ", d->error); 
            
            if(IsntSCLError( SCLGetErrorString(d->error, sizeof(errorBuf), errorBuf)))
            {
                printf("%s", errorBuf);
            }
            
            printf("\n\n");
        }
            break;
            
        case kSCloudEvent_Done:
        {    
            printf("Done\n\n" );
        }
            break;
            
        case kSCloudEvent_Init:
        {    
            printf("Init\n" );
        }
            break;
            
        default:
            printf("OTHER EVENT %d\n", event->type);
            break;
    }
    
done:
    return err;
}
 

static SCLError TestSCloud()
{
    SCLError err = kSCLError_NoErr;
    SCloudContextRef   scloud = NULL;
    SCloudContextRef   scloud1 = NULL;
    int         i;
    
    for(i = 0; banter[i] != NULL; i++)
    {
        uint8_t key[SCLOUD_KEY_LEN] = {0};
        size_t  keylen  = 0;
  
        uint8_t keyURL[SCLOUD_KEY_LEN * 2] = {0};
        size_t  keyURLlen  = 0;
        
        uint8_t locator[SCLOUD_HASH_LEN] = {0};;
        size_t  locatorlen  = 0;
        
        uint8_t locatorURL[SCLOUD_HASH_LEN * 2] = {0};;
        size_t  locatorURLlen  = 0;
        
         uint8_t metaData[128];
        size_t metaDataLen = 0;
        
        uint8_t outBuffer[4096] = {0};
        uint8_t *p;
        size_t  outTotal  = 0;
        size_t  dataSize  = 0;
        
        metaDataLen = sprintf((char*)metaData, "Item %d, Length %d and some other meta data", i,  (int)strlen(banter[i]));
                
        printf("Encrypting Message %d, %d bytes\n\n",i, (int)strlen(banter[i]));
         
        err = SCloudEncryptNew( banter[i] ,  strlen(banter[i]) , metaData, metaDataLen, &scloud); CKERR;
         
        printf("Key: ");
        keyURLlen = sizeof(keyURL);
        err = SCloudEncryptGetKeyREST(scloud, keyURL, &keyURLlen); CKERR;
        printf("%s\n",keyURL);
        
        keylen = sizeof(key);
        err =  SCloudEncryptGetKey (scloud, key, &keylen); CKERR;
        dumpHex(key, (int)keylen,0);
        
        printf("\n");
         printf("Locator: ");
        
        locatorURLlen = sizeof(locatorURL);
        err = SCloudEncryptGetLocatorREST(scloud, locatorURL, &locatorURLlen); CKERR;
        printf("%s\n",locatorURL);
        
        locatorlen = sizeof(locator);
        err =  SCloudEncryptGetLocator (scloud, locator, &locatorlen);CKERR;
        dumpHex(locator, (int)locatorlen,0);
        printf("\n");

#define CHUNK_SIZE 128
   
           
        for(dataSize = CHUNK_SIZE;
            IsntSCLError( ( err = SCloudEncryptNext(scloud, &outBuffer[outTotal], &dataSize)) );
            outTotal += dataSize, dataSize = CHUNK_SIZE)
        {
            printf("Encypted %d bytes\n", (int)dataSize);
        }
        if(err == kSCLError_EndOfIteration) err = kSCLError_NoErr;
        
        SCloudFree(scloud);
        scloud = NULL;
        CKERR;
        
        dumpHex(outBuffer, (int) outTotal, 0);
        
        if (i&1)
        {
            err = SCloudDecryptNew(keyURL, strlen((char*)keyURL), true, sEventHandler, (void*)0x1234567, &scloud1); CKERR;
            
        }
        else
        {
            err = SCloudDecryptNew(key, keylen, false, sEventHandler, (void*)0x1234567, &scloud1); CKERR;
            
        }
        
        size_t bytes2copy ;
         
        for(bytes2copy = MIN(CHUNK_SIZE, outTotal), p =  outBuffer;
              IsntSCLError( ( err = SCloudDecryptNext(scloud1, p, bytes2copy  )) );
            p+= bytes2copy, outTotal -= bytes2copy, bytes2copy = MIN(CHUNK_SIZE, outTotal) )
        {
         }

        if(err == kSCLError_EndOfIteration) err = kSCLError_NoErr;
        
        if(IsSCLError( err))
        {
            printf("SCloudDecryptNext Err: %d\n", err);
            
        }
        
    }
    
     
done:    
    
    if(IsntNull(scloud1))
        SCloudFree(scloud1);
    
    
    if(IsntNull(scloud))
        SCloudFree(scloud);
    
    printf("SCloud test Complete \n");
    
    return err;
}


ltc_math_descriptor ltc_mp;


int scloudtest_main(int argc, char **arg)
{
    SCLError err = CRYPT_OK;
    char version_string[32];
 
    
    register_prng(&sprng_desc);
    register_hash (&sha256_desc);
    register_hash (&sha512_desc);
    register_hash (&sha512_256_desc);
    register_hash (&skein512_desc);
    register_cipher (&aes_desc);
    register_hash (&skein256_desc);
    register_hash (&skein512_desc);
   
    
    err = SCloudGetVersionString(sizeof(version_string), version_string); CKERR;
    
    printf("Test libscloud version: %s\n", version_string);
    
     ltc_mp = ltm_desc;
      
    err =  TestSCloud() ;CKERR;
    
    
    
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
    
    result = scloudtest_main(0,NULL);
    
    return (result);
}
#else


int main(int argc, char **argv)
{
    return(scloudtest_main(argc, argv));
}
#endif

