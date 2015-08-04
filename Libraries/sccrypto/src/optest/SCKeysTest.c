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
//  SCKeysTest.c
//  sccrypto
//
//  Created by Vinnie Moscaritolo on 10/24/14.
//
//

#include <stdio.h>
#include <time.h>

#include "SCcrypto.h"
#include "crypto_optest.h"

static char *Msgs[] = {
    "Hello. My name is Inigo Montoya. You killed my father. Prepare to die.",
    " Finish him. Finish him, your way.",
    "Oh good, my way. Thank you Vizzini... what's my way?",
    " Pick up one of those rocks, get behind a boulder, in a few minutes the man in black will come running around the bend, the minute his head is in view, hit it with the rock.",
    "My way's not very sportsman-like. ",
    "Why do you wear a mask? Were you burned by acid, or something like that?",
    " Oh no, it's just that they're terribly comfortable. I think everyone will be wearing them in the future.",
    " I do not envy you the headache you will have when you awake. But for now, rest well and dream of large women.",
    " I just want you to feel you're doing well.",
    "That Vizzini, he can *fuss*." ,
    "Fuss, fuss... I think he like to scream at *us*.",
    "Probably he means no *harm*. ",
    "He's really very short on *charm*." ,
    "You have a great gift for rhyme." ,
    "Yes, yes, some of the time.",
    "Enough of that.",
    "Fezzik, are there rocks ahead? ",
    "If there are, we all be dead. ",
    "No more rhymes now, I mean it. ",
    "Anybody want a peanut?",
    "short",
    "no",
    "",
    NULL
};


