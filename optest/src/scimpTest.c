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
 
#include <tomcrypt.h>

#include "SCpubTypes.h"
#include "cryptowrappers.h"
#include "SCimp.h"
#include "SCimpPriv.h"
 
 

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#define OPTEST_IOS_SPECIFIC 1
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
#define OPTEST_OSX_SPECIFIC 1
#endif


/*____________________________________________________________________________
 Testing 
 ____________________________________________________________________________*/

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

void dumpHex8(  uint8_t* buffer)
{
    char hexDigit[] = "0123456789ABCDEF";
	register int			i;
	const unsigned char	  *bufferPtr = buffer;
    
    for (i = 0; i < 8; i++){
        printf("%c",  hexDigit[ bufferPtr[i] >>4]);
        printf("%c",  hexDigit[ bufferPtr[i] &0xF]);
        if((i) &0x01) printf("%c", ' ');
    }
    
}

static  SCLError dumpInfo(SCimpContextRef ctx)
{
    SCLError     err  = kSCLError_NoErr;
    SCimpInfo    info;
    char *SASstr = NULL;
    
    err = SCimpGetInfo(ctx, &info); CKERR;
    
    printf("%12s: %02x\n","Version", info.version);
    printf("%12s: %02x\n","cipherSuite", info.cipherSuite);
    printf("%12s: %02x\n","SAS method", info.sasMethod);
    printf("%12s: %s\n","Keyed", info.isReady?"TRUE":"FALSE");
    printf("%12s: %s\n","Has CS", info.hasCs?"TRUE":"FALSE");
    printf("%12s: %s\n","CS Matches", info.csMatches?"TRUE":"FALSE");
    
    SCimpGetAllocatedDataProperty(ctx, kSCimpProperty_SASstring, (void*) &SASstr, NULL);
    printf("%12s: |%s|\n","SAS", SASstr?SASstr:"<NULL>");
    printf("\n");
 
done:
    return err;
    
    if(SASstr) XFREE(SASstr);

}



static  char*  stateText( SCimpState state )
{
    static struct
    {
        SCimpState      state;
        char*           txt;
    }state_txt[] =
    {
        { kSCimpState_Init,		"Init"},
        { kSCimpState_Ready,	"Ready"},
        { kSCimpState_Commit,	"Commit"},
        { kSCimpState_DH2,		"DH2"},
        { kSCimpState_DH1,		"DH1"},
        { kSCimpState_Confirm,	"Confirm"},
        {NO_NEW_STATE,         "NO_NEW_STATE"},
        {0,NULL}
    };
    
    int i;
    
    for(i = 0; state_txt[i].txt; i++)
        if(state_txt[i].state == state) return(state_txt[i].txt);
    
    return "Invalid";
    
}

