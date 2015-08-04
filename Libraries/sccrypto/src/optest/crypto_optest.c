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
//  main,c.c
//  tomcrypt
//

#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <string.h>

#include  "SCcrypto.h"
 #include  "crypto_optest.h"


typedef enum
{
    kTest_Invalid   = 0,
    kTest_Hash,
    kTest_Hmac,
    kTest_Ciphers,
    kTest_ECC,
    kTest_CCM,
    kTest_P2K,
    kTest_SirenHash,
    kTest_SCKeys,
    kTest_SCloud,
    kTest_SCIMP,
    kTest_All,
} SDKTest;



static SDKTest sDefaultTests[]  =
{
    kTest_Hash,
    kTest_Hmac,
    kTest_Ciphers,
    kTest_CCM,
    kTest_ECC,
    kTest_P2K,
    kTest_SirenHash,
    kTest_SCKeys,
    kTest_SCloud,
    kTest_SCIMP,
    kTest_Invalid		// null terminated
};

/* for command line processing */
typedef enum
{
    kArg_Invalid   = 0,
    kArg_TestID,
    kArg_TestSet,
    kArg_Boolean,
    kArg_String,
    kArg_UInt,
    kArg_HexString,
    kArg_HexStringFile,
    kArg_Other,
} ArgType;


typedef struct
{
    bool        enable;
    ArgType 	type;
    void*		argument;
    SDKTest		testID;
    char*		shortName;
    char		charName;
    char*		longName;
} TestTable;

unsigned int gLogLevel	= OPTESTLOG_LEVEL_OFF;

int		sDebug_flag		= 0;
int		sVerbose_flag		= 0;

/*---------------------------------------------------------------------------------------
 Command line arguments
 ---------------------------------------------------------------------------------------*/

static TestTable sOpTestTable[] =
{
    //	{ 0, kArg_TestID,	  NULL,  kTest_FipsMode,	"fipsmode",	"Enable FIPS 140-2 mode"},
    { 0, kArg_TestID,	  NULL,  kTest_Hash,		"hash",				0,  "Secure Hash Algorithms" },
    { 0, kArg_TestID,	  NULL,  kTest_Hmac,		"HMAC",				0,  "Keyed-Hashing for Message Authentication" },
    { 0, kArg_TestID,	  NULL,  kTest_Ciphers,		"ciphers",			0,  "Low Level Encryption" },

    { 0, kArg_TestID,	  NULL,  kTest_ECC,         "ECC",				0,  "Ellipic Curve Public Key" },
    { 0, kArg_TestID,	  NULL,  kTest_CCM,         "CCM",				0,  "Counter with CBC-MAC (CCM)" },
    { 0, kArg_TestID,	  NULL,  kTest_P2K,         "P2K",				0,  "Key Derivation (PBKDF2)" },
    { 0, kArg_TestID,	  NULL,  kTest_SirenHash,   "siren",            0,  "Siren Hash" },
    { 0, kArg_TestID,	  NULL,  kTest_SCKeys,      "sckeys",           0,  "SC Keys API" },
    { 0, kArg_TestID,	  NULL,  kTest_SCloud,      "scloud",           0,  "SCloud API" },
    { 0, kArg_TestID,	  NULL,  kTest_SCIMP,       "scimp",            0,  "SCIMP API" },
    
    { 0, kArg_TestID,	  NULL,  kTest_Invalid,		 "none",				0,  NULL },
    
    /* arguments/modifiers */
    { 0, kArg_Boolean,  &sVerbose_flag,	kTest_Invalid,	"verbose",		'v',  "Enables verbose output" },
    { 0, kArg_Boolean,  &sDebug_flag,	kTest_Invalid,	"debug",		'd',  "Enables debug output" },
    
    /* preload test sets */
    { 0, kArg_TestSet,	&sDefaultTests,	kTest_All		,		"default",	0,	"Default test set"  },
};

#define OptestTableEntries  ((int)(sizeof(sOpTestTable) /  sizeof(TestTable)))

/*---------------------------------------------------------------------------------------
 Process Command line options
 ---------------------------------------------------------------------------------------*/

static int sLoadTestSet(SDKTest* testSet)
{
    int count, j;
    
    for(count = 0; *testSet; testSet++)
        for( j = 0; j < OptestTableEntries; j ++)
            if ( *testSet  == sOpTestTable[j].testID )
            {
                sOpTestTable[j].enable = 1;
                count++;
            }
    return count;
}

