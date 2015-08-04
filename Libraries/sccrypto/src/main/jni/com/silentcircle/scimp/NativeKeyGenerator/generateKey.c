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
#include "uint8_t_array.h"
#include "scimp_keys.h"
#include "jni_macros.h"

JNIEXPORT jbyteArray JNICALL Java_com_silentcircle_scimp_NativeKeyGenerator_generateKey( JNIEnv *jni, jobject this, jstring jowner, jbyteArray jstorageKey ) {

  NEW_BYTES( jstorageKey, storageKeyItems, storageKeySize );
  NEW_STRING( jowner, owner );

  jbyteArray joutKey = NULL;
  if ( VERIFY_BYTES( jstorageKey, storageKeyItems ) && VERIFY_STRING( jowner, owner ) ) {
	  uint8_t_array *outKey = uint8_t_array_init();
	  uint8_t_array *storageKey = uint8_t_array_copy( storageKeyItems, storageKeySize );
	  if ( (outKey != NULL) && (storageKey != NULL) ) {
		  SCKeyContextRef key = kInvalidSCKeyContextRef;

		  SCimp_generatePrivateKey( &key, owner, 3600 * 24 * 30 );
		  SCimp_exportPrivateKey( key, storageKey, outKey );

		  joutKey = (*jni)->NewByteArray( jni, outKey->size );
		  if ( joutKey != NULL )
			  (*jni)->SetByteArrayRegion( jni, joutKey, 0, outKey->size, outKey->items );

		  SCKeyFree( key );
	  }
	  //uint8_t_array_free( outKey );
	  uint8_t_array_free( storageKey );
  }
  FREE_STRING( jowner, owner );
  FREE_BYTES( jstorageKey, storageKeyItems );

  return joutKey;

}
