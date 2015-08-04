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
#include <string.h>
#include <SCimp.h>

#include "scimp_packet.h"
#include "uint8_t_array.h"
#include "scimp_tests.h"

#define NEW_BYTES( jname, name, nameSize ) jbyte *name = (*jni)->GetByteArrayElements( jni, jname, 0 ); size_t nameSize = (size_t) (*jni)->GetArrayLength( jni, jname );
#define FREE_BYTES( jname, name )  (*jni)->ReleaseByteArrayElements( jni, jname, name, JNI_ABORT );

#define NEW_STRING( jname, name ) const char *name = jname == NULL ? NULL : (*jni)->GetStringUTFChars( jni, jname, NULL );
#define FREE_STRING( jname, name ) if( jname != NULL ) { (*jni)->ReleaseStringUTFChars( jni, jname, name ); }

#define NEW_OUT_STRING( jname, name ) jstring jname = name == NULL ? NULL : (*jni)->NewStringUTF( jni, name );
#define FREE_OUT_STRING( jname ) if( jname != NULL ) { (*jni)->DeleteLocalRef( jni, jname ); }

#define NEW_OUT_BYTES( jname, name ) jbyteArray jname = name == NULL ? NULL : (*jni)->NewByteArray( jni, name->size ); (*jni)->SetByteArrayRegion( jni, jname, 0, name->size, (jbyte*) name->items );
#define FREE_OUT_BYTES( jname ) ;

static char localUserID[1024] = "alice@silentcircle.com";
static char remoteUserID[1024] = "bob@silentcircle.com";

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpKeySerializer( JNIEnv *jni, jobject this ) {
	SCLError err = runSCimpTest(TestSCimpKeySerializer, localUserID, remoteUserID);
	return (jint) err;
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpPKCommunication( JNIEnv *jni, jobject this ) {
	SCLError err = runSCimpTest(TestSCimpPKCommunication, localUserID, remoteUserID);
	return (jint) err;
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpPKSaveRestore( JNIEnv *jni, jobject this ) {
	SCLError err = runSCimpTest(TestSCimpPKSaveRestore, localUserID, remoteUserID);
	return (jint) err;
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpPKContention( JNIEnv *jni, jobject this ) {
	SCLError err = runSCimpTest(TestSCimpPKContention, localUserID, remoteUserID);
	return (jint) err;
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpOfflinePKCommunication( JNIEnv *jni, jobject this ) {
	SCLError err = runSCimpTest(TestSCimpOfflinePKCommunication, localUserID, remoteUserID);
	return (jint) err;
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpPKExpiration( JNIEnv *jni, jobject this ) {
	SCLError err = runSCimpTest(TestSCimpPKExpiration, localUserID, remoteUserID);
	return (jint) err;
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpSimultaneousPKCommunication( JNIEnv *jni, jobject this ) {
	SCLError err = runSCimpTest(TestSCimpSimultaneousPKCommunication, localUserID, remoteUserID);
	return (jint) err;
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpDHSimultaneousCommunication( JNIEnv *jni, jobject this ) {
	SCLError err = runSCimpTest(TestSCimpDHSimultaneousCommunication, localUserID, remoteUserID);
	return (jint) err;
}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpDHCommunication( JNIEnv *jni, jobject this ) {
	SCLError err = runSCimpTest(TestSCimpDHCommunication, localUserID, remoteUserID);
	return (jint) err;
}


// NOTE: this is not currently used:
JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCKeyDeserialize( JNIEnv *jni, jobject this, jstring jserializedKey ) {

  NEW_STRING( jserializedKey, serializedKey );
  SCKeyContextRef key = NULL;
  uint8_t *in = (uint8_t*) serializedKey;
  size_t inSize = strlen(serializedKey);
  SCLError err = SCKeyDeserialize( in, inSize, &key );

  if( key != NULL ) {
    SCKeyFree( key );
  }

  FREE_STRING( jserializedKey, serializedKey );

  return (jint) err;

}

JNIEXPORT jint JNICALL Java_com_silentcircle_scimp_NativePacket_testSCimpSync( JNIEnv *jni, jobject this ) {
//	SCLError err = runSCimpTest(TestSCimpDHCommunication, localUserID, remoteUserID);
//	return (jint) err;
	// TODO: implement this
	return (jint) kSCLError_FeatureNotAvailable;
}

#undef FREE_BYTES
#undef NEW_BYTES
#undef FREE_OUT_STRING
#undef NEW_OUT_STRING
#undef FREE_OUT_BYTES
#undef NEW_OUT_BYTES
#undef FREE_STRING
#undef NEW_STRING
