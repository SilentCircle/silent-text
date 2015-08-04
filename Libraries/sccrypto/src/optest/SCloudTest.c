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
//  SCimpTest.c
//  optest
//

#include <limits.h>
#include <stdio.h>
#include <sys/param.h>

#include "SCcrypto.h"
#include "crypto_optest.h"


#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#define OPTEST_IOS_SPECIFIC 1
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
#define OPTEST_OSX_SPECIFIC 1
#endif

#ifndef MIN
#define MIN(x, y) ( ((x)<(y))?(x):(y) )
#endif




typedef  struct {
    char*           data;
    size_t          dataLen;
    size_t          dataAllocLen;
    
    char*           metadata;
    size_t          metaLen;
    size_t          metaAllocLen;
    
} scloud_decrypt_info;

static const size_t realloc_quantum = 128;


static SCLError sEventHandler(SCloudContextRef ctx, SCloudEvent* event, void* userData)
{
    SCLError     err  = kSCLError_NoErr;
    scloud_decrypt_info *info = (scloud_decrypt_info*)userData;
   
    
    switch(event->type)
    {
    
        case kSCloudEvent_Progress:
        {
            SCloudEventProgressData  *d =    &event->data.progress;
 
            OPTESTLogDebug("EVENT HASHING ( %zd, %zd, %d%%)\n", d->bytesProcessed , d->bytesTotal,
                   (int)(((float)d->bytesProcessed / (float)d->bytesTotal)*100));
        }
            break;

        case kSCloudEvent_DecryptedData:
        {
            SCloudEventDecryptData  *d =    &event->data.decryptData;
            
            OPTESTLogDebug("EVENT DECRYPT DATA (%d)\n", (int)d->length);
            OPTESTLogDebug("\t|%.*s|\n\n", (int)d->length, d->data);
            
            if(info)
            {
               if(d->length + info->dataLen > info->dataAllocLen)
               {
                   info->data = XREALLOC(info->data, info->dataAllocLen + realloc_quantum);
                   info->dataAllocLen = info->dataAllocLen + realloc_quantum;
               };
                
                COPY(d->data, info->data +  info->dataLen, d->length);
                info->dataLen+=d->length;
            }
            
        }
            break;
            
        case kSCloudEvent_DecryptedMetaData:
        {
            SCloudEventDecryptMetaData  *d =    &event->data.metaData;
            
            OPTESTLogDebug("EVENT DECRYPT META (%d)\n", (int)d->length);
            OPTESTLogDebug("\t|%.*s|\n\n", (int)d->length, d->data);
            
            if(info)
            {
                if(d->length + info->metaLen > info->metaAllocLen)
                {
                    info->metadata = XREALLOC(info->metadata, info->metaAllocLen + realloc_quantum);
                    info->metaAllocLen = info->metaAllocLen + realloc_quantum;
                };
                
                COPY(d->data, info->metadata +  info->metaLen, d->length);
                info->metaLen+=d->length;
            }

        }
        break;
             
        case kSCloudEvent_DecryptedMetaDataComplete:
        {
            SCloudEventDecryptMetaData  *d =    &event->data.metaData;
            
            OPTESTLogDebug("EVENT DECRYPT META COMPLETE(%d)\n", (int)d->length);
            OPTESTLogDebug("\t|%.*s|\n\n", (int)d->length, d->data);
            
        }
        break;
            
        case kSCloudEvent_Error:
        {    
            SCloudEventErrorData  *d =  &event->data.errorData;
            char errorBuf[256];
            
            err = d->error;
            
            OPTESTLogError("EVENT ERROR: %d ", d->error);
            
            if(IsntSCLError( SCCrypto_GetErrorString(d->error, sizeof(errorBuf), errorBuf)))
            {
                OPTESTLogError("%s", errorBuf);
            }
            
            OPTESTLogError("\n\n");
        }
            break;
            
        case kSCloudEvent_Done:
        {    
            OPTESTLogDebug("EVENT Done\n\n" );
        }
            break;
            
        case kSCloudEvent_Init:
        {    
            OPTESTLogDebug("EVENT Init\n" );
        }
            break;
            
        case kSCloudEvent_DecryptedHeader:
        {
            OPTESTLogDebug("EVENT  Decrypted Header\n" );
        }
            break;
            
            
        default:
            OPTESTLogError("EVENT OTHER %d\n", event->type);
            break;
    }
    
//done:
    return err;
}



typedef  struct {
    const char*      context;
    const char*      data;
    const char*      metadata;
    uint8_t         locator[SCLOUD_LOCATOR_LEN];
    const char*     locatorURL;
    
} scloud_kat_vector;


