/*
 * Copyright (C) 2012 Werner Dittmann
 * All rights reserved.
 *
 * @author Werner Dittmann <Werner.Dittmann@t-online.de>
 *
 */
#include "tomcrypt.h"
#pragma clang diagnostic ignored "-Wconversion"

/* Paramters for Bernstein/Lange curves. Currently Curve3617:
 * x^2+y^2 = 1+3617x^2y^2, mod P
 * 
 * More details see:
 *
 * http://safecurves.cr.yp.to/field.html
 * http://safecurves.cr.yp.to/base.html
 *
 */

/**
  @file ecc_bl.c
  Implementation for EC Crypto for Bernstein/Lange curves, Werner Dittmann
*/

#ifdef LTC_ECC_BL

/* This holds the key settings.  ***MUST*** be organized by size from smallest to largest. */
const ltc_ecc_set_type ltc_ecc_bl_sets[] = {
    {
        52,                                                                                                          /* Actually 51.75 bytes */
        "Curve3617",
        "3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffef",  /* Prime */
        "3617",                                                                                                      /* Constant in formula */
        "7ffffffffffffffffffffffffffffffffffffffffffffffffffeb3cc92414cf706022b36f1c0338ad63cf181b0e71a5e106af79",   /* order */
        "1a334905141443300218c0631c326e5fcd46369f44c03ec7f57ff35498a4ab4d6d6ba111301a73faa8537c64c4fd3812f3cbc595",  /* Gx*/
        "22",                                                                                                        /* Gy (radix 16) */
    },

    {
        0,
        NULL, NULL, NULL, NULL, NULL, NULL
    },
};

int ltc_ecc_bl_setCurve(ecc_key *pub, const ltc_ecc_set_type *dp) 
{
    LTC_ARGCHK(pub  != NULL);
    LTC_ARGCHK(dp   != NULL);

    pub->dp = dp;
    return CRYPT_OK;
}

int ltc_ecc_bl_CheckKey(const ecc_key *pub)
{
    void *prime, *b, *t0, *t1, *t2, *t3, *one;
    int err = CRYPT_ERROR;

    mp_init_multi(&prime, &b, &t0, &t1, &t2, &t3, &one, NULL);

    if ((err = mp_read_radix(prime, (char *)pub->dp->prime, 16)) != CRYPT_OK) { goto errkey; }

    /* Represent point at infinity by (0, 0), make sure it's not that */
    if (mp_cmp_d(pub->pubkey.x, 0) == LTC_MP_EQ && mp_cmp_d(pub->pubkey.y, 0) == LTC_MP_EQ) {
        goto errkey;
    }
    /* Check that coordinates are within range */
    if (mp_cmp_d(pub->pubkey.x, 0) == LTC_MP_LT || mp_cmp(pub->pubkey.x, prime) >= LTC_MP_EQ) {
        goto errkey;
    }
    if (mp_cmp_d(pub->pubkey.y, 0) == LTC_MP_LT || mp_cmp(pub->pubkey.y, prime) >= LTC_MP_EQ) {
        goto errkey;
    }
    if ((err = mp_read_radix(b, (char *)pub->dp->B, 10)) != CRYPT_OK) { goto errkey; }
    if ((err = mp_read_radix(one, "1", 10)) != CRYPT_OK)              { goto errkey; }

    /* Check that point satisfies EC equation x^2+y^2 = 1+3617x^2y^2, mod P */
    if ((err = mp_sqrmod(pub->pubkey.y, prime, t1)) != CRYPT_OK) { goto errkey; }  /* t1 = y^2 */
    if ((err = mp_sqrmod(pub->pubkey.x, prime, t2)) != CRYPT_OK) { goto errkey; }  /* t2 = x^2 */

    if ((err = mp_addmod(t1, t2, prime, t3)) != CRYPT_OK)        { goto errkey; }  /* t3 = t1 + t2, (x^2+y^2), left hand result */

    if ((err = mp_mulmod(b, t1, prime, t0)) != CRYPT_OK)         { goto errkey; }  /* t0 = b * t1,  (3617 * y^2) */
    if ((err = mp_mulmod(t0, t2, prime, t0)) != CRYPT_OK)        { goto errkey; }  /* t0 = t0 * t2, (3617 * x^2 * y^2) */
    if ((err = mp_addmod(t0, one, prime, t0)) != CRYPT_OK)       { goto errkey; }  /* t0 = t0 + 1,  (3617 * x^2 * y^2 + 1) */

    if (mp_cmp (t0, t3) == LTC_MP_EQ) {
        err = CRYPT_OK;
    }

errkey:
    mp_clear_multi(prime, b, t0, t1, t2, t3, one, NULL);
    return err;
}

