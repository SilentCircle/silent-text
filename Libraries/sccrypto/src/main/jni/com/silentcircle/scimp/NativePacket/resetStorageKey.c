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
#include "scimp_packet.h"
#include "jni_macros.h"

JNIEXPORT void JNICALL Java_com_silentcircle_scimp_NativePacket_resetStorageKey( JNIEnv *jni, jobject this, jbyteArray joldStorageKey, jstring jcontext, jbyteArray jnewStorageKey ) {

  NEW_STRING( jcontext, context );
  NEW_BYTES( joldStorageKey, oldStorageKey, oldStorageKeySize );
  NEW_BYTES( jnewStorageKey, newStorageKey, newStorageKeySize );

  if ( VERIFY_STRING( jcontext, context )
		  && VERIFY_BYTES( joldStorageKey, oldStorageKey )
		  && VERIFY_BYTES( jnewStorageKey, newStorageKey ) ) {

		uint8_t_array *inOldStorageKey = uint8_t_array_copy( oldStorageKey, oldStorageKeySize );
		if (inOldStorageKey != NULL) {
			SCimpPacket *packet = SCimpPacket_restore( inOldStorageKey, context );
			uint8_t_array_free( inOldStorageKey );

			if (packet != NULL) {
				packet->storageKey = uint8_t_array_copy( newStorageKey, newStorageKeySize );
				SCimpPacket_save( packet );

				SCimpPacket_free( packet );
			}
		}
  }
  FREE_STRING( jcontext, context );
  FREE_BYTES( joldStorageKey, oldStorageKey );
  FREE_BYTES( jnewStorageKey, newStorageKey );

}