SCLError sEventHandler(SCimpContextRef ctx, SCimpEvent* event, void* uservalue)
{
    SCLError     err  = kSCLError_NoErr;
    static int  idNum = 0;
    
    SCimpContextRef destCtx = uservalue;
    
    printf("EVENT (%d, %s <%s>) -  ", event->type, ctx->isInitiator?"Initiator":"Responder", ctx->meStr);
    switch(event->type)
    {
        case kSCimpEvent_Transition:
        {
            SCimpEventTransitionData  *d =    &event->data.transData;
            
            printf("STATE: %s\n", stateText(d->state ) );
        }
            break;
            
        case kSCimpEvent_SendPacket:
        {
            SCimpEventSendData  *d =    &event->data.sendData;
            char msgID[32];
            int msgIDLen = 0;
         
            printf("SEND PACKET (%d) id='%s' \n", (int)d->length,
                                     event->userRef?(char*)event->userRef:"none");
            printf("|%.*s|\n\n", (int)d->length, d->data);
            
            
            msgIDLen = sprintf(msgID, "Reply %d", idNum++);
                
            err = SCimpProcessPacket(destCtx,event->data.sendData.data, event->data.sendData.length,  msgID );
        }
            
            break;
            
        case kSCimpEvent_Decrypted:
        {
            SCimpEventDecryptData  *d =    &event->data.decryptData;
  
            printf("DECRYPTED (%d) id='%s'\n", (int)d->length,
                     event->userRef?(char*)event->userRef:"none");
                   
            printf("\t|%.*s|\n\n", (int)d->length, d->data);
            
        }
            
            break;

        case kSCimpEvent_ClearText:
        {
            SCimpEventClearText  *d =    &event->data.clearText;
            
            printf("CLEARTEXT (%d) id='%s'\n", (int)d->length,
                   event->userRef?(char*)event->userRef:"none");
              printf("\t|%.*s|\n\n", (int)d->length, d->data);
            
        }
           break;   
            
          
        case kSCimpEvent_Keyed:
        {    
            SCimpInfo  *d =    &event->data.keyedData.info;
            char *SASstr = NULL;
             
            printf("KEYED\n" );
            printf("%12s: %02x\n","Version", d->version);
            printf("%12s: %02x\n","cipherSuite", d->cipherSuite);
            printf("%12s: %02x\n","SAS method", d->sasMethod);
            
            SCimpGetAllocatedDataProperty(ctx, kSCimpProperty_SASstring, (void*) &SASstr, NULL); 
            printf("%12s: |%s|\n","SAS", SASstr?SASstr:"<NULL>");
            printf("%12s: %s\n","CS Matches", d->csMatches?"TRUE":"FALSE");
            
            if(SASstr) XFREE(SASstr);
            printf("\n");
        }
             break;
 
        case kSCimpEvent_Error:
        {    
            SCimpEventErrorData  *d =  &event->data.errorData;
            char errorBuf[256];
            
            
            printf("ERROR  %d  id='%s'\n", (int)d->error,
                    event->userRef?(char*)event->userRef:"none");
            
             
            if(IsntSCLError( SCLGetErrorString(d->error, sizeof(errorBuf), errorBuf)))
            {
                printf("%s", errorBuf);
            }
     
            printf("\n\n");
        }
            break;

        case kSCimpEvent_Warning:
        {    
            SCimpEventWarningData  *d =  &event->data.warningData;
            char errorBuf[256];
            
            printf("WARNING: %d ", d->warning); 
            
            if(IsntSCLError( SCLGetErrorString(d->warning, sizeof(errorBuf), errorBuf)))
            {
                printf("%s", errorBuf);
            }
            
            printf("\n\n");
        }
            break;
            
        case kSCimpEvent_ReKeying:
        {    
            SCimpInfo  *d =    &event->data.keyedData.info;
            
            printf("RE-KEY REQUEST\n" );
            printf("%12s: %02x\n","Version", d->version);
            printf("%12s: %02x\n","cipherSuite", d->cipherSuite);
            printf("%12s: %02x\n","SAS", d->sasMethod);
            printf("\n");
            
//            if(d->cipherSuite == kSCimpCipherSuite_SKEIN_AES256_ECC384)   err = kSCLError_UserAbort;
          }
             break;
      
        case kSCimpEvent_Shutdown:
        {    
            printf("SHUTDOWN\n" );
        }
             break;

        default:
            printf("OTHER EVENT %d\n", event->type);
            break;
    }
  
done:
    return err;
}



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




