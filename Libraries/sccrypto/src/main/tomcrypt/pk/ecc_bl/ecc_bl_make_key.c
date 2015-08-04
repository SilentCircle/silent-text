#include <tomcrypt.h>

/**
  @file ecc_bl_make_key.c
  ECC Crypto for Bernstein Curve3617, Werner Dittmann
*/  

#ifdef LTC_ECC_BL

/**
  Make a new ECC key 
  @param prng         An active PRNG state
  @param wprng        The index of the PRNG you wish to use
  @param keysize      The keysize for the new key (in octets from 20 to 65 bytes)
  @param key          [out] Destination of the newly created key
  @return CRYPT_OK if successful, upon error all allocated memory will be freed
*/

int ecc_bl_make_key_ex(prng_state *prng, int wprng, ecc_key *key, const ltc_ecc_set_type *dp)
{
   int            err;
   ecc_point     *base;
   void          *prime, *order, *b;
   unsigned char *buf;
   int            keysize;

   LTC_ARGCHK(key         != NULL);
   LTC_ARGCHK(ltc_mp.name != NULL);
   LTC_ARGCHK(dp          != NULL);

   /* good prng? */
   if ((err = prng_is_valid(wprng)) != CRYPT_OK) {
      return err;
   }

   key->idx = -1;
   key->dp  = dp;
   keysize  = dp->size;

   /* allocate ram */
   base = NULL;
   buf  = XMALLOC(ECC_MAXSIZE);
   if (buf == NULL) {
      return CRYPT_MEM;
   }

   /* make up random string */
   if (prng_descriptor[wprng].read(buf, (unsigned long)keysize, prng) != (unsigned long)keysize) {
      err = CRYPT_ERROR_READPRNG;
      goto ERR_BUF;
   }

   /* Prepare the secret random data: clear bottom 3 bits. Clearing top 2 bits
    * makes is a 414 bit value. This is big endian order.
    */
    buf[51] &= ~0x7;
    buf[0] &= 0x3f;

    /* setup the key variables */
   if ((err = mp_init_multi(&key->pubkey.x, &key->pubkey.y, &key->pubkey.z, &key->k, &prime, &order, &b, NULL)) != CRYPT_OK) {
      goto ERR_BUF;
   }
   base = ltc_ecc_new_point();
   if (base == NULL) {
      err = CRYPT_MEM;
      goto errkey;
   }

   /* read in the specs for this key */
   if ((err = mp_read_radix(prime,   (char *)key->dp->prime, 16)) != CRYPT_OK)                  { goto errkey; }
   if ((err = mp_read_radix(order,   (char *)key->dp->order, 16)) != CRYPT_OK)                  { goto errkey; }
   if ((err = mp_read_radix(b, (char *)key->dp->B, 10)) != CRYPT_OK)                             { goto errkey; }
   if ((err = mp_read_radix(base->x, (char *)key->dp->Gx, 16)) != CRYPT_OK)                     { goto errkey; }
   if ((err = mp_read_radix(base->y, (char *)key->dp->Gy, 16)) != CRYPT_OK)                     { goto errkey; }
   if ((err = mp_set(base->z, 1)) != CRYPT_OK)                                                  { goto errkey; }
   if ((err = mp_read_unsigned_bin(key->k, (unsigned char *)buf, keysize)) != CRYPT_OK)         { goto errkey; }

   /* make the public key */
   if ((err = ltc_ecc_bl_mulmod(key->k, base, &key->pubkey, prime, b, 1)) != CRYPT_OK)              { goto errkey; }
   key->type = PK_PRIVATE;

   /* free up ram */
   err = CRYPT_OK;
   goto cleanup;
errkey:
   mp_clear_multi(key->pubkey.x, key->pubkey.y, key->pubkey.z, key->k, NULL);
cleanup:
   ltc_ecc_del_point(base);
   mp_clear_multi(prime, order, b, NULL);
ERR_BUF:
#ifdef LTC_CLEAN_STACK
   zeromem(buf, ECC_MAXSIZE);
#endif
   XFREE(buf);
   return err;
}

/**
  Create an ECC shared secret between two keys
  @param private_key      The private ECC key
  @param public_key       The public key
  @param out              [out] Destination of the shared secret (Conforms to EC-DH from ANSI X9.63)
  @param outlen           [in/out] The max size and resulting size of the shared secret
  @return CRYPT_OK if successful
*/
int ecc_bl_shared_secret(ecc_key *private_key, ecc_key *public_key,
                      unsigned char *out, unsigned long *outlen)
{
   unsigned long  x;
   ecc_point     *result;
   void          *prime, *b;
   int            err;

   LTC_ARGCHK(private_key != NULL);
   LTC_ARGCHK(public_key  != NULL);
   LTC_ARGCHK(out         != NULL);
   LTC_ARGCHK(outlen      != NULL);

   /* type valid? */
   if (private_key->type != PK_PRIVATE) {
      return CRYPT_PK_NOT_PRIVATE;
   }

   if (ltc_ecc_is_valid_idx(private_key->idx) == 0 || ltc_ecc_is_valid_idx(public_key->idx) == 0) {
      return CRYPT_INVALID_ARG;
   }

   if (XSTRCMP(private_key->dp->name, public_key->dp->name) != 0) {
      return CRYPT_PK_TYPE_MISMATCH;
   }

   /* make new point */
   result = ltc_ecc_new_point();
   if (result == NULL) {
      return CRYPT_MEM;
   }

   if ((err = mp_init_multi(&prime, &b, NULL)) != CRYPT_OK) {
      ltc_ecc_del_point(result);
      return err;
   }

   if ((err = mp_read_radix(prime, (char *)private_key->dp->prime, 16)) != CRYPT_OK)                    { goto done; }
   if ((err = mp_read_radix(b, (char *)private_key->dp->B, 10)) != CRYPT_OK)                            { goto done; }
   if ((err = ltc_ecc_bl_mulmod(private_key->k, &public_key->pubkey, result, prime, b, 1)) != CRYPT_OK) { goto done; }

   x = (unsigned long)mp_unsigned_bin_size(prime);
   if (*outlen < x) {
      *outlen = x;
      err = CRYPT_BUFFER_OVERFLOW;
      goto done;
   }
   zeromem(out, x);
   if ((err = mp_to_unsigned_bin(result->x, out + (x - mp_unsigned_bin_size(result->x)))) != CRYPT_OK)  { goto done; }

   err     = CRYPT_OK;
   *outlen = x;
done:
   mp_clear_multi(prime, b, NULL);
   ltc_ecc_del_point(result);
   return err;
}

int ecc_bl_make_key(prng_state *prng, int wprng, int keysize, ecc_key *key)
{
    int x, err;
    
    /* find key size */
    for (x = 0; (keysize > ltc_ecc_bl_sets[x].size) && (ltc_ecc_bl_sets[x].size != 0); x++);
    keysize = ltc_ecc_bl_sets[x].size;
    
    if (keysize > ECC_MAXSIZE || ltc_ecc_bl_sets[x].size == 0) {
        return CRYPT_INVALID_KEYSIZE;
    }
    err = ecc_bl_make_key_ex(prng, wprng, key, &ltc_ecc_bl_sets[x]);
    key->idx = x;
    return err;
}


#endif
/* $Source$ */
/* $Revision$ */
/* $Date$ */

