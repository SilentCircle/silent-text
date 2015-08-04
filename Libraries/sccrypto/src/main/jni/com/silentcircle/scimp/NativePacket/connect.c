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
#include "scimp_packet.h"
#include "jni_macros.h"
#include "jni_callbacks.h"

JNIEXPORT void JNICALL Java_com_silentcircle_scimp_NativePacket_connect( JNIEnv *jni, jobject this, jbyteArray jstorageKey, jstring jpacketID, jstring jlocalUserID, jstring jremoteUserID, jstring jcontext ) {

  NEW_BYTES( jstorageKey, storageKeyItems, storageKeySize );
  NEW_STRING( jpacketID, packetID );
  NEW_STRING( jlocalUserID, localUserID );
  NEW_STRING( jremoteUserID, remoteUserID );
  NEW_STRING( jcontext, context );

  if ( VERIFY_BYTES( jstorageKey, storageKeyItems )
		  && VERIFY_STRING( jpacketID, packetID )
		  && VERIFY_STRING( jlocalUserID, localUserID )
		  && VERIFY_STRING( jremoteUserID, remoteUserID )
		  && VERIFY_STRING( jcontext, context ) ) {

		uint8_t_array *storageKey = uint8_t_array_copy( storageKeyItems, storageKeySize );
		if ( storageKey != NULL ) {

			SCimpPacket *packet = NULL;

			if( context != NULL && strlen(context) > 0 ) {
				packet = SCimpPacket_restore( storageKey, context );
			} else {
				packet = SCimpPacket_create( storageKey, localUserID, remoteUserID );
			}

			if (packet != NULL) {
				if( packet->error == kSCLError_NoErr ) {
					SCimpPacket_connect( packet );
				}

				if( packet->error != kSCLError_NoErr ) {
					jint jerror = (jint) packet->error;
					jint jstate = (jint) packet->state;
					(*jni)->CallVoidMethod( jni, this, onError, jstorageKey, jpacketID, jlocalUserID, jremoteUserID, jerror, jstate );
				}

				if( packet->warning != kSCLError_NoErr ) {
					jint jwarning = (jint) packet->warning;
					jint jstate = (jint) packet->state;
					(*jni)->CallVoidMethod( jni, this, onWarning, jstorageKey, jpacketID, jlocalUserID, jremoteUserID, jwarning, jstate );
				}

				switch( packet->action ) {
					case kSCimpPacket_Action_CONNECT: {
						NEW_OUT_BYTES( joutData, packet->outgoingData );
						NEW_OUT_STRING( joutContext, packet->context );
						NEW_OUT_STRING( joutSecret, packet->secret );

						if ( VERIFY_OUT_BYTES( joutData, packet->outgoingData )
								&& VERIFY_OUT_STRING( joutContext, packet->context )
								&& VERIFY_OUT_STRING( joutSecret, packet->secret ) )
						(*jni)->CallVoidMethod( jni, this, onSendPacket, jstorageKey, jpacketID, jlocalUserID, jremoteUserID, joutData, joutContext, joutSecret );

						FREE_OUT_STRING( joutSecret );
						FREE_OUT_STRING( joutContext );
						FREE_OUT_BYTES( joutData );
					}break;

				}

				SCimpPacket_free( packet );
			}
		}
		//uint8_t_array_free( storageKey );
  }
  FREE_STRING( jcontext, context );
  FREE_STRING( jremoteUserID, remoteUserID );
  FREE_STRING( jlocalUserID, localUserID );
  FREE_STRING( jpacketID, packetID );
  FREE_BYTES( jstorageKey, storageKeyItems );
}
