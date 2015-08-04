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
#ifndef __SCIMP_KEYS_H__
#define __SCIMP_KEYS_H__ 1

#include <SCkeys.h>
#include "uint8_t_array.h"

SCLError SCimp_generatePrivateKey( SCKeyContextRef *key, const char *owner, time_t expireAfter );

SCLError SCimp_generatePrivateKeyWithSize( SCKeyContextRef *key, const char *owner, time_t expireAfter, size_t keySize );

SCLError SCimp_generatePrivateKeyWithSizeAndDates( SCKeyContextRef *key, const char *owner, size_t keySize, time_t startDate, time_t expireDate );

SCLError SCimp_exportPrivateKey( SCKeyContextRef in, uint8_t_array *storageKey, uint8_t_array *out );

SCLError SCimp_importPrivateKey( uint8_t_array *in, uint8_t_array *storageKey, SCKeyContextRef *out );

SCLError SCimp_exportPublicKey( SCKeyContextRef in, uint8_t_array *out );

SCLError SCimp_importPublicKey( uint8_t_array *in, SCKeyContextRef *out );

#endif/*__SCIMP_KEYS_H__*/