#ifdef FOR_TEST_ONLY
static void hexdump(const char* title, const unsigned char *s, int l) {
    int n=0;

    if (s == NULL) return;

    fprintf(stderr, "%s",title);
    for( ; n < l ; ++n)
    {
        if((n%16) == 0)
            fprintf(stderr, "\n%04x",n);
        fprintf(stderr, " %02x",s[n]);
    }
    fprintf(stderr, "\n");
}
#endif

#ifdef DO_NOT_USE
static mod3617(void *a, void *m, void *r) 
{

    unsigned char buf[500];
    unsigned char bufbin[200];
    unsigned char bufbin1[52];
    unsigned char bufbin2[52] = {0};
    unsigned char x, carry = 0;
    unsigned char *b0, *b1;
    int cmp, err, offset, size;
    void *tmp;

    cmp = mp_cmp(m, a);
    if (cmp == LTC_MP_EQ) {      /* a is equal modulo, set result to zero */
        mp_set(r, 0);
        return CRYPT_OK;
    }
    if (cmp == LTC_MP_GT) {      /* modulo is greater than a - copy a to r and return it */
        mp_copy(a, r);
        return CRYPT_OK;
    }

//    mp_toradix(a, buf, 16); fprintf(stderr, "         a: %s\n", buf);
    if ((err = mp_init(&tmp)) != CRYPT_OK) {
        return err;
    }
    size = mp_unsigned_bin_size(a);
    offset = size - 52;
    mp_to_unsigned_bin(a, bufbin);
    memcpy(bufbin1, &bufbin[offset], 52);
    bufbin1[0] &= 0x3f;

    b0 = bufbin;
    b1 = bufbin2;
//    fprintf(stderr, "size: %d, offset: %d ", size, offset);
    while (offset) {
        x = *b0++;
        *b1++ = (x >> 6) | carry;
        carry = x << 2;
        offset--;
    }
//    fprintf(stderr, "carry: %x, x shifted: %x, x: %x\n", carry, *b0 >> 6, *b0);
    *b1 = (*b0 >> 6) | carry;

    mp_read_unsigned_bin(r, bufbin2, size - 52 + 1);
//    mp_toradix(r, buf, 16); fprintf(stderr, "         r: %s\n", buf);

    if ((err = mp_mul_d(r, 17, r)) != CRYPT_OK)   {goto err_exit;}

    mp_read_unsigned_bin(tmp, bufbin1, 52);
    if ((err = mp_add(r, tmp, r)) != CRYPT_OK)    {goto err_exit;}

    while (mp_cmp(r, m) >= LTC_MP_EQ) {
        if ((err = mp_sub(r, m, r)) != CRYPT_OK)  {goto err_exit;}
    }

err_exit:
    mp_clear(tmp);
    return err;
/*
    bnExtractLittleBytes(a, buffer, 0, 52);
    buffer[51] &= 0x3f;

    bnCopy(&tmp, a);
    bnRShift(&tmp, 414);
    bnCopy(r, &tmp);
    bnLShift(r, 4);
    bnAdd(r, &tmp);

    bnInsertLittleBytes(&tmp, buffer, 0, 52);

    bnAdd(r, &tmp);
    while (bnCmp(r, modulo) >= 0) {
        bnSub(r, modulo);
    }
    bnEnd(&tmp);
    return 0;
*/
}
#endif
/* 
 * Define some local macros to reduce typing and enable changing function calls
 * ATTENTION: these macros use the *first* parameter (r) as result (was easier to convert from some existing code)
 */
#if 1
#define MUL_MOD(r, a, b, m, mp) {if((err = mp_mul(a, b, r)) != CRYPT_OK){goto err_exit;} if ((err = mp_mod(r, m, r)) != CRYPT_OK){ goto err_exit; }}

#define SQR_MOD(r, a, m, mp) {if((err = mp_sqr(a, r)) != CRYPT_OK){goto err_exit;} if ((err = mp_mod(r, m, r)) != CRYPT_OK){ goto err_exit; }}

#else
#define MUL_MOD(r, a, b, m, mp) {if((err = mp_mul(a, b, r)) != CRYPT_OK){goto err_exit;} if ((err = mod3617(r, m, r)) != CRYPT_OK){ goto err_exit; }}

#define SQR_MOD(r, a, m, mp) {if((err = mp_sqr(a, r)) != CRYPT_OK){goto err_exit;} if ((err = mod3617(r, m, r)) != CRYPT_OK){ goto err_exit; }}