static SCLError RunSCLOUD_KAT(int testNo, scloud_kat_vector *kat)
{
    SCLError err = kSCLError_NoErr;
    SCloudContextRef   scloud = NULL;
    size_t              blocksize    = 10;
    
    uint8_t             *keyBLOB = NULL;
    size_t              keyBLOBlen  = 0;
 
    uint8_t             locator[SCLOUD_LOCATOR_LEN] = {0};;
    size_t              locatorlen  = 0;
    
    uint8_t             locatorURL[SCLOUD_LOCATOR_LEN * 2] = {0};;
    size_t              locatorURLlen  = 0;
   
    uint8_t         outBuffer[4096] = {0};
    size_t          outTotal  = 0;
    size_t          dataSize  = 0;
    
    scloud_decrypt_info decryptBlock;
    
    OPTESTLogInfo("\t\tEncrypting Message %d, %d + %d bytes\n",testNo,
                        (int)strlen(kat->metadata) ,(int)strlen(kat->data) );
    
    err = SCloudEncryptNew((void*)kat->context, strlen(kat->context),
                           (void*) kat->data ,  strlen(kat->data) ,
                           (void*) kat->metadata, strlen(kat->metadata),
                           sEventHandler, NULL,
                           &scloud); CKERR;

   
    err = SCloudCalculateKey(scloud, blocksize); CKERR;
    
    locatorlen = sizeof(locator);
    err =  SCloudEncryptGetLocator (scloud, locator, &locatorlen);CKERR;
    
    OPTESTLogDebug("\t\tLocator\n");
    dumpHex(IF_LOG_DEBUG,locator, (int)locatorlen,0);
    
    /* check locator against know-answer */
    err = compare2Results( kat->locator, 20, locator, locatorlen , kResultFormat_Byte, "SCloud Locator"); CKERR;
    
    locatorURLlen = sizeof(locatorURL);
    err = SCloudEncryptGetLocatorREST(scloud, locatorURL, &locatorURLlen); CKERR;
    
    err = compare2Results(kat->locatorURL, strlen(kat->locatorURL), locatorURL, strlen((char*)locatorURL) , kResultFormat_Byte, "SCloud LocatorURL" );
    OPTESTLogVerbose("\t\tLocator URL \"%s\"\n", locatorURL);

    err = SCloudEncryptGetKeyBLOB(scloud, &keyBLOB, &keyBLOBlen); CKERR;
    OPTESTLogVerbose("\t\tKeyBLOB: %.*s\n", keyBLOBlen, keyBLOB);
    
#define CHUNK_SIZE 64
    
   for(dataSize = CHUNK_SIZE;
        IsntSCLError( ( err = SCloudEncryptNext(scloud, &outBuffer[outTotal], &dataSize)) );
        outTotal += dataSize, dataSize = CHUNK_SIZE)
    {
        OPTESTLogDebug("\t\tEncrypted %d bytes\n", (int)dataSize);
    }
    if(err == kSCLError_EndOfIteration) err = kSCLError_NoErr;
    CKERR;
 
    OPTESTLogDebug("\t\tEncrypted Message %d bytes\n", outTotal);

    // free the scloud context
    SCloudFree(scloud);
    scloud = NULL;

    // setup decrypt test
    decryptBlock.dataAllocLen = realloc_quantum;
    decryptBlock.dataLen = 0;
    decryptBlock.data = XMALLOC(decryptBlock.dataAllocLen);
    decryptBlock.metaAllocLen = realloc_quantum;
    decryptBlock.metaLen = 0;
    decryptBlock.metadata = XMALLOC(decryptBlock.metaAllocLen);
    
    
    err = SCloudDecryptNew(keyBLOB, keyBLOBlen, sEventHandler, (void*)&decryptBlock, &scloud); CKERR;
    size_t bytes2copy ;
    uint8_t *p;
    
    for(bytes2copy = MIN(CHUNK_SIZE, outTotal), p =  outBuffer;
        IsntSCLError( ( err = SCloudDecryptNext(scloud, p, bytes2copy  )) );
        p+= bytes2copy, outTotal -= bytes2copy, bytes2copy = MIN(CHUNK_SIZE, outTotal) )
    {
    }
    
    if(err == kSCLError_EndOfIteration) err = kSCLError_NoErr;

    OPTESTLogDebug("\t\tDecrypted Message %d + %d bytes\n",decryptBlock.metaLen,  decryptBlock.dataLen);

    /* compare decrypt consistency */
    err = compare2Results(kat->data, strlen(kat->data), decryptBlock.data, decryptBlock.dataLen , kResultFormat_Byte, "Scloud Data" );
    err = compare2Results(kat->metadata, strlen(kat->metadata), decryptBlock.metadata, decryptBlock.metaLen , kResultFormat_Byte, "Scloud Meta Data" );

     
    OPTESTLogVerbose("\n");
 
done:
   
    if(decryptBlock.metadata)
        XFREE(decryptBlock.metadata);
  
    if(decryptBlock.data)
        XFREE(decryptBlock.data);
    
    if(IsntNull(scloud))
        SCloudFree(scloud);

    return err;
}



