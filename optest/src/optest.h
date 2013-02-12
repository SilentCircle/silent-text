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
//  optest.h
//  tomcrypt
//

#ifndef tomcrypt_optest_h
#define tomcrypt_optest_h
#include <tomcrypt.h>


//#include "SCpubTypes.h"
#include "cryptowrappers.h"


#define ALLOC(_n) malloc(_n)
#define FREE(_p) free(_p)
#define REALLOC(_p,_n) realloc(_p, _n)



#define DO(x) do { run_cmd((x), __LINE__, __FILE__, #x); } while (0);

#if  OPTEST_IOS_SPECIFIC

int printf(const char*, ...);

#else
#define printf printf
#endif

typedef enum 
{
	kResultFormat_None  = 0,
	kResultFormat_Byte, 
	kResultFormat_Long,
    
} DumpFormatType;

char *hash_algor_table(HASH_Algorithm algor);
void dumpHex8(  uint8_t* buffer);
void dumpHex32(  uint8_t* buffer);

void dumpHex(  uint8_t* buffer, int length, int offset);
void dumpLong(uint8_t* buffer, int length);
int compareResults(const void* expected, const void* calculated, size_t len, 
                  DumpFormatType format, char* comment );

void run_cmd(int res, int line, char *file, char *cmd);

int TestCiphers();
int TestStorageCiphers();
int TestHash();
int TestHMAC();
int TestGCM();
int TestCCM();
int TestPK(prng_state * PRNG);
int otrMathTest();
int TestECC_DH();

SCLError TestKDF();


#endif
