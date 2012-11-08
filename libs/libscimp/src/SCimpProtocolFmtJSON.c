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


 
#include "SCpubTypes.h"
#include "cryptowrappers.h"
#include "SCimp.h"
#include "SCimpPriv.h"
#include <stdio.h>
#include <errno.h>
#include <tomcrypt.h>

#include "yajl_parse.h"
#include <yajl_gen.h>


#ifndef MAX
#define MAX(x,y) ((x)>(y)?(x):(y))
#endif



#define CKSTAT  if((stat != yajl_gen_status_ok)) {\
printf("ERROR %d  %s:%d \n",  err, __FILE__, __LINE__); \
err = kSCLError_CorruptData; \
goto done; }


static const char* kCommitStr = "commit";
static const char* kDH1Str = "dh1";
static const char* kDH2Str = "dh2";
static const char* kConfirmStr = "confirm";
static const char* kDataStr = "data";

static const char* kVersionStr      = "version";
static const char* kCipherSuiteStr  = "cipherSuite";
static const char* kSASmethodStr    = "sasMethod";
static const char* kHpkiStr         = "Hpki";
static const char* kHcsStr          = "Hcs";
static const char* kPKrStr          = "PKr";
static const char* kPKiStr          = "PKi";

static const char* kKMACRStr          = "macr";
static const char* kKMACIStr          = "maci";

static const char* kMacStr          = "mac";
static const char* kSeqStr          = "seq";
static const char* kMsgStr          = "msg";

static const char* kScimpStateStr    = "scimpstate";
static const char* kStateStr          = "state";
static const char* kStateTagStr       = "state_tag";

static const char* kSCIMPhdr        = "?SCIMP:";


enum SCimp_JSON_Type_
{
    SCimp_JSON_Type__Invalid ,
    SCimp_JSON_Type_UINT8,
    SCimp_JSON_Type_UINT16,
    SCimp_JSON_Type_HASH,
    SCimp_JSON_Type_MAC,
    SCimp_JSON_Type_TAG,
    SCimp_JSON_Type_STRING,
    SCimp_JSON_Type_STATE_TAG,
   ENUM_FORCE( SCimp_JSON_Type_ )
};
ENUM_TYPEDEF( SCimp_JSON_Type_, SCimp_JSON_Type   );

typedef struct  {
    uint8_t        state_tag[SCIMP_STATE_TAG_LEN];
    uint8_t        *msg; 
    size_t         msgLen;
    
} SCimp_State;

struct SCimpJSONcontext
{
    bool            isState;    
    SCimp_State     state;      // used for decoding saved state

    SCimpMsgPtr     msg;        // used for decoding messages
    int             level;
    
    SCimp_JSON_Type jType;
    void*           jItem;
    size_t*         jItemSize;
     
};

typedef struct SCimpJSONcontext SCimpJSONcontext;
 
#pragma mark
#pragma mark debuging

#if  DEBUG_PACKETS  


#define XCODE_COLORS_ESCAPE_MAC "\033["
#define XCODE_COLORS_ESCAPE_IOS "\xC2\xA0["

#if TARGET_OS_IPHONE
#define XCODE_COLORS_ESCAPE  XCODE_COLORS_ESCAPE_IOS
#else
#define XCODE_COLORS_ESCAPE  XCODE_COLORS_ESCAPE_MAC
#endif

#define XCODE_COLORS_RESET_FG   "fg;" // Clear any foreground color
#define XCODE_COLORS_RESET_BG  "bg;" // Clear any background color
#define XCODE_COLORS_RESET     ";"   // Clear any foreground or background color

#define XCODE_COLORS_BLUEGREEN_TXT  "fg0,128,128;"
#define XCODE_COLORS_RED_TXT  "fg255,0,0;" 
#define XCODE_COLORS_GREEN_TXT  "fg0,128,0;" 


static int DPRINTF(const char *color, const char *fmt, ...)
{
	va_list marker;
	char s[8096];
	int len;
	
	va_start( marker, fmt );     
	len = vsprintf( s, fmt, marker );
	va_end( marker ); 
    
    if(color)  printf("%s%s",  XCODE_COLORS_ESCAPE, color);
    
    printf( "%s",s);
    
    if(color)  printf("%s%s",  XCODE_COLORS_ESCAPE, XCODE_COLORS_RESET);
    
    fflush(stdout);
    
	
	return 0;
}

