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
//  SCkeys.c
//  shared
//

#include <ctype.h>


#ifndef __USE_BSD
#define __USE_BSD
#include <time.h>
#undef __USE_BSD
#endif

#include "yajl_parse.h"
#include <yajl_gen.h>

#include "SCcrypto.h"
#include "SCutilities.h"

#if defined(ANDROID)
#include "timegm.c"
#endif

#define SCKEY_HASH_LEN              32
#define SALT_BYTES                  8
#define PKDF_HASH_BYTES              16

#define kSCKeyProtocolVersion  0x02
#define MAX_PRIVKEY_LEN 256


#define CKSTAT  if((stat != yajl_gen_status_ok)) {\
printf("ERROR %d (%d)  %s:%d \n",  err, stat, __FILE__, __LINE__); \
err = kSCLError_CorruptData; \
goto done; }

#define CMP2(b1, l1, b2, l2)							\
(((l1) == (l2)) && (memcmp((void *)(b1), (void *)(b2), (l1)) == 0))

#define STRCMP2(s1, s2) \
    (CMP2((s1), strlen(s1), (s2), strlen(s2)))

#define K_KEYSUITE_AES128     "aes128"
#define K_KEYSUITE_AES256     "aes256"
#define K_KEYSUITE_2FISH256      "twofish256"
#define K_KEYSUITE_ECC384     "ecc384"
#define K_KEYSUITE_ECC414     "Curve3617"

#define K_KEYTYPE      "keyType"
#define K_KEYSUITE      "keySuite"
#define K_SYMKEY        "symkey"
#define K_START_DATE    "start_date"
#define K_EXPIRE_DATE   "expire_date"
#define K_LOCATOR       "locator"

#define K_ENCRYPT_LOCATOR   "encrypted_to"
#define K_SIGN_LOCATOR      "signed_by"
#define K_SIGNATURES      "signatures"

#define K_OWNER             "owner"
#define K_HASHLIST         "hashList"
#define K_SALT              "salt"
#define K_ROUNDS            "rounds"
#define K_KEYHASH           "keyHash"
#define K_KEYKDF           "kdf"
#define K_KEYKDF_PBKDF2     "pbkdf2"
#define K_IV                "iv"
#define K_HMAC_CODE         "HMAC_code"
#define K_PUB_X963           "ansi_x963"
#define K_SIGNATURE     "signature"



char *const kSCKeyProp_SCKeyType       = K_KEYTYPE;
char *const kSCKeyProp_SCKeySuite       = K_KEYSUITE;
char *const kSCKeyProp_SymmetricKey     = K_SYMKEY;
char *const kSCKeyProp_StartDate        = K_START_DATE;
char *const kSCKeyProp_ExpireDate       = K_EXPIRE_DATE;
char *const kSCKeyProp_Locator          = K_LOCATOR;

char *const kSCKeyProp_EncryptedTo      = K_ENCRYPT_LOCATOR;
char *const kSCKeyProp_SignedBy         = K_SIGN_LOCATOR;
char *const kSCKeyProp_Owner            = K_OWNER;
char *const kSCKeyProp_HashList         = K_HASHLIST;
char *const kSCKeyProp_KDF              = K_KEYKDF;
char *const kSCKeyProp_IV               = K_IV;
char *const kSCKeyProp_KeyHash          = K_KEYHASH;

char *const kSCKeyProp_HMACcode            = K_HMAC_CODE;
char *const kSCKeyProp_PubKeyANSI_X963     = K_PUB_X963;
char *const kSCKeyProp_Signature            = K_SIGNATURE;


#define K_VERSION       "version"
#define K_PUBKEY        "pubKey"
#define K_PRIVKEY       "privKey"
#define K_ENCSYMKEY     "encrypted"

static char *const kSCKeyProp_SCKeyVersion  = K_VERSION;
static char *const kSCKeyProp_PubKey        = K_PUBKEY;
static char *const kSCKeyProp_PrivKey       = K_PRIVKEY;
static char *const kSCKeyProp_EncryptedKey  = K_ENCSYMKEY;
static char *const kSCKeyProp_Salt          = K_SALT;
static char *const kSCKeyProp_Rounds        = K_ROUNDS;

static char *const kSCKeyProp_Signatures    = K_SIGNATURES;


static const char*  kSCKeyDefaultSignedPropertyList[] = {
    K_KEYSUITE, K_LOCATOR, K_START_DATE, K_EXPIRE_DATE,K_OWNER, K_SYMKEY,K_PUBKEY, K_IV, K_HMAC_CODE, NULL };


typedef struct SCPropertyInfo  SCPropertyInfo;


struct SCPropertyInfo
{
    char           *name;
    SCKeyPropertyType type;
    bool              readOnly;
} ;

static SCPropertyInfo sPropertyTable[] = {
    
    {K_KEYTYPE,    SCKeyPropertyType_Numeric,  true},
    {K_KEYSUITE,    SCKeyPropertyType_Numeric,  true},
    {K_SYMKEY,      SCKeyPropertyType_Binary,   true},
    {K_PUBKEY,      SCKeyPropertyType_Binary,   true},
    {K_LOCATOR,     SCKeyPropertyType_Binary,   false},
    {K_ENCRYPT_LOCATOR, SCKeyPropertyType_Binary,   false},
    {K_SIGN_LOCATOR, SCKeyPropertyType_Binary,      false},
    {K_HASHLIST,    SCKeyPropertyType_UTF8String,   true},
    {K_START_DATE,  SCKeyPropertyType_Time,     false},
    {K_EXPIRE_DATE, SCKeyPropertyType_Time,     false},
    {K_OWNER,       SCKeyPropertyType_UTF8String,     false},
    {K_IV,          SCKeyPropertyType_Binary,     false},
    {K_PUB_X963,    SCKeyPropertyType_Binary,     true},
      
    {K_HMAC_CODE,   SCKeyPropertyType_Binary,    true},
    {NULL,          SCKeyPropertyType_Invalid,  true},
};


enum SCKeyDF_
{
    SCKeyDF_Invalid             = 0,
    SCKeyDF_PBKDF2              = 1,
    
    ENUM_FORCE( SCKeyDF_ )
};


ENUM_TYPEDEF( SCKeyDF_, SCKeyDF   );

 
typedef struct SCProperty  SCProperty;

struct SCProperty
{
    uint8_t         *prop;
    SCKeyPropertyType type;
     uint8_t        *value;
    size_t          valueLen;
 
    SCProperty      *next;
} ;

typedef struct SCSigItem  SCSigItem;


typedef struct SCKeySymmetric_
{
    uint8_t        		symKey[64];
    
    uint8_t             *eSymKey;
    size_t              eSymKeyLen;
    
    uint8_t        		ePubLocator[SCKEY_LOCATOR_BYTES];
 
}SCKeySymmetric;

typedef struct SCKeyPublic_
{
    uint8_t             pubKey[256];
    size_t              pubKeyLen;
    
    uint8_t             *lockedPrivKey;
    uint8_t             *privKey;
    size_t              privKeyLen;
     
    ECC_ContextRef      ecc;
    
}SCKeyPublic;


typedef struct SCKeySignature_
{
    uint8_t            *signature;
    size_t             signatureLen;
    
    uint8_t             sPubLocator[SCKEY_LOCATOR_BYTES];
    time_t              startDate;
    time_t              expireDate;
    char**              hashList;   // pointer to array of strings
    
}SCKeySignature;

struct SCSigItem
{
    SCSigItem      *next;
    SCKeySignature  sig;
};

typedef struct SCKeyPassPhrase_
{
    SCKeyDF     kdf;
    uint8_t     lockedKey[64];
    uint8_t     salt[SALT_BYTES];
    uint32_t    rounds;
    uint8_t     keyHash[PKDF_HASH_BYTES];
    
}SCKeyPassPhrase;



typedef struct SCKeyHMAC_
{
    uint8_t             HMAC[SCKEY_LOCATOR_BYTES];
      
}SCKeyHMAC;

typedef struct SCKey_Context    SCKey_Context;

struct SCKey_Context
{
#define kSCKey_ContextMagic     0x53436B79 
	uint32_t            magic;
    SCKeyType           keyType;
    SCKey_Context       *next;      // used for chaining sigs
    
    SCKeySuite  		keySuite;
    union {
        SCKeySymmetric  sym;
        SCKeyPublic     pub;
        SCKeySignature  sig;
        SCKeyPassPhrase pass;
        SCKeyHMAC       hmac;
    };
    
    /* optional */
    uint8_t        		locator[SCKEY_LOCATOR_BYTES];
    time_t              startDate;
    time_t              expireDate;
    uint8_t*            owner;
    SCSigItem           *sigList;
    SCProperty          *propList;
} ;



#pragma mark - validity test


static bool
sSCKey_ContextIsValid( const SCKeyContextRef  ref)
{
	bool	valid	= false;
	
	valid	= IsntNull( ref ) && ref->magic	 == kSCKey_ContextMagic;
	
	return( valid );
}

#define validateSCKeyContext( s )		\
ValidateParam( sSCKey_ContextIsValid( s ) )

static bool
sSCKey_ContextIsECC( const SCKeyContextRef  ref)
{
    return (ref->keySuite == kSCKeySuite_ECC384) || (ref->keySuite == kSCKeySuite_ECC414);
}


#pragma mark - fwd declare

static bool sVerifyKeySig(SCKey_Context *ctx, const SCKeySignature *sig );
static SCKeySignature* sFindSignature(SCKey_Context *ctx, const uint8_t *signedBy );
static void sInsertProperty(SCKey_Context *ctx, const char *propName,
                            SCKeyPropertyType propType, void *data,  size_t  datSize);
static void sCloneSignatures(SCKey_Context *src, SCKey_Context *dest );
#pragma mark - utilities


size_t sGetKeyLength(SCKeySuite keySuite)
{
    size_t          keylen = 0;
    
    switch(keySuite)
    {
        case kSCKeySuite_AES128:
            keylen = 16;
            break;
            
        case kSCKeySuite_AES256:
            keylen = 32;
            break;
            
        case kSCKeySuite_2FISH256:
            keylen = 32;
            break;
           
        default:;
    }
    
    return keylen;
    
}


static SCKeySuite sParseKeySuiteString(const unsigned char * stringVal,
                                size_t stringLen)
{
    SCKeySuite keySuite = kEnumMaxValue;
    
    if(CMP2(stringVal, stringLen, K_KEYSUITE_AES128, strlen(K_KEYSUITE_AES128)))
    {
        keySuite = kSCKeySuite_AES128;
    }
    else if(CMP2(stringVal, stringLen, K_KEYSUITE_AES256, strlen(K_KEYSUITE_AES256)))
    {
        keySuite = kSCKeySuite_AES256;
       
    }
    else if(CMP2(stringVal, stringLen, K_KEYSUITE_2FISH256, strlen(K_KEYSUITE_2FISH256)))
    {
        keySuite = kSCKeySuite_2FISH256;
    }
     else if(CMP2(stringVal, stringLen, K_KEYSUITE_ECC384, strlen(K_KEYSUITE_ECC384)))
    {
        keySuite = kSCKeySuite_ECC384;
    }
    else if(CMP2(stringVal, stringLen, K_KEYSUITE_ECC414, strlen(K_KEYSUITE_ECC414)))
    {
        keySuite = kSCKeySuite_ECC414;
    }
    
    
    return keySuite;
}

static char * sKeySuiteString(SCKeySuite keySuite)
{
     switch(keySuite)
    {
        case kSCKeySuite_AES128: return K_KEYSUITE_AES128;
        case kSCKeySuite_AES256: return K_KEYSUITE_AES256;
        case kSCKeySuite_2FISH256: return K_KEYSUITE_2FISH256;
        case kSCKeySuite_ECC384: return K_KEYSUITE_ECC384;
        case kSCKeySuite_ECC414: return K_KEYSUITE_ECC414;
        default:;
    }
       return "Invalid";
}



static const char *kRfc339Format = "%Y-%m-%dT%H:%M:%SZ";

static time_t parseRfc3339(const unsigned char *s, size_t stringLen)
{
	struct tm tm;
	time_t t;
    const unsigned char *p = s;
    
    if(stringLen < strlen("YYYY-MM-DDTHH:MM:SSZ"))
        return 0;
    
	memset(&tm, 0, sizeof tm);
    
	/* YYYY- */
	if (!isdigit(s[0]) || !isdigit(s[1]) ||  !isdigit(s[2]) || !isdigit(s[3]) || s[4] != '-')
		return 0;
	tm.tm_year = (((s[0] - '0') * 10 + s[1] - '0') * 10 +  s[2] - '0') * 10 + s[3] - '0' - 1900;
	s += 5;
    
	/* mm- */
	if (!isdigit(s[0]) || !isdigit(s[1]) || s[2] != '-')
		return 0;
	tm.tm_mon = (s[0] - '0') * 10 + s[1] - '0';
	if (tm.tm_mon < 1 || tm.tm_mon > 12)
		return 0;
  	--tm.tm_mon;	/* 0-11 not 1-12 */
	s += 3;
    
	/* ddT */
	if (!isdigit(s[0]) || !isdigit(s[1]) || toupper(s[2]) != 'T')
		return 0;
	tm.tm_mday = (s[0] - '0') * 10 + s[1] - '0';
	s += 3;
    
	/* HH: */
	if (!isdigit(s[0]) || !isdigit(s[1]) || s[2] != ':')
		return 0;
	tm.tm_hour = (s[0] - '0') * 10 + s[1] - '0';
	s += 3;
    
	/* MM: */
	if (!isdigit(s[0]) || !isdigit(s[1]) || s[2] != ':')
		return 0;
	tm.tm_min = (s[0] - '0') * 10 + s[1] - '0';
	s += 3;
    
	/* SS */
	if (!isdigit(s[0]) || !isdigit(s[1]))
		return 0;
	tm.tm_sec = (s[0] - '0') * 10 + s[1] - '0';
	s += 2;
    
 	if (*s == '.') {
		do
			++s;
		while (isdigit(*s));
	}
    
   	if (toupper(s[0]) == 'Z' &&  ((s-p == stringLen -1) ||  s[1] == '\0'))
		tm.tm_gmtoff = 0;
	else if (s[0] == '+' || s[0] == '-')
    {
		char tzsign = *s++;
        
		/* HH: */
		if (!isdigit(s[0]) || !isdigit(s[1]) || s[2] != ':')
			return 0;
		tm.tm_gmtoff = ((s[0] - '0') * 10 + s[1] - '0') * 3600;
		s += 3;
        
		/* MM */
		if (!isdigit(s[0]) || !isdigit(s[1]) || s[2] != '\0')
			return 0;
		tm.tm_gmtoff += ((s[0] - '0') * 10 + s[1] - '0') * 60;
        
		if (tzsign == '-')
			tm.tm_gmtoff = -tm.tm_gmtoff;
	} else
		return 0;
    
    t = timegm(&tm);
	if (t < 0)
		return 0;
	return t;  
	
	//  	return t - tm.tm_gmtoff;

 }


static int sMakeHashList(const char * str, size_t len, char*** listOut)
{
    int retval = 0;
    
    const int bumpEntries = 1;
    const  int bumpBytes = sizeof(char*) * bumpEntries;
    
    char** table = NULL;
    int allocItems = bumpEntries;
    int tableItem = 0;
    
    table = XMALLOC(bumpBytes + sizeof(char*));     // allocate one extra for list end
    
    table[tableItem] = NULL;
    
    const char *ptr = str;
    char field [ 1024 ];
    int n;
 
    // skip  [
    while(sscanf(ptr, "%1[\[]%n", field, &n) == 1 )
        ptr += n; /* advance the pointer by the number of characters read */
    
    if(field[0] != '[')goto done;;
    
    while ( sscanf(ptr, "%*[,\" ]%1024[^\"]%n", field, &n) == 1 )
    {
        ptr += n; /* advance the pointer by the number of characters read */
        if ( *ptr != '\"' )
        {
            break; /* didn't find an expected delimiter, done? */
        }
        ++ptr; /* skip the delimiter */
        
        if(tableItem == allocItems)
        {
            char** newTable = NULL;
            
            newTable =  XMALLOC(sizeof(char*) * (allocItems  + bumpEntries + 1));
            COPY(table, newTable, (sizeof(char*) * allocItems ) );
            XFREE(table);
            table = newTable;
            allocItems+= bumpEntries;
        }
        
        if(strlen(field))
            table[tableItem++] = strdup(field);
    }
    
    table[tableItem] = NULL;
    
    
    *listOut = table;
    retval = tableItem;
    
done:
    return retval;
    
}


