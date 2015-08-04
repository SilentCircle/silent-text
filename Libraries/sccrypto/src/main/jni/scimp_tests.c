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
#include <jni.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
//#include <unistd.h>
#include <SCimp.h>
#include "scimp_tests.h"
#include "scimp_packet.h"
#include "scimp_keys.h"
#include "message_queue.h"
#include "uint8_t_array.h"

#define SC_KEY_DEFAULT_EXPIRE_AFTER ( 60 * 60 * 24 )

#if defined(ANDROID)
#include <android/log.h>
#define XPRINTF( tag, format, ... ) __android_log_print( ANDROID_LOG_DEBUG, tag, format, __VA_ARGS__ );
#else
#define XPRINTF( tag, format, ... ) fprintf( stderr, format, __VA_ARGS__ );
#endif

OfflineMessageQueue *_offlineQ;
SCKeyContextRef sEventHandlerTestKey = kInvalidSCKeyContextRef;

SCLError sendBanter(SCimpPacket **initiatorP, SCimpPacket **responderP
		, bool bRandomizeMessages, bool bRandomizeSaveRestore, bool bRandomizeConnect);

SCLError _checkIncomingPackets( SCimpPacket *initiator, SCimpPacket *responder);
SCLError _checkIncomingPacketsOneWay( SCimpPacket *initiator, SCimpPacket *responder);
SCLError _checkQueue(SCimpPacket *packet, OfflineMessageQueue *q);
SCLError _verifySecureConnection( SCimpPacket *initiator, SCimpPacket *responder);
SCLError _testSaveRestorePacket(SCimpPacket *packetIn, SCimpPacket **packetOut);


void printPacketInfo( const char *tag, SCimpPacket *packet );

extern SCLError SCimpPacketEventHandler( SCimpContextRef context, SCimpEvent *event, void *misc );
static SCLError SCimpTestsEventHandler( SCimpContextRef context, SCimpEvent *event, void *misc );

SCLError runSCimpTest(SCLError (*TestMethod)(SCimpPacket **, SCimpPacket **), char *localUserID, char *remoteUserID) {
	// TODO: fill/init storage keys
	uint8_t_array *iStorageKey = uint8_t_array_allocate(64);
	if (iStorageKey == NULL)
		return kSCLError_OutOfMemory;

	uint8_t_array *rStorageKey = uint8_t_array_allocate(64);
	if (rStorageKey == NULL) {
		uint8_t_array_free(iStorageKey);
		return kSCLError_OutOfMemory;
	}

	SCimpPacket *initiator = SCimpPacket_create( iStorageKey, localUserID, remoteUserID );
	SCimpPacket *responder = SCimpPacket_create( rStorageKey, remoteUserID, localUserID );

	SCLError err;
	if ( (initiator != NULL) && (responder != NULL) ) {
		// override default event handler with ours
		SCimpSetEventHandler( initiator->scimp, SCimpTestsEventHandler, (void*) initiator );
		SCimpSetEventHandler( responder->scimp, SCimpTestsEventHandler, (void*) responder );

		err = (*TestMethod)(&initiator, &responder);
	} else
		err = kSCLError_OutOfMemory;

	SCimpPacket_free(initiator); // Note: this also frees iStorageKey
	SCimpPacket_free(responder); // Note: this also frees rStorageKey

	return err;
}

SCLError runAllSCimpTests(char *localUserID, char *remoteUserID) {
	srand (time(NULL)); // seed random number generator

	SCLError err;

	err = runSCimpTest(TestSCimpKeySerializer, localUserID, remoteUserID); CKERR;

	err = runSCimpTest(TestSCimpPKCommunication, localUserID, remoteUserID); CKERR;

	err = runSCimpTest(TestSCimpPKSaveRestore, localUserID, remoteUserID); CKERR;

	err = runSCimpTest(TestSCimpPKContention, localUserID, remoteUserID); CKERR;

	err = runSCimpTest(TestSCimpOfflinePKCommunication, localUserID, remoteUserID); CKERR;

	err = runSCimpTest(TestSCimpPKExpiration, localUserID, remoteUserID); CKERR;

	err = runSCimpTest(TestSCimpSimultaneousPKCommunication, localUserID, remoteUserID); CKERR;

	err = runSCimpTest(TestSCimpDHCommunication, localUserID, remoteUserID); CKERR;

	err = runSCimpTest(TestSCimpDHSimultaneousCommunication, localUserID, remoteUserID); CKERR;

	err = runSCimpTest(TestSCimpDHRekey, localUserID, remoteUserID); CKERR;

	done:
		return err;
}

// JNI-interface
char testLocalUserID[1024] = "alice";//@silentcircle.com";
char testRemoteUserID[1024] = "bob";//@silentcircle.com";