#endif



static void yajlFree(void * ctx, void * ptr)
{
    XFREE(ptr);
}

static void * yajlMalloc(void * ctx, size_t sz)
{
    return XMALLOC(sz);
}

static void * yajlRealloc(void * ctx, void * ptr, size_t sz)
{
    
    return XREALLOC(ptr, sz);
}



static void sAdd2End(SCimpMsg **msg, SCimpMsgPtr entry)
{
    SCimpMsgPtr p = NULL;
    
    if(IsNull(*msg))
        *msg = entry;
    else 
    {
        for(p = *msg; p->next; p = p->next);
        p->next = entry;
    }
    
}

 


static int sParse_number(void * ctx, const char * str, size_t len)
{
    SCimpJSONcontext *jctx = (SCimpJSONcontext*) ctx;
    char buf[32] = {0};
    int valid = 0;
   
    if(len < sizeof(buf))
    {
        COPY(str,buf,len);
        if(jctx->jType == SCimp_JSON_Type_UINT8)
        {
            uint8_t val = atoi(buf);
            *((uint8_t*) jctx->jItem) = val;
            valid = 1;
        }
        if(jctx->jType == SCimp_JSON_Type_UINT16)
        {
            uint16_t val = atoi(buf);
            *((uint16_t*) jctx->jItem) = val;
            valid = 1;
        }
    }
    
    return valid;
}

static int sParse_string(void * ctx, const unsigned char * stringVal,
                         size_t stringLen)
{
    SCimpJSONcontext *jctx = (SCimpJSONcontext*) ctx;
    int valid = 0;
      
    if(jctx->jType == SCimp_JSON_Type_HASH 
       || jctx->jType == SCimp_JSON_Type_MAC
       || jctx->jType ==  SCimp_JSON_Type_TAG
       || jctx->jType ==  SCimp_JSON_Type_STATE_TAG)
    {
        uint8_t     buf[ MAX( MAX( SCIMP_HASH_LEN, SCIMP_MAC_LEN) , SCIMP_TAG_LEN)  ];
        size_t      dataLen = sizeof(buf);
        
      if( base64_decode(stringVal,  stringLen, buf, &dataLen) == CRYPT_OK)
      {
         if((jctx->jType == SCimp_JSON_Type_HASH  && dataLen == SCIMP_HASH_LEN)
            || (jctx->jType == SCimp_JSON_Type_MAC  && dataLen == SCIMP_MAC_LEN)
            || (jctx->jType == SCimp_JSON_Type_TAG  && dataLen == SCIMP_TAG_LEN)
            || (jctx->jType == SCimp_JSON_Type_STATE_TAG  && dataLen == SCIMP_STATE_TAG_LEN))
         {
             COPY(buf, jctx->jItem, dataLen);
             valid = 1;
         }
      }
     } 
    else if(jctx->jType == SCimp_JSON_Type_STRING)
    {
        size_t      dataLen =  stringLen ;
        uint8_t     *buf =  XMALLOC(stringLen);
        
        if( base64_decode(stringVal,  stringLen, buf, &dataLen) == CRYPT_OK)
        {
            *((size_t*) jctx->jItemSize) = dataLen;
            *((uint8_t**) jctx->jItem) = buf;
            valid = 1;
        }
        else 
        {
            XFREE(buf);
        }
        
    }

      
    return valid;
}


