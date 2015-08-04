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
//  optest.h
//  tomcrypt
//

#ifndef tomcrypt_optest_h
#define tomcrypt_optest_h

#include  "SCcrypto.h"
 
#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
#define OPTEST_IOS_SPECIFIC 1
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
#define OPTEST_OSX_SPECIFIC 1
#endif

#define STRICMP		strcasecmp


#define ALLOC(_n) malloc(_n)
#define FREE(_p) free(_p)
#define REALLOC(_p,_n) realloc(_p, _n)



#define DO(x) do { run_cmd((x), __LINE__, __FILE__, #x); } while (0);
typedef enum 
{
	kResultFormat_None  = 0,
	kResultFormat_Byte, 
	kResultFormat_Long,
    
} DumpFormatType;


#define OPTESTLOG_FLAG_ERROR    (1 << 0)  // 0...0001
#define OPTESTLOG_FLAG_WARN     (1 << 1)  // 0...0010
#define OPTESTLOG_FLAG_INFO     (1 << 2)  // 0...0100
#define OPTESTLOG_FLAG_VERBOSE  (1 << 3)  // 0...1000
#define OPTESTLOG_FLAG_DEBUG    (1 << 4)  // 0...10000

#define OPTESTLOG_LEVEL_OFF     0
#define OPTESTLOG_LEVEL_ERROR   (OPTESTLOG_FLAG_ERROR)                                                    // 0...0001
#define OPTESTLOG_LEVEL_WARN    (OPTESTLOG_FLAG_ERROR | OPTESTLOG_FLAG_WARN)                                    // 0...0011
#define OPTESTLOG_LEVEL_INFO    (OPTESTLOG_FLAG_ERROR | OPTESTLOG_FLAG_WARN | OPTESTLOG_FLAG_INFO)                    // 0...0111
#define OPTESTLOG_LEVEL_VERBOSE (OPTESTLOG_FLAG_ERROR | OPTESTLOG_FLAG_WARN | OPTESTLOG_FLAG_INFO | OPTESTLOG_FLAG_VERBOSE) // 0...1111
#define OPTESTLOG_LEVEL_DEBUG   (OPTESTLOG_FLAG_ERROR | OPTESTLOG_FLAG_WARN | OPTESTLOG_FLAG_INFO | OPTESTLOG_FLAG_VERBOSE | OPTESTLOG_FLAG_DEBUG) // 0...11111

#define IF_LOG_ERROR   (gLogLevel & OPTESTLOG_FLAG_ERROR)
#define IF_LOG_WARN    (gLogLevel & OPTESTLOG_FLAG_WARN)
#define IF_LOG_INFO    (gLogLevel & OPTESTLOG_FLAG_INFO)
#define IF_LOG_VERBOSE (gLogLevel & OPTESTLOG_FLAG_VERBOSE)
#define IF_LOG_DEBUG   (gLogLevel & OPTESTLOG_FLAG_DEBUG)

#define OPTESTLogError(frmt, ...)   LOG_MAYBE(IF_LOG_ERROR,    frmt, ##__VA_ARGS__)
#define OPTESTLogWarn(frmt, ...)    LOG_MAYBE(IF_LOG_WARN,     frmt, ##__VA_ARGS__)
#define OPTESTLogInfo(frmt, ...)    LOG_MAYBE(IF_LOG_INFO,     frmt, ##__VA_ARGS__)
#define OPTESTLogVerbose(frmt, ...) LOG_MAYBE(IF_LOG_VERBOSE,  frmt, ##__VA_ARGS__)
#define OPTESTLogDebug(frmt, ...)   LOG_MAYBE(IF_LOG_DEBUG,    frmt, ##__VA_ARGS__)

#define LOG_MAYBE(  flg, frmt, ...) \
do { if(flg) OPTESTPrintF(frmt, ##__VA_ARGS__); } while(0)


extern unsigned int gLogLevel;

int OPTESTPrintF(const char *, ...);
 
char *hash_algor_table(HASH_Algorithm algor);
char *cipher_algor_table(Cipher_Algorithm algor);
char *sckey_suite_table(SCKeySuite   keySuite);
char *scimp_suite_table(SCimpCipherSuite    cipherSuite);
char*  scimp_method_table( SCimpMethod method );
char*  scimp_stateInfo_table( SCimpState state );

void dumpHex8(int logFlag,  uint8_t* buffer);
void dumpHex32(int logFlag,  uint8_t* buffer);
void dumpHex(int logFlag,  uint8_t* buffer, int length, int offset);
void dumpLong(int logFlag, uint8_t* buffer, int length);

void dumpByteConst( uint8_t* buffer, size_t length);  // used for creating consts;

int compareResults(const void* expected, const void* calculated, size_t len, 
                  DumpFormatType format, char* comment );

int compare2Results(const void* expected, size_t expectedLen,
                    const void* calculated, size_t  calculatedLen,
                   DumpFormatType format, char* comment );




SCLError TestHash();
SCLError TestHMAC();
SCLError TestCiphers();
SCLError TestECC();
SCLError TestCCM();
SCLError TestP2K();
SCLError TestSirenHash();
SCLError TestSCKeys();
SCLError TestSCloud();
SCLError  TestSCIMP();
#endif
