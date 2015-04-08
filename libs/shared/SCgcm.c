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

/**
 @file SCgcm.c 
 GCM Encryption wrappers for tomcrypt
 */


#include <stdio.h>
#include <tomcrypt.h>
#include "cryptowrappers.h"

#define CKSTAT {if (status != CRYPT_OK)  goto done; }
 
#define	roundup(x, y)	((((x)+((y)-1))/(y))*(y))
#define MIN_MSG_BLOCKSIZE   32
#define MSG_BLOCKSIZE   16


/**
 Encrypts a block of using tomcrypt gcm functions
 @param key Pointer to the key used to encypt with. twice the size of the cipher (upper half is key, lower half is IV)
 @param keyLen Length in bytes of key
 @param seq  sequence number of message 
 @param seq  Length in bytes of sequence number
 @param in  Pointer to plaintext
 @param inLen  length of plaintext in bytes
 @param outData  Pointer to where to put pointer of allocated cipher text
 @param outSize  Pointer to length of  allocated cipher text
 @param outTag  pointer to MAC tag (typically 16 bytes)
 @param outTag  pointer to length of MAC tag
@return kSCLError_NoErr if successful
 */

SCLError GCM_Encrypt(uint8_t *key, size_t keyLen, 
                     uint8_t *seq, size_t seqLen, 
                     const uint8_t *in, size_t inLen,
                     uint8_t **outData, size_t *outSize, 
                     uint8_t *outTag, size_t *outTagSize)

{
    SCLError err = kSCLError_NoErr;
    int     status = CRYPT_OK;
    
    uint8_t  bytes2Pad;
    uint8_t *buffer = NULL;
    size_t buffLen = 0;
    int IVlen = keyLen >>1;
    unsigned char  T[32];
    unsigned long tagLen = 0;
    
    
    /* calclulate Pad byte */
    if(inLen < MIN_MSG_BLOCKSIZE)
    {
        bytes2Pad =  MIN_MSG_BLOCKSIZE - inLen;
    }
    else
    {
        bytes2Pad =  roundup(inLen, MSG_BLOCKSIZE) +  MSG_BLOCKSIZE - inLen;
    };
    
    buffLen = inLen + bytes2Pad;
    buffer = XMALLOC(buffLen);
    CKNULL(buffer);
    
    memcpy(buffer, in, inLen);
    memset(buffer+inLen, bytes2Pad, bytes2Pad);
    
    tagLen = sizeof(T);
    status = gcm_memory(find_cipher("aes"), 
                        key, IVlen , 
                        key+ IVlen, IVlen, 
                        seq,    seqLen, 
                        buffer, buffLen, 
                        buffer, 
                        T, &tagLen ,
                        GCM_ENCRYPT); CKSTAT;
    
    *outData = buffer;
    *outSize = buffLen;
    memcpy(outTag, T, tagLen);
    *outTagSize = tagLen;
    
done:
    
    if(status != CRYPT_OK)
    {
        if(buffer)
        {
            memset(buffer, buffLen, 0);
            XFREE(buffer);
        }
        err = sCrypt2SCLError(status);
    }
    
    return err;
}


SCLError GCM_Decrypt(uint8_t *key,  size_t keyLen, 
                     uint8_t *seq,  size_t seqLen, 
                     uint8_t *in,   size_t inLen,
                     uint8_t *tag,      size_t tagSize, 
                     uint8_t **outData, size_t *outSize)
{
    SCLError err = kSCLError_NoErr;
    int     status = CRYPT_OK;
    
    uint8_t *buffer = NULL;
    size_t buffLen = inLen;
    int IVlen = keyLen >>1;
    uint8_t  bytes2Pad = 0;
    
    unsigned char  T[32];
    unsigned long tagLen = sizeof(T);
    
    buffer = XMALLOC(buffLen);
    CKNULL(buffer);
    
    status = gcm_memory(find_cipher("aes"), 
                        key, IVlen , 
                        key+ IVlen, IVlen, 
                        seq, seqLen, 
                        buffer, buffLen, 
                        in, 
                        T, &tagLen ,
                        GCM_DECRYPT);CKSTAT;
    
    if( tagLen != tagSize || (memcmp(T,tag,tagLen) != 0)) 
        RETERR(kSCLError_CorruptData);
    
    bytes2Pad = *(buffer+buffLen-1);
    
    *outData = buffer;
    *outSize = buffLen- bytes2Pad;
    
done:
    if(status != CRYPT_OK || err != kSCLError_NoErr)
    {
        if(buffer)
        {
            memset(buffer, buffLen, 0);
            XFREE(buffer);
        }
        
        err = IsSCLError(err)?err:sCrypt2SCLError(status);
    }
    
    
    return err;
}

