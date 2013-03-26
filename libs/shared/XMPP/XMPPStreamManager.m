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
//  XMPPClient.m
//  silenttextlib
//
//  Created by Vinnie Moscaritolo on 2/18/13.
//  Copyright (c) 2013 Silent Circle. All rights reserved.
//

#import "XMPPStreamManager.h"
#import "DDLog.h"
#import "DDTTYLogger.h"
#import "XMPPLogging.h"

#include <tomcrypt.h>

#include "SCpubTypes.h"
#include "cryptowrappers.h"
#include "SCimp.h"
#import <CommonCrypto/CommonDigest.h>
#import "XMPPSilentCircle.h"
#import "XMPPMessage+SilentCircle.h"
#import "Siren.h"

#import "AppConstants.h"

// Log levels: off, error, warn, info, verbose
static const int ddLogLevel = LOG_LEVEL_OFF;



@interface XMPPStreamManager ()

@property (strong, nonatomic) XMPPReconnect *xmppReconnect;

@property (nonatomic, readonly) XMPPJID *localJid;

@property (nonatomic, readonly) NSString *password;

@property (nonatomic)       BOOL  isXmppConnected;
@end

@implementation XMPPStreamManager


- (id)initWithDelegate:(id)aDelegate
{
    
	if ((self = [super init]))
	{
        self.xmppSilentCircle.scimpCipherSuite = kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384;
        self.xmppSilentCircle.scimpSASMethod = kSCimpSAS_NATO;

        _delegate = aDelegate;
    }
	return self;
}


- (XMPPStream *) setupStream {
    
	NSAssert(!_xmppStream, @"Method setupStream invoked multiple times");
    
    _xmppStream = [[XMPPStream alloc] init];
    _xmppReconnect = [[XMPPReconnect alloc] init];
    
    [_xmppReconnect activate:_xmppStream];
    
    [_xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
    [_xmppReconnect addDelegate:self delegateQueue:dispatch_get_main_queue()];
  
    
    // Setup Scimp
	//
	// This module automatically encrypts/decrypts outgoing/incoming messages on the fly using SCimp.
	// We configure it to encrypt all communications.
	
    // Make sure storage gets a chance to see messages before they are SCimped.
    [_xmppStream addDelegate: self.xmppSilentCircleStorage delegateQueue: dispatch_get_main_queue()];
    
	self.xmppSilentCircle = [[XMPPSilentCircle alloc] initWithStorage: self.xmppSilentCircleStorage];
    
    // Connect up the XMPPSilentCircleDelegate methods.
    [self.xmppSilentCircle addDelegate: self.xmppSilentCircleStorage delegateQueue: dispatch_get_main_queue()];
    
    [_xmppSilentCircle addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
    _xmppSilentCircle.scimpCipherSuite = kSCimpCipherSuite_SHA256_HMAC_AES128_ECC384;
    _xmppSilentCircle.scimpSASMethod = kSCimpSAS_NATO;
    
	[_xmppSilentCircle activate: _xmppStream];

    return _xmppStream;
    
}

- (void) teardownStream {
    
	[_xmppSilentCircle deactivate];
    [_xmppReconnect deactivate];

	_xmppSilentCircle = nil;
	_xmppSilentCircleStorage = nil;
    _password = nil;
    _localJid = nil;
    
  } // -teardownStream


-(BOOL) isConnected
{
    return _isXmppConnected;
}

- (BOOL) connectAsJID: (XMPPJID*)JID  password:(NSString*)password
{
    _localJid = JID;
    _password = password;
    
    
    return [self connect];
}

- (BOOL) connect {
    
    NSError *error = nil;
    
    if (!_xmppStream) {
        
        [self setupStream];
    }
	if (_xmppStream.isConnected && !_xmppStream.isDisconnected) { // Transition to connection is complete.
        
        return YES;
	}
	if (!_xmppStream.isConnected && !_xmppStream.isDisconnected) { // Transitioning to connection.
        
        return NO;
	}
    if (!_xmppStream.myJID) {
                 
        _xmppStream.myJID = _localJid;
    }
    

    if (![_xmppStream oldSchoolSecureConnect:&error]) {
            
            DDLogError(@"Error connecting: %@", error);
            
            return NO;
        }
        return YES;
        
} // -connect
    

- (void)goOnline
{
    XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
    
    [self.xmppStream sendElement:presence];
    
    GCDMulticastDelegate <XMPPStreamManagerDelegate> *mcd = (id)[_xmppStream multicastDelegate];
    
    if(mcd)
        [mcd xmppSilentCircle:self  willGoOnline:_localJid  ];
    
}

- (void)goOffline
{
    XMPPPresence *presence = [XMPPPresence presenceWithType:@"unavailable"];
 
    [[self xmppStream] sendElement:presence];
   
    GCDMulticastDelegate <XMPPStreamManagerDelegate> *mcd = (id)[_xmppStream multicastDelegate];
    
    if(mcd)
        [mcd xmppSilentCircle:self  willGoOffline:_localJid  ];
    
}


- (void) disconnect {
    
    [self goOffline];
    [_xmppStream disconnect];
    
    
} // -disconnect


- (void) disconnectAfterSending {
    
    [self goOffline];
    [_xmppStream disconnectAfterSending];
    
    
} // -disconnectAfterSending


#pragma mark - XMPPStreamDelegate methods.
    

- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}


- (void)xmppStreamDidSecure:(XMPPStream *)sender
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStreamWillConnect:(XMPPStream *)sender
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    _isXmppConnected = YES;
    
    NSError *error = nil;

    
    if (![_xmppStream authenticateWithPassword: _password error:&error]) {
        
        DDLogError(@"Error authenticating: %@", error);
    }
    
}

