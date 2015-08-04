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
//  SCloudJSON.c
//  scloud
//
#include "yajl_parse.h"
#include <yajl_gen.h>

#include "SCcrypto.h"
#include "SCutilities.h"
#include "SCloud.h"
#include "SCloudPriv.h"

static const char* kVersionStr      = "version";
static const char* kKeySuiteStr     = "keySuite";
static const char* kSymKeyStr       = "symkey";

#define CKSTAT  if((stat != yajl_gen_status_ok)) {\
printf("ERROR %d  %s:%d \n",  err, __FILE__, __LINE__); \
err = kSCLError_CorruptData; \
goto done; }

#ifdef __clang__
#pragma mark - debuging
#endif

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
	len = vsnprintf( s, sizeof(s), fmt, marker );
	va_end( marker );
    
    if(color)  printf("%s%s",  XCODE_COLORS_ESCAPE, color);
    
    printf( "%s",s);
    
    if(color)  printf("%s%s",  XCODE_COLORS_ESCAPE, XCODE_COLORS_RESET);
    
    fflush(stdout);
    
	
	return 0;
}

#endif

#ifdef __clang__
#pragma mark - memory management
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

#ifdef __clang__
#pragma mark - utility
#endif

static void bin2hex(  uint8_t* inBuf, size_t inLen, uint8_t* outBuf, size_t* outLen)
{
    static          char hexDigit[] = "0123456789ABCDEF";
    register        int    i;
    register        uint8_t* p = outBuf;
    
    for (i = 0; i < inLen; i++)
    {
        *p++  = hexDigit[ inBuf[i] >>4];
        *p++ =  hexDigit[ inBuf[i]  &0xF];
    }
    
    *outLen = p-outBuf;
    
}

#ifdef __clang__
#pragma mark - key import
#endif

enum SCloud_JSON_Type_
{
    SCloud_JSON_Type__Invalid ,
    SCloud_JSON_Type_VERSION,
    SCloud_JSON_Type_ENUM_KEYSUITE,
    SCloud_JSON_Type_SYMKEY,
 
    ENUM_FORCE( SCloud_JSON_Type_ )
};
ENUM_TYPEDEF( SCloud_JSON_Type_, SCloud_JSON_Type   );
 
struct SCloudJSONcontext
{
    uint8_t             version;    // message version
    SCloudKey           key;        // used for decoding messages
    int                 level;
    
    SCloud_JSON_Type jType;
    void*           jItem;
    size_t*         jItemSize;
    
};

typedef struct SCloudJSONcontext SCloudJSONcontext;

static int sParse_start_map(void * ctx)
{
    SCloudJSONcontext *jctx = (SCloudJSONcontext*) ctx;
    int retval = 1;
    
    if(IsntNull(jctx))
    {
           jctx->level++;
    }
    
// done:
    
    return retval;
}

static int sParse_end_map(void * ctx)
{
    SCloudJSONcontext *jctx = (SCloudJSONcontext*) ctx;
    
    if(IsntNull(jctx)  )
    {
        
        jctx->level--;
         
    }
    
    
    return 1;
}


static int sParse_number(void * ctx, const char * str, size_t len)
{
    SCloudJSONcontext *jctx = (SCloudJSONcontext*) ctx;
    char buf[32] = {0};
    int valid = 0;
    
    if(len < sizeof(buf))
    {
        COPY(str,buf,len);
        if(jctx->jType == SCloud_JSON_Type_VERSION)
        {
            uint8_t val = atoi(buf);
            if(val == kSCloudProtocolVersion)
               valid = 1;
        }
        else if(jctx->jType == SCloud_JSON_Type_ENUM_KEYSUITE)
        {
            int val = atoi(buf);
            jctx->key.keySuite = val;
            valid = 1;
        }
    }
 
    return valid;
}


#define _base(x) ((x >= '0' && x <= '9') ? '0' : \
(x >= 'a' && x <= 'f') ? 'a' - 10 : \
(x >= 'A' && x <= 'F') ? 'A' - 10 : \
'\255')
#define HEXOF(x) (x - _base(x))

