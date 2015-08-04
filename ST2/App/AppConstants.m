/*
Copyright (C) 2014-2015, Silent Circle, LLC. All rights reserved.

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
#import "AppConstants.h"

@implementation AppConstants

static BOOL isIPhone;
static BOOL isIPhone5;
static BOOL isIPhone6;
static BOOL isIPhone6Plus;
static BOOL isIPad;
static BOOL isIOS7OrLater;
static BOOL isIOS8OrLater;
static BOOL isLessThanIOS8;


#pragma mark -  key hashes

/* old key Hashes */

//	static uint8_t oldProductionWebAPIKeyHash[] =
//	{   0x26, 0x2F, 0xCD, 0x3A, 0x68, 0x11, 0xA0, 0xFF,
//        0x7F, 0xDA, 0xCB, 0xB5, 0x4A, 0x57, 0x2C, 0x6F,
//        0xEE, 0xAE, 0x19, 0x9C, 0xC0, 0xAD, 0x77, 0x95,
//        0xE7, 0xFC, 0xEC, 0xFA, 0x1A, 0xD1, 0xE7, 0xC5
//	};
//
//
//    static uint8_t oldProductionXmppKeyHash[] =
//	{   0xCB, 0x9B, 0xAE, 0x9E, 0x08, 0x64, 0x60, 0xC2,
//        0xB2, 0xF1, 0x27, 0x1F, 0x02, 0xE5, 0x29, 0xBD,
//        0x83, 0xEF, 0x1C, 0xD8, 0xCF, 0xBB, 0xA3, 0xA1,
//        0x7D, 0x9F, 0x7D, 0x82, 0xE1, 0x6C, 0x29, 0x4B
//	};

//    static uint8_t oldDevXmppKeyHash[] =
//	{   0xEE, 0xC0, 0x63, 0x3C, 0x2E, 0xBF, 0xA0, 0x1C,
//        0xDE, 0x60, 0x4B, 0x33, 0xC2, 0x77, 0x31, 0x44,
//        0xF6, 0xAC, 0x29, 0x7D, 0xE2, 0xA3, 0x59, 0xBC,
//        0x09, 0x5E, 0x3E, 0x7A, 0x6D, 0xB9, 0xB5, 0x78
//	};
//
//
//    static uint8_t oldQAWebAPIKeyHash[] =
//	{   0xD4, 0xD5, 0x79, 0x3C, 0x90, 0x62, 0xA9, 0xE4,
//        0x0C, 0x10, 0xE5, 0xB9, 0x5E, 0xEC, 0x59, 0xF1,
//        0xCB, 0x2A, 0x00, 0x78, 0x8B, 0x0F, 0xD3, 0x55,
//        0x76, 0x67, 0x46, 0x6E, 0x74, 0xDF, 0x7B, 0x2C
//	};




#pragma mark  silentcircle.com (production)

/*
 
 ----------
 
 $openssl req -pubkey -noout -in xmpp-production.csr
 
 ----BEGIN PUBLIC KEY----
 MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAns0JFSyOC68Q0zfNePmj
 i2TVM9NMRkMhO4EcTmMsxWtv0q5baT28E5vIVmftMzE2HT8+L40o6AON6Xxheiuf
 M554AqOCz7SfmP5clMxu2mK4vph+bBHiQsqOshoNLKnewrmuYiwDKecLh0lpyRLU
 JV2DRhQwFnHMtX05540ziJcYP2PduaiRXug7zkN8UC3k1/hh54cwrvi+n/i3f7PN
 iKm9lcPCZq6kafuBXxhaosIc8SwTQiB/rymas60HtZUjacFXSje7SpMms0EBZxWM
 OvKdObwgMzO98ZDqmrxl5akQYh9MfSRslaRDmgb1NwaX5QIyYyHqWtQ2DMArU+D9
 xwIDAQAB
 ----END PUBLIC KEY----
 
 
 i2d_X509_PUBKEY (294 bytes)
 
 30 82 01 22 30 0D 06 09 2A 86 48 86 F7 0D 01 01
 01 05 00 03 82 01 0F 00 30 82 01 0A 02 82 01 01
 00 9E CD 09 15 2C 8E 0B AF 10 D3 37 CD 78 F9 A3
 8B 64 D5 33 D3 4C 46 43 21 3B 81 1C 4E 63 2C C5
 6B 6F D2 AE 5B 69 3D BC 13 9B C8 56 67 ED 33 31
 36 1D 3F 3E 2F 8D 28 E8 03 8D E9 7C 61 7A 2B 9F
 33 9E 78 02 A3 82 CF B4 9F 98 FE 5C 94 CC 6E DA
 62 B8 BE 98 7E 6C 11 E2 42 CA 8E B2 1A 0D 2C A9
 DE C2 B9 AE 62 2C 03 29 E7 0B 87 49 69 C9 12 D4
 25 5D 83 46 14 30 16 71 CC B5 7D 39 E7 8D 33 88
 97 18 3F 63 DD B9 A8 91 5E E8 3B CE 43 7C 50 2D
 E4 D7 F8 61 E7 87 30 AE F8 BE 9F F8 B7 7F B3 CD
 88 A9 BD 95 C3 C2 66 AE A4 69 FB 81 5F 18 5A A2
 C2 1C F1 2C 13 42 20 7F AF 29 9A B3 AD 07 B5 95
 23 69 C1 57 4A 37 BB 4A 93 26 B3 41 01 67 15 8C
 3A F2 9D 39 BC 20 33 33 BD F1 90 EA 9A BC 65 E5
 A9 10 62 1F 4C 7D 24 6C 95 A4 43 9A 06 F5 37 06
 97 E5 02 32 63 21 EA 5A D4 36 0C C0 2B 53 E0 FD
 C7 02 03 01 00 01
 
 
 SHA-256	8A DD 13 4E D6 4E 7C C1 89 AB 09 A6 34 BD D1 FF 7E 77 CF 6B CD 97 5E F8 90 C7 5A 3C C6 CB FE A4
 
 */


