/*
Copyright © 2012-2013, Silent Circle, LLC.  All rights reserved.

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
//
//  CovergentEncrypt.c
//  tomcrypt
//

#include <stdio.h>
#include <tomcrypt.h>
#include "optest.h"


int covergentEncryptMem(const uint8_t *in, size_t len)
{
    int	err 		= CRYPT_OK;
    hash_state      md;
    symmetric_CBC   CBC;
   
    int             cipher_idx;
    
    uint8_t            key     [64];	
    uint8_t            lookup  [64];	
    
    
    uint8_t IV1[] = {
 		0x0A, 0x0B, 0x0C, 0x0D, 0x0F, 0x10, 0x11, 0x12, 0x14, 0x15, 0x16, 0x17, 0x19, 0x1A, 0x1B, 0x1C
	};
 
    
    sha256_init(&md);
    sha256_process(&md, in,  len);
    sha256_done(&md, key);

    sha256_init(&md);
    sha256_process(&md, key,  sizeof(key));
    sha256_done(&md, lookup);

    cipher_idx = find_cipher("aes");
    
    DO(cbc_start(cipher_idx, IV1,  key, sizeof(key), 0, &CBC));
    
    
//    DO(cbc_encrypt(in, out, len, &CBC));
    
    cbc_done(&CBC);

    
    
    

done:
    return err;
}
