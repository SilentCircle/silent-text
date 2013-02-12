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

#include "SCimp.h"

#if SUPPORT_XML_MESSAGE_FORMAT

#include <libxml/parser.h>
#include <libxml/tree.h>
#include <libxml/xmlsave.h>


#include "SCimpPriv.h"
#include <stdio.h>
#include <errno.h>

static SCLError sParseBase64(xmlChar *str, uint8_t *out, size_t *outLen)
{
    SCLError         err = kSCLError_NoErr;
    unsigned long length = *outLen;
    
    *outLen = 0;
    
    if(base64_decode(str,  strlen((char*)str), out, &length) != CRYPT_OK)
        RETERR(kSCLError_CorruptData);
    
      *outLen = length;
    
done:
    return err;
}


SCLError scimpSerializeMessageXML( SCimpContext *ctx, SCimpMsg *msg,  uint8_t **outData, size_t *outSize)
{
    SCLError         err = kSCLError_NoErr;
    xmlDoc          *doc    = NULL;
    xmlBufferPtr    xmlBuf  = NULL;
    xmlSaveCtxtPtr  savectx = NULL;
    uint8_t         *outBuf = NULL;
    xmlChar         tempBuf[256];
    unsigned long   tempLen;
    xmlChar         *dataBuf = NULL;
     
    xmlNodePtr  node = NULL;

    doc = xmlNewDoc(BAD_CAST "1.0");
    

    switch(msg->msgType)
    {
        case kSCimpMsg_Commit:
        {
            node = xmlNewNode(NULL, BAD_CAST "commit");
            xmlDocSetRootElement(doc, node);

            sprintf(tempBuf, "%d", msg->commit.version);
            xmlNewChild(node, NULL, BAD_CAST "version", tempBuf);
            
            sprintf(tempBuf, "%d", msg->commit.cipherSuite);
            xmlNewChild(node, NULL, BAD_CAST "cipherSuite", BAD_CAST tempBuf);
       
            sprintf(tempBuf, "%d", msg->commit.sasMethod);
            xmlNewChild(node, NULL, BAD_CAST "sasMethod", BAD_CAST tempBuf);
            
            tempLen = sizeof(tempBuf);
            base64_encode(msg->commit.Hpki,SCIMP_HASH_LEN, tempBuf, &tempLen);
            xmlNewChild(node, NULL, BAD_CAST "Hpki",  tempBuf);
            
            tempLen = sizeof(tempBuf);
            base64_encode(msg->commit.Hcs,SCIMP_MAC_LEN, tempBuf, &tempLen);
            xmlNewChild(node, NULL, BAD_CAST "Hcs",  tempBuf);
             
        }
        break;
            
        case kSCimpMsg_DH1:
        {
            node = xmlNewNode(NULL, BAD_CAST "dh1");
            xmlDocSetRootElement(doc, node);
            
            tempLen = sizeof(tempBuf);
            base64_encode(msg->dh1.pk, msg->dh1.pkLen, tempBuf, &tempLen);
            xmlNewChild(node, NULL, BAD_CAST "PKr",  tempBuf);
                
            tempLen = sizeof(tempBuf);
            base64_encode(msg->dh1.Hcs,SCIMP_MAC_LEN, tempBuf, &tempLen);
            xmlNewChild(node, NULL, BAD_CAST "Hcs",  tempBuf);
            
         }

              break;
            
        case kSCimpMsg_DH2:
        {
            node = xmlNewNode(NULL, BAD_CAST "dh2");
            xmlDocSetRootElement(doc, node);
            
            tempLen = sizeof(tempBuf);
            base64_encode(msg->dh2.pk, msg->dh2.pkLen, tempBuf, &tempLen);
            xmlNewChild(node, NULL, BAD_CAST "PKi",  tempBuf);
            
            tempLen = sizeof(tempBuf);
            base64_encode(msg->dh2.Maci,SCIMP_MAC_LEN, tempBuf, &tempLen);
            xmlNewChild(node, NULL, BAD_CAST "maci",  tempBuf);
        }
              break;
            
        case kSCimpMsg_Confirm:
        {
            node = xmlNewNode(NULL, BAD_CAST "confirm");
            xmlDocSetRootElement(doc, node);
             
            tempLen = sizeof(tempBuf);
            base64_encode(msg->confirm.Macr,SCIMP_MAC_LEN, tempBuf, &tempLen);
            xmlNewChild(node, NULL, BAD_CAST "macr",  tempBuf);
        }
             break;
            
        case kSCimpMsg_Data:
        {
            tempLen =  ((((msg->data.msgLen) + 2) / 3) * 4)+1;
            dataBuf = XMALLOC(tempLen); CKNULL(dataBuf);
            if( base64_encode(msg->data.msg, msg->data.msgLen, dataBuf, &tempLen) != CRYPT_OK)
                RETERR(kSCLError_BufferTooSmall);

            node = xmlNewDocRawNode(doc, NULL,  BAD_CAST "data", dataBuf);
            sprintf(tempBuf, "%06d", msg->data.seqNum);
            xmlSetProp(node, BAD_CAST "seq", tempBuf );
            
            tempLen = sizeof(tempBuf);
            base64_encode(msg->data.tag,16, tempBuf, &tempLen);
            xmlSetProp(node, BAD_CAST "mac", tempBuf );
        }
            break;
            
            
              
        default:
             return(kSCLError_CorruptData);
    }
    
   
    xmlBuf = xmlBufferCreate(); CKNULL(xmlBuf)
    savectx = xmlSaveToBuffer(xmlBuf, 0, XML_SAVE_NO_DECL); CKNULL(savectx)
    
    xmlSaveTree(savectx, node);
    xmlSaveClose(savectx);
     
    outBuf = XMALLOC(xmlBufferLength(xmlBuf)); CKNULL(outBuf);
    memcpy(outBuf, xmlBufferContent(xmlBuf), xmlBufferLength(xmlBuf));
     
    *outData = outBuf;
    *outSize = xmlBufferLength(xmlBuf);
  
  done:

    if(doc)
        xmlFreeDoc(doc);

    if(xmlBuf)
        xmlBufferFree(xmlBuf);
 
    if(dataBuf) 
        XFREE(dataBuf);
    
    return err;

}

