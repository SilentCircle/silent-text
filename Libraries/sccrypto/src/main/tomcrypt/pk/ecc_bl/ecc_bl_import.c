#include <tomcrypt.h>

/**
  @file ecc_import.c
  ECC Crypto for Bernstein Curve3617, Werner Dittmann
*/  

#ifdef LTC_ECC_BL

/**
  Import an ECC key from a binary packet, using user supplied domain params rather than one of the NIST ones
  @param in      The packet to import
  @param inlen   The length of the packet
  @param key     [out] The destination of the import
  @param dp      pointer to user supplied params; must be the same as the params used when exporting
  @return CRYPT_OK if successful, upon error all allocated memory will be freed
*/
int ecc_bl_import_ex(const unsigned char *in, unsigned long inlen, ecc_key *key, const ltc_ecc_set_type *dp)
{
   unsigned long key_size;
   unsigned char flags[1];
   int           err;

   LTC_ARGCHK(in  != NULL);
   LTC_ARGCHK(key != NULL);
   LTC_ARGCHK(ltc_mp.name != NULL);

   /* init key */
   if (mp_init_multi(&key->pubkey.x, &key->pubkey.y, &key->pubkey.z, &key->k, NULL) != CRYPT_OK) {
      return CRYPT_MEM;
   }

   /* find out what type of key it is */
   if ((err = der_decode_sequence_multi(in, inlen, 
                                  LTC_ASN1_BIT_STRING, 1UL, &flags,
                                  LTC_ASN1_EOL,        0UL, NULL)) != CRYPT_OK) {
      goto done;
   }


   if (flags[0] == 1) {
      /* private key */
      key->type = PK_PRIVATE;
      if ((err = der_decode_sequence_multi(in, inlen,
                                     LTC_ASN1_BIT_STRING,      1UL, flags,
                                     LTC_ASN1_SHORT_INTEGER,   1UL, &key_size,
                                     LTC_ASN1_INTEGER,         1UL, key->pubkey.x,
                                     LTC_ASN1_INTEGER,         1UL, key->pubkey.y,
                                     LTC_ASN1_INTEGER,         1UL, key->k,
                                     LTC_ASN1_EOL,             0UL, NULL)) != CRYPT_OK) {
         goto done;
      }
   } else {
      /* public key */
      key->type = PK_PUBLIC;
      if ((err = der_decode_sequence_multi(in, inlen,
                                     LTC_ASN1_BIT_STRING,      1UL, flags,
                                     LTC_ASN1_SHORT_INTEGER,   1UL, &key_size,
                                     LTC_ASN1_INTEGER,         1UL, key->pubkey.x,
                                     LTC_ASN1_INTEGER,         1UL, key->pubkey.y,
                                     LTC_ASN1_EOL,             0UL, NULL)) != CRYPT_OK) {
         goto done;
      }
   }

   if (dp == NULL) {
     /* find the idx */
     for (key->idx = 0; ltc_ecc_bl_sets[key->idx].size && (unsigned long)ltc_ecc_bl_sets[key->idx].size != key_size; ++key->idx);
     if (ltc_ecc_sets[key->idx].size == 0) {
       err = CRYPT_INVALID_PACKET;
       goto done;
     }
     key->dp = &ltc_ecc_bl_sets[key->idx];
   } 
   else {
     key->idx = -1;
     key->dp = dp;
   }
   /* set z */
   if ((err = mp_set(key->pubkey.z, 1)) != CRYPT_OK) { goto done; }
   
   /* is it a point on the curve?  */
   if ((err = ltc_ecc_bl_CheckKey(key)) != CRYPT_OK) {
      goto done;
   }

   /* we're good */
   return CRYPT_OK;
done:
   mp_clear_multi(key->pubkey.x, key->pubkey.y, key->pubkey.z, key->k, NULL);
   return err;
}

/**
 Import an ECC key from a binary packet
 @param in      The packet to import
 @param inlen   The length of the packet
 @param key     [out] The destination of the import
 @return CRYPT_OK if successful, upon error all allocated memory will be freed
 */
int ecc_bl_import(const unsigned char *in, unsigned long inlen, ecc_key *key)
{
    return ecc_bl_import_ex(in, inlen, key, NULL);
}



#endif
/* $Source$ */
/* $Revision$ */
/* $Date$ */

