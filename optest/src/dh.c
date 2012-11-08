/*  Off-the-Record Messaging library
 *  Copyright (C) 2004-2008  Ian Goldberg, Chris Alexander, Nikita Borisov
 *                           <otr@cypherpunks.ca>
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of version 2.1 of the GNU Lesser General
 *  Public License as published by the Free Software Foundation.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 
 
 1  - rewrite to use tomcrypt  - vin 
 
 */




#include <stdio.h>
#include <stdint.h>
#include "tomcrypt.h"
#include "dh.h"

#include "optest.h"

static const char* DH1536_MODULUS_S = ""
"FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1"
"29024E088A67CC74020BBEA63B139B22514A08798E3404DD"
"EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245"
"E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED"
"EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3D"
"C2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F"
"83655D23DCA3AD961C62F356208552BB9ED529077096966D"
"670C354E4ABC9804F1746C08CA237327FFFFFFFFFFFFFFFF";
static const char *DH1536_GENERATOR_S = "02";
static const int DH1536_MOD_LEN_BITS = 1536;
static const int DH1536_MOD_LEN_BYTES = 192;


static gcry_mpi_t DH1536_MODULUS = NULL;
static gcry_mpi_t DH1536_MODULUS_MINUS_2 = NULL;
static gcry_mpi_t DH1536_GENERATOR = NULL;


/*
 * Call this once, at plugin load time.  It sets up the modulus and
 * generator MPIs.
 */
void otrl_dh_init(void)
{
    DO( mp_init_multi(&DH1536_MODULUS, &DH1536_GENERATOR, &DH1536_MODULUS_MINUS_2 ,NULL));
    
    DO( mp_read_radix(DH1536_MODULUS, (char *)DH1536_MODULUS_S, 16));
    DO( mp_read_radix(DH1536_GENERATOR, (char *)DH1536_GENERATOR_S, 16));
    
    DO( mp_sub_d(DH1536_MODULUS, 2, DH1536_MODULUS_MINUS_2));
}


/*
 * Call this once, at plugin load time.  It sets up the modulus and
 * generator MPIs.
 */
void otrl_dh_free(void)
{
    
    mp_clear_multi(DH1536_GENERATOR, DH1536_MODULUS, DH1536_MODULUS_MINUS_2, NULL);
    DH1536_GENERATOR = NULL;
    DH1536_MODULUS = NULL;
    DH1536_MODULUS_MINUS_2 = NULL;
    
 }

/*
 * Initialize the fields of a DH keypair.
 */
void otrl_dh_keypair_init(DH_keypair *kp)
{
    kp->groupid = 0;
    kp->priv = NULL;
    kp->pub = NULL;
}

/*
* Copy a DH_keypair.
*/
void otrl_dh_keypair_copy(DH_keypair *dst, const DH_keypair *src)
{
    dst->groupid = src->groupid;
    
    
 //   dst->priv = gcry_mpi_copy(src->priv);
 //   dst->pub = gcry_mpi_copy(src->pub);
}


/*
 * Deallocate the contents of a DH_keypair (but not the DH_keypair
 * itself)
 */
void otrl_dh_keypair_free(DH_keypair *kp)
{
    
    mp_clear_multi(kp->priv, kp->pub, NULL);
    kp->priv = NULL;
    kp->pub = NULL;
}


/*
 * Generate a DH keypair for a specified group.
 */ 
int otrl_dh_gen_keypair(unsigned int groupid, DH_keypair *kp)
{
    void* secbuf        = NULL;
    const int kSecBufLen = 40;
    
    if (groupid != DH1536_GROUP_ID) {
        /* Invalid group id */
        return CRYPT_PK_INVALID_TYPE;
    }
    
    kp->groupid = groupid;
    mp_init_multi(&kp->priv, &kp->pub, NULL);

    /* Generate the secret key: a random 320-bit value */
    secbuf = XMALLOC(kSecBufLen);
    
    sprng_read(secbuf, kSecBufLen,NULL);
    DO( mp_read_unsigned_bin(kp->priv,  secbuf, kSecBufLen));
    ZERO(secbuf,kSecBufLen);
    XFREE(secbuf);
    
    DO( mp_exptmod(DH1536_GENERATOR, kp->priv, DH1536_MODULUS, kp->pub));
    return CRYPT_OK;
}
 

/*
 * Construct session keys from a DH keypair and someone else's public
 * key.
 */