static SCLError PASSPHRASE_HASH( const uint8_t  *key,
                                unsigned long  key_len,
                                uint8_t       *salt,
                                unsigned long  salt_len,
                                unsigned int   rounds,
                                uint8_t        *mac_buf,
                                unsigned long  mac_len)
{
    SCLError    err     = kSCLError_NoErr;
    
    MAC_ContextRef  macRef     = kInvalidMAC_ContextRef;
    
    err = MAC_Init(kMAC_Algorithm_HMAC, kHASH_Algorithm_SHA256, key, key_len, &macRef); CKERR
    err = MAC_Update( macRef, salt, salt_len); CKERR;
    err = MAC_Update( macRef, key, key_len); CKERR;
    size_t mac_len_SZ = (size_t)mac_len;
    err = MAC_Final( macRef, mac_buf, &mac_len_SZ); CKERR;
    
done:
    
    MAC_Free(macRef);
    
    return err;
}

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
/* not used:
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
*/

#pragma mark - key import

enum SCKey_JSON_Type_
{
    SCKey_JSON_Type_Invalid ,
    SCKey_JSON_Type_BASE ,
    SCKey_JSON_Type_VERSION,
    SCKey_JSON_Type_KEYSUITE,
    SCKey_JSON_Type_SYMKEY,
    
    SCKey_JSON_Type_LOCATOR,

    SCKey_JSON_Type_PUBKEY,
    SCKey_JSON_Type_PRIVKEY,
    SCKey_JSON_Type_EXPIRE,
    SCKey_JSON_Type_START,
    
    SCKey_JSON_Type_ENCRYPTED_TO,
    SCKey_JSON_Type_SIGNED_BY,
    SCKey_JSON_Type_ENCRYPTED_SYMKEY,
    SCKey_JSON_Type_SIGNATURE,
    SCKey_JSON_Type_SIGNATURES,
    SCKey_JSON_Type_PROPERTY,
    SCKey_JSON_Type_OWNER,
    SCKey_JSON_Type_HASHLIST,
    SCKey_JSON_Type_ROUNDS,
    SCKey_JSON_Type_SALT,
    SCKey_JSON_Type_KDF,
    SCKey_JSON_Type_KEYHASH,
    SCKey_JSON_Type_HMACCODE,
    SCKey_JSON_Type_PUBKEY_LOCATOR,
    
    ENUM_FORCE( SCKey_JSON_Type_ )
};
ENUM_TYPEDEF( SCKey_JSON_Type_, SCKey_JSON_Type   );

struct SCKeyJSONcontext
{
    uint8_t             version;    // message version
    SCKey_Context       key;        // used for decoding messages
    int                 level;
    
    SCKey_JSON_Type jType[8];
    void*           jItem;
    size_t*         jItemSize;
    uint8_t*        jTag;
    
    SCSigItem       sigItem;        // used for parsing signatures
};

typedef struct SCKeyJSONcontext SCKeyJSONcontext;

static int sParse_start_map(void * ctx)
{
    SCKeyJSONcontext *jctx = (SCKeyJSONcontext*) ctx;
    int retval = 0;
    
    jctx->level++;
    
    if(IsntNull(jctx))
    {      
        if(jctx->level > 1)
        {
             if(jctx->jType[jctx->level-1] == SCKey_JSON_Type_SIGNATURES)
                 retval = 1;
        }
        else
            retval = 1;
        
    }
    
    return retval;
}

static int sParse_end_map(void * ctx)
{
    SCKeyJSONcontext *jctx = (SCKeyJSONcontext*) ctx;
    int retval = 0;
    
    if(IsntNull(jctx)  )
    {
        
        if(jctx->level > 1)
        {
            SCKey_Context* key = &jctx->key;
            
            if(jctx->jType[jctx->level-1] == SCKey_JSON_Type_SIGNATURES)
            {
                SCSigItem* item = &jctx->sigItem;
                SCSigItem* sigItem = XMALLOC(sizeof(SCSigItem));
                if(sigItem)
                {
                    COPY(item, sigItem, sizeof(SCSigItem));
                    
                    sigItem->next = key->sigList;
                    key->sigList = sigItem;
                    ZERO(item, sizeof(SCSigItem));
                    retval = 1;
                 }
            }
        }
        else
            retval = 1;

        jctx->level--;
        
    }
     return retval;
}


