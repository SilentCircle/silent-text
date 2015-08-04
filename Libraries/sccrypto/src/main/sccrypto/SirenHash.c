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
//  SirenHash.c
//  crypto-optest
 
#include "yajl_parse.h"
#include <yajl_gen.h>
//#include <tomcrypt.h>

#include "SCpubTypes.h"
#include "SCcrypto.h"
#include "SCutilities.h"

#define CKSTAT  if((stat != yajl_gen_status_ok)) {\
printf("ERROR %d  %s:%d \n",  err, __FILE__, __LINE__); \
err = kSCLError_CorruptData; \
goto done; }


char*  sHashable_tags_list[] = {
    "cloud_key",
    "cloud_url",
    "duration",
    "fyeo",
    "hasGPS",
    "location",
    "media_type",
    "message",
    "mimetype",
    "preview",
    "received_id",
    "request_burn",
    "request_receipt",
    "request_resend",
    "shred_after",
    "thumbnail",
    "vcard",
    NULL
};

// static const int  maxHashableTagEntries = sizeof(sHashable_tags_list) / sizeof(char*);

#define kMaxHashableTagEntries (sizeof(sHashable_tags_list) / sizeof(char*))

typedef struct  {
    char        *tag;
    uint8_t     *data;
    size_t      dataLen;
    
} HashableItem;

 

#pragma mark - debug

//#define DEBUG_HASH 1

#if DEBUG_HASH

#define HAS_XCODE_COLORS 1

#if TARGET_OS_IPHONE
#define HAS_XCODE_COLORS 1
#endif


#if HAS_XCODE_COLORS

#define XCODE_COLORS_ESCAPE_MAC "\033["
#define XCODE_COLORS_ESCAPE_IOS "\xC2\xA0["

#if TARGET_OS_IPHONE && !TARGET_IPHONE_SIMULATOR
#define XCODE_COLORS_ESCAPE  XCODE_COLORS_ESCAPE_IOS
#else
#define XCODE_COLORS_ESCAPE  XCODE_COLORS_ESCAPE_MAC
#endif

#define XCODE_COLORS_RESET_FG   "fg;" // Clear any foreground color
#define XCODE_COLORS_RESET_BG  "bg;" // Clear any background color
#define XCODE_COLORS_RESET     ";"   // Clear any foreground or background color

#define XCODE_COLORS_BLUE_TXT  "fg0,0,255;"
#define XCODE_COLORS_RED_TXT  "fg255,0,0;"
#define XCODE_COLORS_GREEN_TXT  "fg0,128,0;"

#else  // no HAS_XCODE_COLORS

#define XCODE_COLORS_ESCAPE ""
#define XCODE_COLORS_RESET_FG   "" // Clear any foreground color
#define XCODE_COLORS_RESET_BG  "" // Clear any background color
#define XCODE_COLORS_RESET     ""   // Clear any foreground or background color
#define XCODE_COLORS_BLUE_TXT  ""
#define XCODE_COLORS_RED_TXT  ""
#define XCODE_COLORS_GREEN_TXT  ""

#endif


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

static void dumpHex(  uint8_t* buffer, int length, int offset)
{
	char hexDigit[] = "0123456789ABCDEF";
	register int			i;
	int						lineStart;
	int						lineLength;
	short					c;
	const unsigned char	  *bufferPtr = buffer;
    
    char                    lineBuf[80];
    char                    *p;
    
#define kLineSize	16
	for (lineStart = 0, p = lineBuf; lineStart < length; lineStart += lineLength,  p = lineBuf )
    {
		lineLength = kLineSize;
		if (lineStart + lineLength > length)
			lineLength = length - lineStart;
        
		p += sprintf(p, "%6d: ", lineStart+offset);
		for (i = 0; i < lineLength; i++){
            *p++ = hexDigit[ bufferPtr[lineStart+i] >>4];
            *p++ = hexDigit[ bufferPtr[lineStart+i] &0xF];
   			if((lineStart+i) &0x01)  *p++ = ' ';  ;
		}
		for (; i < kLineSize; i++)
			p += sprintf(p, "   ");
        
		p += sprintf(p,"  ");
		for (i = 0; i < lineLength; i++) {
			c = bufferPtr[lineStart + i] & 0xFF;
			if (c > ' ' && c < '~')
				*p++ = c ;
			else {
				*p++ = '.';
			}
		}
        *p++ = 0;
        
		DPRINTF(XCODE_COLORS_RED_TXT, "%s\n",lineBuf);
	}
#undef kLineSize
}