static uint8_t newProductionXmppKeyHash[] =
{   0x8A, 0xDD, 0x13, 0x4E, 0xD6, 0x4E, 0x7C, 0xC1,
    0x89, 0xAB, 0x09, 0xA6, 0x34, 0xBD, 0xD1, 0xFF,
    0x7E, 0x77, 0xCF, 0x6B, 0xCD, 0x97, 0x5E, 0xF8,
    0x90, 0xC7, 0x5A, 0x3C, 0xC6, 0xCB, 0xFE, 0xA4
    
};


/*
 
 
 $openssl req -pubkey -noout -in sccps-production.csr
 
 -----BEGIN PUBLIC KEY-----
 MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAt6eDb+eO01NcHILx+JLT
 8k9d0jIU4K/3LxTEbcyK6y9A+SQeO/XLcWXzRjwraiwLiddBgdC7/QKHcVVeUNR7
 nopMtiMng1BSsyjh50AvOZK+bd6B3TYvSly4XR93osaFPumvZ98po0Fh98+Em4Ve
 Dxw0yJ1pTIzvayjjNU+prttRbPo6c89L/OJfkTfIB5IhTUXNmflQaSOA8PFrW27e
 mph0zL+U08Ql9TsH3KMKs0MNyKDMSfRrPRxZjTOMa5zspmO6ZbxF7yxFzYuwottJ
 tAG6vjzPwpAzxcwrHLqKuuiYJCl/kXPjfn/F36pAq4K4TDmxEKsO2W4m37BQao8A
 /QIDAQAB
 -----END PUBLIC KEY-----
 
 i2d_X509_PUBKEY(294)
 
 30 82 01 22 30 0D 06 09 2A 86 48 86 F7 0D 01 01
 01 05 00 03 82 01 0F 00 30 82 01 0A 02 82 01 01
 00 B7 A7 83 6F E7 8E D3 53 5C 1C 82 F1 F8 92 D3
 F2 4F 5D D2 32 14 E0 AF F7 2F 14 C4 6D CC 8A EB
 2F 40 F9 24 1E 3B F5 CB 71 65 F3 46 3C 2B 6A 2C
 0B 89 D7 41 81 D0 BB FD 02 87 71 55 5E 50 D4 7B
 9E 8A 4C B6 23 27 83 50 52 B3 28 E1 E7 40 2F 39
 92 BE 6D DE 81 DD 36 2F 4A 5C B8 5D 1F 77 A2 C6
 85 3E E9 AF 67 DF 29 A3 41 61 F7 CF 84 9B 85 5E
 0F 1C 34 C8 9D 69 4C 8C EF 6B 28 E3 35 4F A9 AE
 DB 51 6C FA 3A 73 CF 4B FC E2 5F 91 37 C8 07 92
 21 4D 45 CD 99 F9 50 69 23 80 F0 F1 6B 5B 6E DE
 9A 98 74 CC BF 94 D3 C4 25 F5 3B 07 DC A3 0A B3
 43 0D C8 A0 CC 49 F4 6B 3D 1C 59 8D 33 8C 6B 9C
 EC A6 63 BA 65 BC 45 EF 2C 45 CD 8B B0 A2 DB 49
 B4 01 BA BE 3C CF C2 90 33 C5 CC 2B 1C BA 8A BA
 E8 98 24 29 7F 91 73 E3 7E 7F C5 DF AA 40 AB 82
 B8 4C 39 B1 10 AB 0E D9 6E 26 DF B0 50 6A 8F 00
 FD 02 03 01 00 01
 
 
 SHA-256 8ed194c579d749dd3ae7aedaa2f5a8af9fc9ebe4522e408fce6f7b17a46e97bd
 
 */

static uint8_t newProductionWebAPIKeyHash[] =
{   0x8E, 0xD1, 0x94, 0xC5, 0x79, 0xD7, 0x49, 0xDD,
    0x3A, 0xE7, 0xAE, 0xDA, 0xA2, 0xF5, 0xA8, 0xAF,
    0x9F, 0xC9, 0xEB, 0xE4, 0x52, 0x2E, 0x40, 0x8F,
    0xCE, 0x6F, 0x7B, 0x17, 0xA4, 0x6E, 0x97, 0xBD
};


#pragma mark qa.silentcircle.net

/*
 ----------
 
 $openssl req -pubkey -noout -in xmpp-qa.csr
 
 ----BEGIN PUBLIC KEY----
 MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApGH4LX7AO8VhE0ckYl22
 k9/Dk9YZNQLpR4/a1ysZHLPsDEjGdFYeadxCKuGwCEYqI2kljcY2fvTqVzLkm5J7
 ipIA1GxsoWtGMQzBBiPxfpzoqHfr+HMSlyGJEcaC1lbKRM9OpmnWBtyQulTvq0IY
 1p8T11aiMgslicWlaDeXjczugdRabuUkIzmh2wC0joALQlJ0FDafJuE73fL6LAXW
 OWc291Xi8Pq8XKWLLRaiiX0mdr6LX91DNBdkPdiEvMGBzLRmRfisn07hYpSXugn0
 WUemJvhuz3kFrg7ktrG7Ore49czvViTc/vAFF4O+hYVvG04aS5mpXf0IkVkiAeGW
 JQIDAQAB
 ----END PUBLIC KEY----
 
 i2d_X509_PUBKEY(294)
 
 30 82 01 22 30 0D 06 09 2A 86 48 86 F7 0D 01 01
 01 05 00 03 82 01 0F 00 30 82 01 0A 02 82 01 01
 00 A4 61 F8 2D 7E C0 3B C5 61 13 47 24 62 5D B6
 93 DF C3 93 D6 19 35 02 E9 47 8F DA D7 2B 19 1C
 B3 EC 0C 48 C6 74 56 1E 69 DC 42 2A E1 B0 08 46
 2A 23 69 25 8D C6 36 7E F4 EA 57 32 E4 9B 92 7B
 8A 92 00 D4 6C 6C A1 6B 46 31 0C C1 06 23 F1 7E
 9C E8 A8 77 EB F8 73 12 97 21 89 11 C6 82 D6 56
 CA 44 CF 4E A6 69 D6 06 DC 90 BA 54 EF AB 42 18
 D6 9F 13 D7 56 A2 32 0B 25 89 C5 A5 68 37 97 8D
 CC EE 81 D4 5A 6E E5 24 23 39 A1 DB 00 B4 8E 80
 0B 42 52 74 14 36 9F 26 E1 3B DD F2 FA 2C 05 D6
 39 67 36 F7 55 E2 F0 FA BC 5C A5 8B 2D 16 A2 89
 7D 26 76 BE 8B 5F DD 43 34 17 64 3D D8 84 BC C1
 81 CC B4 66 45 F8 AC 9F 4E E1 62 94 97 BA 09 F4
 59 47 A6 26 F8 6E CF 79 05 AE 0E E4 B6 B1 BB 3A
 B7 B8 F5 CC EF 56 24 DC FE F0 05 17 83 BE 85 85
 6F 1B 4E 1A 4B 99 A9 5D FD 08 91 59 22 01 E1 96
 25 02 03 01 00
 
 
 SHA-256	bfd44d71679be19497b67065afd8305cde997a8a8c799075428cde89b918fbc9
 
 */
