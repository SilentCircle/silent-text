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
#include <time.h>
#include "scimp_keys.h"

SCLError SCimp_generatePrivateKey( SCKeyContextRef *key, const char *owner, time_t expireAfter ) {
  const size_t kDefaultKeySize = 414; // 384 // EA: upgraded default from 384
  return SCimp_generatePrivateKeyWithSize( key, owner, expireAfter, kDefaultKeySize );
}

SCLError SCimp_generatePrivateKeyWithSize( SCKeyContextRef *key, const char *owner, time_t expireAfter, size_t keySize ) {
  time_t now = time( NULL );
  time_t later = now + expireAfter;
  return SCimp_generatePrivateKeyWithSizeAndDates( key, owner, keySize, now, later );
}

SCLError SCimp_generatePrivateKeyWithSizeAndDates( SCKeyContextRef *key, const char *owner, size_t keySize, time_t startDate, time_t expireDate ) {

  SCLError err = kSCLError_NoErr;
  ECC_ContextRef ecc = kInvalidECC_ContextRef;
  uint8_t_array *nonce = uint8_t_array_allocate(32);
  sprng_read( nonce->items, nonce->size, NULL );

  err = ECC_Init( &ecc ); CKERR;
  err = ECC_Generate( ecc, keySize ); CKERR;
  err = SCKeyImport_ECC( ecc, nonce->items, nonce->size, key ); CKERR;

  ECC_Free( ecc );
  ecc = kInvalidECC_ContextRef;
  uint8_t_array_free( nonce );

  err = SCKeySetProperty( *key, kSCKeyProp_StartDate,  SCKeyPropertyType_Time,       &startDate,     sizeof( time_t )   ); CKERR;
  err = SCKeySetProperty( *key, kSCKeyProp_ExpireDate, SCKeyPropertyType_Time,       &expireDate,   sizeof( time_t )   ); CKERR;
  err = SCKeySetProperty( *key, kSCKeyProp_Owner,      SCKeyPropertyType_UTF8String, (void*) owner,    strlen( owner )    ); CKERR;

done:

  return err;

}

SCLError SCimp_exportPrivateKey( SCKeyContextRef in, uint8_t_array *storageKey, uint8_t_array *out ) {

  SCLError err = kSCLError_NoErr;

  err = SCKeySerializePrivate( in, storageKey->items, storageKey->size, &out->items, &out->size ); CKERR;

done:

  return err;

}

SCLError SCimp_exportPublicKey( SCKeyContextRef in, uint8_t_array *out ) {

  SCLError err = kSCLError_NoErr;

  err = SCKeySerialize( in, &out->items, &out->size ); CKERR;

done:

  return err;

}

SCLError SCimp_importPrivateKey( uint8_t_array *in, uint8_t_array *storageKey, SCKeyContextRef *out ) {

  SCLError err = kSCLError_NoErr;
  bool isLocked = true;

  err = SCKeyDeserialize( in->items, in->size, out ); CKERR;
  err = SCKeyIsLocked( *out, &isLocked ); CKERR;

  if( isLocked ) {
    err = SCKeyUnlock( *out, storageKey->items, storageKey->size ); CKERR;
  }

done:

  return err;

}

SCLError SCimp_importPublicKey( uint8_t_array *in, SCKeyContextRef *out ) {

  SCLError err = kSCLError_NoErr;

  err = SCKeyDeserialize( in->items, in->size, out ); CKERR;

done:

  return err;

}
