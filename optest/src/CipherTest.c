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
#include <stdint.h>
#include <tomcrypt.h>
#include "optest.h"


typedef struct  {
	int         algor;
    int         keysize;
    uint8_t        *key;
    uint8_t*       PT;			/* Plaintext			*/
    size_t		PTlen;
    uint8_t*       IV;			/* Init Vector			*/
    uint8_t*       EBC;		/* EBC	Known Answer	*/
    size_t		EBClen;
    uint8_t*       CBC;		/* CBC Known Answer		*/
    size_t		CBClen;
  } katvector;

char* cipher_name(int idx)
{
    LTC_MUTEX_LOCK(&ltc_cipher_mutex);
    if (idx < 0 || idx >= TAB_SIZE || cipher_descriptor[idx].name == NULL) {
        LTC_MUTEX_UNLOCK(&ltc_cipher_mutex);
        return NULL;
    }
    LTC_MUTEX_UNLOCK(&ltc_cipher_mutex);
    return cipher_descriptor[idx].name;
}



static int RunCipherKAT(  katvector *kat)

{
    int err = CRYPT_OK;
    char* name = NULL;
    uint8_t *out = NULL;
    
    size_t  alloc_len =   MAX(kat->EBClen, kat->CBClen);
    
    symmetric_ECB ECB;
    symmetric_CBC CBC;
    
    out = malloc(alloc_len); 
    ZERO(out, alloc_len);
    
    
    //   err = cipher_is_valid(kat->algor); CKERR;
    
    name = cipher_name(kat->algor);
    
    printf("\t%-7s %d ", name, kat->keysize);
    
    printf("%6s", "ECB");
    
    DO( ecb_start(kat->algor, kat->key, kat->keysize>>3, 0, &ECB));
    
    DO( ecb_encrypt(kat->PT, out, kat->PTlen, &ECB))
    
    /* check against know-answer */
    DO( compareResults( kat->EBC, out, kat->EBClen , kResultFormat_Byte, "Symmetric Encrypt"));
    
    DO(ecb_decrypt(out, out, kat->PTlen, &ECB));
    
    /* check against orginal plain-text  */
    DO(compareResults( kat->PT, out, kat->PTlen , kResultFormat_Byte, "Symmetric Decrypt"));
    
    
    printf("%6s", "CBC");
    
    DO(cbc_start(kat->algor, kat->IV,  kat->key, kat->keysize>>3, 0, &CBC));
    
    DO(cbc_encrypt(kat->PT, out, kat->PTlen, &CBC));
    
    /* check against know-answer */
    DO(compareResults( kat->CBC, out, kat->CBClen , kResultFormat_Byte, "Symmetric Encrypt"));
    
    // reset CBC befire decrypt*/
    cbc_done(&CBC);
    DO(cbc_start(kat->algor, kat->IV,  kat->key, kat->keysize>>3, 0, &CBC));
    
    DO(cbc_decrypt(out, out, kat->PTlen, &CBC));
    
    /* check against orginal plain-text  */
    DO( compareResults( kat->PT, out, kat->PTlen , kResultFormat_Byte, "Symmetric Decrypt"));
    
done:
    
    ecb_done(&ECB);
    cbc_done(&CBC);
    
    free(out);
    
    printf("\n");
    return err;
}