static uint8_t newQAXmppKeyHash[] =
{
    0xBF, 0xD4, 0x4D, 0x71, 0x67, 0x9B, 0xE1, 0x94,
    0x97, 0xB6, 0x70, 0x65, 0xAF, 0xD8, 0x30, 0x5C,
    0xDE, 0x99, 0x7A, 0x8A, 0x8C, 0x79, 0x90, 0x75,
    0x42, 0x8C, 0xDE, 0x89, 0xB9, 0x18, 0xFB, 0xC9

};


/*
 
 $openssl req -pubkey -noout -in sccps-qa.csr
 -----BEGIN PUBLIC KEY-----
 MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAt2qmbsKfW0OXPk0RRwq8
 EfyiRQxUmR3jUDV44IaXrN2kmrCI9fJwhtGbg02petxlbGEIS8QjrFXU+5c0cjhS
 hE5T1nOneMO1L8c/Of58Igbxa86B9Oy28S+QGkExNFl2ZldmoS+xfmfjlq/9amtV
 ojscSkxpVmde1Zstl8hwaIHpx6aCUuwjoWhKfK8jPlIbeYQ2WPcVLZLSPAvMuf/A
 R+DwVyrmajXt/uRKgjyFvJcUXnxZNAXptQypqwZfBeu2gcnC3xQSomtCSpbCDUJf
 VLjnXgxmOzQ7WlqLPxSAKggoVYZ075ZKXA0HArO+FZ6LTvDYUchVBa0m2bKQiqHM
 iwIDAQAB
 -----END PUBLIC KEY-----
 
 
 i2d_X509_PUBKEY(294)
 
 30 82 01 22 30 0D 06 09 2A 86 48 86 F7 0D 01 01
 01 05 00 03 82 01 0F 00 30 82 01 0A 02 82 01 01
 00 B7 6A A6 6E C2 9F 5B 43 97 3E 4D 11 47 0A BC
 11 FC A2 45 0C 54 99 1D E3 50 35 78 E0 86 97 AC
 DD A4 9A B0 88 F5 F2 70 86 D1 9B 83 4D A9 7A DC
 65 6C 61 08 4B C4 23 AC 55 D4 FB 97 34 72 38 52
 84 4E 53 D6 73 A7 78 C3 B5 2F C7 3F 39 FE 7C 22
 06 F1 6B CE 81 F4 EC B6 F1 2F 90 1A 41 31 34 59
 76 66 57 66 A1 2F B1 7E 67 E3 96 AF FD 6A 6B 55
 A2 3B 1C 4A 4C 69 56 67 5E D5 9B 2D 97 C8 70 68
 81 E9 C7 A6 82 52 EC 23 A1 68 4A 7C AF 23 3E 52
 1B 79 84 36 58 F7 15 2D 92 D2 3C 0B CC B9 FF C0
 47 E0 F0 57 2A E6 6A 35 ED FE E4 4A 82 3C 85 BC
 97 14 5E 7C 59 34 05 E9 B5 0C A9 AB 06 5F 05 EB
 B6 81 C9 C2 DF 14 12 A2 6B 42 4A 96 C2 0D 42 5F
 54 B8 E7 5E 0C 66 3B 34 3B 5A 5A 8B 3F 14 80 2A
 08 28 55 86 74 EF 96 4A 5C 0D 07 02 B3 BE 15 9E
 8B 4E F0 D8 51 C8 55 05 AD 26 D9 B2 90 8A A1 CC
 8B 02 03 01 00 01
 
 
 SHA-256	SHA-256	5650dd750abc6fe5376814461a3bf4aed6913c1cbf0e53568d642953424b3e37
 
 
 */

static uint8_t newQAWebAPIKeyHash[] =
{   0x56, 0x50, 0xDD, 0x75, 0x0A, 0xBC, 0x6F, 0xE5,
    0x37, 0x68, 0x14, 0x46, 0x1A, 0x3B, 0xF4, 0xAE,
    0xD6, 0x91, 0x3C, 0x1C, 0xBF, 0x0E, 0x53, 0x56,
    0x8D, 0x64, 0x29, 0x53, 0x42, 0x4B, 0x3E, 0x37

};


#pragma mark testing.silentcircle.net

