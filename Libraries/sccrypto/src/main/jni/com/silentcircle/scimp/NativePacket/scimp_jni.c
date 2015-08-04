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
#include <SCimp.h>
#include <SCimpPriv.h>
#include "uint8_t_array.h"
#include "jni_macros.h"

// API Methods Implemented:
// SCimpStartDHSync
// SCimpSendPublicSync
// SCimpProcessPacketSync
// SCimpSendMsgSync
// SCimpFreeEventBlock

#define SCIMP_JNI_VERBOSE 0
#if defined(ANDROID)
#include <android/log.h>
#define XPRINTF( tag, format, ... ) __android_log_print( ANDROID_LOG_DEBUG, tag, format, __VA_ARGS__ );
#else
#define XPRINTF( tag, format, ... ) fprintf( stderr, format, __VA_ARGS__ );
#endif

// forward declarations
SCLError startSCimp(JNIEnv *jni, jbyteArray jstorageKey, jbyteArray jcontext, const char *localUserID, const char *remoteUserID, SCimpContextRef *scimpP, SCKeyContextRef *scKeyP);
void finishSCimp(SCimpContextRef scimpP, SCKeyContextRef scKey);
jobject processSCimpResultBlock(JNIEnv *jni, SCimpContextRef scimp, SCKeyContextRef sKey, SCimpResultBlock *resultsIn, const char *localUserID, SCLError *errP);
jobject createResultBlock(JNIEnv *jni, SCLError err);
jobject createSCimpInfo(JNIEnv *jni, SCimpInfo info);

// SCimpStartDHSync
JNIEXPORT jobject JNICALL Java_com_silentcircle_scimp_NativePacket_startDHSync( JNIEnv *jni, jobject this, jbyteArray jstorageKey, jstring jlocalUserID, jstring jremoteUserID, jbyteArray jcontext ) {
	NEW_STRING( jlocalUserID, localUserID);
	NEW_STRING( jremoteUserID, remoteUserID);

	jobject resultObj = NULL;
	SCLError err = kSCLError_NoErr;
	if ( VERIFY_STRING(jlocalUserID, localUserID)
			&& VERIFY_STRING(jremoteUserID, remoteUserID) ) {
		SCimpResultBlock *resultBlock;
		SCimpContextRef scimp;
		SCKeyContextRef sKey = NULL;
		err = startSCimp(jni, jstorageKey, jcontext, localUserID, remoteUserID, &scimp, &sKey); CKERR;
		err = SCimpStartDHSync(scimp, &resultBlock); //CKERR;
		resultObj = processSCimpResultBlock(jni, scimp, sKey, resultBlock, localUserID, &err);
		finishSCimp(scimp, sKey);
		if (resultBlock != NULL)
			SCimpFreeEventBlock(resultBlock);
	}

done:
	FREE_STRING( jremoteUserID, remoteUserID);
	FREE_STRING( jlocalUserID, localUserID);

	if ( (resultObj == NULL) && (err != kSCLError_NoErr) )
		resultObj = createResultBlock(jni, err);

	return resultObj;
}