static int sParse_string(void * ctx, const unsigned char * stringVal,
                         size_t stringLen)
{
     int valid = 0;
    SCloudJSONcontext *jctx = (SCloudJSONcontext*) ctx;
     
    if(jctx->jType == SCloud_JSON_Type_SYMKEY)
    {
        switch (jctx->key.keySuite)
        {
            case kSCloudKeySuite_AES128:
            {
                if(stringLen != 64) return 0;
                jctx->key.algorithm = kCipher_Algorithm_AES128;
             }
            break;
                
            default:
                return 0;
                break;
        }
        
        
        uint8_t  *p;
        size_t count;
        
        for (count = 0, p = (uint8_t*) stringVal; count < stringLen && p && *p; p+=2, count+=2 ) {
            jctx->key.symKey[(p - stringVal) >> 1] = ((HEXOF(*p)) << 4) + HEXOF(*(p+1));
         }
        
        if(count == stringLen) valid = 1;
        jctx->key.symKeyLen = count>>1;
        
    }
    
    return valid;
}

static int sParse_map_key(void * ctx, const unsigned char * stringVal,
                          size_t stringLen)
{
    SCloudJSONcontext *jctx = (SCloudJSONcontext*) ctx;
     int valid = 0;
     
    if(CMP(stringVal, kVersionStr, strlen(kVersionStr)))
    {
        jctx->jType = SCloud_JSON_Type_VERSION;
         valid = 1;
    }
    if(CMP(stringVal, kKeySuiteStr , strlen(kKeySuiteStr)))
    {
        jctx->jType = SCloud_JSON_Type_ENUM_KEYSUITE;
        valid = 1;
    }
    if(CMP(stringVal, kSymKeyStr, strlen(kSymKeyStr)))
    {
        jctx->jType = SCloud_JSON_Type_SYMKEY;
        valid = 1;
    }
     
    return valid;
}


SCLError scloudDeserializeKey( uint8_t *inData, size_t inLen, SCloudKey *keyOut)
{
    SCLError             err = kSCLError_NoErr;
    yajl_gen_status     stat = yajl_gen_status_ok;
    yajl_handle         pHand = NULL;
    SCloudJSONcontext    *jctx = NULL;
    
     
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
    
    
    jctx = XMALLOC(sizeof (SCloudJSONcontext)); CKNULL(jctx);
    ZERO(jctx, sizeof(SCloudJSONcontext));
    
    pHand = yajl_alloc(&callbacks, &allocFuncs, (void *) jctx);
    
    yajl_config(pHand, yajl_allow_comments, 1);
    stat = (yajl_gen_status) yajl_parse(pHand, inData,  inLen); CKSTAT;
    stat = (yajl_gen_status) yajl_complete_parse(pHand); CKSTAT;
    
    if(keyOut)
        *keyOut = jctx->key;
    
 done:
       if(IsntNull(jctx))
        XFREE(jctx);
    
    if(IsntNull(pHand))
        yajl_free(pHand);
    
    return err;

}


#ifdef __clang__
#pragma mark - key export
#endif

SCLError SCloudEncryptGetKeyBLOB( SCloudContextRef ctx,
                                uint8_t **outData, size_t *outSize)
{
    SCLError            err = kSCLError_NoErr;
    yajl_gen_status     stat = yajl_gen_status_ok;
    
    uint8_t             *yajlBuf = NULL;
    size_t              yajlLen = 0;
    
    uint8_t             *outBuf = NULL;
    yajl_gen            g = NULL;
    
    char                tempBuf[1024];
    size_t              tempLen;
    uint8_t             *dataBuf = NULL;
    
    
    yajl_alloc_funcs allocFuncs = {
        yajlMalloc,
        yajlRealloc,
        yajlFree,
        (void *) NULL
    };
    
    g = yajl_gen_alloc(&allocFuncs); CKNULL(g);
    
    yajl_gen_config(g, yajl_gen_beautify, 0);
    yajl_gen_config(g, yajl_gen_validate_utf8, 1);
    stat = yajl_gen_map_open(g); CKSTAT;
    
    
    stat = yajl_gen_string(g, (uint8_t*)kVersionStr, strlen(kVersionStr)) ; CKSTAT;
    sprintf((char*)tempBuf, "%d", kSCloudProtocolVersion);
    stat = yajl_gen_number(g, tempBuf, strlen((char*)tempBuf)) ; CKSTAT;
    
    stat = yajl_gen_string(g, (uint8_t*)kKeySuiteStr, strlen(kKeySuiteStr)) ; CKSTAT;
    sprintf((char*)tempBuf, "%d", ctx->key.keySuite);
    stat = yajl_gen_number(g, tempBuf, strlen((char*)tempBuf)) ; CKSTAT;
   
    stat = yajl_gen_string(g, (uint8_t*)kSymKeyStr, strlen(kSymKeyStr)) ; CKSTAT;
    bin2hex(ctx->key.symKey, ctx->key.symKeyLen, (uint8_t*) tempBuf, &tempLen);
    stat = yajl_gen_string(g, (uint8_t*) tempBuf, tempLen) ; CKSTAT;
    
    stat = yajl_gen_map_close(g); CKSTAT;
    
    stat =  yajl_gen_get_buf(g, (const unsigned char**) &yajlBuf, &yajlLen);CKSTAT;
    
    
#if DEBUG_PACKETS
    {
        DPRINTF(XCODE_COLORS_BLUEGREEN_TXT, "\n%*s\n", (int)yajlLen, yajlBuf);
    }
#endif
    
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
 
    
 //   COPY(ctx->key.symKey, buffer, ctx->key.symKeyLen);
    
    
};