static SCLError scSaveRestoreKeyTest(SCKeySuite storageKeySuite, SCKeySuite eccKeySuite )
{
    SCLError        err = kSCLError_NoErr;
  
    SCKeyContextRef sKey = kInvalidSCKeyContextRef;         // storage key
    SCKeyContextRef signKey = kInvalidSCKeyContextRef;
    SCKeyContextRef     pKey = kInvalidSCKeyContextRef;     // pbdkf2 encrypted storage key

    Cipher_Algorithm    algorithm = kCipher_Algorithm_Invalid;
    size_t              symKeyLen = 0;
    
    time_t          startDate  = time(NULL) ;
    time_t          expireDate  = startDate + (3600 * 24);
    char*           user1 = "ed_snowden@silentcircle.com";
 
    uint8_t*        keyData = NULL;
    size_t          keyDataLen = 0;
    
    uint8_t*        sKeyData = NULL;
    size_t          sKeyDataLen = 0;
    bool            isLocked = true;
    
    char*           passPhrase = "Pedicabo ego vos et irrumabo";
    
    
    // used for comparison test
    ECC_ContextRef  ecc  =  kInvalidECC_ContextRef;
    ECC_ContextRef  ecc1  =  kInvalidECC_ContextRef;
    
    OPTESTLogInfo("\tTesting SCKeys %s Save/Restore using %s\n", sckey_suite_table(eccKeySuite),  sckey_suite_table(storageKeySuite));
    
    // setup a storage key for the private SCC key  */
    
    // we do this code just one time and export the encrypted passphrase for later use.
    char*           nonce = "some stupid nonce data";
    uint8_t IV[32];
    err = SCKeyCipherForKeySuite(storageKeySuite, &algorithm, &symKeyLen);  CKERR;
    err = RNG_GetBytes(IV,symKeyLen); CKERR;
    err = SCKeyNew(storageKeySuite, (uint8_t*)nonce, strlen(nonce), &sKey); CKERR;
    err = SCKeySetProperty (sKey, kSCKeyProp_IV, SCKeyPropertyType_Binary,  IV   , symKeyLen ); CKERR;
    err = SCKeyEncryptToPassPhrase(sKey, (const uint8_t*)passPhrase, strlen(passPhrase), &pKey); CKERR;
    err = SCKeySerialize(pKey, &sKeyData, &sKeyDataLen); CKERR;
    OPTESTLogVerbose("\t\tExport storage key (%d bytes)\n", (int)sKeyDataLen );
    OPTESTLogDebug("\t\tEncrypted Storage Key Packet: (%ld bytes)\n%s\n",sKeyDataLen, (char*)sKeyData);
    SCKeyFree(pKey); pKey = NULL;
    
       /* create a signing key for things like voicemail, etc */
    err = SCKeyNew(eccKeySuite, (uint8_t*)nonce, strlen(nonce),  &signKey); CKERR;
    err = SCKeySetProperty (signKey, kSCKeyProp_Owner, SCKeyPropertyType_UTF8String, user1 , strlen(user1) ); CKERR;
    err = SCKeySetProperty(signKey, kSCKeyProp_StartDate,  SCKeyPropertyType_Time ,  &startDate, sizeof(time_t)); CKERR;
    err = SCKeySetProperty(signKey, kSCKeyProp_ExpireDate,  SCKeyPropertyType_Time ,  &expireDate, sizeof(time_t)); CKERR;
  
    // used for testing
    err = SCKeyExport_ECC(signKey, &ecc); CKERR;
 
    /* save the private ecc key */
    err = SCKeySerializePrivateWithSCKey(signKey, sKey, &keyData, &keyDataLen); CKERR;
    OPTESTLogVerbose("\t\tExport ECC key (%d bytes)\n", (int)keyDataLen );
    OPTESTLogDebug("\t\tPrivate Key Packet: (%ld bytes)\n%s\n",keyDataLen, (char*)keyData);
    
    SCKeyFree(sKey);    sKey = NULL;
    SCKeyFree(signKey); signKey = NULL;
 
    // pretend we readin  keyData  and sKeyData from some device..
    
    OPTESTLogVerbose("\t\tReconstitute the storage key \n" );
   // reconstitute the storage key
    err = SCKeyDeserialize(sKeyData,  strlen((char*) sKeyData) , &pKey); CKERR;
    err = SCKeyDecryptFromPassPhrase(pKey, (const uint8_t*)passPhrase, strlen(passPhrase), &sKey); CKERR;
    
   // resconstitute the ECC key
    OPTESTLogVerbose("\t\tReconstitute the ECC key \n" );
    err = SCKeyDeserialize(keyData,  strlen((char*) keyData) , &signKey); CKERR;
 
    OPTESTLogVerbose("\t\tUnlock Private Key Packet \n" );
    err = SCKeyUnlockWithSCKey(signKey, sKey); CKERR;
    err = SCKeyIsLocked(signKey,&isLocked); CKERR;
    ASSERTERR(isLocked, kSCLError_SelfTestFailed);
    
    OPTESTLogVerbose("\t\tConsistency check of reimported key \n" );
    
    {
        uint8_t         pk[128];
        size_t          pkLen = sizeof (pk);
   
        uint8_t         pk1[128];
        size_t          pk1Len = sizeof (pk1);

        uint8_t         privKey[256];
        size_t          privKeyLen = sizeof (privKey);
        
        uint8_t         privKey1[256];
        size_t          privKey1Len = sizeof (privKey1);

        err = SCKeyExport_ECC(signKey, &ecc1); CKERR;
        
        err = ECC_Export_ANSI_X963(ecc , pk, pkLen, &pkLen);
        err = ECC_Export_ANSI_X963(ecc1 , pk1, pk1Len, &pk1Len);
        err = compare2Results(pk, pkLen, pk1, pk1Len, kResultFormat_Byte, "ECC public Key");
  
        err =  ECC_Export(ecc, true, privKey, sizeof(privKey), &privKeyLen);CKERR;
        err =  ECC_Export(ecc1, true, privKey1, sizeof(privKey1), &privKey1Len);CKERR;
        err = compare2Results(privKey, privKeyLen, privKey1, privKey1Len, kResultFormat_Byte, "ECC private Key");
     }
    
   done:
    
    OPTESTLogDebug("\n" );
    
    
    if(ECC_ContextRefIsValid(ecc))
        ECC_Free(ecc);
    
    if(ECC_ContextRefIsValid(ecc1))
        ECC_Free(ecc1);
    
    if(SCKeyContextRefIsValid(pKey))
        SCKeyFree(pKey);
    

    if(SCKeyContextRefIsValid(pKey))
        SCKeyFree(pKey);
   
    
    if(SCKeyContextRefIsValid(signKey))
        SCKeyFree(signKey);

    if(SCKeyContextRefIsValid(sKey))
        SCKeyFree(sKey);
    

    return err;
}