- (void)xmppStreamDidAuthenticate:(XMPPStream *)sender
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    [self goOnline];
    
    
}

- (void)xmppStream:(XMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (BOOL)xmppStream:(XMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
    DDLogVerbose(@"%@: %@ - %@", THIS_FILE, THIS_METHOD, [iq elementID]);
    
    return NO;
}


- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
    DDLogVerbose(@"%@: %@ - %@", THIS_FILE, THIS_METHOD, [presence fromStr]);
}

- (void)xmppStream:(XMPPStream *)sender didReceiveError:(id)error
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStreamDidDisconnect:(XMPPStream *)sender withError:(NSError *)error
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    if (_isXmppConnected)
    {
        DDLogError(@"Unable to connect to server. Check xmppStream.hostName");
    }
    _isXmppConnected = NO;
    
}


- (void)xmppStream:(XMPPStream *)sender willSecureWithSettings:(NSMutableDictionary *)settings
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
#if VALIDATE_XMPP_CERT
    
    [settings removeAllObjects];
    
#endif
}


- (NSData *) xmppCert {
    
    NSData* xmppCertData = NULL;
    
    NSData *certData = [NSData dataWithContentsOfFile: [[NSBundle mainBundle]
                                                        pathForResource: kSilentCircleXMPPCert
                                                        ofType: @"cer"]];
    if(certData)
    {
        SecCertificateRef xmppCert = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certData);
        if(xmppCert) xmppCertData = (__bridge_transfer NSData*)SecCertificateCopyData(xmppCert);
        
    }
    
    return xmppCertData;
}



- (void)xmppStreamDidSecureWithCertificate:(XMPPStream *)sender  certificateData:(NSData *)serverCertificateData
{
    DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
    NSData* xmppCert = [self xmppCert];
    
#pragma warning  -- REMOVE BEFORE SHIP
    
    if(!xmppCert)return;
    
    uint8_t hash[CC_SHA1_DIGEST_LENGTH];
    uint8_t  xmppCertHash   [CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1([xmppCert bytes], (CC_LONG)[xmppCert length], xmppCertHash);
    CC_SHA1([serverCertificateData bytes], (CC_LONG)[serverCertificateData length], hash);
    
    if(!CMP(hash,xmppCertHash, CC_SHA1_DIGEST_LENGTH))
    {
        [self disconnect ];
        /*
         UIAlertView *alertView = nil;
         
         alertView = [[UIAlertView alloc] initWithTitle: NSLS_COMMON_CONNECT_FAILED
         message: NSLS_COMMON_CERT_FAILED
         delegate: self
         cancelButtonTitle: NSLS_COMMON_OK
         otherButtonTitles: nil];
         [alertView show];
         */
        
    }
    
    
}


    
#pragma mark - XMPPReconnectDelegate methods.
    
    - (BOOL)xmppReconnect:(XMPPReconnect *)sender shouldAttemptAutoReconnect:(SCNetworkReachabilityFlags)reachabilityFlags
    {
        DDLogVerbose(@"---------- xmppReconnect:shouldAttemptAutoReconnect: ----------");
        
        return YES;
    }
    
    - (void)xmppReconnect:(XMPPReconnect *)sender didDetectAccidentalDisconnect:(SCNetworkReachabilityFlags)connectionFlags
    {
        DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
        
    }




@end
