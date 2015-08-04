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
#include <SCloud.h>
#include "uint8_t_array.h"
#include "scloud_encrypt_parameters.h"
#include "scloud_encrypt_packet.h"

SCloudEncryptPacket *SCloudEncryptPacket_init( SCloudEncryptParameters *parameters ) {

  SCloudEncryptPacket *this = malloc( sizeof( SCloudEncryptPacket ) );

  this->version = 1;
  this->parameters = parameters;
  this->key = uint8_t_array_init();
  this->locator = uint8_t_array_init();
  this->data = uint8_t_array_init();

  return this;

}

void SCloudEncryptPacket_free( SCloudEncryptPacket *this ) {
  if( this == NULL ) { return; }
  if( this->parameters != NULL ) { SCloudEncryptParameters_free( this->parameters ); this->parameters = NULL; }
  if( this->data != NULL ) { uint8_t_array_free( this->data ); this->data = NULL; }
  if( this->key != NULL ) { uint8_t_array_free( this->key ); this->key = NULL; }
  if( this->locator != NULL ) { uint8_t_array_free( this->locator ); this->locator = NULL; }
  free( this );
}

SCLError SCloudEncryptPacket_encrypt( SCloudEncryptPacket *this, uint8_t_array *data ) {

  SCLError err = kSCLError_NoErr;

  if( this->parameters->context->items == NULL ) { this->parameters->context->items = malloc(8); }
  if( this->parameters->metaData->items == NULL ) { this->parameters->metaData->items = malloc(16); }

  SCloudContextRef scloud = NULL;

  uint8_t_array *context = this->parameters->context;
  uint8_t_array *metaData = this->parameters->metaData;

  err = SCloudEncryptNew( context->items, context->size, data->items, data->size, metaData->items, metaData->size, SCloudEncryptPacketEventHandler, (void*) this, &scloud ); CKERR;
  err = SCloudCalculateKey( scloud, 1024 ); CKERR;
  err = SCloudEncryptGetKeyBLOB( scloud, &this->key->items, &this->key->size ); CKERR;

  this->locator->size = 256;
  this->locator->items = malloc( this->locator->size ); CKNULL(this->locator->items);
  err = SCloudEncryptGetLocator( scloud, this->locator->items, &this->locator->size ); CKERR;
  this->locator->items = realloc( this->locator->items, this->locator->size ); CKNULL(this->locator->items);

  this->data->size = 0;
  this->data->items = malloc( sizeof(uint8_t) * ( data->size * 4 ) ); CKNULL(this->data->items);
#define CHUNK_SIZE 8 * 1024
  size_t dataSize = CHUNK_SIZE;
  while( err == kSCLError_NoErr ) {
    err = SCloudEncryptNext( scloud, this->data->items + this->data->size, &dataSize );
    if( err == kSCLError_NoErr || err == kSCLError_EndOfIteration ) {
      this->data->size += dataSize;
      dataSize = CHUNK_SIZE;
    }
  }
#undef CHUNK_SIZE
  this->data->items = realloc( this->data->items, this->data->size ); CKNULL(this->data->items);

  if( err == kSCLError_EndOfIteration ) { err = kSCLError_NoErr; }

done:

  if( IsntNull(scloud) ) { SCloudFree(scloud); }

  return err;

}

SCLError SCloudEncryptPacketEventHandler( SCloudContextRef ctx, SCloudEvent* event, void *uservalue ) {
  return kSCLError_NoErr;
}
