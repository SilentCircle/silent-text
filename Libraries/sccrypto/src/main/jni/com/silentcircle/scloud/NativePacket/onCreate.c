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
#include <SCloud.h>
#include "uint8_t_array.h"
#include "scloud_encrypt_parameters.h"
#include "scloud_encrypt_packet.h"
#include "scloud_decrypt_parameters.h"
#include "scloud_decrypt_packet.h"
#include "jni_callbacks.h"

JNIEXPORT void JNICALL Java_com_silentcircle_scloud_NativePacket_onCreate( JNIEnv *jni, jobject this ) {

  jclass jSCloudPacket = (*jni)->GetObjectClass( jni, this );

  onDecrypted = (*jni)->GetMethodID( jni, jSCloudPacket, "onBlockDecrypted", "([B[B)V" );
  onEncrypted = (*jni)->GetMethodID( jni, jSCloudPacket, "onBlockEncrypted", "([BLjava/lang/String;[B)V" );

  SCLError error = kSCLError_NoErr;
  uint8_t_array *expected = uint8_t_array_parse( "Hello, world!" );
  SCloudEncryptParameters *encryptParameters = SCloudEncryptParameters_init();
  encryptParameters->context = uint8_t_array_parse( "example@silentcircle.com" );
  SCloudEncryptPacket *encryptPacket = SCloudEncryptPacket_init( encryptParameters );
  error = SCloudEncryptPacket_encrypt( encryptPacket, expected );
  if( error == kSCLError_NoErr ) {
    SCloudDecryptParameters *decryptParameters = SCloudDecryptParameters_init();
    decryptParameters->key = uint8_t_array_copy( encryptPacket->key->items, encryptPacket->key->size );
    SCloudDecryptPacket *decryptPacket = SCloudDecryptPacket_init( decryptParameters );
    error = SCloudDecryptPacket_decrypt( decryptPacket, encryptPacket->data );
    if( error == kSCLError_NoErr ) {
      uint8_t_array *actual = decryptPacket->data;
      if( expected->size == actual->size && memcmp( expected->items, actual->items, expected->size ) == 0 ) {
        SCloud_enabled = 1;
      }
    }
    SCloudDecryptPacket_free( decryptPacket );
  }
  SCloudEncryptPacket_free( encryptPacket );
  uint8_t_array_free( expected );

}
