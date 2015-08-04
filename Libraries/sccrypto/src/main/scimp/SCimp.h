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
#ifndef Included_SCimp_h	/* [ */
#define Included_SCimp_h

#include "SCpubTypes.h"
#include "SCkeys.h"

#define SUPPORT_XML_MESSAGE_FORMAT      0
#define SCIMP_SHORT_VERSION_STRING		"1.5.0"
#define SCIMP_BUILD_NUMBER              45

#ifdef __clang__
#pragma mark
#pragma mark SCimp Public Defines
#endif

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
    
    kSCimpState_PKInit           = 13,      /* scimp 2 - pkstart info ready, waiting for first send */
    kSCimpState_PKStart          = 14,      /* scimp 2 - pkstart  sent, waiting for DH1 from other side */
    kSCimpState_PKCommit         = 15,      /* scimp 2 - pkstart was received, sent DH1         */
    
    kSCimpState_DH1              = 21,
    kSCimpState_Confirm          = 22,

 
    ENUM_FORCE( SCimpState_ )
};

ENUM_TYPEDEF( SCimpState_, SCimpState  );


/*____________________________________________________________________________
 SCimp protocol Messages	
 ____________________________________________________________________________*/

/*
 
 Suite	Hash                KDF MAC			Cipher          PK
 1		SHA-256             HMAC/SHA-256	AES-128         ECC-384
 2		SHA-512/256         HMAC/SHA-512	AES-256         ECC-384
 3		SKEIN-512/256       SKEINMAC-512	AES-256         ECC-384

 6		SKEIN-512/256       SKEINMAC-512	TWOFISH-256     ECC-414

*/

enum SCimpCipherSuite_
{
    kSCimpCipherSuite_Invalid                       = 0,
    kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384     = 1,
    kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384  = 2,
    kSCimpCipherSuite_SKEIN_AES256_ECC384           =3,
 
    kSCimpCipherSuite_Symmetric_AES128              = 4,
    kSCimpCipherSuite_Symmetric_AES256              = 5,
    
    kSCimpCipherSuite_SKEIN_2FISH_ECC414            =6,
    
    // kSCimpCipherSuite_SKEIN_AES256_ECC414 was a mistake, the  algorithm was actually 2FISH

#if defined(ANDROID) ||  defined(__GNUC__)
        kSCimpCipherSuite_SKEIN_AES256_ECC414 = kSCimpCipherSuite_SKEIN_2FISH_ECC414 ,
#else
        kSCimpCipherSuite_SKEIN_AES256_ECC414 __attribute__((deprecated)) = kSCimpCipherSuite_SKEIN_2FISH_ECC414 ,
#endif
    
    
    ENUM_FORCE( SCimpCipherSuite_ )
};
ENUM_TYPEDEF( SCimpCipherSuite_, SCimpCipherSuite   );

enum SCimpSAS_
{
    kSCimpSAS_Invalid = 0,    
    kSCimpSAS_ZJC11 = 1,     /* 4 char Base 32 */
    kSCimpSAS_NATO  = 2,     /* NATO Phonetic Alphabet 4 words */
    kSCimpSAS_HEX   = 3,     /* Short Hex String */
    kSCimpSAS_PGP   = 4,     /* PGP Words */
    
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


enum SCimpMethod_
{
    kSCimpMethod_Invalid    = 0,
    kSCimpMethod_DH         = 1,        /* Scimp version 1 DH key exchange*/
    kSCimpMethod_Symmetric  = 2,        /* Scimp symmetric  */
    kSCimpMethod_PubKey     = 3,        /* Scimp 2 Public Key  */
    kSCimpMethod_DHv2       = 4,        /* Scimp version 2 DH key exchange  */
    
    ENUM_FORCE( SCimpMethod_ )
};
ENUM_TYPEDEF( SCimpMethod_, SCimpMethod    );

enum SCimpProperty_
{
    kSCimpProperty_Invalid  = 0,
    
    /* Numeric Properties */
    kSCimpProperty_CipherSuite = 1,
    kSCimpProperty_SASMethod   = 2,
    kSCimpProperty_MsgFormat   = 3,
    kSCimpProperty_SCIMPstate  = 4,
    kSCimpProperty_SCIMPmethod = 5,
    
    /* Data Properties */
    kSCimpProperty_SharedSecret = 20,
    kSCimpProperty_NextSecret   = 21,
    kSCimpProperty_SASstring    = 22,
 
    
    /* Time Properties */
    kSCimpProperty_KeyedTime    = 30,
    
    ENUM_FORCE( SCimpProperty_ )
};

enum SCimpLogging_
{
    kSCimpLogging_None      = 0,
    kSCimpLogging_Keying    = (1 << 0),
    kSCimpLogging_Data      = (1 << 1), /* log kSCimpMsg_Data */
    