static int sParse_number(void * ctx, const char * str, size_t len)
{
    SCKeyJSONcontext *jctx = (SCKeyJSONcontext*) ctx;
    char buf[32] = {0};
    int valid = 0;
    
    if(len < sizeof(buf))
    {
        COPY(str,buf,len);
        if(jctx->jType[jctx->level] == SCKey_JSON_Type_VERSION)
        {
            uint8_t val = atoi(buf);
            if(val == kSCKeyProtocolVersion)
                valid = 1;
        }
        else if(jctx->jType[jctx->level] == SCKey_JSON_Type_KEYSUITE)
        {
            int val = atoi(buf);
            jctx->key.keySuite = val;
            valid = 1;
        }
        else if(jctx->jType[jctx->level] == SCKey_JSON_Type_ROUNDS)
        {
            int val = atoi(buf);
            jctx->key.pass.rounds = val;
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
    SCKeyJSONcontext *jctx = (SCKeyJSONcontext*) ctx;
    
    if(jctx->jType[jctx->level] == SCKey_JSON_Type_PROPERTY)
    {
        SCPropertyInfo  *propInfo = NULL;
        
        for(propInfo = sPropertyTable;  propInfo->name  && !valid; propInfo++)
        {
            if(CMP2(jctx->jTag, strlen((char *)(jctx->jTag)), propInfo->name, strlen(propInfo->name)))
            {
                switch (propInfo->type)
                {
                    case SCKeyPropertyType_UTF8String:
                        sInsertProperty(&jctx->key, propInfo->name, SCKeyPropertyType_UTF8String, (void*)stringVal, stringLen);
                        valid = 1;
                        break;
                        
                    case SCKeyPropertyType_Time:
                    {
                        time_t t = parseRfc3339(stringVal, stringLen);
                        sInsertProperty(&jctx->key, propInfo->name, SCKeyPropertyType_UTF8String,  &t, sizeof(time_t));
                        valid = 1;
                        break;
                    }
                        
                    case SCKeyPropertyType_Binary:
                    {
                        size_t dataLen = stringLen;
                        uint8_t     *buf = XMALLOC(dataLen);
                        
                        if(IsntSCLError(B64_decode(stringVal, (unsigned long)stringLen, buf, &dataLen)))
                        {
                            sInsertProperty(&jctx->key, propInfo->name, SCKeyPropertyType_Binary, (void*)buf, dataLen);
                            valid = 1;
                        }
                        XFREE(buf);
                        break;
                    }
                        
                    default:
                        break;
                }
            }
        }
        
        // else just copy it
        if(!valid)
        {
            sInsertProperty(&jctx->key, (char *)(jctx->jTag), SCKeyPropertyType_UTF8String, (void*)stringVal, stringLen);
            valid = 1;
        }
        
        if(jctx->jTag)
        {
            free(jctx->jTag);
            jctx->jTag = NULL;
        }
        
    }
    else if(jctx->jType[jctx->level] == SCKey_JSON_Type_SIGNATURES)
    {
        valid = 1;
    }
    
    else if(jctx->jType[jctx->level] == SCKey_JSON_Type_KEYSUITE)
    {
        jctx->key.keySuite = sParseKeySuiteString(stringVal,  stringLen);
        if(jctx->key.keySuite != kEnumMaxValue)
            valid = 1;
    }
    else if(jctx->jType[jctx->level] == SCKey_JSON_Type_SYMKEY)
    {
        int         expected = 0;
        uint8_t     buf[128];
        size_t dataLen = sizeof(buf);
        
        switch (jctx->key.keySuite)
        {
            case kSCKeySuite_AES128: expected = 16; break;
            case kSCKeySuite_AES256: expected = 32; break;
            case kSCKeySuite_2FISH256: expected = 32; break;
              default: return 0;   break;
        }
        
        if(IsntSCLError(B64_decode(stringVal,  stringLen, buf, &dataLen))
           && (dataLen == expected))
        {
            jctx->key.keyType = kSCKeyType_Symmetric;
            
            COPY(buf, jctx->key.sym.symKey, dataLen);
            valid = 1;
        }
    }
     else if(jctx->jType[jctx->level] == SCKey_JSON_Type_HMACCODE)
    {
        uint8_t     buf[128];
        size_t dataLen = sizeof(buf);
        
        if(IsntSCLError(B64_decode(stringVal,  stringLen, buf, &dataLen))
           && (dataLen == SCKEY_LOCATOR_BYTES))
        {
            jctx->key.keyType = kSCKeyType_HMACcode;
            
            COPY(buf, jctx->key.hmac.HMAC, dataLen);
            valid = 1;
        }
    }
     else if(jctx->jType[jctx->level] == SCKey_JSON_Type_SALT)
    {
         uint8_t     buf[128];
         size_t dataLen = sizeof(buf);
        
           if(IsntSCLError(B64_decode(stringVal, stringLen, buf, &dataLen))
           && (dataLen == SALT_BYTES))
        {
            jctx->key.keyType = kSCKeyType_PassPhrase;
            
            COPY(buf, jctx->key.pass.salt, dataLen);
            valid = 1;
        }
    }
    else if(jctx->jType[jctx->level] == SCKey_JSON_Type_KEYHASH)
    {
        uint8_t     buf[128];
        size_t dataLen = sizeof(buf);
        
        if(IsntSCLError(B64_decode(stringVal,  stringLen, buf, &dataLen))
           && (dataLen == PKDF_HASH_BYTES))
        {
            jctx->key.keyType = kSCKeyType_PassPhrase;
            
            COPY(buf, jctx->key.pass.keyHash, dataLen);
            valid = 1;
        }
    }
    
    else if(jctx->jType[jctx->level] == SCKey_JSON_Type_KDF)
    {
          
        if(CMP2(stringVal, stringLen, K_KEYKDF_PBKDF2, strlen(K_KEYKDF_PBKDF2)))
        {
            jctx->key.keyType = kSCKeyType_PassPhrase;
            jctx->key.pass.kdf = SCKeyDF_PBKDF2;
            valid = 1;
        }
    }
     else if(jctx->jType[jctx->level] == SCKey_JSON_Type_LOCATOR)
    {
        uint8_t     buf[SCKEY_LOCATOR_BYTES];
        size_t      dataLen = sizeof(buf);
        
        if(IsntSCLError(B64_decode(stringVal,  stringLen, buf, &dataLen))
           && (dataLen == SCKEY_LOCATOR_BYTES))
        {
            COPY(buf, jctx->key.locator, dataLen);
            valid = 1;
        }
    }
    
    else if(jctx->jType[jctx->level] == SCKey_JSON_Type_ENCRYPTED_SYMKEY)
    {
        
        if(jctx->key.keyType == kSCKeyType_PassPhrase)
        {
            
            uint8_t     buf[64];
            size_t      dataLen = sizeof(buf);
            
            ValidateParam(ctx);
                   
            if(IsntSCLError(B64_decode(stringVal,  stringLen, buf, &dataLen))
               && (dataLen == (unsigned long)sGetKeyLength(jctx->key.keySuite)))
            {
                COPY(buf, jctx->key.pass.lockedKey, dataLen);
                jctx->key.keyType = kSCKeyType_PassPhrase;
                
                valid = 1;
            }
         }
        else
        {
            size_t dataLen = stringLen;

            jctx->key.sym.eSymKey  = XMALLOC(stringLen);
            
            if(jctx->key.sym.eSymKey &&
               IsntSCLError(B64_decode(stringVal,  stringLen, jctx->key.sym.eSymKey, &dataLen)))
            {
                jctx->key.sym.eSymKeyLen = (size_t)dataLen;
                jctx->key.keyType = kSCKeyType_Symmetric;
                
                valid = 1;
            }
        }
    }
    else if(jctx->jType[jctx->level] == SCKey_JSON_Type_EXPIRE)
    {
        
        time_t *date = jctx->level > 1? & jctx->sigItem.sig.expireDate : &jctx->key.expireDate;
        time_t t = parseRfc3339(stringVal, stringLen);
        *date = t;
        
        valid = 1;
    }
    else if(jctx->jType[jctx->level] == SCKey_JSON_Type_START)
    {
        time_t *date = jctx->level > 1? & jctx->sigItem.sig.startDate : &jctx->key.startDate;
        time_t t = parseRfc3339(stringVal, stringLen);
        *date = t;
        
        valid = 1;
    }
    
    else if(jctx->jType[jctx->level] == SCKey_JSON_Type_PRIVKEY)
    {
        size_t dataLen = stringLen;
        jctx->key.pub.lockedPrivKey  = XMALLOC(stringLen);
        
        if(jctx->key.pub.lockedPrivKey &&
           IsntSCLError(B64_decode(stringVal,  stringLen, jctx->key.pub.lockedPrivKey, &dataLen)))
        {
            jctx->key.pub.privKeyLen = (size_t)dataLen;
            jctx->key.keyType = kSCKeyType_Private;
            valid = 1;
        }
        
    }
    else if(jctx->jType[jctx->level] == SCKey_JSON_Type_PUBKEY)
    {
        uint8_t     buf[128];
        size_t dataLen = sizeof(buf);
        
        if(IsntSCLError(B64_decode(stringVal,  stringLen, buf, &dataLen) )
           &&  dataLen <= sizeof(buf)  )
        {
            COPY(buf, jctx->key.pub.pubKey, dataLen);
            jctx->key.pub.pubKeyLen = (size_t)dataLen;
            
            if(jctx->key.keyType == kSCKeyType_Invalid)
                jctx->key.keyType = kSCKeyType_Public;
            valid = 1;
        }
        
    }
    else if(jctx->jType[jctx->level] == SCKey_JSON_Type_SIGNATURE)
    {
        size_t dataLen = stringLen;
        
        SCKeySignature* sig = jctx->level > 1? & jctx->sigItem.sig: &jctx->key.sig;
        
        sig->signature  = XMALLOC(stringLen);
        
        if(sig->signature &&
           IsntSCLError(B64_decode(stringVal,  stringLen, sig->signature, &dataLen) ))
        {
            sig->signatureLen = (size_t)dataLen;
            
            valid = 1;
        }
    }
    else if(jctx->jType[jctx->level] == SCKey_JSON_Type_OWNER)
    {
        jctx->key.owner = (uint8_t *)strndup((char *)stringVal, stringLen);
         valid = 1;
    }
    else if(jctx->jType[jctx->level] == SCKey_JSON_Type_SIGNED_BY)
    {
        uint8_t     buf[SCKEY_LOCATOR_BYTES];
        size_t dataLen = sizeof(buf);
        
        SCKeySignature* sig = jctx->level > 1? & jctx->sigItem.sig: &jctx->key.sig;
        
        
        if(IsntSCLError(B64_decode(stringVal,  stringLen, buf, &dataLen))
           && (dataLen == SCKEY_LOCATOR_BYTES))
        {
            COPY(buf, sig->sPubLocator, dataLen);
            valid = 1;
        }
    }
    else if(jctx->jType[jctx->level] == SCKey_JSON_Type_HASHLIST)
    {
         SCKeySignature* sig = jctx->level > 1? & jctx->sigItem.sig: &jctx->key.sig;
        
        if(sMakeHashList((char *)stringVal,  stringLen, &sig->hashList) > 0)
            valid = 1;
    }
   else if((jctx->key.keySuite == kSCKeySuite_AES128)
           || (jctx->key.keySuite == kSCKeySuite_AES256)
           || (jctx->key.keySuite == kSCKeySuite_2FISH256))
   {
        if(jctx->jType[jctx->level] == SCKey_JSON_Type_ENCRYPTED_TO)
        {
            uint8_t     buf[SCKEY_LOCATOR_BYTES];
            size_t dataLen = sizeof(buf);
            
            if(IsntSCLError(B64_decode(stringVal,  stringLen, buf, &dataLen) )
               && (dataLen == SCKEY_LOCATOR_BYTES))
            {
                COPY(buf, jctx->key.sym.ePubLocator, dataLen);
                valid = 1;
            }
        }
    }
    
    
    
    
    return valid;
}

static int sParse_map_key(void * ctx, const unsigned char * stringVal, size_t stringLen )
{
    SCKeyJSONcontext *jctx = (SCKeyJSONcontext*) ctx;
    int valid = 0;
    
    if(CMP2(stringVal, stringLen,kSCKeyProp_SCKeyVersion, strlen(kSCKeyProp_SCKeyVersion)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_VERSION;
        valid = 1;
    }
    else if(CMP2(stringVal, stringLen,kSCKeyProp_SCKeySuite , strlen(kSCKeyProp_SCKeySuite)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_KEYSUITE;
        valid = 1;
    }
    else if(CMP2(stringVal, stringLen,kSCKeyProp_SymmetricKey, strlen(kSCKeyProp_SymmetricKey)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_SYMKEY;
        valid = 1;
    }
    else if(CMP2(stringVal, stringLen,kSCKeyProp_Locator, strlen(kSCKeyProp_Locator)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_LOCATOR;
        valid = 1;
    }
    else  if(CMP2(stringVal, stringLen,kSCKeyProp_ExpireDate  , strlen(kSCKeyProp_ExpireDate)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_EXPIRE;
        valid = 1;
    }
    else  if(CMP2(stringVal, stringLen,kSCKeyProp_StartDate, strlen(kSCKeyProp_StartDate)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_START;
        valid = 1;
    }
    else  if(CMP2(stringVal, stringLen,kSCKeyProp_PubKey, strlen(kSCKeyProp_PubKey)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_PUBKEY;
        valid = 1;
    }
    else  if(CMP2(stringVal, stringLen,kSCKeyProp_HMACcode, strlen(kSCKeyProp_HMACcode)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_HMACCODE;
        valid = 1;
    }
      else  if(CMP2(stringVal, stringLen,kSCKeyProp_Salt, strlen(kSCKeyProp_Salt)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_SALT;
        valid = 1;
    }
    else  if(CMP2(stringVal, stringLen,kSCKeyProp_Rounds, strlen(kSCKeyProp_Rounds)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_ROUNDS;
        valid = 1;
    }
    else  if(CMP2(stringVal, stringLen,kSCKeyProp_KDF, strlen(kSCKeyProp_KDF)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_KDF;
        valid = 1;
    }
    else  if(CMP2(stringVal, stringLen,kSCKeyProp_KeyHash, strlen(kSCKeyProp_KeyHash)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_KEYHASH;
        valid = 1;
    }

    else  if(CMP2(stringVal, stringLen,kSCKeyProp_PrivKey, strlen(kSCKeyProp_PrivKey)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_PRIVKEY;
        valid = 1;
    }
    else if(CMP2(stringVal, stringLen,kSCKeyProp_SignedBy, strlen(kSCKeyProp_SignedBy)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_SIGNED_BY;
        if(jctx->level == 1 && (jctx->key.keyType == kSCKeyType_Invalid))
        {
            jctx->key.keyType = kSCKeyType_Signature;
        }
         valid = 1;
    }
    else if(CMP2(stringVal, stringLen,kSCKeyProp_HashList, strlen(kSCKeyProp_HashList)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_HASHLIST;
        valid = 1;
    }
    else if(CMP2(stringVal, stringLen,kSCKeyProp_EncryptedTo, strlen(kSCKeyProp_EncryptedTo)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_ENCRYPTED_TO;
        valid = 1;
    }
    else if(CMP2(stringVal, stringLen,kSCKeyProp_EncryptedKey, strlen(kSCKeyProp_EncryptedKey)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_ENCRYPTED_SYMKEY;
        valid = 1;
    }
    else if(CMP2(stringVal, stringLen,kSCKeyProp_Signature, strlen(kSCKeyProp_Signature)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_SIGNATURE;
        if(jctx->level == 1 && (jctx->key.keyType == kSCKeyType_Invalid))
        {
            jctx->key.keyType = kSCKeyType_Signature;
        }
        valid = 1;
    }
    else if(CMP2(stringVal, stringLen,kSCKeyProp_Signatures, strlen(kSCKeyProp_Signatures)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_SIGNATURES;
        valid = 1;
    }
    else if(CMP2(stringVal, stringLen,kSCKeyProp_Owner, strlen(kSCKeyProp_Owner)))
    {
        jctx->jType[jctx->level] = SCKey_JSON_Type_OWNER;
        valid = 1;
    }
    else
    {
        
        jctx->jType[jctx->level] = SCKey_JSON_Type_PROPERTY;
        if(jctx->jTag) free(jctx->jTag);
        jctx->jTag = (uint8_t *)strndup((char *)stringVal, stringLen);
        valid = 1;

    }

    return valid;
}



SCLError SCKeyDeserialize( uint8_t *inData, size_t inLen, SCKeyContextRef *ctx)
{
    SCLError                err = kSCLError_NoErr;
    yajl_status             stat = yajl_status_ok;
    yajl_handle             pHand = NULL;
    SCKeyJSONcontext       *jctx = NULL;
    SCKey_Context*          keyCTX = NULL;
    
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
   
    ValidateParam(ctx);
    ValidateParam(inData);
    *ctx = NULL;
    
    jctx = XMALLOC(sizeof (SCKeyJSONcontext)); CKNULL(jctx);
    ZERO(jctx, sizeof(SCKeyJSONcontext));
    jctx->jType[jctx->level] = SCKey_JSON_Type_BASE;
    
    jctx->key.magic = kSCKey_ContextMagic;
    jctx->key.keyType = kSCKeyType_Invalid;
    pHand = yajl_alloc(&callbacks, &allocFuncs, (void *) jctx);
    
    yajl_config(pHand, yajl_allow_comments, 1);
    stat = yajl_parse(pHand, inData,  inLen); CKSTAT;
    stat = yajl_complete_parse(pHand); CKSTAT;
      
    keyCTX = XMALLOC(sizeof (SCKey_Context)); CKNULL(keyCTX);
    COPY(&jctx->key, keyCTX, sizeof (SCKey_Context));
   
    if(keyCTX->keyType == kSCKeyType_HMACcode)
    {
        
    }
    else if( sSCKey_ContextIsECC(keyCTX))
    {
        err = ECC_Init(&keyCTX->pub.ecc); CKERR;
        err = ECC_Import_ANSI_X963(keyCTX->pub.ecc, keyCTX->pub.pubKey, keyCTX->pub.pubKeyLen);CKERR;
        
        if(keyCTX->sigList)
        {
            // find self sig
            SCKeySignature* sig =  sFindSignature(keyCTX, keyCTX->locator);
            if(sig)
            {
                bool verify = sVerifyKeySig(keyCTX, sig);
                if(!verify)
                    RETERR(kSCLError_BadIntegrity);
                        
            }
            
        }
     }
    
    *ctx = keyCTX;
    

done:
    if(IsSCLError(err) && keyCTX)
    {
        SCKeyFree(keyCTX);
    }
    
    if(IsntNull(jctx))
    {
        ZERO(jctx, sizeof(SCKeyJSONcontext));
        XFREE(jctx);
    }
    
    if(IsntNull(pHand))
        yajl_free(pHand);
    
    return err;
 }


SCLError SCKeyIsLocked( SCKeyContextRef ctx, bool *isLocked)
{
    SCLError        err = kSCLError_NoErr;
    validateSCKeyContext(ctx);
    ValidateParam(isLocked);

    bool bLocked =  ((ctx->keyType == kSCKeyType_Private) && ctx->pub.lockedPrivKey )
                || ((ctx->keyType == kSCKeyType_Symmetric) && ctx->sym.eSymKey );
    
    if(isLocked) *isLocked = bLocked;
       
    return err;

}

SCLError scSCKeyUnlockInternal( SCKeyContextRef ctx, Cipher_Algorithm  encryptKeyAlgor,  uint8_t *encryptKey, size_t encryptKeyLen)
{
    SCLError        err = kSCLError_NoErr;
    
    size_t keyLen = encryptKeyLen>>1;
    
    uint8_t* privData = NULL;
    size_t privDataLen = 0;
    
    validateSCKeyContext(ctx);
    ValidateParam(encryptKey);
    
     bool bLocked = ( sSCKey_ContextIsECC(ctx)  && ctx->pub.lockedPrivKey );
    
    if(bLocked)
    {
        err = MSG_Decrypt(encryptKeyAlgor, encryptKey,  keyLen, encryptKey + keyLen,
                          ctx->pub.lockedPrivKey, ctx->pub.privKeyLen,
                          &privData, &privDataLen); CKERR;
        
        if(ctx->pub.ecc)
        {
            ECC_Free(ctx->pub.ecc);
            ctx->pub.ecc = kInvalidECC_ContextRef;
        }
        err = ECC_Init(&ctx->pub.ecc); CKERR;
        err = ECC_Import(ctx->pub.ecc, privData, privDataLen);CKERR;
        
        ctx->pub.privKey = privData;
        ctx->pub.privKeyLen = privDataLen;
        XFREE(ctx->pub.lockedPrivKey);
        ctx->pub.lockedPrivKey = NULL;
        privData = NULL;
        
    }
    
    
done:
    
    if(privData)
    {
        ZERO(privData, privDataLen);
        XFREE(privData);
    }
    return err;
    
}

SCLError SCKeyUnlock( SCKeyContextRef ctx, uint8_t *encryptKey, size_t encryptKeyLen)
{
    SCLError        err = kSCLError_NoErr;
    Cipher_Algorithm    storageKeyalgorithm = kCipher_Algorithm_Invalid;
    
    validateSCKeyContext(ctx);
    ValidateParam(encryptKey);
    
    switch(encryptKeyLen>>1)
    {
        case 16: storageKeyalgorithm = kCipher_Algorithm_AES128; break;
        case 32: storageKeyalgorithm = kCipher_Algorithm_AES256; break;
        default:
            RETERR(kSCLError_BadParams) ;
    }

    
    err = scSCKeyUnlockInternal(ctx,storageKeyalgorithm,encryptKey,encryptKeyLen); CKERR;
    
    
done:
     return err;
  
}


SCLError SCKeyUnlockWithSCKey( SCKeyContextRef ctx, SCKeyContextRef   storageKeyCtx)
{
    SCLError            err = kSCLError_NoErr;
  
    Cipher_Algorithm    storageKeyalgorithm = kCipher_Algorithm_Invalid;

    uint8_t symKey[64];
    size_t  symKeyLen = 0;
    size_t  ivLen = 0;
    
    err = SCKeyCipherForKeySuite(storageKeyCtx->keySuite, &storageKeyalgorithm, NULL); CKERR;
    err = SCKeyGetProperty(storageKeyCtx, kSCKeyProp_SymmetricKey, NULL, symKey , sizeof(symKey), &symKeyLen); CKERR;
    err = SCKeyGetProperty(storageKeyCtx, kSCKeyProp_IV, NULL,  symKey+symKeyLen , symKeyLen, &ivLen); CKERR;
    err = scSCKeyUnlockInternal(ctx, storageKeyalgorithm, symKey, symKeyLen + ivLen); CKERR;
    
    
done:
    ZERO(symKey, sizeof(symKey));
    
      return err;

}

#pragma mark - key export

static yajl_gen_status sGenPropStrings(SCKeyContextRef ctx, yajl_gen g)

{
    SCLError            err = kSCLError_NoErr;
    yajl_gen_status     stat = yajl_gen_status_ok;
    
    SCProperty *prop = ctx->propList;
    while(prop)
    {
        stat = yajl_gen_string(g, prop->prop, strlen((char *)(prop->prop))) ; CKSTAT;
        switch(prop->type)
        {
            case SCKeyPropertyType_UTF8String:
                stat = yajl_gen_string(g, prop->value, prop->valueLen) ; CKSTAT;
                
                break;
                
            case SCKeyPropertyType_Binary:
            {
                size_t propLen =  prop->valueLen*4;
                uint8_t     *propBuf =  XMALLOC(propLen);
                
                B64_encode(prop->value, prop->valueLen, propBuf, &propLen);
                stat = yajl_gen_string(g, propBuf, (size_t)propLen) ; CKSTAT;
                XFREE(propBuf);
            }
                break;
                
            case SCKeyPropertyType_Time:
            {
                uint8_t     tempBuf[32];
                size_t      tempLen;
                time_t      gTime;
                struct      tm *nowtm;
                
                COPY(prop->value, &gTime, sizeof(gTime));
                nowtm = gmtime(&gTime);
                tempLen = strftime((char *)tempBuf, sizeof(tempBuf), kRfc339Format, nowtm);
                stat = yajl_gen_string(g, tempBuf, tempLen) ; CKSTAT;
            }
                break;
                
            default:
                yajl_gen_string(g, (uint8_t *)"NULL", 4) ;
                break;
        }
        
        prop = prop->next;
    }
    
done:
    return err;
}

static yajl_gen_status sGenSignatureStrings(SCKeyContextRef ctx, yajl_gen g)

{
    SCLError            err = kSCLError_NoErr;
    yajl_gen_status     stat = yajl_gen_status_ok;
    uint8_t             tempBuf[1024];
    size_t              tempLen;

    SCSigItem *sigItem = ctx->sigList;
    if(sigItem)
    {
        stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_Signatures, strlen(kSCKeyProp_Signatures)) ; CKSTAT;
        stat = yajl_gen_array_open(g);
        
        while(sigItem)
        {
            stat = yajl_gen_map_open(g); CKSTAT;
            
            stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_Signature, strlen(kSCKeyProp_Signature)) ; CKSTAT;
            tempLen = sizeof(tempBuf);
            B64_encode(sigItem->sig.signature, sigItem->sig.signatureLen, tempBuf, &tempLen);
            stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;
            
            stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_SignedBy, strlen(kSCKeyProp_SignedBy)) ; CKSTAT;
            tempLen = sizeof(tempBuf);
            B64_encode(sigItem->sig.sPubLocator, SCKEY_LOCATOR_BYTES, tempBuf, &tempLen);
            stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;
            
            stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_StartDate, strlen(kSCKeyProp_StartDate)) ; CKSTAT;
            struct tm *nowtm;
            nowtm = gmtime(&sigItem->sig.startDate);
            tempLen = strftime((char *)tempBuf, sizeof(tempBuf), kRfc339Format, nowtm);
            stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;

            {
                char**   itemName = sigItem->sig.hashList;
                char*    hashString = strdup("[");
                
                stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_HashList, strlen(kSCKeyProp_HashList)) ; CKSTAT;
           
                if(!itemName) itemName = (char**)kSCKeyDefaultSignedPropertyList;
                
                for( ;*itemName; itemName++)
                {
                   
                    if(STRCMP2(*itemName, kSCKeyProp_SymmetricKey) && (ctx->keyType != kSCKeyType_Symmetric))
                        continue;
                    
                    if(STRCMP2(*itemName, kSCKeyProp_PubKey)
                            && ((ctx->keyType != kSCKeyType_Public) && (ctx->keyType != kSCKeyType_Private)))
                        continue;
                       
                    char* s1 = XMALLOC( strlen(hashString) + strlen(*itemName)+6);
                    
                    sprintf(s1, "%s\"%s\"%c", hashString, *itemName, *(itemName+1)?',':']');
                    XFREE(hashString);
                    hashString = s1;
                    
                }
                stat = yajl_gen_string(g, (uint8_t *)hashString, strlen(hashString)) ; CKSTAT;
                XFREE(hashString);
            }
                
            stat = yajl_gen_map_close(g); CKSTAT;
            
            sigItem = sigItem->next;
         }
        stat = yajl_gen_array_close(g);
     }
    
done:
    return err;
}


static SCLError scSCKeySerializeInternal( SCKeyContextRef ctx,
                                         bool doPrivate,
                                         Cipher_Algorithm encryptAlgor,
                                         uint8_t *encryptKey, size_t encryptKeyLen,
                                         uint8_t **outData, size_t *outSize)
{
    SCLError            err = kSCLError_NoErr;
    yajl_gen_status     stat = yajl_gen_status_ok;
    
    uint8_t             *yajlBuf = NULL;
    size_t              yajlLen = 0;
    
    uint8_t             *outBuf = NULL;
    yajl_gen            g = NULL;
    
    uint8_t             tempBuf[1024];
    size_t              tempLen;
    uint8_t             *dataBuf = NULL;
    size_t              keyBytes = 0;
    
    uint8_t     zero_locator[SCKEY_LOCATOR_BYTES];
    ZERO(zero_locator, SCKEY_LOCATOR_BYTES);

    yajl_alloc_funcs allocFuncs = {
        yajlMalloc,
        yajlRealloc,
        yajlFree,
        (void *) NULL
    };

    validateSCKeyContext(ctx);
    ValidateParam(outData);
    ValidateParam(outSize);
    
    g = yajl_gen_alloc(&allocFuncs); CKNULL(g);
    
#if DEBUG
    yajl_gen_config(g, yajl_gen_beautify, 1);
#else
    yajl_gen_config(g, yajl_gen_beautify, 0);

#endif
    yajl_gen_config(g, yajl_gen_validate_utf8, 1);
    stat = yajl_gen_map_open(g); CKSTAT;
     
    stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_SCKeyVersion, strlen(kSCKeyProp_SCKeyVersion)) ; CKSTAT;
    sprintf((char *)tempBuf, "%d", kSCKeyProtocolVersion);
    stat = yajl_gen_number(g, (char *)tempBuf, strlen((char *)tempBuf)) ; CKSTAT;
    
    stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_SCKeySuite, strlen(kSCKeyProp_SCKeySuite)) ; CKSTAT;
    
#if 1
    sprintf((char *)tempBuf, "%s", sKeySuiteString(ctx->keySuite));
    stat = yajl_gen_string(g, tempBuf, strlen((char *)tempBuf)) ; CKSTAT;

#else
    sprintf(tempBuf, "%d", ctx->keySuite);
    stat = yajl_gen_number(g, tempBuf, strlen(tempBuf)) ; CKSTAT;
    
#endif
    if(ctx->keyType == kSCKeyType_HMACcode)
    {
        
        tempLen = sizeof(tempBuf);
        err = B64_encode(ctx->hmac.HMAC, SCKEY_LOCATOR_BYTES, tempBuf, &tempLen); CKERR;
        stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_HMACcode, strlen(kSCKeyProp_HMACcode)) ; CKSTAT;
        stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;
        
    }
     else if(sSCKey_ContextIsECC(ctx))
    {
 
        stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_PubKey, strlen(kSCKeyProp_PubKey)) ; CKSTAT;
        tempLen = sizeof(tempBuf);
        B64_encode(ctx->pub.pubKey, ctx->pub.pubKeyLen, tempBuf, &tempLen);
        stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;
         
        if(ctx->pub.privKeyLen && doPrivate)
        {
            stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_PrivKey, strlen(kSCKeyProp_PrivKey)) ; CKSTAT;
            
            size_t keyLen = encryptKeyLen>>1;
            uint8_t* keyData = NULL;
            size_t keyDataLen = 0;
            
            err = MSG_Encrypt(encryptAlgor, encryptKey, keyLen, encryptKey + keyLen, ctx->pub.privKey, ctx->pub.privKeyLen, &keyData, &keyDataLen); CKERR;
            tempLen = sizeof(tempBuf);
            B64_encode(keyData, keyDataLen, tempBuf, &tempLen);
            stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;
            XFREE(keyData);
        }

      }
    
    else if(ctx->keyType == kSCKeyType_PassPhrase)
    {
     
         if(ctx->pass.kdf == SCKeyDF_PBKDF2)
        {
            stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_KDF, strlen(kSCKeyProp_KDF)) ; CKSTAT;
            sprintf((char *)tempBuf,"%s", K_KEYKDF_PBKDF2);
            stat = yajl_gen_string(g, tempBuf, strlen((char *)tempBuf)) ; CKSTAT;
        }
          
        stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_Salt, strlen(kSCKeyProp_Salt)) ; CKSTAT;
        tempLen = sizeof(tempBuf);
        B64_encode(ctx->pass.salt, SALT_BYTES, tempBuf, &tempLen);
        stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;

        stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_Rounds, strlen(kSCKeyProp_Rounds)) ; CKSTAT;
        sprintf((char *)tempBuf, "%d", ctx->pass.rounds);
        stat = yajl_gen_number(g, (char *)tempBuf, strlen((char *)tempBuf)) ; CKSTAT;
        
        stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_KeyHash, strlen(kSCKeyProp_KeyHash)) ; CKSTAT;
        tempLen = sizeof(tempBuf);
        B64_encode(ctx->pass.keyHash, PKDF_HASH_BYTES, tempBuf, &tempLen);
        stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;
       
        stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_EncryptedKey, strlen(kSCKeyProp_EncryptedKey)) ; CKSTAT;
        switch(ctx->keySuite)
        {
            case kSCKeySuite_AES128: keyBytes = 16; break;
            case kSCKeySuite_AES256: keyBytes = 32; break;
            case kSCKeySuite_2FISH256: keyBytes = 32; break;
            default: RETERR(kSCLError_BadParams);
        }
        
        tempLen = sizeof(tempBuf);
        B64_encode(ctx->pass.lockedKey, keyBytes, tempBuf, &tempLen);
        stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;

    }
    else
    {
        stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_SymmetricKey, strlen(kSCKeyProp_SymmetricKey)) ; CKSTAT;
        switch(ctx->keySuite)
        {
            case kSCKeySuite_AES128: keyBytes = 16; break;
            case kSCKeySuite_AES256: keyBytes = 32; break;
            case kSCKeySuite_2FISH256: keyBytes = 32; break;
            default: RETERR(kSCLError_BadParams);
        }
        
        tempLen = sizeof(tempBuf);
        B64_encode(ctx->sym.symKey, keyBytes, tempBuf, &tempLen);
        stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;
    }
    
    if(ctx->owner )
    {
        stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_Owner, strlen(kSCKeyProp_Owner)) ; CKSTAT;
        stat = yajl_gen_string(g, ctx->owner, strlen((char *)(ctx->owner))) ; CKSTAT;
   }

    if(memcmp(ctx->locator,zero_locator,SCKEY_LOCATOR_BYTES) )
    {
        stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_Locator, strlen(kSCKeyProp_Locator)) ; CKSTAT;
       
        tempLen = sizeof(tempBuf);
        B64_encode(ctx->locator, SCKEY_LOCATOR_BYTES, tempBuf, &tempLen);
        stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;
    }
    if(ctx->startDate != 0)
    {
        stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_StartDate, strlen(kSCKeyProp_StartDate)) ; CKSTAT;
        struct tm *nowtm;
        nowtm = gmtime(&ctx->startDate);
        tempLen = strftime((char *)tempBuf, sizeof(tempBuf), kRfc339Format, nowtm);
        stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;
    }
    
    if(ctx->expireDate != 0)
    {
        stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_ExpireDate, strlen(kSCKeyProp_ExpireDate)) ; CKSTAT;
        struct tm *nowtm;
        nowtm = gmtime(&ctx->expireDate);
        tempLen = strftime((char *)tempBuf, sizeof(tempBuf), kRfc339Format, nowtm);
        stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;
    }
    
    err = sGenSignatureStrings(ctx, g); CKERR;
    
    err = sGenPropStrings(ctx, g); CKERR;
    
    stat = yajl_gen_map_close(g); CKSTAT;
    
    stat =  yajl_gen_get_buf(g, (const unsigned char**) &yajlBuf, &yajlLen);CKSTAT;
    
    outBuf = XMALLOC(yajlLen+1); CKNULL(outBuf);
    memcpy(outBuf, yajlBuf, yajlLen);
    outBuf[yajlLen] = 0;
    
    *outData = outBuf;
    *outSize = yajlLen;
    
    
done:
    
    if(IsntNull(g))
        yajl_gen_free(g);
    
    if(dataBuf)
        XFREE(dataBuf);
    
    return err;
 };



SCLError SCKeySerializePrivateWithSCKey( SCKeyContextRef    ctx,
                                        SCKeyContextRef     storageKeyCtx,
                                        uint8_t **outData, size_t *outSize)
{
    SCLError            err = kSCLError_NoErr;
    validateSCKeyContext(ctx);
    validateSCKeyContext(storageKeyCtx);
    ValidateParam(outData);
    ValidateParam(outSize);
    
    Cipher_Algorithm  storageKeyalgorithm = kCipher_Algorithm_Invalid;
  
    uint8_t symKey[128];
    size_t  symKeyLen = 0;
    size_t  expectedKeyLen = 0;
    size_t  ivLen = 0;
    bool     bIsLocked = true;
    
    err = SCKeyIsLocked(storageKeyCtx, &bIsLocked);CKERR;
    if(bIsLocked) RETERR(kSCLError_KeyLocked);
     
    err = SCKeyCipherForKeySuite(storageKeyCtx->keySuite, &storageKeyalgorithm, &expectedKeyLen); CKERR;
    
   err = SCKeyGetProperty(storageKeyCtx, kSCKeyProp_SymmetricKey, NULL,  symKey , sizeof(symKey), &symKeyLen); CKERR;
    ASSERTERR(expectedKeyLen != symKeyLen, kSCLError_BadParams);
    
    err = SCKeyGetProperty(storageKeyCtx, kSCKeyProp_IV, NULL,  symKey+symKeyLen , symKeyLen, &ivLen); CKERR;
    ASSERTERR(ivLen != symKeyLen, kSCLError_BadParams);
    
    
    err = scSCKeySerializeInternal(ctx,true,
                                   storageKeyalgorithm, symKey, symKeyLen + ivLen,
                                   outData,outSize);CKERR;
    
done:
    
    ZERO(symKey, sizeof(symKey));
    
    return err;
};


//* I would like to depricate this api soon enough, since I cant specify the storage key cipher */

SCLError SCKeySerializePrivate( SCKeyContextRef ctx,
                               uint8_t *encryptKey, size_t encryptKeyLen,
                               uint8_t **outData, size_t *outSize)
{
    SCLError            err = kSCLError_NoErr;
    Cipher_Algorithm    storageKeyalgorithm = kCipher_Algorithm_Invalid;
    validateSCKeyContext(ctx);
    ValidateParam(outData);
    ValidateParam(outSize);
    
    switch(encryptKeyLen)
    {
            case 32: storageKeyalgorithm = kCipher_Algorithm_AES128; break;
            case 64: storageKeyalgorithm = kCipher_Algorithm_AES256; break;
            default:
            RETERR(kSCLError_BadParams) ;
       }
    
    err = scSCKeySerializeInternal(ctx,true, storageKeyalgorithm, encryptKey, encryptKeyLen, outData,outSize);CKERR;
    
done:
    return err;
};


SCLError SCKeySerialize( SCKeyContextRef ctx, uint8_t **outData, size_t *outSize)
{
    SCLError            err = kSCLError_NoErr;
    validateSCKeyContext(ctx);
    ValidateParam(outData);
    ValidateParam(outSize);
    
    err = scSCKeySerializeInternal(ctx,false,kCipher_Algorithm_Invalid,  NULL, 0, outData,outSize);CKERR;
    
done:
    return err;
    
}

#pragma mark - init / free
static SCLError sCalculateECCData(SCKeyContextRef  ctx, const uint8_t *nonce, unsigned long nonceLen )
{
    SCLError        err = kSCLError_NoErr;
    size_t          len = 0;
    size_t          pubKeyLen = 0;
    
    if(ECC_isPrivate(ctx->pub.ecc))
    {
        ctx->pub.privKey = XMALLOC(MAX_PRIVKEY_LEN);
        err =  ECC_Export( ctx->pub.ecc, true, ctx->pub.privKey, MAX_PRIVKEY_LEN, &len);CKERR;
        ctx->pub.privKeyLen  = (uint8_t)(len & 0xff);
    }
    
    err =  ECC_Export_ANSI_X963( ctx->pub.ecc, ctx->pub.pubKey, sizeof(ctx->pub.pubKey), &pubKeyLen);CKERR;
    ctx->pub.pubKeyLen = pubKeyLen;
    
    err = MAC_ComputeKDF(kMAC_Algorithm_HMAC,  kHASH_Algorithm_SHA256,
                         ctx->pub.pubKey,  ctx->pub.pubKeyLen,
                         "SCKey_ECC_Key",
                         nonce, nonceLen,
                         SCKEY_LOCATOR_BYTES >> 3,  SCKEY_LOCATOR_BYTES, ctx->locator); CKERR;
    
done:
    return err;
    
}


static SCLError sNewPubKeyInternal (SCKeySuite   keySuite,
                                const uint8_t        *nonce, size_t nonceLen,
                                SCKeyContextRef      *ctx)
{
    SCLError        err = kSCLError_NoErr;
    SCKey_Context*   keyCTX = NULL;
   
    ValidateParam(ctx);
    *ctx = NULL;
    
    keyCTX = XMALLOC(sizeof (SCKey_Context)); CKNULL(keyCTX);
    ZERO(keyCTX, sizeof(SCKey_Context));
    
    keyCTX->keySuite = keySuite;
    keyCTX->magic = kSCKey_ContextMagic;
    
    keyCTX->keyType = kSCKeyType_Private;
    
    err = ECC_Init(&keyCTX->pub.ecc);

    switch(keySuite)
    {
        case kSCKeySuite_ECC384:
            err = ECC_Generate(keyCTX->pub.ecc, 384); CKERR;
            break;
            
        case kSCKeySuite_ECC414:
            err = ECC_Generate(keyCTX->pub.ecc, 414); CKERR
            break;
            
        default:
            RETERR(kSCLError_BadCipherNumber);
    }
    err = sCalculateECCData(keyCTX,nonce,nonceLen); CKERR;
    
    // self sign key
     err = SCKeySignKey(keyCTX, keyCTX, (char**) kSCKeyDefaultSignedPropertyList); CKERR;
    
    *ctx = keyCTX;
    
done:
    if(IsSCLError(err))
    {
        if(IsntNull(keyCTX))
        {
            XFREE(keyCTX);
        }
    }
   return err;
 }



static SCLError sNewSymmetricInternal (SCKeySuite   keySuite,
                                bool                makeKey,
                               const void           *importKey,
                               const uint8_t        *nonce, size_t nonceLen,
                               SCKeyContextRef      *ctx)
{
    SCLError          err = kSCLError_NoErr;
    SCKey_Context*   keyCTX = NULL;
    
    size_t          keylen = 0;
    ValidateParam(ctx);
    *ctx = NULL;
    
    keylen =  sGetKeyLength(keySuite);
    if(!keylen) RETERR(kSCLError_BadCipherNumber);
     
    
    keyCTX = XMALLOC(sizeof (SCKey_Context)); CKNULL(keyCTX);
    ZERO(keyCTX, sizeof(SCKey_Context));
    
    keyCTX->magic       = kSCKey_ContextMagic;
    keyCTX->keySuite    = keySuite;
    keyCTX->keyType     = kSCKeyType_Symmetric;
     
    if(makeKey)
    {
        err =  RNG_GetBytes(keyCTX->sym.symKey,keylen); CKERR;
    }
    else
    {
        COPY(importKey, keyCTX->sym.symKey, keylen);
     }
    
    err = MAC_ComputeKDF(kMAC_Algorithm_HMAC,  kHASH_Algorithm_SHA256,
                         keyCTX->sym.symKey,  keylen,
                         "SCKey_Symmetric_Key",
                         nonce, nonceLen,
                         SCKEY_LOCATOR_BYTES >> 3,  SCKEY_LOCATOR_BYTES, keyCTX->locator); CKERR;
    
    *ctx = keyCTX;
    
done:
    if(IsSCLError(err))
    {
        if(IsntNull(keyCTX))
        {
            XFREE(keyCTX);
        }
    }
    
    return err;
 
}


SCLError SCKeyExport_ECC(SCKeyContextRef  keyCTX,  ECC_ContextRef *ecc )
{
    SCLError        err         = kSCLError_NoErr;
    uint8_t         *keyData    = NULL;
    size_t          keyDataLen  = 0;
     
    
    ValidateParam(keyCTX);
    ValidateParam(ecc);
     
    err = ECC_Init(ecc); CKERR;

    keyData = XMALLOC(MAX_PRIVKEY_LEN);
    if(ECC_isPrivate(keyCTX->pub.ecc))
    {
        err = ECC_Export( keyCTX->pub.ecc, true, keyData, MAX_PRIVKEY_LEN, &keyDataLen);CKERR;
        err = ECC_Import(*ecc, keyData, keyDataLen);CKERR;
    }
    else
    {
        err = ECC_Export_ANSI_X963( keyCTX->pub.ecc, keyData, MAX_PRIVKEY_LEN, &keyDataLen);CKERR;
        err = ECC_Import_ANSI_X963( *ecc, keyData, keyDataLen);CKERR;
    }
    
done:
    
    if(keyData)
    {
        ZERO(keyData, keyDataLen);
        XFREE(keyData);
     }
    
    if(IsSCLError(err))
    {
        if(IsntNull(*ecc))
        {
            XFREE(*ecc);
        }
    }
    
    return err;

}




SCLError SCKeyExport_ANSI_X963(SCKeyContextRef  keyCTX, void *outData, size_t bufSize, size_t *datSize)
{
    SCLError        err         = kSCLError_NoErr;
     
    
    ValidateParam(keyCTX);

    err = ECC_Export_ANSI_X963( keyCTX->pub.ecc, outData, bufSize,datSize); 
      
    return err;
}


SCLError SCKeyImport_ECC( ECC_ContextRef  ecc,
                         uint8_t            *nonce, unsigned long nonceLen,
                         SCKeyContextRef *ctx)
{
    SCLError          err = kSCLError_NoErr;
    SCKey_Context*   keyCTX = NULL;
    
    size_t          len = 0;
    size_t          pubKeyLen = 0;
    
    size_t          keyBits = 0;
    
    ValidateParam(ctx);
    *ctx = NULL;
    
    err = ECC_KeySize(ecc , &keyBits); CKERR;
    
    keyCTX = XMALLOC(sizeof (SCKey_Context)); CKNULL(keyCTX);
    ZERO(keyCTX, sizeof(SCKey_Context));
    
    keyCTX->magic = kSCKey_ContextMagic;
    keyCTX->keySuite =   keyBits > 384 ? kSCKeySuite_ECC414: kSCKeySuite_ECC384;
    keyCTX->keyType = kSCKeyType_Public;
    
    err = ECC_Init(&keyCTX->pub.ecc); CKERR;

    if(ECC_isPrivate(ecc))
    {
        keyCTX->pub.privKey = XMALLOC(MAX_PRIVKEY_LEN);
        err =  ECC_Export( ecc, true, keyCTX->pub.privKey, MAX_PRIVKEY_LEN, &len);CKERR;
        keyCTX->pub.privKeyLen  = (uint8_t)(len & 0xff);
        keyCTX->keyType = kSCKeyType_Private;
    }
    
    
    
    err =  ECC_Export_ANSI_X963( ecc, keyCTX->pub.pubKey, sizeof(keyCTX->pub.pubKey), &pubKeyLen);CKERR;
    keyCTX->pub.pubKeyLen = pubKeyLen;
    
    /* it's not very easy to copy the ECC context so we just reimport it */
    if(ECC_isPrivate(ecc))
    {
        err = ECC_Import(keyCTX->pub.ecc, keyCTX->pub.privKey, keyCTX->pub.privKeyLen);CKERR;
    }
    else
    {
        err = ECC_Import_ANSI_X963(keyCTX->pub.ecc, keyCTX->pub.pubKey, sizeof(keyCTX->pub.pubKey));CKERR;
    }
    
    err = MAC_ComputeKDF(kMAC_Algorithm_HMAC,  kHASH_Algorithm_SHA256,
                         keyCTX->pub.pubKey,  pubKeyLen,
                         "SCKey_ECC_Key",
                         nonce, nonceLen,
                         SCKEY_LOCATOR_BYTES >> 3,  SCKEY_LOCATOR_BYTES, keyCTX->locator); CKERR;
    
    *ctx = keyCTX;
    
done:
    
    
    if(IsSCLError(err))
    {
        if(IsntNull(keyCTX))
        {
            SCKeyFree(keyCTX);
        }
    }
    
    return err;
}

SCLError SCKeyImport_Symmetric(SCKeySuite       keySuite,
                             const void         *key,
                             const uint8_t      *nonce, size_t nonceLen,
                             SCKeyContextRef   *ctx)
{
    SCLError        err = kSCLError_NoErr;
    
    ValidateParam(ctx);
    
    err = sNewSymmetricInternal(keySuite, false, key, nonce,nonceLen, ctx); CKERR;
    
done:
    
    return err;
}

SCLError SCKeyNew(SCKeySuite     keySuite,
                  const uint8_t   *nonce, size_t nonceLen,
                SCKeyContextRef   *ctx)
{
    SCLError        err = kSCLError_NoErr;

    ValidateParam(ctx);
 
     switch (keySuite) {
        case kSCKeySuite_ECC384:
        case kSCKeySuite_ECC414:
             err = sNewPubKeyInternal(keySuite, nonce,nonceLen, ctx); CKERR;
             break;

         case kSCKeySuite_AES128:
         case kSCKeySuite_AES256:
         case kSCKeySuite_2FISH256:
            err = sNewSymmetricInternal(keySuite, true, NULL, nonce,nonceLen, ctx); CKERR;
            break;

        default:
             err = kSCLError_BadParams;
            break;
    }
done:
   
    return err;
}



void SCKeyFree(SCKeyContextRef  ctx)
{
    if(sSCKey_ContextIsValid(ctx))
    {
        SCProperty *prop = ctx->propList;
        
        while(prop)
        {
            SCProperty *nextProp = prop->next;
            XFREE(prop->prop);
            XFREE(prop->value);
            XFREE(prop);
            prop = nextProp;
        }
  
        
        SCSigItem   *sig = ctx->sigList;
        
        while(sig)
        {
            SCSigItem *nextSig = sig->next;
            
            if(sig->sig.hashList)
            {
                if(sig->sig.hashList != (char**)kSCKeyDefaultSignedPropertyList)
                {
                    char**   itemName = sig->sig.hashList;
                    
                    for(;*itemName; itemName++)  XFREE(*itemName);
                    XFREE(sig->sig.hashList);

                }
            }
            if (sig->sig.signature)
            	XFREE(sig->sig.signature);
            XFREE(sig);
            sig = nextSig;
        }

        switch(ctx->keySuite)
        {
            case kSCKeySuite_ECC384:
            case kSCKeySuite_ECC414:
                if(ECC_ContextRefIsValid(ctx->pub.ecc))
                     ECC_Free(ctx->pub.ecc);
                
                    if(ctx->pub.privKey && ctx->pub.privKeyLen)
                    {
                        ZERO(ctx->pub.privKey ,ctx->pub.privKeyLen);
                        XFREE(ctx->pub.privKey);
                        ctx->pub.privKey = 0;
                    }
                
                    if(ctx->pub.lockedPrivKey)
                    {
                        XFREE(ctx->pub.lockedPrivKey);
                    }

                  break;
            default:
                break;
         }

        if (ctx->owner)
        	XFREE(ctx->owner);
        
        ZERO(ctx, sizeof(SCKey_Context));
        XFREE(ctx);
    }
}

SCLError SCKeyCipherForKeySuite(SCKeySuite keySuite, Cipher_Algorithm *algorithm, size_t *keyLen)
{
    SCLError        err = kSCLError_NoErr;
     Cipher_Algorithm  alg = kCipher_Algorithm_Invalid;
    size_t len = 0;
    
    switch(keySuite)
    {
        case kSCKeySuite_AES128:
            alg = kCipher_Algorithm_AES128;
            len = 16;
            break;
            
        case kSCKeySuite_AES256:
            alg = kCipher_Algorithm_AES256;
            len = 32;
            break;
            
        case kSCKeySuite_2FISH256:
            alg = kCipher_Algorithm_2FISH256;
            len = 32;
            break;
            
        default:
            err = kSCLError_BadParams;
            break;
            ;
    }
    
    if(IsntSCLError(err))
    {
        if(algorithm) *algorithm = alg;
        if(keyLen) *keyLen = len;
    }

    
    return err;
    
}


#pragma mark - property management

static SCProperty* sFindProperty(SCKey_Context *ctx, const char *propName )
{
    SCProperty* prop = ctx->propList;
    
    while(prop)
    {
        if(CMP2(prop->prop, strlen((char *)(prop->prop)), propName, strlen(propName)))
        {
            break;
        }else
            prop = prop->next;
    }
    
    return prop;
}

static void sInsertProperty(SCKey_Context *ctx, const char *propName,
                            SCKeyPropertyType propType, void *data,  size_t  datSize)
{
    SCProperty* prop = sFindProperty(ctx,propName);
    if(!prop)
    {
        prop = XMALLOC(sizeof(SCProperty));
        ZERO(prop,sizeof(SCProperty));
        prop->prop = (uint8_t *)strndup(propName, strlen(propName));
        prop->next = ctx->propList;
        ctx->propList = prop;
    }
    
    if(prop->value) XFREE(prop->value);
    prop->value = XMALLOC(datSize);
    prop->type = propType;
    COPY(data, prop->value, datSize );
    prop->valueLen = datSize;
    
};


static void sCloneProperties(SCKey_Context *src, SCKey_Context *dest )
{
    SCProperty* sprop = NULL;
    SCProperty** lastProp = &dest->propList;
    
    for(sprop = src->propList; sprop; sprop = sprop->next)
    {
        SCProperty* newProp =  XMALLOC(sizeof(SCProperty));
        ZERO(newProp,sizeof(SCProperty));
        newProp->prop = (uint8_t *)strndup((char *)(sprop->prop), strlen((char *)(sprop->prop)));
        newProp->type = sprop->type;
        newProp->value = XMALLOC(sprop->valueLen);
        COPY(sprop->value, newProp->value, sprop->valueLen );
        newProp->valueLen = sprop->valueLen;
        *lastProp = newProp;
        lastProp = &newProp->next;
    }
    *lastProp = NULL;
    
 }


static bool isSignableProperty(SCKeyContextRef ctx,  const char *propName)
{
    bool isSignable = false;
    const char **p;
    
    for(p = kSCKeyDefaultSignedPropertyList; *p; p++)
    {
        if(STRCMP2(*p, propName))
        {
            isSignable = true;
            break;
        }
    }
    
    
    return isSignable;
}



SCLError SCKeySetProperty( SCKeyContextRef ctx,
                          const char *propName, SCKeyPropertyType propType,
                          void *data,  size_t  datSize)
{
    
    SCLError    err = kSCLError_NoErr;
    SCPropertyInfo  *propInfo = NULL;
    bool found = false;
    
    validateSCKeyContext(ctx);
    
    
    for(propInfo = sPropertyTable; propInfo->name; propInfo++)
    {
        if(CMP2(propName, strlen(propName), propInfo->name, strlen(propInfo->name)))
        {
            if(propInfo->readOnly)
                RETERR(kSCLError_BadParams);
            
            if(propType != propInfo->type)
                RETERR(kSCLError_BadParams);
            
            if(STRCMP2(propName, kSCKeyProp_ExpireDate))
            {
              if(datSize != sizeof(ctx->expireDate))
                  RETERR(kSCLError_BadParams);
                
                COPY(data, &ctx->expireDate, sizeof(ctx->expireDate));
                
            }
            else if(STRCMP2(propName, kSCKeyProp_StartDate))
            {
                if(datSize != sizeof(ctx->startDate))
                    RETERR(kSCLError_BadParams);
                
                COPY(data, &ctx->startDate, sizeof(ctx->startDate));
            }
            else if(STRCMP2(propName, kSCKeyProp_Locator))
            {
                if(datSize != sizeof(ctx->locator))
                    RETERR(kSCLError_BadParams);
                
                COPY(data, ctx->locator, sizeof(ctx->locator));
               
            }
            else if(STRCMP2(propName, kSCKeyProp_Owner))
            {
                ctx->owner = (uint8_t *)strndup(data, datSize);
            }
            else if(STRCMP2(propName, kSCKeyProp_IV))
            {
                sInsertProperty(ctx, propName, propType, data, datSize);CKERR; 
            }
             
            found = true;
             break;
         }
    }

    if(!found)
        sInsertProperty(ctx, propName, propType, data, datSize);CKERR;

    if((ctx->keyType == kSCKeyType_Private)  && isSignableProperty(ctx, propName))
    {
        
        // re-sign key
        err = SCKeySignKey(ctx, ctx, NULL); CKERR;
    }


done:
    return err;
  
}

static SCLError sMakeHash(HASH_Algorithm algorithm, const unsigned char *in, unsigned long inlen, unsigned long outLen, uint8_t *out)
{
    SCLError             err         = kSCLError_NoErr;
    HASH_ContextRef     hashRef     = kInvalidHASH_ContextRef;
 	uint8_t             hashBuf[128];
    uint8_t             *p = (outLen < sizeof(hashBuf))?hashBuf:out;
    
    err = HASH_Init( algorithm, & hashRef); CKERR;
    err = HASH_Update( hashRef, in,  inlen); CKERR;
    err = HASH_Final( hashRef, p); CKERR;
    
    if((err == kSCLError_NoErr) & (p!= out))
        COPY(hashBuf, out, outLen);
    
done:
    if(!IsNull(hashRef))
        HASH_Free(hashRef);
    
    return err;
}

static SCLError sGetSCKeyGetPropertyInternal( SCKeyContextRef ctx,
                                              const char *propName, SCKeyPropertyType *outPropType,
                                              void *outData, size_t bufSize, size_t *datSize, bool doAlloc,
                                              uint8_t** allocBuffer)
{
    SCLError            err         = kSCLError_NoErr;
    SCPropertyInfo      *propInfo   = NULL;
    SCProperty*         otherProp   = NULL;
    SCKeyPropertyType   propType    = SCKeyPropertyType_Invalid;
    bool                found       = false;
    
    size_t          actualLength = 0;
    uint8_t*        buffer = NULL;
    uint8_t         hashBuf[PUBKEY_HASH_LEN];
    
    if(datSize)
        *datSize = 0;
    
    
    if( sSCKey_ContextIsECC(ctx)
       && CMP2(propName, strlen(propName), kSCKeyProp_KeyHash, strlen(kSCKeyProp_KeyHash)))
    {
        actualLength = ((((PUBKEY_HASH_LEN) + 2) / 3) * 4) + 1;
        found = true;
    }

    if(!found) for(propInfo = sPropertyTable;propInfo->name; propInfo++)
    {
        if(CMP2(propName, strlen(propName), propInfo->name, strlen(propInfo->name)))
        {
            propType = propInfo->type;
            
            found = true;

            if(STRCMP2(propName, kSCKeyProp_SymmetricKey))
            {
                switch(ctx->keySuite)
                {
                    case kSCKeySuite_AES128:
                        actualLength = 16;
                        break;
                    case kSCKeySuite_AES256:
                        actualLength = 32;
                        break;
                    case kSCKeySuite_2FISH256:
                        actualLength = 32;
                        break;
                        
                    default:
                        RETERR(kSCLError_BadParams);
                        break;
                }
                if(ctx->sym.eSymKey)
                    RETERR(kSCLError_KeyNotFound);
            }
            else if(STRCMP2(propName, kSCKeyProp_Locator))
            {
                actualLength = ((((SCKEY_LOCATOR_BYTES) + 2) / 3) * 4) + 1;
            }
            else if(STRCMP2(propName, kSCKeyProp_EncryptedTo))
            {
                if(((ctx->keySuite == kSCKeySuite_AES128)
                    || (ctx->keySuite == kSCKeySuite_AES256)
                    || (ctx->keySuite == kSCKeySuite_2FISH256) )
                   && (ctx->sym.eSymKey))
                {
                    actualLength = ((((SCKEY_LOCATOR_BYTES) + 2) / 3) * 4) + 1;
                }
                else
                    RETERR(kSCLError_BadParams );
            }
            
            else if(STRCMP2(propName, kSCKeyProp_HMACcode))
            {
                if(ctx->keyType == kSCKeyType_HMACcode)
                {
                    actualLength = ((((SCKEY_LOCATOR_BYTES) + 2) / 3) * 4) + 1;
                }
                else
                    RETERR(kSCLError_BadParams );
            }
            else if(STRCMP2(propName, kSCKeyProp_PubKeyANSI_X963))
            {
                if((ctx->keyType == kSCKeyType_Public) || (ctx->keyType == kSCKeyType_Private))
                {
                    actualLength = 128;
                }
                else
                    RETERR(kSCLError_BadParams );
            }
             else if(STRCMP2(propName, kSCKeyProp_ExpireDate))
            {
                actualLength =  sizeof(ctx->expireDate);
            }
            else if(STRCMP2(propName, kSCKeyProp_StartDate))
            {
                actualLength =  sizeof(ctx->startDate);
            }
            else if(STRCMP2(propName, kSCKeyProp_SCKeySuite))
            {
                actualLength =  sizeof(SCKeySuite);
            }
            else if(STRCMP2(propName, kSCKeyProp_SCKeyType))
            {
                actualLength =  sizeof(SCKeyType);
            }

            else if(STRCMP2(propName, kSCKeyProp_Owner))
            {
                actualLength = strlen((char *)(ctx->owner));
            }
            else
                found = false;
 
            break;
        }
     }
    
    if(!found)
    {
        otherProp = sFindProperty(ctx,propName);
        if(otherProp)
        {
            actualLength = (unsigned long)(otherProp->valueLen);
            propType = otherProp->type;
            found = true;
        }
    }
    
    if(!found)
        RETERR(kSCLError_BadParams);
    
 
    if(!actualLength)
        goto done;
    
    if(doAlloc)
    {
        buffer = XMALLOC(actualLength + sizeof('\0')); CKNULL(buffer);
        *allocBuffer = buffer;
    }
    else
    {
        actualLength = (actualLength < (unsigned long)bufSize) ? actualLength : (unsigned long)bufSize;
        buffer = outData;
    }
    
    if( sSCKey_ContextIsECC(ctx)
       && CMP2(propName, strlen(propName), kSCKeyProp_KeyHash, strlen(kSCKeyProp_KeyHash)))
    {
        // calculate the truncated key hash for the ECC key.
        err = sMakeHash(kHASH_Algorithm_SHA256, ctx->pub.pubKey, sizeof(ctx->pub.pubKey), SCKEY_LOCATOR_BYTES, hashBuf);
        err = B64_encode(hashBuf, SCKEY_LOCATOR_BYTES, buffer, &actualLength); CKERR;
    }
    else if(STRCMP2(propName, kSCKeyProp_SymmetricKey))
    {
        COPY(&ctx->sym.symKey,  buffer, actualLength);
    }
    else if(STRCMP2(propName, kSCKeyProp_Locator))
    {
        err = B64_encode(ctx->locator, SCKEY_LOCATOR_BYTES, buffer, &actualLength); CKERR;
        actualLength++;
        buffer[actualLength]= '\0';
     }
    else if(STRCMP2(propName, kSCKeyProp_EncryptedTo))
    {
        err = B64_encode(ctx->sym.ePubLocator, SCKEY_LOCATOR_BYTES, buffer, &actualLength); CKERR;
        actualLength++;
        buffer[actualLength]= '\0';
    }
    else if(STRCMP2(propName, kSCKeyProp_HMACcode))
    {
        err = B64_encode(ctx->hmac.HMAC, SCKEY_LOCATOR_BYTES, buffer, &actualLength); CKERR;
        actualLength++;
        buffer[actualLength]= '\0';
    }
     else if(STRCMP2(propName, kSCKeyProp_StartDate))
    {
        COPY(&ctx->startDate, buffer, actualLength);
     }
    else if(STRCMP2(propName, kSCKeyProp_ExpireDate))
    {
        COPY(&ctx->expireDate, buffer, actualLength);
    }
    else if(STRCMP2(propName, kSCKeyProp_SCKeySuite))
    {
        COPY(&ctx->keySuite, buffer, actualLength);
    }
    else if(STRCMP2(propName, kSCKeyProp_SCKeyType))
    {
        COPY(&ctx->keyType, buffer, actualLength);
    }
     else if(STRCMP2(propName, kSCKeyProp_Owner))
    {
        strncpy((char *)buffer, (char *)(ctx->owner), actualLength);
    }
    else if(STRCMP2(propName, kSCKeyProp_PubKeyANSI_X963))
    {
    	size_t bufSize = (size_t)actualLength;
        err = ECC_Export_ANSI_X963( ctx->pub.ecc, buffer, bufSize, &bufSize); CKERR;
        actualLength = (unsigned long)bufSize;
    }
   
    else if(otherProp)
    {
        COPY(otherProp->value,  buffer, actualLength);
        propType = otherProp->type;
    }
      
    if(outPropType)
        *outPropType = propType;

    if(datSize)
        *datSize = actualLength;
    
    
done:
    return err;
    
}
 
SCLError SCKeyGetProperty( SCKeyContextRef ctx,
                              const char *propName,
                                SCKeyPropertyType *outPropType, void *outData, size_t bufSize, size_t *datSize)
{
    SCLError err = kSCLError_NoErr;
    
    validateSCKeyContext(ctx);
    ValidateParam(outData);
     
    if ( IsntNull( outData ) )
	{
		ZERO( outData, bufSize );
	}
    
    err =  sGetSCKeyGetPropertyInternal(ctx, propName, outPropType, outData, bufSize, datSize, false, NULL);
    
    return err;
}



SCLError SCKeyGetAllocatedProperty( SCKeyContextRef ctx,
                                        const char *propName,
                                        SCKeyPropertyType *outPropType, void **outData, size_t *datSize)
{
    SCLError    err = kSCLError_NoErr;
    
    validateSCKeyContext(ctx);
    ValidateParam(outData);
    
    err =  sGetSCKeyGetPropertyInternal(ctx, propName, outPropType, NULL, 0, datSize, true, (uint8_t**) outData);
    
    return err;
}

#pragma mark - passphrase




static SCLError sNewPassPhraseInternal ( SCKeyContextRef    symCtx,
                                        const uint8_t       *passphrase, size_t passphraseLen,
                                        SCKeyContextRef      *ctx)
{
    SCLError        err = kSCLError_NoErr;
    SCKey_Context*   keyCTX = NULL;
    size_t          keylen = 0;
    Cipher_Algorithm algorithm = kCipher_Algorithm_Invalid;
    
    uint8_t         unlocking_key[64];
    
    ValidateParam(ctx);
    *ctx = NULL;
    
    keyCTX = XMALLOC(sizeof (SCKey_Context)); CKNULL(keyCTX);
    ZERO(keyCTX, sizeof(SCKey_Context));
    
    keyCTX->keySuite = symCtx->keySuite;
    keyCTX->magic = kSCKey_ContextMagic;
    keyCTX->keyType = kSCKeyType_PassPhrase;
    keyCTX->pass.kdf = SCKeyDF_PBKDF2;
    
    COPY(symCtx->locator, keyCTX->locator, SCKEY_LOCATOR_BYTES);
    
    switch(symCtx->keySuite)
    {
        case kSCKeySuite_AES128:
            keylen = 16;
            algorithm = kCipher_Algorithm_AES128;
            break;
            
        case kSCKeySuite_AES256:
            keylen = 32;
            algorithm = kCipher_Algorithm_AES256;
            break;
            
        case kSCKeySuite_2FISH256:
            keylen = 32;
            algorithm = kCipher_Algorithm_2FISH256;
            break;
            
        default:
            RETERR(kSCLError_BadCipherNumber);
    }
    
    err = RNG_GetBytes( keyCTX->pass.salt, SALT_BYTES ); CKERR;
    
    err = PASS_TO_KEY_SETUP(strlen((char *)passphrase),
                            keylen, keyCTX->pass.salt, SALT_BYTES, &keyCTX->pass.rounds); CKERR;
     
    err = PASS_TO_KEY(passphrase, strlen((char *)passphrase),
                      keyCTX->pass.salt, SALT_BYTES,  keyCTX->pass.rounds,
                      unlocking_key, keylen); CKERR;
    
 
    
    err =  ECB_Encrypt(algorithm, unlocking_key, symCtx->sym.symKey, keylen, keyCTX->pass.lockedKey); CKERR;
    
     err = PASSPHRASE_HASH(unlocking_key, keylen,
                          keyCTX->pass.salt, SALT_BYTES,
                          keyCTX->pass.rounds,
                          keyCTX->pass.keyHash, PKDF_HASH_BYTES); CKERR;
 
    sCloneProperties(symCtx, keyCTX);
    sCloneSignatures(symCtx, keyCTX);
    
    *ctx = keyCTX;
    
done:
    if(IsSCLError(err))
    {
        if(IsntNull(keyCTX))
        {
            XFREE(keyCTX);
        }
    }
    
    ZERO(unlocking_key, sizeof(unlocking_key));
    
    return err;
}



SCLError SCKeyEncryptToPassPhrase(SCKeyContextRef        symCtx,
                                  const uint8_t           *passphrase,
                                  size_t                  passphraseLen,
                                  SCKeyContextRef         *ctx)
{
    SCLError        err = kSCLError_NoErr;
    
    ValidateParam(ctx);
    
    err = sNewPassPhraseInternal(symCtx, passphrase,passphraseLen, ctx); CKERR;
    
done:
    
    return err;
}

SCLError SCKeyDecryptFromPassPhrase(SCKeyContextRef   passCtx,
                                    const uint8_t         *passphrase,
                                    size_t                passphraseLen,
                                    SCKeyContextRef       *symCtx)
{
    SCLError            err = kSCLError_NoErr;
    SCKey_Context*      keyCTX = NULL;
    size_t              keylen = 0;
    Cipher_Algorithm    algorithm = kCipher_Algorithm_Invalid;
    
    uint8_t             unlocking_key[64];
    uint8_t             keyHash[PKDF_HASH_BYTES];
     
    ValidateParam(passCtx);
    ValidateParam(passphrase);
     
    if(passCtx->keyType != kSCKeyType_PassPhrase)  
        RETERR(kSCLError_BadParams);
    
    switch(passCtx->keySuite)
    {
        case kSCKeySuite_AES128:
            keylen = 16;
            algorithm = kCipher_Algorithm_AES128;
            break;
            
        case kSCKeySuite_AES256:
            keylen = 32;
            algorithm = kCipher_Algorithm_AES256;
            break;
            
        case kSCKeySuite_2FISH256:
            keylen = 32;
            algorithm = kCipher_Algorithm_2FISH256;
            break;

        default:
            RETERR(kSCLError_BadCipherNumber);
    }
   
    
   err = PASS_TO_KEY(passphrase, strlen((char *)passphrase),
                      passCtx->pass.salt, SALT_BYTES,  passCtx->pass.rounds,
                      unlocking_key, keylen); CKERR;
    
    err = PASSPHRASE_HASH(unlocking_key, keylen,
                          passCtx->pass.salt, SALT_BYTES,
                          passCtx->pass.rounds,
                          keyHash, PKDF_HASH_BYTES); CKERR;
 

    if(!CMP(keyHash, passCtx->pass.keyHash, PKDF_HASH_BYTES))
        RETERR(kSCLError_BadIntegrity);
    
    keyCTX = XMALLOC(sizeof (SCKey_Context)); CKNULL(keyCTX);
    ZERO(keyCTX, sizeof(SCKey_Context));
    
    keyCTX->magic       = kSCKey_ContextMagic;
    keyCTX->keySuite    = passCtx->keySuite;
    keyCTX->keyType     = kSCKeyType_Symmetric;
    
    COPY(passCtx->locator, keyCTX->locator, SCKEY_LOCATOR_BYTES);

    err =  ECB_Decrypt(algorithm, unlocking_key, passCtx->pass.lockedKey, keylen, keyCTX->sym.symKey); CKERR;
    
    sCloneProperties(passCtx, keyCTX);
    sCloneSignatures(passCtx, keyCTX);
    
    *symCtx = keyCTX;

    
done:
    if(IsSCLError(err))
    {
        if(IsntNull(keyCTX))
        {
            XFREE(keyCTX);
        }
    }
    
    ZERO(unlocking_key, sizeof(unlocking_key));
     
    return err;
    
}



#pragma mark - key signing

static void sDeleteSignature(SCKey_Context *ctx, const uint8_t *signedBy )
{
    SCSigItem* item = ctx->sigList;
    SCSigItem* previous = NULL;
    
    // find the item;
    
    for(item = ctx->sigList; item; item = item->next)
    {
        if(CMP(item->sig.sPubLocator, signedBy, SCKEY_LOCATOR_BYTES)) break;
        previous = item;
    }
    
    if(item)
    {
        // remove from list head?
        if(ctx->sigList == item)
            ctx->sigList = item->next;
        else
            previous->next = item->next;
        
        XFREE(item->sig.signature);
        XFREE(item);
    }
}

static void sInsertSig(SCKey_Context *ctx,
                       SCKeyContextRef  signingCtx,
                       uint8_t          *sigData,
                       size_t           sigDataLen,
                       char**          hashList)
{
    SCSigItem* sigItem = XMALLOC(sizeof(SCSigItem));
    if(sigItem)
    {
        ZERO(sigItem,sizeof(SCSigItem));
        
        sigItem->sig.signature = XMALLOC(sigDataLen);
        COPY(sigData, sigItem->sig.signature, sigDataLen );
        sigItem->sig.signatureLen = sigDataLen;
        sigItem->sig.hashList = hashList;
        
        sigItem->sig.startDate = time(NULL);
        
        COPY(signingCtx->locator, sigItem->sig.sPubLocator, SCKEY_LOCATOR_BYTES );
        
        // delete old sigs
        sDeleteSignature(ctx, signingCtx->locator);
        
        sigItem->next = ctx->sigList;
        ctx->sigList = sigItem;
    }
};

static SCKeySignature* sFindSignature(SCKey_Context *ctx, const uint8_t *signedBy )
{
    SCSigItem* sig = ctx->sigList;
    
    while(sig)
    {
        if(CMP(sig->sig.sPubLocator, signedBy, SCKEY_LOCATOR_BYTES))
        {
            return(&sig->sig);
            
            break;
        }else
            sig = sig->next;
    }
    
    return NULL;
}

static void sCloneSignatures(SCKey_Context *src, SCKey_Context *dest )
{
    SCSigItem* item = NULL;
    SCSigItem** lastSig = &dest->sigList;
    
    for(item = src->sigList; item; item = item->next)
    {
        SCSigItem* newItem =  XMALLOC(sizeof(SCSigItem));
        ZERO(newItem,sizeof(SCSigItem));
        
        if(item->sig.signature)
        {
            newItem->sig.signature = XMALLOC(item->sig.signatureLen );
            COPY(item->sig.signature, newItem->sig.signature, item->sig.signatureLen );
            
            newItem->sig.signatureLen = item->sig.signatureLen;
            COPY(item->sig.sPubLocator, newItem->sig.sPubLocator, SCKEY_LOCATOR_BYTES );
            
            newItem->sig.startDate = item->sig.startDate;
            newItem->sig.expireDate = item->sig.expireDate;
            
            if(item->sig.hashList)
            {
             // count hashList Items
                int count = 0;
                char **hashItem = NULL;
                 
                for(hashItem =  item->sig.hashList; *hashItem; hashItem++, count++);
               
                if(count)
                {
                    
                    newItem->sig.hashList = XMALLOC((count +1 ) * sizeof(char*));
                    ZERO(newItem->sig.hashList, (count +1 ) * sizeof(char*));
                    for( count = 0, hashItem =  item->sig.hashList; *hashItem; hashItem++, count++)
                    {
                        newItem->sig.hashList[count] = strdup(*hashItem);
                     }
                 }
               }
            
            *lastSig = newItem;
            lastSig = &newItem->next;
         }
        
    }
    *lastSig = NULL;
    
}



static SCLError sCalulateKeyHash( SCKeyContextRef keyCtx,  char* hashList[], uint8_t* hashBuf, size_t *hashBytes )
{
    SCLError        err = kSCLError_NoErr;
    HASH_ContextRef hash = kInvalidHASH_ContextRef;
    
    if(!hashList) hashList = (char**)kSCKeyDefaultSignedPropertyList;
    char**   itemName = hashList;
   
    size_t      tempLen;
    uint8_t     tempBuf[512];

    err  = HASH_Init(kHASH_Algorithm_SHA256, &hash); CKERR;
    
    for( ;*itemName; itemName++)
    {
        if(STRCMP2(*itemName, kSCKeyProp_SCKeySuite))
        {
            err  = HASH_Update(hash, &keyCtx->keySuite, sizeof(SCKeySuite)); CKERR;
        }
        else if(STRCMP2(*itemName, kSCKeyProp_Locator))
        {
            err  = HASH_Update(hash, &keyCtx->locator, SCKEY_LOCATOR_BYTES);CKERR;
        }
        else if(STRCMP2(*itemName, kSCKeyProp_StartDate))
        {
            struct tm *nowtm;
            nowtm = gmtime(&keyCtx->startDate);
            tempLen = strftime((char *)tempBuf, sizeof(tempBuf), kRfc339Format, nowtm);
            err  = HASH_Update(hash,tempBuf, tempLen);CKERR;
        }
        else if(STRCMP2(*itemName, kSCKeyProp_ExpireDate))
        {
            struct tm *nowtm;
            nowtm = gmtime(&keyCtx->expireDate);
            tempLen = strftime((char *)tempBuf, sizeof(tempBuf), kRfc339Format, nowtm);
            err  = HASH_Update(hash,tempBuf, tempLen);CKERR;
        }
        else if(STRCMP2(*itemName, kSCKeyProp_HMACcode) && (keyCtx->keyType == kSCKeyType_HMACcode))
        {
            err  = HASH_Update(hash, &keyCtx->hmac.HMAC, SCKEY_LOCATOR_BYTES);CKERR;
        }
        else if(STRCMP2(*itemName, kSCKeyProp_Owner))
        {
            if(keyCtx->owner)
            {
                err  = HASH_Update(hash, keyCtx->owner, strlen((char *)(keyCtx->owner)));CKERR;
            }
        }
        else if(STRCMP2(*itemName, kSCKeyProp_SymmetricKey) && (keyCtx->keyType == kSCKeyType_Symmetric))
        {
            size_t keyBytes = 0;
            
            switch(keyCtx->keySuite)
            {
                case kSCKeySuite_AES128: keyBytes = 16; break;
                case kSCKeySuite_AES256: keyBytes = 32; break;
                case kSCKeySuite_2FISH256: keyBytes = 32; break;
                default: RETERR(kSCLError_BadParams);
            }
            
            err  = HASH_Update(hash, keyCtx->sym.symKey, keyBytes);
            
        }
        else if(STRCMP2(*itemName, kSCKeyProp_PubKey))
        {
            if((keyCtx->keyType == kSCKeyType_Public) || (keyCtx->keyType == kSCKeyType_Private ) )
            {
                err  = HASH_Update(hash, &keyCtx->pub.pubKey, keyCtx->pub.pubKeyLen);
            }
        }
    }
     
    HASH_GetSize(hash, hashBytes);
    
    HASH_Final(hash,hashBuf);
    
done:
    
    ZERO(tempBuf, sizeof(tempBuf));
    
    if(HASH_ContextRefIsValid(hash))
        HASH_Free(hash);
    
    return err;
    

}



static bool sVerifyKeySig(SCKeyContextRef  ctx, const SCKeySignature *sig )
{
    SCLError        err = kSCLError_NoErr;
 
    bool verified = false;
    
    uint8_t     keyHash[32];
    size_t      hashBytes = 0;

    err = sCalulateKeyHash(ctx, sig->hashList, keyHash, &hashBytes);

    err = SCKeyVerifyHash(ctx, keyHash, hashBytes, sig->signature, sig->signatureLen); CKERR;
    
    verified = true;
 
done:
      
    return verified;
}


SCLError SCKeyVerifySig( SCKeyContextRef  keyCtx,  char* signingList[], SCKeyContextRef  signingKeyCtx,  SCKeyContextRef  sigCtx )
{
    SCLError        err = kSCLError_NoErr;
    char**      hashList  = signingList;

    uint8_t     keyHash[32];
    size_t      hashBytes = 0;
    
    validateSCKeyContext(keyCtx);
   
    err = sCalulateKeyHash(keyCtx, hashList ,keyHash, &hashBytes);
 
    err = SCKeyVerifyHash(signingKeyCtx, keyHash, hashBytes, sigCtx->sig.signature, sigCtx->sig.signatureLen); CKERR;
    
done:
    return err;

}

SCLError SCKeySignKey(  SCKeyContextRef  signingCtx, SCKeyContextRef  keyCtx,  char* signingList[])
{
    SCLError        err = kSCLError_NoErr;
     
    const int   ST_BUFF_SIZE = 256;
    uint8_t     ST[ST_BUFF_SIZE];
    size_t      STlen = 0;
    
    uint8_t     keyHash[32];
    size_t      hashBytes = 0;
    char**      hashList  = signingList;
      
    validateSCKeyContext(signingCtx);
    validateSCKeyContext(keyCtx);
    
    bool canSign =  sSCKey_ContextIsECC(signingCtx)
    &&  ECC_ContextRefIsValid(signingCtx->pub.ecc)
    && ECC_isPrivate(signingCtx->pub.ecc);
    
    bool bLocked = (  signingCtx->pub.lockedPrivKey );
     
    if(!canSign)
        RETERR(kSCLError_BadParams);

    if( bLocked)
        RETERR(kSCLError_KeyLocked);
   
    err = sCalulateKeyHash(keyCtx, hashList ,keyHash, &hashBytes);
    
    err = ECC_Sign(signingCtx->pub.ecc, keyHash , hashBytes,  ST, ST_BUFF_SIZE, &STlen);CKERR;
    sInsertSig(keyCtx, signingCtx, ST, STlen, hashList);

    
done:
     return err;
 }


#pragma mark - key fingerprint

#define kSCKey_FingerprintVersion    0x01
#define FP_BLOB_VERSION_CAN_RESTORE(oldVersion, currentVersion) ( (currentVersion == oldVersion) )

/* key fingerpints  blob format
 
 offset     len     value           desc
 0          4       'SCky'          kSCKey_ContextMagic
 4          1        0x01           kSCKey_FingerprintVersion
 5          1        0x02 or 0x03   kSCKeySuite
 6          1        20             SCKEY_LOCATOR_BYTES
 7          20       <bin>          key locator
 27         1        32             hash Length
 28         32       <bin>          SHA-256 hash of public key as caclulated by sCalulateKeyHash
 ...        2                       owner length (16 bits(
 ...        n       <str>           key owner JID name

 */


SCLError SCKeySerialize_Fingerprint( SCKeyContextRef keyCtx, uint8_t **outData, size_t *outSize)
{
    SCLError        err = kSCLError_NoErr;
    
    validateSCKeyContext(keyCtx);
    
    if(!outData || !outSize)
        RETERR(kSCLError_BadParams);
    
    SCKey_Context*      ctx = keyCtx;
    
    uint8_t*            buffer = NULL;
    size_t              bufLen = 0;
    uint8_t             *p = NULL;
    
    uint8_t             keyHash[32];
    size_t              hashBytes = 0;
    
    size_t              ownerLen = ctx->owner? strlen((const char *) ctx->owner): 0;
    
    if(ownerLen > UINT16_MAX)
        RETERR(kSCLError_FeatureNotAvailable);

    err = sCalulateKeyHash(ctx, NULL, keyHash, &hashBytes); CKERR;
    
    bufLen = sizeof(ctx->magic) + sizeof(uint8_t) + sizeof(uint8_t)
    +  sizeof(uint8_t)  + sizeof(ctx->locator)
    +  sizeof(uint8_t)  + hashBytes
    +  sizeof(uint16_t) + ownerLen;
    
    buffer = XMALLOC(bufLen); CKNULL(buffer);
    
    p = buffer;
    
    sStore32( ctx->magic, &p);
    sStore8( kSCKey_FingerprintVersion, &p);
    sStore8( ctx->keySuite, &p);
    
    sStore8( SCKEY_LOCATOR_BYTES, &p);
    sStoreArray(ctx->locator, SCKEY_LOCATOR_BYTES, &p );
    
    sStore8( hashBytes, &p);
    sStoreArray(keyHash, hashBytes, &p );
    
    sStore16(ownerLen , &p); // note: we store the null-termination byte
    if(ownerLen)
    {
        sStoreArray(ctx->owner, ownerLen, &p);  
    }
  
    *outData = buffer;
    *outSize = bufLen;
    
done:
    return err;
}


SCLError  sParseFingerPrint(uint8_t *buffer, size_t bufLen,
                            uint8_t *locatorOut, size_t * locatorBytesOut,
                             uint8_t *keyHashOut, size_t * hashBytesOut,
                             uint8_t **ownerOut, size_t * ownerBytesOut )
{
    SCLError        err = kSCLError_NoErr;
    ValidateParam(buffer);
    
    uint8_t             *bufferEnd = NULL;
    uint8_t             *p = NULL;
    
    uint8_t             blobVersion = 0;
    SCKeySuite          keySuite = kSCKeySuite_Invalid;
    
    uint8_t             keyHash[32];
    size_t              hashBytes = 0;
    
    uint8_t             locator[SCKEY_LOCATOR_BYTES];
    size_t              locatorBytes = 0;
    
    size_t              ownerBytes = 0;
    uint8_t*            owner = NULL;
    
    // check blobsize here
    size_t expectedbufLen = sizeof(uint32_t) + sizeof(uint8_t) + sizeof(uint8_t)
    +  sizeof(uint8_t) + SCKEY_LOCATOR_BYTES
    +  sizeof(uint8_t) + sizeof(uint16_t);
    
    if(bufLen < expectedbufLen)
        RETERR(kSCLError_CorruptData);
    
    p = buffer;
    bufferEnd = buffer + bufLen;
    
    // check fpBlob here
    if((sLoad32(&p) != kSCKey_ContextMagic)) RETERR(kSCLError_CorruptData);
    
    blobVersion = sLoad8(&p);
    if (!FP_BLOB_VERSION_CAN_RESTORE(blobVersion, kSCKey_FingerprintVersion))
        RETERR(kSCLError_CorruptData);
    
    keySuite = sLoad8(&p);
    
    if ( ((keySuite == kSCKeySuite_ECC414) || (keySuite == kSCKeySuite_ECC384)) != true   )
        RETERR(kSCLError_CorruptData);
    
    locatorBytes = sLoad8(&p);
    if(locatorBytes != SCKEY_LOCATOR_BYTES)
        RETERR(kSCLError_CorruptData);
    
    err = sLoadArray(locator, locatorBytes, &p, bufferEnd ); CKERR;
    
    hashBytes = sLoad8(&p);
    if(hashBytes > sizeof(keyHash))
        RETERR(kSCLError_CorruptData);
    
    err = sLoadArray(keyHash, hashBytes, &p, bufferEnd ); CKERR;
    
    ownerBytes = sLoad16(&p);
    owner = p;
    p+=ownerBytes;
    
    if(locatorOut)
        COPY(locator, locatorOut, locatorBytes);
    
    if(locatorBytesOut)
        *locatorBytesOut=locatorBytes;
    
    if(keyHashOut)
        COPY(keyHash, keyHashOut, hashBytes);
    
    if(hashBytesOut)
        *hashBytesOut = hashBytes;
    
    if(ownerBytesOut)
        *ownerBytesOut = ownerBytes;
    
    if(ownerOut)
    {
        uint8_t* ownerData = XMALLOC(ownerBytes + 1);
        COPY(owner, ownerData, ownerBytes);
        ownerData[ownerBytes] = '\0';
        *ownerOut = ownerData;
    }
    
done:
    return err;

}

SCLError SCKeyDeserialize_Fingerprint( uint8_t *buffer, size_t bufLen,
                                      uint8_t **locatorDataOut, uint8_t **fpOut,
                                      uint8_t **ownerDataOut, size_t *ownDataLenOut,
                                      uint8_t **hashWordsOut, size_t *hashWordsLengthOut)
{
    SCLError        err = kSCLError_NoErr;
     ValidateParam(buffer);
 
     union  {
        uint8_t     b [32];
        uint32_t    w[4];
    }keyHash;

    size_t              hashBytes = 0;
    
    uint32_t            SAS = 0;
    char                SASString[256];
    size_t              SASbytes    = sizeof(SASString);
  
    uint8_t             locator[SCKEY_LOCATOR_BYTES];
    size_t              locatorBytes = 0;

     size_t              actualLength = 0;
    uint8_t             *locatorData = NULL;
    uint8_t             *fpData = NULL;
    
    err = sParseFingerPrint(buffer,bufLen, locator, &locatorBytes, keyHash.b, &hashBytes, ownerDataOut, ownDataLenOut); CKERR;
    SAS =  ntohl(keyHash.w[3]);
    
    PGPWordEncode(SAS, SASString, &SASbytes);
    
    if(locatorDataOut)
    {
        actualLength = ((((locatorBytes) + 2) / 3) * 4) + 1;
        locatorData = XMALLOC(actualLength + sizeof('\0')); CKNULL(buffer);
        err = B64_encode(locator, locatorBytes, locatorData, &actualLength); CKERR;
        actualLength++;
        locatorData[actualLength]= '\0';
        
        *locatorDataOut = locatorData;
    }
    
    if(fpOut)
    {
        actualLength = ((((hashBytes) + 2) / 3) * 4) + 1;
        fpData = XMALLOC(actualLength + sizeof('\0')); CKNULL(buffer);
        err = B64_encode(keyHash.b, hashBytes, fpData, &actualLength); CKERR;
        actualLength++;
        fpData[actualLength]= '\0';
        
        *fpOut = fpData;
    }
    
    if(hashWordsOut)
    {
        char* buffer  = XMALLOC(SASbytes +1); CKNULL(buffer);
        strlcpy(buffer, SASString, SASbytes+1);
        *hashWordsOut =  (uint8_t*)buffer;
     }
    
    if(hashWordsLengthOut)
        *hashWordsLengthOut = SASbytes;
        


  done:
    return err;
}

SCLError SCKeyVerify_Fingerprint(SCKeyContextRef  ctx, uint8_t *inData, size_t inLen)
{
    SCLError        err = kSCLError_NoErr;
      validateSCKeyContext(ctx);
    
    bool canVerify =  sSCKey_ContextIsECC(ctx)
    &&  ECC_ContextRefIsValid(ctx->pub.ecc);
    
    if(!canVerify)
        RETERR(kSCLError_BadParams);
    
    uint8_t             keyHash[32];
    size_t              hashBytes = 0;
    
    uint8_t             locator[SCKEY_LOCATOR_BYTES];
    size_t              locatorBytes = 0;
 
    size_t              ownerLen = 0;
    
    uint8_t             calulatedKeyHash[32];
    size_t              calulatedHashBytes = 0;

    
    err = sParseFingerPrint(inData,inLen, locator, &locatorBytes, keyHash, &hashBytes, NULL, &ownerLen); CKERR;
  
    if(((locatorBytes == SCKEY_LOCATOR_BYTES) && CMP(ctx->locator,locator,locatorBytes)) == false)
        RETERR(kSCLError_CorruptData);
    
       err = sCalulateKeyHash(ctx, NULL, calulatedKeyHash, &calulatedHashBytes); CKERR;
   
    if(((calulatedHashBytes == hashBytes) && CMP(keyHash,calulatedKeyHash, hashBytes)) == false)
        RETERR(kSCLError_CorruptData);
    
done:
    
    
    return err;
}

#ifdef DEBUG
#warning Add code to export key signature info and verify it
#endif

#pragma mark - encrypt decrypt


SCLError SCKeyPublicEncrypt( SCKeyContextRef  ctx,
                            void *inData, size_t inDataLen,
                            void *outData, size_t bufSize, size_t *outDataLen)
{
    SCLError    err = kSCLError_NoErr;
    
    validateSCKeyContext(ctx);
 
    bool canEncrypt =  sSCKey_ContextIsECC(ctx)
                    &&  ECC_ContextRefIsValid(ctx->pub.ecc);
    
    if(!canEncrypt)
        RETERR(kSCLError_BadParams);
     
    err = ECC_Encrypt(ctx->pub.ecc, inData, inDataLen,  outData, bufSize, outDataLen);CKERR;
      
done:
    return err;
    
}

SCLError SCKeyPublicDecrypt( SCKeyContextRef  ctx,
                            void *inData, size_t inDataLen,
                            void *outData, size_t bufSize, size_t *outDataLen)
{
    SCLError    err = kSCLError_NoErr;
    
    validateSCKeyContext(ctx);
    
    bool canDecrypt =  sSCKey_ContextIsECC(ctx)
                        &&  ECC_ContextRefIsValid(ctx->pub.ecc)
                        && ECC_isPrivate(ctx->pub.ecc);
    
    if(!canDecrypt)
        RETERR(kSCLError_BadParams);
    
    err = ECC_Decrypt(ctx->pub.ecc, inData, inDataLen,  outData, bufSize, outDataLen);CKERR;
    
done:
    return err;
    
}


SCLError SCKeySignHash( SCKeyContextRef  ctx,
                       void *hash, size_t hashLen,
                       void *outSig, size_t bufSize, size_t *outSigLen)
{
    SCLError    err = kSCLError_NoErr;
    
    validateSCKeyContext(ctx);
    
    bool canSign =  sSCKey_ContextIsECC(ctx)
    &&  ECC_ContextRefIsValid(ctx->pub.ecc)
    && ECC_isPrivate(ctx->pub.ecc);
    
    if(!canSign)
        RETERR(kSCLError_BadParams);
    
    err = ECC_Sign(ctx->pub.ecc, hash, hashLen,  outSig, bufSize, outSigLen);CKERR;
    
done:
    return err;
    
}

SCLError SCKeyVerifyHash( SCKeyContextRef  ctx,
                      void *hash, size_t hashLen,
                      void *sig,  size_t sigLen)
{
    SCLError    err = kSCLError_NoErr;
    
    validateSCKeyContext(ctx);
    
    bool canVerify =  sSCKey_ContextIsECC(ctx)
                    &&  ECC_ContextRefIsValid(ctx->pub.ecc);
    
    if(!canVerify)
        RETERR(kSCLError_BadParams);
         
    err = ECC_Verify(ctx->pub.ecc,  sig, sigLen, hash, hashLen);
    
done:
    return err;
    
}



SCLError SCKeyPublicEncryptKey( SCKeyContextRef  pubCtx,
                               SCKeyContextRef  symCtx,
                               uint8_t **outData, size_t *outSize)
{
    SCLError    err = kSCLError_NoErr;
    
#define CT_BUFF_SIZE 256
    
    uint8_t        CT[CT_BUFF_SIZE];
    size_t         CTlen = 0;

    uint8_t             *yajlBuf = NULL;
    size_t              yajlLen = 0;
    
    uint8_t             tempBuf[1024];
    size_t              tempLen;
    
    uint8_t             *outBuf = NULL;
    yajl_gen            g = NULL;
    yajl_gen_status     stat = yajl_gen_status_ok;
    
    uint8_t     zero_locator[SCKEY_LOCATOR_BYTES];
    ZERO(zero_locator, SCKEY_LOCATOR_BYTES);

    yajl_alloc_funcs allocFuncs = {
        yajlMalloc,
        yajlRealloc,
        yajlFree,
        (void *) NULL
    };
    

    validateSCKeyContext(pubCtx);
    validateSCKeyContext(symCtx);
    ValidateParam(outData);
    ValidateParam(outSize);
    
    bool canEncrypt =  sSCKey_ContextIsECC(pubCtx)
                        &&  ECC_ContextRefIsValid(pubCtx->pub.ecc)
                        && ((symCtx->keySuite == kSCKeySuite_AES128)
                            || (symCtx->keySuite == kSCKeySuite_AES256)
                            || (symCtx->keySuite == kSCKeySuite_2FISH256) );
      
    if(!canEncrypt)
        RETERR(kSCLError_BadParams);
    
    size_t keylen = 0;
    
    keylen =  sGetKeyLength(symCtx->keySuite);
    if(!keylen) RETERR(kSCLError_BadCipherNumber);
    
    err = ECC_Encrypt(pubCtx->pub.ecc, symCtx->sym.symKey, keylen,  CT, CT_BUFF_SIZE, &CTlen);CKERR;
 
    g = yajl_gen_alloc(&allocFuncs); CKNULL(g);
    
#if DEBUG
    yajl_gen_config(g, yajl_gen_beautify, 1);
#else
    yajl_gen_config(g, yajl_gen_beautify, 0);
    
#endif
    yajl_gen_config(g, yajl_gen_validate_utf8, 1);
    stat = yajl_gen_map_open(g); CKSTAT;

    stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_SCKeyVersion, strlen(kSCKeyProp_SCKeyVersion)) ; CKSTAT;
    sprintf((char *)tempBuf, "%d", kSCKeyProtocolVersion);
    stat = yajl_gen_number(g, (char *)tempBuf, strlen((char *)tempBuf)) ; CKSTAT;
    
    stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_SCKeySuite, strlen(kSCKeyProp_SCKeySuite)) ; CKSTAT;

