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


#ifndef Included_scKAPS_h	/* [ */
#define Included_scKAPS_h

#pragma mark
#pragma mark KAPS Public Defines

typedef struct SCKAPSContext *      SCKAPSContextRef;

/*____________________________________________________________________________
 Invalid values for each of the "ref" data types. Use these for assignment
 and initialization only. Use the SCXXXRefIsValid macros (below) to test
 for valid/invalid values.
 ____________________________________________________________________________*/

#define	kInvalidSCKAPSContextRef		((SCKAPSContextRef) NULL)

/*____________________________________________________________________________
 Macros to test for ref validity. Use these in preference to comparing
 directly with the kInvalidXXXRef values.
 ____________________________________________________________________________*/

#define SCKAPSContextRefIsValid( ref )		( (ref) != kInvalidSCKAPSContextRef )

/*____________________________________________________________________________
 KAPS protocol Messages	
 ____________________________________________________________________________*/

enum KAPSMsg_
{
    kKAPSMsg_Commit     = 0,
    kKAPSMsg_DH1        = 1,
    kKAPSMsg_DH2        = 2,
    kKAPSMsg_Confirm    = 3,
    
    ENUM_FORCE( KAPSMsg_ )
};
ENUM_TYPEDEF( KAPSMsg_, KAPSMsg   );

enum KAPSPublicKeyAlgorithm_
{
    kKAPSPublicKeyAlgorithm_Invalid   = 0,
    kKAPSPublicKeyAlgorithm_ECDH_P384 = 1,
    kKAPSPublicKeyAlgorithm_ECDH_P256 = 2,
    
    ENUM_FORCE( KAPSPublicKeyAlgorithm_ )
};
ENUM_TYPEDEF( KAPSPublicKeyAlgorithm_, KAPSPublicKeyAlgorithm   );

enum KAPSAuthTag_
{
    kKAPSAuthTag_Invalid = 0,
    kKAPSAuthTag_OMAC16 = 1,      
    kKAPSAuthTag_OMAC24 = 2,      
    kKAPSAuthTag_OMAC32 = 3,      
    
    ENUM_FORCE( KAPSAuthTag_ )
};
ENUM_TYPEDEF( KAPSAuthTag_, KAPSAuthTag   );

enum KAPSHashAlgorithm_
{
    kKAPSHashAlgorithm_Invalid  = 0,
    kKAPSHashAlgorithm_Skein512  = 1,
    kKAPSHashAlgorithm_SHA512    = 2,
    
    ENUM_FORCE( KAPSHashAlgorithm_ )
};
ENUM_TYPEDEF( KAPSHashAlgorithm_, KAPSHashAlgorithm   );

enum KAPSMACAlgorithm_
{
    kKAPSMACAlgorithm_Invalid  = 0,
    kKAPSMACAlgorithm_Skein512  = 1,
    kKAPSMACAlgorithm_HMAC512   = 2,
    
    ENUM_FORCE( KAPSMACAlgorithm_ )
};
ENUM_TYPEDEF( KAPSMACAlgorithm_, KAPSMACAlgorithm   );


enum KAPSCipherAlgorithm_
{
    kKAPSCipherAlgorithm_Invalid  = 0,
    kKAPSCipherAlgorithm_AES256  = 1,
    
    ENUM_FORCE( KAPSCipherAlgorithm_ )
};
ENUM_TYPEDEF( KAPSCipherAlgorithm_, KAPSCipherAlgorithm   );


enum KAPSsas_
{
    kKAPSSAS_Invalid = 0,    
   kKAPSSAS_ZJC11 = 1,     /* 4 char Base 32 */
    kKAPSSAS_NATO  = 2,     /* NATO Phonetic Alphabet 4 words */
    
    ENUM_FORCE( KAPSAS_ )
};
ENUM_TYPEDEF( KAPSsas_, KAPSsas   );

enum KAPSProperty_
{
    kKAPSProperty_Invalid  = 0,

    /* Numeric Properties */
    kKAPSProperty_PublicKeyAlgorithm,
    kKAPSProperty_MACAlgorithm,
    kKAPSProperty_HASHAlgorithm,
    kKAPSProperty_CipherAlgorithm,
    kKAPSProperty_SASMethod,
    kKAPSProperty_AuthTagMethod,
     
    
    /* Data Properties */
    kKAPSProperty_SharedSecret,
    kKAPSProperty_NextSecret,
    kKAPSProperty_SASstring,
    
    ENUM_FORCE( KAPSProperty_ )
};

ENUM_TYPEDEF( KAPSProperty_, KAPSProperty   );


typedef struct KAPSInfo
{
    BYTE                    version;        /* protocol version */
    KAPSPublicKeyAlgorithm  pkAlg;
    KAPSMACAlgorithm        macAlg;
    KAPSHashAlgorithm       hashAlg;
    KAPSsas                 sasMethod;
    KAPSCipherAlgorithm     cipherAlg;
    KAPSAuthTag             authTag;
    
    Boolean                 isInitiator;    /* this is the initiator */
    Boolean                 hasCs;          /* has existing shared secret */
    Boolean                 csMatches;      /* hashes of cached shared secret match */

} KAPSInfo;


int 
SCNewKAPS(
          Boolean                   isInitiator, 
          char*                     initiatorStr, 
          char*                     responderStr,
           SCKAPSContextRef *       outKaps 
          );

 
int SCGetKapsSASString(SCKAPSContextRef kaps, char *sasStr, size_t *sasStrLen);

int SCGetKapsInfo( SCKAPSContextRef kaps, KAPSInfo* info);

void SCFreeKAPS(SCKAPSContextRef kaps);

int SCGetKAPSNumericProperty( SCKAPSContextRef kaps,
                          KAPSProperty whichProperty, 
                          UInt32 *prop);

int SCSetKAPSNumericProperty( SCKAPSContextRef kaps,
                             KAPSProperty whichProperty, 
                             UInt32 prop);

int SCGetKAPSDataProperty( SCKAPSContextRef kaps,
                           KAPSProperty whichProperty, 
                          void *buffer, size_t bufSize, size_t *datSize);


int SCGetKAPSAllocatedDataProperty( SCKAPSContextRef kaps,
                                   KAPSProperty whichProperty, 
                                   void **outData, size_t *datSize);

 int SCSetKAPSDataProperty( SCKAPSContextRef kaps,
                          KAPSProperty whichProperty, 
                           void *data,  size_t  datSize);



#endif /* Included_scKAPS_h */ /* ] */