static SCLError TestSCimp1()
{
    SCLError err = kSCLError_NoErr;
    
    SCimpContextRef   scimpI = NULL;
    SCimpContextRef   scimpR = NULL;
 
    char        *bobStr     = "bob@silentcircle.com/iBob's Phone";
    char        *aliceStr   = "alice@silentcircle.com/Alice's Desktop";
    int i;
    
    
    printf("\nSCimp test1 \n");
    
    printf("*** \tSetup SCimp context \n");
    /* Setup Initiator */  
    err = SCimpNew(bobStr, 
                   aliceStr,
                   &scimpI); CKERR;
    
    /* Setup Responder */  
    err = SCimpNew(aliceStr, 
                   bobStr,
                   &scimpR);CKERR;
    

    
    // setup the internal loopback
    err = SCimpSetEventHandler(scimpI, sEventHandler, scimpR); CKERR;
    err = SCimpSetEventHandler(scimpR, sEventHandler,  scimpI); CKERR;
  
    err = SCimpEnableTransitionEvents(scimpI, true); CKERR;
    err = SCimpEnableTransitionEvents(scimpR, true); CKERR;

    /* kick off key exchange */
    printf("*** \nStarting Key Exchange\n\n");
    err = SCimpStartDH(scimpI); CKERR;
  
    for(i = 0; banter[i] != NULL; i++)
    {
        err = SCimpSendMsg( i&1?scimpR:scimpI, banter[i] ,strlen(banter[i]), NULL);
        if(err == kSCLError_NotConnected) 
        { 
            printf("\n\n*** NO LONGER CONNECTED\n\n");
            err = kSCLError_NoErr; break;
        }
        CKERR;
        if(i == 2)
        {
            break;
        }
    }
            
    
    /* test out of band message */
    { const char commit_msg[] = "?SCIMP:ewogICAgImNvbW1pdCI6IHsKICAgICAgICAidmVyc2lvbiI6IDEsCiAgICAgICAgImNpcGhlclN1aXRlIjogMSwKICAgICAgICAic2FzTWV0aG9kIjogMSwKICAgICAgICAiSHBraSI6ICJIRWdyV0ZFY3lEanBrNVZFZlo2cXpoTnlQcm9Ya1Fwa0ZiS1U0Y3YwbWo4PSIsCiAgICAgICAgIkhjcyI6ICJjNFV1L2JuZURyWT0iCiAgICB9Cn0K.";
  
        
        const char dh1_msg[] = "?SCIMP:ewogICAgImRoMSI6IHsKICAgICAgICAiUEtyIjogIk1Hd0RBZ2NBQWdFd0FqRUFrelJtYjdiRC9paERaN2UwenBIdk9uRGZKY0pLVTF2bEtqSkpsVGVnRnQ3S3hwczRrZGlCUWRhT2Q4QUxPSDNqQWpCcm0vcjZCSW5seWRHSkFTR3VBR0dnN1FQSlRXbFZ6MlN3S1dSQ2tOZ3UvRlRFdVRMeWNRTjQ0c2xIM2lWQWZZcz0iLAogICAgICAgICJIY3MiOiAiK1NsQVRCSnRPRzg9IgogICAgfQp9Cg==.";
  
        const char dh2_msg[] = "?SCIMP:ewogICAgImRoMiI6IHsKICAgICAgICAiUEtpIjogIk1Hd0RBZ2NBQWdFd0FqQjNTR3V3dDRlYk10SFVocklsRUJCbkswSG9tK3kya01aVGJIZ290c1Q3YW1uYlVheGJ0UWY2OHdsYTZISWZYZGNDTVFDRkhnbXpoVWMzdngrQ05Cd1REN0F4T2Y1ZWNXS2RqZXJnZ3ZnZnRnVGYza0UxcFdVSU55K2NOQlVqQlZaaG8yYz0iLAogICAgICAgICJtYWNpIjogIlJWMXcyeVllbEpRPSIKICAgIH0KfQo=.";

        const char confirm_msg[] = "?SCIMP:ewogICAgImNvbmZpcm0iOiB7CiAgICAgICAgIm1hY3IiOiAiY3FNYjBoSFpvQW89IgogICAgfQp9Cg==.";

        const char msgID[] = "commit-packet-0";
        
        printf("\e[0;35m *** \tTesting bad Message\n\e[0m ");
        err =  SCimpProcessPacket(scimpI, (void*)commit_msg, strlen(commit_msg), (void*)msgID);
        if(IsSCLError(err))
        {
            printf("\tFails with Error %d\n\n", err);
        //        CKERR;
        }
    }

    
    for(i = 0; banter[i] != NULL; i++)
    {
        err = SCimpSendMsg( i&1?scimpR:scimpI, banter[i] ,strlen(banter[i]), NULL);
        if(err == kSCLError_NotConnected) 
        { 
            printf("\n\n*** NO LONGER CONNECTED\n\n");
            err = kSCLError_NoErr; break;
        }
        CKERR;
        
     }
    

    
    printf("*** \tSCimp test OK \n");
    
done:
    
    if(IsntNull(scimpI))
        SCimpFree(scimpI);
    
    if(IsntNull(scimpR))
        SCimpFree(scimpR);
    
    printf("SCimp test Complete \n");
    
    return err;
  
}