/*
 
 
 $openssl req -pubkey -noout -in xmpp-testing.csr
 
 ----BEGIN PUBLIC KEY----
 MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoSbTwwVZZedhgYAHmPXc
 9PdzHnryI0BoayPnkyoypi8kkaeVHicx/YcZsyrSEx0/RsFahNhGjPTkAaa7kvsa
 2/Q1ZGs53OEITvm3kV1mVuzY5+/ZaX+oi5IH1A6I6EHcAREJ3RI/xdRzG6JyT7sh
 6SUMukcAyu+pPNXf1LJQHooFbGCaK7NC08fAw3Yb2rYSwhcGgnaUSbtEMwhcUCFG
 obwCsHTy3EXLHuM3IhD3Ggg8780km0p4A3LijQf87RhZu6ZVwoHCrKR5jgZN1n6z
 6k5vrq6iva60dTbgF0Augls3idkDHjnMIrSFz4cztz9fjQogYD0Ns2ONvDLuib+m
 AwIDAQAB
 ----END PUBLIC KEY----
 
 
 i2d_X509_PUBKEY(294)
 
 30 82 01 22 30 0D 06 09 2A 86 48 86 F7 0D 01 01
 01 05 00 03 82 01 0F 00 30 82 01 0A 02 82 01 01
 00 A1 26 D3 C3 05 59 65 E7 61 81 80 07 98 F5 DC
 F4 F7 73 1E 7A F2 23 40 68 6B 23 E7 93 2A 32 A6
 2F 24 91 A7 95 1E 27 31 FD 87 19 B3 2A D2 13 1D
 3F 46 C1 5A 84 D8 46 8C F4 E4 01 A6 BB 92 FB 1A
 DB F4 35 64 6B 39 DC E1 08 4E F9 B7 91 5D 66 56
 EC D8 E7 EF D9 69 7F A8 8B 92 07 D4 0E 88 E8 41
 DC 01 11 09 DD 12 3F C5 D4 73 1B A2 72 4F BB 21
 E9 25 0C BA 47 00 CA EF A9 3C D5 DF D4 B2 50 1E
 8A 05 6C 60 9A 2B B3 42 D3 C7 C0 C3 76 1B DA B6
 12 C2 17 06 82 76 94 49 BB 44 33 08 5C 50 21 46
 A1 BC 02 B0 74 F2 DC 45 CB 1E E3 37 22 10 F7 1A
 08 3C EF CD 24 9B 4A 78 03 72 E2 8D 07 FC ED 18
 59 BB A6 55 C2 81 C2 AC A4 79 8E 06 4D D6 7E B3
 EA 4E 6F AE AE A2 BD AE B4 75 36 E0 17 40 2E 82
 5B 37 89 D9 03 1E 39 CC 22 B4 85 CF 87 33 B7 3F
 5F 8D 0A 20 60 3D 0D B3 63 8D BC 32 EE 89 BF A6
 03 02 03 01 00 01
 
 SHA-256	b8f7bb35f04095601115851c15805bb5b95b6ad67832eddb2d076b2237911067

  */

static uint8_t newTestXmppKeyHash[] =
{
    0xB8, 0xF7, 0xBB, 0x35, 0xF0, 0x40, 0x95, 0x60,
    0x11, 0x15, 0x85, 0x1C, 0x15, 0x80, 0x5B, 0xB5,
    0xB9, 0x5B, 0x6A, 0xD6, 0x78, 0x32, 0xED, 0xDB,
    0x2D, 0x07, 0x6B, 0x22, 0x37, 0x91, 0x10, 0x67
};



 /*
 
 $openssl req -pubkey -noout -in sccps-testing.csr
 -----BEGIN PUBLIC KEY-----
 MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAz6EseVGmWjCp3moGrCP6
 VwebpaKWpIc6ywjCsnAPqO81NnaLSiRAT4gDCUFZzyqkmrHVR5hSfHMCnfTaijLt
 jSKjxOcAqa6uxwCDAc6MUTNoQzG2uUXgUBqP3UxADYbd1W1thgB16Ht969Rhy3Sl
 6C5roCcJ7YijcJQw5cx+QdFJnfVhJOavKp//JZerGPeLyHeO59xmQ8RpFEg8WggY
 sgVRE1gqAi4CoqNSbTw0m2Klsb81rflphHHb171tWJAO8Bo2Fuxcx9p2UxEVamUs
 laRKoSOcFCX7K8X1F0P5oor45a+2gqBZps7LkWrVwokJHILnZ9/gIAJ3xL6uGrvb
 SwIDAQAB
 -----END PUBLIC KEY-----
 
  i2d_X509_PUBKEY(294)

  30 82 01 22 30 0D 06 09 2A 86 48 86 F7 0D 01 01
  01 05 00 03 82 01 0F 00 30 82 01 0A 02 82 01 01
  00 CF A1 2C 79 51 A6 5A 30 A9 DE 6A 06 AC 23 FA
  57 07 9B A5 A2 96 A4 87 3A CB 08 C2 B2 70 0F A8
  EF 35 36 76 8B 4A 24 40 4F 88 03 09 41 59 CF 2A
  A4 9A B1 D5 47 98 52 7C 73 02 9D F4 DA 8A 32 ED
  8D 22 A3 C4 E7 00 A9 AE AE C7 00 83 01 CE 8C 51
  33 68 43 31 B6 B9 45 E0 50 1A 8F DD 4C 40 0D 86
  DD D5 6D 6D 86 00 75 E8 7B 7D EB D4 61 CB 74 A5
  E8 2E 6B A0 27 09 ED 88 A3 70 94 30 E5 CC 7E 41
  D1 49 9D F5 61 24 E6 AF 2A 9F FF 25 97 AB 18 F7
  8B C8 77 8E E7 DC 66 43 C4 69 14 48 3C 5A 08 18
  B2 05 51 13 58 2A 02 2E 02 A2 A3 52 6D 3C 34 9B
  62 A5 B1 BF 35 AD F9 69 84 71 DB D7 BD 6D 58 90
  0E F0 1A 36 16 EC 5C C7 DA 76 53 11 15 6A 65 2C
  95 A4 4A A1 23 9C 14 25 FB 2B C5 F5 17 43 F9 A2
  8A F8 E5 AF B6 82 A0 59 A6 CE CB 91 6A D5 C2 89
  09 1C 82 E7 67 DF E0 20 02 77 C4 BE AE 1A BB DB
  4B 02 03 01 00 01
  
  
 SHA-256	SHA-256	35e9f63061ffa856fe3bf5553b6f04ae5aa5e346d0f3ac2a00eb9c7fb1c1a7a7
 
 
 */

static uint8_t newTestWebAPIKeyHash[] =
{   0x35, 0xE9, 0xF6, 0x30, 0x61, 0xFF, 0xA8, 0x56,
    0xFE, 0x3B, 0xF5, 0x55, 0x3B, 0x6F, 0x04, 0xAE,
    0x5A, 0xA5, 0xE3, 0x46, 0xD0, 0xF3, 0xAC, 0x2A,
    0x00, 0xEB, 0x9C, 0x7F, 0xB1, 0xC1, 0xA7, 0xA7
};





#pragma mark dev.silentcircle.net