static SCLError sSCKeysStorageTest(SCKeySuite keySuite)
{
    SCLError        err = kSCLError_NoErr;
    SCKeyContextRef storageKey = kInvalidSCKeyContextRef;
    SCKeyContextRef pKey = kInvalidSCKeyContextRef;
    
    const char* passphrase  = "Tant las fotei com auziretz";
    uint8_t* keyData = NULL;
    size_t  keyDataLen = 0;
  
    Cipher_Algorithm    algorithm = kCipher_Algorithm_Invalid;
    size_t              symKeyLen = 0;
   
    int msg_count = ( sizeof(Msgs) / sizeof(char*)) -1;
    
    typedef struct {
        uint8_t 	*data;
        size_t     len;
    }storage_entry;

    storage_entry *msg_store = NULL;
    
    uint8_t    deviceUUID[32];
    uint8_t    IV[32];
    
    OPTESTLogInfo("\tTesting SCKeys Storage API (%s)\n", sckey_suite_table(keySuite));
    
    msg_store = XMALLOC(sizeof(storage_entry) * msg_count);  CKNULL(msg_store);
    ZERO(msg_store,sizeof(storage_entry) * msg_count);
    
    // we use the UUID only as a nonce, it should be unique but doesnt have to be secure
    err =  RNG_GetBytes(deviceUUID,sizeof(deviceUUID));

    // generate a 128 bit storagre key and a 128 bit IV
     err =  RNG_GetBytes(IV,sizeof(IV));
  
    err = SCKeyCipherForKeySuite(keySuite, &algorithm, &symKeyLen);  CKERR;
 
    OPTESTLogVerbose("\t\tCreate %s encyption key\n",cipher_algor_table(algorithm));
    err = SCKeyNew(keySuite, deviceUUID, sizeof(deviceUUID), &storageKey); CKERR;
    err = SCKeySetProperty (storageKey, kSCKeyProp_IV, SCKeyPropertyType_Binary,  IV   , symKeyLen); CKERR;
    
    OPTESTLogVerbose("\t\tEncrypt %d test messages\n", msg_count);
    // Encrypt a bunch of messages
    for(int i = 0; Msgs[i] != NULL; i++)
    {
        unsigned long msgLen;

        msgLen = strlen(Msgs[i]);
        
        OPTESTLogDebug("\t\t  %3d - %3d bytes |%.*s|\n", i+1,  (int)msgLen,(int)msgLen, Msgs[i] );
        err = SCKeyStorageEncrypt(storageKey,
                                  (uint8_t*) Msgs[i], msgLen,
                                  &msg_store[i].data,   &msg_store[i].len); CKERR;
        
        dumpHex(IF_LOG_DEBUG, msg_store[i].data, (int)msg_store[i].len, 0);
        OPTESTLogDebug("\n");
        
    }
    
    OPTESTLogVerbose("\t\tSecure the storage key to a passphrase\n");
    
    // secure the storage key to a passphrase
    err = SCKeyEncryptToPassPhrase(storageKey, (uint8_t*)passphrase, strlen(passphrase), &pKey); CKERR;
    
    // get rid of orignial storage key
    SCKeyFree(storageKey);   storageKey = NULL;
    
    err = SCKeySerialize(pKey, &keyData, &keyDataLen); CKERR;
    SCKeyFree(pKey);   pKey = NULL;
    ZERO(IV,sizeof(IV));
    
    // save the passphrase key somewhere
    OPTESTLogDebug("\t\tPBKDF2 Passphrase Key Packet: (%ld bytes)\n%s\n",keyDataLen, (char*)keyData);
    
    // restore the passphrase key
    err = SCKeyDeserialize(keyData,  keyDataLen, &pKey);CKERR;
    
    // unlock passphrase key and make a SKey
    err = SCKeyDecryptFromPassPhrase(pKey, (uint8_t*)passphrase, strlen(passphrase), &storageKey ); CKERR;
    
    SCKeyFree(pKey); pKey = NULL;
    
    OPTESTLogVerbose("\t\tDecrypt and compare %d messages\n", msg_count);
     for(int i = 0; Msgs[i] != NULL; i++)
    {
        unsigned long msgLen;
        
        uint8_t*    PT = NULL;
        size_t      PTLen = 0;
        
        msgLen = strlen(Msgs[i]);
        
          err = SCKeyStorageDecrypt(storageKey,
                                  msg_store[i].data,   msg_store[i].len,
                                  &PT,    &PTLen); CKERR;
        
        if(msgLen != PTLen)
        {
            OPTESTLogInfo("ERROR  MSG Decrypt: Expecting %d bytes, got %d\n", (int)msgLen, (int)PTLen );
            RETERR(kSCLError_SelfTestFailed);
        }
        
        err = compareResults( Msgs[i],  PT, msgLen , kResultFormat_Byte, "MSG Decrypt"); CKERR;
        
        if(PT) XFREE(PT);
        PT = NULL;
      }
 
     SCKeyFree(storageKey);
    storageKey = NULL;
    
    OPTESTLogVerbose("\n");
done:
    
    for(int i = 0; i < msg_count; i++)
    {
        if(msg_store[i].data )
        {
            XFREE(msg_store[i].data);
        }
        
    }
    
    XFREE(msg_store);
    
    
    if(SCKeyContextRefIsValid(pKey))
        SCKeyFree(pKey);
    
    if(SCKeyContextRefIsValid(storageKey))
        SCKeyFree(storageKey);
 
    
    return err;
    
}