// SCimpSendPublicSync
JNIEXPORT jobject JNICALL Java_com_silentcircle_scimp_NativePacket_sendPublicSync( JNIEnv *jni, jobject this, jbyteArray jstorageKey, jbyteArray jpublicKey, jstring jlocalUserID, jstring jremoteUserID, jbyteArray jdata, jbyteArray jcontext ) {
	NEW_BYTES( jpublicKey, publicKeyItems, publicKeySize );
	NEW_BYTES( jdata, dataItems, dataSize );
	NEW_STRING( jlocalUserID, localUserID );
	NEW_STRING( jremoteUserID, remoteUserID );

	jobject resultObj = NULL;
	SCLError err = kSCLError_NoErr;
	uint8_t_array *publicKey = NULL;
	uint8_t_array *storageKey = NULL;
	uint8_t_array *data = NULL;

	if ( VERIFY_BYTES( jpublicKey, publicKeyItems )
			&& VERIFY_BYTES( jdata, dataItems )
			&& VERIFY_STRING( jlocalUserID, localUserID )
			&& VERIFY_STRING( jremoteUserID, remoteUserID ) ) {

		publicKey = uint8_t_array_copy( publicKeyItems, publicKeySize );
		data = uint8_t_array_copy( dataItems, dataSize );

		if ( (publicKey == NULL) || (data == NULL) ) {
			err = kSCLError_OutOfMemory; CKERR;
		}

		SCimpResultBlock *resultBlock = NULL;
		SCimpContextRef scimp;
		SCKeyContextRef sKey = NULL;
		SCKeyContextRef remotePublicKey = kInvalidSCKeyContextRef;
		err = startSCimp(jni, jstorageKey, jcontext, localUserID, remoteUserID, &scimp, &sKey); CKERR;
		err = SCimp_importPublicKey( publicKey, &remotePublicKey ); CKERR;
		err = SCimpSendPublicSync(scimp, remotePublicKey, (void *)data->items,	data->size,	NULL, &resultBlock); // CKERR;
		resultObj = processSCimpResultBlock(jni, scimp, sKey, resultBlock, localUserID, &err);
		finishSCimp(scimp, sKey);
		if (resultBlock != NULL)
			SCimpFreeEventBlock(resultBlock);
	}

done:
	FREE_STRING( jremoteUserID, remoteUserID );
	FREE_STRING( jlocalUserID, localUserID );
	FREE_BYTES( jdata, dataItems );
	FREE_BYTES( jpublicKey, publicKeyItems );
	if (publicKey != NULL)
		uint8_t_array_free(publicKey);
	if (data != NULL)
		uint8_t_array_free(data);

	if ( (resultObj == NULL) && (err != kSCLError_NoErr) )
		resultObj = createResultBlock(jni, err);

	return resultObj;
}

// SCimpSendMsgSync
JNIEXPORT jobject JNICALL Java_com_silentcircle_scimp_NativePacket_sendMessageSync( JNIEnv *jni, jobject this, jbyteArray jstorageKey, jstring jlocalUserID, jstring jremoteUserID, jbyteArray jdata, jbyteArray jcontext ) {
	NEW_BYTES( jdata, dataItems, dataSize );
	NEW_STRING( jlocalUserID, localUserID );
	NEW_STRING( jremoteUserID, remoteUserID );

	jobject resultObj = NULL;
	SCLError err = kSCLError_NoErr;
	uint8_t_array *storageKey = NULL;
	uint8_t_array *data = NULL;
	if ( VERIFY_BYTES( jdata, dataItems )
			&& VERIFY_STRING( jlocalUserID, localUserID )
			&& VERIFY_STRING( jremoteUserID, remoteUserID ) ) {

		data = uint8_t_array_copy( dataItems, dataSize );

		if (data == NULL) {
			err = kSCLError_OutOfMemory; CKERR;
		}

		SCimpResultBlock *resultBlock = NULL;
		SCimpContextRef scimp;
		SCKeyContextRef sKey = NULL;
		err = startSCimp(jni, jstorageKey, jcontext, localUserID, remoteUserID, &scimp, &sKey); CKERR;
		err = SCimpSendMsgSync(scimp, (void *)data->items, data->size,	NULL, &resultBlock); // CKERR;
		resultObj = processSCimpResultBlock(jni, scimp, sKey, resultBlock, localUserID, &err);
		finishSCimp(scimp, sKey);
		if (resultBlock != NULL)
			SCimpFreeEventBlock(resultBlock);
	}

done:
	FREE_STRING( jremoteUserID, remoteUserID );
	FREE_STRING( jlocalUserID, localUserID );
	FREE_BYTES( jdata, dataItems );
	if (data != NULL)
		uint8_t_array_free(data);

	if ( (resultObj == NULL) && (err != kSCLError_NoErr) )
		resultObj = createResultBlock(jni, err);

	return resultObj;
}