int otrl_dh_session(DH_sesskeys *sess, const DH_keypair *kp, gcry_mpi_t y)
{
    int     err = CRYPT_OK;
    
    gcry_mpi_t gab;
    size_t gablen, hashdatalen;
 
    unsigned char *gabdata;
    unsigned char *hashdata;
    unsigned char sendbyte, rcvbyte;
     
    otrl_dh_session_blank(sess);
    
    if (kp->groupid != DH1536_GROUP_ID) {
        /* Invalid group id */
        return CRYPT_PK_INVALID_TYPE;
    }

    /* Calculate the shared secret MPI */
    mp_init(&gab);
    DO( mp_exptmod(y, kp->priv, DH1536_MODULUS, gab));
       
    /* Output it in the right format */
    gablen = mp_unsigned_bin_size(gab);
    gabdata = XMALLOC(gablen+5); CKNULL(gabdata);
    gabdata[1] = (gablen >> 24) & 0xff;
    gabdata[2] = (gablen >> 16) & 0xff;
    gabdata[3] = (gablen >> 8) & 0xff;
    gabdata[4] = gablen & 0xff;
    mp_to_unsigned_bin(gab, gabdata+5);
    mp_clear(gab);

    hashdatalen = 20;
    hashdata = XMALLOC(hashdatalen); CKNULL(gabdata);

    /* Are we the "high" or "low" end of the connection? */
    if ( mp_cmp(kp->pub, y) > 0 ) {
        sendbyte = 0x01;
        rcvbyte = 0x02;
    } else {
        sendbyte = 0x02;
        rcvbyte = 0x01;
    }

    /* Calculate the sending encryption key */
    gabdata[0] = sendbyte;
    err = hash_memory( find_hash("sha1"),gabdata, gablen+5, hashdata, &hashdatalen ); CKERR;
 
  //  err = ctr_start(find_cipher("aes128")) CKERR;
    //err = gcry_cipher_open(&(sess->sendenc), GCRY_CIPHER_AES,  GCRY_CIPHER_MODE_CTR, GCRY_CIPHER_SECURE);
 // err = gcry_cipher_setkey(sess->sendenc, hashdata, 16);

    /* Calculate the sending MAC key */
     
///  #warning finish  this
  
done:
    XFREE(gabdata);
    XFREE(hashdata);

    return err;
   
}

/*
* Blank out the contents of a DH_sesskeys (without releasing it)
*/
void otrl_dh_session_blank(DH_sesskeys *sess)
{
    ZERO(&sess->sendenc, sizeof(sess->sendenc));
    ZERO(&sess->sendmac, sizeof(sess->sendmac));
    ZERO(&sess->rcvenc, sizeof(sess->rcvenc));
    ZERO(&sess->rcvmac, sizeof(sess->rcvmac));
    
    memset(sess->sendctr, 0, 16);
    memset(sess->rcvctr, 0, 16);
    memset(sess->sendmackey, 0, 20);
    memset(sess->rcvmackey, 0, 20);
    sess->sendmacused = 0;
    sess->rcvmacused = 0;
}

/*
 * Deallocate the contents of a DH_sesskeys (but not the DH_sesskeys
 * itself)
 */
void otrl_dh_session_free(DH_sesskeys *sess)
{
//    gcry_cipher_close(sess->sendenc);
//    gcry_cipher_close(sess->rcvenc);
 //   gcry_md_close(sess->sendmac);
 //   gcry_md_close(sess->rcvmac);
    
    otrl_dh_session_blank(sess);
}


int otrMathTest()
{
    int     err = CRYPT_OK;
     
    int bufLen = 0;
    void* buf1 = NULL;
     
    DH_keypair kp, kp1;
    DH_sesskeys  sess;

    register_hash (&sha1_desc);

    printf("Generate OTR DH key\n");
    otrl_dh_init();
    otrl_dh_keypair_init(&kp);
    DO(otrl_dh_gen_keypair(DH1536_GROUP_ID, &kp)); 
      
    bufLen = mp_unsigned_bin_size(kp.pub);
    buf1 =  XMALLOC(bufLen);
    mp_to_unsigned_bin(kp.pub, buf1);
    printf("Pub(%d)\n", mp_count_bits(kp.pub));
    dumpHex(buf1, bufLen, 4);
    XFREE(buf1);

    bufLen = mp_unsigned_bin_size(kp.priv);
    buf1 =  XMALLOC(bufLen);
    mp_to_unsigned_bin(kp.priv, buf1);
    printf("Priv(%d)\n", mp_count_bits(kp.priv));
    dumpHex(buf1, bufLen, 4);
    XFREE(buf1);

    printf("Generate Partner OTR DH key\n");
    otrl_dh_keypair_init(&kp1);
    DO(otrl_dh_gen_keypair(DH1536_GROUP_ID, &kp1)); 
   
    bufLen = mp_unsigned_bin_size(kp1.pub);
    buf1 =  XMALLOC(bufLen);
    mp_to_unsigned_bin(kp1.pub, buf1);
    printf("Pub(%d)\n", mp_count_bits(kp1.pub));
    dumpHex(buf1, bufLen, 4);
    XFREE(buf1);

    printf("Create Session key\n");
    DO(otrl_dh_session(&sess, &kp,  kp1.pub));
    
    
    otrl_dh_session_free(&sess);
    otrl_dh_keypair_free(&kp1);    
    otrl_dh_keypair_free(&kp);    
    otrl_dh_free();
    
    return err;

}