JNIEXPORT jobject JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpSync( JNIEnv *jni, jobject this) {
	uint8_t_array *storageKey = uint8_t_array_allocate(64);
	if (storageKey == NULL)
		return NULL;

	jbyteArray jStorageKey = (*jni)->NewByteArray(jni, storageKey->size);
	(*jni)->SetByteArrayRegion(jni, jStorageKey, 0, storageKey->size, storageKey->items);

	jstring jLocalUserID = (*jni)->NewStringUTF(jni, testLocalUserID);
	jstring jRemoteUserID = (*jni)->NewStringUTF(jni, testRemoteUserID);

	// test startDH
	jobject resultObj = (jobject)Java_com_silentcircle_scimp_NativePacket_startDHSync( jni, this, jStorageKey, jLocalUserID, jRemoteUserID, NULL);
// test restoring context
	jclass classResultBlock = (*jni)->FindClass(jni, "com/silentcircle/scimp/SCimpResultBlock");
	jfieldID contextFID = (*jni)->GetFieldID(jni, classResultBlock, "context", "[B");
	jbyteArray jContext = (*jni)->GetObjectField(jni, resultObj, contextFID);

//	int contextSize = (*jni)->GetArrayLength(jni, jContext);
//	XPRINTF("SCIMP-JNI", "Resultant context is %d bytes", contextSize);

//resultObj = (jobject)Java_com_silentcircle_scimp_NativePacket_startDHSync( jni, this, jStorageKey, jLocalUserID, jRemoteUserID, jContext);

	// test sendMessage
	char *message = "Hello World!";
	jbyteArray jMessage = (*jni)->NewByteArray(jni, strlen(message));
	(*jni)->SetByteArrayRegion(jni, jMessage, 0, strlen(message), message);

	resultObj = (jobject)Java_com_silentcircle_scimp_NativePacket_sendMessageSync( jni, this, jStorageKey, jLocalUserID, jRemoteUserID, jMessage, jContext);
	(*jni)->DeleteLocalRef(jni, jMessage);

	(*jni)->DeleteLocalRef(jni, jStorageKey);
	(*jni)->DeleteLocalRef(jni, jLocalUserID);
	(*jni)->DeleteLocalRef(jni, jRemoteUserID);

	uint8_t_array_free(storageKey);
	return resultObj;
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpKeySerializer( JNIEnv *jni, jobject this) {
	  return runSCimpTest(TestSCimpKeySerializer, testLocalUserID, testRemoteUserID);
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpPKCommunication( JNIEnv *jni, jobject this) {
	  return runSCimpTest(TestSCimpPKCommunication, testLocalUserID, testRemoteUserID);
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpPKSaveRestore( JNIEnv *jni, jobject this) {
	  return runSCimpTest(TestSCimpPKSaveRestore, testLocalUserID, testRemoteUserID);
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpPKContention( JNIEnv *jni, jobject this) {
	  return runSCimpTest(TestSCimpPKContention, testLocalUserID, testRemoteUserID);
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpOfflinePKCommunication( JNIEnv *jni, jobject this) {
	  return runSCimpTest(TestSCimpOfflinePKCommunication, testLocalUserID, testRemoteUserID);
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpPKExpiration( JNIEnv *jni, jobject this) {
	  return runSCimpTest(TestSCimpPKExpiration, testLocalUserID, testRemoteUserID);
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpSimultaneousPKCommunication( JNIEnv *jni, jobject this) {
	  return runSCimpTest(TestSCimpSimultaneousPKCommunication, testLocalUserID, testRemoteUserID);
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpDHCommunication( JNIEnv *jni, jobject this) {
	  return runSCimpTest(TestSCimpDHCommunication, testLocalUserID, testRemoteUserID);
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpDHSimultaneousCommunication( JNIEnv *jni, jobject this) {
	  return runSCimpTest(TestSCimpDHSimultaneousCommunication, testLocalUserID, testRemoteUserID);
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpDHRekey( JNIEnv *jni, jobject this) {
	  return runSCimpTest(TestSCimpDHRekey, testLocalUserID, testRemoteUserID);
}

static SCLError SCimpTestsEventHandler( SCimpContextRef context, SCimpEvent *event, void *misc ) {
	SCimpPacket *packet = misc;
	switch (event->type) {
		case kSCimpEvent_SendPacket:
			if (_offlineQ != NULL) {
				// check if we have queued up data
			    if (packet->outgoingData != NULL) {
			    	uint8_t_array *queuedData = uint8_t_array_copy(packet->outgoingData->items, packet->outgoingData->size);
			    	pushQ(_offlineQ, queuedData);
			    }
			}
			break;
	    case kSCimpEvent_NeedsPrivKey: {
            SCLError err = kSCLError_KeyNotFound;
	    	if (packet->getPrivateKey == NULL) {
	            if(SCKeyContextRefIsValid(sEventHandlerTestKey)) {
	                SCKeySuite keyType1;
	                err = SCKeyGetProperty(sEventHandlerTestKey, kSCKeyProp_SCKeySuite,   NULL,  &keyType1, sizeof(SCKeySuite),  NULL);
	                SCimpEventNeedsPrivKeyData data = event->data.needsKeyData;
	                if(keyType1 == data.expectingKeySuite) {
	                	*data.privKey = sEventHandlerTestKey;
	                    err = kSCLError_NoErr;
	                }
	            }
	            packet->error = err;
	    	}
	    	break;
	    }
	    default:
	    	break;
	}
	if (packet->error != kSCLError_NoErr)
		return packet->error; // already has an error!

	// call the default handler
	SCLError err = SCimpPacketEventHandler( context, event, misc );
	return err;
}

SCLError sendTestPacket( SCimpPacket *initiator, SCimpPacket *responder, char *data, bool bCheckIncomingPackets ) {
  uint8_t_array *packetData = uint8_t_array_parse(data);
  SCLError err = SCimpPacket_sendPacket( initiator, packetData );
  uint8_t_array_free(packetData);
  if ( (!bCheckIncomingPackets) || (err != kSCLError_NoErr) )
	  return err;

  return _checkIncomingPackets(initiator, responder);
}

SCLError sendOfflinePacket( SCimpPacket *initiator, OfflineMessageQueue *q, char *data ) {
  _offlineQ = q;
  uint8_t_array *packetData = uint8_t_array_parse(data);
  SCLError err = SCimpPacket_sendPacket( initiator, packetData ); CKERR;
  uint8_t_array_free(packetData);

  uint8_t_array *queuedData = uint8_t_array_copy(initiator->outgoingData->items, initiator->outgoingData->size);
  pushQ(q, queuedData);

  uint8_t_array_free( initiator->outgoingData );
  initiator->outgoingData = NULL;

  done:
  	  _offlineQ = NULL;
  	  return err;
}

static char *banter[] = {
	"Hello. My name is Inigo Montoya. You killed my father. Prepare to die.",
    "Finish him. Finish him, your way.",
    "Oh good, my way. Thank you Vizzini... what's my way?",
    "Pick up one of those rocks, get behind a boulder, in a few minutes the man in black will come running around the bend, the minute his head is in view, hit it with the rock.",
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

SCLError testKeyDeserialization( uint8_t_array *keyIn ) {
  SCKeyContextRef key = kInvalidSCKeyContextRef;
  SCLError err = SCKeyDeserialize( keyIn->items, keyIn->size, &key ); CKERR;
  done:
  	  SCKeyFree( key );
  	  return err;
}

SCLError TestSCimpKeySerializer(SCimpPacket **initiator, SCimpPacket **responder) {
	SCimpPacket *alice = *initiator;
	SCimpPacket *bob = *responder;

	SCKeyContextRef alicePrivateKey = NULL;
	SCKeyContextRef bobPrivateKey = NULL;
	SCLError err = kSCLError_NoErr;

	// generate private keys for alice & bob
	err = SCimp_generatePrivateKey( &alicePrivateKey, alice->localUserID, SC_KEY_DEFAULT_EXPIRE_AFTER ); CKERR;
	err = SCimp_generatePrivateKey( &bobPrivateKey, bob->localUserID, SC_KEY_DEFAULT_EXPIRE_AFTER ); CKERR;

	// test exporting public keys
	uint8_t_array *alicePublicKeySerialized = uint8_t_array_init();
	uint8_t_array *bobPublicKeySerialized = uint8_t_array_init();
	err = SCimp_exportPublicKey( alicePrivateKey, alicePublicKeySerialized ); CKERR;
	err = SCimp_exportPublicKey( bobPrivateKey, bobPublicKeySerialized ); CKERR;

	// test importing public keys
	err = testKeyDeserialization( alicePublicKeySerialized ); CKERR;
	err = testKeyDeserialization( bobPublicKeySerialized ); CKERR;

	// test exporting private keys
	uint8_t_array *alicePrivateKeySerialized = uint8_t_array_init();
	uint8_t_array *bobPrivateKeySerialized = uint8_t_array_init();

	err = SCimp_exportPrivateKey( alicePrivateKey, alice->storageKey, alicePrivateKeySerialized ); CKERR;
	err = SCimp_exportPrivateKey( bobPrivateKey, bob->storageKey, bobPrivateKeySerialized ); CKERR;

	err = SCimpPacket_setPrivateKey( alice, alicePrivateKeySerialized, alice->storageKey ); CKERR;
	err = SCimpPacket_setPrivateKey( bob, bobPrivateKeySerialized, bob->storageKey ); CKERR;

	// clean-up
	SCKeyFree(alicePrivateKey);
	uint8_t_array_free(alicePrivateKeySerialized);
	uint8_t_array_free(alicePublicKeySerialized);

	SCKeyFree(bobPrivateKey);
	uint8_t_array_free(bobPrivateKeySerialized);
	uint8_t_array_free(bobPublicKeySerialized);
done:
	if (err != kSCLError_NoErr) {
		printPacketInfo( "initiator", alice );
		printPacketInfo( "responder", bob );
		printf("Test Failed with error %d.\n", err);
	} else
		printf("Test Successful.\n");
	return err;
}

SCLError TestSCimpPKCommunication(SCimpPacket **initiator, SCimpPacket **responder) {
	SCimpPacket *alice = *initiator;
	SCimpPacket *bob = *responder;

	// to test PK communication, we:
	// 1. generate and set a private/public key for alice
	// 2. generate a private/public key for bob
	// 3. pass bob's public key to alice

	// two flavors:
	// a. set bob's private key now
	// b. set bob's private key later, in event handler (to test NeedsPrivKey event)

	bool bTestCipherMismatch = true;
	SCKeyContextRef alicePrivateKey = NULL;
	SCKeyContextRef bobPrivateKey = NULL;
	//  SCKeyContextRef bobPublicKey = NULL;

	SCLError err = kSCLError_NoErr;
	err = SCimp_generatePrivateKeyWithSize( &alicePrivateKey, alice->localUserID, SC_KEY_DEFAULT_EXPIRE_AFTER, 384 ); CKERR;
	size_t bobCipherKeySize = (bTestCipherMismatch) ? 414 : 384;
	err = SCimp_generatePrivateKeyWithSize( &bobPrivateKey, bob->localUserID, SC_KEY_DEFAULT_EXPIRE_AFTER, bobCipherKeySize ); CKERR;

	uint8_t_array *alicePrivateKeySerialized = uint8_t_array_init();
	//  uint8_t_array *alicePublicKeySerialized = uint8_t_array_init();
	uint8_t_array *bobPublicKeySerialized = uint8_t_array_init();

	err = SCimp_exportPrivateKey( alicePrivateKey, alice->storageKey, alicePrivateKeySerialized ); CKERR;
	err = SCimpPacket_setPrivateKey( alice, alicePrivateKeySerialized, alice->storageKey ); CKERR;

	// optional: set a shared secret
	uint8_t secret[64];
	sprng_read(secret,sizeof(secret),NULL);
	err = SCimpSetDataProperty(alice->scimp, kSCimpProperty_SharedSecret,  secret, sizeof(secret)); CKERR;
	err = SCimpSetDataProperty(bob->scimp, kSCimpProperty_SharedSecret,  secret, sizeof(secret)); CKERR;

	// two ways to set Bob's private key
	// one way is to do it right now
	// the other way is to have it set in the handler, using a test global variable
	if (1) {
		// set Bob's private key
		uint8_t_array *bobPrivateKeySerialized = uint8_t_array_init();
		err = SCimp_exportPrivateKey( bobPrivateKey, bob->storageKey, bobPrivateKeySerialized ); CKERR;
		err = SCimpPacket_setPrivateKey( bob, bobPrivateKeySerialized, bob->storageKey ); CKERR;
		uint8_t_array_free(bobPrivateKeySerialized);
	} else {
		sEventHandlerTestKey = bobPrivateKey;
	}

	// pass bob's public key to alice
	err = SCimp_exportPublicKey( bobPrivateKey, bobPublicKeySerialized ); CKERR;
	err = SCimpPacket_setPublicKey( alice, bobPublicKeySerialized ); CKERR;

	// clean-up keys
	SCKeyFree(alicePrivateKey);
	uint8_t_array_free(alicePrivateKeySerialized);

	SCKeyFree(bobPrivateKey);
	uint8_t_array_free(bobPublicKeySerialized);

	// test back-and-forth banter
	printf("Testing dialog.\n");

	err = sendBanter(&alice, &bob, false, true, true); CKERR;

	// test save/restore packets
	printf("Testing save/restore state.\n");
	SCimpPacket *aliceRestored = NULL, *bobRestored = NULL;
	err = _testSaveRestorePacket(alice, &aliceRestored); CKERR;
	alice = aliceRestored;
	err = _testSaveRestorePacket(bob, &bobRestored); CKERR;
	bob = bobRestored;

	// test back-and-forth banter after save/restore
	err = _verifySecureConnection(alice, bob); CKERR;

	printf("Testing dialog.\n");
	err = sendBanter(&alice, &bob, false, true, false); CKERR;

  	done:
		if (err != kSCLError_NoErr) {
			  printPacketInfo( "initiator", alice );
			  printPacketInfo( "responder", bob );
			  printf("Test Failed with error %d.\n", err);
		} else
			printf("Test Successful.\n");

	*initiator = alice;
	*responder = bob;
	return err;
}

SCLError TestSCimpPKSaveRestore(SCimpPacket **initiator, SCimpPacket **responder) {
	SCimpPacket *alice = *initiator;
	SCimpPacket *bob = *responder;
	SCKeyContextRef alicePrivateKey = NULL;
	SCKeyContextRef bobPrivateKey = NULL;

	SCLError err = kSCLError_NoErr;
	err = SCimp_generatePrivateKeyWithSize( &alicePrivateKey, alice->localUserID, SC_KEY_DEFAULT_EXPIRE_AFTER, 414 ); CKERR;
	err = SCimp_generatePrivateKeyWithSize( &bobPrivateKey, bob->localUserID, SC_KEY_DEFAULT_EXPIRE_AFTER, 414 ); CKERR;

	uint8_t_array *alicePrivateKeySerialized = uint8_t_array_init();
	uint8_t_array *bobPublicKeySerialized = uint8_t_array_init();

	err = SCimp_exportPrivateKey( alicePrivateKey, alice->storageKey, alicePrivateKeySerialized ); CKERR;
	err = SCimpPacket_setPrivateKey( alice, alicePrivateKeySerialized, alice->storageKey ); CKERR;

	// optional: set a shared secret
	uint8_t secret[64];
	sprng_read(secret,sizeof(secret),NULL);
	err = SCimpSetDataProperty(alice->scimp, kSCimpProperty_SharedSecret,  secret, sizeof(secret)); CKERR;
	err = SCimpSetDataProperty(bob->scimp, kSCimpProperty_SharedSecret,  secret, sizeof(secret)); CKERR;

	// set Bob's private key
	uint8_t_array *bobPrivateKeySerialized = uint8_t_array_init();
	err = SCimp_exportPrivateKey( bobPrivateKey, bob->storageKey, bobPrivateKeySerialized ); CKERR;
	err = SCimpPacket_setPrivateKey( bob, bobPrivateKeySerialized, bob->storageKey ); CKERR;

	// pass bob's public key to alice
	err = SCimp_exportPublicKey( bobPrivateKey, bobPublicKeySerialized ); CKERR;
	err = SCimpPacket_setPublicKey( alice, bobPublicKeySerialized ); CKERR;

	// clean-up keys
	SCKeyFree(alicePrivateKey);
	uint8_t_array_free(alicePrivateKeySerialized);

	SCKeyFree(bobPrivateKey);
	uint8_t_array_free(bobPrivateKeySerialized);
	uint8_t_array_free(bobPublicKeySerialized);

	// test back-and-forth banter
	printf("Testing dialog.\n");

	int count = 0;
	while (count < 5) {
		int i;
		for (i = 0; banter[i] != NULL; i++) {
			err = sendTestPacket( alice, bob, banter[i], true); CKERR;
			// test save/restore packets
			printf("Testing save/restore state.\n");
			SCimpPacket *aliceRestored = NULL, *bobRestored = NULL;
			err = _testSaveRestorePacket(alice, &aliceRestored); CKERR;
			alice = aliceRestored;
			err = _testSaveRestorePacket(bob, &bobRestored); CKERR;
			bob = bobRestored;
		}
		count++;
	}

  	done:
		if (err != kSCLError_NoErr) {
			  printPacketInfo( "initiator", alice );
			  printPacketInfo( "responder", bob );
			  printf("Test Failed with error %d.\n", err);
		} else
			printf("Test Successful.\n");

	*initiator = alice;
	*responder = bob;

	return err;
}

SCLError TestSCimpPKContention(SCimpPacket **initiator, SCimpPacket **responder) {
	SCimpPacket *alice = *initiator;
	SCimpPacket *bob = *responder;
	SCKeyContextRef alicePrivateKey = NULL;
	SCKeyContextRef bobPrivateKey = NULL;
	bool bTestCipherMismatch = true;

	SCLError err = kSCLError_NoErr;
	err = SCimp_generatePrivateKeyWithSize( &alicePrivateKey, alice->localUserID, SC_KEY_DEFAULT_EXPIRE_AFTER, 384 ); CKERR;
	size_t bobCipherKeySize = (bTestCipherMismatch) ? 414 : 384;
	err = SCimp_generatePrivateKeyWithSize( &bobPrivateKey, bob->localUserID, SC_KEY_DEFAULT_EXPIRE_AFTER, bobCipherKeySize ); CKERR;

	uint8_t_array *alicePrivateKeySerialized = uint8_t_array_init();
	uint8_t_array *bobPublicKeySerialized = uint8_t_array_init();

	err = SCimp_exportPrivateKey( alicePrivateKey, alice->storageKey, alicePrivateKeySerialized ); CKERR;
	err = SCimpPacket_setPrivateKey( alice, alicePrivateKeySerialized, alice->storageKey ); CKERR;
	uint8_t_array_free(alicePrivateKeySerialized);
	SCKeyFree(alicePrivateKey);
	alicePrivateKey = NULL;

	// optional: set a shared secret
	uint8_t secret[64];
	sprng_read(secret,sizeof(secret),NULL);
	err = SCimpSetDataProperty(alice->scimp, kSCimpProperty_SharedSecret,  secret, sizeof(secret)); CKERR;
	err = SCimpSetDataProperty(bob->scimp, kSCimpProperty_SharedSecret,  secret, sizeof(secret)); CKERR;

	// set Bob's private key
	uint8_t_array *bobPrivateKeySerialized = uint8_t_array_init();
	err = SCimp_exportPrivateKey( bobPrivateKey, bob->storageKey, bobPrivateKeySerialized ); CKERR;
	err = SCimpPacket_setPrivateKey( bob, bobPrivateKeySerialized, bob->storageKey ); CKERR;
	uint8_t_array_free(bobPrivateKeySerialized);

	// pass bob's original public key to alice
	err = SCimp_exportPublicKey( bobPrivateKey, bobPublicKeySerialized ); CKERR;
	err = SCimpPacket_setPublicKey( alice, bobPublicKeySerialized ); CKERR;
	uint8_t_array_free(bobPublicKeySerialized);

	// bob gets a new public/private key
	SCKeyFree(bobPrivateKey);
	bobPrivateKey = NULL;
	err = SCimp_generatePrivateKeyWithSize( &bobPrivateKey, bob->localUserID, SC_KEY_DEFAULT_EXPIRE_AFTER, bobCipherKeySize ); CKERR;

	bobPrivateKeySerialized = uint8_t_array_init();
	err = SCimp_exportPrivateKey( bobPrivateKey, bob->storageKey, bobPrivateKeySerialized ); CKERR;
	err = SCimpPacket_setPrivateKey( bob, bobPrivateKeySerialized, bob->storageKey ); CKERR;
	uint8_t_array_free(bobPrivateKeySerialized);

	SCKeyFree(bobPrivateKey);
	bobPrivateKey = NULL;

	// test back-and-forth banter
	printf("Testing dialog.\n");

	// alice sends first message to bob
	err = sendTestPacket( alice, bob, banter[0], false); CKERR;
//	err = _checkIncomingPacketsOneWay(bob, alice);
	// bob receives packet
	err = _checkIncomingPacketsOneWay(alice, bob);
	if (err == kSCLError_KeyNotFound) {
		// bob did not find the key
		// try DH
		SCimpPacket_reset(bob, true);
		err = SCimpPacket_connect(bob); CKERR;
		err = _checkIncomingPackets(alice, bob);

		err = _verifySecureConnection(alice, bob); CKERR;

		int i;
		for (i = 0; i < 10; i++) {
			err = sendBanter(&alice, &bob, false, true, false); CKERR;
/*
			printf("Testing save/restore state.\n");
			SCimpPacket *aliceRestored = NULL, *bobRestored = NULL;
			err = _testSaveRestorePacket(alice, &aliceRestored); CKERR;
			alice = aliceRestored;
			err = _testSaveRestorePacket(bob, &bobRestored); CKERR;
			bob = bobRestored;
*/
		}
	} else
		CKERR;

  	done:
		if (err != kSCLError_NoErr) {
			  printPacketInfo( "initiator", alice );
			  printPacketInfo( "responder", bob );
			  printf("Test Failed with error %d.\n", err);
		} else
			printf("Test Successful.\n");

	*initiator = alice;
	*responder = bob;

	return err;
}

SCLError TestSCimpOfflinePKCommunication(SCimpPacket **initiator, SCimpPacket **responder) {
	SCimpPacket *alice = *initiator;
	SCimpPacket *bob = *responder;
	SCKeyContextRef alicePrivateKey = NULL;
	SCKeyContextRef bobPrivateKey = NULL;

	const int QUEUE_SIZE = 20;
	uint8_t_array *queuedData[QUEUE_SIZE];

	SCLError err = kSCLError_NoErr;
	err = SCimp_generatePrivateKey( &alicePrivateKey, alice->localUserID, SC_KEY_DEFAULT_EXPIRE_AFTER ); CKERR;
	err = SCimp_generatePrivateKey( &bobPrivateKey, bob->localUserID, SC_KEY_DEFAULT_EXPIRE_AFTER ); CKERR;

	uint8_t_array *alicePrivateKeySerialized = uint8_t_array_init();
	uint8_t_array *bobPublicKeySerialized = uint8_t_array_init();

	err = SCimp_exportPrivateKey( alicePrivateKey, alice->storageKey, alicePrivateKeySerialized ); CKERR;
	err = SCimpPacket_setPrivateKey( alice, alicePrivateKeySerialized, alice->storageKey ); CKERR;

	// set Bob's private key
	uint8_t_array *bobPrivateKeySerialized = uint8_t_array_init();
	err = SCimp_exportPrivateKey( bobPrivateKey, bob->storageKey, bobPrivateKeySerialized ); CKERR;
	err = SCimpPacket_setPrivateKey( bob, bobPrivateKeySerialized, bob->storageKey ); CKERR;

	// pass bob's public key to alice
	err = SCimp_exportPublicKey( bobPrivateKey, bobPublicKeySerialized ); CKERR;
	err = SCimpPacket_setPublicKey( alice, bobPublicKeySerialized ); CKERR;

	// clean-up keys
	SCKeyFree(alicePrivateKey);
	uint8_t_array_free(alicePrivateKeySerialized);

	SCKeyFree(bobPrivateKey);
	uint8_t_array_free(bobPrivateKeySerialized);
	uint8_t_array_free(bobPublicKeySerialized);

	// test back-and-forth banter with one person offline at all times
	printf("Testing Offline communication.\n");
	SCimpPacket *initiatorP = alice, *responderP = bob;
	OfflineMessageQueue *initiatorQ = initQ();
	OfflineMessageQueue *responderQ = initQ();

	int i;
	for (i = 0; banter[i] != NULL; i++) {
		// 1. wake up: check if I have any messages to process
		err = _checkQueue(initiatorP, initiatorQ); CKERR;

		// 2. send off some number of messages
		err = sendOfflinePacket(initiatorP, responderQ, banter[i]); CKERR;
//
		// swap responder/initiator, continue
		SCimpPacket *tInitiator = initiatorP;
		initiatorP = responderP;
		responderP = tInitiator;

		OfflineMessageQueue *tQ = initiatorQ;
		initiatorQ = responderQ;
		responderQ = tQ;
	}
	err = _checkQueue(initiatorP, initiatorQ); CKERR;

	freeQ(initiatorQ);
	freeQ(responderQ);

	// test back-and-forth banter after save/restore
	err = _verifySecureConnection(alice, bob); CKERR;

	// skipped message test
	// EA: IN PROGRESS
	SCimpPacket_reset(alice, true);
	SCimpPacket_reset(bob, true);
	err = SCimpPacket_connect(alice); CKERR;
	err = _checkIncomingPackets(alice, bob); CKERR;

	// TEST #2, test skipped messages
	initiatorP = alice;
	responderP = bob;
	initiatorQ = initQ();
	responderQ = initQ();

	const int kNumSkippedMessages = 10;

	// load up the queue with some messages
	for (i = 0; i < QUEUE_SIZE; i++)
		err = sendOfflinePacket(initiatorP, responderQ, banter[i]); CKERR;

	for (i = 0; i < QUEUE_SIZE; i++)
		queuedData[i] = popQ(responderQ);

	for (i = kNumSkippedMessages; i < QUEUE_SIZE; i++) {
		err = SCimpPacket_receivePacket( responderP, queuedData[i] );
		uint8_t_array_free(queuedData[i]);
		CKERR;
	}

	freeQ(initiatorQ);
	freeQ(responderQ);

/* TODO: FINISH THIS TEST
 * THIS TEST IS KNOWN TO BREAK
// EA: IN PROGRESS
	const int kNumOutOfOrderMessages = 12;

	SCimpPacket_reset(alice, true);
	SCimpPacket_reset(bob, true);
	err = SCimpPacket_connect(alice); CKERR;
	err = _checkIncomingPackets(alice, bob); CKERR;

// TEST #3, test out-of-order messages
	initiatorP = alice;
	responderP = bob;
	initiatorQ = initQ();
	responderQ = initQ();

	// load up the queue with some messages
	for (i = 0; i < QUEUE_SIZE; i++)
		err = sendOfflinePacket(initiatorP, responderQ, banter[i]); CKERR;

	for (i = 0; i < QUEUE_SIZE; i++)
		queuedData[i] = popQ(responderQ);

	for (i = kNumOutOfOrderMessages-1; i >= 0; i--) {
    	err = SCimpPacket_receivePacket( responderP, queuedData[i] );
    	uint8_t_array_free(queuedData[i]);
    	CKERR;
	}

//	// swap responder/initiator, continue
//	SCimpPacket *tInitiator = initiatorP;
//	initiatorP = responderP;
//	responderP = tInitiator;
//
//	OfflineMessageQueue *tQ = initiatorQ;
//	initiatorQ = responderQ;
//	responderQ = tQ;

//	err = _checkQueue(initiatorP, initiatorQ); CKERR;

	freeQ(initiatorQ);
	freeQ(responderQ);
 */

	err = _verifySecureConnection(alice, bob); CKERR;

  	done:
		if (err != kSCLError_NoErr) {
			  printf("TEST FAILED: error = %d\n", err);
			  printPacketInfo( "initiator", alice );
			  printPacketInfo( "responder", bob );
		} else
			printf("Test Successful.\n");

	*initiator = alice;
	*responder = bob;

	return err;
}


SCLError TestSCimpPKExpiration(SCimpPacket **initiator, SCimpPacket **responder) {
	SCimpPacket *alice = *initiator;
	SCimpPacket *bob = *responder;
	// 1. generate and set a private/public key for alice
	// 2. generate an *expired* private/public key for bob
	// 3. pass bob's public key to alice
	SCKeyContextRef alicePrivateKey = NULL;
	SCKeyContextRef bobPrivateKey = NULL;

	SCLError err = kSCLError_NoErr;
	err = SCimp_generatePrivateKeyWithSize( &alicePrivateKey, alice->localUserID, SC_KEY_DEFAULT_EXPIRE_AFTER, 414 ); CKERR;

	uint8_t_array *alicePrivateKeySerialized = uint8_t_array_init();
	err = SCimp_exportPrivateKey( alicePrivateKey, alice->storageKey, alicePrivateKeySerialized ); CKERR;
	err = SCimpPacket_setPrivateKey( alice, alicePrivateKeySerialized, alice->storageKey ); CKERR;

	uint8_t_array *bobPublicKeySerialized = uint8_t_array_init();
	uint8_t_array *bobPrivateKeySerialized = uint8_t_array_init();

	time_t now = time(NULL);
	time_t lastWeek = now - 7*24*3600;
	time_t yesterday = now - 24*3600;
	time_t in5sec = now + 5;
	time_t tomorrow = now + 24*3600;

	// test 1: Alice uses a public key from Bob that is already expired
	err = SCimp_generatePrivateKeyWithSizeAndDates( &bobPrivateKey, bob->localUserID, 414, lastWeek, yesterday ); CKERR;
	err = SCimp_exportPrivateKey( bobPrivateKey, bob->storageKey, bobPrivateKeySerialized ); CKERR;
	// test that it *does* fail when Bob's key has expired here
	err = SCimpPacket_setPrivateKey( bob, bobPrivateKeySerialized, bob->storageKey );
	ASSERTERR(err != kSCLError_KeyExpired, err); // expecting KeyExpired

	// pass bob's public key to alice
	err = SCimp_exportPublicKey( bobPrivateKey, bobPublicKeySerialized ); CKERR;

	// test that it *does* fail when Bob's key has expired here
	err = SCimpPacket_setPublicKey( alice, bobPublicKeySerialized );
	ASSERTERR(err != kSCLError_KeyExpired, err); // expecting KeyExpired

	// finish test, reset bob
	uint8_t_array_free(bobPublicKeySerialized);
	uint8_t_array_free(bobPrivateKeySerialized);
	SCKeyFree(bobPrivateKey);

	SCimpPacket_reset(bob, true);
	bobPublicKeySerialized = uint8_t_array_init();
	bobPrivateKeySerialized = uint8_t_array_init();

	// clear alice's error state
	SCimpPacket_reset(alice, false);

	// test 2: Alice uses a public key from Bob that expires before she sends PK-start
	err = SCimp_generatePrivateKeyWithSizeAndDates( &bobPrivateKey, bob->localUserID, 414, lastWeek, in5sec ); CKERR;
	err = SCimp_exportPrivateKey( bobPrivateKey, bob->storageKey, bobPrivateKeySerialized ); CKERR;

	err = SCimpPacket_setPrivateKey( bob, bobPrivateKeySerialized, bob->storageKey ); CKERR;

	// pass bob's public key to alice
	err = SCimp_exportPublicKey( bobPrivateKey, bobPublicKeySerialized ); CKERR;
	err = SCimpPacket_setPublicKey( alice, bobPublicKeySerialized ); CKERR;

	// wait until bob's key has expired
	while (time(NULL) <= in5sec);

	// test back-and-forth banter
	printf("Testing dialog.\n");
	err = sendBanter(&alice, &bob, false, false, false); CKERR;

	// finish test, reset bob
	uint8_t_array_free(bobPublicKeySerialized);
	uint8_t_array_free(bobPrivateKeySerialized);
	SCKeyFree(bobPrivateKey);

	SCimpPacket_reset(bob, true);

	// reset alice
	uint8_t_array_free(alicePrivateKeySerialized);
	SCKeyFree(alicePrivateKey);
	SCimpPacket_reset(alice, true);

	in5sec = time(NULL) + 5; // reset time from previous test

	err = SCimp_generatePrivateKeyWithSizeAndDates( &alicePrivateKey, alice->localUserID, 414, lastWeek, in5sec ); CKERR;
	alicePrivateKeySerialized = uint8_t_array_init();
	err = SCimp_exportPrivateKey( alicePrivateKey, alice->storageKey, alicePrivateKeySerialized ); CKERR;
	err = SCimpPacket_setPrivateKey( alice, alicePrivateKeySerialized, alice->storageKey ); CKERR;

	bobPublicKeySerialized = uint8_t_array_init();
	bobPrivateKeySerialized = uint8_t_array_init();

	err = SCimp_generatePrivateKeyWithSizeAndDates( &bobPrivateKey, bob->localUserID, 414, lastWeek, tomorrow ); CKERR;
	err = SCimp_exportPrivateKey( bobPrivateKey, bob->storageKey, bobPrivateKeySerialized ); CKERR;

	err = SCimpPacket_setPrivateKey( bob, bobPrivateKeySerialized, bob->storageKey ); CKERR;

	// pass bob's public key to alice
	err = SCimp_exportPublicKey( bobPrivateKey, bobPublicKeySerialized ); CKERR;
	err = SCimpPacket_setPublicKey( alice, bobPublicKeySerialized ); CKERR;

	uint8_t_array_free(alicePrivateKeySerialized);
	SCKeyFree(alicePrivateKey);

	uint8_t_array_free(bobPublicKeySerialized);
	uint8_t_array_free(bobPrivateKeySerialized);
	SCKeyFree(bobPrivateKey);

	// Alice sends Bob a pkstart
	// Bob doesn't get the pkstart until alice's key has expired
	// Realistically, Alice might have sent that just minutes before her key is set to expire
	// Now Bob has this pkstart packet that uses an expired key
	OfflineMessageQueue *bobQ = initQ();
	err = sendOfflinePacket(alice, bobQ, banter[0]); CKERR;

	// wait until alice's key has expired
	while (time(NULL) <= in5sec);

	// bob checks messages
	err = _checkQueue(bob, bobQ); CKERR;

	freeQ(bobQ);
	bobQ = NULL;

	// test back-and-forth banter
	printf("Testing dialog.\n");
	// send the banter backwards since we already sent one message and it's bob's turn
	err = sendBanter(&bob, &alice, false, false, false); CKERR;

	done:
		if (err != kSCLError_NoErr) {
			  printPacketInfo( "initiator", alice );
			  printPacketInfo( "responder", bob );
			  printf("Test Failed with error %d.\n", err);
		} else
			printf("Test Successful.\n");

	*initiator = alice;
	*responder = bob;

	return err;
}

SCLError TestSCimpSimultaneousPKCommunication(SCimpPacket **initiator, SCimpPacket **responder) {
	SCimpPacket *alice = *initiator;
	SCimpPacket *bob = *responder;

	// to test PK communication, we:
	// 1. generate and set a private/public key for alice
	// 2. generate a private/public key for bob
	// 3a. pass bob's public key to alice
	// 3b. pass alice's public key to bob

	SCKeyContextRef alicePrivateKey = NULL;
	SCKeyContextRef bobPrivateKey = NULL;

	SCLError err = kSCLError_NoErr;
	err = SCimp_generatePrivateKey( &alicePrivateKey, alice->localUserID, SC_KEY_DEFAULT_EXPIRE_AFTER ); CKERR;
	err = SCimp_generatePrivateKey( &bobPrivateKey, bob->localUserID, SC_KEY_DEFAULT_EXPIRE_AFTER ); CKERR;

	uint8_t_array *alicePrivateKeySerialized = uint8_t_array_init();

	err = SCimp_exportPrivateKey( alicePrivateKey, alice->storageKey, alicePrivateKeySerialized ); CKERR;
	err = SCimpPacket_setPrivateKey( alice, alicePrivateKeySerialized, alice->storageKey ); CKERR;

	uint8_t_array *bobPrivateKeySerialized = uint8_t_array_init();
	err = SCimp_exportPrivateKey( bobPrivateKey, bob->storageKey, bobPrivateKeySerialized ); CKERR;
	err = SCimpPacket_setPrivateKey( bob, bobPrivateKeySerialized, bob->storageKey ); CKERR;

	// optional: set a shared secret
	uint8_t secret[64];
	sprng_read(secret,sizeof(secret),NULL);
	err = SCimpSetDataProperty(alice->scimp, kSCimpProperty_SharedSecret,  secret, sizeof(secret)); CKERR;
	err = SCimpSetDataProperty(bob->scimp, kSCimpProperty_SharedSecret,  secret, sizeof(secret)); CKERR;

	// pass bob's public key to alice
	uint8_t_array *bobPublicKeySerialized = uint8_t_array_init();
	err = SCimp_exportPublicKey( bobPrivateKey, bobPublicKeySerialized ); CKERR;
	err = SCimpPacket_setPublicKey( alice, bobPublicKeySerialized ); CKERR;

	uint8_t_array *alicePublicKeySerialized = uint8_t_array_init();
	err = SCimp_exportPublicKey( alicePrivateKey, alicePublicKeySerialized ); CKERR;
	err = SCimpPacket_setPublicKey( bob, alicePublicKeySerialized ); CKERR;

	// test simultaneous back-and-forth banter
	printf("Testing simultaneous PK-Start.\n");

	uint8_t_array_free(alicePrivateKeySerialized);
	uint8_t_array_free(alicePublicKeySerialized);
	SCKeyFree(alicePrivateKey);

	uint8_t_array_free(bobPublicKeySerialized);
	uint8_t_array_free(bobPrivateKeySerialized);
	SCKeyFree(bobPrivateKey);

	//err = sendBanter(&alice, &bob, false, false, false); CKERR;
	err = sendTestPacket(alice, bob, banter[0], false); CKERR;
	err = sendTestPacket(bob, alice, banter[0], false); CKERR;

	// now see what happens
	err = _checkIncomingPackets(alice, bob); CKERR;

/*
	// test save/restore packets
	printf("Testing save/restore state.\n");
	SCimpPacket *aliceRestored = NULL, *bobRestored = NULL;
	err = _testSaveRestorePacket(alice, &aliceRestored); CKERR;
	alice = aliceRestored;
	err = _testSaveRestorePacket(bob, &bobRestored); CKERR;
	bob = bobRestored;
*/
	// test back-and-forth banter after save/restore
	err = _verifySecureConnection(alice, bob); CKERR;

	printf("Testing dialog.\n");
	err = sendBanter(&alice, &bob, true, true, true); CKERR;

	done:
		if (err != kSCLError_NoErr) {
			  printPacketInfo( "initiator", alice );
			  printPacketInfo( "responder", bob );
			  printf("Test Failed with error %d.\n", err);
		} else
			printf("Test Successful.\n");

	*initiator = alice;
	*responder = bob;

	return err;
}

SCLError TestSCimpDHCommunication(SCimpPacket **initiator, SCimpPacket **responder) {
	SCimpPacket *alice = *initiator;
	SCimpPacket *bob = *responder;
	SCLError err = kSCLError_NoErr;

	// start DH key exchange
  	printf("Testing DH connect.\n");
	err = SCimpPacket_connect(alice); CKERR;
	err = _checkIncomingPackets(alice, bob); CKERR;
	err = _verifySecureConnection(alice, bob); CKERR;

	// test back-and-forth banter
	printf("Testing dialog.\n");
	err = sendBanter(&alice, &bob, true, true, true); CKERR;

	// test save/restore packets
	printf("Testing save/restore state.\n");
	SCimpPacket *aliceRestored = NULL, *bobRestored = NULL;
	err = _testSaveRestorePacket(alice, &aliceRestored); CKERR;
	alice = aliceRestored;
	err = _testSaveRestorePacket(bob, &bobRestored); CKERR;
	bob = bobRestored;

	// test back-and-forth banter after save/restore
	err = _verifySecureConnection(alice, bob); CKERR;

	printf("Testing dialog.\n");
	int i;
	for (i=0; i<10; i++) {
		err = sendBanter(&alice, &bob, true, true, true); CKERR;
	}

	done:
		if (err != kSCLError_NoErr) {
			  printPacketInfo( "initiator", alice );
			  printPacketInfo( "responder", bob );
			  printf("Test Failed with error %d.\n", err);
		} else
			printf("Test Successful.\n");

	*initiator = alice;
	*responder = bob;

	return err;
}

SCLError TestSCimpDHSimultaneousCommunication(SCimpPacket **initiator, SCimpPacket **responder) {
	SCimpPacket *alice = *initiator;
	SCimpPacket *bob = *responder;
	SCLError err = kSCLError_NoErr;

	// start DH key exchange
  	printf("Testing Simultaneous DH connect.\n");
	err = SCimpPacket_connect(alice); CKERR;
	err = SCimpPacket_connect(bob); CKERR;

	err = _checkIncomingPackets(alice, bob); CKERR;
	err = _verifySecureConnection(alice, bob); CKERR;

	// test back-and-forth banter
	printf("Testing dialog.\n");
	err = sendBanter(&alice, &bob, true, true, true); CKERR;

	done:
		if (err != kSCLError_NoErr) {
			  printPacketInfo( "initiator", alice );
			  printPacketInfo( "responder", bob );
			  printf("Test Failed with error %d.\n", err);
		} else
			printf("Test Successful.\n");

	*initiator = alice;
	*responder = bob;

	return err;
}

SCLError TestSCimpDHRekey(SCimpPacket **initiator, SCimpPacket **responder) {
	SCimpPacket *alice = *initiator;
	SCimpPacket *bob = *responder;
	SCLError err = kSCLError_NoErr;

	// start DH key exchange
  	printf("Testing DH connect.\n");
	err = SCimpPacket_connect(alice); CKERR;
	err = _checkIncomingPackets(alice, bob); CKERR;
	err = _verifySecureConnection(alice, bob); CKERR;

	// test back-and-forth banter
	printf("Testing dialog.\n");
	err = sendBanter(&alice, &bob, true, true, true); CKERR;

	OfflineMessageQueue *bobQ = initQ();

// re-key
// alice sends commit
err = SCimpPacket_connect(alice); CKERR;
// don't check incoming yet
//err = _checkIncomingPackets(alice, bob); CKERR;

// bob responds with DH1
err = _checkIncomingPacketsOneWay(alice, bob); CKERR;

// alice responds with 2 messages, then DH2

sendOfflinePacket(alice, bobQ, banter[0]); CKERR;
sendOfflinePacket(alice, bobQ, banter[1]); CKERR;
// alice sends DH2
err = _checkIncomingPacketsOneWay(bob, alice); CKERR;

// bob checks his queue (data messages) first
err = _checkQueue(bob, bobQ); CKERR;

// bob checks his incoming
err = _checkIncomingPacketsOneWay(alice, bob); CKERR;


//
//	freeQ(bobQ);

	done:
		if (err != kSCLError_NoErr) {
			  printPacketInfo( "initiator", alice );
			  printPacketInfo( "responder", bob );
			  printf("Test Failed with error %d.\n", err);
		} else
			printf("Test Successful.\n");

	*initiator = alice;
	*responder = bob;

	return err;
}


/*
// TODO: implement this
static SCLError TestSetupSCimpMultiCast(char* threadID, SCimpContextRef* scimpIout, SCimpContextRef* scimpROut  )
{
    SCLError        err = kSCLError_NoErr;
    SCKeyContextRef multicastKey = kInvalidSCKeyContextRef;
    SCKeyContextRef multicastKey1 = kInvalidSCKeyContextRef;
    time_t      startDate  = time(NULL) ;
    time_t      expireDate  = startDate + (3600 * 24);

    SCimpContextRef   scimpR0 = NULL;
    SCimpContextRef   scimpI0 = NULL;

    SCimpContextRef   scimpI = NULL;
    SCimpContextRef   scimpR = NULL;

     SCKeyContextRef keyB = kInvalidSCKeyContextRef;

    uint8_t*    keyBlob = NULL;
    size_t      keyBloblen = 0;

      char*  alice = "alice@silentcircle.com";
    char*  bob = "bob@silentcircle.com";

    printf("*** \tSetup keys \n");

    // we use the UUID only as a nonce, it should be unique but doesnt have to be secure
    uint8_t    deviceUUID[32];
    sprng_read(deviceUUID,sizeof(deviceUUID),NULL);

     // generate a keypair for recipient
    sprng_read(deviceUUID,sizeof(deviceUUID),NULL);
    err = SCKeyNew(kSCKeySuite_ECC384, deviceUUID, sizeof(deviceUUID),  &keyB); CKERR;
    err = SCKeySetProperty (keyB, kSCKeyProp_Owner, SCKeyPropertyType_UTF8String, bob, strlen(bob) ); CKERR;
    err = SCKeySetProperty(keyB, kSCKeyProp_StartDate,  SCKeyPropertyType_Time ,  &startDate, sizeof(time_t)); CKERR;
    err = SCKeySetProperty(keyB, kSCKeyProp_ExpireDate,  SCKeyPropertyType_Time ,  &expireDate, sizeof(time_t)); CKERR;

    // create endpoints for transporting keys
    err = SCimpNew(alice, NULL, &scimpI0);
    err = SCimpNew(bob, NULL, &scimpR0);

    err = SCimpSetEventHandler(scimpI0, sEventHandler, scimpR0); CKERR;
    err = SCimpSetEventHandler(scimpR0, sEventHandler,  scimpI0); CKERR;

    sEventHandlerTestKey = keyB;

   // create multicast key
    err = SCKeyNew(kSCKeySuite_AES256, deviceUUID, sizeof(deviceUUID), &multicastKey);
    err = SCKeySerialize( multicastKey, &keyBlob, &keyBloblen); CKERR;

    err = SCimpSendPublic(scimpI0, keyB, keyBlob, keyBloblen, NULL);

    if(!SCKeyContextRefIsValid(sEventHandlerRcvKey))
        RETERR(kSCLError_SelfTestFailed);

    multicastKey1 = sEventHandlerRcvKey;
    sEventHandlerRcvKey = kInvalidSCKeyContextRef;

    printf("*** \tSetup SCimp contexts \n");
    // Setup Initiator
    err = SCimpNewSymmetric(multicastKey, threadID, &scimpI); CKERR;
    err = SCimpNewSymmetric(multicastKey1, threadID, &scimpR); CKERR;

    err = SCimpSetEventHandler(scimpI, sEventHandler, scimpR); CKERR;
    err = SCimpSetEventHandler(scimpR, sEventHandler,  scimpI); CKERR;

    *scimpIout = scimpI;
    *scimpROut = scimpR;
done:
    if(IsntNull(scimpI0))
        SCimpFree(scimpI0);

    if(IsntNull(scimpR0))
        SCimpFree(scimpR0);

    if(IsntNull(keyBlob))
        XFREE(keyBlob);

    if(SCKeyContextRefIsValid(keyB))
        SCKeyFree(keyB);

    if(SCKeyContextRefIsValid(multicastKey))
        SCKeyFree(multicastKey);

    if(SCKeyContextRefIsValid(multicastKey1))
        SCKeyFree(multicastKey1);

    return err;
}
*/

SCLError sendBanter(SCimpPacket **initiatorP, SCimpPacket **responderP
		, bool bRandomizeMessages, bool bRandomizeSaveRestore, bool bRandomizeConnect) {

  int kSaveRestoreInterval = 3;//rand() % 5 + 5; // range is 5-10 // 3
  int kReconnectInterval = 2;//rand() % 5 + 5; // range is 5-10 // 8

  SCLError err = kSCLError_NoErr;
  SCimpPacket *initiator = *initiatorP;
  SCimpPacket *responder = *responderP;
  int i;
  for (i = 0; banter[i] != NULL; ) {
	  int numMessages = (bRandomizeMessages) ? (rand() % 5 + 1) : 1; // range is 1-5
	  int j;
	  for (j = 0; j < numMessages; j++) {
		  int idx = i+j;
		  if (banter[idx] == NULL)
			  break;

		  err = sendTestPacket( initiator, responder, banter[idx], true); CKERR;
		  if (responder->decryptedData) {
			  char *resultS = (char *)uint8_t_array_copyToCString(responder->decryptedData);
			  if( strcmp( banter[idx], resultS ) == 0 )
				  printf("Packet decrypted OK.\n");
			  else {
				  printf("Failed decryption matching! Expected: %s, Received: %s\n", banter[idx], resultS);
				  err = kSCLError_AssertFailed;
			  }
		  	  free(resultS);
		  } else {
			  err = kSCLError_AssertFailed; // how can we get here?
		  }
	  	  if (err != kSCLError_NoErr)
	  		  goto done;

	  	  if ( (bRandomizeSaveRestore) && ((idx % kSaveRestoreInterval) == 0) ) {
			  // test save/restore after 1st packet and every subsequent interval
			  printf("Testing save/restore state.\n");

				SCimpPacket *iRestored = NULL, *rRestored = NULL;
				err = _testSaveRestorePacket(initiator, &iRestored); CKERR;
				*initiatorP = iRestored;
				initiator = *initiatorP;

				err = _testSaveRestorePacket(responder, &rRestored); CKERR;
				*responderP = rRestored;
				responder = *responderP;
		  }
		  if ( (bRandomizeConnect) && (idx > 0) && ((idx % kReconnectInterval) == 0) ) {
			  // testing reconnect
			  printf("Testing DH connect.\n");
			  err = SCimpPacket_connect(initiator);//CKERR;
			  if (err != kSCLError_NoErr)
				  goto done;
			  err = _checkIncomingPackets(initiator, responder);// CKERR;
			  if (err != kSCLError_NoErr)
				  goto done;
			  err = _verifySecureConnection(initiator, responder);// CKERR;
			  if (err != kSCLError_NoErr)
				  goto done;
		  }
	  }
	  i += j;

	  // swap responder/initiator, continue
	  SCimpPacket *tInitiator = initiator;
	  initiator = responder;
	  responder = tInitiator;
	  *initiatorP = initiator;
	  *responderP = responder;
  }
  done:
    return err;
}

SCLError _checkIncomingPackets( SCimpPacket *initiator, SCimpPacket *responder) {
  SCLError err = kSCLError_NoErr;
  while( initiator->outgoingData != NULL || responder->outgoingData != NULL ) {
    if( initiator->outgoingData != NULL ) {
    	err = SCimpPacket_receivePacket( responder, initiator->outgoingData );
    	if( initiator->outgoingData != NULL ) {
    		uint8_t_array_free( initiator->outgoingData );
    		initiator->outgoingData = NULL;
    	}
    	if (err != kSCLError_NoErr)
    		return err;
    }
    if( responder->outgoingData != NULL ) {
    	err = SCimpPacket_receivePacket( initiator, responder->outgoingData );
    	if( responder->outgoingData != NULL ) {
    		uint8_t_array_free( responder->outgoingData );
    		responder->outgoingData = NULL;
    	}
    	if (err != kSCLError_NoErr)
    		return err;
    }
  }
  return kSCLError_NoErr;
}

SCLError _checkIncomingPacketsOneWay( SCimpPacket *initiator, SCimpPacket *responder) {
	SCLError err = kSCLError_NoErr;
	while (initiator->outgoingData != NULL) {
    	err = SCimpPacket_receivePacket( responder, initiator->outgoingData );
    	uint8_t_array_free( initiator->outgoingData );
    	initiator->outgoingData = NULL;
    	if (err != kSCLError_NoErr)
    		return err;
	}
	return kSCLError_NoErr;
}

SCLError _checkQueue(SCimpPacket *packet, OfflineMessageQueue *q) {
	_offlineQ = q;
	SCLError err = kSCLError_NoErr;
	uint8_t_array *queuedData;
	while ( (queuedData = popQ(q)) != NULL ) {
    	err = SCimpPacket_receivePacket( packet, queuedData );
    	uint8_t_array_free(queuedData);
    	CKERR;
	}
done:
	_offlineQ = NULL;
	return err;
}

SCLError _verifySecureConnection( SCimpPacket *initiator, SCimpPacket *responder) {
  int isLevel1 = false;
  int secureI = SCimpPacket_isMinimumSecureMethod(initiator, kSCimpMethod_DHv2);
  if (!secureI) {
	  secureI = SCimpPacket_isMinimumSecureMethod(initiator, kSCimpMethod_DH);
	  isLevel1 = true;
  }

  int secureR = SCimpPacket_isMinimumSecureMethod(responder, kSCimpMethod_DHv2);
  if (!secureR) {
	  secureR = SCimpPacket_isMinimumSecureMethod(responder, kSCimpMethod_DH);
	  isLevel1 = true;
  }
  if ( (!secureI) || (!secureR) )
    return kSCLError_AssertFailed;

  printf("Connection verified secure: v%s\n", (isLevel1) ? "1" : "2");
  return kSCLError_NoErr;
}

SCLError _testSaveRestorePacket(SCimpPacket *packetIn, SCimpPacket **packetOut) {
	// NOTE: this method free's packetIn
	uint8_t_array *storageKey = uint8_t_array_copy(packetIn->storageKey->items, packetIn->storageKey->size);

	if (packetIn->context == NULL)
		return kSCLError_AssertFailed; // can't be NULL!

	SCLError err = SCimpPacket_save(packetIn); CKERR;

	char *context = malloc((strlen(packetIn->context)+1)*sizeof(char));
	strcpy(context, packetIn->context);

	SCimpPacket_free(packetIn); // NOTE: free's packet, storage key, context, etc.

	*packetOut = SCimpPacket_restore(storageKey, context);
	free(context);

	err = (*packetOut) ? (*packetOut)->error : kSCLError_OutOfMemory;

	done:
		return err;
}

void printPacketInfo( const char *tag, SCimpPacket *packet ) {
	char *outgoingData = (packet->outgoingData) ? (char *)uint8_t_array_copyToCString(packet->outgoingData) : NULL;
	char *decryptedData = (packet->decryptedData) ? (char *)uint8_t_array_copyToCString(packet->decryptedData) : NULL;
	fprintf( stderr, "[%s] {\n  \"error\": %d,\n  \"warning\": %d,\n  \"state\": %d,\n  \"secret\": \"%s\",\n  \"context\": \"%s\",\n  \"outgoing_data\": \"%s\",\n  \"decrypted_data\": \"%s\"\n}\n\n", packet->localUserID, packet->error, packet->warning, packet->state, packet->secret, packet->context, (outgoingData) ? outgoingData : "", (decryptedData) ? decryptedData : "");
	free(outgoingData);
	free(decryptedData);
}

#undef SC_KEY_DEFAULT_EXPIRE_AFTER
#undef XPRINTF