/*
 * ECC Key Save/Restore
 */

static SCLError sSCKeyTest2(SCKeySuite keySuite, SCKeySuite lockingKeySuite)
{
    SCLError        err = kSCLError_NoErr;
    SCKeyContextRef sKey = kInvalidSCKeyContextRef;
    SCKeyContextRef key1 = kInvalidSCKeyContextRef;
    SCKeyContextRef key2 = kInvalidSCKeyContextRef;
    SCKeyContextRef signKey = kInvalidSCKeyContextRef;
    ECC_ContextRef  ecc = kInvalidECC_ContextRef;
    SCKeySuite      keyType;
    SCKeySuite      keyType1;
    SCKeyPropertyType propType;
    
    Cipher_Algorithm    algorithm = kCipher_Algorithm_Invalid;
    size_t              symKeyLen = 0;
    
    uint8_t*        keyData = NULL;
    size_t          keyDataLen = 0;
    uint8_t*        keyData1 = NULL;
    size_t          keyDataLen1 = 0;
    size_t          ecckeysize = 0;
    uint8_t         symKey[32];
    uint8_t         IV[32];
    
    char*           user1 = "user1@silentcircle.com";
    char*           user2 = "user2@silentcircle.com";
    
    char            comment[256] = {0};
    char*           nonce = "some stupid nonce data";
    time_t          startDate  = time(NULL) ;
    time_t          expireDate  = startDate + (3600 * 24);
    time_t          date1;
    char*           commentProperty = "comment";
    bool            isLocked = true;
   
    sprintf(comment,"Optest %s ECC Key", sckey_suite_table(keySuite));
    OPTESTLogInfo("\tTesting %s Key Save/Restore using %s\n",
                  sckey_suite_table(keySuite),sckey_suite_table(lockingKeySuite));
   
    switch (keySuite) {
        case kSCKeySuite_ECC384:
            ecckeysize = 384;
            break;
            
        case kSCKeySuite_ECC414:
            ecckeysize = 414;
            break;
            
        default:
            RETERR(kSCLError_BadParams);
            break;
    }
    
    // fixed SYM key test
    for(int i = 0; i< sizeof(symKey); i++) symKey[i] = i;
    for(int i = 0; i< sizeof(IV); i++) IV[i] = i;

    // create a SCKey with sym data
    err = SCKeyImport_Symmetric(lockingKeySuite, symKey, (uint8_t*)nonce, strlen(nonce), &sKey); CKERR;
    err = SCKeyCipherForKeySuite(lockingKeySuite, &algorithm, &symKeyLen);  CKERR;
    err = SCKeySetProperty (sKey, kSCKeyProp_IV, SCKeyPropertyType_Binary,  IV, symKeyLen ); CKERR;
  
    OPTESTLogVerbose("\t\tGenerate %d bit ECC key \n", ecckeysize);
    err = ECC_Init(&ecc);
    err = ECC_Generate(ecc, ecckeysize); CKERR;
    
    OPTESTLogVerbose("\t\tImport %d bit ECC key to SCKEy \n", ecckeysize);
    err = SCKeyImport_ECC( ecc, (uint8_t*)nonce, strlen(nonce),  &key1); CKERR;
    ECC_Free(ecc );
    ecc = kInvalidECC_ContextRef;
 
    err = SCKeySetProperty (key1, commentProperty, SCKeyPropertyType_UTF8String, comment, strlen(comment) ); CKERR;
    err = SCKeySetProperty(key1, kSCKeyProp_StartDate,  SCKeyPropertyType_Time ,  &startDate, sizeof(time_t)); CKERR;
    err = SCKeySetProperty(key1, kSCKeyProp_ExpireDate,  SCKeyPropertyType_Time ,  &expireDate, sizeof(time_t)); CKERR;
    err = SCKeySetProperty (key1, kSCKeyProp_Owner, SCKeyPropertyType_UTF8String, user1, strlen(user1) ); CKERR;
  
    // create a signing key to sign test wkey with
    err = SCKeyNew(keySuite, (uint8_t*)nonce, strlen(nonce),  &signKey); CKERR;
    err = SCKeySetProperty (signKey, kSCKeyProp_Owner, SCKeyPropertyType_UTF8String, user2 , strlen(user2) ); CKERR;
    err = SCKeySignKey( signKey, key1,NULL); CKERR;
    
    // serialize it
    err = SCKeySerialize(key1, &keyData, &keyDataLen); CKERR;
    OPTESTLogDebug("\t\tPublic Key Packet: (%ld bytes)\n%s\n",keyDataLen, (char*)keyData);
    XFREE(keyData); keyData = NULL;

    err = SCKeySerializePrivateWithSCKey(key1, sKey, &keyData, &keyDataLen); CKERR;
    OPTESTLogDebug("\t\tPrivate Key Packet: (%ld bytes)\n%s\n",keyDataLen, (char*)keyData);
    
    OPTESTLogVerbose("\t\tImport Private Key Packet \n" );
    err = SCKeyDeserialize(keyData,  keyDataLen, &key2);CKERR;
    XFREE(keyData); keyData = NULL;
  
    OPTESTLogVerbose("\t\tUnlock Private Key Packet \n" );
    err = SCKeyIsLocked(key2,&isLocked); CKERR;
     // the freshly iported key should be locked
    ASSERTERR(!isLocked, kSCLError_SelfTestFailed);
    err = SCKeyUnlockWithSCKey(key2, sKey); CKERR;
  
    // check reimport
    OPTESTLogVerbose("\t\tCompare Deserialized Key \n" );
    err = SCKeyGetProperty(key2, kSCKeyProp_SCKeySuite,   NULL,  &keyType1, sizeof(SCKeySuite),  NULL); CKERR;
    err = compareResults(&keyType, &keyType, sizeof(SCKeySuite), kResultFormat_Byte, "keySuite");CKERR;
    
    err = SCKeyGetAllocatedProperty(key1, kSCKeyProp_Locator,NULL,  (void*)&keyData ,  &keyDataLen); CKERR;
    err = SCKeyGetAllocatedProperty(key2, kSCKeyProp_Locator,&propType,  (void*)&keyData1 ,  &keyDataLen1); CKERR;
    ASSERTERR(propType != SCKeyPropertyType_Binary,  kSCLError_SelfTestFailed);
    err = compareResults(keyData, keyData1, keyDataLen, kResultFormat_Byte, "locator");CKERR;
    XFREE(keyData); keyData = NULL;
    XFREE(keyData1); keyData1 = NULL;
    
    err = SCKeyGetProperty(key2, kSCKeyProp_StartDate,   &propType,  &date1, sizeof(time_t),  &keyDataLen); CKERR;
    ASSERTERR(propType != SCKeyPropertyType_Time,  kSCLError_SelfTestFailed);
    err = compareResults(&startDate, &date1, sizeof(time_t), kResultFormat_Byte, "startDate");CKERR;
    
    err = SCKeyGetProperty(key2, kSCKeyProp_ExpireDate,   &propType,  &date1, sizeof(time_t),  &keyDataLen); CKERR;
    ASSERTERR(propType != SCKeyPropertyType_Time,  kSCLError_SelfTestFailed);
    err = compareResults(&expireDate, &date1, sizeof(time_t), kResultFormat_Byte, "expireDate");CKERR;
 
// TODO: we need to add code in SCKeys to xport the key signatures and verify them
    
    OPTESTLogVerbose(" \n" );
    
done:
    if(ECC_ContextRefIsValid(ecc) )
        ECC_Free(ecc );
    
    if(SCKeyContextRefIsValid(key1))
        SCKeyFree(key1);
    
    if(SCKeyContextRefIsValid(key2))
        SCKeyFree(key2);

    if(keyData)
        XFREE(keyData);

    if(keyData1)
        XFREE(keyData1);

    return err;
};