/*
 
 $openssl req -pubkey -noout -in xmpp-dev.csr
 
 ----BEGIN PUBLIC KEY----
 MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtyxIxNBbHrGJJu92U/+s
 i/1EmAka+IYCr1Ai6ix5A95RXxJSz07yihKQdGjjAieiCSMCBOMnXVWeE228nTEN
 yqznzKSSXbP3cYx815EHvMnfKKPqtNIAZ4wf7yEEnpTeBKUmHoJtTfjffSiYR0Kv
 tITjRlYzFE/euEYrzhJa9p/BW6xXjBR1r7icvm1pqAGqjqSvukFSPcWUKFebCWte
 3W+fTrbef9GNlqrpINa0foYOK+Lcru6mfNP+F1tuL3U5XVUEmrKqXw7M47tm3SlO
 owmGD17J2sfYp554cn4yjKfFywI2MEXyKrGpFoGHXt5Ninkw/hg9IFpghPptZsnj
 EwIDAQAB
 ----END PUBLIC KEY----
 
 i2d_X509_PUBKEY(294)

 30 82 01 22 30 0D 06 09 2A 86 48 86 F7 0D 01 01
 01 05 00 03 82 01 0F 00 30 82 01 0A 02 82 01 01
 00 B7 2C 48 C4 D0 5B 1E B1 89 26 EF 76 53 FF AC
 8B FD 44 98 09 1A F8 86 02 AF 50 22 EA 2C 79 03
 DE 51 5F 12 52 CF 4E F2 8A 12 90 74 68 E3 02 27
 A2 09 23 02 04 E3 27 5D 55 9E 13 6D BC 9D 31 0D
 CA AC E7 CC A4 92 5D B3 F7 71 8C 7C D7 91 07 BC
 C9 DF 28 A3 EA B4 D2 00 67 8C 1F EF 21 04 9E 94
 DE 04 A5 26 1E 82 6D 4D F8 DF 7D 28 98 47 42 AF
 B4 84 E3 46 56 33 14 4F DE B8 46 2B CE 12 5A F6
 9F C1 5B AC 57 8C 14 75 AF B8 9C BE 6D 69 A8 01
 AA 8E A4 AF BA 41 52 3D C5 94 28 57 9B 09 6B 5E
 DD 6F 9F 4E B6 DE 7F D1 8D 96 AA E9 20 D6 B4 7E
 86 0E 2B E2 DC AE EE A6 7C D3 FE 17 5B 6E 2F 75
 39 5D 55 04 9A B2 AA 5F 0E CC E3 BB 66 DD 29 4E
 A3 09 86 0F 5E C9 DA C7 D8 A7 9E 78 72 7E 32 8C
 A7 C5 CB 02 36 30 45 F2 2A B1 A9 16 81 87 5E DE
 4D 8A 79 30 FE 18 3D 20 5A 60 84 FA 6D 66 C9 E3
 13 02 03 01 00 01
 
 SHA-256	cfa05c16ca94349a4928c297b26aa8cba4f48e58bfeebe755e86859abb847ac8
 */

static uint8_t newDevXmppKeyHash[] =
{
    0xCF, 0xA0, 0x5C, 0x16, 0xCA, 0x94, 0x34, 0x9A,
    0x49, 0x28, 0xC2, 0x97, 0xB2, 0x6A, 0xA8, 0xCB,
    0xA4, 0xF4, 0x8E, 0x58, 0xBF, 0xEE, 0xBE, 0x75,
    0x5E, 0x86, 0x85, 0x9A, 0xBB, 0x84, 0x7A, 0xC8
};

// newDevWebAPIKeyHash  is same as newQAWebAPIKeyHash

#define newDevWebAPIKeyHash  newQAWebAPIKeyHash


//#define iPhone6 ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && MAX([UIScreen mainScreen].bounds.size.height,[UIScreen mainScreen].bounds.size.width) == 667)
//#define iPhone6Plus ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone && MAX([UIScreen mainScreen].bounds.size.height,[UIScreen mainScreen].bounds.size.width) == 736)

#pragma mark -

+ (void)initialize
{
	static BOOL initialized = NO;
	if (!initialized)
	{
		initialized = YES;
		
		UIUserInterfaceIdiom userInterfaceIdiom = [[UIDevice currentDevice] userInterfaceIdiom];
		isIPhone = (userInterfaceIdiom == UIUserInterfaceIdiomPhone);
        isIPhone5 = (userInterfaceIdiom == UIUserInterfaceIdiomPhone && 
                     MAX([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width) == 568);
        isIPhone6 = (userInterfaceIdiom == UIUserInterfaceIdiomPhone && 
                     MAX([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width) == 667);
        isIPhone6Plus = (userInterfaceIdiom == UIUserInterfaceIdiomPhone && 
                         MAX([UIScreen mainScreen].bounds.size.height,[UIScreen mainScreen].bounds.size.width) == 736);
		isIPad   = (userInterfaceIdiom == UIUserInterfaceIdiomPad);
		
		NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
		if ([systemVersion compare:@"7.0" options:NSNumericSearch] != NSOrderedAscending) {
			isIOS7OrLater = YES;
		}
        if ([systemVersion compare:@"8.0" options:NSNumericSearch] != NSOrderedAscending) {
            isIOS8OrLater = YES;
        }
        
        isLessThanIOS8 = (isIOS7OrLater && NO == isIOS8OrLater);
	}
}

+ (BOOL)isIPhone
{
	return isIPhone;
}

+ (BOOL)isIPhone5
{
    return isIPhone5;
}

+ (BOOL)isIPhone6
{
    return isIPhone6;
}

+ (BOOL)isIPhone6Plus
{
    return isIPhone6Plus;
}

+ (BOOL)isIPad
{
	return isIPad;
}

+ (BOOL)isIOS7OrLater
{
	return isIOS7OrLater;
}

+ (BOOL)isIOS8OrLater
{
	return isIOS8OrLater;
}

+ (BOOL)isLessThanIOS8
{
    return isLessThanIOS8;
}

+ (XMPPJID *)stInfoJID
{
	static XMPPJID *stInfoJID = nil;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		stInfoJID = [XMPPJID jidWithString:@"info.silentcircle.com"];
	});
	
	return stInfoJID;
}