static unsigned short crc16(unsigned char* data_p, unsigned char length){
    unsigned char x;
    unsigned short crc = 0xFFFF;
    
    while (length--){
        x = crc >> 8 ^ *data_p++;
        x ^= x>>4;
        crc = (crc << 8) ^ ((unsigned short)(x << 12)) ^ ((unsigned short)(x <<5)) ^ ((unsigned short)x);
    }
    return crc;
}
#endif


#pragma mark - memory management

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
#pragma mark - utility
 
#pragma mark - key import

 
struct SirenJSONcontext
{
    int                 level;
    
    int             validItem;
    HASH_ContextRef hash;
    
    void*           jItem;
    size_t*         jItemSize;
    
    HashableItem hashableItems[ kMaxHashableTagEntries];
    int          hashableItemsCount;
    
};

typedef struct SirenJSONcontext SirenJSONcontext;

static int sParse_start_map(void * ctx)
{
    SirenJSONcontext *jctx = (SirenJSONcontext*) ctx;
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
    SirenJSONcontext *jctx = (SirenJSONcontext*) ctx;
    
    if(IsntNull(jctx)  )
    {
        
        jctx->level--;
        
    }
    
    
    return 1;
}


static int sParse_bool(void * ctx, int boolVal)
{
    SirenJSONcontext *jctx = (SirenJSONcontext*) ctx;
    
    uint8_t     val = boolVal?1:0;
    
    if(jctx->validItem)
    {
        char buffer[2] = {'1',0};
        buffer[1] = val;
        
        uint8_t* data =  (uint8_t*) XMALLOC(sizeof(buffer));
        if(!data) return 0;
        
        COPY(buffer, data, sizeof(buffer));
        
        jctx->hashableItems[jctx->hashableItemsCount].data = data;
        jctx->hashableItems[jctx->hashableItemsCount].dataLen = sizeof(buffer);
        jctx->hashableItemsCount++;
    }
    return 1;
}


static int sParse_number(void * ctx, const char * stringVal, size_t stringLen)
{
    SirenJSONcontext *jctx = (SirenJSONcontext*) ctx;
    
    if(jctx->validItem)
    {
        uint16_t    len = (uint16_t)stringLen;
        
        char buffer[8];
        sprintf(buffer,"%d",len);
        
        uint16_t    totalLen = len + strlen(buffer);
        
        uint8_t* data =  XMALLOC(totalLen);
        if(!data) return 0;
        
        COPY(buffer, data, strlen(buffer));
        COPY(stringVal, data + strlen(buffer), stringLen);
        
        jctx->hashableItems[jctx->hashableItemsCount].data = data;
        jctx->hashableItems[jctx->hashableItemsCount].dataLen = totalLen;
        jctx->hashableItemsCount++;
    }
    
    
    return 1;
}


static int sParse_string(void * ctx, const unsigned char * stringVal,
                         size_t stringLen)
{
    SirenJSONcontext *jctx = (SirenJSONcontext*) ctx;
    
    if(jctx->validItem)
    {
        uint16_t    len = (uint16_t)stringLen;
        uint16_t    totalLen = len + sizeof(len);
        
        uint8_t* data =  XMALLOC(totalLen);
        if(!data) return 0;
        
        COPY(&len, data, sizeof(len));
        COPY(stringVal, sizeof(len) + data, len);
        
        jctx->hashableItems[jctx->hashableItemsCount].data = data;
        jctx->hashableItems[jctx->hashableItemsCount].dataLen = totalLen;
        jctx->hashableItemsCount++;
    }
    
    return 1;
}