/*
 * Symmetric Key Save/Restore
 */

static SCLError sSCKeyTest1(SCKeySuite keySuite)
{
    SCLError        err = kSCLError_NoErr;
    SCKeyContextRef key = kInvalidSCKeyContextRef;
    SCKeyContextRef key1 = kInvalidSCKeyContextRef;
 
    
    uint8_t     symKey[32];
    uint8_t     symKey1[32];
    uint8_t*    keyData = NULL;
    size_t      keyDataLen = 0;
    uint8_t*    keyData1 = NULL;
    size_t      keyDataLen1 = 0;
    char        comment[256] = {0};
    char        comment1[256] = {0};
 
    char*       nonce = "some stupid nonce data";
    time_t      startDate  = time(NULL) ;
    time_t      expireDate  = startDate + (3600 * 24);
    
    char*       commentProperty = "comment";
    
    SCKeySuite          keyType1 =  kSCKeySuite_Invalid ;
    SCKeyPropertyType propType = SCKeyPropertyType_Invalid;
    
    // fixed SYM key test
    for(int i = 0; i< 32; i++) symKey[i] = i;

    sprintf(comment,"Optest %s Symmetric Key", sckey_suite_table(keySuite));
                 
    OPTESTLogInfo("\tTesting Symmetric Key Save/Restore (%s)\n", sckey_suite_table(keySuite));
    
    // create a SCKey with sym data and add some properties
    err = SCKeyImport_Symmetric(keySuite, symKey, (uint8_t*)nonce, strlen(nonce), &key);
 
    err = SCKeySetProperty (key, commentProperty, SCKeyPropertyType_UTF8String, comment, strlen(comment) ); CKERR;
    err = SCKeySetProperty(key, kSCKeyProp_StartDate,  SCKeyPropertyType_Time ,  &startDate, sizeof(time_t)); CKERR;
    err = SCKeySetProperty(key, kSCKeyProp_ExpireDate,  SCKeyPropertyType_Time ,  &expireDate, sizeof(time_t)); CKERR;
    
    // serialize it
    err = SCKeySerialize(key, &keyData, &keyDataLen); CKERR;
   
    OPTESTLogDebug("\t\tKey Packet: (%ld bytes)\n%s\n",keyDataLen, (char*)keyData);
 
    // deserialize it
    err = SCKeyDeserialize(keyData,  keyDataLen, &key1);CKERR;
    XFREE(keyData); keyData = NULL;
    
    err = SCKeyGetProperty(key1, kSCKeyProp_SCKeySuite,   NULL,  &keyType1, sizeof(SCKeySuite),  NULL); CKERR;
    err = compareResults(&keySuite, &keyType1, sizeof(SCKeySuite), kResultFormat_Byte, "keySuite");CKERR;
    
    err = SCKeyGetProperty(key1, kSCKeyProp_SymmetricKey, NULL, &symKey1 , sizeof(symKey1), &keyDataLen); CKERR;
    err = compareResults(symKey, symKey1, keyDataLen, kResultFormat_Byte, "symKey");CKERR;
    
    XFREE(keyData); keyData = NULL;
    
    err = SCKeyGetAllocatedProperty(key, kSCKeyProp_Locator, NULL,  (void*)&keyData ,  &keyDataLen); CKERR;
    err = SCKeyGetAllocatedProperty(key1, kSCKeyProp_Locator, &propType,  (void*)&keyData1 ,  &keyDataLen1); CKERR;
    err = compareResults(keyData, keyData1, keyDataLen, kResultFormat_Byte, "locator");CKERR;

    err = SCKeyGetProperty(key1, commentProperty, &propType,  comment1 , sizeof(comment1),  &keyDataLen1); CKERR;
    err = compare2Results(comment, strlen(comment), comment1, keyDataLen1, kResultFormat_Byte, "comment");CKERR;

    if(keyData) XFREE(keyData);
    if(keyData1) XFREE(keyData1);
    if(key) SCKeyFree(key);
    if(key1) SCKeyFree(key1);
    
    
done:
    
    return err;

}

