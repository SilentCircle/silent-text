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
#include <SCimp.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "scimp_keys.h"
#include "scimp_packet.h"
#include "uint8_t_array.h"
#include <SCimpPriv.h>

#define SCIMP_PACKET_VERBOSE 0
#if defined(ANDROID)
#include <android/log.h>
#define XPRINTF( tag, format, ... ) __android_log_print( ANDROID_LOG_DEBUG, tag, format, __VA_ARGS__ );
#else
#define XPRINTF( tag, format, ... ) fprintf( stderr, format, __VA_ARGS__ );
#endif

#define __STRCOPY( to, from, length ) if( length < (size_t)-1 ) { to = realloc( to, length + 1 ); if (to != NULL) { memcpy( to, from, length ); to[length] = (char) 0; } }
#define __COPY( to, from, length ) to = uint8_t_array_copy( (void*) from, length );

void SCimpPacket_debug_print(SCimpPacket *packet);

/*static*/SCLError SCimpPacketEventHandler(SCimpContextRef context,
		SCimpEvent *event, void *misc) {

	SCimpPacket *packet = misc;

	switch (event->type) {

	case kSCimpEvent_Transition: {
		SCimpEventTransitionData data = event->data.transData;
		packet->state = data.state;
		switch (data.state) {
		case kSCimpState_Commit: {
			// ...do something?
		}
			break;
		default: {
			// ...don't worry about it.
		}
			break;
		}
	}
		break;

	case kSCimpEvent_SendPacket: {

		packet->action = kSCimpPacket_Action_SEND;
		SCimpEventSendData data = event->data.sendData;
		packet->notifiable = data.shouldPush;
		packet->isPublicKeyData = data.isPKdata;

		if (packet->outgoingData != NULL) {
			uint8_t_array_free(packet->outgoingData);
		}

		__COPY( packet->outgoingData, data.data, data.length);

#if SCIMP_PACKET_VERBOSE
		SCimpPacket_debug_print( packet );
#endif // SCIMP_PACKET_VERBOSE
	}
		break;

	case kSCimpEvent_Decrypted: {

		packet->action = kSCimpPacket_Action_RECEIVE;
		SCimpEventDecryptData data = event->data.decryptData;

		if (packet->decryptedData != NULL) {
			uint8_t_array_free(packet->decryptedData);
		}

		__COPY( packet->decryptedData, data.data, data.length);

#if SCIMP_PACKET_VERBOSE
		uint8_t *decryptS = uint8_t_array_copyToCString( packet->decryptedData );
		XPRINTF( "SCIMP-PACKET", "(%s) DECRYPTED: %s\n", packet->localUserID, decryptS );
		free( decryptS );
#endif // SCIMP_PACKET_VERBOSE
	}
		break;

	case kSCimpEvent_ClearText: {

#if SCIMP_PACKET_VERBOSE
		XPRINTF( "SCIMP-PACKET", "CLEAR TEXT: %s\n", event->data.clearText.data );
#endif // SCIMP_PACKET_VERBOSE
	}
		break;

	case kSCimpEvent_PubData: {
		packet->action = kSCimpPacket_Action_RECEIVE;
		SCimpEventPubData data = event->data.pubData;
		if (packet->decryptedData != NULL) {
			uint8_t_array_free(packet->decryptedData);
		}

		__COPY( packet->decryptedData, data.data, data.length);

#if SCIMP_PACKET_VERBOSE
		uint8_t *decryptS = uint8_t_array_copyToCString( packet->decryptedData );
		XPRINTF( "SCIMP-PACKET", "(%s) PUB DATA: %s\n", packet->localUserID, decryptS );
		free( decryptS );
#endif // SCIMP_PACKET_VERBOSE
	}
		break;

	case kSCimpEvent_Keyed: {

		if (packet->secret != NULL) {
			free(packet->secret);
			packet->secret = NULL;
		}

		SCimpInfo info = event->data.keyedData.info;
		size_t size = 0;
		SCimpGetAllocatedDataProperty(packet->scimp, kSCimpProperty_SASstring,
				(void*) &packet->secret, &size);

		if (packet->outgoingData == NULL) {
			packet->action = kSCimpPacket_Action_CONNECT;
		}

		if (info.scimpMethod == kSCimpMethod_DH) {
			SCimpAcceptSecret(packet->scimp);
		}

	}
		break;

	case kSCimpEvent_ReKeying: {
		// SCimpInfo info = event->data.keyedData.info;
		// TODO: What to do with this information?
	}
		break;

	case kSCimpEvent_NeedsPrivKey: {
		SCimpEventNeedsPrivKeyData data = event->data.needsKeyData;
#if SCIMP_PACKET_VERBOSE
		XPRINTF( "SCIMP-PACKET", "(%s) NEEDS PRIV KEY: %s\n", packet->localUserID, data.locator );
#endif
		if (packet->getPrivateKey != NULL) {
			// we have a callback method provided, use that
			packet->error = packet->getPrivateKey(data.locator, *data.privKey);
		} else {
//          SCimpEventNeedsPrivKeyData  *d =  &event->data.needsKeyData;
//          fprintf( stderr, "NEEDS KEY: %s\n" , data.locator);
#if SCIMP_PACKET_VERBOSE
			XPRINTF( "SCIMP-PACKET", "(%s) NO getPrivateKey CONFIGURED", packet->localUserID );
#endif
			packet->error = kSCLError_KeyNotFound;
		}
	}
		break;

	case kSCimpEvent_AdviseSaveState: {
		SCimpPacket_save(packet);
	}
		break;

	case kSCimpEvent_Error: {
		packet->error = event->data.errorData.error;
	}
		break;

	case kSCimpEvent_Warning: {
		packet->warning = event->data.warningData.warning;
	}
		break;

	default: {
		// ...don't worry about it.
	}
		break;

	}

	return packet->error;

}