// SCimpProcessPacketSync
JNIEXPORT jobject JNICALL Java_com_silentcircle_scimp_NativePacket_processPacketSync( JNIEnv *jni, jobject this, jbyteArray jstorageKey, jstring jlocalUserID, jstring jremoteUserID, jbyteArray jdata, jbyteArray jcontext ) {
	NEW_BYTES( jdata, dataItems, dataSize );
	NEW_STRING( jlocalUserID, localUserID );
	NEW_STRING( jremoteUserID, remoteUserID );

	jobject resultObj = NULL;
	SCLError err = kSCLError_NoErr;
	uint8_t_array *storageKey = NULL;
	uint8_t_array *data = NULL;
	if ( VERIFY_BYTES( jdata, dataItems )
			&& VERIFY_STRING( jlocalUserID, localUserID )
			&& VERIFY_STRING( jremoteUserID, remoteUserID ) ) {

		data = uint8_t_array_copy( dataItems, dataSize );
		if (data == NULL) {
			err = kSCLError_OutOfMemory; CKERR;
		}

		SCimpResultBlock *resultBlock = NULL;
		SCimpContextRef scimp;
		SCKeyContextRef sKey = NULL;
		err = startSCimp(jni, jstorageKey, jcontext, localUserID, remoteUserID, &scimp, &sKey); CKERR;
		err = SCimpProcessPacketSync(scimp, (void *)data->items, data->size, NULL,	&resultBlock); // CKERR;
		resultObj = processSCimpResultBlock(jni, scimp, sKey, resultBlock, localUserID, &err);
		finishSCimp(scimp, sKey);
		if (resultBlock != NULL)
			SCimpFreeEventBlock(resultBlock);
	}

done:
	FREE_STRING( jremoteUserID, remoteUserID );
	FREE_STRING( jlocalUserID, localUserID );
	FREE_BYTES( jdata, dataItems );
	if (data != NULL)
		uint8_t_array_free(data);

	if ( (resultObj == NULL) && (err != kSCLError_NoErr) )
		resultObj = createResultBlock(jni, err);

	return resultObj;
}

SCLError _createSCKey(JNIEnv *jni, jbyteArray jstorageKey, SCKeyContextRef *scKeyP) {
	SCLError err = kSCLError_NoErr;
	NEW_BYTES( jstorageKey, storageKeyItems, storageKeySize);
	if (!VERIFY_BYTES(jstorageKey, storageKeyItems)) {
		err = kSCLError_OutOfMemory; CKERR;
	}

	size_t keySize = storageKeySize/2;
	char *nonce = "AAL;KJADSF;LKJADSqewrmn.ewqroiuzxcKASDF;zcpiqwekjrzcoipuv ADSF;LKJADSF; ASDFKLJ;ADSF"; // anything
	err = SCKeyImport_Symmetric(kSCKeySuite_AES256, storageKeyItems, (uint8_t*)nonce, strlen(nonce), scKeyP); CKERR;
	err = SCKeySetProperty(*scKeyP, kSCKeyProp_IV, SCKeyPropertyType_Binary, storageKeyItems+keySize, keySize); CKERR;
#if SCIMP_JNI_VERBOSE
	XPRINTF( "SCIMP-JNI", "SCKey created with keySize: %d", keySize );
#endif

done:
	FREE_BYTES( jstorageKey, storageKeyItems);
	return err;
}

void _deleteSCKey(SCKeyContextRef sKey) {
	if (SCKeyContextRefIsValid(sKey))
		SCKeyFree(sKey);
}

