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

#ifndef Included_SCimp_h	/* [ */
#define Included_SCimp_h

#include "SCpubTypes.h"

#define SUPPORT_XML_MESSAGE_FORMAT      0
#define SCIMP_SHORT_VERSION_STRING		"1.0.3"
#define SCIMP_BUILD_NUMBER              44

#pragma mark
#pragma mark SCimp Public Defines

typedef struct SCimpContext *      SCimpContextRef;

/*____________________________________________________________________________
 Invalid values for each of the "ref" data types. Use these for assignment
 and initialization only. Use the SCXXXRefIsValid macros (below) to test
 for valid/invalid values.
 ____________________________________________________________________________*/

#define	kInvalidSCimpContextRef		((SCimpContextRef) NULL)

/*____________________________________________________________________________
 Macros to test for ref validity. Use these in preference to comparing
 directly with the kInvalidXXXRef values.
 ____________________________________________________________________________*/

#define SCimpContextRefIsValid( ref )		( (ref) != kInvalidSCimpContextRef )

#define NO_NEW_STATE    (INT_MAX -1)
#define ANY_STATE       INT_MAX

enum SCimpState_
{
    kSCimpState_Init             = 0,
    kSCimpState_Ready            = 1,
    kSCimpState_Error            = 2,
    
    /* Initiator State */
    kSCimpState_Commit           = 11,
    kSCimpState_DH2              = 12,
    
    /* Responder State */
    kSCimpState_DH1              = 21,
    kSCimpState_Confirm        = 22,
    
    ENUM_FORCE( SCimpState_ )
};

ENUM_TYPEDEF( SCimpState_, SCimpState  );


/*____________________________________________________________________________
 SCimp protocol Messages	
 ____________________________________________________________________________*/

/*
 
 Suite	Hash                KDF MAC			Cipher		PK
 1		SHA-256             HMAC/SHA-256	AES-128     ECC-384
 2		SHA-512/256         HMAC/SHA-512	AES-256     ECC-384
 3		SKEIN-512/256       SKEINMAC-512	AES-256     ECC-384
 
*/

enum SCimpCipherSuite_
{
    kSCimpCipherSuite_Invalid                       = 0,
    kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384     = 1,
    kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384  = 2,
    kSCimpCipherSuite_SKEIN_AES256_ECC384           =3,
       
    ENUM_FORCE( SCimpCipherSuite_ )
};
ENUM_TYPEDEF( SCimpCipherSuite_, SCimpCipherSuite   );
  
enum SCimpSAS_
{
    kSCimpSAS_Invalid = 0,    
    kSCimpSAS_ZJC11 = 1,     /* 4 char Base 32 */
    kSCimpSAS_NATO  = 2,     /* NATO Phonetic Alphabet 4 words */
    kSCimpSAS_HEX   = 3,     /* Short Hex String */
    
    ENUM_FORCE( SCimpAS_ )
};
ENUM_TYPEDEF( SCimpSAS_, SCimpSAS   );


enum SCimpMsgFormat_
{
    kSCimpMsgFormat_Invalid = 0,    
    kSCimpMsgFormat_JSON    = 1,  
    
#if SUPPORT_XML_MESSAGE_FORMAT
    kSCimpMsgFormat_XML = 2,      
#endif       

    ENUM_FORCE( SCimpMsgFormat_ )
};
ENUM_TYPEDEF( SCimpMsgFormat_, SCimpMsgFormat   );


enum SCimpProperty_
{
    kSCimpProperty_Invalid  = 0,
    
    /* Numeric Properties */
    kSCimpProperty_CipherSuite,
    kSCimpProperty_SASMethod,
    kSCimpProperty_MsgFormat,
    kSCimpProperty_SCIMPstate,
    
    
    /* Data Properties */
    kSCimpProperty_SharedSecret,
    kSCimpProperty_NextSecret,
    kSCimpProperty_SASstring,
    
    ENUM_FORCE( SCimpProperty_ )
};

typedef struct SCimpInfo
{
    uint8_t                 version;        /* protocol version */
    SCimpCipherSuite        cipherSuite;
    SCimpSAS                sasMethod;
    
    bool                    isReady;        /* are we connected & Keyed ? */
    bool                    isInitiator;    /* this is the initiator */
    bool                    hasCs;          /* has existing shared secret */
    bool                    csMatches;      /* hashes of cached shared secret match */
    
} SCimpInfo;


ENUM_TYPEDEF( SCimpProperty_, SCimpProperty   );