#if 1
    sprintf((char *)tempBuf, "%s", sKeySuiteString(symCtx->keySuite));
    stat = yajl_gen_string(g, tempBuf, strlen((char *)tempBuf)) ; CKSTAT;
    
#else
    sprintf((char *)tempBuf, "%d", symCtx->keySuite);
    stat = yajl_gen_number(g, (char *)tempBuf, strlen((char *)tempBuf)) ; CKSTAT;
    
#endif
    
    stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_EncryptedKey, strlen(kSCKeyProp_EncryptedKey)) ; CKSTAT;
    tempLen = sizeof(tempBuf);
    B64_encode(CT, CTlen, tempBuf, &tempLen);
    stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;

    if(memcmp(symCtx->locator,zero_locator,SCKEY_LOCATOR_BYTES) )
    {
        stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_Locator, strlen(kSCKeyProp_Locator)) ; CKSTAT;
        
        tempLen = sizeof(tempBuf);
        B64_encode(symCtx->locator, SCKEY_LOCATOR_BYTES, tempBuf, &tempLen);
        stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;
    }
    
    stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_EncryptedTo, strlen(kSCKeyProp_EncryptedTo)) ; CKSTAT;
    
    tempLen = sizeof(tempBuf);
    B64_encode(pubCtx->locator, SCKEY_LOCATOR_BYTES, tempBuf, &tempLen);
    stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;

    err = sGenSignatureStrings(symCtx, g); CKERR;
    
    err = sGenPropStrings(symCtx, g); CKERR;
  
    stat = yajl_gen_map_close(g); CKSTAT;
    
    stat =  yajl_gen_get_buf(g, (const unsigned char**) &yajlBuf, &yajlLen);CKSTAT;
    
    outBuf = XMALLOC(yajlLen+1); CKNULL(outBuf);
    memcpy(outBuf, yajlBuf, yajlLen);
    outBuf[yajlLen] = 0;
    
    *outData = outBuf;
    *outSize = yajlLen;

