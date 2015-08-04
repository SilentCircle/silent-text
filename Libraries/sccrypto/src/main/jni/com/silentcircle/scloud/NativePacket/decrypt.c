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
#include "scloud_decrypt_parameters.h"
#include "scloud_decrypt_packet.h"
#include "jni_macros.h"
#include "jni_callbacks.h"


JNIEXPORT void JNICALL Java_com_silentcircle_scloud_NativePacket_decrypt( JNIEnv *jni, jobject this, jbyteArray jdata, jbyteArray jkey ) {

  if( SCloud_enabled != 1 ) { return; }

  //jboolean jignore;
  jbyte *data = (*jni)->GetByteArrayElements( jni, jdata, 0 );

  jbyte *key = (*jni)->GetByteArrayElements( jni, jkey, 0 );
  //const char *key = (*jni)->GetStringUTFChars( jni, jkey, &jignore );

  if ( VERIFY_BYTES(jdata, data) && VERIFY_BYTES(jkey, key) ) {
		SCloudDecryptParameters *parameters = SCloudDecryptParameters_init();
//  parameters->key = uint8_t_array_parse( key );
		parameters->key = uint8_t_array_copy(key, (*jni)->GetArrayLength( jni, jkey ));

		SCloudDecryptPacket *packet = SCloudDecryptPacket_init( parameters );
		uint8_t_array *inData = uint8_t_array_copy( data, (*jni)->GetArrayLength( jni, jdata ) );
		if (inData != NULL) {
			SCLError error = SCloudDecryptPacket_decrypt( packet, inData );
			uint8_t_array_free( inData );

			if ( ( error == kSCLError_NoErr ) && (packet->data != NULL) ) {
				jbyteArray joutData = (*jni)->NewByteArray( jni, sizeof(uint8_t) * packet->data->size );
				(*jni)->SetByteArrayRegion( jni, joutData, 0, sizeof(uint8_t) * packet->data->size, (jbyte*) packet->data->items );

				jbyteArray joutMetaData = (*jni)->NewByteArray( jni, sizeof(uint8_t) * packet->metaData->size );
				(*jni)->SetByteArrayRegion( jni, joutMetaData, 0, sizeof(uint8_t) * packet->metaData->size, (jbyte*) packet->metaData->items );

				if ( (joutData != NULL) && (joutMetaData != NULL) )
					(*jni)->CallVoidMethod( jni, this, onDecrypted, joutData, joutMetaData );

				if (joutData != NULL)
					(*jni)->DeleteLocalRef( jni, joutData );
				if (joutMetaData != NULL)
					(*jni)->DeleteLocalRef( jni, joutMetaData );

			} else {
				LOGE( "NativePacket#decrypt: Error Code: %d", error );
			}
		}
		SCloudDecryptPacket_free( packet );
  }

//  (*jni)->ReleaseStringUTFChars( jni, jkey, key );
  if (key != NULL)
	  (*jni)->ReleaseByteArrayElements( jni, jkey, key, JNI_ABORT );
  if (data != NULL)
	  (*jni)->ReleaseByteArrayElements( jni, jdata, data, JNI_ABORT );
}
