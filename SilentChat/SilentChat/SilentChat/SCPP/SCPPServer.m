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
//
//  SCPPServer.m
//  SilentChat
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "XMPPSilentCircle.h"

#import "SCPPServer.h"

#import "XMPPServer+Class.h"

//#define CLASS_DEBUG 1
#import "DDGMacros.h"

@interface SCPPServer () 

@property (strong, nonatomic, readwrite) XMPPSilentCircle *xmppSilentCircle;

@end

@implementation SCPPServer

@synthesize xmppSilentCircle    = _xmppSilentCircle;
@synthesize xmppSilentCircleStorage = _xmppSilentCircleStorage;
@synthesize scimpCipherSuite    = _scimpCipherSuite;
@synthesize scimpSASMethod      = _scimpSASMethod;

- (XMPPStream *) setupStream {
    
    XMPPStream *xmppStream = [super setupStream];
    
	// Setup SilentCircle
	//
	// This module automatically encrypts/decrypts outgoing/incoming messages on the fly using SCimp.
	// We configure it to encrypt all communications.
	
    // Make sure storage gets a chance to see messages before they are SCimped.
    [xmppStream addDelegate: self.xmppSilentCircleStorage delegateQueue: dispatch_get_main_queue()];
    
	self.xmppSilentCircle = [[XMPPSilentCircle alloc] initWithStorage: self.xmppSilentCircleStorage];
    
    // Connect up the XMPPSilentCircleDelegate methods.
    [self.xmppSilentCircle addDelegate: self.xmppSilentCircleStorage delegateQueue: dispatch_get_main_queue()];
	
	self.xmppSilentCircle.jidsToEncrypt = [NSSet setWithObject:[XMPPSilentCircle wildcardJID]];
    
    self.xmppSilentCircle.scimpCipherSuite = kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384;
    self.xmppSilentCircle.scimpSASMethod = kSCimpSAS_NATO;
     
	[self.xmppSilentCircle activate: xmppStream];
    
    return xmppStream;
    
} // -setupStream


- (void) teardownStream {
    
	[self.xmppSilentCircle deactivate];

	self.xmppSilentCircle = nil;
	self.xmppSilentCircleStorage = nil;
    
    [super teardownStream];
    
} // -teardownStream

@end
