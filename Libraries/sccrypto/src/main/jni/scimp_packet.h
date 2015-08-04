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
#ifndef __SCIMP_PACKET_H__
#define __SCIMP_PACKET_H__ 1

#include <stdint.h>
#include <SCkeys.h>
#include <SCimp.h>
#include "uint8_t_array.h"

#define kSCimpPacket_Flag_INSECURE 0
#define kSCimpPacket_Flag_SECURE 1
#define kSCimpPacket_Action_CONNECT 0
#define kSCimpPacket_Action_SEND    1
#define kSCimpPacket_Action_RECEIVE 2

typedef SCLError (*SCimpPacket_getPrivateKey)( char *locator, SCKeyContextRef outPrivateKey );

typedef struct {
  uint8_t version;
  SCimpContextRef scimp;
  SCLError warning;
  SCLError error;
  int action;
  SCimpState state;
  uint8_t_array *decryptedData;
  uint8_t_array *outgoingData;
  char *context;
  uint8_t_array *storageKey;
  char *secret;
  char *localUserID;
  char *remoteUserID;
  SCimpPacket_getPrivateKey getPrivateKey;
  int notifiable;
  int isPublicKeyData;
} SCimpPacket;

SCimpPacket *SCimpPacket_init( uint8_t_array *storageKey );

void SCimpPacket_free( SCimpPacket *this );

void SCimpPacket_reset( SCimpPacket *this, bool bClearKeys );

SCimpPacket *SCimpPacket_create( uint8_t_array *storageKey, const char *localUserID, const char *remoteUserID );

SCimpPacket *SCimpPacket_restore( uint8_t_array *storageKey, const char *context );

SCLError SCimpPacket_save( SCimpPacket *this );

SCLError SCimpPacket_receivePacket( SCimpPacket *this, uint8_t_array *data );

SCLError SCimpPacket_sendPacket( SCimpPacket *this, uint8_t_array *data );

SCLError SCimpPacket_connect( SCimpPacket *this );

SCLError SCimpPacket_setPrivateKey( SCimpPacket *this, uint8_t_array *privateKey, uint8_t_array *storageKey );

SCLError SCimpPacket_setPublicKey( SCimpPacket *this, uint8_t_array *publicKey );

int SCimpPacket_isSecure( SCimpPacket *this );

int SCimpPacket_isMinimumSecureMethod( SCimpPacket *this, SCimpMethod method );

#endif/*__SCIMP_PACKET_H__*/