SCimpPacket *SCimpPacket_init(uint8_t_array *storageKey) {

	SCimpPacket *packet = malloc(sizeof(SCimpPacket));
	if (packet == NULL)
		return NULL;

	packet->version = 1;
	packet->error = kSCLError_NoErr;
	packet->warning = kSCLError_NoErr;
	packet->storageKey = storageKey;
	packet->outgoingData = NULL;
	packet->decryptedData = NULL;
	packet->context = NULL;
	packet->scimp = NULL;
	packet->secret = NULL;
	packet->localUserID = NULL;
	packet->remoteUserID = NULL;
	packet->getPrivateKey = NULL;
	packet->notifiable = 0;
	packet->isPublicKeyData = 0;
	packet->state = kSCimpState_Init;
	return packet;

}

void SCimpPacket_free(SCimpPacket *packet) {

	if (packet == NULL) {
		return;
	}

	if (packet->outgoingData != NULL) {
		uint8_t_array_free(packet->outgoingData);
		packet->outgoingData = NULL;
	}
	if (packet->decryptedData != NULL) {
		uint8_t_array_free(packet->decryptedData);
		packet->decryptedData = NULL;
	}
	if (packet->scimp != NULL) {
		SCimpFree(packet->scimp);
		packet->scimp = NULL;
	}
	if (packet->context != NULL) {
		free(packet->context);
		packet->context = NULL;
	}
	if (packet->storageKey != NULL) {
		uint8_t_array_free(packet->storageKey);
		packet->storageKey = NULL;
	}
	if (packet->secret != NULL) {
		free(packet->secret);
		packet->secret = NULL;
	}
	if (packet->localUserID != NULL) {
		free(packet->localUserID);
		packet->localUserID = NULL;
	}
	if (packet->remoteUserID != NULL) {
		free(packet->remoteUserID);
		packet->remoteUserID = NULL;
	}

	packet->getPrivateKey = NULL;
	packet->notifiable = 0;
	packet->isPublicKeyData = 0;

	free(packet);
	packet = NULL;

}

void SCimpPacket_reset(SCimpPacket *packet, bool bClearKeys) {
	if (packet == NULL)
		return;
	packet->error = kSCLError_NoErr;
	packet->warning = kSCLError_NoErr;
	if (packet->outgoingData != NULL) {
		uint8_t_array_free(packet->outgoingData);
		packet->outgoingData = NULL;
	}
	if (packet->decryptedData != NULL) {
		uint8_t_array_free(packet->decryptedData);
		packet->decryptedData = NULL;
	}
	if (packet->secret != NULL) {
		free(packet->secret);
		packet->secret = NULL;
	}

	packet->getPrivateKey = NULL;
	packet->notifiable = 0;
	packet->isPublicKeyData = 0;
	packet->state = kSCimpState_Init;

	// reset SCimp context last because it ends up calling our Handler
	if (packet->scimp) {
		if (packet->scimp->scKey && bClearKeys) {
			SCKeyFree(packet->scimp->scKey);
			packet->scimp->scKey = NULL;
		}
		scResetSCimpContext(packet->scimp, true);
		packet->state = packet->scimp->state;
	}
}