done:
    return err;
  
};


SCLError SCKeyPublicDecryptKey( SCKeyContextRef  pubCtx,
                               SCKeyContextRef  symCtx )
{
    SCLError    err = kSCLError_NoErr;
    size_t      tempLen;
    
    validateSCKeyContext(pubCtx);
    validateSCKeyContext(symCtx);
      
    bool canDecrypt =   sSCKey_ContextIsECC(pubCtx)
                        &&  ECC_ContextRefIsValid(pubCtx->pub.ecc) && ECC_isPrivate(pubCtx->pub.ecc)
                        && ((symCtx->keySuite == kSCKeySuite_AES128)
                            || (symCtx->keySuite == kSCKeySuite_AES256)
                            || (symCtx->keySuite == kSCKeySuite_2FISH256))
                        &&  symCtx->sym.eSymKey && (symCtx->sym.eSymKeyLen > 0);
      
    if(!canDecrypt)
        RETERR(kSCLError_BadParams);
    
    size_t keylen = 0;
    
    keylen =  sGetKeyLength(symCtx->keySuite);
    if(!keylen) RETERR(kSCLError_BadCipherNumber);
     
    err = ECC_Decrypt(pubCtx->pub.ecc,
                      symCtx->sym.eSymKey,
                      symCtx->sym.eSymKeyLen,
                      symCtx->sym.symKey, keylen, &tempLen);CKERR;

    if(keylen != tempLen)
        RETERR(kSCLError_CorruptData);
    
    XFREE(symCtx->sym.eSymKey);
    symCtx->sym.eSymKey = NULL;
    symCtx->sym.eSymKeyLen = 0;
    
done:
    return err;
}


