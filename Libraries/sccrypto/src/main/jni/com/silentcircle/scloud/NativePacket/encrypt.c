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
#include "uint8_t_array.h"
#include "base64.h"
#include <SCloud.h>
#include "scloud_encrypt_parameters.h"
#include "scloud_encrypt_packet.h"
#include "jni_macros.h"
#include "jni_callbacks.h"

JNIEXPORT void JNICALL Java_com_silentcircle_scloud_NativePacket_encrypt( JNIEnv *jni, jobject this, jstring jcontext, jstring jmetaData, jbyteArray jdata ) {

  if( SCloud_enabled != 1 ) { return; }

  jboolean jignore;
  const char *context = (*jni)->GetStringUTFChars( jni, jcontext, &jignore );
  const char *metaData = (*jni)->GetStringUTFChars( jni, jmetaData, &jignore );
  jbyte *data = (*jni)->GetByteArrayElements( jni, jdata, 0 );
  size_t dataSize = (size_t) (*jni)->GetArrayLength( jni, jdata );

  SCloudEncryptParameters *parameters = SCloudEncryptParameters_init();
  parameters->context = uint8_t_array_parse( context );
  parameters->metaData = uint8_t_array_parse( metaData );

  SCloudEncryptPacket *packet = SCloudEncryptPacket_init( parameters );
  uint8_t_array *inData = uint8_t_array_copy( data, dataSize );
  SCLError error;
  if (inData == NULL)
	  error = kSCLError_OutOfMemory;
  else {
	  error = SCloudEncryptPacket_encrypt( packet, inData );
	  uint8_t_array_free( inData );
  }

  if( error == kSCLError_NoErr ) {
    packet->key->items[packet->key->size] = (char) 0;
    //jstring jkey = (*jni)->NewStringUTF( jni, packet->key->items );
    jbyteArray jkey = (*jni)->NewByteArray( jni, sizeof(uint8_t) * packet->key->size );
    if (jkey != NULL) {
    	(*jni)->SetByteArrayRegion( jni, jkey, 0, sizeof(uint8_t) * packet->key->size, (jbyte*) packet->key->items );

    	char base64locator[64];
    	sc_base64_encode( packet->locator->items, packet->locator->size, base64locator, 64 );
    	jstring jlocator = (*jni)->NewStringUTF( jni, base64locator );
    	jbyteArray joutData = (*jni)->NewByteArray( jni, sizeof(uint8_t) * packet->data->size );
    	if (joutData != NULL) {
    		(*jni)->SetByteArrayRegion( jni, joutData, 0, sizeof(uint8_t) * packet->data->size, (jbyte*) packet->data->items );
    		(*jni)->CallVoidMethod( jni, this, onEncrypted, jkey, jlocator, joutData );
    		(*jni)->DeleteLocalRef( jni, joutData );
    	}
    	(*jni)->DeleteLocalRef( jni, jlocator );
    	(*jni)->DeleteLocalRef( jni, jkey );
    }
  } else {
    LOGE("NativePacket#encrypt: Error Code: %d", error );
  }

  SCloudEncryptPacket_free( packet );

  (*jni)->ReleaseByteArrayElements( jni, jdata, data, JNI_ABORT );
  (*jni)->ReleaseStringUTFChars( jni, jmetaData, metaData );
  (*jni)->ReleaseStringUTFChars( jni, jcontext, context );

}
