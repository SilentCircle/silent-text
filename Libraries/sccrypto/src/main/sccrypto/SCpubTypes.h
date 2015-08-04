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
#ifndef Included_scPubTypes_h	/* [ */
#define Included_scPubTypes_h

#include <limits.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
//#include <time.h>

#ifdef __GNUC__
#define DEPRECATED(func) func __attribute__ ((deprecated))
#elif defined(_MSC_VER)
#define DEPRECATED(func) __declspec(deprecated) func
#else
#pragma message("WARNING: You need to implement DEPRECATED for this compiler")
#define DEPRECATED(func) func
#endif


#if ( DEBUG == 1 )
#define STATUS_LOG(...)	 printf(__VA_ARGS__)
#else
#define STATUS_LOG(...)
#endif

#define kEnumMaxValue		INT_MAX

#define ENUM_FORCE( enumName )		\
k ## enumName ## force = kEnumMaxValue

#if INT_MAX == 0x7FFFFFFFL
#define ENUM_TYPEDEF( enumName, typeName )	typedef enum enumName typeName
#else
#define ENUM_TYPEDEF( enumName, typeName )	typedef int32_t typeName
#endif

#ifndef MAX
#define MAX(a,b) (a >= b ? a : b)
#endif

#define IsSCLError(_err_)  (_err_ != kSCLError_NoErr) 
#define IsntSCLError(_err_)  (_err_ == kSCLError_NoErr) 

#define CKERR  if((err != kSCLError_NoErr)) {\
STATUS_LOG("ERROR %d  %s:%d \n",  err, __FILE__, __LINE__); \
goto done; }

#define ASSERTERR( _a_ , _err_ )  if((_a_))  { \
err = _err_; \
STATUS_LOG("ERROR %d  %s:%d \n",  err, __FILE__, __LINE__); \
goto done; }
 

#ifndef IsntNull
#define IsntNull( p )	( (int) ( (p) != NULL ) )
#endif


#ifndef IsNull
#define IsNull( p )		( (int) ( (p) == NULL ) )
#endif

#define RETERR(x)	do { err = x; goto done; } while(0)

#define COPY(b1, b2, len)							\
memcpy((void *)(b2), (void *)b1, (int)(len) )

static void * (* const volatile __memset_vp)(void *, int, size_t) = (memset);

#define ZERO(b1, len) \
(*__memset_vp)((void *)(b1), 0, (int)(len) )

#ifndef XMALLOC
#ifdef malloc
#define LTC_NO_PROTOTYPES
#endif
#define XMALLOC  malloc
#endif
#ifndef XREALLOC
#ifdef realloc
#define LTC_NO_PROTOTYPES
#endif
#define XREALLOC realloc
#endif
#ifndef XFREE
#ifdef free
#define LTC_NO_PROTOTYPES
#endif
#define XFREE    free
#endif

#define CMP(b1, b2, length)							\
(memcmp((void *)(b1), (void *)(b2), (length)) == 0)

#define CMP2(b1, l1, b2, l2)							\
(((l1) == (l2)) && (memcmp((void *)(b1), (void *)(b2), (l1)) == 0))

#define CKNULL(_p) if(IsNull(_p)) {\
err = kSCLError_OutOfMemory; \
goto done; }

#define BOOLVAL(x) (!(!(x)))

#define BitSet(arg,val) ((arg) |= (val))
#define BitClr(arg,val) ((arg) &= ~(val))
#define BitFlp(arg,val) ((arg) ^= (val))
#define BitTst(arg,val) BOOLVAL((arg) & (val))

#define ValidateParam( expr )	\
if ( ! (expr ) )	\
{\
STATUS_LOG("ERROR %s(%d): %s is not true\n",  __FILE__, __LINE__, #expr ); \
return( kSCLError_BadParams );\
};

#define ValidatePtr( ptr )	\
ValidateParam( (ptr) != NULL )


enum SCLError
{
    kSCLError_NoErr = 0,
    kSCLError_NOP,						// 1
	kSCLError_UnknownError,				// 2
	kSCLError_BadParams,				// 3
	kSCLError_OutOfMemory,				// 4
	kSCLError_BufferTooSmall,			// 5
    
    kSCLError_UserAbort,				// 6
	kSCLError_UnknownRequest,			// 7
	kSCLError_LazyProgrammer,			// 8
    
	kSCLError_AssertFailed,				// 9
    
	kSCLError_FeatureNotAvailable, 		// 10
	kSCLError_ResourceUnavailable, 		// 11
	kSCLError_NotConnected,				// 12
	kSCLError_ImproperInitialization,	// 13
	kSCLError_CorruptData,				// 14
	kSCLError_SelfTestFailed,			// 15
	kSCLError_BadIntegrity,				// 16
	kSCLError_BadHashNumber,			// 17
	kSCLError_BadCipherNumber,			// 18
    kSCLError_BadPRNGNumber,			// 19

    kSCLError_SecretsMismatch,			// 20
    kSCLError_KeyNotFound,				// 21

    kSCLError_ProtocolError,			// 22
    kSCLError_ProtocolContention,		// 23
  
    kSCLError_KeyLocked,				// 24
    kSCLError_KeyExpired,				// 25

    kSCLError_EndOfIteration,			// 26
    kSCLError_OtherError,				// 27
    kSCLError_PubPrivKeyNotFound		// 28

};

typedef int SCLError;


#endif /* Included_scPubTypes_h */ /* ] */