SCLError SCKeySign( SCKeyContextRef  privCtx,
                       void *hash, size_t hashLen,
                       uint8_t **outData, size_t *outSize)
{
    SCLError    err = kSCLError_NoErr;
    
#define ST_BUFF_SIZE 256
    
    uint8_t        ST[ST_BUFF_SIZE];
    size_t         STlen = 0;
    
    uint8_t             *yajlBuf = NULL;
    size_t              yajlLen = 0;
    
    uint8_t             tempBuf[1024];
    size_t              tempLen;
    
    uint8_t             *outBuf = NULL;
    yajl_gen            g = NULL;
    yajl_gen_status     stat = yajl_gen_status_ok;
    
    uint8_t     zero_locator[SCKEY_LOCATOR_BYTES];
    ZERO(zero_locator, SCKEY_LOCATOR_BYTES);
    
    yajl_alloc_funcs allocFuncs = {
        yajlMalloc,
        yajlRealloc,
        yajlFree,
        (void *) NULL
    };
    
    validateSCKeyContext(privCtx);
    ValidateParam(hash);
    ValidateParam(hashLen == 32);
    ValidateParam(outData);
    ValidateParam(outSize);
    
    bool canSign =  sSCKey_ContextIsECC(privCtx)
        &&  ECC_ContextRefIsValid(privCtx->pub.ecc) && ECC_isPrivate(privCtx->pub.ecc)
        && (hashLen == 32);
    
    if(!canSign)
        RETERR(kSCLError_BadParams);
     
     err = ECC_Sign(privCtx->pub.ecc, hash, hashLen,  ST, ST_BUFF_SIZE, &STlen);CKERR;
     
    g = yajl_gen_alloc(&allocFuncs); CKNULL(g);
    
#if DEBUG
    yajl_gen_config(g, yajl_gen_beautify, 1);
#else
    yajl_gen_config(g, yajl_gen_beautify, 0);
    
#endif
    
     yajl_gen_config(g, yajl_gen_validate_utf8, 1);
    stat = yajl_gen_map_open(g); CKSTAT;
    
    stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_SCKeyVersion, strlen(kSCKeyProp_SCKeyVersion)) ; CKSTAT;
    sprintf((char *)tempBuf, "%d", kSCKeyProtocolVersion);
    stat = yajl_gen_number(g, (char *)tempBuf, strlen((char *)tempBuf)) ; CKSTAT;
        
    stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_Signature, strlen(kSCKeyProp_Signature)) ; CKSTAT;
    tempLen = sizeof(tempBuf);
    B64_encode(ST, STlen, tempBuf, &tempLen);
    stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;
      
    stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_SignedBy, strlen(kSCKeyProp_SignedBy)) ; CKSTAT;
    tempLen = sizeof(tempBuf);
    B64_encode(privCtx->locator, SCKEY_LOCATOR_BYTES, tempBuf, &tempLen);
    stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;
    
    
    stat = yajl_gen_string(g, (uint8_t *)kSCKeyProp_StartDate, strlen(kSCKeyProp_StartDate)) ; CKSTAT;
    time_t now = time(NULL);
    struct tm *nowtm;
    nowtm = gmtime(&now);
    tempLen = strftime((char *)tempBuf, sizeof(tempBuf), kRfc339Format, nowtm);
    stat = yajl_gen_string(g, tempBuf, (size_t)tempLen) ; CKSTAT;

    stat = yajl_gen_map_close(g); CKSTAT;
    
    stat =  yajl_gen_get_buf(g, (const unsigned char**) &yajlBuf, &yajlLen);CKSTAT;
    
    outBuf = XMALLOC(yajlLen+1); CKNULL(outBuf);
    memcpy(outBuf, yajlBuf, yajlLen);
    outBuf[yajlLen] = 0;
    
    *outData = outBuf;
    *outSize = yajlLen;
    
