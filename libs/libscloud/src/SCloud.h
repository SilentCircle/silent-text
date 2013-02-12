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

#ifndef Included_scloud_h	/* [ */
#define Included_scloud_h

#include "SCpubTypes.h"


#pragma mark
#pragma mark SCloud Public Defines

#define SCLOUD_BUILD_NUMBER             2
#define SCLOUD_SHORT_VERSION_STRING		"0.2.0"

#define SCLOUD_KEY_LEN              32
#define SCLOUD_BLOCK_LEN            (SCLOUD_KEY_LEN >>1)
#define SCLOUD_LOCATOR_LEN          32
#define  SCLOUD_MIN_BUF_SIZE        32

#define TRUNCATED_LOCATOR_BITS      160


typedef struct SCloudContext *      SCloudContextRef;

/*____________________________________________________________________________
 Invalid values for each of the "ref" data types. Use these for assignment
 and initialization only. Use the SCXXXRefIsValid macros (below) to test
 for valid/invalid values.
 ____________________________________________________________________________*/

#define	kInvalidSCloudContextRef		((SCloudContextRef) NULL)

/*____________________________________________________________________________
 Macros to test for ref validity. Use these in preference to comparing
 directly with the kInvalidXXXRef values.
 ____________________________________________________________________________*/

#define SCloudContextRefIsValid( ref )		( (ref) != kInvalidSCloudContextRef )



#pragma mark
#pragma mark SCloud Callbacks


enum SCloudEventType_
{
    kSCloudEvent_NULL             = 0,
    kSCloudEvent_Init,
    kSCloudEvent_Progress,
    kSCloudEvent_Error,
    kSCloudEvent_DecryptedData,
    kSCloudEvent_DecryptedMetaData,
    kSCloudEvent_DecryptedMetaDataComplete,
    kSCloudEvent_Done,
    
    ENUM_FORCE( SCloudEvent_ )
};
ENUM_TYPEDEF( SCloudEventType_, SCloudEventType  );


typedef struct SCloudEventDecryptData_
{
    uint8_t*            data;
    size_t              length;
} SCloudEventDecryptData;

typedef struct SCloudEventDecryptMetaData_
{
    uint8_t*            data;
    size_t              length;
} SCloudEventDecryptMetaData;


typedef struct SCloudEventErrorData_
{
    SCLError    error;
} SCloudEventErrorData;


typedef struct SCloudEventProgressData_
{
    size_t			bytesProcessed;
	size_t			bytesTotal;
} SCloudEventProgressData;

typedef union SCloudEventData
{
    SCloudEventErrorData         errorData;
    SCloudEventDecryptMetaData   metaData;
    SCloudEventDecryptData       decryptData;
    SCloudEventProgressData     progress;
    
} SCloudEventData;

struct SCloudEvent
{
    SCloudEventType           type;			/**< Type of event */
	SCloudEventData			 data;			/**< Event specific data */
    
};
typedef struct SCloudEvent SCloudEvent;

typedef int (*SCloudEventHandler)(SCloudContextRef      scloudRef,
SCloudEvent*            event,
void*                  uservalue);


#pragma mark SCloud Public Functions

SCLError    SCloudEncryptNew (void *contextStr,     size_t contextStrLen,
                              void *data,           size_t dataLen,
                              void *metaData,       size_t metaDataLen,
                              SCloudEventHandler        handler,
                              void*                     userValue,
                              SCloudContextRef          *scloudRefOut); 


SCLError	SCloudCalculateKey ( SCloudContextRef scloudRef, size_t blocksize) ;


SCLError    SCloudEncryptGetKeyBLOB( SCloudContextRef ctx,
                         uint8_t **outData, size_t *outSize);

__attribute__((deprecated))
SCLError	SCloudEncryptGetKey ( SCloudContextRef scloudRef,
                                 uint8_t * buffer, size_t *bufferSize);

__attribute__((deprecated))
SCLError	SCloudEncryptGetKeyREST ( SCloudContextRef ctx,
                                     uint8_t * buffer, size_t *bufferSize);

SCLError	SCloudEncryptGetLocator ( SCloudContextRef scloudRef,
                                     uint8_t * buffer, size_t *bufferSize);

SCLError	SCloudEncryptGetLocatorREST ( SCloudContextRef ctx, 
                                         uint8_t * buffer, size_t *bufferSize);

SCLError	SCloudEncryptNext ( SCloudContextRef cloudRef,
                               uint8_t *buffer, size_t *bufferSize);


SCLError    SCloudDecryptNew (uint8_t * key, size_t keyLen,
                              SCloudEventHandler    handler, 
                              void*                 userValue,
                              SCloudContextRef      *scloudRefOut); 


SCLError	SCloudDecryptNext ( SCloudContextRef scloudRef,
                               uint8_t *in, size_t inSize);

 
SCLError  SCloudGetVersionString(size_t	bufSize, char *outString);

void        SCloudFree (SCloudContextRef scloudRef  );


#endif /* Included_scloud_h */ /* ] */
