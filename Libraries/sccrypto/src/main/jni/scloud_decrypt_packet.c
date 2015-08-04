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
#include <stdlib.h>
#include <string.h>
#include <SCloud.h>
#include "uint8_t_array.h"
#include "scloud_decrypt_parameters.h"
#include "scloud_decrypt_packet.h"

SCloudDecryptPacket *SCloudDecryptPacket_init(
		SCloudDecryptParameters *parameters) {

	SCloudDecryptPacket *scloud = malloc(sizeof(SCloudDecryptPacket));
	if (scloud != NULL) {
		scloud->version = 1;
		scloud->parameters = parameters;
		scloud->data = uint8_t_array_init();
		scloud->metaData = uint8_t_array_init();
	}
	return scloud;

}

void SCloudDecryptPacket_free(SCloudDecryptPacket *scloud) {

	if (scloud == NULL) {
		return;
	}

	if (scloud->parameters != NULL) {
		SCloudDecryptParameters_free(scloud->parameters);
		scloud->parameters = NULL;
	}
	if (scloud->data != NULL) {
		uint8_t_array_free(scloud->data);
		scloud->data = NULL;
	}
	if (scloud->metaData != NULL) {
		uint8_t_array_free(scloud->metaData);
		scloud->metaData = NULL;
	}

	free(scloud);

}

SCLError SCloudDecryptPacket_decrypt(SCloudDecryptPacket *scloud, uint8_t_array *data) {

	SCLError err = kSCLError_NoErr;
	SCloudContextRef scloudNew = NULL;
	uint8_t_array *key = scloud->parameters->key;

	err = SCloudDecryptNew(key->items, key->size, SCloudDecryptPacketEventHandler, (void*) scloud, &scloudNew); CKERR;
	err = SCloudDecryptNext(scloudNew, data->items, data->size); CKERR;

	done:
		if (IsntNull(scloudNew)) {
			SCloudFree(scloudNew);
		}

	return err;

}

SCLError SCloudDecryptPacketEventHandler(SCloudContextRef ctx,
		SCloudEvent* event, void *uservalue) {

	SCloudDecryptPacket *packet = uservalue;

	switch (event->type) {

	case kSCloudEvent_DecryptedData: {

		SCloudEventDecryptData *d = &event->data.decryptData;
		uint8_t_array *out = packet->data;

		size_t newSize = out->size + d->length;
		if (newSize < out->size) {
			// This implies an unsigned long wrap! protect against a wrap
			return kSCLError_OutOfMemory;
		}

		out->items = realloc(out->items, newSize);
		if (out->items == NULL)
			return kSCLError_OutOfMemory;

		memcpy(out->items + out->size, d->data, newSize - out->size);
		out->size = newSize;
	}
		break;

	case kSCloudEvent_DecryptedMetaData: {

		SCloudEventDecryptMetaData *d = &event->data.metaData;
		uint8_t_array *out = packet->metaData;

		size_t newSize = out->size + d->length;
		if (newSize < out->size) {
			// This implies an unsigned long wrap! protect against a wrap
			return kSCLError_OutOfMemory;
		}

		out->items = realloc(out->items, newSize);
		if (out->items == NULL)
			return kSCLError_OutOfMemory;

		memcpy(out->items + out->size, d->data, newSize - out->size);
		out->size = newSize;

	}
		break;

	default: {
		// Do nothing.
	}
		break;

	}

	return kSCLError_NoErr;

}