static SCLError TestSCimpSimple()
{
    SCLError err = kSCLError_NoErr;
    
    SCimpContextRef   scimpI = NULL;
    SCimpContextRef   scimpR = NULL;
    
    char        *bobStr     = "bob@silentcircle.com/iBob's Phone";
    char        *aliceStr   = "alice@silentcircle.com/Alice's Desktop";
    int i;
    
     uint8_t        secret[64];
     
    printf("\nSCimp simple tests \n");
     
    /* Fill  shared secret with random number */
    sprng_read(secret,sizeof(secret),NULL);
    
    printf("*** \tSetup SCimp context \n");
    /* Setup Initiator */  
    err = SCimpNew(bobStr, 
                   aliceStr,
                   &scimpI); CKERR;
    
    /* Setup Responder */  
    err = SCimpNew(aliceStr, 
                   bobStr,
                   &scimpR);CKERR;
    
    
    
    // setup the internal loopback
    err = SCimpSetEventHandler(scimpI, sEventHandler, scimpR); CKERR;
    err = SCimpSetEventHandler(scimpR, sEventHandler,  scimpI); CKERR;
  
    err = SCimpSetNumericProperty(scimpI,kSCimpProperty_SASMethod, kSCimpSAS_NATO); CKERR;
    err = SCimpSetNumericProperty(scimpR, kSCimpProperty_CipherSuite, kSCimpCipherSuite_SKEIN_AES256_ECC384); CKERR;
    
 //   err = SCimpSetDataProperty(scimpI, kSCimpProperty_SharedSecret,  secret, sizeof(secret)); CKERR;
    
    /* kick off key exchange */
    printf("*** \nStarting Key Exchange\n\n");
    err = SCimpStartDH(scimpI); CKERR;
    
    
    printf("Initiator Info\n" );
    err = dumpInfo(scimpI); CKERR;
    
    printf("Responder Info\n" );
    err = dumpInfo(scimpR); CKERR;
    
    printf("*** \nAccept the new next secrets\n\n");
    err = SCimpAcceptSecret(scimpI); CKERR;
    err = SCimpAcceptSecret(scimpR); CKERR;
    
    
    printf("*** \nReStarting Key Exchange\n\n");
    err = SCimpStartDH(scimpR); CKERR;
    
    printf("Initiator Info\n" );
    err = dumpInfo(scimpI); CKERR;
    
    printf("Responder Info\n" );
    err = dumpInfo(scimpR); CKERR;
    

    for(i = 0; banter[i] != NULL; i++)
    {
        err = SCimpSendMsg( i&1?scimpR:scimpI, banter[i] ,strlen(banter[i]), NULL);
        if(err == kSCLError_NotConnected) 
        { 
            printf("\n\n*** NO LONGER CONNECTED\n\n");
            err = kSCLError_NoErr; break;
        }
        CKERR;
        if(i == 2)
        {
            break;
        }
    }
    
    
    printf("*** \tSCimp simple test OK \n");
    
done:
    
    if(IsntNull(scimpI))
        SCimpFree(scimpI);
    
    if(IsntNull(scimpR))
        SCimpFree(scimpR);
    
    printf("SCimp simple Complete \n");
    
    return err;
    
}

