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


#include <stdio.h>
#include <ctype.h>

#include "SCutilities.h"

/* Functions to load and store in network (big) endian format */

void sLoadArray( void *val, size_t len,  uint8_t **ptr )
{
    uint8_t *bptr =  *ptr;
    memcpy(val, bptr, len);
    
    *ptr =  bptr + len;
    
}


uint64_t sLoad64( uint8_t **ptr )
{
    uint8_t *bptr = *ptr;
    uint64_t retval = ((uint64_t) bptr[0]<<56)  
    | ((uint64_t) bptr[1]<<48)
    | ((uint64_t) bptr[2]<<40)  
    | ((uint64_t) bptr[3]<<32)  
    | ((uint64_t) bptr[4]<<24) 
    | ((uint64_t) bptr[5]<<16) 
    | ((uint64_t) bptr[6]<<8) 
    | ((uint64_t) bptr[7]);
    
    *ptr =  bptr+sizeof(retval);
    return (retval);
}

 uint32_t sLoad32( uint8_t **ptr )
{
    uint8_t *bptr = *ptr;
    uint32_t retval = (bptr[0]<<24) | (bptr[1]<<16) | (bptr[2]<<8) | bptr[3];
    
    *ptr =  bptr+sizeof(retval);
    return (retval);
}


uint16_t sLoad16( uint8_t **ptr )
{
    uint8_t *bptr = *ptr;
    uint16_t retval = (bptr[0]<<8) | bptr[1];
    
    *ptr =  bptr+sizeof(retval);
    return (retval);
}

uint8_t sLoad8( uint8_t **ptr )
{
    uint8_t *bptr = *ptr;
    uint8_t retval = *bptr;
    
    *ptr =  bptr+sizeof(uint8_t);
    return (retval);
}

void sStoreArray( void *val, size_t len,  uint8_t **ptr )
{
    uint8_t *bptr =  *ptr;
    memcpy(bptr, val, len);
    
    *ptr =  bptr + len;
    
}

void sStorePad( uint8_t pad, size_t len,  uint8_t **ptr )
{
    uint8_t *bptr =  *ptr;
    memset(bptr, pad, len);
    
    *ptr =  bptr + len;
    
}

 
void sStore64( uint64_t val, uint8_t **ptr )
{
    uint8_t *bptr = *ptr;
    *bptr++ = (uint8_t)(val>>56);
    *bptr++ = (uint8_t)(val>>48);
    *bptr++ = (uint8_t)(val>>40);
    *bptr++ = (uint8_t)(val>>32);
    *bptr++ = (uint8_t)(val>>24);
    *bptr++ = (uint8_t)(val>>16);
    *bptr++ = (uint8_t)(val>> 8);
    *bptr++ = (uint8_t)val;
    
    *ptr =  bptr;
}

void sStore32( uint32_t val, uint8_t **ptr )
{
    uint8_t *bptr = *ptr;
    *bptr++ = (uint8_t)(val>>24);
    *bptr++ = (uint8_t)(val>>16);
    *bptr++ = (uint8_t)(val>> 8);
    *bptr++ = (uint8_t)val;
    *ptr =  bptr;
}

void sStore16( uint16_t val, uint8_t **ptr )
{
    uint8_t *bptr = *ptr;
    *bptr++ = (uint8_t)(val>> 8);
    *bptr++ = (uint8_t)val;
    *ptr =  bptr;
}

void sStore8( uint8_t val, uint8_t **ptr )
{
    uint8_t *bptr = *ptr;
    *bptr++ = (uint8_t)val;
    *ptr =  bptr;
}


/**
 base64 Encode a buffer (NUL terminated)
 @param in      The input buffer to encode
 @param inlen   The length of the input buffer
 @param out     [out] The destination of the base64 encoded data
 @param outlen  [in/out] The max size and resulting size
 @return kSCLError_NoErr if successful
 */


static char const sBase64ArmorTable[65] =
"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";


static void
sArmorWord(uint8_t const raw[3], uint8_t armor[4])
{
	armor[0] = sBase64ArmorTable[raw[0] >> 2 & 0x3f];
	armor[1] = sBase64ArmorTable[(raw[0] << 4 & 0x30) + (raw[1] >> 4 & 0x0f)];
	armor[2] = sBase64ArmorTable[(raw[1] << 2 & 0x3c) + (raw[2] >> 6 & 0x03)];
	armor[3] = sBase64ArmorTable[raw[2] & 0x3f];
}



