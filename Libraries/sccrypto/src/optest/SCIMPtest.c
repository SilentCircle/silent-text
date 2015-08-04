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
//  SCIMPtest.c
//  sccrypto
//
//  Created by Vinnie Moscaritolo on 10/29/14.
//
//

#include <limits.h>
#include <stdio.h>
#include <sys/param.h>

#include "SCcrypto.h"
#include "crypto_optest.h"

static char *banter[] = {
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

#define FREE_RESULT(_rslt_) { SCimpFreeEventBlock(_rslt_); _rslt_= NULL; }
#define FREE_DATA(_data_) { XFREE(_data_); _data_= NULL; }

typedef  struct {
    char*           data;
    size_t          dataLen;
    
    SCimpContextRef scimpI;
    SCimpContextRef scimpR;
    
    SCKeyContextRef  privKeyR;
    
} scimp_handler_info;




static bool inSyncMode;

static char *scimp_msg_type_table(SCimpMsg_Type  msgType)
{
    switch (msgType )
    {
        case kSCimpMsg_Commit: 		return (("Commit"));
        case kSCimpMsg_DH1: 		return (("DH1"));
        case kSCimpMsg_DH2: 		return (("DH2"));
        case kSCimpMsg_Confirm:     return (("Confirm"));
        case kSCimpMsg_Data: 		return (("Data"));
        case kSCimpMsg_PubData:     return (("PubData"));
        case kSCimpMsg_PKstart: 		return (("PKstart"));
        case kSCimpMsg_ClearText:   	return (("CLRtxt"));
            
        default:				return (("Invalid"));
    }
}

static SCLError sLOG_SCIMP_Info(unsigned int logLevel, SCimpContextRef ctx)
{
    SCLError     err  = kSCLError_NoErr;
    SCimpInfo    info;
    char *SASstr = NULL;
    
    if(gLogLevel & logLevel)
    {
         err = SCimpGetInfo(ctx, &info); CKERR;
        
        OPTESTPrintF("\t\t\t%12s: %02x\n","Version", info.version);
        OPTESTPrintF("\t\t\t%12s: %02x %s\n","cipherSuite", info.cipherSuite, scimp_suite_table(info.cipherSuite));
        
        OPTESTPrintF("\t\t\t%12s: %02x\n","SAS method", info.sasMethod);
        
        OPTESTPrintF("\t\t\t%12s: %s\n","SCIMP method", scimp_method_table(info.scimpMethod));
        
        OPTESTPrintF("\t\t\t%12s: %s\n","Keyed", info.isReady?"TRUE":"FALSE");
        OPTESTPrintF("\t\t\t%12s: %s\n","Has CS", info.hasCs?"TRUE":"FALSE");
        OPTESTPrintF("\t\t\t%12s: %s\n","CS Matches", info.csMatches?"TRUE":"FALSE");
        
        
        SCimpGetAllocatedDataProperty(ctx, kSCimpProperty_SASstring, (void*) &SASstr, NULL);
        OPTESTPrintF("\t\t\t%12s: |%s|\n","SAS", SASstr?SASstr:"<NULL>");
        OPTESTPrintF("\n");
 
    }
    
done:
    if(SASstr) XFREE(SASstr);
    return err;
}


static SCLError sEventHandler(SCimpContextRef ctx, SCimpEvent* event, void* userData)
{
    SCLError     err  = kSCLError_NoErr;
  
    SCimpInfo     scimpInfo;
    
    scimp_handler_info *info = (scimp_handler_info*)userData;
    
    SCimpContextRef otherCtx =  (ctx == info->scimpR?info->scimpI:info->scimpR);
    
    SCimpGetInfo(ctx, &scimpInfo); CKERR;
    
    
    if(scimpInfo.cipherSuite == kSCimpCipherSuite_Symmetric_AES128
    || scimpInfo.cipherSuite == kSCimpCipherSuite_Symmetric_AES128)
        OPTESTLogDebug("\t\t\t   EVENT (%2d, %s) -  ", event->type, scimpInfo.isInitiator?"Initiator":"Responder");
    else
        OPTESTLogDebug("\t\t\t   EVENT (%2d, %s <%s>) -  ", event->type, scimpInfo.isInitiator?"Initiator":"Responder", scimpInfo.meStr);

    switch(event->type)
    {
        case kSCimpEvent_SendPacket:
        {
            SCimpEventSendData  *d =    &event->data.sendData;
            
            OPTESTLogDebug("SEND PACKET %s (%d)  id='%s' \n",
                   d->shouldPush?"PUSH": "NOPUSH",
                   (int)d->length,
                   event->userRef?(char*)event->userRef:"none");
   //         OPTESTLogDebug("|%.*s|\n\n", (int)d->length, d->data);
            
            if(!inSyncMode)
            {
                err = SCimpProcessPacket(otherCtx,event->data.sendData.data, event->data.sendData.length,  NULL);
  
            }
            break;
        };
            
        case kSCimpEvent_Keyed:
        {
            SCimpInfo  *d =    &event->data.keyedData.info;
            char *SASstr = NULL;
            
            OPTESTLogDebug("KEYED\n" );
            OPTESTLogDebug("\t\t\t%12s: %02x\n","Version", d->version);
            OPTESTLogDebug("\t\t\t%12s: %02x\n","cipherSuite", d->cipherSuite);
            OPTESTLogDebug("\t\t\t%12s: %s\n","SCIMP method", scimp_method_table(d->scimpMethod));
            
            OPTESTLogDebug("\t\t\t%12s: %02x\n","SAS method", d->sasMethod);
            
            SCimpGetAllocatedDataProperty(ctx, kSCimpProperty_SASstring, (void*) &SASstr, NULL);
            OPTESTLogDebug("\t\t\t%12s: |%s|\n","SAS", SASstr?SASstr:"<NULL>");
            OPTESTLogDebug("\t\t\t%12s: %s\n","CS Matches", d->csMatches?"TRUE":"FALSE");
            
            if(SASstr) XFREE(SASstr);
            OPTESTLogDebug("\n");
            
            if(!inSyncMode)
            {

                if(d->scimpMethod == kSCimpMethod_DH)
                {
    //                OPTESTLogDebug("\t\t\t   Accept the new secrets\n\n");
                    err = SCimpAcceptSecret(ctx); CKERR;
                }
                
            }
            
        }
            break;
 
        case kSCimpEvent_Decrypted:
        {
            SCimpEventDecryptData  *d =    &event->data.decryptData;
            
            OPTESTLogDebug("DECRYPTED (%d) id='%s'\n", (int)d->length,
                   event->userRef?(char*)event->userRef:"none");
            
            OPTESTLogDebug("\t|%.*s|\n", (int)d->length, d->data);
            
            err = compare2Results(info->data, info->dataLen, d->data, d->length, kResultFormat_Byte, "Decrypted");
         }
              break;
            
            
        case kSCimpEvent_PubData:
        {
            SCimpEventPubData  *d =    &event->data.pubData;
            
            OPTESTLogDebug("PUB DECRYPTED (%d) id='%s'\n", (int)d->length,
                           event->userRef?(char*)event->userRef:"none");
            
            OPTESTLogDebug("\t|%.*s|\n", (int)d->length, d->data);
            
            err = compare2Results(info->data, info->dataLen, d->data, d->length, kResultFormat_Byte, "Decrypted");
       

        }
            break;
            
            
        case kSCimpEvent_AdviseSaveState:
            OPTESTLogDebug("SAVE STATE\n");
            break;
             
            
        case kSCimpEvent_NeedsPrivKey:
        {
            SCimpEventNeedsPrivKeyData  *d =    &event->data.needsKeyData;
            
            OPTESTLogDebug("Scimp Needs %s PrivKey  %s\n",  sckey_suite_table(d->expectingKeySuite) , d->locator  );
            
            *(d->privKey) = info->privKeyR;
        }
            
            break;

        case kSCimpEvent_Error:
        {
            SCimpEventErrorData  *d =    &event->data.errorData;
            char str[256];
            
            SCCrypto_GetErrorString(d->error, sizeof(str), str);
            OPTESTLogError("Error %d:  %s\n", err, str);
        }
            break;
            
        case kSCimpEvent_Warning:
        {
            SCimpEventWarningData *d =    &event->data.warningData;
            char str[256];
            
            SCCrypto_GetErrorString(d->warning, sizeof(str), str);
            OPTESTLogError("Warning %d:  %s\n", err, str);
        }
            break;
            
        case kSCimpEvent_Transition:
        {
            SCimpEventTransitionData *d =    &event->data.transData;

            OPTESTLogDebug("TRANS -> %s (%s)\n",  scimp_stateInfo_table(d->state), scimp_method_table(d->method));
            
        }
            break;
          
        case kSCimpEvent_LogMsg:
        {
            SCimpEventLoggingData *d =    &event->data.loggingData;
            
              OPTESTLogDebug("Msg %-3s %-6s:\n", d->isOutgoing?"OUT":"IN", scimp_msg_type_table(d->msg->msgType));
        }
            break;
            

        default:
            OPTESTLogError("OTHER %d\n", event->type);
            break;
    }
 
    
done:
    return err;
}


static SCLError sCreateSCIMPStorageKey(SCKeySuite keySuite, SCKeyContextRef * keyOut)
{
    SCLError        err = kSCLError_NoErr;
    SCKeyContextRef storageKey = kInvalidSCKeyContextRef;
    
    Cipher_Algorithm    algorithm = kCipher_Algorithm_Invalid;
    size_t              symKeyLen = 0;
    
    
    typedef struct {
        uint8_t 	*data;
        size_t     len;
    }storage_entry;
    
    
    uint8_t    deviceUUID[32];
    uint8_t    IV[32];
    
    // we use the UUID only as a nonce, it should be unique but doesnt have to be secure
    err =  RNG_GetBytes(deviceUUID,sizeof(deviceUUID));
    
    // generate a 128 bit storagre key and a 128 bit IV
    err =  RNG_GetBytes(IV,sizeof(IV));
    
    err = SCKeyCipherForKeySuite(keySuite, &algorithm, &symKeyLen);  CKERR;
    
    OPTESTLogVerbose("\t\tCreate %s encyption key\n",cipher_algor_table(algorithm));
    err = SCKeyNew(keySuite, deviceUUID, sizeof(deviceUUID), &storageKey); CKERR;
    err = SCKeySetProperty (storageKey, kSCKeyProp_IV, SCKeyPropertyType_Binary,  IV   , symKeyLen); CKERR;
    
    if(keyOut)
        *keyOut = storageKey;
done:
    return err;
};


SCKeySuite scSCimpCipherAlgorithm(SCimpCipherSuite  suite)
{
    SCKeySuite keySuite = kSCKeySuite_Invalid;
    
    switch(suite)
    {
        case kSCimpCipherSuite_SKEIN_2FISH_ECC414:
            keySuite = kSCKeySuite_2FISH256;
            break;
            
        case kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384:
        case kSCimpCipherSuite_Symmetric_AES128:
            keySuite = kSCKeySuite_AES128;
             break;
            
        case kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384:
        case kSCimpCipherSuite_SKEIN_AES256_ECC384:
        case kSCimpCipherSuite_Symmetric_AES256:
            keySuite = kSCKeySuite_AES256;
          break;
            
        default:
            break;
            
    }
    
    return keySuite;
}


static SCLError sCompareKeyingInfo( SCimpContextRef scimpI,  SCimpContextRef scimpR)
{
    SCLError          err   = kSCLError_NoErr;
    
    SCimpInfo    InfoI;
    SCimpInfo    InfoR;
    char *SASstrI = NULL;
    char *SASstrR = NULL;
    
    OPTESTLogVerbose("\t\t\tCompare Keying Info.");
    
    err = SCimpGetInfo(scimpI, &InfoI); CKERR;
    err = SCimpGetInfo(scimpR, &InfoR); CKERR;
    
   
    ASSERTERR(InfoI.version != InfoR.version , kSCLError_SelfTestFailed);
    
    if(InfoI.version == 1)
    {
        // V1 of SCIMP will always defer to ECC 384 cipherSuite
        // so you can only test for algorithm slection in that case
        ASSERTERR(InfoI.cipherSuite != kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384 , kSCLError_SelfTestFailed);
      }
    
    ASSERTERR(InfoI.cipherSuite != InfoR.cipherSuite , kSCLError_SelfTestFailed);
    ASSERTERR(InfoI.sasMethod != InfoR.sasMethod , kSCLError_SelfTestFailed);
    ASSERTERR(InfoI.scimpMethod != InfoR.scimpMethod , kSCLError_SelfTestFailed);
    
    SCimpGetAllocatedDataProperty(scimpI, kSCimpProperty_SASstring, (void*) &SASstrI, NULL);
    SCimpGetAllocatedDataProperty(scimpR, kSCimpProperty_SASstring, (void*) &SASstrR, NULL);
    err = compare2Results(SASstrI, strlen(SASstrI), SASstrR, strlen(SASstrR), kResultFormat_Byte, "SAS String");
    
    OPTESTLogVerbose(" SAS = |%s|", SASstrI?SASstrI:"<NULL>");

done:
    
    OPTESTLogVerbose("\n");
    
    if(IsntNull(SASstrR))
        XFREE(SASstrR);
    
    if(IsntNull(SASstrI))
        XFREE(SASstrI);
    
    return err;
}

static SCLError sSCMIPpublicTest(SCimpCipherSuite cipherSuite, SCKeySuite publicKeySuite)
{
    SCLError          err   = kSCLError_NoErr;
    SCimpContextRef   scimpI = NULL;
    SCimpContextRef   scimpR = NULL;
    char*               nonce = "some stupid nonce data";

    time_t          startDate  = time(NULL) ;
    time_t          expireDate  = startDate + (3600 * 24);
    char*           user1 = "ed_snowden@silentcircle.com";

    SCKeyContextRef     privKey = kInvalidSCKeyContextRef;
    SCKeyContextRef     pubKey = kInvalidSCKeyContextRef;
  
    uint8_t*        keyData = NULL;
    size_t          keyDataLen = 0;

    SCKeyContextRef   storageKey = NULL;
    
    scimp_handler_info  handler_block;
    
    char            *bobStr     = "bob";
    char            *aliceStr   = "alice";
    
    OPTESTLogInfo("\t\tTesting SCIMP Public Key  Messaging for %s  \n", scimp_suite_table(cipherSuite));
    
    OPTESTLogVerbose("\t\t\tCreate Public/Private %s Keys\n", sckey_suite_table(publicKeySuite));
    err = SCKeyNew(publicKeySuite, (uint8_t*)nonce, strlen(nonce),  &privKey); CKERR;
    err = SCKeySetProperty (privKey, kSCKeyProp_Owner, SCKeyPropertyType_UTF8String, user1 , strlen(user1) ); CKERR;
    err = SCKeySetProperty(privKey, kSCKeyProp_StartDate,  SCKeyPropertyType_Time ,  &startDate, sizeof(time_t)); CKERR;
    err = SCKeySetProperty(privKey, kSCKeyProp_ExpireDate,  SCKeyPropertyType_Time ,  &expireDate, sizeof(time_t)); CKERR;
    
    err = SCKeySerialize(privKey, &keyData, &keyDataLen); CKERR;
    err = SCKeyDeserialize(keyData,  keyDataLen  , &pubKey); CKERR;
    XFREE(keyData); keyData = NULL;

    
    // create SCIMP endpoints for transporting keys
    
    /* Setup Initiator */
    err = SCimpNew(bobStr,
                   aliceStr,
                   &scimpI); CKERR;
    
    /* Setup Responder */
    err = SCimpNew(aliceStr,
                   bobStr,
                   &scimpR);CKERR;
    
    handler_block.scimpR    = scimpR;
    handler_block.privKeyR  = privKey;
    
    handler_block.scimpI = scimpI;
    
    err = SCimpSetNumericProperty(scimpI, kSCimpProperty_CipherSuite, cipherSuite);
    
    err = SCimpSetEventHandler(scimpI, sEventHandler, &handler_block); CKERR;
    err = SCimpSetEventHandler(scimpR, sEventHandler, &handler_block); CKERR;
    
    err = SCimpSetLoggingEventLevel(scimpI, kSCimpLogging_All) ; CKERR;
    err = SCimpSetLoggingEventLevel(scimpR, kSCimpLogging_All) ; CKERR;

    OPTESTLogVerbose("\t\t\tSend Test Messages\n");
 
    for(int i = 0; banter[i] != NULL; i++)
    {
        handler_block.data = banter[i];
        handler_block.dataLen = strlen(banter[i]);
 
        err = SCimpSendPublic( scimpI, pubKey, banter[i] ,strlen(banter[i]), NULL); CKERR;
        
    };
    
    
    OPTESTLogVerbose("\n");

    goto done;
    
done:
    if(keyData)
        XFREE(keyData);

    if(SCKeyContextRefIsValid(pubKey))
        SCKeyFree(pubKey);
    
    if(SCKeyContextRefIsValid(privKey))
        SCKeyFree(privKey);
  
    if(SCKeyContextRefIsValid(storageKey))
        SCKeyFree(storageKey);
    
    if(IsntNull(scimpI))
        SCimpFree(scimpI);
    
    if(IsntNull(scimpR))
        SCimpFree(scimpR);
    
    
    return err;
}


static SCLError sSCMIPtest1(SCimpCipherSuite cipherSuite)
{
    SCLError          err   = kSCLError_NoErr;
    SCimpContextRef   scimpI = NULL;
    SCimpContextRef   scimpR = NULL;
    
    SCKeyContextRef   storageKey = NULL;
    
    scimp_handler_info  handler_block;
    
    char            *bobStr     = "bob";
    char            *aliceStr   = "alice";
    
    OPTESTLogInfo("\t\tTesting SCIMP Messaging for %s  \n", scimp_suite_table(cipherSuite));
    
    err = sCreateSCIMPStorageKey(scSCimpCipherAlgorithm(cipherSuite), &storageKey); CKERR;
    
     /* Setup Initiator */
    err = SCimpNew(bobStr,
                   aliceStr,
                   &scimpI); CKERR;
    
    /* Setup Responder */
    err = SCimpNew(aliceStr,
                   bobStr,
                   &scimpR);CKERR;
    
    handler_block.scimpR = scimpR;
    handler_block.scimpI = scimpI;
    
    err = SCimpSetNumericProperty(scimpI,kSCimpProperty_SASMethod, kSCimpSAS_PGP); CKERR;
    err = SCimpSetNumericProperty(scimpI, kSCimpProperty_CipherSuite, cipherSuite);
    
    err = SCimpSetEventHandler(scimpI, sEventHandler, &handler_block); CKERR;
    err = SCimpSetEventHandler(scimpR, sEventHandler, &handler_block); CKERR;

    err = SCimpSetLoggingEventLevel(scimpI, kSCimpLogging_Keying) ; CKERR;
    err = SCimpSetLoggingEventLevel(scimpR, kSCimpLogging_Keying) ; CKERR;
    
    OPTESTLogVerbose("\t\t\tStart Key Exchange\n");
    err = SCimpStartDH(scimpI); CKERR;
    
    OPTESTLogDebug("\t\t\tInitiator Info\n" );
    sLOG_SCIMP_Info(OPTESTLOG_FLAG_DEBUG, scimpI);
    
    OPTESTLogDebug("\t\t\tResponder Info\n" );
    sLOG_SCIMP_Info(OPTESTLOG_FLAG_DEBUG, scimpR);

   err = sCompareKeyingInfo(scimpI, scimpR); CKERR;
    
    OPTESTLogVerbose("\t\t\tSend Test Messages\n");

    for(int i = 0; banter[i] != NULL; i++)
    {
        void * storageBlob = NULL;
        size_t  blobSize = 0;
        
        handler_block.data = banter[i];
        handler_block.dataLen = strlen(banter[i]);
        
        if(i&1)
        {
            err = SCimpEncryptState(scimpR, storageKey, &storageBlob, &blobSize); CKERR;
             SCimpFree(scimpR); scimpR = NULL;
             err = SCimpDecryptState(storageKey, storageBlob, blobSize, &scimpR); CKERR;
             err = SCimpSetEventHandler(scimpR, sEventHandler, &handler_block); CKERR;
  
             handler_block.scimpR = scimpR;
             XFREE(storageBlob);
        }
        else
        {
            err =  SCimpEncryptState(scimpI, storageKey, &storageBlob, &blobSize); CKERR;
            SCimpFree(scimpI); scimpI = NULL;
            err = SCimpDecryptState(storageKey, storageBlob, blobSize, &scimpI); CKERR;
            err = SCimpSetEventHandler(scimpI, sEventHandler, &handler_block); CKERR;

            handler_block.scimpI = scimpI;
            XFREE(storageBlob);
        }
    
        err = SCimpSendMsg( i&1?scimpR:scimpI, banter[i] ,strlen(banter[i]), NULL); CKERR;
        
    };
    
    OPTESTLogVerbose("\n");

done:
  
    if(SCKeyContextRefIsValid(storageKey))
        SCKeyFree(storageKey);
    
     if(IsntNull(scimpI))
        SCimpFree(scimpI);
    
    if(IsntNull(scimpR))
        SCimpFree(scimpR);
    

    return err;
}


static void sDumpResultBlock(SCimpContextRef ctx, SCimpResultBlock* resultsIn, void* userData)
{
    SCimpResultBlock* result = resultsIn;
    
    while (result)
    {
        SCimpResultBlock* nextResult = result->next;
        SCimpEvent  *event = &result->event;
        
        sEventHandler(ctx, event, userData);
        
        result = nextResult;
    }
    OPTESTLogDebug("\n");

}




static void sGetSendPacket(SCimpResultBlock* resultsIn, uint8_t **dataOut, size_t *lengthOut )
{
    SCimpResultBlock* result = resultsIn;
    
    *dataOut = NULL;
    *lengthOut = 0;
    
    while (result)
    {
        SCimpResultBlock* nextResult = result->next;
        SCimpEvent  *event = &result->event;
        
        if(event->type == kSCimpEvent_SendPacket)
        {
            size_t length = event->data.sendData.length;
            uint8_t* data = XMALLOC(length);
            COPY(event->data.sendData.data, data, length);
              *dataOut = data;
            *lengthOut = length;
            
            break;
        }
        
        result = nextResult;
    }
}

static void sGetDecryptedPacket(SCimpResultBlock* resultsIn, uint8_t **dataOut, size_t *lengthOut )
{
    SCimpResultBlock* result = resultsIn;
    
    *dataOut = NULL;
    *lengthOut = 0;
    
    while (result)
    {
        SCimpResultBlock* nextResult = result->next;
        SCimpEvent  *event = &result->event;
        
        if(event->type == kSCimpEvent_Decrypted)
        {
            size_t length = event->data.decryptData.length;
            uint8_t* data = XMALLOC(length);
            COPY(event->data.decryptData.data, data, length);
            *dataOut = data;
            *lengthOut = length;
            
            break;
        }
        
        result = nextResult;
    }
}

static SCLError sProcessSendingFromResultBlock(SCimpContextRef ctx1, SCimpContextRef ctx2,void* userData, SCimpResultBlock* resultsIn)
{
    SCLError          err   = kSCLError_NoErr;
    uint8_t*            data = NULL;
    size_t              dataLength = 0;
    scimp_handler_info  *handler_block = userData;
    
    sGetSendPacket(resultsIn, &data, &dataLength);
    
    if(data)
    {
        SCimpResultBlock* resultBlock;
        
        err = SCimpProcessPacketSync(ctx1, data, dataLength, &handler_block,  &resultBlock);
        FREE_DATA(data);
        data = NULL; dataLength = 0;
        sDumpResultBlock(ctx2, resultBlock, &handler_block);
        
        sGetSendPacket(resultsIn, &data, &dataLength);
        
        if(data)
        {
            err =  sProcessSendingFromResultBlock(ctx2, ctx1, userData, resultBlock ); CKERR;
        }
        
        FREE_RESULT(resultBlock);
      }
    
    
done:
    
    return err;
 }

static SCLError sSCMIPtestSyncAPIS(SCimpCipherSuite cipherSuite, SCKeySuite publicKeySuite )
{
    SCLError          err   = kSCLError_NoErr;
    SCimpContextRef   scimpI = NULL;
    SCimpContextRef   scimpR = NULL;
    
    SCKeyContextRef   storageKey = NULL;
    SCKeyContextRef     privKey = kInvalidSCKeyContextRef;
    SCKeyContextRef     pubKey = kInvalidSCKeyContextRef;

    SCimpResultBlock*   resultBlock = NULL;
    scimp_handler_info  handler_block;
    
    char            *bobStr     = "bob";
    char            *aliceStr   = "alice";
     bool  useSCIMP2 = publicKeySuite != kSCKeySuite_Invalid;
    
    
    OPTESTLogInfo("\t\tTesting SCIMP%s Sync API for %s \n", useSCIMP2?"-2":"", scimp_suite_table(cipherSuite));
    
    if(useSCIMP2)
    {
        time_t          startDate  = time(NULL) ;
        time_t          expireDate  = startDate + (3600 * 24);
        char*               nonce = "some stupid nonce data";
        uint8_t*        keyData = NULL;
        size_t          keyDataLen = 0;

        OPTESTLogVerbose("\t\t\tCreate Public/Private %s Keys\n", sckey_suite_table(publicKeySuite));
        err = SCKeyNew(publicKeySuite, (uint8_t*)nonce, strlen(nonce),  &privKey); CKERR;
        err = SCKeySetProperty (privKey, kSCKeyProp_Owner, SCKeyPropertyType_UTF8String, aliceStr , strlen(aliceStr) ); CKERR;
        err = SCKeySetProperty(privKey, kSCKeyProp_StartDate,  SCKeyPropertyType_Time ,  &startDate, sizeof(time_t)); CKERR;
        err = SCKeySetProperty(privKey, kSCKeyProp_ExpireDate,  SCKeyPropertyType_Time ,  &expireDate, sizeof(time_t)); CKERR;
        
        err = SCKeySerialize(privKey, &keyData, &keyDataLen); CKERR;
        err = SCKeyDeserialize(keyData,  keyDataLen  , &pubKey); CKERR;
        XFREE(keyData); keyData = NULL;
    }
    
    err = sCreateSCIMPStorageKey(scSCimpCipherAlgorithm(cipherSuite), &storageKey); CKERR;
    
    /* Setup Initiator */
    err = SCimpNew(bobStr,
                   aliceStr,
                   &scimpI); CKERR;
    
    /* Setup Responder */
    err = SCimpNew(aliceStr,
                   bobStr,
                   &scimpR);CKERR;
    
    
    err = SCimpSetNumericProperty(scimpI,kSCimpProperty_SASMethod, kSCimpSAS_PGP); CKERR;
    err = SCimpSetNumericProperty(scimpI, kSCimpProperty_CipherSuite, cipherSuite);

    err = SCimpSetLoggingEventLevel(scimpI, kSCimpLogging_All) ; CKERR;
    err = SCimpSetLoggingEventLevel(scimpR, kSCimpLogging_All) ; CKERR;

    err = SCimpEnableTransitionEvents(scimpI, true);
    err = SCimpEnableTransitionEvents(scimpR, true);
    
    err = SCimpSetEventHandler(scimpR, sEventHandler, &handler_block); CKERR;

    handler_block.scimpR = scimpR;
    handler_block.scimpI = scimpI;
    handler_block.privKeyR  = privKey;
    
    uint8_t*            data = NULL;
    size_t              dataLength = 0;
   
    inSyncMode = true;
    
    if(!useSCIMP2)
    {
        OPTESTLogVerbose("\t\t\tStart Key Exchange\n");
         // start commit
        err = SCimpStartDHSync(scimpI, &resultBlock); CKERR;
         sDumpResultBlock(scimpI, resultBlock, &handler_block);
        
        // process the keying chatter until done
         err =  sProcessSendingFromResultBlock(scimpR, scimpI,  &handler_block,  resultBlock); CKERR;
        FREE_RESULT(resultBlock);

        OPTESTLogDebug("\t\t\tInitiator Info\n" );
        sLOG_SCIMP_Info(OPTESTLOG_FLAG_DEBUG, scimpI);
        
        OPTESTLogDebug("\t\t\tResponder Info\n" );
        sLOG_SCIMP_Info(OPTESTLOG_FLAG_DEBUG, scimpR);
        
        err = sCompareKeyingInfo(scimpI, scimpR); CKERR;
        }
    
   
    OPTESTLogVerbose("\t\t\tSend, Receive and Compare Test Messages\n");
     for(int i = 0; banter[i] != NULL; i++)
    {
          handler_block.data = banter[i];
        handler_block.dataLen = strlen(banter[i]);
        
        if(useSCIMP2 && i ==0)
        {
            err = SCimpSendPKStartMsgSync(scimpI, pubKey,  banter[i] ,strlen(banter[i]), NULL,  &resultBlock); CKERR;
            sDumpResultBlock(scimpI, resultBlock, &handler_block);
            sGetSendPacket(resultBlock, &data, &dataLength);
            FREE_RESULT(resultBlock);
            
            err = SCimpProcessPacketSync(scimpR, data, dataLength, &handler_block,  &resultBlock);
            FREE_DATA(data);
            
            sDumpResultBlock(scimpR, resultBlock, &handler_block);
            
            sGetDecryptedPacket(resultBlock, &data, &dataLength);
            err = compare2Results(data, dataLength, banter[i] ,strlen(banter[i]), kResultFormat_Byte, "Decrypted");
            FREE_DATA(data);

            err =  sProcessSendingFromResultBlock(scimpI, scimpR,  &handler_block,  resultBlock); CKERR;
            FREE_RESULT(resultBlock);
            
            err = sCompareKeyingInfo(scimpI, scimpR); CKERR;
            
            

        }
        else if(i&1)
        {
            err = SCimpSendMsgSync(scimpR, banter[i] ,strlen(banter[i]), NULL,  &resultBlock); CKERR;
             sDumpResultBlock(scimpR, resultBlock, &handler_block);
            sGetSendPacket(resultBlock, &data, &dataLength);
            FREE_RESULT(resultBlock);
         
            err = SCimpProcessPacketSync(scimpI, data, dataLength, &handler_block,  &resultBlock);
            FREE_DATA(data);
            
            sDumpResultBlock(scimpI, resultBlock, &handler_block);
            sGetDecryptedPacket(resultBlock, &data, &dataLength);
            FREE_RESULT(resultBlock);
            
            err = compare2Results(data, dataLength, banter[i] ,strlen(banter[i]), kResultFormat_Byte, "Decrypted");
            FREE_DATA(data);

        }
        else
        {
            err = SCimpSendMsgSync(scimpI, banter[i] ,strlen(banter[i]), NULL,  &resultBlock); CKERR;
            sDumpResultBlock(scimpI, resultBlock, &handler_block);
            sGetSendPacket(resultBlock, &data, &dataLength);
            FREE_RESULT(resultBlock);
            
            err = SCimpProcessPacketSync(scimpR, data, dataLength, &handler_block,  &resultBlock);
            FREE_DATA(data);
            
            sDumpResultBlock(scimpR, resultBlock, &handler_block);
            sGetDecryptedPacket(resultBlock, &data, &dataLength);
            FREE_RESULT(resultBlock);
            
            err = compare2Results(data, dataLength, banter[i] ,strlen(banter[i]), kResultFormat_Byte, "Decrypted");
            FREE_DATA(data);
           
        }
    }

 
    OPTESTLogVerbose("\n");
    
done:
    inSyncMode = false;
    
    
    if(SCKeyContextRefIsValid(storageKey))
        SCKeyFree(storageKey);
    
    if(SCKeyContextRefIsValid(pubKey))
        SCKeyFree(pubKey);
    
    if(SCKeyContextRefIsValid(privKey))
        SCKeyFree(privKey);
    
    if(IsntNull(scimpI))
        SCimpFree(scimpI);
    
    if(IsntNull(scimpR))
        SCimpFree(scimpR);
    
    
    return err;

};

SCLError  TestSCIMP()
{
    SCLError    err = kSCLError_NoErr;
    char        version_string[32];
    
    inSyncMode = false;
    
    err = SCimpGetVersionString(sizeof(version_string), version_string); CKERR;
    
    OPTESTLogInfo("\tTesting SCIMP version: %s\n", version_string);
  
    // Sync API
    err =  sSCMIPtestSyncAPIS(kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384, kSCKeySuite_Invalid); CKERR;
    err =  sSCMIPtestSyncAPIS(kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384, kSCKeySuite_ECC384); CKERR;
    err =  sSCMIPtestSyncAPIS(kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384, kSCKeySuite_Invalid); CKERR;
    err =  sSCMIPtestSyncAPIS(kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384, kSCKeySuite_ECC384); CKERR;
    err =  sSCMIPtestSyncAPIS(kSCimpCipherSuite_SKEIN_AES256_ECC384, kSCKeySuite_Invalid); CKERR;
    err =  sSCMIPtestSyncAPIS(kSCimpCipherSuite_SKEIN_AES256_ECC384, kSCKeySuite_ECC384); CKERR;
    err =  sSCMIPtestSyncAPIS(kSCimpCipherSuite_SKEIN_2FISH_ECC414, kSCKeySuite_Invalid); CKERR;
    err =  sSCMIPtestSyncAPIS(kSCimpCipherSuite_SKEIN_2FISH_ECC414, kSCKeySuite_ECC384); CKERR;
    err =  sSCMIPtestSyncAPIS(kSCimpCipherSuite_SKEIN_2FISH_ECC414, kSCKeySuite_ECC414); CKERR;

        // V1 of SCIMP will always defer to ECC 384 cipherSuite
    err =  sSCMIPtest1(kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384); CKERR;
    err =  sSCMIPtest1(kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384   ); CKERR;
    err =  sSCMIPtest1(kSCimpCipherSuite_SKEIN_AES256_ECC384); CKERR;
    err =  sSCMIPtest1(kSCimpCipherSuite_SKEIN_2FISH_ECC414); CKERR;
    
    err =  sSCMIPpublicTest(kSCimpCipherSuite_SKEIN_2FISH_ECC414, kSCKeySuite_ECC414);
    err =  sSCMIPpublicTest(kSCimpCipherSuite_SKEIN_2FISH_ECC414, kSCKeySuite_ECC384);
    
    
done:
    
    return err;
}