// startSCimp either restores an encypted context or creates a new one
SCLError startSCimp(JNIEnv *jni, jbyteArray jstorageKey, jbyteArray jcontext, const char *localUserID, const char *remoteUserID, SCimpContextRef *scimpP, SCKeyContextRef *scKeyP) {
	SCLError err = kSCLError_NoErr;

	if (*scKeyP == NULL) {
		err = _createSCKey(jni, jstorageKey, scKeyP); CKERR;
	}
	bool hasContext = false;
	if (jcontext != NULL) {
		NEW_BYTES( jcontext, context, contextSize );
		if (!VERIFY_BYTES(jcontext, context)) {
			err = kSCLError_OutOfMemory; CKERR;
		}
		if (contextSize > 0) {
			err = SCimpDecryptState(*scKeyP, context, contextSize, scimpP); CKERR;
			hasContext = true;
		}
		FREE_BYTES(jcontext, context);
	}
	if (!hasContext) {
		err = SCimpNew( localUserID, remoteUserID, scimpP ); CKERR;
		err = SCimpSetNumericProperty( *scimpP, kSCimpProperty_CipherSuite, kSCimpCipherSuite_SKEIN_2FISH_ECC414 ); CKERR; // non NIST
		err = SCimpSetNumericProperty( *scimpP, kSCimpProperty_SASMethod, kSCimpSAS_PGP ); CKERR;
	}

	done:
	    return err;
}

void finishSCimp(SCimpContextRef scimpP, SCKeyContextRef scKey) {
	_deleteSCKey(scKey);
}