SCLError URL64_encode(uint8_t *in, size_t inlen,  uint8_t *out, size_t * outLen)
{
    SCLError   err = kSCLError_NoErr;
     
    size_t			len;
	size_t          t;
	uint8_t const *	out0 = out;
	int             i;
	uint8_t			padded[3];

    
    ValidateParam(in);
    ValidateParam(out);

	/* Fill the output buffer from the input buffer */
	for (len = 0; len < inlen; len += 3)
	{
		for (i = 0; i < 3; i++)
			padded[i] = len + i < inlen ? in[i] : 0;
		
		sArmorWord(padded, out);
		in += 3;
		out += 4;
	}
	
	/* Now back up and erase any overrun */
	t = (size_t)(inlen - len); 		/* Zero or negative */
	
	out[t] = '\0';

    *outLen =  (out - out0);

done:
    
    return (err); 
    
}


static const unsigned char decodeMap[] =
{
    0xFF, 0xFF, 0xFF, 0xFF,   0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,   0xFF, 0xFF, 0xFF, 0xFF, 
	0xFF, 0xFF, 0xFF, 0xFF,   0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,   0xFF, 0xFF, 0xFF, 0xFF, 
	0xFF, 0xFF, 0xFF, 0xFF,   0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,   0xFF, 0x3e, 0xFF, 0xFF, 
	0x34, 0x35, 0x36, 0x37,   0x38, 0x39, 0x3a, 0x3b, 0x3c, 0x3d, 0xFF, 0xFF,   0xFF, 0xFF, 0xFF, 0xFF, 
	0xFF, 0x00, 0x01, 0x02,   0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a,   0x0b, 0x0c, 0x0d, 0x0e, 
	0x0f, 0x10, 0x11, 0x12,   0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0xFF,   0xFF, 0xFF, 0xFF, 0x3f, 
	0xFF, 0x1a, 0x1b, 0x1c,   0x1d, 0x1e, 0x1f, 0x20, 0x21, 0x22, 0x23, 0x24,   0x25, 0x26, 0x27, 0x28, 
	0x29, 0x2a, 0x2b, 0x2c,   0x2d, 0x2e, 0x2f, 0x30, 0x31, 0x32, 0x33, 0xFF,   0xFF, 0xFF, 0xFF, 0xFF, 
};

/**
 base64 decode a block of memory
 @param in       The base64 data to decode
 @param inlen    The length of the base64 data
 @param out      [out] The destination of the binary decoded data
 @param outlen   [out] The max size and resulting size of the decoded data
 @return kSCLError_NoErr if successful
 */

SCLError URL64_decode(const uint8_t *in,  size_t inlen, uint8_t *out, size_t *outlen) 
{
   	uint8_t     *curpos;
    
    ValidateParam(in     != NULL);
    ValidateParam(out    != NULL);
    ValidateParam(outlen != NULL);
 
    if(outlen) *outlen = 0;
	if(inlen <2) goto error;
	
  	for (curpos = out; inlen >= 2; inlen -= 4,in+=4)
	{
		short a, b, c, d;
 		
		if( isspace(in[0]) || isspace(in[1]) ) break;
 		if((a = decodeMap [(in[0] & 0x7f)]) == 0xFF) goto error;
		if((b = decodeMap [(in[1] & 0x7f)])  == 0xFF) goto error;
 	 	*curpos++ = (a << 2) | (b >> 4);
		if (inlen == 2) break;
        
		if( isspace(in[2])) break;
 		if((c = decodeMap [(in[2] & 0x7f)]) == 0xFF) goto error;
  		*curpos++ = ((b << 4) & 0xf0) | (c >> 2);
 		if (inlen == 3) break;
        
		if( isspace(in[3])) break;
		if((d = decodeMap [(in[3] & 0x7f)]) == 0xFF) goto error;
		*curpos++ = ((c << 6) & 0xc0) | d;
	}
	
    
	if(outlen)
		*outlen = curpos - out;
	return kSCLError_NoErr;
	
error:
 	return kSCLError_CorruptData;
 
}


size_t URL64_encodeLength(  size_t	inlen)
{
 	return (inlen == 0 ? 0 : ((((inlen) + 2) / 3) * 4)) + 1;
}


size_t URL64_decodeLength(  size_t	inlen)
{
    return (3 * inlen) / 4 +2; /* maximum length */

}