static SCLError TestSCimp()
{
    SCLError err = kSCLError_NoErr;
    
    SCimpContextRef   scimpI = NULL;
    SCimpContextRef   scimpR = NULL;
    SCimpMsgFormat    format =   kSCimpMsgFormat_JSON;
    
    char        *bobStr     = "bob@silentcircle.com/iBob's Phone";
    char        *aliceStr   = "alice@silentcircle.com/Alice's Desktop";
    
    uint8_t        secret[64];
    
    SCimpInfo    info;
    int         i;
      
    
    printf("\nSCimp test \n");
    
    printf("*** \tSetup SCimp context \n");
    /* Setup Initiator */  
    err = SCimpNew(bobStr, 
                     aliceStr,
                     &scimpI); CKERR;
    
    /* Setup Responder */  
    err = SCimpNew(aliceStr, 
                     bobStr,
                     &scimpR);CKERR;
    
    err = SCimpSetNumericProperty(scimpI ,kSCimpProperty_MsgFormat,  format); CKERR;
    err = SCimpSetNumericProperty(scimpR ,kSCimpProperty_MsgFormat,  format); CKERR;
 
    // setup the internal loopback
    err = SCimpSetEventHandler(scimpI, sEventHandler, scimpR); CKERR;
    err = SCimpSetEventHandler(scimpR, sEventHandler,  scimpI); CKERR;
    err = SCimpEnableTransitionEvents(scimpI, true); CKERR;
    err = SCimpEnableTransitionEvents(scimpI, true); CKERR;
    
    err = SCimpGetNumericProperty(scimpR ,kSCimpProperty_MsgFormat,  &format); CKERR;
    printf("*** \tTesting with Message format %d\n", format);
    
    /* Fill Initiator shared secret with random number */
    sprng_read(secret,sizeof(secret),NULL);
    
    err = SCimpSetDataProperty(scimpI, kSCimpProperty_SharedSecret,  secret, sizeof(secret)); CKERR;
    
    secret[0] = secret[0]+1;
    err = SCimpSetDataProperty(scimpR, kSCimpProperty_SharedSecret,  secret, sizeof(secret)); CKERR;
    
#if 0
    /* test passthrough */
    printf("*** \tTest Unencrypted passthrough\n");
    for(i = 0; i < 4; i++)
    {
        char msgID[32];
         
        sprintf(msgID, "ClearText %d", i);
         
         err = SCimpProcessPacket( i&1?scimpR:scimpI, (uint8_t*)banter[i] ,strlen(banter[i]),  msgID);
    }
#endif
    
    /* kick off key exchange */
    printf("*** \nStarting Key Exchange\n\n");
    err = SCimpStartDH(scimpI); CKERR;
    
    
    err = SCimpGetInfo(scimpI, &info); CKERR;
    if(!info.isReady)
    {
        printf("Initiator is not ready!\n");
        RETERR(kSCLError_SelfTestFailed);
    }
      
    
     // accept the new next secrets
    printf("*** \nAccept the new next secrets\n\n");
    err = SCimpAcceptSecret(scimpI); CKERR;
    err = SCimpAcceptSecret(scimpR); CKERR;
      
    err = SCimpSetNumericProperty(scimpI,kSCimpProperty_SASMethod, kSCimpSAS_HEX); CKERR;
    err = SCimpSetNumericProperty(scimpI,kSCimpProperty_SASMethod, kSCimpSAS_NATO); CKERR;
      // do it again!

      printf("*** \tRekey with updated secrets\n\n");
    err = SCimpStartDH(scimpI); CKERR;
    
    err = SCimpGetInfo(scimpR, &info); CKERR;
     if(!info.csMatches)
    {
        printf("Responder Secrets did not match!\n");
        RETERR(kSCLError_SelfTestFailed);
    }
    
    err = SCimpGetInfo(scimpI, &info); CKERR;
    if(!info.csMatches)
    {
        printf("Initiator Secrets did not match!\n");
        RETERR(kSCLError_SelfTestFailed);
    }
    printf("*** \tShared Secret was updated.\n\n");

    printf("*** \tStarting Message Transfer\n");
    for(i = 0; banter[i] != NULL; i++)
    {
        char msgID[32];
         
        sprintf(msgID, "message %d", i);
        
        err = SCimpSendMsg( i&1?scimpR:scimpI, banter[i] ,strlen(banter[i]), msgID);
        if(err == kSCLError_NotConnected) 
        { 
            err = kSCLError_NoErr; break;
        }
        CKERR;
        
        
        /*      if(i == 3)
         {
         
         printf("*** \tAlice requests rekey with cipher suite 2 \n\n");
         
         err = SCimpSetNumericProperty(scimpR, kSCimpProperty_CipherSuite, kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384); CKERR;
         
         err = SCimpStartDH(scimpR); CKERR;
         }
         
         */
        
        if(i == 7)
        {
            
            printf("*** \tAlice requests rekey with cipher suite 3 \n\n");
            printf("*** \tBOTH NODES CHANGE MSG FORMATS \n\n");
            
            err = SCimpSetNumericProperty(scimpR, kSCimpProperty_CipherSuite, kSCimpCipherSuite_SKEIN_AES256_ECC384); CKERR;
            
#if SUPPORT_XML_MESSAGE_FORMAT
            
            err = SCimpSetNumericProperty(scimpI ,kSCimpProperty_MsgFormat,  kSCimpMsgFormat_XML); CKERR;
            err = SCimpSetNumericProperty(scimpR ,kSCimpProperty_MsgFormat,  kSCimpMsgFormat_XML); CKERR;
#endif            
            
            err = SCimpStartDH(scimpR); CKERR;
        }
        
    }
    CKERR;
    
    /* test out of band message */
    { const char commit_msg[] = "?SCIMP:ewogICAgImNvbW1pdCI6IHsKICAgICAgICAidmVyc2lvbiI6IDEsCiAgICAgICAgImNpcGhlclN1aXRlIjogMSwKICAgICAgICAic2FzTWV0aG9kIjogMSwKICAgICAgICAiSHBraSI6ICJIRWdyV0ZFY3lEanBrNVZFZlo2cXpoTnlQcm9Ya1Fwa0ZiS1U0Y3YwbWo4PSIsCiAgICAgICAgIkhjcyI6ICJjNFV1L2JuZURyWT0iCiAgICB9Cn0K.";
        
        const char msgID[] = "commit-packet-0";
        
        printf("*** \tTesting bad Message\n");
        err =  SCimpProcessPacket(scimpI, (void*)commit_msg, strlen(commit_msg),  (void*) msgID);
        if(IsSCLError(err))
            printf("\tFails with Error %d\n\n", err);
 
    } 
  
    
     {
        void* blob = NULL;
        size_t bloblen = 0;
        
        uint8_t     key[64]     = {0};
        size_t      keyLen      = 64;

        /* Fill save key with random number */
        sprng_read(key,sizeof(key),NULL);
         
        err = SCimpSaveState(scimpR, key, keyLen, &blob, &bloblen); CKERR;
        printf("*** \tSave Alice's state %ld bytes\n", bloblen);
        printf("\n%s\n", blob);
        
        SCimpFree(scimpR); scimpR = NULL;
        
        
        printf("*** \trestore Alice's state \n\n");
        err = SCimpRestoreState(key, keyLen, blob, bloblen, &scimpR);CKERR;
        XFREE(blob);
        
        // reset the internal loopback
        err = SCimpSetEventHandler(scimpR, sEventHandler,  scimpI); CKERR;
        err = SCimpSetEventHandler(scimpI, sEventHandler,  scimpR); CKERR;
 
         err = SCimpEnableTransitionEvents(scimpI, true); CKERR;
         err = SCimpEnableTransitionEvents(scimpR, true); CKERR;

    }
    
    for(i = 0; banter[i] != NULL; i++)
    {
        err = SCimpSendMsg( i&1?scimpR:scimpI, banter[i] ,strlen(banter[i]), NULL);
        if(err == kSCLError_NotConnected) 
        { 
            printf("\n\n*** NO LONGER CONNECTED\n\n");
            err = kSCLError_NoErr; break;
        }
        CKERR;
        
     }
   
    /* test passthrough */
    printf("*** \tTest Unencrypted passthrough\n");
    for(i = 0; i < 4; i++)
    {
        
        err = SCimpProcessPacket( i&1?scimpR:scimpI, (uint8_t*)banter[i] ,strlen(banter[i]), NULL);
    }

    
    printf("*** \tSCimp test OK \n");
    
done:
    
    if(IsntNull(scimpI))
        SCimpFree(scimpI);
    
    if(IsntNull(scimpR))
        SCimpFree(scimpR);
    
    printf("SCimp test Complete \n");
    
    return err;
}


ltc_math_descriptor ltc_mp;


int scimptest_main(int argc, char **arg)
{
    SCLError err = CRYPT_OK;
    char version_string[32];
    
    err = SCimpGetVersionString(sizeof(version_string), version_string); CKERR;
    
    printf("Test libscimp version: %s\n", version_string);
    
    ltc_mp = ltm_desc;
  
    
    register_prng(&sprng_desc);
    register_hash (&sha256_desc);
    register_hash (&sha512_desc);
    register_hash (&sha512_256_desc);
    register_hash (&skein512_desc);
    register_cipher (&aes_desc);
    register_hash (&skein256_desc);
    register_hash (&skein512_desc);
   
//    err = TestSCimpSimple(); CKERR;
    
//      err =  TestSCimp1() ;CKERR;
    
    err =  TestSCimp() ;CKERR;
    
      
      
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
    
    result = scimptest_main(0,NULL);
    
    return (result);
}
#else


int main(int argc, char **argv)
{
    return(scimptest_main(argc, argv));
}
#endif

 
