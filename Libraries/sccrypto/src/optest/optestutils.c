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
//  optestutils.c
//  optest
//

#include <stdio.h>
#include <stdarg.h>
#include <stdio.h>

#include "SCcrypto.h"

#include "crypto_optest.h"

void OutputString(char *s);

#ifdef OPTEST_IOS_SPECIFIC

#elif defined(OPTEST_OSX_SPECIFIC) || (OPTEST_LINUX_SPECIFIC)

#ifndef INXCTEST

void OutputString(char *s)
{
    printf( "%s",s);
}

#endif
#endif



int OPTESTPrintF( const char *fmt, ...)
{
    va_list marker;
    char s[8096];
    int len;
    
    va_start( marker, fmt );
    len = vsprintf( s, fmt, marker );
    va_end( marker );
    
    OutputString(s);
    
    return 0;
}

int OPTESTVPrintF( const char *fmt, va_list marker)
{
    char s[8096];
    int	len;
    
    len = vsprintf( s, fmt, marker );
    
    OutputString(s);
    
    return 0;
}

void dumpHex8(int logFlag,  uint8_t* buffer)
{
    char hexDigit[] = "0123456789ABCDEF";
	register int			i;
	const unsigned char	  *bufferPtr = buffer;
    
    if(!logFlag) return;
    
    for (i = 0; i < 8; i++){
        OPTESTPrintF( "%c",  hexDigit[ bufferPtr[i] >>4]);
        OPTESTPrintF("%c",  hexDigit[ bufferPtr[i] &0xF]);
        if((i) &0x01) OPTESTPrintF("%c", ' ');
    }
    
}


void dumpHex32(int logFlag,  uint8_t* buffer)
{
    char hexDigit[] = "0123456789ABCDEF";
	register int			i;
	const unsigned char	  *bufferPtr = buffer;
  
    if(!logFlag) return;

    for (i = 0; i < 32; i++){
        OPTESTPrintF( "%c",  hexDigit[ bufferPtr[i] >>4]);
        OPTESTPrintF( "%c",  hexDigit[ bufferPtr[i] &0xF]);
        if((i) &0x01) OPTESTPrintF( "%c", ' ');
    }
    
}

void dumpByteConst( uint8_t* buffer, size_t length)
{
#define kLineSize	8
    
    printf("\n");
    
   for( int count = 0; length;  buffer++, length--)
   {
        bool newLine = (++count == kLineSize);
       
       printf("0x%02x%s%s",
              *buffer,
              length > 1?",":"",
              newLine? "\n":"");
       
       if(newLine) count = 0;
   }
    printf("\n");
   
}

void dumpHex(int logFlag,  uint8_t* buffer, int length, int offset)
{
	char hexDigit[] = "0123456789ABCDEF";
	register int			i;
	int						lineStart;
	int						lineLength;
	short					c;
	const unsigned char	  *bufferPtr = buffer;
    
    char                    lineBuf[80];
    char                    *p;
    
    if(!logFlag) return;

#define kLineSize	8
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
        
		OPTESTPrintF( "%s\n",lineBuf);
	}
#undef kLineSize
}

void dumpLong(int logFlag ,uint8_t* buffer, int length)
{
	char hexDigit[] = "0123456789abcdef";
 	register int			i;
	int						lineStart;
	int						lineLength;
 	const uint8_t			 *bufferPtr = buffer;
	
    if(!logFlag) return;

#define kLineSize	16
	for (lineStart = 0; lineStart < length; lineStart += lineLength) {
		lineLength = kLineSize;
		if (lineStart + lineLength > length)
			lineLength = length - lineStart;
        
		OPTESTPrintF("%6s ", "");
		for (i = 0; i < lineLength; i++){
#if 1
			OPTESTPrintF("%c",  hexDigit[ bufferPtr[lineStart+i] >>4]);
			OPTESTPrintF("%c",  hexDigit[ bufferPtr[lineStart+i] &0xF]);
	 		if( ((lineStart+i) & 0x3)  == 0x3) OPTESTPrintF("%c", ' ');
#else
			OPTESTPrintF("0x%c%c, ", hexDigit[ bufferPtr[lineStart+i] >>4] ,  hexDigit[ bufferPtr[lineStart+i] &0xF]);
#endif
            
		}
        OPTESTPrintF("\n");
	}
#undef kLineSize
}

static void dump64(int logFlag,uint8_t* b, size_t cnt )
{
    if(!logFlag) return;

    size_t i, j;
    for (i=0;i < cnt; i=i+8)
    {
        OPTESTPrintF( "0x");
        for(j=8; j > 0; j--)
            OPTESTPrintF("%02X",b[i+j-1]);
        OPTESTPrintF( "L, ");
        
        if (i %16 == 15 || i==cnt-1) OPTESTPrintF("\n");
    }
    OPTESTPrintF("\n");
}

int compare2Results(const void* expected, size_t expectedLen,
                    const void* calculated, size_t  calculatedLen,
                    DumpFormatType format, char* comment )
{
    SCLError err = kSCLError_NoErr;
 
    if(calculatedLen != expectedLen)
    {
        OPTESTLogError( "\n\t\tFAILED %s \n",comment );
        OPTESTLogError( "\t\texpected %d bytes , calculated %d bytes \n", expectedLen, calculatedLen);
        err =  kSCLError_SelfTestFailed;
    }
    else
        err = compareResults(expected,calculated , expectedLen, format, comment );
    
 return err;
}