+ (XMPPJID *)ocaVoicemailJID
{
	static XMPPJID *ocaVoicemailJID = nil;
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		ocaVoicemailJID = [XMPPJID jidWithString:@"voicemail.silentcircle.com"];
	});
	
	return ocaVoicemailJID;
}

BOOL IsSTInfoJID(XMPPJID *jid)
{
	if ([jid isEqualToJID:[AppConstants stInfoJID] options:XMPPJIDCompareFull])
		return YES;
	
	if ([[jid full] isEqualToString:kSTInfoUsername_deprecated])
		return YES;
	
	return NO;
}

BOOL IsSTInfoJidStr(NSString *jidStr)
{
	if ([jidStr isEqualToString:[[AppConstants stInfoJID] full]])
		return YES;
	
	if ([jidStr isEqualToString:kSTInfoUsername_deprecated])
		return YES;
	
	return NO;
}

BOOL IsOCAVoicemailJID(XMPPJID *jid)
{
	if ([jid isEqualToJID:[AppConstants ocaVoicemailJID] options:XMPPJIDCompareFull])
		return YES;
	
	if ([jid.user isEqualToString:@"scvoicemail"]) // e.g.: scvoicemail@xmpp-dev.silentcircle.net
		return YES;
	
	if ([[jid full] isEqualToString:kOCAVoicemailUsername_deprecated])
		return YES;
	
	return NO;
}

BOOL IsOCAVoicemailJidStr(NSString *jidStr)
{
	if ([jidStr isEqualToString:[[AppConstants ocaVoicemailJID] full]])
		return YES;
	
	if ([jidStr hasPrefix:@"scvoicemail@"]) // e.g.: scvoicemail@xmpp-dev.silentcircle.net
		return YES;
	
	if ([jidStr isEqualToString:kOCAVoicemailUsername_deprecated])
		return YES;
	
	return NO;
}

+ (NSString *)STInfoDisplayName
{
	return NSLocalizedString(@"- Do Not Reply -", @"- Do Not Reply -" );
}

+ (NSString *)OCAVoicemailDisplayName
{
	return NSLocalizedString(@"- Voice Mail -", @"- Voice Mail -" );
}

+ (BOOL)isApsEnvironmentDevelopment
{
	
#if DEBUG || TARGET_IPHONE_SIMULATOR
	return YES;
#endif

	// The file looks like this:
	//
	// @#$@#$@#$@#$@#$ garbage characters %^&%^&%^&%^&%^&
	// <?xml version="1.0" encoding="UTF-8"?>
	// <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	// <plist version="1.0">
	//   <dict>
	//     <key>AppIDName</key>
	//     <string>SilentText2</string>
	//
	//     ... a bunch of other key/value pairs ...
	//
	//     <key>Entitlements</key>
	//     <dict>
	//       <key>keychain-access-groups</key>
	//         <array>
	//           <string>4D98PK6HWS.*</string>
	//         </array>
	//         <key>get-task-allow</key>
	//         <true/>
	//         <key>application-identifier</key>
	//         <string>4D98PK6HWS.com.silentcircle.ST2</string>
	//         <key>com.apple.developer.team-identifier</key>
	//         <string>4D98PK6HWS</string>
	//         <key>aps-environment</key>                                    // <- What we're looking for
	//         <string>development</string>
	//         <key>com.apple.developer.default-data-protection</key>
	//         <string>NSFileProtectionComplete</string>
	//       </dict>
	//
	//     ... a bunch of other key/value pairs ...
	//
	//   </dict>
	// </plist>
	// @#$@#$@#$@#$@#$ garbage characters %^&%^&%^&%^&%^&

    static BOOL isApsEnvironmentDevelopment = NO;
	
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
		
        // There is no provisioning profile in AppStore Apps.
		
		NSString *path = [[NSBundle mainBundle] pathForResource:@"embedded" ofType:@"mobileprovision"];
		NSData *data = [NSData dataWithContentsOfFile:path];
		if (data)
		{
			// This file is a text-based plist embedded within PCKS#7.
			// So it's readable, but there's a bunch of garbage characters before & after the plist text.
			//
			// So we've got some hackish code to extract the plist, so we can do our thing.
			
			NSMutableString *profile = [[NSMutableString alloc] initWithCapacity:data.length];
			const char *bytes = [data bytes];
			
			for (NSUInteger i = 0; i < data.length; i++) {
				[profile appendFormat:@"%c", bytes[i]];
			}
		//	NSLog(@"profile: %@", profile);
			
			NSRange startRange = [profile rangeOfString:@"<?xml "];
			NSRange endRange = [profile rangeOfString:@"</plist>"];
			
			if ((startRange.location != NSNotFound) && (endRange.location != NSNotFound))
			{
				NSRange plistRange;
				plistRange.location = startRange.location;
				plistRange.length = endRange.location + endRange.length - startRange.location;
				
				NSString *plist = [profile substringWithRange:plistRange];
		//		NSLog(@"plist: %@", plist);
				
				@try
				{
					NSData *plistData = [plist dataUsingEncoding:NSUTF8StringEncoding];
					NSDictionary *dict = [NSPropertyListSerialization propertyListWithData:plistData
					                                                               options:NSPropertyListImmutable
					                                                                format:NULL
					                                                                 error:NULL];
		//			NSLog(@"dict: %@", dict);
					
					id aps_environment = [[dict objectForKey:@"Entitlements"] objectForKey:@"aps-environment"];
		//			NSLog(@"aps-environment: (%@) (%@)", aps_environment, [aps_environment class]);
					
					if ([aps_environment isKindOfClass:[NSString class]])
					{
						NSString *value = (NSString *)aps_environment;
						
						isApsEnvironmentDevelopment = ([value caseInsensitiveCompare:@"development"] == NSOrderedSame);
					}
				}
				@catch (NSException *e)
				{
		//			NSLog(@"Error parsing mobileprovision: %@", e);
				}
			}
		}
    });
	
	return isApsEnvironmentDevelopment;
}