jobject processSCimpResultBlock(JNIEnv *jni, SCimpContextRef scimp, SCKeyContextRef sKey, SCimpResultBlock *resultsIn, const char *localUserID, SCLError *errP) {
	SCLError err = *errP;

	int totalEvents = 0;
	SCimpResultBlock *result = resultsIn;
	while (result) {
		totalEvents++;
		result = result->next;
	}

#if SCIMP_JNI_VERBOSE
	XPRINTF( "SCIMP-JNI", "(%s) ProcessResultBlock processing %d SCimpEvents", localUserID, totalEvents );
#endif

    // allocate a new array for events
    jclass classSCimpEvent = (*jni)->FindClass(jni, "com/silentcircle/scimp/SCimpEvent");
	jobjectArray resultsOut = (*jni)->NewObjectArray(jni, totalEvents, classSCimpEvent, NULL);

	// Get the Method ID of the SCimpEvent constructor which takes an int
	jmethodID eventInit = (*jni)->GetMethodID(jni, classSCimpEvent, "<init>", "(I)V");

	// Get the Field ID of the SCimpEvent instance variables "value1", "value2" and "data"
	jfieldID eventValue1FID = (*jni)->GetFieldID(jni, classSCimpEvent, "value1", "I"); // int
	jfieldID eventValue2FID = (*jni)->GetFieldID(jni, classSCimpEvent, "value2", "I"); // int

	jfieldID dataFID = (*jni)->GetFieldID(jni, classSCimpEvent, "data", "[B"); // byte array

	// iterate through the events and create Java versions
	bool bKeyed = false;
	jsize eventIdx = 0;
	result = resultsIn;
	while (result) {
		SCimpEvent event = result->event;

		// allocate a new SCimpEvent instance
		jobject eventObj = (*jni)->NewObject(jni, classSCimpEvent, eventInit, (jint) event.type);

#if SCIMP_JNI_VERBOSE
	XPRINTF( "SCIMP-JNI", "(%s) ProcessResultBlock, Event Type = %d", localUserID, event.type );
#endif

		switch (event.type) {
			case kSCimpEvent_Error: {
				err = event.data.errorData.error;
				(*jni)->SetIntField(jni, eventObj, eventValue1FID, (jint) event.data.errorData.error);
				break;
			}
			case kSCimpEvent_Warning: {
				(*jni)->SetIntField(jni, eventObj, eventValue1FID, (jint) event.data.warningData.warning);
				break;
			}
			case kSCimpEvent_SendPacket: {
				SCimpEventSendData sendData = event.data.sendData;
				(*jni)->SetIntField(jni, eventObj, eventValue1FID, (jint) sendData.shouldPush);
				(*jni)->SetIntField(jni, eventObj, eventValue2FID, (jint) sendData.isPKdata);

				jbyteArray jByteArray = (*jni)->NewByteArray(jni, sendData.length);
				(*jni)->SetByteArrayRegion(jni, jByteArray, 0, sendData.length, sendData.data);
#if SCIMP_JNI_VERBOSE
		XPRINTF( "SCIMP-JNI", "(%s) SEND PACKET: %s\n", localUserID, sendData.data );
#endif // SCIMP_PACKET_VERBOSE
				(*jni)->SetObjectField(jni, eventObj, dataFID, jByteArray);
				(*jni)->DeleteLocalRef(jni, jByteArray);
				break;
			}
			case kSCimpEvent_Keyed:
				bKeyed = true;
				break;
			case kSCimpEvent_ReKeying:
				break;
			case kSCimpEvent_Decrypted: {
				SCimpEventDecryptData decryptData = event.data.decryptData;
				jbyteArray jByteArray = (*jni)->NewByteArray(jni, decryptData.length);
				(*jni)->SetByteArrayRegion(jni, jByteArray, 0, decryptData.length, decryptData.data);
#if SCIMP_JNI_VERBOSE
		XPRINTF( "SCIMP-JNI", "(%s) DECRYPTED: %s\n", localUserID, decryptData.data );
#endif // SCIMP_PACKET_VERBOSE
				(*jni)->SetObjectField(jni, eventObj, dataFID, jByteArray);
				(*jni)->DeleteLocalRef(jni, jByteArray);
				break;
			}
			case kSCimpEvent_ClearText: {
				SCimpEventClearText clearText = event.data.clearText;
				jbyteArray jByteArray = (*jni)->NewByteArray(jni, clearText.length);
				(*jni)->SetByteArrayRegion(jni, jByteArray, 0, clearText.length, clearText.data);
#if SCIMP_JNI_VERBOSE
		XPRINTF( "SCIMP-JNI", "(%s) CLEAR TEXT: %s\n", localUserID, clearText.data );
#endif // SCIMP_PACKET_VERBOSE
				(*jni)->SetObjectField(jni, eventObj, dataFID, jByteArray);
				(*jni)->DeleteLocalRef(jni, jByteArray);
				break;
			}
			case kSCimpEvent_Shutdown:
			case kSCimpEvent_AdviseSaveState:
				// no additional data or values
				break;
			case kSCimpEvent_Transition: {
				SCimpEventTransitionData transData = event.data.transData;
				(*jni)->SetIntField(jni, eventObj, eventValue1FID, (jint) transData.state);
				(*jni)->SetIntField(jni, eventObj, eventValue2FID, (jint) transData.method);
				break;
			}
			case kSCimpEvent_PubData: {
				SCimpEventPubData pubData = event.data.pubData;
				jbyteArray jByteArray = (*jni)->NewByteArray(jni, pubData.length);
				(*jni)->SetByteArrayRegion(jni, jByteArray, 0, pubData.length, pubData.data);
#if SCIMP_JNI_VERBOSE
		XPRINTF( "SCIMP-JNI", "(%s) PUB DATA: %s\n", localUserID, pubData.data );
#endif // SCIMP_PACKET_VERBOSE
				(*jni)->SetObjectField(jni, eventObj, dataFID, jByteArray);
				(*jni)->DeleteLocalRef(jni, jByteArray);
				break;
			}
			case kSCimpEvent_NeedsPrivKey:
				// will never get called from SCimp Sync methods
				break;
			case kSCimpEvent_LogMsg:
				// NYI
				break;
			default:
#if SCIMP_JNI_VERBOSE
				XPRINTF( "SCIMP-JNI", "WARN: Unrecognized Event Type: %d", event.type );
#endif
				break;
		}
		// add the object to the results array
		(*jni)->SetObjectArrayElement(jni, resultsOut, eventIdx, eventObj);
		result = result->next;
		eventIdx++;
	}
#if SCIMP_JNI_VERBOSE
	XPRINTF( "SCIMP-JNI", "(%s) ProcessResultBlock completed", localUserID );
#endif

	jobject resultBlockObj = createResultBlock(jni, err);

	jclass classResultBlock = (*jni)->FindClass(jni, "com/silentcircle/scimp/SCimpResultBlock");
    jfieldID resultsFID = (*jni)->GetFieldID(jni, classResultBlock, "results", "[Lcom/silentcircle/scimp/SCimpEvent;");
    (*jni)->SetObjectField(jni, resultBlockObj, resultsFID, resultsOut);

	// encrypt SCimp context and set on result object
	void *encryptBuffer = NULL;
	size_t encryptBufferSize = 0;

	SCLError saveStateErr = SCimpEncryptState(scimp, sKey, &encryptBuffer, &encryptBufferSize);
	if (saveStateErr != kSCLError_NoErr) {
		if (err == kSCLError_NoErr)
	    	err = saveStateErr; // set any saveState error if we didn't have any error previously
#if SCIMP_JNI_VERBOSE
		XPRINTF( "SCIMP-JNI", "ERROR: unable to encrypt state (%d)", saveStateErr );
#endif
	}

#if SCIMP_JNI_VERBOSE
	XPRINTF( "SCIMP-JNI", "(%s) Encrypted context is %d bytes", localUserID, encryptBufferSize );
#endif

/* TESTING
XPRINTF("SCIMP-JNI", "(%s) Testing decrypting context", localUserID);
SCimpContextRef testScimp;
SCLError testErr = SCimpDecryptState(sKey, encryptBuffer, encryptBufferSize, &testScimp);
if (testErr != kSCLError_NoErr) {
	XPRINTF("SCIMP-JNI", "FAILED, error = %d", testErr);
} else
	XPRINTF("SCIMP-JNI", "(%s) Success", localUserID);
*/
//	jstring context = (*jni)->NewStringUTF(jni, encryptBuffer);
	jbyteArray jByteArray = (*jni)->NewByteArray(jni, encryptBufferSize);
	(*jni)->SetByteArrayRegion(jni, jByteArray, 0, encryptBufferSize, encryptBuffer);

	jfieldID contextFID = (*jni)->GetFieldID(jni, classResultBlock, "context", "[B"); // byte array //Ljava/lang/String;");
	(*jni)->SetObjectField(jni, resultBlockObj, contextFID, jByteArray);
	(*jni)->DeleteLocalRef(jni, jByteArray);
#if SCIMP_JNI_VERBOSE
	XPRINTF( "SCIMP-JNI", "(%s) Context saved", localUserID );
#endif

    // set SCimpInfo field
	SCimpInfo info;
	SCimpGetInfo(scimp, &info);

	jobject infoObj = createSCimpInfo(jni, info);
    jfieldID infoFID = (*jni)->GetFieldID(jni, classResultBlock, "info", "Lcom/silentcircle/scimp/SCimpInfo;");
    (*jni)->SetObjectField(jni, resultBlockObj, infoFID, infoObj);

    if (bKeyed) {
    	// if we had a "Keyed" event, accept the secret
		if (info.scimpMethod == kSCimpMethod_DH)
			SCimpAcceptSecret(scimp);

		// include the sasPhrase in the result block
    	char *sasBuffer = NULL;
		size_t sasBufferSize = 0;
		SCimpGetAllocatedDataProperty(scimp, kSCimpProperty_SASstring,
				(void*) &sasBuffer, &sasBufferSize);

		if (sasBuffer != NULL) {
			jByteArray = (*jni)->NewByteArray(jni, sasBufferSize);
			if (jByteArray != NULL) {
				(*jni)->SetByteArrayRegion(jni, jByteArray, 0, sasBufferSize, sasBuffer);

				jfieldID sasFID = (*jni)->GetFieldID(jni, classResultBlock, "sasPhrase", "[B"); // byte array //Ljava/lang/String;");
				(*jni)->SetObjectField(jni, resultBlockObj, sasFID, jByteArray);
				(*jni)->DeleteLocalRef(jni, jByteArray);
			}
			XFREE(sasBuffer);
		}
    }

    *errP = err;
	return resultBlockObj;
}