int TestCiphers()
{
    int err = CRYPT_OK;
    int idx;
    
    unsigned int		i;
    
    uint8_t P1[512];
    
    /* Test vectors for ECB known answer test */
    /* AES 128 bit key */
    uint8_t K1[] = {
		0x00, 0x01, 0x02, 0x03, 0x05, 0x06, 0x07, 0x08,
		0x0A, 0x0B, 0x0C, 0x0D, 0x0F, 0x10, 0x11, 0x12
	};
    
    uint8_t IV1[] = {
 		0x0A, 0x0B, 0x0C, 0x0D, 0x0F, 0x10, 0x11, 0x12, 0x14, 0x15, 0x16, 0x17, 0x19, 0x1A, 0x1B, 0x1C
	};
    
    uint8_t Cebc1[] = {
		0xc7, 0xb1, 0x3e, 0x86, 0xa2, 0x16, 0xe2, 0x9c, 0x52, 0x2a, 0x5d, 0x12, 0x97, 0xe5, 0x6c, 0x49, 
		0x1d, 0xf9, 0x0c, 0xd4, 0x73, 0x3a, 0xbc, 0x69, 0x86, 0x66, 0x4e, 0x11, 0xf3, 0x1a, 0x54, 0xd2, 
		0x47, 0xc2, 0xe0, 0x0e, 0xdb, 0x0a, 0x54, 0x3b, 0x01, 0x0e, 0x45, 0x97, 0x4d, 0x9e, 0x31, 0x08, 
		0x35, 0x18, 0x5c, 0xf3, 0x07, 0x86, 0xac, 0xa4, 0x7e, 0x3b, 0x60, 0x30, 0x53, 0xd0, 0x3f, 0x1c, 
	};
    
    uint8_t Ccbc1[] = {
        0x7e, 0x0c, 0xd0, 0x7e, 0x6d, 0xd9, 0xb8, 0x5a, 0xba, 0xf7, 0x66, 0x3c, 0xa6, 0xb2, 0xe4, 0x36, 
        0x6e, 0x8c, 0x2f, 0xcf, 0x57, 0xd5, 0x77, 0xba, 0x75, 0xa8, 0xb4, 0x4d, 0x23, 0x40, 0xa7, 0x88, 
        0x16, 0x30, 0x22, 0x48, 0x7d, 0x70, 0xd2, 0x9f, 0x21, 0xac, 0x79, 0x7f, 0x83, 0x50, 0x36, 0x25, 
        0xa7, 0xd9, 0xf9, 0xdd, 0x74, 0xe5, 0xc0, 0x6c, 0xc6, 0x25, 0x0d, 0x8f, 0x5d, 0xd0, 0xde, 0xc6, 
	};
 	
   	
    /* AES 192 bit key */
    uint8_t K2[] = {
		0x00, 0x01, 0x02, 0x03, 0x05, 0x06, 0x07, 0x08,
		0x0A, 0x0B, 0x0C, 0x0D, 0x0F, 0x10, 0x11, 0x12,
		0x14, 0x15, 0x16, 0x17, 0x19, 0x1A, 0x1B, 0x1C
	};
    uint8_t Cebc2[] = {
		0x11, 0x40, 0x98, 0x78, 0x0a, 0x5c, 0xda, 0xb5, 0xec, 0xe2, 0x24, 0x04, 0x73, 0x29, 0x3c, 0xfa, 
		0x9e, 0xfa, 0x77, 0xa0, 0x36, 0x44, 0xde, 0x99, 0xe5, 0x71, 0xa5, 0xb5, 0x80, 0x6e, 0xc0, 0x91, 
		0x0f, 0xd9, 0x51, 0x4d, 0x6e, 0x43, 0x23, 0x82, 0x7a, 0x51, 0xd8, 0xd9, 0xf7, 0x3d, 0xb7, 0xa5, 
		0x54, 0x35, 0x2e, 0x6d, 0x4f, 0x89, 0xfe, 0xe5, 0x9b, 0x9d, 0x33, 0xff, 0xde, 0x68, 0xe6, 0x7f 
	};
    
    uint8_t Ccbc2[] = {
        0xb8, 0x66, 0xd6, 0xca, 0x74, 0xfe, 0xb4, 0x4e, 0x2a, 0x51, 0xfa, 0xf3, 0x83, 0xfe, 0x09, 0xb9, 
        0xc5, 0x63, 0x8b, 0xec, 0x5d, 0x5c, 0xc1, 0x5e, 0x65, 0x89, 0x9e, 0x9f, 0x1f, 0x94, 0x85, 0xb1, 
        0x6a, 0xd7, 0x51, 0x1b, 0x35, 0x69, 0xfe, 0x09, 0x73, 0x24, 0xd4, 0xa4, 0x9d, 0x5f, 0xf5, 0x84, 
        0x7e, 0x2a, 0x47, 0x4e, 0x39, 0x7a, 0x35, 0xa8, 0x95, 0xb3, 0x31, 0x1b, 0x81, 0xca, 0xb1, 0x5c, 
	};
    
	
    /* AES 256 bit key */
    uint8_t K3[] = {
		0x00, 0x01, 0x02, 0x03, 0x05, 0x06, 0x07, 0x08,
		0x0A, 0x0B, 0x0C, 0x0D, 0x0F, 0x10, 0x11, 0x12,
		0x14, 0x15, 0x16, 0x17, 0x19, 0x1A, 0x1B, 0x1C,
		0x1E, 0x1F, 0x20, 0x21, 0x23, 0x24, 0x25, 0x26
	};
    uint8_t Cebc3[] = {
		0xda, 0xd2, 0xa9, 0x13, 0x2f, 0x24, 0xf9, 0x97, 0x93, 0xfe, 0x81, 0x10, 0x4a, 0xd5, 0x8a, 0x63, 
		0xa9, 0x1a, 0x1f, 0x49, 0xb9, 0x9c, 0xd8, 0x37, 0x0a, 0x5c, 0xa9, 0xae, 0x55, 0xcb, 0x17, 0xee, 
		0x01, 0xa8, 0xda, 0x61, 0x41, 0x0b, 0xca, 0xaa, 0xda, 0x5d, 0xdf, 0xfd, 0x8b, 0xea, 0xc7, 0x09, 
		0x0d, 0x22, 0x1f, 0xef, 0x3f, 0x03, 0x16, 0x02, 0xfa, 0x87, 0xf0, 0x47, 0x73, 0xde, 0x77, 0xd4, 
	};
    
    uint8_t Ccbc3[] = {
        0x2c, 0x93, 0x91, 0xa6, 0xc1, 0x22, 0x1b, 0xe6, 0x6f, 0x49, 0x4b, 0x07, 0x18, 0x17, 0x97, 0xd9, 
        0x9f, 0x52, 0xac, 0xa2, 0x99, 0x4c, 0x25, 0x9e, 0x3e, 0x3e, 0xa5, 0xa1, 0x11, 0xa4, 0xe7, 0x84, 
        0x89, 0xa0, 0x1a, 0x5c, 0xff, 0x12, 0xf5, 0x39, 0xc0, 0xa6, 0x8d, 0x4f, 0x30, 0x6a, 0x2f, 0x1e, 
        0x87, 0xec, 0x63, 0x52, 0x7d, 0xf7, 0x86, 0x40, 0x28, 0xa1, 0x89, 0xbd, 0x1d, 0xb5, 0xc3, 0x00, 
	};
 	
    printf("\nTesting Ciphers\n");
 
    register_cipher (&aes_desc);
  
    if ((idx = find_cipher("aes")) == -1) {
        if ((idx = find_cipher("rijndael")) == -1) {
            return CRYPT_NOP;
        }
    }
      
    katvector kat_vector_array[] = 
	{
        {	idx, 128,	K1, P1, 64,	 IV1, Cebc1, sizeof(Cebc1),  Ccbc1, sizeof(Ccbc1) },
        {	idx, 192,	K2, P1, 64,  IV1, Cebc2, sizeof(Cebc2),  Ccbc2, sizeof(Ccbc2)},
        {	idx, 256,   K3, P1, 64,  IV1, Cebc3, sizeof(Cebc3),  Ccbc3, sizeof(Ccbc3)},		
	};
 
    
    /* init the P1 */
	for (i = 0; i < sizeof(P1) ; i++) P1[i] = i;
    
    /* run  known answer tests (KAT) */
	for (i = 0; i < sizeof(kat_vector_array)/ sizeof(katvector) ; i++)
	{
        DO( RunCipherKAT( &kat_vector_array[i] ));
        
	}
    
    return err;
}