static TestTable* sFindTest(SDKTest id)
{
    int   j;
    for( j = 0; j < OptestTableEntries; j ++)
        if ( sOpTestTable[j].testID == id)
        {
            return  &sOpTestTable[j];
        }
    return NULL;
}

static char* sGetTestName(SDKTest id)
{
    TestTable* test = sFindTest(id);
    
    return( test?test->shortName: NULL);
}

static void sUsage()
{
    int j;
    
    fprintf (stderr, "\nSCCrypto Operational Testtool\n\nusage: minioptest [options] ..\nOptions: \n ");
    OPTESTPrintF("\tTests:\n" );
    for( j = 0; j < OptestTableEntries; j ++)
        if(  (sOpTestTable[j].type ==  kArg_TestID) && sOpTestTable[j].longName)
            OPTESTPrintF("\t--%-15s Test %s\n", sOpTestTable[j].shortName, sOpTestTable[j].longName);
    OPTESTPrintF("\n");
    
    OPTESTPrintF("\tTest Sets:\n" );
    for( j = 0; j < OptestTableEntries; j ++)
        if(  (sOpTestTable[j].type ==  kArg_TestSet) && sOpTestTable[j].longName)
        {
            SDKTest *p;
            int	i;
            
            OPTESTPrintF("\t--%-15s %s", sOpTestTable[j].shortName, sOpTestTable[j].longName);
            for (i = 0, p = sOpTestTable[j].argument; *p; p++, i++)
            {
                if((i & 3) == 0) OPTESTPrintF("\n\t%-20s","");
                OPTESTPrintF("%-10s",  sGetTestName(*p));
            }
            OPTESTPrintF("\n\n");
        }
    
    OPTESTPrintF("\tOptions:\n" );
    for( j = 0; j < OptestTableEntries; j ++)
        if( ((sOpTestTable[j].type == kArg_Boolean)
             || (sOpTestTable[j].type == kArg_String)
             || (sOpTestTable[j].type == kArg_HexString)
             || (sOpTestTable[j].type == kArg_Other))
           && sOpTestTable[j].longName)
            OPTESTPrintF("\t%s%c   %2s%-10s %s\n", 
                         sOpTestTable[j].charName?"-":"",  sOpTestTable[j].charName?sOpTestTable[j].charName:' ', 
                         sOpTestTable[j].shortName?"--":"",  sOpTestTable[j].shortName?sOpTestTable[j].shortName:"", 
                         sOpTestTable[j].longName);
    
}



/* Setup requested tests & arguments */
static void sSetupTestOptions (int argc, char **argv)
{
    
    int i, j;
    int testCount = 0;
    size_t	temp = 0;
    
    if(argc > 1)
    {
        for (i = 1; i < argc; i++)
        {
            bool found = false;
            
            for( j = 0; j < OptestTableEntries; j ++)
                if ( (IsntNull( sOpTestTable[j].shortName)
                      &&  ((strncmp(argv[i], "--", 2) == 0)
                           && (STRICMP(argv[i] + 2,  sOpTestTable[j].shortName) == 0)) )
                    || (( *(argv[i]) ==  '-' ) && ( *(argv[i] + 1) == sOpTestTable[j].charName)))
                {
                    found = true;
                    switch(sOpTestTable[j].type)
                    {
                        case kArg_TestID:
                            sOpTestTable[j].enable = 1;
                            testCount++;
                            break;
                            
                        case kArg_TestSet:
                            testCount += sLoadTestSet(sOpTestTable[j].argument);
                            break;
                            
                        case kArg_Boolean:
                            if(IsNull(sOpTestTable[j].argument)) continue;
                            *((bool*)sOpTestTable[j].argument) = true;
                            break;
                            
                        case kArg_String:
                            if(IsNull(sOpTestTable[j].argument)) continue;
                            temp = strlen(argv[++i]);
                            *((char**)sOpTestTable[j].argument) = malloc(temp + 2);
                            strcpy(*((char**)sOpTestTable[j].argument), argv[i]);
                            break;
                            
                        case kArg_HexString:
                        case kArg_HexStringFile:
                            if(IsNull(sOpTestTable[j].argument)) continue;
                            if(IsNull(argv[++i]))  goto error;
                            *((char**)sOpTestTable[j].argument) = malloc(temp + 2);
                            strcpy(*((char**)sOpTestTable[j].argument), argv[i]);
                            
                            break;
                            
                        case kArg_UInt:
                            if(IsNull(sOpTestTable[j].argument)) continue;
                            if( sscanf(argv[++i],"%zu",&temp) == 1)
                                *((ArgType*)sOpTestTable[j].argument) =  (int)temp;
                            break;
                            
                        case kArg_Other:
                        default:;
                    }
                    break;
                }
            if(!found) goto error;
        }
    }
    
    
    /* use default tests for this platform */
    if(testCount == 0)
        sLoadTestSet(sDefaultTests);
    
    if(sVerbose_flag) gLogLevel = OPTESTLOG_LEVEL_VERBOSE;
    if(sDebug_flag) gLogLevel =  OPTESTLOG_LEVEL_DEBUG;
         
    return;
    
error:
    sUsage();
    exit(1);
}