static int sParseKey(SCimpJSONcontext * jctx, const unsigned char * stringVal, size_t stringLen)
{
     
    int valid = 0;
    
    if(jctx->isState)
    {
         
        if(CMP(stringVal, kStateTagStr, strlen(kStateTagStr)))
        {
            jctx->jType = SCimp_JSON_Type_STATE_TAG;
            jctx->jItem =  &jctx->state.state_tag;
            valid = 1;
        }
        else if(CMP(stringVal, kStateStr, strlen(kStateStr)))
        {
            jctx->jType = SCimp_JSON_Type_STRING;
            jctx->jItem = &jctx->state.msg;
            jctx->jItemSize = &jctx->state.msgLen;
            valid = 1;
        }
    }
    else
    {
        SCimpMsgPtr msg = jctx->msg;
        
        switch(msg->msgType)
        {
            case kSCimpMsg_Commit:
                if(CMP(stringVal, kVersionStr, strlen(kVersionStr)))
                {
                    jctx->jType = SCimp_JSON_Type_UINT8;
                    jctx->jItem = &msg->commit.version;
                    valid = 1;
                }
                else if(CMP(stringVal, kCipherSuiteStr, strlen(kCipherSuiteStr)))
                {
                    jctx->jType = SCimp_JSON_Type_UINT8;
                    jctx->jItem = &msg->commit.cipherSuite;
                    valid = 1;
                }
                else if(CMP(stringVal, kSASmethodStr, strlen(kSASmethodStr)))
                {
                    jctx->jType = SCimp_JSON_Type_UINT8;
                    jctx->jItem = &msg->commit.sasMethod;
                    valid = 1;
                }
                else if(CMP(stringVal, kHpkiStr, strlen(kHpkiStr)))
                {
                    jctx->jType = SCimp_JSON_Type_HASH;
                    jctx->jItem = &msg->commit.Hpki;
                    valid = 1;
                }
                else if(CMP(stringVal, kHcsStr, strlen(kHcsStr)))
                {
                    jctx->jType = SCimp_JSON_Type_MAC;
                    jctx->jItem = &msg->commit.Hcs;
                    valid = 1;
                }
                break;
                
            case kSCimpMsg_DH1:
                if(CMP(stringVal, kPKrStr, strlen(kPKrStr)))
                {
                    jctx->jType = SCimp_JSON_Type_STRING;
                    jctx->jItem = &msg->dh1.pk;
                    jctx->jItemSize = &msg->dh1.pkLen;
                    valid = 1;
                }
                else if(CMP(stringVal, kHcsStr, strlen(kHcsStr)))
                {
                    jctx->jType = SCimp_JSON_Type_MAC;
                    jctx->jItem = &msg->dh1.Hcs;
                    valid = 1;
                }
                
                break;
                
            case kSCimpMsg_DH2:
                
                if(CMP(stringVal, kPKiStr, strlen(kPKiStr)))
                {
                    jctx->jType = SCimp_JSON_Type_STRING;
                    jctx->jItem = &msg->dh2.pk;
                    jctx->jItemSize = &msg->dh2.pkLen;
                    valid = 1;
                }
                else if(CMP(stringVal, kKMACIStr, strlen(kKMACIStr)))
                {
                    jctx->jType = SCimp_JSON_Type_MAC;
                    jctx->jItem = &msg->dh2.Maci;
                    valid = 1;
                }
                
                break;
                
            case kSCimpMsg_Confirm:
                if(CMP(stringVal, kKMACRStr, strlen(kKMACRStr)))
                {
                    jctx->jType = SCimp_JSON_Type_MAC;
                    jctx->jItem = &msg->confirm.Macr;
                    valid = 1;
                }
                
                break;
                
            case kSCimpMsg_Data:
                
                if(CMP(stringVal, kSeqStr, strlen(kSeqStr)))
                {
                    jctx->jType = SCimp_JSON_Type_UINT16;
                    jctx->jItem = &msg->data.seqNum;
                    valid = 1;
                 }
                else if(CMP(stringVal, kMacStr, strlen(kMacStr)))
                {
                    jctx->jType = SCimp_JSON_Type_TAG;
                    jctx->jItem = &msg->data.tag;
                    valid = 1;
                }
                else if(CMP(stringVal, kMsgStr, strlen(kMsgStr)))
                {
                    jctx->jType = SCimp_JSON_Type_STRING;
                    jctx->jItem = &msg->data.msg;
                    jctx->jItemSize = &msg->data.msgLen;
                    valid = 1;
                }
                 
                break;
                 
            default:
                 break;
                
        }
    }

    return valid;
}

