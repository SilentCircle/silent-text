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
#include "SCimp.h"


//#include "KAPS.h"   

enum KAPSstate_
{
    kKAPSstate_Init             = 0,
    kKAPSstate_Ready,
    
    /* Initiator State */
    kKAPSstate_Rekey,
    kKAPSstate_Commit,
    kKAPSstate_DH2,
    
    /* Responder State */
    kKAPSstate_DH1,
    kKAPSstate_Confirmed,

    
    ENUM_FORCE( KAPSstate_ )
};

ENUM_TYPEDEF( KAPSstate_, KAPSstate  );

enum KAPSeventType_
{
    kKAPSevent_NULL             = 0,
    kKAPSevent_RCV_Commit,            
    kKAPSevent_RCV_DH1,             
    kKAPSevent_RCV_DH2 ,
    kKAPSevent_RCV_Confirm ,
    kKAPSevent_Complete ,
    kKAPSevent_Shutdown ,
       
    ENUM_FORCE( KAPSeventType_ )
};

#define NO_NEW_STATE    (INT_MAX -1)
#define ANY_STATE       INT_MAX

ENUM_TYPEDEF( KAPSeventType_, KAPSeventType   );

/* a simple value sufficient to hold any numeric or pointer type */
typedef void *				UserValue;

typedef struct  KAPSEvent
{
	KAPSeventType	type;
	void*           data;
}  KAPSEvent;


typedef int (*KAPSeventHandler)(SCimpContextRef kaps,  void* data, size_t dataLen,  UserValue uservalue);

static int sRecieveKAPSEvent(SCimpContextRef ctx, KAPSeventType event, void* data, size_t dataLen, UserValue uservalue);

typedef struct  state_type_type
{
    KAPSstate           current;
    KAPSeventType       event;
    KAPSstate           next;
    KAPSeventHandler    func;
    
}state_type_type;


struct SCKAPSContext 
{
    KAPSstate               state;          /* State of this end */
};

static int sProcessKAPSmsg_DH1(SCimpContextRef ctx, uint8_t *in, size_t inLen,UserValue uservalue  )
{
    int             err = CRYPT_OK;
     
    printf("Port %d, Process DH1\n", (int)ctx->port);
    return err;
}
static int sProcessKAPSmsg_Commit(SCimpContextRef ctx, uint8_t *in, size_t inLen,UserValue uservalue  )
{
    int             err = CRYPT_OK;
  
    printf("Port %d, Process Commit\n", (int)ctx->port);
    
    err = sRecieveKAPSEvent(ctx, kKAPSevent_NULL, NULL, 0, (void*) 99999);
 
    err = sRecieveKAPSEvent(ctx, kKAPSevent_NULL, NULL, 0, (void*) 99999);
 
    err = sRecieveKAPSEvent(ctx, kKAPSevent_NULL, NULL, 0, (void*) 99999);
    
     return err;
}
static int sProcessKAPSmsg_DH2(SCimpContextRef ctx, uint8_t *in, size_t inLen,UserValue uservalue  )
{
    int             err = CRYPT_OK;
     
    printf("Port %d, Process DH2\n", (int)ctx->port);
    return err;
}
static int sProcessKAPSmsg_Confirm(SCimpContextRef ctx, uint8_t *in, size_t inLen,UserValue uservalue  )
{
    int             err = CRYPT_OK;
     
    printf("Port %d, Process Confirm\n", (int)ctx->port);
    return err;
}

static int sProcessKAPSmsg_Shutdown(SCKAPSContextRef ctx, uint8_t *in, size_t inLen,UserValue uservalue  )
{
    int             err = CRYPT_OK;
     
    printf("Port %d, Process Shutdown\n", (int)ctx->port);
   return err;
}
static int sProcessKAPSmsg_Null(SCKAPSContextRef ctx, uint8_t *in, size_t inLen,UserValue uservalue  )
{
    int             err = CRYPT_OK;
    
    printf("Port %d, Process Null\n", (int)ctx->port);
    return err;
}


static const state_type_type KAPS_state_table[]=
{
    {  
        ANY_STATE,
        kKAPSevent_NULL,
        NO_NEW_STATE,
        sProcessKAPSmsg_Null,
    },  
    {  
        ANY_STATE,
        kKAPSevent_Shutdown,
        kKAPSstate_Init,
        sProcessKAPSmsg_Shutdown,
    },  

    {  
        kKAPSstate_Init,
        kKAPSevent_RCV_Commit,
        kKAPSstate_Commit,
        sProcessKAPSmsg_Commit 
     },  
    {  
        kKAPSstate_Commit,
        kKAPSevent_RCV_DH2,
        kKAPSstate_Ready,
        sProcessKAPSmsg_DH2,
    },  
    
    {  
        kKAPSstate_Init,
        kKAPSevent_RCV_DH1,
        kKAPSstate_DH1,
        sProcessKAPSmsg_DH1,
    },  
    
    {  
        kKAPSstate_DH1,
        kKAPSevent_RCV_Confirm,
        kKAPSstate_Ready,
        sProcessKAPSmsg_Confirm ,
    },  
    
     
};

#define KAPS_STATE_TABLE_SIZE (sizeof(KAPS_state_table) / sizeof(state_type_type))


static int sRecieveKAPSEvent(SCKAPSContextRef ctx, KAPSeventType event, void* data, size_t dataLen, UserValue uservalue)
{
    int     err         = CRYPT_OK;
 
    const state_type_type * table = KAPS_state_table;
    int i;
    
    for(i=0; i < KAPS_STATE_TABLE_SIZE; i++, table++)
    {
        if((event == table->event) 
           && ((ctx->state == table->current) || (table->current == ANY_STATE )))
        {
            if(table->func)
                err = (*table->func)(ctx, data, dataLen, uservalue);
            if(table->next != NO_NEW_STATE)
            {
                ctx->state = table->next;
            }
        
        };
    }
    
    return err;
}


int testTable()
{
    int                     err         = CRYPT_OK;
    struct  SCKAPSContext   ctx1;
    struct  SCKAPSContext   ctx2;
    char                    msg[] = "here is a messsage";
    
    ctx1.state = kKAPSstate_Init;
    ctx2.state = kKAPSstate_Init;
    ctx1.port = 1;
    ctx2.port = 2;
    
    
    err = sRecieveKAPSEvent(&ctx1, kKAPSevent_RCV_Commit, msg, strlen(msg), (void*) 99999);
     err = sRecieveKAPSEvent(&ctx1, kKAPSevent_RCV_DH2, msg, strlen(msg), (void*) 99999);
    err = sRecieveKAPSEvent(&ctx1, kKAPSevent_Shutdown, NULL, 0, (void*) 99999);
    
    
    err = sRecieveKAPSEvent(&ctx2, kKAPSevent_RCV_DH1, msg, strlen(msg), (void*) 99999);
    err = sRecieveKAPSEvent(&ctx1, kKAPSevent_NULL, NULL, 0, (void*) 99999);
    err = sRecieveKAPSEvent(&ctx2, kKAPSevent_RCV_Confirm, msg, strlen(msg), (void*) 99999);
    err = sRecieveKAPSEvent(&ctx2, kKAPSevent_Shutdown, NULL, 0, (void*) 99999);
    
 
    return err;
}