enum SCimpEventType_
{
    kSCimpEvent_NULL             = 0,
    kSCimpEvent_Error,
    kSCimpEvent_Warning,
    kSCimpEvent_SendPacket,
    kSCimpEvent_Keyed,
    kSCimpEvent_ReKeying,
    kSCimpEvent_Decrypted,
    kSCimpEvent_ClearText,
    kSCimpEvent_Shutdown,
    kSCimpEvent_Transition,
    kSCimpEvent_AdviseSaveState,
     
    ENUM_FORCE( SCimpEvent_ )
};
ENUM_TYPEDEF( SCimpEventType_, SCimpEventType  );

typedef struct SCimpEventSendData_
{
    uint8_t*            data; 
    size_t              length;
} SCimpEventSendData;

typedef struct SCimpEventDecryptData_
{
    uint8_t*            data; 
    size_t              length;
} SCimpEventDecryptData;

 
typedef struct SCimpEventClearText_
{
    uint8_t*            data; 
    size_t              length;
} SCimpEventClearText;

typedef struct SCimpEventKeyedData_
{
    SCimpInfo    info;
} SCimpEventKeyedData;
 
typedef struct SCimpEventErrorData_
{
    SCLError    error;
} SCimpEventErrorData;

 
typedef struct SCimpEventWarningData_
{
    SCLError    warning;
} SCimpEventWarningData;


typedef struct SCimpEventTransitionData_
{
    SCimpState    state;
} SCimpEventTransitionData;

typedef union SCimpEventData
{
    SCimpEventErrorData         errorData;
    SCimpEventWarningData       warningData;
    
    SCimpEventKeyedData         keyedData;
    SCimpEventKeyedData         rekeyedData;
    SCimpEventSendData          sendData;
    SCimpEventDecryptData       decryptData;
    SCimpEventClearText         clearText;
    SCimpEventTransitionData    transData;

} SCimpEventData;


struct SCimpEvent
{
    SCimpEventType			 type;			/**< Type of event */
    void*                    userRef;       /* optional userref passed in by SCimpSendMsg or SCimpProcessPacket */
	SCimpEventData			 data;			/**< Event specific data */
};
typedef struct SCimpEvent SCimpEvent;
 

SCLError SCimpNew(
          const char*           meStr, 
          const char*           youStr,
          SCimpContextRef *     outScimp 
          );


SCLError SCimpGetInfo( SCimpContextRef scimp, SCimpInfo* info);

void     SCimpFree(SCimpContextRef scimp);

SCLError SCimpGetNumericProperty( SCimpContextRef scimp,
                             SCimpProperty whichProperty, 
                             uint32_t *prop);

SCLError SCimpSetNumericProperty( SCimpContextRef scimp,
                             SCimpProperty whichProperty, 
                             uint32_t prop);

SCLError SCimpGetDataProperty( SCimpContextRef scimp,
                          SCimpProperty whichProperty, 
                          void *buffer, size_t bufSize, size_t *datSize);

SCLError SCimpGetAllocatedDataProperty( SCimpContextRef scimp,
                                   SCimpProperty whichProperty, 
                                   void **outData, size_t *datSize);

SCLError SCimpSetDataProperty( SCimpContextRef scimp,
                          SCimpProperty whichProperty, 
                          void *data,  size_t  datSize);

SCLError SCimpStartDH(SCimpContextRef scimp);  

SCLError SCimpSaveState(SCimpContextRef scimp,  uint8_t *key, size_t  keyLen, void **outBlob, size_t *blobSize);

SCLError SCimpRestoreState( uint8_t *key, size_t  keyLen, void *blob, size_t blobSize,  SCimpContextRef *scimp);

SCLError SCimpProcessPacket(
                         SCimpContextRef     scimp, 
                         uint8_t*            data, 
                         size_t              dataLen,
                         void*               userRef);


SCLError SCimpSendMsg(SCimpContextRef  scimp, 
                      void*            data, 
                      size_t           dataLen,
                      void*            userRef );

SCLError SCimpAcceptSecret(SCimpContextRef ctx);

/* callback stuff */
 
typedef int (*ScimpEventHandler)(SCimpContextRef    scimp, 
                                 SCimpEvent*        event,
                                 void*              uservalue);

SCLError SCimpSetEventHandler(SCimpContextRef scimp, ScimpEventHandler handler, void* userValue);

SCLError SCimpEnableTransitionEvents(SCimpContextRef  scimp, bool enable);
 
SCLError  SCimpGetVersionString(size_t	bufSize, char *outString);
 

#endif /* Included_SCimp_h */ /* ] */