#endif

#define ADD_MOD(r, a, b, m) {if ((err = mp_add (a, b, r)) != CRYPT_OK){goto err_exit;} if (mp_cmp (r, m) >= LTC_MP_EQ) {\
if ((err = mp_sub (r, m, r)) != CRYPT_OK){goto err_exit;} }}

#define SUB_MOD(r, a, b, m) {if (mp_cmp (a, b) == LTC_MP_LT) {if ((err = mp_add (a, m, a)) != CRYPT_OK){goto err_exit;}} \
if ((err = mp_sub (a, b, r)) != CRYPT_OK){goto err_exit;} }


int ltc_ecc_bl_map(ecc_point *P, void *modulus, ecc_point *R)
{
    int err;
    void  *z_1;

    if ((err = mp_init_multi(&z_1, NULL)) != CRYPT_OK) {
        return err;
    }

    /* affine x = X / Z */
    if ((err = mp_invmod(P->z, modulus, z_1)) != CRYPT_OK)  { goto err_exit; } /* z_1 = Z^(-1) */
    MUL_MOD(R->x, P->x, z_1, modulus, mp);

    /* affine y = Y / Z */
    MUL_MOD(R->y, P->y, z_1, modulus, mp);

    if ((err = mp_set(R->z, 1)) != CRYPT_OK)                { goto err_exit; }

err_exit:
    mp_clear_multi(z_1, NULL);
    return err;
}

int ltc_ecc_bl_projective_add_point(ecc_point *P, ecc_point *Q, ecc_point *R, void *modulus, void *b)
{
     ecc_point *ptP = 0;
     ecc_point *ptQ = 0;

     void  *t0, *t1, *t2, *t3;
     int    err;

    /* if P is (@,@), R = Q */
    if (mp_cmp_d(P->z, 0) == LTC_MP_EQ) {
        if ((err = mp_copy(Q->x, R->x)) != CRYPT_OK)  { return err; }
        if ((err = mp_copy(Q->y, R->y)) != CRYPT_OK)  { return err; }
        if ((err = mp_copy(Q->z, R->z)) != CRYPT_OK)  { return err; }
        return CRYPT_OK;
    }

    if (mp_cmp_d(Q->z, 0) == LTC_MP_EQ) {
        if ((err = mp_copy(P->x, R->x)) != CRYPT_OK)  { return err; }
        if ((err = mp_copy(P->y, R->y)) != CRYPT_OK)  { return err; }
        if ((err = mp_copy(P->z, R->z)) != CRYPT_OK)  { return err; }
        return CRYPT_OK;
    }

    if ((err = mp_init_multi(&t0, &t1, &t2, &t3, NULL)) != CRYPT_OK) {
      return err;
    }

    /* Check for overlapping arguments, copy if necessary and set pointers */
    if (P == R) {
        ptP = ltc_ecc_new_point();
        if ((err = mp_copy(P->x, ptP->x)) != CRYPT_OK)  { goto err_exit; }
        if ((err = mp_copy(P->y, ptP->y)) != CRYPT_OK)  { goto err_exit; }
        if ((err = mp_copy(P->z, ptP->z)) != CRYPT_OK)  { goto err_exit; }
    }
    else 
        ptP = P;

    if (Q == R) {
        ptQ = ltc_ecc_new_point();
        if ((err = mp_copy(Q->x, ptQ->x)) != CRYPT_OK)  { goto err_exit; }
        if ((err = mp_copy(Q->y, ptQ->y)) != CRYPT_OK)  { goto err_exit; }
        if ((err = mp_copy(Q->z, ptQ->z)) != CRYPT_OK)  { goto err_exit; }
    }
    else
        ptQ = Q;

    /* Compute A, C, D first */
    MUL_MOD(R->z, ptP->z, ptQ->z, modulus, mp);             /* Rz -> A; (Z1 * Z2); Rz becomes R3 */
    MUL_MOD(R->x, ptP->x, ptQ->x, modulus, mp);             /* Rx -> C; (X1 * X2); Rx becomes R1 */
    MUL_MOD(R->y, ptP->y, ptQ->y, modulus, mp);             /* Ry -> D; (Y1 * Y2); Ry becomes R2 */

    /* Compute large parts of X3 equation, sub result in t0 */
    ADD_MOD(t0, ptP->x, ptP->y, modulus);               /* t0 -> X1 + Y1 */
    ADD_MOD(t1, ptQ->x, ptQ->y, modulus);               /* t1 -> X2 + Y2 */
    MUL_MOD(t2, t0, t1, modulus, mp);                       /* t2 = t0 * t1 */
    SUB_MOD(t2, t2, R->x, modulus);                     /* t2 - C */
    SUB_MOD(t2, t2, R->y, modulus);                     /* t2 - D */
    MUL_MOD(t0, t2, R->z, modulus, mp);                     /* t0 -> R7; (t2 * A); sub result */

    /* Compute E */
    MUL_MOD(t2, R->x, R->y, modulus, mp);                   /* t2 = C * D */
    MUL_MOD(t1, t2, b, modulus, mp);                        /* t1 -> E; t1 new R8 */

    /* Compute part of Y3 equation, sub result in t2 */
    SUB_MOD(R->y, R->y, R->x, modulus);                 /* Ry = D - C; sub result */
    MUL_MOD(t2, R->y, R->z, modulus, mp);                   /* t2 = Ry * A; sub result */

    /* Compute B */
    SQR_MOD(R->z, R->z, modulus, mp);                       /* Rz -> B; (A^2) */

    /* Compute F */
    SUB_MOD(t3, R->z, t1, modulus);                     /* t3 -> F; (B - E) */

    /* Compute G */
    ADD_MOD(R->z, R->z, t1, modulus);                   /* Rz -> G; (B + E) */

    /* Compute, X, Y, Z results */
    MUL_MOD(R->x, t3, t0, modulus, mp);                     /* Rx = F * t0 */
    MUL_MOD(R->y, t2, R->z, modulus, mp);                   /* Ry = t2 * G */
    MUL_MOD(R->z, t3, R->z, modulus, mp);                   /* Rz = F * G */

err_exit:
    mp_clear_multi(t0, t1, t2, t3, NULL);
    if (P == R)
        ltc_ecc_del_point(ptP);
    if (Q == R)
        ltc_ecc_del_point(ptQ);

    return err;
}