static int sParseMsgType(SCimpJSONcontext * jctx, const unsigned char * stringVal, size_t stringLen)
{
    int valid = 0;
    
    if(jctx->isState)
    {
        if(CMP(stringVal, kScimpStateStr, strlen(kScimpStateStr)))
        {
            // we dont do anything for state info here.;
            valid = 1;
        }
    }
    else
    {
        SCimpMsgPtr msg = jctx->msg;

        
        if(CMP(stringVal, kCommitStr, strlen(kCommitStr)))
        {
            msg->msgType = kSCimpMsg_Commit;
            valid = 1;
        }
        else if(CMP(stringVal, kDH1Str, strlen(kDH1Str)))
        {
            msg->msgType = kSCimpMsg_DH1;
            valid = 1;
        }
        else if(CMP(stringVal, kDH2Str, strlen(kDH2Str)))
        {
            msg->msgType = kSCimpMsg_DH2;
            valid = 1;
         }
        else if(CMP(stringVal, kConfirmStr, strlen(kConfirmStr)))
        {
            msg->msgType = kSCimpMsg_Confirm;
            valid = 1;
        }
        else if(CMP(stringVal, kDataStr, strlen(kDataStr)))
        {
            msg->msgType = kSCimpMsg_Data;
            valid = 1;
       }
    }
    
    return valid;
    
}


static int sParse_map_key(void * ctx, const unsigned char * stringVal,
                          size_t stringLen)
{
    SCimpJSONcontext *jctx = (SCimpJSONcontext*) ctx;
    int valid = 0;
    
    
    if(IsntNull(jctx))
    {
        
        if(jctx->level == 1)
        {
            valid = sParseMsgType(jctx, stringVal, stringLen);
            
        }
        else 
        {
            valid = sParseKey(jctx, stringVal, stringLen);
        }
        
    }
    
    return valid;
}

static int sParse_start_map(void * ctx)
{
    SCimpJSONcontext *jctx = (SCimpJSONcontext*) ctx;
    int retval = 1;
    
    if(IsntNull(jctx))
    {
        if(!jctx->isState && IsNull(jctx->msg))
        {
            jctx->msg = XMALLOC(sizeof (SCimpMsg)); 
            ZERO(jctx->msg, sizeof(SCimpMsg));
            
        }
        jctx->level++;
    }
    
done:
    
    return retval;
}


static int sParse_end_map(void * ctx)
{
    SCimpJSONcontext *jctx = (SCimpJSONcontext*) ctx;
 
    if(IsntNull(jctx) && IsntNull(jctx->msg))
    {
         
         jctx->level--;
        
        
    }
    
    
    return 1;
}

static SCLError scimp_base64_decode( uint8_t *inData, size_t inSize, 
                              uint8_t **outData, size_t *outSize)
{
    SCLError             err = kSCLError_NoErr;

    uint8_t *start  = NULL;
    uint8_t *end    = NULL;
    size_t  len     = 0;
    uint8_t *oBuf   = NULL;
  
    start = strnstr(inData, kSCIMPhdr, inSize);
    if(IsNull(start)) RETERR(kSCLError_CorruptData);
    start += (strlen(kSCIMPhdr));
    inSize -=  (start-inData);
        
    end =   memchr(start, '.', inSize);
    if(IsNull(end)) RETERR(kSCLError_CorruptData);
    
    len = end - start;  
    
    oBuf = XMALLOC(len); CKNULL(oBuf);  // overallocate   -- so what! this isn't a pdp11
     
    if(base64_decode(start,len, oBuf, &len) != CRYPT_OK) 
        RETERR(kSCLError_CorruptData);
    
    *outData = oBuf;
    *outSize = len;
    
done:
    
    if(IsntSCLError(err))
    {
        if(IsNull(oBuf))
            XFREE (oBuf);
    }
    return(err);
}

