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
//
//  optestutils.c
//  optest
//

#include <stdio.h>
#include <tomcrypt.h>


#include "optest.h"

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


void dumpHex32(  uint8_t* buffer)
{
    char hexDigit[] = "0123456789ABCDEF";
	register int			i;
	const unsigned char	  *bufferPtr = buffer;
    
    for (i = 0; i < 32; i++){
        printf("%c",  hexDigit[ bufferPtr[i] >>4]);
        printf("%c",  hexDigit[ bufferPtr[i] &0xF]);
        if((i) &0x01) printf("%c", ' ');
    }
    
}

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

void dumpLong(uint8_t* buffer, int length)
{
	char hexDigit[] = "0123456789abcdef";
 	register int			i;
	int						lineStart;
	int						lineLength;
 	const uint8_t			 *bufferPtr = buffer;
	
#define kLineSize	16
	for (lineStart = 0; lineStart < length; lineStart += lineLength) {
		lineLength = kLineSize;
		if (lineStart + lineLength > length)
			lineLength = length - lineStart;
        
		printf("%6s ", "");
		for (i = 0; i < lineLength; i++){
#if 1
			printf("%c",  hexDigit[ bufferPtr[lineStart+i] >>4]);
			printf("%c",  hexDigit[ bufferPtr[lineStart+i] &0xF]);
	 		if( ((lineStart+i) & 0x3)  == 0x3) printf("%c", ' ');
#else
			printf("0x%c%c, ", hexDigit[ bufferPtr[lineStart+i] >>4] ,  hexDigit[ bufferPtr[lineStart+i] &0xF]);
#endif
            
		}
        printf("\n");
	}
#undef kLineSize
}

static void dump64(uint8_t* b, size_t cnt )
{
    size_t i, j;
    for (i=0;i < cnt; i=i+8)
    {
        printf( "0x");
        for(j=8; j > 0; j--)
            printf("%02X",b[i+j-1]);
        printf( "L, ");
        
        if (i %16 == 15 || i==cnt-1) printf("\n");
    }
    printf("\n");
}



int compareResults(const void* expected, const void* calculated, size_t len, 
                   DumpFormatType format, char* comment )
{
    int err = CRYPT_OK;
 	
	err = CMP(expected, calculated, len) 
	? CRYPT_OK : CRYPT_ERROR;  
	
 	if( (err != CRYPT_OK)  && IsntNull(comment) && (format != kResultFormat_None))
	{	
		printf("\n\t\tFAILED %s\n",comment);
		switch(format)
		{
			case kResultFormat_Byte:
				printf("\t\texpected:\n");
				dumpHex(( uint8_t*) expected, len, 0);
				printf("\t\tcalulated:\n");
				dumpHex(( uint8_t*) calculated, len, 0);
 				printf("\n");
				break;
				
			case kResultFormat_Long:
				printf("\t\texpected:\n");
				dump64(( uint8_t*) expected, len);
				printf("\t\tcalulated:\n");
				dump64(( uint8_t*) calculated, len );
				printf("\n");
				break;
				
			default:
				break;
 		}
 	}
	
	return err;
}

void run_cmd(int res, int line, char *file, char *cmd)
{
    if (res != CRYPT_OK) {
        fprintf(stderr, "%s (%d)\n%s:%d:%s\n", error_to_string(res), res, file, line, cmd);
        if (res != CRYPT_NOP) {
            exit(EXIT_FAILURE);
        }
    }
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
