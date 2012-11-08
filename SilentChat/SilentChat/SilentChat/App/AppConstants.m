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


#import "AppConstants.h"


NSString *const kSilentCircleSignupURL = @"https://accounts.silentcircle.com";

#if DEBUG_AUTH_SERVER
NSString *const kSilentCircleProvisionURL = @"http://sccps-testing.silentcircle.com";
#else
NSString *const kSilentCircleProvisionURL = @"https://sccps.silentcircle.com";
#endif
NSString *const kSilentCircleProvisionCert =   @"accounts.silentcircle.com";

NSString *const kSilentCircleXMPPCert =   @"silentcircle.com";

NSString *const kDefaultAccountDomain = @"silentcircle.com";
NSString *const kDefaultServerDomain  = NULL;

 

NSString *const kABPersonPhoneSilentPhoneLabel = @"silent phone";
NSString *const kABPersonInstantMessageServiceSilentText = @"silent circle";



// keychain constants

NSString *const kAPIKeyFormat    = @"%@.apiKey";
NSString *const kDeviceKeyFormat    = @"%@.deviceKey";

NSString *const kStorageKeyFormat = @"%@.storageKey";
NSString *const kGUIDPassphraseFormat = @"%@.guidPassphrase";
NSString *const kPassphraseMetaDataFormat = @"%@.passphraseMetaData";


NSString *const kSCErrorDomain = @"com.silentcircle.error";


NSString *const kXMPPAvailable = @"available";
NSString *const kXMPPBody = @"body";
NSString *const kXMPPChat = @"chat";
NSString *const kXMPPFrom = @"from";
NSString *const kXMPPID   = @"id";
NSString *const kXMPPResource = @"resource";
NSString *const kXMPPTo   = @"to";
NSString *const kXMPPUnavailable = @"unavailable";
NSString *const kXMPPX    = @"x";


NSString *const kSCPPNameSpace = @"http://silentcircle.com";
NSString *const kSCPPSiren = @"siren";
NSString *const kSCPPBodyTextFormat =
@"%@ has requested a private conversation protected by Silent Circle Instant Message Protocol. \nSee http://silentcircle.com for more information.";

//@implementation AppConstants
//@end