static void sAdd2End(SCimpMsg **msg, SCimpMsgPtr entry)
{
    SCimpMsgPtr p = NULL;
    
    if(IsNull(*msg))
        *msg = entry;
    else 
    {
        for(p = *msg; p->next; p = p->next);
        p->next = entry;
    }
           
}

static SCLError sDeserializeCOMMIT(xmlDoc *doc, xmlNode * a_node, SCimpMsg **msg   )
{
    SCLError err = kSCLError_NoErr;
    SCimpMsgPtr p = NULL;
    xmlNode		*cur		= NULL;
    size_t      dataLen;
    
    p = XMALLOC(sizeof (SCimpMsg)); CKNULL(p);
    ZERO(p, sizeof(SCimpMsg));
         
    p->msgType = kSCimpMsg_Commit;
 
    for (cur = a_node->children; cur; cur = cur->next) 
	{
        if (cur->type == XML_ELEMENT_NODE) 
        {
            xmlChar *str = NULL;
            
            if(xmlStrcmp( cur->name, (const xmlChar *)"version") == 0)
            {
                str = xmlNodeListGetString(doc, cur->xmlChildrenNode, 1);
				if (str)
                {
                    p->commit.version =  atoi ((char*)str);
                }
            } 
            else if(xmlStrcmp( cur->name, (const xmlChar *)"cipherSuite") == 0)
            {
                str = xmlNodeListGetString(doc, cur->xmlChildrenNode, 1);
				if (str)
                {
                    p->commit.cipherSuite =  atoi ((char*)str);
                }
            } 
            else if(xmlStrcmp( cur->name, (const xmlChar *)"sasMethod") == 0)
            {
                str = xmlNodeListGetString(doc, cur->xmlChildrenNode, 1);
				if (str)
                {
                    p->commit.sasMethod =  atoi ((char*)str);
                  }
                
            } 
            else if(xmlStrcmp( cur->name, (const xmlChar *)"Hpki") == 0)
            {
                str = xmlNodeListGetString(doc, cur->xmlChildrenNode, 1);
				if (str)
                {
                    dataLen = sizeof(p->commit.Hpki);
                    err = sParseBase64(str, p->commit.Hpki, &dataLen); CKERR;
                }
            } 
            else if(xmlStrcmp( cur->name,(const xmlChar *) "Hcs") == 0)
            {
                str = xmlNodeListGetString(doc, cur->xmlChildrenNode, 1);
                if (str)
                {
                    dataLen = sizeof(p->commit.Hcs);
                    err = sParseBase64(str, p->commit.Hcs, &dataLen); CKERR;
                }
            }
            if (str) {
				xmlFree (str);
				str = NULL;
			}
        }
    }

    
    sAdd2End(msg, p);

done:
    return err;
    
}
static SCLError sDeserializeDH1(xmlDoc *doc, xmlNode * a_node, SCimpMsg **msg   )
{
    SCLError err = kSCLError_NoErr;
    
    SCimpMsgPtr p = NULL;
    xmlNode		*cur		= NULL;
    size_t      dataLen;
    
    p = XMALLOC(sizeof (SCimpMsg)); CKNULL(p);
    ZERO(p, sizeof(SCimpMsg));
    
    p->msgType = kSCimpMsg_DH1;
   
    for (cur = a_node->children; cur; cur = cur->next) 
	{
        if (cur->type == XML_ELEMENT_NODE) 
        {
            xmlChar *str = NULL;
            
            if(xmlStrcmp( cur->name, (const xmlChar *)"PKr") == 0)
            {
                str = xmlNodeListGetString(doc, cur->xmlChildrenNode, 1);
				if (str)
                {
                    dataLen = strlen(str);
                    p->dh1.pk = XMALLOC(dataLen);  CKNULL(p->dh1.pk);
                    err = sParseBase64(str, p->dh1.pk, &dataLen); CKERR;
                    p->dh1.pkLen = dataLen;
                }
            } 
             else if(xmlStrcmp( cur->name,(const xmlChar *) "Hcs") == 0)
            {
                str = xmlNodeListGetString(doc, cur->xmlChildrenNode, 1);
                if (str)
                {
                    dataLen = sizeof(p->dh1.Hcs);
                    err = sParseBase64(str, p->dh1.Hcs, &dataLen); CKERR;
                }
            }
            if (str) {
				xmlFree (str);
				str = NULL;
			}
        }
    }

    
    sAdd2End(msg, p);
    
done:
    return err;
    
}
static SCLError sDeserializeDH2(xmlDoc *doc, xmlNode * a_node, SCimpMsg **msg   )
{
    SCLError err = kSCLError_NoErr;
     
    SCimpMsgPtr p = NULL;
    xmlNode		*cur		= NULL;
    size_t      dataLen;
    
    p = XMALLOC(sizeof (SCimpMsg)); CKNULL(p);
    ZERO(p, sizeof(SCimpMsg));
    
    p->msgType = kSCimpMsg_DH2;
    
    for (cur = a_node->children; cur; cur = cur->next) 
	{
        if (cur->type == XML_ELEMENT_NODE) 
        {
            xmlChar *str = NULL;
            
            if(xmlStrcmp( cur->name, (const xmlChar *)"PKi") == 0)
            {
                str = xmlNodeListGetString(doc, cur->xmlChildrenNode, 1);
				if (str)
                {
                    dataLen = strlen(str);
                    p->dh2.pk = XMALLOC(dataLen); CKNULL(p->dh2.pk);
                    err = sParseBase64(str, p->dh2.pk, &dataLen); CKERR;
                    p->dh2.pkLen = dataLen;
                }
            } 
            else if(xmlStrcmp( cur->name,(const xmlChar *) "maci") == 0)
            {
                str = xmlNodeListGetString(doc, cur->xmlChildrenNode, 1);
                if (str)
                {
                    dataLen = sizeof(p->dh2.Maci);
                    err = sParseBase64(str, p->dh2.Maci, &dataLen); CKERR;
                }
            }
            if (str) {
				xmlFree (str);
				str = NULL;
			}
        }
    }
    
    sAdd2End(msg, p);
    
done:
    return err;
    
}
static SCLError sDeserializeConfirm(xmlDoc *doc, xmlNode * a_node, SCimpMsg **msg   )
{
    SCLError err = kSCLError_NoErr;
    
    SCimpMsgPtr p = NULL;
    xmlNode		*cur		= NULL;
    size_t      dataLen;
    
    p = XMALLOC(sizeof (SCimpMsg)); CKNULL(p);
    ZERO(p, sizeof(SCimpMsg));
    
    p->msgType = kSCimpMsg_Confirm;
    
    for (cur = a_node->children; cur; cur = cur->next) 
	{
        if (cur->type == XML_ELEMENT_NODE) 
        {
            xmlChar *str = NULL;
            
            if(xmlStrcmp( cur->name,(const xmlChar *) "macr") == 0)
            {
                str = xmlNodeListGetString(doc, cur->xmlChildrenNode, 1);
                if (str)
                {
                    dataLen = sizeof(p->confirm.Macr);
                    err = sParseBase64(str, p->confirm.Macr, &dataLen); CKERR;
                }
            }
            if (str) {
				xmlFree (str);
				str = NULL;
			}
        }
    }
    
    sAdd2End(msg, p);
    
done:
    return err;
    
}