static SCLError scimp_base64_encode(const  uint8_t *inData, size_t inSize, 
                                    uint8_t **outData, size_t *outSize)
{
    SCLError    err = kSCLError_NoErr;
  
    size_t      len     = 0;
    uint8_t     *oBuf   = NULL;
    uint8_t     *start  = NULL;

    len =  ((((inSize) + 2) / 3) * 4)+1 + strlen(kSCIMPhdr) + 1;
    
    oBuf = XMALLOC(len); CKNULL(oBuf);
    *oBuf= 0;
    
    start = stpcpy(oBuf, kSCIMPhdr);
    
    if( base64_encode(inData,inSize, start, &len) != CRYPT_OK)
        RETERR(kSCLError_BufferTooSmall);
    
    strcat(oBuf, ".");
    len = strlen(oBuf);
 
    *outData = oBuf;
    *outSize = len;
    
done:
    
    if(IsSCLError(err))
    {
        if(IsNull(oBuf))
            XFREE (oBuf);
    }
    return(err);
}


SCLError scimpDeserializeMessageJSON( SCimpContext *ctx,  uint8_t *inData, size_t inSize, SCimpMsg **msg)
{
    SCLError             err = kSCLError_NoErr;
    yajl_gen_status     stat = yajl_gen_status_ok;
    yajl_handle         pHand = NULL;
    SCimpJSONcontext    *jctx = NULL;
    
    uint8_t             *jBuf   = NULL;
    size_t              jBufLen = 0;
    
    static yajl_callbacks callbacks = {
        NULL,
        NULL,
        NULL,
        NULL,
        sParse_number,
        sParse_string,
        sParse_start_map,
        sParse_map_key,
        sParse_end_map,
        NULL,
        NULL
    };
    
    
    yajl_alloc_funcs allocFuncs = {
        yajlMalloc,
        yajlRealloc,
        yajlFree,
        (void *) NULL
    };
    
    
    // check for cleartext
    if((inSize < (strlen(kSCIMPhdr) +1)) 
       || memcmp(  inData, kSCIMPhdr, strlen(kSCIMPhdr)) != 0)
    {
        // process cleartext message
       SCimpMsgPtr newMsg = NULL;
       uint8_t     *clrBuf   = NULL;
          
        newMsg = XMALLOC(sizeof (SCimpMsg)); CKNULL(newMsg);
        ZERO(newMsg, sizeof(SCimpMsg));

        newMsg->msgType = kSCimpMsg_ClearText;
        
        clrBuf = XMALLOC(inSize); CKNULL(clrBuf);
        COPY(inData,clrBuf, inSize); 
        newMsg->clearTxt.msg = clrBuf;
        newMsg->clearTxt.msgLen = inSize;
         
         *msg = newMsg;
    }
    else
    {
        // process SCIMP message
 
        err =  scimp_base64_decode(inData, inSize, &jBuf, &jBufLen); CKERR;
        
        jctx = XMALLOC(sizeof (SCimpJSONcontext)); CKNULL(jctx);
        ZERO(jctx, sizeof(SCimpJSONcontext));
         
        pHand = yajl_alloc(&callbacks, &allocFuncs, (void *) jctx);
        
        yajl_config(pHand, yajl_allow_comments, 1);
        stat = yajl_parse(pHand, jBuf,  jBufLen); CKSTAT;
        stat = yajl_complete_parse(pHand); CKSTAT;
   
        if(IsntNull(jctx->msg))
            *msg = jctx->msg;
   }
    
        
done:
    
    if(IsntNull(jBuf))   
        XFREE(jBuf);
   
    if(IsntNull(jctx))   
        XFREE(jctx);
    
    if(IsntNull(pHand))   
        yajl_free(pHand);
    
    return err;
    
}


