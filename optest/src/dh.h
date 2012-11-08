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

#ifndef __DH_H__
#define __DH_H__

#include <tomcrypt.h>

typedef void* gcry_mpi_t;
typedef void* gcry_cipher_hd_t;
typedef void* gcry_md_hd_t;

#define DH1536_GROUP_ID 5

typedef struct {
    unsigned int groupid;
    void* priv;
    void* pub;
} DH_keypair;

/* Which half of the secure session id should be shown in bold? */
typedef enum {
    OTRL_SESSIONID_FIRST_HALF_BOLD,
    OTRL_SESSIONID_SECOND_HALF_BOLD
} OtrlSessionIdHalf;

typedef struct {
    unsigned char sendctr[16];
    unsigned char rcvctr[16];
    symmetric_CTR sendenc;
    symmetric_CTR rcvenc;
    hmac_state  sendmac;
    unsigned char sendmackey[20];
    int sendmacused;
    hmac_state  rcvmac;
    unsigned char rcvmackey[20];
    int rcvmacused;
} DH_sesskeys;




/*
 * Call this once, at plugin load time.  It sets up the modulus and
 * generator MPIs.
 */
void otrl_dh_init(void);

/*
 * Initialize the fields of a DH keypair.
 */
void otrl_dh_keypair_init(DH_keypair *kp);

/*
 * Copy a DH_keypair.
 */
void otrl_dh_keypair_copy(DH_keypair *dst, const DH_keypair *src);

/*
 * Deallocate the contents of a DH_keypair (but not the DH_keypair
 * itself)
 */
void otrl_dh_keypair_free(DH_keypair *kp);
 
/*
 * Construct session keys from a DH keypair and someone else's public
 * key.
 */
int otrl_dh_session(DH_sesskeys *sess, const DH_keypair *kp,
                             gcry_mpi_t y);


/*
 * Deallocate the contents of a DH_sesskeys (but not the DH_sesskeys
 * itself)
 */
void otrl_dh_session_free(DH_sesskeys *sess);

/*
 * Blank out the contents of a DH_sesskeys (without releasing it)
 */
void otrl_dh_session_blank(DH_sesskeys *sess);

#endif
