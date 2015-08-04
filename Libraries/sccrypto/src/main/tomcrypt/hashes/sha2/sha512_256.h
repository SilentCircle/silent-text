 
const struct ltc_hash_descriptor sha512_256_desc =
{
    "sha512/256",
    19,
    32,
    128,
    
    /* OID */
    { 2, 16, 840, 1, 101, 3, 4, 2, 6,  },
    9,
    
   
    &sha512_256_init,
    &sha512_process,
    &sha512_256_done,
    &sha512_256_test,
    NULL
};

 
/**
 Initialize the hash state
 @param md   The hash state you wish to initialize
 @return CRYPT_OK if successful
 */
int sha512_256_init(hash_state * md)
{
    LTC_ARGCHK(md != NULL);
    
    md->sha512.curlen = 0;
    md->sha512.length = 0;
    md->sha512.state[0] = CONST64(0x22312194FC2BF72C);
    md->sha512.state[1] = CONST64(0x9F555FA3C84C64C2);
    md->sha512.state[2] = CONST64(0x2393B86B6F53B151);
    md->sha512.state[3] = CONST64(0x963877195940EABD);
    md->sha512.state[4] = CONST64(0x96283EE2A88EFFE3);
    md->sha512.state[5] = CONST64(0xBE5E1E2553863992);
    md->sha512.state[6] = CONST64(0x2B0199FC2C85B8AA);
    md->sha512.state[7] = CONST64(0x0EB72DDC81C52CA2);
     
    return CRYPT_OK;
}

/**
 Terminate the hash to get the digest
 @param md  The hash state
 @param out [out] The destination of the hash (48 bytes)
 @return CRYPT_OK if successful
 */
int sha512_256_done(hash_state * md, unsigned char *out)
{
    unsigned char buf[64];
    
    LTC_ARGCHK(md  != NULL);
    LTC_ARGCHK(out != NULL);
    
    if (md->sha512.curlen >= sizeof(md->sha512.buf)) {
        return CRYPT_INVALID_ARG;
    }
    
    sha512_done(md, buf);
    XMEMCPY(out, buf, 32);
#ifdef LTC_CLEAN_STACK
    zeromem(buf, sizeof(buf));
#endif
    return CRYPT_OK;
}

/**
 Self-test the hash
 @return CRYPT_OK if successful, CRYPT_NOP if self-tests have been disabled
 */  
int  sha512_256_test(void)
{
#ifndef LTC_TEST
    return CRYPT_NOP;
#else    
         
    int i;
     hash_state md;
 
    uint8_t tmp[32];
    
    static const struct {
        char *msg;
        unsigned char hash[32];
    } tests[] = {
        { "abc",
            {   0x53, 0x04, 0x8e, 0x26, 0x81, 0x94, 0x1e, 0xf9, 
                0x9b, 0x2e, 0x29, 0xb7, 0x6b, 0x4c, 0x7d, 0xab, 
                0xe4, 0xc2, 0xd0, 0xc6, 0x34, 0xfc, 0x6d, 0x46, 
                0xe0, 0xe2, 0xf1, 0x31, 0x07, 0xe7, 0xaf, 0x23 }
        },
        { "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu",
            {   0x39, 0x28, 0xe1, 0x84, 0xfb, 0x86, 0x90, 0xf8, 
                0x40, 0xda, 0x39, 0x88, 0x12, 0x1d, 0x31, 0xbe, 
                0x65, 0xcb, 0x9d, 0x3e, 0xf8, 0x3e, 0xe6, 0x14, 
                0x6f, 0xea, 0xc8, 0x61, 0xe1, 0x9b, 0x56, 0x3a
             }
        },
    };

     for (i = 0; i < (int)(sizeof(tests) / sizeof(tests[0])); i++) {
        sha512_256_init(&md);
        sha512_256_process(&md, (unsigned char *)tests[i].msg, (unsigned long)strlen(tests[i].msg));
        sha512_256_done(&md, tmp);
           
         if (XMEMCMP(tmp, tests[i].hash, 32) != 0) {
            return CRYPT_FAIL_TESTVECTOR;
        }
    }

     
     
     return CRYPT_OK;
#endif
}






/* $Source$ */
/* $Revision$ */
/* $Date$ */