static SCLError sSCKeyTest3(SCKeySuite keySuite)
{
    SCLError        err = kSCLError_NoErr;
    SCKeyContextRef key1 = kInvalidSCKeyContextRef;
    char*           nonce = "some stupid nonce data";
 
//    Cipher_Algorithm    algorithm = kCipher_Algorithm_Invalid;
//    size_t              symKeyLen = 0;
  
#define PTsize 32
    uint8_t        PT[PTsize];
    
    uint8_t        CT[256];
    size_t         CTlen = 0;
    
    uint8_t        DT[PTsize];
    size_t         DTlen = 0;
 
    uint8_t*    sigData = NULL;
    size_t      sigDataLen = 0;
//    uint8_t*    keyData = NULL;
//    size_t      keyDataLen = 0;

//    time_t      startDate  = time(NULL) ;
//    time_t      expireDate  = startDate + (3600 * 24);

    // fixed PT key test
    for(int i = 0; i< PTsize; i++) PT[i] = i;
    
    OPTESTLogInfo("\tTesting %s Signing and Encryption Consistency \n", sckey_suite_table(keySuite));

//    err = SCKeyCipherForKeySuite(keySuite, &algorithm, NULL);  CKERR;
//    OPTESTLogVerbose("\t\tCreate %s encyption key\n",cipher_algor_table(algorithm));

    err = SCKeyNew(keySuite, (uint8_t*)nonce, strlen(nonce),  &key1); CKERR;
    
    OPTESTLogVerbose("\t\tPublic Key Encrypt %d byte key \n", sizeof(PT));
    err = SCKeyPublicEncrypt(key1, PT, sizeof(PT),  CT, sizeof(CT), &CTlen);CKERR;
    dumpHex(IF_LOG_DEBUG, CT, (int)CTlen, 0);
    
    OPTESTLogVerbose("\t\tTest Decryption \n");
   err = SCKeyPublicDecrypt(key1, CT, CTlen,  DT, sizeof(DT), &DTlen); CKERR;
    err = compareResults( DT, PT, PTsize , kResultFormat_Byte, "ECC Decrypt"); CKERR;
    
    err = SCKeySignHash(key1, PT,sizeof(PT),CT, sizeof(CT), &CTlen); CKERR;
    OPTESTLogVerbose("\t\tPublic Key Sign - low level (%ld bytes) \n", CTlen);
    dumpHex(IF_LOG_DEBUG, CT, (int)CTlen, 0);
    
    err = SCKeySign(key1,PT,sizeof(PT), &sigData, &sigDataLen); CKERR;
    OPTESTLogVerbose("\t\tPublic Key Sign - JSON  (%ld bytes) \n",sigDataLen);
    OPTESTLogDebug("%s",sigData );
  
    OPTESTLogVerbose("\t\tTest Signature Verification\n");
    err = SCKeyVerifyHash(key1,  PT,sizeof(PT), CT, CTlen);  CKERR;
    err = SCKeyVerify(key1, PT,sizeof(PT), sigData, sigDataLen); CKERR;
    // force sig fail
    PT[3] ^=1;
    ASSERTERR(SCKeyVerifyHash(key1,  PT,sizeof(PT), CT, CTlen) != kSCLError_BadIntegrity, kSCLError_SelfTestFailed );
    ASSERTERR(SCKeyVerify(key1, PT,sizeof(PT), sigData, sigDataLen) != kSCLError_BadIntegrity, kSCLError_SelfTestFailed );
    
    
#if 0  
    {
    // get pub key
        SCKeyContextRef iKey = kInvalidSCKeyContextRef;
        err = SCKeyGetAllocatedProperty(key1, kSCKeyProp_PubKeyANSI_X963, NULL,  (void*)&keyData ,  &keyDataLen); CKERR;
    
    // make commit code
        err = SCKeyMakeHMACcode(keySuite, keyData, keyDataLen, PT, PTsize, expireDate,  key1, &iKey); CKERR;
     
        XFREE(keyData); keyData = NULL;
        
        err = SCKeySerialize(iKey, &keyData, &keyDataLen); CKERR;
        printf("HMAC_code: (%ld bytes)\n%s\n",keyDataLen, (char*)keyData);
        SCKeyFree(iKey); iKey = NULL;
        err = SCKeyDeserialize(keyData,  keyDataLen, &iKey);CKERR;
        XFREE(keyData); keyData = NULL;
        

    }
#endif

   OPTESTLogVerbose("\n");

    SCKeyFree(key1);   key1 = NULL;
    
done:
    if(SCKeyContextRefIsValid(key1))
        SCKeyFree(key1);
    
    if(sigData)
        XFREE(sigData);
//    
//    if(keyData)
//        XFREE(keyData);
   
    return err;
    
}