SCLError SCloudEncryptGetSegmentBLOB( SCloudContextRef ctx, int segNum, uint8_t **outData, size_t *outSize ) {

    SCLError            err = kSCLError_NoErr;
    yajl_gen_status     stat = yajl_gen_status_ok;

    uint8_t             *yajlBuf = NULL;
    size_t              yajlLen = 0;

    uint8_t             *outBuf = NULL;
    yajl_gen            g = NULL;

    char                tempBuf[1024];
    size_t              tempLen;
    uint8_t             *dataBuf = NULL;


    yajl_alloc_funcs allocFuncs = {
        yajlMalloc,
        yajlRealloc,
        yajlFree,
        (void *) NULL
    };

    g = yajl_gen_alloc(&allocFuncs); CKNULL(g);

    yajl_gen_config(g, yajl_gen_beautify, 0);
    yajl_gen_config(g, yajl_gen_validate_utf8, 1);

    stat = yajl_gen_array_open(g); CKSTAT;

    sprintf((char*)tempBuf, "%d", segNum);
    stat = yajl_gen_number(g, tempBuf, strlen(tempBuf)) ; CKSTAT;

    URL64_encode(ctx->locator, TRUNCATED_LOCATOR_BITS >>3,  (uint8_t*)tempBuf, &tempLen);
    stat = yajl_gen_string(g, (uint8_t*) tempBuf, tempLen) ; CKSTAT;

    stat = yajl_gen_map_open(g); CKSTAT;

    stat = yajl_gen_string(g,  (uint8_t*)kVersionStr, strlen(kVersionStr)) ; CKSTAT;
    sprintf((char*)tempBuf, "%d", kSCloudProtocolVersion);
    stat = yajl_gen_number(g, (char*)tempBuf, strlen(tempBuf)) ; CKSTAT;

    stat = yajl_gen_string(g,  (uint8_t*)kKeySuiteStr, strlen(kKeySuiteStr)) ; CKSTAT;
    sprintf((char*)tempBuf, "%d", ctx->key.keySuite);
    stat = yajl_gen_number(g, tempBuf, strlen(tempBuf)) ; CKSTAT;

    stat = yajl_gen_string(g,  (uint8_t*)kSymKeyStr, strlen(kSymKeyStr)) ; CKSTAT;
    bin2hex(ctx->key.symKey, ctx->key.symKeyLen, (uint8_t*)tempBuf, &tempLen);
    stat = yajl_gen_string(g, (uint8_t*)tempBuf, tempLen) ; CKSTAT;

    stat = yajl_gen_map_close(g); CKSTAT;

    stat = yajl_gen_array_close(g); CKSTAT;

    stat =  yajl_gen_get_buf(g, (const unsigned char**) &yajlBuf, &yajlLen);CKSTAT;

#if DEBUG_PACKETS
    {
        DPRINTF(XCODE_COLORS_BLUEGREEN_TXT, "\n%*s\n", (int)yajlLen, yajlBuf);
    }
#endif

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

};