jobject createResultBlock(JNIEnv *jni, SCLError err) {
	// build the SCimpResultBlock object that will be returned
	jclass classResultBlock = (*jni)->FindClass(jni, "com/silentcircle/scimp/SCimpResultBlock");
	// Get the Method ID of the constructor which takes no parameters
	jmethodID resultBlockInit = (*jni)->GetMethodID(jni, classResultBlock, "<init>", "()V");

	// Call back constructor to allocate a new instance, with no argument
    jobject resultBlockObj = (*jni)->NewObject(jni, classResultBlock, resultBlockInit);//, NULL);
    jfieldID errorFID = (*jni)->GetFieldID(jni, classResultBlock, "errorCode", "I"); // int
	(*jni)->SetIntField(jni, resultBlockObj, errorFID, (jint) err);

	return resultBlockObj;
}

jobject createSCimpInfo(JNIEnv *jni, SCimpInfo info) {
	// build the SCimpInfo object that will be returned
	jclass classSCimpInfo = (*jni)->FindClass(jni, "com/silentcircle/scimp/SCimpInfo");
	// Get the Method ID of the constructor which takes no parameters
	jmethodID infoInit = (*jni)->GetMethodID(jni, classSCimpInfo, "<init>", "()V");

	// Call back constructor to allocate a new instance, with no argument
    jobject infoObj = (*jni)->NewObject(jni, classSCimpInfo, infoInit);//, NULL);

    // set all the properties
    jfieldID fieldID = (*jni)->GetFieldID(jni, classSCimpInfo, "version", "B"); // byte
	(*jni)->SetByteField(jni, infoObj, fieldID, (jbyte) info.version);
    fieldID = (*jni)->GetFieldID(jni, classSCimpInfo, "cipherSuite", "I"); // int
	(*jni)->SetIntField(jni, infoObj, fieldID, (jint) info.cipherSuite);
    fieldID = (*jni)->GetFieldID(jni, classSCimpInfo, "sasMethod", "I"); // int
	(*jni)->SetIntField(jni, infoObj, fieldID, (jint) info.sasMethod);
    fieldID = (*jni)->GetFieldID(jni, classSCimpInfo, "scimpMethod", "I"); // int
	(*jni)->SetIntField(jni, infoObj, fieldID, (jint) info.scimpMethod);

    fieldID = (*jni)->GetFieldID(jni, classSCimpInfo, "isReady", "Z"); // boolean
	(*jni)->SetBooleanField(jni, infoObj, fieldID, (jboolean) info.isReady);
    fieldID = (*jni)->GetFieldID(jni, classSCimpInfo, "isInitiator", "Z"); // boolean
	(*jni)->SetBooleanField(jni, infoObj, fieldID, (jboolean) info.isInitiator);
    fieldID = (*jni)->GetFieldID(jni, classSCimpInfo, "hasCs", "Z"); // boolean
	(*jni)->SetBooleanField(jni, infoObj, fieldID, (jboolean) info.hasCs);
    fieldID = (*jni)->GetFieldID(jni, classSCimpInfo, "csMatches", "Z"); // boolean
	(*jni)->SetBooleanField(jni, infoObj, fieldID, (jboolean) info.csMatches);
    fieldID = (*jni)->GetFieldID(jni, classSCimpInfo, "canPKstart", "Z"); // boolean
	(*jni)->SetBooleanField(jni, infoObj, fieldID, (jboolean) info.canPKstart);

    fieldID = (*jni)->GetFieldID(jni, classSCimpInfo, "keyedTime", "J"); // long
	(*jni)->SetLongField(jni, infoObj, fieldID, (jlong) info.keyedTime);

// const char* meStr;
// const char* youStr;

	fieldID = (*jni)->GetFieldID(jni, classSCimpInfo, "state", "I"); // int
	(*jni)->SetIntField(jni, infoObj, fieldID, (jint) info.state);

    return infoObj;
}

#undef SCIMP_JNI_VERBOSE
#undef XPRINTF