SCLError scimpSerializeMessageJSON( SCimpContext *ctx, SCimpMsg *msg,  uint8_t **outData, size_t *outSize)
{
    SCLError             err = kSCLError_NoErr;
    yajl_gen_status     stat = yajl_gen_status_ok;
    
    const uint8_t       *yajlBuf = NULL;
    size_t              yajlLen = 0;

     yajl_gen            g = NULL;

    uint8_t             tempBuf[256];
    unsigned long       tempLen;
    uint8_t             *dataBuf = NULL;
    
    yajl_alloc_funcs allocFuncs = {
        yajlMalloc,
        yajlRealloc,
        yajlFree,
        (void *) NULL
    };
  
    g = yajl_gen_alloc(&allocFuncs); CKNULL(g);
    
    yajl_gen_config(g, yajl_gen_beautify, 1);
    yajl_gen_config(g, yajl_gen_validate_utf8, 1);
   
 
    switch(msg->msgType)
    {
        case kSCimpMsg_Commit:
        {
            stat = yajl_gen_map_open(g); CKSTAT;
            stat = yajl_gen_string(g, kCommitStr, strlen(kCommitStr)) ; CKSTAT;
            stat = yajl_gen_map_open(g); CKSTAT;
            
            stat = yajl_gen_string(g, kVersionStr, strlen(kVersionStr)) ; CKSTAT;
            sprintf(tempBuf, "%d", msg->commit.version);
            stat = yajl_gen_number(g, tempBuf, strlen(tempBuf)) ; CKSTAT;
            
            stat = yajl_gen_string(g, kCipherSuiteStr, strlen(kCipherSuiteStr)) ; CKSTAT;
            sprintf(tempBuf, "%d", msg->commit.cipherSuite);
            stat = yajl_gen_number(g, tempBuf, strlen(tempBuf)) ; CKSTAT;
            
            stat = yajl_gen_string(g, kSASmethodStr, strlen(kSASmethodStr)) ; CKSTAT;
            sprintf(tempBuf, "%d", msg->commit.sasMethod);
            stat = yajl_gen_number(g, tempBuf, strlen(tempBuf)) ; CKSTAT;
           
            stat = yajl_gen_string(g, kHpkiStr, strlen(kHpkiStr)) ; CKSTAT;
            tempLen = sizeof(tempBuf);
            base64_encode(msg->commit.Hpki,SCIMP_HASH_LEN, tempBuf, &tempLen);
            stat = yajl_gen_string(g, tempBuf, tempLen) ; CKSTAT;
               
            stat = yajl_gen_string(g, kHcsStr, strlen(kHcsStr)) ; CKSTAT;
            tempLen = sizeof(tempBuf);
            base64_encode(msg->commit.Hcs,SCIMP_MAC_LEN, tempBuf, &tempLen);
            stat = yajl_gen_string(g, tempBuf, tempLen) ; CKSTAT;
          
            stat = yajl_gen_map_close(g); CKSTAT;
            stat = yajl_gen_map_close(g); CKSTAT;
       }
            break;
            
        case kSCimpMsg_DH1:
        {
            stat = yajl_gen_map_open(g); CKSTAT;
            stat = yajl_gen_string(g, kDH1Str, strlen(kDH1Str)) ; CKSTAT;
            stat = yajl_gen_map_open(g); CKSTAT;
    
            stat = yajl_gen_string(g, kPKrStr, strlen(kPKrStr)) ; CKSTAT;
            tempLen = sizeof(tempBuf);
            base64_encode(msg->dh1.pk, msg->dh1.pkLen, tempBuf, &tempLen);
            stat = yajl_gen_string(g, tempBuf, tempLen) ; CKSTAT;
  
            stat = yajl_gen_string(g, kHcsStr, strlen(kHcsStr)) ; CKSTAT;
            tempLen = sizeof(tempBuf);
            base64_encode(msg->dh1.Hcs,SCIMP_MAC_LEN, tempBuf, &tempLen);
            stat = yajl_gen_string(g, tempBuf, tempLen) ; CKSTAT;
            
            stat = yajl_gen_map_close(g); CKSTAT;
            stat = yajl_gen_map_close(g); CKSTAT;
            
        }
            
            break;
            
        case kSCimpMsg_DH2:
        {
            stat = yajl_gen_map_open(g); CKSTAT;
            stat = yajl_gen_string(g, kDH2Str, strlen(kDH2Str)) ; CKSTAT;
            stat = yajl_gen_map_open(g); CKSTAT;
    
            stat = yajl_gen_string(g, kPKiStr, strlen(kPKiStr)) ; CKSTAT;
            tempLen = sizeof(tempBuf);
            base64_encode(msg->dh2.pk, msg->dh2.pkLen, tempBuf, &tempLen);
            stat = yajl_gen_string(g, tempBuf, tempLen) ; CKSTAT;
            
            stat = yajl_gen_string(g, kKMACIStr, strlen(kKMACIStr)) ; CKSTAT;
            tempLen = sizeof(tempBuf);
            base64_encode(msg->dh2.Maci,SCIMP_MAC_LEN, tempBuf, &tempLen);
            stat = yajl_gen_string(g, tempBuf, tempLen) ; CKSTAT;
              
            stat = yajl_gen_map_close(g); CKSTAT;
            stat = yajl_gen_map_close(g); CKSTAT;
       
        }
            break;
            
        case kSCimpMsg_Confirm:
        {
            stat = yajl_gen_map_open(g); CKSTAT;
            stat = yajl_gen_string(g, kConfirmStr, strlen(kConfirmStr)) ; CKSTAT;
            stat = yajl_gen_map_open(g); CKSTAT;
        
            stat = yajl_gen_string(g, kKMACRStr, strlen(kKMACRStr)) ; CKSTAT;
            tempLen = sizeof(tempBuf);
            base64_encode(msg->confirm.Macr,SCIMP_MAC_LEN, tempBuf, &tempLen);
            stat = yajl_gen_string(g, tempBuf, tempLen) ; CKSTAT;
            
            stat = yajl_gen_map_close(g); CKSTAT;
            stat = yajl_gen_map_close(g); CKSTAT;
        }
            break;
            
        case kSCimpMsg_Data:
        {
            unsigned long       dataLen;

            dataLen =  ((((msg->data.msgLen) + 2) / 3) * 4)+1;
            dataBuf = XMALLOC(dataLen); CKNULL(dataBuf);
            if( base64_encode(msg->data.msg, msg->data.msgLen, dataBuf, &dataLen) != CRYPT_OK)
                RETERR(kSCLError_BufferTooSmall);

            stat = yajl_gen_map_open(g); CKSTAT;
            stat = yajl_gen_string(g, kDataStr, strlen(kDataStr)) ; CKSTAT;
            stat = yajl_gen_map_open(g); CKSTAT;
              
            err = yajl_gen_string(g, kSeqStr, strlen(kSeqStr)) ; CKSTAT;
            sprintf(tempBuf, "%d", msg->data.seqNum);
            stat = yajl_gen_number(g, tempBuf, strlen(tempBuf)) ; CKSTAT;
               
            err = yajl_gen_string(g, kMacStr, strlen(kMacStr)) ; CKERR;
            tempLen = sizeof(tempBuf);
            base64_encode(msg->data.tag,SCIMP_MAC_LEN, tempBuf, &tempLen);
            stat = yajl_gen_string(g, tempBuf, tempLen) ; CKSTAT;
               
            err = yajl_gen_string(g, kMsgStr, strlen(kMsgStr)) ; CKERR;
            err = yajl_gen_string(g, dataBuf,dataLen ) ; CKERR;
              
            stat = yajl_gen_map_close(g); CKSTAT;
            stat = yajl_gen_map_close(g); CKSTAT;
        }
            break;
            
            
        default:
            return(kSCLError_CorruptData);
    }

    stat =  yajl_gen_get_buf(g, &yajlBuf, &yajlLen);CKSTAT;
    
#if DEBUG_PACKETS
    {
        DPRINTF(XCODE_COLORS_BLUEGREEN_TXT, "\n%*s\n", (int)yajlLen, yajlBuf);
     }
#endif
     
    err = scimp_base64_encode(yajlBuf,yajlLen, outData,outSize); CKERR;
       
done:
    
    if(IsntNull(g))   
        yajl_gen_free(g);

    if(dataBuf) 
        XFREE(dataBuf);

    return err;
    
}
 