typedef struct  {
    int         algor;
    int         keysize;
    uint64_t    *key;
    uint64_t    *tweek;
    uint64_t*   PT;			/* Plaintext			*/
    size_t		PTlen;
    uint64_t*   STOR;		/* Storage Known Answer		*/
    size_t      STORlen;
} storage_katvector;


int RunStorageCipherKAT(  storage_katvector *kat)

{
    int err = CRYPT_OK;
    char*   name = NULL;
    uint64_t *out = NULL;
     
    symmetric_key KEY;
    
    out = malloc(kat->STORlen); 
    ZERO(out, kat->STORlen);
    
    name = cipher_name(kat->algor);
    
    printf("\t%-7s %d ", name, kat->keysize);
    
    DO( threefish_setup_key(kat->key, kat->keysize, kat->tweek, &KEY));
     
    DO( threefish_word_encrypt(kat->PT, out, &KEY))
    
      /* check against know-answer */
    DO( compareResults( kat->STOR, out, kat->STORlen , kResultFormat_Long, "Word Encrypt"));
    
    DO( threefish_word_decrypt(out, out, &KEY))
    
    /* check against orginal plain-text  */
    DO( compareResults( kat->PT, out, kat->STORlen , kResultFormat_Long, "Word Decrypt"));
        
done:
    
    threefish_done(&KEY);
      
    free(out);
    
    printf("\n");
    return err;
}