SCimpPacket *SCimpPacket_create(uint8_t_array *storageKey,
		const char *localUserID, const char *remoteUserID) {

	SCimpPacket *packet = SCimpPacket_init(storageKey);
	if (packet == NULL)
		return NULL;

	__STRCOPY( packet->localUserID, localUserID, strlen( localUserID ));
	if (remoteUserID != NULL)
		__STRCOPY( packet->remoteUserID, remoteUserID, strlen( remoteUserID ));

#define __IMPORTANT(statement) packet->error = statement; if( packet->error != kSCLError_NoErr ) { return packet; }

	__IMPORTANT( SCimpNew( localUserID, remoteUserID, &packet->scimp ));
	__IMPORTANT(
			SCimpSetNumericProperty( packet->scimp, kSCimpProperty_CipherSuite, kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384 ));
	__IMPORTANT(
			SCimpSetNumericProperty( packet->scimp, kSCimpProperty_SASMethod, kSCimpSAS_PGP ));

	__IMPORTANT(
			SCimpSetEventHandler( packet->scimp, SCimpPacketEventHandler, (void*) packet ));
	__IMPORTANT( SCimpEnableTransitionEvents( packet->scimp, true ));

#undef __IMPORTANT
	packet->state = packet->scimp->state;

	return packet;

}

int SCimpPacket_isMinimumSecureMethod(SCimpPacket *packet, SCimpMethod method) {

	SCimpInfo info;
	SCimpGetInfo(packet->scimp, &info);

	if (!info.isReady) {
		return kSCimpPacket_Flag_INSECURE;
	}

	return packet->scimp->method >= method;

}

int SCimpPacket_isSecure(SCimpPacket *packet) {

	SCimpInfo info;
	SCimpGetInfo(packet->scimp, &info);

	if (!info.isReady) {
		return kSCimpPacket_Flag_INSECURE;
	}

	return SCimpPacket_isMinimumSecureMethod(packet, kSCimpMethod_DH) ?
			kSCimpPacket_Flag_SECURE : kSCimpPacket_Flag_INSECURE;

}

static void captureError(SCimpPacket *packet, SCLError error) {
	if (packet->error == kSCLError_NoErr) {
		packet->error = error;
	}
}
#define CAPTURE_ERROR( from ) captureError( packet, from );

SCLError SCimpPacket_receivePacket(SCimpPacket *packet, uint8_t_array *data) {
	CAPTURE_ERROR(
			SCimpProcessPacket( packet->scimp, (void*) data->items, data->size, (void*) packet ));
	return packet->error;
}

SCLError SCimpPacket_sendPacket(SCimpPacket *packet, uint8_t_array *data) {
	CAPTURE_ERROR(
			SCimpSendMsg( packet->scimp, (void*) data->items, data->size, (void*) packet ));
	return packet->error;
}

SCLError SCimpPacket_connect(SCimpPacket *packet) {

	if (packet->scimp != NULL && packet->scimp->method != kSCimpMethod_DH) {
		// reset the context if method not DH
		SCimpPacket_reset(packet, true);
	}

	CAPTURE_ERROR( SCimpStartDH( packet->scimp ));

	packet->action = kSCimpPacket_Action_CONNECT;

	return packet->error;

}

SCLError SCimpPacket_setPublicKey(SCimpPacket *packet, uint8_t_array *publicKey) {

	SCKeyContextRef remotePublicKey = kInvalidSCKeyContextRef;

	SCimpInfo info;
	ZERO( &info, sizeof(info));
	SCimpGetInfo(packet->scimp, &info);

	if (info.canPKstart) {

		CAPTURE_ERROR( SCimp_importPublicKey( publicKey, &remotePublicKey ));
		// EA: remotePublicKey is ALLOC'd

		if (packet->error == kSCLError_NoErr) {
			time_t now = time(NULL);
			time_t later = now + (60 * 60 * 24 * 30);
			CAPTURE_ERROR(
					SCimpStartPublicKey( packet->scimp, remotePublicKey, later ));
		}

		SCKeyFree(remotePublicKey);

	} else {
		packet->error = kSCLError_KeyExpired;
	}

	ZERO( &info, sizeof(info));

	return packet->error;

}