static SCLError sSCKeyTest4(SCKeySuite keySuite)
{
    SCLError        err = kSCLError_NoErr;
    SCKeyContextRef key1 = kInvalidSCKeyContextRef;
    char*           nonce = "some stupid nonce data";
    char*           user1 = "ed_snowden@silentcircle.com";
    
    uint8_t*        fingerPrintData = NULL;
    size_t          fingerPrintDataSize = 0;
    
    uint8_t*        locator = NULL;
    uint8_t*        fp = NULL;
 
    uint8_t*        ownerData = NULL;
    size_t          ownerDataSize = 0;

    uint8_t*        hashWords = NULL;
    size_t          hashWordsSize = 0;

    OPTESTLogInfo("\tTesting %s Key Fingerprint APIs \n", sckey_suite_table(keySuite));
    
    err = SCKeyNew(keySuite, (uint8_t*)nonce, strlen(nonce),  &key1); CKERR;
    err = SCKeySetProperty (key1, kSCKeyProp_Owner, SCKeyPropertyType_UTF8String, user1 , strlen(user1) ); CKERR;
   
    err = SCKeySerialize_Fingerprint(key1, &fingerPrintData, &fingerPrintDataSize); CKERR;
    
    OPTESTLogDebug("\n\t%3d bytes\n", (int)fingerPrintDataSize);
     dumpHex(IF_LOG_DEBUG, fingerPrintData, (int)fingerPrintDataSize, 0);
    OPTESTLogDebug("\n");
    
    err =  SCKeyDeserialize_Fingerprint( fingerPrintData, fingerPrintDataSize, &locator, &fp,
                                        &ownerData, &ownerDataSize,
                                        &hashWords, &hashWordsSize);
    
    OPTESTLogDebug("\t%10s: %s\n\t%10s: %s\n\t%10s: %s\n\t%10s: %s\n",
                   "Locator",locator,
                   "Hash",fp,
                   "Hash Words", hashWords,
                   "Owner", ownerData? (char*)ownerData:"<none>");
 
   // test key fingerprint reassembly
    err = SCKeyVerify_Fingerprint(key1, fingerPrintData, fingerPrintDataSize); CKERR;
    
    OPTESTLogVerbose("\n");
    
    SCKeyFree(key1);   key1 = NULL;
    
done:
    if(SCKeyContextRefIsValid(key1))
        SCKeyFree(key1);
    
    if(hashWords)
        XFREE(hashWords);

    if(ownerData)
        XFREE(ownerData);
    
    if(fp)
      XFREE(fp);
  
    if(locator)
        XFREE(locator);
    
      return err;
    
}