+ (NSDictionary *)SilentCircleNetworkInfo
{
	return @{
		kNetworkID_Production:
		@{
			@"displayName" : @"Production",
			
			@"brokerSRV"   : @"_broker-client._tcp.silentcircle.com",
			@"xmppSRV"     : @"_xmpp-client._tcp.silentcircle.com",
			
//			@"brokerURL"   : @"199.217.106.51",
//			@"brokerPort"  : @(443),

			@"xmppDomain"  : @"silentcircle.com",
			
			// These are fallback ports
			@"xmppURL"     : @"ves97t.silentcircle.net",
			@"xmppPort"    : @(443),
			
			@"xmppSHA256"  : @[ // array
			                    [NSData dataWithBytes:newProductionXmppKeyHash length:sizeof(newProductionXmppKeyHash)]
			                  ],
			
			@"webAPISHA256": @[ // array
			                    [NSData dataWithBytes:newProductionWebAPIKeyHash length:sizeof(newProductionWebAPIKeyHash)]
			                  ],
			
			@"canProvision": @(YES),
			@"canMulticast": @(YES),
			@"canDelayNotifications": @(NO),
		},
		
		
		kNetworkID_QA:
		@{
			@"displayName" : @"QA",
			@"displayColor": [UIColor colorWithRed:255/255.0f green:88/255.0f blue:161/255.0f alpha:1.0f],
			
			@"brokerSRV"   : @"_broker-client._tcp.xmpp-qa.silentcircle.net",
			@"xmppSRV"     : @"_xmpp-client._tcp.xmpp-qa.silentcircle.net",
			
//			@"brokerURL"   : @"accounts-qa.silentcircle.com",
//			@"brokerPort"  : @(443),

//			@"xmppURL"     : @"jb02q-fsyyz.silentcircle.net",
//			@"xmppPort"    : @(5223),
			
			@"xmppDomain"  : @"xmpp-qa.silentcircle.net",
			
			@"xmppSHA256"  : @[ // array
			                    [NSData dataWithBytes:newQAXmppKeyHash length:sizeof(newQAXmppKeyHash)]
			                  ],
			
			@"webAPISHA256": @[ // array
			                    [NSData dataWithBytes:newQAWebAPIKeyHash length:sizeof(newQAXmppKeyHash)]
			                  ],
			
		#if INCLUDE_QA_NET
			@"canProvision": @(YES),
		#endif
			@"canMulticast": @(YES),
			@"canDelayNotifications": @(YES),
		},
		
		
		kNetworkID_Testing:
		@{
			@"displayName" : @"Testing",
			@"displayColor": [UIColor colorWithRed:149/255.0f green:182/255.0f blue:11/255.0f alpha:1.0f],
			
			@"brokerSRV"   : @"_broker-client._tcp.xmpp-testing.silentcircle.net",
			@"xmppSRV"     : @"_xmpp-client._tcp.xmpp-testing.silentcircle.net",
			
			@"brokerURL"   : @"accounts-testing.silentcircle.com",
			@"brokerPort"  : @(443),
			
			@"xmppDomain"  : @"xmpp-testing.silentcircle.net",
			
			@"xmppSHA256"  : @[ // array
			                    [NSData dataWithBytes:newTestXmppKeyHash length:sizeof(newTestXmppKeyHash)]
			                  ],
			
			@"webAPISHA256": @[ // array
			                    [NSData dataWithBytes:newTestWebAPIKeyHash length:sizeof(newTestWebAPIKeyHash)]
			                  ],
			
		#if INCLUDE_TEST_NET
			@"canProvision": @(YES),
		#endif
			@"canMulticast": @(YES),
			@"canDelayNotifications": @(YES),
		},
		
		
		kNetworkID_Development:
		@{
			@"displayName" : @"Development",
			@"displayColor": [UIColor colorWithRed:149/255.0f green:114/255.0f blue:10/255.0f alpha:1.0f],
			
			@"brokerSRV"   : @"_broker-client._tcp.xmpp-dev.silentcircle.net",
			@"xmppSRV"     : @"_xmpp-client._tcp.xmpp-dev.silentcircle.net",
			
//			@"brokerURL"   : @"sccps-testing.silentcircle.com",
//			@"brokerPort"  : @(443),
			
//			@"brokerURL"   : @"accounts-dev.silentcircle.com",
//			@"brokerPort"  : @(443),
			
			@"xmppURL"     : @"jb01d-jtymq.silentcircle.net",
			@"xmppPort"    : @(5223),
			
			@"xmppDomain"  : @"xmpp-dev.silentcircle.net",
			
			@"xmppSHA256"  : @[ // array
			                    [NSData dataWithBytes:newDevXmppKeyHash length:sizeof(newDevXmppKeyHash)]
			                  ],
			
			@"webAPISHA256": @[ // array
			                    [NSData dataWithBytes:newDevWebAPIKeyHash length:sizeof(newDevWebAPIKeyHash)]
			                  ],

		#if INCLUDE_DEV_NET
			@"canProvision": @(YES),
		#endif
			@"canMulticast": @(YES),
			@"canDelayNotifications": @(YES),
		},
		
		
		kNetworkID_Fake:
		@{
			@"displayName" : @"Fake",
			@"displayColor": [UIColor colorWithRed:129/255.0f green:187/255.0f blue:121/255.0f alpha:1.0f],
			
			@"xmppDomain"  : @"fake.silentcircle.net",
			
			@"canProvision": @(NO),
			@"canMulticast": @(YES),
			@"canDelayNotifications": @(YES),
		},
	
	};
}

/**
 * Returns the set of all supported xmppDomains.
 * This comes from the SilentCircleNetworkInfo dictionary,
 * by populating a set from all values for @"xmppDomain" within the dictionary.
**/
+ (NSSet *)supportedXmppDomains
{
	NSDictionary *silentCircleNetworkInfo = [self SilentCircleNetworkInfo];
	
	NSMutableSet *xmppDomains = [NSMutableSet setWithCapacity:[silentCircleNetworkInfo count]];
	
	[silentCircleNetworkInfo enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
		
	//	__unsafe_unretained NSString *networkID = (NSString *)key;        // cast
		__unsafe_unretained NSDictionary *dict = (NSDictionary *)object;  // cast
		
		if ([[dict objectForKey:@"canProvision"] boolValue])
		{
			[xmppDomains addObject:[dict objectForKey:@"xmppDomain"]];
		}
	}];
	
	return [xmppDomains copy];
}