static SCLError sDeserializeData(xmlDoc *doc, xmlNode * a_node, SCimpMsg **msg   )
{
    SCLError err = kSCLError_NoErr;
    
    SCimpMsgPtr p = NULL;
    xmlNodePtr  cur		= NULL;
    xmlAttrPtr  prop		= NULL;
    size_t      dataLen;
    
    p = XMALLOC(sizeof (SCimpMsg)); CKNULL(p);
    ZERO(p, sizeof(SCimpMsg));
    
    p->msgType = kSCimpMsg_Data;
      
    for (prop = a_node->properties; prop; prop = prop->next) 
	{
        if (prop->type == XML_ATTRIBUTE_NODE) 
        {
            xmlChar *str = NULL;
            
            if(xmlStrcmp( prop->name, (const xmlChar *)"seq") == 0)
            {
                str = xmlNodeListGetString(doc, prop->xmlChildrenNode, 1);
				if (str)
                {
                    p->data.seqNum =  atoi ((char*)str);
                }
            } 
            else if(xmlStrcmp( prop->name,(const xmlChar *) "mac") == 0)
            {
                str = xmlNodeListGetString(doc, prop->xmlChildrenNode, 1);
                if (str)
                {
                    dataLen = sizeof(p->data.tag);
                    err = sParseBase64(str, p->data.tag, &dataLen); CKERR;
                }
            }
           
            if (str) {
                xmlFree (str);
                str = NULL;
            }
        }
    }
    
     
    for (cur = a_node->children; cur; cur = cur->next) 
	{
        if (cur->type == XML_TEXT_NODE) 
        {
            xmlChar *str = NULL;
            
            str = xmlNodeListGetString(doc, cur, 1);
            if (str)
            {
                dataLen = strlen(str);
                p->data.msg = XMALLOC(dataLen); CKNULL(p->data.msg);
                err = sParseBase64(str, p->data.msg, &dataLen); CKERR;
                p->data.msgLen = dataLen;
            }
            if (str) {
				xmlFree (str);
				str = NULL;
			}
        }
    }
        
    
    sAdd2End(msg, p);
    
done:
    return err;

}




 
static SCLError sDeserializeSCIMP(xmlDoc *doc, xmlNode * a_node, SCimpMsg **msg   )
{
    SCLError err = kSCLError_NoErr;
    
    xmlNode		*cur		= NULL;
   
    for (cur = a_node; cur; cur = cur->next) 
	{
        if (cur->type == XML_ELEMENT_NODE) 
        {
            if(xmlStrcmp(cur->name,(const xmlChar *)"scimp") == 0)
            {
                 err = sDeserializeSCIMP(doc, cur->children,msg); CKERR;
             } 
            else if(xmlStrcmp(cur->name,(const xmlChar *) "commit") == 0)
            {
                err = sDeserializeCOMMIT(doc, cur, msg); CKERR;
                
            } 
            else if(xmlStrcmp(cur->name, (const xmlChar *)"dh1") == 0)
            {
                err = sDeserializeDH1(doc, cur, msg); CKERR;
                
            } 
            else if(xmlStrcmp(cur->name,(const xmlChar *)"dh2") == 0)
            {
                err = sDeserializeDH2(doc, cur, msg); CKERR;
                
            } 
            else if(xmlStrcmp(cur->name, (const xmlChar *)"confirm") == 0)
            {
                err = sDeserializeConfirm(doc, cur,msg); CKERR;
                
            } 
            else if(xmlStrcmp(cur->name, (const xmlChar *)"data") == 0)
            {
               err = sDeserializeData(doc, cur,msg); CKERR;
                
            }
             else RETERR(kSCLError_CorruptData);
         }
    }  
    
done:
    return err;
    
}
 

SCLError scimpDeserializeMessageXML( SCimpContext *ctx,  uint8_t *inData, size_t inSize, SCimpMsg **msg)
{
    SCLError     err = kSCLError_NoErr;
   
    xmlDoc	 *doc = NULL;
    xmlNodePtr root_node = NULL;
    
    doc = xmlReadMemory( (void*) inData,  inSize, NULL, 0, 0);
    if(IsNull(doc)) RETERR(kSCLError_CorruptData);
    
    root_node = xmlDocGetRootElement(doc);
    if(IsNull(root_node)) RETERR(kSCLError_CorruptData);
  
    err = sDeserializeSCIMP(doc, root_node, msg);
    xmlFreeDoc(doc);

done:
      return err;
    
}

#endif