static int sParse_map_key(void * ctx, const unsigned char * stringVal,
                          size_t stringLen)
{
    SirenJSONcontext *jctx = (SirenJSONcontext*) ctx;
    
    jctx->validItem =  0;
    char** tagP;
    for(tagP = sHashable_tags_list; *tagP; tagP++ )
    {
        
        if((strlen(*tagP) == stringLen)
           &&  CMP(stringVal, *tagP, stringLen))
        {
            // mark the item as usable
            jctx->hashableItems[jctx->hashableItemsCount].tag = *tagP;
            jctx->validItem = 1;
            break;
        }
    }
    
#if DEBUG_HASH
    if(!jctx->validItem)
        DPRINTF(XCODE_COLORS_RED_TXT,"\t%.*15s skipped\n", stringLen,stringVal );
#endif
    
    return 1;
}

/* has the item presented and free any memory used by it*/
SCLError  shashItem(HASH_ContextRef ctx, HashableItem *item)
{
    SCLError        err = kSCLError_NoErr;
    if(!item) goto done;
    
    
#if DEBUG_HASH
    DPRINTF(XCODE_COLORS_RED_TXT,"\t%15s %4d %04x\n", item->tag, (int)item->dataLen, crc16(item->data, item->dataLen));
#endif
    
    if(item->tag)
    {
        uint16_t    tagLen = (uint16_t)strlen(item->tag);
        err = HASH_Update(ctx, &tagLen, sizeof(tagLen));    CKERR;
        err = HASH_Update(ctx, item->tag, tagLen);          CKERR;
    }
    if(item->data  && item->dataLen)
    {
        err = HASH_Update(ctx, item->data, item->dataLen);  CKERR;
        XFREE(item->data);
    }
    
    ZERO(item, sizeof(item));
    
done:
    
    return err;
    
}
SCLError  Siren_ComputeHash(    HASH_Algorithm  hash,
                            const char*         sirenData,
                            uint8_t*            hashOut,
                            bool                sorted)
{
    SCLError        err = kSCLError_NoErr;
    
    yajl_gen_status         stat = yajl_gen_status_ok;
    yajl_handle             pHand = NULL;
    SirenJSONcontext       *jctx = NULL;
    
    static yajl_callbacks callbacks = {
        NULL,
        sParse_bool,
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
    
    
    jctx = XMALLOC(sizeof (SirenJSONcontext)); CKNULL(jctx);
    ZERO(jctx, sizeof(SirenJSONcontext));
    err  = HASH_Init(hash, &jctx->hash); CKERR;
    
    // use yajl to fill the hashableItems with tags and values we can hash
    pHand = yajl_alloc(&callbacks, &allocFuncs, (void *) jctx);
    yajl_config(pHand, yajl_allow_comments, 1);
    stat = (yajl_gen_status) yajl_parse(pHand, (uint8_t*)sirenData,  strlen(sirenData)); CKSTAT;
    stat = (yajl_gen_status) yajl_complete_parse(pHand); CKSTAT;
    
    
    // hash the items found in hashableItems using sHashable_tags_list order
    int items2Hash = jctx->hashableItemsCount;
    
#if DEBUG_HASH
    DPRINTF(XCODE_COLORS_RED_TXT,"\nSiren_ComputeHash %s\n",  sorted?"sorted":""  );
#endif
    
    if(sorted)
    {
        for(int j = 0; sHashable_tags_list[j] && items2Hash > 0; j++)
        {
            for(int i = 0; i < jctx->hashableItemsCount; i++)
            {
                char* tag = sHashable_tags_list[j];
                HashableItem *item = &jctx->hashableItems[i];
                
                if(item->tag && strncmp(tag, item->tag, strlen(tag)) == 0 )
                {
                    err = shashItem(jctx->hash, item);
                    items2Hash--;
                    break;
                }
            }
        }
    }
    else
    {
        for(int i = 0; i < items2Hash; i++)
        {
            HashableItem *item = &jctx->hashableItems[i];
            
            if(item->tag)
            {
                err = shashItem(jctx->hash, item);
            }
        }
        
    }
    
    err = HASH_Final(jctx->hash, hashOut); CKERR;
    
#if DEBUG_HASH
    DPRINTF(XCODE_COLORS_RED_TXT,"\n");
    dumpHex(hashOut,  32, 0);
    DPRINTF(XCODE_COLORS_RED_TXT,"\n");
#endif
    
done:
    
    if(IsntNull(jctx))
    {
        ZERO(jctx, sizeof(SirenJSONcontext));
        XFREE(jctx);
    }
    
    if(IsntNull(pHand))
        yajl_free(pHand);
    
    return err;
    
}