SCLError scimpSerializeStateJSON( uint8_t* stateInfo, size_t statelen, 
                                   uint8_t *tag, size_t tagLen, 
                                  uint8_t **outData, size_t *outSize)
{
    SCLError             err = kSCLError_NoErr;
    yajl_gen_status     stat = yajl_gen_status_ok;
    
    const uint8_t       *yajlBuf = NULL;
    size_t              yajlLen = 0;
    
    uint8_t             *outBuf = NULL;
    yajl_gen            g = NULL;
    
    uint8_t             tempBuf[256];
    unsigned long       tempLen;
    
    uint8_t             *dataBuf = NULL;
    unsigned long       dataLen;
      
    yajl_alloc_funcs allocFuncs = {
        yajlMalloc,
        yajlRealloc,
        yajlFree,
        (void *) NULL
    };
    
    g = yajl_gen_alloc(&allocFuncs); CKNULL(g);
    
    yajl_gen_config(g, yajl_gen_beautify, 1);
    yajl_gen_config(g, yajl_gen_validate_utf8, 1);
        
    dataLen =  ((((statelen) + 2) / 3) * 4)+1;
    dataBuf = XMALLOC(dataLen); CKNULL(dataBuf);
    if( base64_encode(stateInfo, statelen, dataBuf, &dataLen) != CRYPT_OK)
        RETERR(kSCLError_BufferTooSmall);
     
    stat = yajl_gen_map_open(g); CKSTAT;
    stat = yajl_gen_string(g, kScimpStateStr, strlen(kScimpStateStr)) ; CKSTAT;
    stat = yajl_gen_map_open(g); CKSTAT;
      
    err = yajl_gen_string(g, kStateTagStr, strlen(kStateTagStr)) ; CKERR;
    tempLen = sizeof(tempBuf);
    base64_encode(tag,tagLen, tempBuf, &tempLen);
    stat = yajl_gen_string(g, tempBuf, tempLen) ; CKSTAT;
    
    err = yajl_gen_string(g, kStateStr, strlen(kStateStr)) ; CKERR;
    err = yajl_gen_string(g, dataBuf,dataLen ) ; CKERR;
    
    stat = yajl_gen_map_close(g); CKSTAT;
    stat = yajl_gen_map_close(g); CKSTAT;
    
    stat =  yajl_gen_get_buf(g, &yajlBuf, &yajlLen);CKSTAT;
    
    outBuf = XMALLOC(yajlLen); CKNULL(outBuf);
    memcpy(outBuf, yajlBuf, yajlLen);
    
    *outData = outBuf;
    *outSize = yajlLen;
    
done:
    
    if(IsntNull(g))   
        yajl_gen_free(g);
    
    if(dataBuf) 
        XFREE(dataBuf);
    
    return err;
}