done:
    return err;
    
}

SCLError SCKeyVerify( SCKeyContextRef  ctx,
                     void *hash, size_t hashLen,
                     uint8_t *sig,  size_t sigLen)
{
    SCLError                err = kSCLError_NoErr;
    yajl_status             stat = yajl_status_ok;
    yajl_handle             pHand = NULL;
    SCKeyJSONcontext       *jctx = NULL;
     
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
    
    ValidateParam(sig);
    
    bool canVerify =  sSCKey_ContextIsECC(ctx) &&  ECC_ContextRefIsValid(ctx->pub.ecc);
    
    if(!canVerify)
        RETERR(kSCLError_BadParams);
    
    jctx = XMALLOC(sizeof (SCKeyJSONcontext)); CKNULL(jctx);
    ZERO(jctx, sizeof(SCKeyJSONcontext));
    jctx->jType[jctx->level] = SCKey_JSON_Type_BASE;

    jctx->key.magic = kSCKey_ContextMagic;
    pHand = yajl_alloc(&callbacks, &allocFuncs, (void *) jctx);
    
    yajl_config(pHand, yajl_allow_comments, 1);
    stat = yajl_parse(pHand, sig,  sigLen); CKSTAT;
    stat = yajl_complete_parse(pHand); CKSTAT;
    
    if( (jctx->key.keyType != kSCKeyType_Signature)
        || !jctx->key.sig.signature
        || (jctx->key.sig.signatureLen == 0))
        RETERR(kSCLError_CorruptData);
       
    if(! CMP( jctx->key.sig.sPubLocator,  ctx->locator, sizeof(ctx->locator)))
        RETERR(kSCLError_KeyNotFound);
    
    err = ECC_Verify(ctx->pub.ecc,jctx->key.sig.signature, jctx->key.sig.signatureLen ,  hash, hashLen );

       
done:
     
    if(IsntNull(jctx))
    {
        ZERO(jctx, sizeof(SCKeyJSONcontext));
        XFREE(jctx);
    }
    
    if(IsntNull(pHand))
        yajl_free(pHand);
    
    return err;

}