int ltc_ecc_bl_projective_dbl_point(ecc_point *P, ecc_point *R, void *modulus)
{
     ecc_point *ptP = 0;
     void  *t0, *t1, *t2;
     int    err;

     if ((err = mp_init_multi(&t0, &t1, &t2, NULL)) != CRYPT_OK) {
         return err;
     }

    /* Check for overlapping arguments, copy if necessary and set pointer */
    if (P == R) {
        ptP = ltc_ecc_new_point();
        if ((err = mp_copy(P->x, ptP->x)) != CRYPT_OK)  { goto err_exit; }
        if ((err = mp_copy(P->y, ptP->y)) != CRYPT_OK)  { goto err_exit; }
        if ((err = mp_copy(P->z, ptP->z)) != CRYPT_OK)  { goto err_exit; }
    }
    else 
        ptP = P;

    /* Compute B, C, D, H, E */
    ADD_MOD(t1, ptP->x, ptP->y, modulus);
    SQR_MOD(t0, t1, modulus, mp);                        /* t0 -> B */

    SQR_MOD(R->x, ptP->x, modulus, mp);                  /* Rx -> C */

    SQR_MOD(R->y, ptP->y, modulus, mp);                  /* Ry -> D */

    SQR_MOD(R->z, ptP->z, modulus, mp);                  /* Rz -> H */
    ADD_MOD(R->z, R->z, R->z, modulus);              /* Rz -> 2H */

    ADD_MOD(t1, R->x, R->y, modulus);                /* t1 -> E */

    /* Compute Ry */
    SUB_MOD(t2, R->x, R->y, modulus);                /* C - D */
    MUL_MOD(R->y, t1, t2, modulus, mp);                  /* E * t2; Ry */

    /* Compute Rx */
    SUB_MOD(t0, t0, t1, modulus);                   /* B - E; sub result */
    SUB_MOD(t2, t1, R->z, modulus);                 /* t2 -> J; (E - 2H) */
    MUL_MOD(R->x, t2, t0, modulus, mp);                 /* J * t0 */

    /* Compute Rz */
    MUL_MOD(R->z, t2, t1, modulus, mp);                 /* J * E */

err_exit:
    mp_clear_multi(t0, t1, t2, NULL);
    if (P == R)
        ltc_ecc_del_point(ptP);

    return err;
}