int TestStorageCiphers()
{
    int err = CRYPT_OK;
    int idx;
    unsigned int		i;

     

    static uint64_t K1[] = { 0L, 0L, 0L, 0L };
    static uint64_t P1[] = { 0L, 0L, 0L, 0L };
    static uint64_t C1[] = { 0x94EEEA8B1F2ADA84L, 0xADF103313EAE6670L, 0x952419A1F4B16D53L, 0xD83F13E63C9F6B11L };
    static uint64_t T1[] = { 0L, 0L };
 
    static uint64_t K2[] = { 0x1716151413121110L, 0x1F1E1D1C1B1A1918L,  0x2726252423222120L, 0x2F2E2D2C2B2A2928L };
    static uint64_t P2[] = { 0xF8F9FAFBFCFDFEFFL, 0xF0F1F2F3F4F5F6F7L,  0xE8E9EAEBECEDEEEFL, 0xE0E1E2E3E4E5E6E7L };
    static uint64_t C2[] = { 0XDF8FEA0EFF91D0E0L, 0XD50AD82EE69281C9L, 0X76F48D58085D869DL, 0XDF975E95B5567065L };
    static uint64_t T2[] = { 0x0706050403020100L, 0x0F0E0D0C0B0A0908L };
 
    static uint64_t K3[] = { 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L };
    static uint64_t P3[] = { 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L };
    static uint64_t T3[] = { 0L, 0L };
    static uint64_t C3[] = { 0xBC2560EFC6BBA2B1L, 0xE3361F162238EB40L, 0xFB8631EE0ABBD175L, 0x7B9479D4C5479ED1L, 
                             0xCFF0356E58F8C27BL, 0xB1B7B08430F0E7F7L, 0xE9A380A56139ABF1L, 0xBE7B6D4AA11EB47EL };
    
    static uint64_t K4[] = { 0x1716151413121110L, 0x1F1E1D1C1B1A1918L, 0x2726252423222120L, 0x2F2E2D2C2B2A2928L, 
                             0x3736353433323130L, 0x3F3E3D3C3B3A3938L, 0x4746454443424140L, 0x4F4E4D4C4B4A4948L };
    static uint64_t P4[] = { 0xF8F9FAFBFCFDFEFFL, 0xF0F1F2F3F4F5F6F7L, 0xE8E9EAEBECEDEEEFL, 0xE0E1E2E3E4E5E6E7L, 
                             0xD8D9DADBDCDDDEDFL, 0xD0D1D2D3D4D5D6D7L, 0xC8C9CACBCCCDCECFL, 0xC0C1C2C3C4C5C6C7L };
    static uint64_t T4[] = { 0x0706050403020100L, 0x0F0E0D0C0B0A0908L };
    static uint64_t C4[] = { 0x2C5AD426964304E3L, 0x9A2436D6D8CA01B4L, 0xDD456DB00E333863L, 0x794725970EB9368BL, 
                             0x043546998D0A2A27L, 0x25A7C918EA204478L, 0x346201A1FEDF11AFL, 0x3DAF1C5C3D672789L };
    
    static uint64_t K5[] = { 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L };
    static uint64_t P5[] = { 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L, 0L };
    static uint64_t T5[] = { 0L, 0L };
    static uint64_t C5[] = { 0x04B3053D0A3D5CF0L, 0x0136E0D1C7DD85F7L, 0x067B212F6EA78A5CL, 0x0DA9C10B4C54E1C6L,
                            0x0F4EC27394CBACF0L, 0x32437F0568EA4FD5L, 0xCFF56D1D7654B49CL, 0xA2D5FB14369B2E7BL, 
                            0x540306B460472E0BL, 0x71C18254BCEA820DL, 0xC36B4068BEAF32C8L, 0xFA4329597A360095L, 
                            0xC4A36C28434A5B9AL, 0xD54331444B1046CFL, 0xDF11834830B2A460L, 0x1E39E8DFE1F7EE4FL  }; 
                        
    static uint64_t K6[] = { 0x1716151413121110L, 0x1F1E1D1C1B1A1918L, 0x2726252423222120L, 0x2F2E2D2C2B2A2928L, 
                            0x3736353433323130L, 0x3F3E3D3C3B3A3938L, 0x4746454443424140L, 0x4F4E4D4C4B4A4948L, 
                            0x5756555453525150L, 0x5F5E5D5C5B5A5958L, 0x6766656463626160L, 0x6F6E6D6C6B6A6968L, 
                            0x7776757473727170L, 0x7F7E7D7C7B7A7978L, 0x8786858483828180L, 0x8F8E8D8C8B8A8988L };
    static uint64_t P6[] = { 0xF8F9FAFBFCFDFEFFL, 0xF0F1F2F3F4F5F6F7L, 0xE8E9EAEBECEDEEEFL, 0xE0E1E2E3E4E5E6E7L, 
                            0xD8D9DADBDCDDDEDFL, 0xD0D1D2D3D4D5D6D7L, 0xC8C9CACBCCCDCECFL, 0xC0C1C2C3C4C5C6C7L, 
                            0xB8B9BABBBCBDBEBFL, 0xB0B1B2B3B4B5B6B7L, 0xA8A9AAABACADAEAFL, 0xA0A1A2A3A4A5A6A7L, 
                            0x98999A9B9C9D9E9FL, 0x9091929394959697L, 0x88898A8B8C8D8E8FL, 0x8081828384858687L };
    static uint64_t T6[] = { 0x0706050403020100L, 0x0F0E0D0C0B0A0908L };
    static uint64_t C6[] = { 0xB0C33CD7DB4D65A6L, 0xBC49A85A1077D75DL, 0x6855FCAFEA7293E4L, 0x1C5385AB1B7754D2L, 
                            0x30E4AAFFE780F794L, 0xE1BBEE708CAFD8D5L, 0x9CA837B7423B0F76L, 0xBD1403670D4963B3L, 
                            0x451F2E3CE61EA48AL, 0xB360832F9277D4FBL, 0x0AAFC7A65E12D688L, 0xC8906E79016D05D7L, 
                            0xB316570A15F41333L, 0x74E98A2869F5D50EL, 0x57CE6F9247432BCEL, 0xDE7CDD77215144DEL  };


	     
    printf("\nTesting Storage Ciphers\n");
    
    register_cipher (&threefish_desc);
    
    if ((idx = find_cipher("threefish")) == -1) {
             return CRYPT_NOP;
        }
    
    storage_katvector storage_kat_vector_array[] = 
	{
        { idx, 256,	K1, T1,	P1, sizeof(P1), C1, sizeof(C1) },
        { idx, 256,	K2, T2,	P2, sizeof(P2), C2, sizeof(C2) },
        
        { idx, 512,	K3, T3,	P3, sizeof(P3), C3, sizeof(C3) },
        { idx, 512,	K4, T4,	P4, sizeof(P4), C4, sizeof(C4) },
        
        { idx, 1024,K5, T5,	P5, sizeof(P5), C5, sizeof(C5) },
        { idx, 1024,K6, T6,	P6, sizeof(P6), C6, sizeof(C6) } 
    };
     
    /* run  known answer tests (KAT) */
  	for (i = 0; i < sizeof(storage_kat_vector_array)/ sizeof(storage_katvector) ; i++)
	{
        DO( RunStorageCipherKAT( &storage_kat_vector_array[i] ));
        
	}

 
    return err;
    
}