SCLError TestSCKeys()
{
    SCLError     err = kSCLError_NoErr;

    err = scSaveRestoreKeyTest(kSCKeySuite_AES128, kSCKeySuite_ECC384); CKERR;
    err = scSaveRestoreKeyTest(kSCKeySuite_AES256, kSCKeySuite_ECC384); CKERR;
    err = scSaveRestoreKeyTest(kSCKeySuite_2FISH256, kSCKeySuite_ECC384); CKERR;
    err = scSaveRestoreKeyTest(kSCKeySuite_AES128, kSCKeySuite_ECC414); CKERR;
    err = scSaveRestoreKeyTest(kSCKeySuite_AES256, kSCKeySuite_ECC414); CKERR;
    err = scSaveRestoreKeyTest(kSCKeySuite_2FISH256, kSCKeySuite_ECC414); CKERR;
    
    err = sSCKeyTest1(kSCKeySuite_AES128); CKERR;
    err = sSCKeyTest1(kSCKeySuite_AES256); CKERR;
    err = sSCKeyTest1(kSCKeySuite_2FISH256); CKERR;
    
    err = sSCKeyTest2(kSCKeySuite_ECC384, kSCKeySuite_AES128 ); CKERR;
    err = sSCKeyTest2(kSCKeySuite_ECC384, kSCKeySuite_AES256 ); CKERR;
    err = sSCKeyTest2(kSCKeySuite_ECC384, kSCKeySuite_2FISH256 ); CKERR;
    err = sSCKeyTest2(kSCKeySuite_ECC414, kSCKeySuite_AES128 ); CKERR;
    err = sSCKeyTest2(kSCKeySuite_ECC414, kSCKeySuite_AES256 ); CKERR;
    err = sSCKeyTest2(kSCKeySuite_ECC414, kSCKeySuite_2FISH256 ); CKERR;
    
    err = sSCKeyTest3(kSCKeySuite_ECC384); CKERR;
    err = sSCKeyTest3(kSCKeySuite_ECC414); CKERR;
      
    err = sSCKeyTest4(kSCKeySuite_ECC384); CKERR;
    err = sSCKeyTest4(kSCKeySuite_ECC414); CKERR;
    
    err = sSCKeysStorageTest(kSCKeySuite_AES128); CKERR;
    err = sSCKeysStorageTest(kSCKeySuite_AES256); CKERR;
    err = sSCKeysStorageTest(kSCKeySuite_2FISH256); CKERR;
    
     
done:
    return err;

};
