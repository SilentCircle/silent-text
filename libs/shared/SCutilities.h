/*
Copyright © 2012, Silent Circle
All rights reserved.

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
DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#ifndef Included_SCutilities_h 	/* [ */
#define Included_SCutilities_h

#include "SCpubTypes.h"


/* Functions to load and store in network (big) endian format */


void sLoadArray( void *val, size_t len,  uint8_t **ptr );

uint64_t sLoad64( uint8_t **ptr );

uint32_t sLoad32( uint8_t **ptr );

uint16_t sLoad16( uint8_t **ptr );

uint8_t sLoad8( uint8_t **ptr );

void sStorePad( uint8_t pad, size_t len,  uint8_t **ptr );

void sStoreArray( void *val, size_t len,  uint8_t **ptr );

void sStore64( uint64_t val, uint8_t **ptr );

void sStore32( uint32_t val, uint8_t **ptr );

void sStore16( uint16_t val, uint8_t **ptr );

void sStore8( uint8_t val, uint8_t **ptr );

SCLError URL64_encode(uint8_t *in, size_t inlen,  uint8_t *out, size_t * outLen);

SCLError URL64_decode(const uint8_t *in,  size_t inlen, uint8_t *out, size_t *outlen);

size_t URL64_encodeLength(  size_t	inlen);

size_t URL64_decodeLength(  size_t	inlen);


#endif /* Included_scPubTypes_h */ /* ] */