SCLError scimpDeserializeStateJSON( uint8_t *inData, size_t inSize, 
                                      uint8_t *outTag, size_t *outTagLen, 
                                      uint8_t **outData, size_t *outSize)

{
    SCLError             err = kSCLError_NoErr;
    
    yajl_gen_status     stat = yajl_gen_status_ok;
    yajl_handle         pHand = NULL;
    SCimpJSONcontext    *jctx = NULL;
    
    static yajl_callbacks callbacks = {
        NULL,
        NULL,
        NULL,
        NULL,
        sParse_number,
        sParse_string,
        sParse_start_map,
        sParse_map_key,
        sParse_end_map,
        NULL,
        NULL
    };
     
    yajl_alloc_funcs allocFuncs = {
        yajlMalloc,
        yajlRealloc,
        yajlFree,
        (void *) NULL
    };
    
    
    jctx = XMALLOC(sizeof (SCimpJSONcontext)); CKNULL(jctx);
    ZERO(jctx, sizeof(SCimpJSONcontext));
    
    jctx->isState = true;
     
    pHand = yajl_alloc(&callbacks, &allocFuncs, (void *) jctx);
    
    yajl_config(pHand, yajl_allow_comments, 1);
    stat = yajl_parse(pHand, inData,  inSize); CKSTAT;
    stat = yajl_complete_parse(pHand); CKSTAT;
    
    if(IsntNull(jctx->state.msg))
    {
        COPY(jctx->state.state_tag, outTag, SCIMP_STATE_TAG_LEN);
        *outTagLen = SCIMP_STATE_TAG_LEN;
        *outData = jctx->state.msg;
        *outSize = jctx->state.msgLen;
     }
    else  
        err = kSCLError_CorruptData;
    
done:
    
    if(IsntNull(jctx))   
        XFREE(jctx);
    
    if(IsntNull(pHand))   
        yajl_free(pHand);
    
    return err;
}