void sCleanupTestOptions()
{
    for(int j = 0; j < OptestTableEntries; j ++)
    {
        switch(sOpTestTable[j].type)
        {
                case kArg_String:
                case kArg_HexString:
                case kArg_HexStringFile:
                    if(sOpTestTable[j].argument)
                    {
                        free(sOpTestTable[j].argument);
                        sOpTestTable[j].argument = NULL;
                    }
                
                break;
                
                default:
                break;
                
        };
        
    }
    
   
}

static char BORDER_TEXT[] = "------------------------------------------\n";


int optest_main(int argc, char **argv)
{
    SCLError err = kSCLError_NoErr;
    char str[256];
    time_t					now;
    int					j;
    
    gLogLevel = OPTESTLOG_LEVEL_INFO;
    
    /* process Test options */
    sSetupTestOptions(argc, argv);

    OPTESTLogInfo("Silent Circle Crypto Library Operational Test\n");

    OPTESTLogInfo(" Initialize SDK\n");
    err = SCCrypto_Init(); CKERR;
    
    err = SCCrypto_GetVersionString(sizeof(str), str); CKERR;
     OPTESTLogInfo("\t%14s: %s\n","Version",str);
    
    /* log start time */
    time(&now);
    OPTESTLogInfo("\t%14s: %s", "Time", ctime(&now));

    /* Run selected tests */
    for( j = 0; j < OptestTableEntries; j ++)
        if (sOpTestTable[j].enable )
        {
            if(sOpTestTable[j].longName)
                OPTESTLogInfo("%s Testing %s\n%s",BORDER_TEXT, sOpTestTable[j].longName, BORDER_TEXT);
            
            switch(sOpTestTable[j].testID)
            {
                    
                    /* Run SHA test */
                case kTest_Hash:
                    err = TestHash();
                    break;
                    
                    /* Run HMAC test */
                case kTest_Hmac:
                    err = TestHMAC();
                    break;
                    
                    /* Run Low Level Encryption test */
                case kTest_Ciphers:
                    err = TestCiphers();
                    break;
                    
                    /* Run HMAC test */
                case kTest_ECC:
                     err = TestECC(); CKERR;
                     break;
                  
                    /* Run Low Level Encryption test */
                case kTest_CCM:
                    err = TestCCM();
                    break;
                    
                case kTest_P2K:
                    err = TestP2K();
                    break;
                    
                case kTest_SirenHash:
                    err = TestSirenHash();
                    break;
                    
                case kTest_SCKeys:
                    err = TestSCKeys();
                    break;
                    
                case kTest_SCloud:
                    err = TestSCloud();
                    break;
                    
                case kTest_SCIMP:
                    err = TestSCIMP();
                    break;
                    
                default:;
            }
            CKERR;
        }
    
    

    
    OPTESTLogInfo("\nSilent Circle Crypto Library operations Successful\n ");

done:
    
    if(IsSCLError(err))
    {
        
        if(IsntSCLError( SCCrypto_GetErrorString(err, sizeof(str), str)))
        {
               OPTESTLogError("\nError %d:  %s\n", err, str);
        }
        else
       {
           OPTESTLogError("\nError %d\n", err);
         
       }
         
    };
    
    sCleanupTestOptions();
    
    return 0;
}

#if OPTEST_IOS_SPECIFIC
int ios_main()
{
    int result = 0;
    
    result = optest_main(0,NULL);
    
    return (result);
}
#else


int main(int argc, char **argv)
{
    return(optest_main(argc, argv));
}
#endif

