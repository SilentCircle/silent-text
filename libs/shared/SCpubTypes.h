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

#ifndef Included_scPubTypes_h	/* [ */
#define Included_scPubTypes_h

#include <limits.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

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


#ifndef IsntNull
#define IsntNull( p )	( (int) ( (p) != NULL ) )
#endif


#ifndef IsNull
#define IsNull( p )		( (int) ( (p) == NULL ) )
#endif

#define RETERR(x)	do { err = x; goto done; } while(0)

#define COPY(b1, b2, len)							\
memcpy((void *)(b2), (void *)b1, (int)(len) )

#define ZERO(b1, len) \
memset((void *)(b1), 0, (int)(len) )


#define CMP(b1, b2, length)							\
(memcmp((void *)(b1), (void *)(b2), (length)) == 0)


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
    
    kSCLError_NoErr =0,
    kSCLError_NOP,
	kSCLError_UnknownError,
	kSCLError_BadParams,
	kSCLError_OutOfMemory,
	kSCLError_BufferTooSmall,
    
    kSCLError_UserAbort,
	kSCLError_UnknownRequest,
	kSCLError_LazyProgrammer,
    
	kSCLError_AssertFailed,
    
	kSCLError_FeatureNotAvailable,
	kSCLError_ResourceUnavailable,
	kSCLError_NotConnected,
	kSCLError_ImproperInitialization,
	kSCLError_CorruptData,
	kSCLError_SelfTestFailed,
	kSCLError_BadIntegrity,
	kSCLError_BadHashNumber,
	kSCLError_BadCipherNumber,
    kSCLError_BadPRNGNumber,

    kSCLError_SecretsMismatch,
    kSCLError_KeyNotFound,
 
    kSCLError_ProtocolError,
    kSCLError_ProtocolContention,
    
    kSCLError_EndOfIteration

};

typedef int SCLError;


#endif /* Included_scPubTypes_h */ /* ] */

