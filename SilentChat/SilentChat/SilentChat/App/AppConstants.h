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


#import <UIKit/UIKit.h>

#define VALIDATE_XMPP_CERT  1
#define DEBUG_AUTH_SERVER   0
#define HAS_FYEO            0



enum {
    kShredAfterNever =      0,
    };


extern NSString *const kSilentCircleSignupURL;
extern NSString *const kSilentCircleProvisionURL;
extern NSString *const kSilentCircleProvisionCert;
extern NSString *const kSilentCircleXMPPCert;

extern NSString *const kDefaultAccountDomain;
extern NSString *const kDefaultServerDomain;
  
extern NSString *const kABPersonPhoneSilentPhoneLabel;
extern NSString *const kABPersonInstantMessageServiceSilentText;
extern NSString *const kSCErrorDomain;

// keychain items
extern NSString *const kAPIKeyFormat;
extern NSString *const kDeviceKeyFormat;
extern NSString *const kStorageKeyFormat;
extern NSString *const kGUIDPassphraseFormat;
extern NSString *const kPassphraseMetaDataFormat;
 

// XMPP items

extern NSString *const kXMPPAvailable;
extern NSString *const kXMPPBody;
extern NSString *const kXMPPChat;
extern NSString *const kXMPPFrom;
extern NSString *const kXMPPID;
extern NSString *const kXMPPResource;
extern NSString *const kXMPPTo;
extern NSString *const kXMPPUnavailable;
extern NSString *const kXMPPX;

// SCIMP items

extern NSString *const kSCPPNameSpace;
extern NSString *const kSCPPSiren;
extern NSString *const kSCPPBodyTextFormat;