SCLError SCimpPacket_setPrivateKey(SCimpPacket *packet, uint8_t_array *privateKey,
		uint8_t_array *storageKey) {

	SCKeyContextRef localPrivateKey = kInvalidSCKeyContextRef;
	CAPTURE_ERROR(
			SCimp_importPrivateKey( privateKey, storageKey, &localPrivateKey ));
	if (packet->error == kSCLError_NoErr) {
		CAPTURE_ERROR( SCimpSetPrivateKey( packet->scimp, localPrivateKey ));
		// if we have an error at this point, the private key was not set and needs to be freed
		if ((packet->error != kSCLError_NoErr)
				&& (localPrivateKey != kInvalidSCKeyContextRef))
			SCKeyFree(localPrivateKey);
	}

	return packet->error;

}

SCLError SCimpPacket_save(SCimpPacket *packet) {

	if (packet->error != kSCLError_NoErr) {
		return packet->error;
	}

	void *stateBuffer = NULL;
	size_t stateBufferSize = 0;

	CAPTURE_ERROR(
			SCimpSaveState( packet->scimp, packet->storageKey->items, packet->storageKey->size, &stateBuffer, &stateBufferSize ));

	if (packet->error == kSCLError_NoErr) {
		__STRCOPY( packet->context, stateBuffer, stateBufferSize);
	}

	if (stateBuffer != NULL) {
		XFREE(stateBuffer);
	}

	return packet->error;

}

SCimpPacket *SCimpPacket_restore(uint8_t_array *storageKey, const char *context) {

	SCimpPacket *packet = SCimpPacket_init(storageKey);
	if (packet == NULL)
		return NULL;

#define __IMPORTANT(statement) packet->error = statement; if( packet->error != kSCLError_NoErr ) { return packet; }
	__IMPORTANT(
			SCimpRestoreState( packet->storageKey->items, packet->storageKey->size, (void*) context, strlen( context ), &packet->scimp ));
	__IMPORTANT(
			SCimpSetEventHandler( packet->scimp, SCimpPacketEventHandler, (void*) packet ));
	__IMPORTANT( SCimpEnableTransitionEvents( packet->scimp, true ));
	__STRCOPY( packet->context, context, strlen( context ));
	// set the context
#undef __IMPORTANT

	if (SCimpPacket_isSecure(packet)) {
		if (packet->secret != NULL) {
			free(packet->secret);
			packet->secret = NULL;
		}
		size_t size = 0;
		SCimpGetAllocatedDataProperty(packet->scimp, kSCimpProperty_SASstring,
				(void*) &packet->secret, &size);
	}

	__STRCOPY( packet->localUserID, packet->scimp->meStr,
			strlen( packet->scimp->meStr ));
	__STRCOPY( packet->remoteUserID, packet->scimp->youStr,
			strlen( packet->scimp->youStr ));
	packet->state = packet->scimp->state;

	return packet;
}

void SCimpPacket_debug_print(SCimpPacket *packet) {
	// for debugging
	if (!packet->outgoingData || !packet->outgoingData->items) {
		return;
	}

	unsigned char clearTextS[1024];
	unsigned long clearLen = sizeof(clearTextS);
	ZERO(clearTextS, clearLen);

	uint8_t *data64 = packet->outgoingData->items;
	size_t dataSz = packet->outgoingData->size;

	if (strncmp((char*) data64, "?SCIMP:", 7) == 0) {
		data64 = data64 + 7;
		dataSz -= 7;
	}

	if ( base64_decode(data64, dataSz, clearTextS, &clearLen) == 0 ) {
		clearTextS[clearLen] = 0; // null-terminate the string
		XPRINTF( "SCIMP-PACKET", "(%s) PACKET: %s\n", packet->localUserID, clearTextS );
	} else
		XPRINTF( "SCIMP-PACKET", "(%s) Unable to decode packet", packet->localUserID );
}

#undef CAPTURE_ERROR
#undef __COPY
#undef __STRCOPY
#undef SCIMP_PACKET_VERBOSE
#undef XPRINTF