    ENUM_FORCE( SCimpLogging_ )
};
ENUM_TYPEDEF( SCimpLogging_, SCimpLogging   );

#define kSCimpLogging_All (kSCimpLogging_Keying | kSCimpLogging_Data)


/* packet detail defines  
  previously from SCimpPriv.h */


#pragma pack(push, 1)

#define SCIMP_MAC_LEN           8
#define SCIMP_HASH_LEN          32
#define SCIMP_TAG_LEN           8

enum SCimpMsg_Type_
{
    kSCimpMsg_Invalid    = 0,
    kSCimpMsg_Commit     = 10,
    kSCimpMsg_DH1        = 11,
    kSCimpMsg_DH2        = 12,
    kSCimpMsg_Confirm    = 13,
    
    kSCimpMsg_Data       = 20,
    kSCimpMsg_PubData    = 21,
    kSCimpMsg_PKstart    = 22,
    
    kSCimpMsg_ClearText   = 30,
    
    ENUM_FORCE( SCimpMsg_Type_ )
};
ENUM_TYPEDEF( SCimpMsg_Type_, SCimpMsg_Type   );


typedef struct  {
    uint8_t        version;
    uint8_t        cipherSuite;
    uint8_t        sasMethod;
    
    char           *locator;
    uint8_t        *pk;
    size_t         pkLen;
    
    uint8_t        Hpki[SCIMP_HASH_LEN];
    
    uint16_t       seqNum;
    uint8_t        tag[SCIMP_TAG_LEN];
    uint8_t        *msg;
    size_t         msgLen;
    
} SCimpMsg_PKstart;


typedef struct  {
    uint8_t        version;
    uint8_t        cipherSuite;
    uint8_t        sasMethod;
    uint8_t        Hpki[SCIMP_HASH_LEN];
    uint8_t        Hcs[SCIMP_MAC_LEN];
} SCimpMsg_Commit;


typedef struct  {
    uint8_t        *pk;
    size_t         pkLen;
    uint8_t        Hcs[SCIMP_MAC_LEN];
} SCimpMsg_DH1;

typedef struct  {
    uint8_t        *pk;
    size_t         pkLen;
    uint8_t        Maci[SCIMP_MAC_LEN];
} SCimpMsg_DH2;

typedef struct  {
    uint8_t        Macr[SCIMP_MAC_LEN];
} SCimpMsg_Confirm;

typedef struct  {
    uint16_t       seqNum;
    uint8_t        tag[SCIMP_TAG_LEN];
    uint8_t        *msg;
    size_t         msgLen;
    
} SCimpMsg_Data;


typedef struct  {
    uint8_t        *msg;
    size_t         msgLen;
} SCimpMsg_ClearTxt;

typedef struct  {
    uint8_t        version;
    uint8_t        cipherSuite;
    
    char           *locator;
    uint8_t         *esk;
    size_t          eskLen;
    
    uint8_t        tag[SCIMP_TAG_LEN];
    uint8_t        *msg;
    size_t         msgLen;
} SCimpMsg_PubData;

#pragma pack(pop)

typedef struct SCimpMsg  * SCimpMsgPtr;

typedef struct SCimpMsg
{
    SCimpMsgPtr             next;
    SCimpMsg_Type           msgType;
    void*                   userRef;
    union
    {
        SCimpMsg_Commit     commit;
        SCimpMsg_PKstart    pkstart;
        SCimpMsg_DH1        dh1;
        SCimpMsg_DH2        dh2;
        SCimpMsg_Confirm    confirm;
        SCimpMsg_Data       data;
        SCimpMsg_ClearTxt   clearTxt;
        SCimpMsg_PubData    pubData;
    };
    
}SCimpMsg;


/* end packet defines */


typedef struct SCimpInfo
{
    uint8_t                 version;        /* protocol version */
    SCimpCipherSuite        cipherSuite;
    SCimpSAS                sasMethod;
    SCimpMethod             scimpMethod;
    
    bool                    isReady;        /* are we connected & Keyed ? */
    bool                    isInitiator;    /* this is the initiator */
    bool                    hasCs;          /* has existing shared secret */
    bool                    csMatches;      /* hashes of cached shared secret match */
    bool                    canPKstart;      /* can do public Key Start*/
    
    time_t                  keyedTime;      /* date/time last keyed */
    
    const char*             meStr;
    const char*             youStr;

    SCimpState              state;
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
    kSCimpEvent_PubData,
    kSCimpEvent_NeedsPrivKey,
    kSCimpEvent_LogMsg,
    
    ENUM_FORCE( SCimpEvent_ )
};
ENUM_TYPEDEF( SCimpEventType_, SCimpEventType  );

 
typedef struct SCimpEventNeedsPrivKey_
{
    char*               locator;
    SCKeyContextRef     *privKey;
    SCKeySuite          expectingKeySuite;
    
} SCimpEventNeedsPrivKeyData;

typedef struct SCimpEventSendData_
{
    uint8_t*            data; 
    size_t              length;
    bool                shouldPush;
    bool                isPKdata;
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

typedef struct SCimpEventPubData_
{
    uint8_t*            data;
    size_t              length;
} SCimpEventPubData;

 
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
    SCimpMethod   method;
} SCimpEventTransitionData;


typedef struct SCimpEventLoggingData_
{
    bool        isOutgoing;
    SCimpMsg*   msg;
    
} SCimpEventLoggingData;

typedef union SCimpEventData
{
    SCimpEventErrorData         errorData;
    SCimpEventWarningData       warningData;
    
    SCimpEventKeyedData         keyedData;
    SCimpEventKeyedData         rekeyedData;
 
    SCimpEventSendData          sendData;
    SCimpEventDecryptData       decryptData;
    SCimpEventPubData           pubData;
    SCimpEventClearText         clearText;
    SCimpEventTransitionData    transData;
    SCimpEventNeedsPrivKeyData  needsKeyData;
    SCimpEventLoggingData       loggingData;

} SCimpEventData;



struct SCimpEvent
{
    SCimpEventType			 type;			/**< Type of event */
    void*                    userRef;       /* optional userref passed in by SCimpSendMsg or SCimpProcessPacket */
    SCimpEventData			 data;			/**< Event specific data */
};
typedef struct SCimpEvent SCimpEvent;


/// sync API

typedef struct SCimpResultBlock SCimpResultBlock;
struct SCimpResultBlock
{
    SCimpEvent          event;
    SCimpResultBlock *  next;
    
};
 
SCLError SCimpStartDHSync(SCimpContextRef ctx,
                          SCimpResultBlock **results);


SCLError SCimpProcessPacketSync(
                                SCimpContextRef         scimp,
                                uint8_t*                data,
                                size_t                  dataLen,
                                void*                   userRef,
                                SCimpResultBlock        **results);


SCLError SCimpSendMsgSync(SCimpContextRef  scimp,
                          void*                 data,
                          size_t                dataLen,
                          void*                 userRef,
                          SCimpResultBlock      **results );

SCLError SCimpSendPKStartMsgSync(SCimpContextRef      scimp,
                                SCKeyContextRef      pubKey,
                                void *               data,
                                size_t               dataLen,
                                void *               userRef,
                                 SCimpResultBlock ** resultsOut );

SCLError SCimpSendPublicSync(SCimpContextRef    scimp,
                             SCKeyContextRef        pubKey,
                             void*                  data,
                             size_t                 dataLen,
                             void*                  userRef,
                             SCimpResultBlock       **results );

SCLError SCimpFreeEventBlock(SCimpResultBlock *results );

/////////////

SCLError SCimpNew(
          const char*           meStr, 
          const char*           youStr,
          SCimpContextRef *     outScimp 
          );


SCLError SCimpNewSymmetric( SCKeyContextRef      key,
                            const char*          threadStr,
                            SCimpContextRef *    outScimp
                            );


SCLError SCimpUpdateSymmetricKey( SCimpContextRef       ctx,
                                 const char*          threadStr,
                                 SCKeyContextRef      key  );

SCLError SCimpGetInfo( SCimpContextRef scimp, SCimpInfo* info);

void     SCimpFree(SCimpContextRef scimp);

SCLError SCimpGetNumericProperty( SCimpContextRef scimp,
                             SCimpProperty whichProperty, 
                             uint32_t *prop);


SCLError SCimpGetTimeProperty( SCimpContextRef scimp,
                                 SCimpProperty whichProperty,
                                 time_t *prop);

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

SCLError SCimpSetPrivateKey(SCimpContextRef    scimp,
                            SCKeyContextRef    privKey );


SCLError SCimpStartPublicKey(SCimpContextRef    ctx,
                             SCKeyContextRef    pubKey,
                             time_t             expireDate );

SCLError SCimpResetKeys(SCimpContextRef ctx);

DEPRECATED(SCLError SCimpSaveState(SCimpContextRef scimp,  uint8_t *key, size_t  keyLen, void **outBlob, size_t *blobSize));

DEPRECATED(SCLError SCimpRestoreState( uint8_t *key, size_t  keyLen, void *blob, size_t blobSize,  SCimpContextRef *scimp));

SCLError SCimpEncryptState(SCimpContextRef ctx,  SCKeyContextRef storageKey, void **outBlob, size_t *blobSize);

SCLError SCimpDecryptState(SCKeyContextRef storageKey, void *blob, size_t blobSize,  SCimpContextRef *scimp);

SCLError SCimpProcessPacket(
                         SCimpContextRef     scimp, 
                         uint8_t*            data, 
                         size_t              dataLen,
                         void*               userRef);


SCLError SCimpSendMsg(SCimpContextRef  scimp, 
                      void*            data, 
                      size_t           dataLen,
                      void*            userRef );
 
SCLError SCimpSendPublic(SCimpContextRef  scimp,
                         SCKeyContextRef  pubKey,
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

SCLError SCimpSetLoggingEventLevel(SCimpContextRef  scimp, SCimpLogging level);

SCLError  SCimpGetVersionString(size_t	bufSize, char *outString);
 

#endif /* Included_SCimp_h */ /* ] */