#ifndef WORKING
int ltc_ecc_bl_mulmod(void *k, ecc_point *G, ecc_point *R, void *modulus, void *b, int map)
{
    unsigned char buffer[52];       // Max length of Curve3617 data
    int size;
    int bits;
    int i, offset, mask = 0, bit;
    int err;
    ecc_point *n;

    size = mp_unsigned_bin_size(k) - 1;
    bits = mp_count_bits(k);

    mp_to_unsigned_bin(k, buffer);
 
    n = ltc_ecc_new_point();
    if ((err = mp_copy(G->x, n->x)) != CRYPT_OK)  { goto err_exit; }
    if ((err = mp_copy(G->y, n->y)) != CRYPT_OK)  { goto err_exit; }
    if ((err = mp_copy(G->z, n->z)) != CRYPT_OK)  { goto err_exit; }

    if ((err = mp_set(R->x, 0)) != CRYPT_OK)  { goto err_exit; }
    if ((err = mp_set(R->y, 0)) != CRYPT_OK)  { goto err_exit; }
    if ((err = mp_set(R->z, 0)) != CRYPT_OK)  { goto err_exit; }

    
    for (i = 0; i < bits; i++) {
        offset = size - (i >> 3);
        mask = 1 << (i & 7);
        bit = buffer[offset] & mask;
        if (bit) {
            if ((err = ltc_ecc_bl_projective_add_point(R, n, R, modulus, b)) != CRYPT_OK)  { goto err_exit; }
        }
        if ((err = ltc_ecc_bl_projective_dbl_point(n, n, modulus))  != CRYPT_OK)           { goto err_exit; }
    }

    /* map R back from projective space if requested */
    if (map) {
        err = ltc_ecc_bl_map(R, modulus, R);
    }
    else {
        err = CRYPT_OK;
    }

err_exit:
    ltc_ecc_del_point(n);
    return err;
}
#else
int ltc_ecc_bl_mulmod(void *k, ecc_point *G, ecc_point *R, void *modulus, void *b, int map)
{
    unsigned char buffer[52];       // Max length of Curve3617 data
    int size;
    int bits;
    int i, offset, mask = 0, bit;
    int err;
    void       *mu, *mp;
    ecc_point *n;

    /* init montgomery reduction */
    if ((err = mp_montgomery_setup(modulus, &mp)) != CRYPT_OK) {
        return err;
    }
    if ((err = mp_init(&mu)) != CRYPT_OK) {
        mp_montgomery_free(mp);
        return err;
    }
    if ((err = mp_montgomery_normalization(mu, modulus)) != CRYPT_OK) {
        mp_montgomery_free(mp);
        mp_clear(mu);
        return err;
    }
    size = mp_unsigned_bin_size(k) - 1;
    bits = mp_count_bits(k);

    mp_to_unsigned_bin(k, buffer);
 
    n = ltc_ecc_new_point();
    /* tG = G  and convert to montgomery */
    if (mp_cmp_d(mu, 1) == LTC_MP_EQ) {
        if ((err = mp_copy(G->x, n->x)) != CRYPT_OK)                                  { goto err_exit; }
        if ((err = mp_copy(G->y, n->y)) != CRYPT_OK)                                  { goto err_exit; }
        if ((err = mp_copy(G->z, n->z)) != CRYPT_OK)                                  { goto err_exit; }
    } 
    else {
        if ((err = mp_mulmod(G->x, mu, modulus, n->x)) != CRYPT_OK)                   { goto err_exit; }
        if ((err = mp_mulmod(G->y, mu, modulus, n->y)) != CRYPT_OK)                   { goto err_exit; }
        if ((err = mp_mulmod(G->z, mu, modulus, n->z)) != CRYPT_OK)                   { goto err_exit; }
    }
    mp_clear(mu);
    mu = NULL;

    if ((err = mp_set(R->x, 0)) != CRYPT_OK)  { goto err_exit; }
    if ((err = mp_set(R->y, 0)) != CRYPT_OK)  { goto err_exit; }
    if ((err = mp_set(R->z, 0)) != CRYPT_OK)  { goto err_exit; }

    
    for (i = 0; i < bits; i++) {
        offset = size - (i >> 3);
        mask = 1 << (i & 7);
        bit = buffer[offset] & mask;
        if (bit) {
            if ((err = ltc_ecc_bl_projective_add_point(R, n, R, modulus, b, mp)) != CRYPT_OK)  { goto err_exit; }
        }
        if ((err = ltc_ecc_bl_projective_dbl_point(n, n, modulus, mp))  != CRYPT_OK)           { goto err_exit; }
    }

    /* map R back from projective space if requested */
    if (map) {
        err = ltc_ecc_bl_map(R, modulus, R, mp);
    }
    else {
        err = CRYPT_OK;
    }

err_exit:
    if (mu != NULL) {
        mp_clear(mu);
    }
    mp_montgomery_free(mp);

    ltc_ecc_del_point(n);
    return err;
}
#endif


#endif