SCLError  TestSCloud()
{
    SCLError    err = kSCLError_NoErr;
    char        version_string[32];
    
    scloud_kat_vector scloud_kat_vector_array[] =
    {
        {
            "context 1",
            "Hello. My name is Inigo Montoya. You killed my father. Prepare to die.12345",
             "That Vizzini, he can *fuss*",
            {   0xa9,0x57,0xdd,0x43,0x40,0xe8,0x22,0xf8,
                0xdb,0x65,0xda,0x9f,0x3e,0xad,0x8b,0x58,
                0x83,0xbf,0x43,0x0e
            },
            "qVfdQ0DoIvjbZdqfPq2LWIO_Qw4A"
        },
        {
            "context 2",
           "Finish him. Finish him, your way.",
            "Fuss, fuss... I think he like to scream at *us*.",
            {   0x41,0xf2,0x3a,0x0f,0xad,0xe8,0xa8,0xc6,
                0xa8,0xbe,0x53,0x61,0x29,0x24,0x2a,0x4a,
                0xc7,0x51,0x33,0xea
            },
            "QfI6D63oqMaovlNhKSQqSsdRM-oA"
        },
        {
            "context 3",
            "Oh good, my way. Thank you Vizzini... what's my way",
            "Probably he means no *harm*. ",
            {   0xf2,0x0c,0xbc,0xc0,0xec,0xe2,0xa8,0x55,
                0x93,0xe6,0x31,0x66,0x9d,0x92,0xd5,0x06,
                0x71,0x55,0x7f,0x54
            },
            "8gy8wOziqFWT5jFmnZLVBnFVf1QA"
        },
        {
            "context 4",
            "Pick up one of those rocks, get behind a boulder, in a few minutes the man in black will come running around the bend, the minute his head is in view, hit it with the rock.",
            "He's really very short on *charm*." ,
            {   0x90,0x77,0xed,0xd1,0xb9,0x80,0xfa,0xd0,
                0x11,0xfd,0xd5,0x48,0x33,0x02,0x6a,0xad,
                0x18,0x8e,0xcb,0xef
            },
            "kHft0bmA-tAR_dVIMwJqrRiOy-8A"
        },
        {
            "context 5",
            "short",
            "You have a great gift for rhyme." ,
            {  0xd5,0x48,0x3f,0x8e,0x08,0x77,0x0f,0xcd,
                0x9f,0x88,0x88,0xcf,0xf6,0xf7,0x32,0x5a,
                0x6c,0xb9,0x05,0x0f
            },
            "1Ug_jgh3D82fiIjP9vcyWmy5BQ8A"
        },
        {
            "context 6",
            "no",
            "Yes, yes, some of the time.",
            {   0xde,0x59,0x07,0xc6,0xdf,0xa0,0x86,0xbd,
                0x66,0xea,0x97,0xed,0x90,0xdf,0x73,0xe2,
                0x81,0x1b,0x54,0x4b
            },
            "3lkHxt-ghr1m6pftkN9z4oEbVEsA"
        },
        {
            "context 7",
             "",
            "Fezzik, are there rocks ahead? ",
           {   0xab,0x10,0xab,0x9c,0x01,0xc9,0x06,0x6b,
                0x24,0xfb,0x14,0xf4,0x47,0xc2,0x24,0xd2,
                0xba,0x83,0xd0,0x40
            },
            "qxCrnAHJBmsk-xT0R8Ik0rqD0EAA"
        },
        {
            "context 8",
            "I do not envy you the headache you will have when you awake. But for now, rest well and dream of large women.",
            "",
            {   0xe2,0x80,0x86,0x27,0xe6,0x82,0x58,0x91,
                0xd4,0x63,0xcd,0x9b,0x11,0x9b,0xff,0x32,
                0xa2,0x21,0x92,0x63
            },
            "4oCGJ-aCWJHUY82bEZv_MqIhkmMA"
        }

   };
    
    err = SCloudGetVersionString(sizeof(version_string), version_string); CKERR;
    
    OPTESTLogInfo("\tTesting Scloud version: %s\n", version_string);

    for (int i = 0; i < sizeof(scloud_kat_vector_array)/ sizeof(scloud_kat_vector) ; i++)
    {
        err = RunSCLOUD_KAT(i, &scloud_kat_vector_array[i]); CKERR;
        
    }
 
 done:

    return err;
}