/**
 * Returns the networkID for the given xmppDomain.
 * The networkID can be used as the key within the SilentCircleNetworkInfo dictionary,
 * in order to obtain other information about the particular network.
**/
+ (NSString *)networkIdForXmppDomain:(NSString *)xmppDomain
{
	__block NSString *matchingNetworkID = nil;
	
	NSDictionary *silentCircleNetworkInfo = [self SilentCircleNetworkInfo];
	
	[silentCircleNetworkInfo enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
		
		__unsafe_unretained NSString *networkID = (NSString *)key;        // cast
		__unsafe_unretained NSDictionary *dict = (NSDictionary *)object;  // cast
		
		if ([[dict objectForKey:@"xmppDomain"] isEqualToString:xmppDomain])
		{
			matchingNetworkID = networkID;
			*stop = YES;
		}
	}];
	
	return matchingNetworkID;
}

/**
 * Convenience method to extract the xmppDomain from the SilentCircleNetworkInfo dictionary.
**/
+ (NSString *)xmppDomainForNetworkID:(NSString *)networkID
{
	NSDictionary *networkInfo = [[self SilentCircleNetworkInfo] objectForKey:networkID];
	
	return [networkInfo objectForKey:@"xmppDomain"];
}

BOOL IsProductionNetworkDomain(XMPPJID *jid)
{
	NSString *domain = jid.domain;
	if (domain == nil) return NO;
	
	NSString *prodDomain = [AppConstants xmppDomainForNetworkID:kNetworkID_Production];
	
	return [domain isEqualToString:prodDomain];
}

+ (NSString *)networkDisplayNameForJID:(XMPPJID *)jid
{
	NSString *networkID = [self networkIdForXmppDomain:jid.domain];
	NSDictionary *networkInfo = [[self SilentCircleNetworkInfo] objectForKey:networkID];
	
	return [networkInfo objectForKey:@"displayName"];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

NSString *const LocalUserActiveDeviceMayHaveChangedNotification = @"LocalUserActiveDeviceMayHaveChanged";

NSString *const kNetworkID_Production  = @"production";
NSString *const kNetworkID_QA          = @"qa";
NSString *const kNetworkID_Testing     = @"test";
NSString *const kNetworkID_Development = @"dev";
NSString *const kNetworkID_Fake        = @"fake";

NSString *const kDefaultAccountDomain = @"silentcircle.com";
NSString *const kTestNetAccountDomain  = @"silentcircle.net";;

NSString *const kSilentStorageS3Bucket = @"com.silentcircle.silenttext.scloud";
NSString *const kSilentStorageS3Mime = @"application/x-scloud";
 
NSString *const kABPersonPhoneSilentPhoneLabel = @"silent phone";
NSString *const kABPersonInstantMessageServiceSilentText = @"silent circle";



// keychain constants

NSString *const kAPIKeyFormat    = @"%@.apiKey";
NSString *const kDeviceKeyFormat    = @"%@.deviceKey";

NSString *const kStorageKeyFormat = @"%@.storageKey";
NSString *const kGUIDPassphraseFormat = @"%@.guidPassphrase";
NSString *const kPassphraseMetaDataFormat = @"%@.passphraseMetaData";


NSString *const kSCErrorDomain = @"com.silentcircle.error";


NSString *const kXMPPBody        = @"body";
NSString *const kXMPPChat        = @"chat";
NSString *const kXMPPID          = @"id";
NSString *const kXMPPThread      = @"thread";
NSString *const kXMPPNotifiable  = @"notifiable";
NSString *const kXMPPBadge       = @"badge";

NSString *const kSTInfoUsername_deprecated       = @"<silenttext>";
NSString *const kOCAVoicemailUsername_deprecated = @"<oca voicemail>";

NSString *const kSilentCircleSignupURL = @"https://accounts.silentcircle.com";

NSString *const kSCNameSpace          = @"http://silentcircle.com";
NSString *const kSCPublicKeyNameSpace = @"http://silentcircle.com/protocol/scimp#public-key";
NSString *const kSCTimestampNameSpace = @"http://silentcircle.com/timestamp";

NSString *const kSCPPSiren = @"siren";
NSString *const kSCPPPubSiren = @"pubSiren";
NSString *const kSCPPTimestamp = @"timestamp";

NSString *const kSCPPBodyTextFormat =
  @"%@ has requested a private conversation protected by Silent Circle. "
  @"See https://silentcircle.com for more information.";


// SCLOUD
NSString *const kSCBrokerSRVname = @"_broker-client._tcp.silentcircle.com";

// ???
NSString *const kStreamParamEntryNetworkID   = @"networkID";            // used for seting up stream

// SCKey
NSString *const kSCKey_Locator      = @"SCKey_locator";
NSString *const kSCKey_Key          = @"SCKey_key";

// Database Collections
NSString *const kSCCollection_STUsers            = @"users";
NSString *const kSCCollection_STScimpState       = @"scimpStates";
NSString *const kSCCollection_STMessageIDCache   = @"dups";
NSString *const kSCCollection_STPublicKeys       = @"scPublicKeys";
NSString *const kSCCollection_STSymmetricKeys    = @"scSymmetricKeys";
NSString *const kSCCollection_STSCloud           = @"scloudObjects";
NSString *const kSCCollection_STImage_Message    = @"msgThumbnails";
NSString *const kSCCollection_STSRVRecord        = @"srvRecord";
NSString *const kSCCollection_STStreamManagement = @"streamManagement";
NSString *const kSCCollection_STNotification     = @"notification";
NSString *const kSCCollection_Prefs              = @"preferences";
NSString *const kSCCollection_Upgrades           = @"upgrades";


// Mime Types
NSString *const kMimeType_vCard    = @"text/x-vcard";
NSString *const kSilentContacts_Extension =   @"silentcontacts";

// Transaction Extended Info

NSString *const kTransactionExtendedInfo_ClearedConversationId = @"clearedConversationId";
NSString *const kTransactionExtendedInfo_ClearedMessageIds = @"clearedMessageIds";

// SRV records
NSTimeInterval  const kDefaultSRVRecordLifespan  =  3600 * 24   ;   // is once a day reasonable?