#pragma mark - Storage Encryption


SCLError SCKeyStorageEncrypt(SCKeyContextRef  symCtx,
                             const uint8_t *in, size_t in_len,
                             uint8_t **outData, size_t *outSize)
{
    SCLError    err = kSCLError_NoErr;
    Cipher_Algorithm  algorithm = kCipher_Algorithm_Invalid;
    SCProperty*     IVprop   = NULL;
    size_t      keylen = 0;
    
    validateSCKeyContext(symCtx);
    
    bool canEncrypt =  (symCtx->keyType  == kSCKeyType_Symmetric) && (symCtx->sym.eSymKey == 0) ;
    
    if(!canEncrypt)
        RETERR(kSCLError_BadParams);
    
     keylen =  sGetKeyLength(symCtx->keySuite);
    if(!keylen) RETERR(kSCLError_BadCipherNumber);
    
    IVprop = sFindProperty(symCtx,kSCKeyProp_IV);
    if(!IVprop)
        RETERR(kSCLError_BadParams);
 
    err = SCKeyCipherForKeySuite(symCtx->keySuite, &algorithm, NULL); CKERR;
    
    err = MSG_Encrypt(algorithm, symCtx->sym.symKey, keylen, IVprop->value, in,in_len,outData, outSize); CKERR;

done:
    
    return err;
   
}

SCLError SCKeyStorageDecrypt(SCKeyContextRef  symCtx,
                             const uint8_t *in, size_t in_len,
                             uint8_t **outData, size_t *outSize)
{
    SCLError    err = kSCLError_NoErr;
    Cipher_Algorithm  algorithm = kCipher_Algorithm_Invalid;
   SCProperty*     IVprop   = NULL;
    size_t      keylen = 0;
    
    validateSCKeyContext(symCtx);
    
    bool canDecrypt =  (symCtx->keyType  == kSCKeyType_Symmetric) && (symCtx->sym.eSymKey == 0) ;
    
    if(!canDecrypt)
        RETERR(kSCLError_BadParams);
    
    keylen =  sGetKeyLength(symCtx->keySuite);
    if(!keylen) RETERR(kSCLError_BadCipherNumber);
    
    IVprop = sFindProperty(symCtx,kSCKeyProp_IV);
    if(!IVprop)
        RETERR(kSCLError_BadParams);

    err = SCKeyCipherForKeySuite(symCtx->keySuite, &algorithm, NULL); CKERR;

    err = MSG_Decrypt(algorithm, symCtx->sym.symKey, keylen, IVprop->value, in,in_len,outData, outSize); CKERR;
    
done:
    
     return err;
}

/* 
  I am removing SCKeyMakeHMACcode, I dont belive it is being used anywhere
  -- Vinnie 27-Oct-14
 */

#if 0
SCLError SCKeyMakeHMACcode( SCKeySuite keySuite, void *PK,      size_t PKlen,
                                void *nonce,    size_t nonceLen,
                                time_t          expireDate,
                                SCKeyContextRef signCtx,
                                SCKeyContextRef  *outCtx) 
{
    SCLError        err = kSCLError_NoErr;
    SCKey_Context*   iCTX = NULL;
  
    ValidateParam(PK);
    ValidateParam(outCtx);
   
    bool canHMAC=    PK && PKlen && nonce && nonceLen > 16  ;
  
    if(!canHMAC)
        RETERR(kSCLError_BadParams);
     
    
    iCTX = XMALLOC(sizeof (SCKey_Context)); CKNULL(iCTX);
    ZERO(iCTX, sizeof(SCKey_Context));
    
    iCTX->magic     = kSCKey_ContextMagic;
    iCTX->keyType   = kSCKeyType_HMACcode;
    iCTX->keySuite  = keySuite;
    
    iCTX->expireDate = expireDate;
 
    err = sMakeHash(kHASH_Algorithm_SHA256, PK, PKlen, SCKEY_LOCATOR_BYTES, iCTX->locator); CKERR;
 
    err = MAC_ComputeKDF(kMAC_Algorithm_HMAC,  kHASH_Algorithm_SHA256,
                         PK, PKlen,
                         "SCKEY_HMAC_Code",
                         nonce, nonceLen,
                         SCKEY_LOCATOR_BYTES >> 3,  SCKEY_LOCATOR_BYTES, iCTX->hmac.HMAC); CKERR;

    //  sign HMAC code
    if(signCtx)
    {
        if(signCtx->owner)
            iCTX->owner = (uint8_t *)strdup((char *)(signCtx->owner));
        
        err = SCKeySignKey(signCtx, iCTX, NULL); CKERR;
    }
    
    
    *outCtx = iCTX;

done:
    if(IsSCLError(err))
    {
        if(IsntNull(iCTX))
        {
            XFREE(iCTX);
        }
    }
    
    return err;
}
 
#endif