SCLError compareResults(const void* expected, const void* calculated, size_t len, 
                   DumpFormatType format, char* comment  )
{
    SCLError err = kSCLError_NoErr;
 	
	err = CMP(expected, calculated, len) 
	? kSCLError_NoErr : kSCLError_SelfTestFailed;
	
 	if( (err != kSCLError_NoErr)  && IsntNull(comment) && (format != kResultFormat_None))
	{	
		OPTESTLogError( "\n\t\tFAILED %s\n",comment );
		switch(format)
		{
			case kResultFormat_Byte:
				OPTESTLogError( "\t\texpected:\n");
				dumpHex(IF_LOG_ERROR, ( uint8_t*) expected, (int)len, 0);
				OPTESTLogError( "\t\tcalulated:\n");
				dumpHex(IF_LOG_ERROR,( uint8_t*) calculated, (int)len, 0);
 				OPTESTLogError( "\n");
				break;
				
			case kResultFormat_Long:
				OPTESTLogError( "\t\texpected:\n");
				dump64(IF_LOG_ERROR,( uint8_t*) expected, len);
				OPTESTLogError( "\t\tcalulated:\n");
				dump64(IF_LOG_ERROR,( uint8_t*) calculated, len );
				OPTESTLogError( "\n");
				break;
				
                
			default:
				break;
 		}
 	}
	
	return err;
}

 
char *hash_algor_table(HASH_Algorithm algor)
{
 	switch (algor )
	{
 		case kHASH_Algorithm_SHA1: 		return (("SHA-1"));
 		case kHASH_Algorithm_SHA224:		return (("SHA-224"));
		case kHASH_Algorithm_SHA256:		return (("SHA-256"));
		case kHASH_Algorithm_SHA384:		return (("SHA-384"));
		case kHASH_Algorithm_SHA512:		return (("SHA-512"));						
        case kHASH_Algorithm_SHA512_256:	return (("SHA-512/256"));						
		case kHASH_Algorithm_SKEIN256:		return (("SKEIN-256"));						
		case kHASH_Algorithm_SKEIN512:		return (("SKEIN-512"));						
		case kHASH_Algorithm_SKEIN1024:		return (("SKEIN-1024"));						
		default:				return (("Invalid"));
	}
}


char *cipher_algor_table(Cipher_Algorithm algor)
{
    switch (algor )
    {
        case kCipher_Algorithm_AES128: 		return (("AES-128"));
        case kCipher_Algorithm_AES192: 		return (("AES-193"));
        case kCipher_Algorithm_AES256: 		return (("AES-256"));
        case kCipher_Algorithm_2FISH256: 		return (("Twofish-256"));
         default:				return (("Invalid"));
    }
}

char *sckey_suite_table(SCKeySuite    keySuite)
{
    switch (keySuite )
    {
        case kSCKeySuite_AES128: 		return (("AES-128"));
        case kSCKeySuite_AES256: 		return (("AES-256"));
        case kSCKeySuite_ECC384: 		return (("ECC-384"));
        case kSCKeySuite_ECC414: 		return (("ECC-Curve3617"));
        case kSCKeySuite_2FISH256: 		return (("Twofish-256"));
          default:				return (("Invalid"));
    }
}

char *scimp_suite_table(SCimpCipherSuite    cipherSuite)
{
    switch (cipherSuite )
    {
        case kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384: 		return ("AES-128 - SHA-256 - ECC-384");
        case kSCimpCipherSuite_SHA512256_HMAC_AES256_ECC384:    return ("AES-256 - SHA-512/256 - ECC-384");
        case kSCimpCipherSuite_SKEIN_AES256_ECC384:             return (("AES-256 - SKEIN - ECC-384"));
        case kSCimpCipherSuite_SKEIN_2FISH_ECC414:             return (("Twofish-256 - SKEIN - ECC-Curve3617"));
          default:				return (("Invalid"));
    }
}


char*  scimp_method_table( SCimpMethod method )
{
    static struct
    {
        SCimpMethod      method;
        char*           txt;
    }method_txt[] =
    {
        { kSCimpMethod_Invalid,		"Invalid"},
        { kSCimpMethod_DH,          "DH"},
        { kSCimpMethod_Symmetric,   "Symmetric"},
        { kSCimpMethod_PubKey,		"Public Key"},
        { kSCimpMethod_DHv2,         "DHv2"},
        {0,NULL}
    };
    
    int i;
    
    for(i = 0; method_txt[i].txt; i++)
        if(method_txt[i].method == method) return(method_txt[i].txt);
    
    return "Invalid";
    
}


char*  scimp_stateInfo_table( SCimpState state )
{
    static struct
    {
        SCimpState      state;
        char*           txt;
    }state_txt[] =
    {
        { kSCimpState_Init,		"Init"},
        { kSCimpState_Ready,	"Ready"},
        { kSCimpState_Error,    "Error" },
        { kSCimpState_Commit,	"Commit"},
        { kSCimpState_DH2,		"DH2"},
        { kSCimpState_DH1,		"DH1"},
        { kSCimpState_Confirm,	"Confirm"},
        { kSCimpState_PKStart,  "PK-Start"},
        { kSCimpState_PKCommit,  "PK-Commit"},
        { kSCimpState_PKInit,   "PK-Init"},
        {NO_NEW_STATE,         "NO_NEW_STATE"},
        {0,NULL}
    };
    
    int i;
    
    for(i = 0; state_txt[i].txt; i++)
        if(state_txt[i].state == state) return(state_txt[i].txt);
    
    return "Invalid";
    
}


