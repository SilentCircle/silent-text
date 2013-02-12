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
//  XMPPServer.m
//  SilentChat
//
//  Portions based upon iPhoneXMPP sample app from the XMPPFramework.
//  Covered by the XMPPFramework BSD style license.
//
 
#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import <CFNetwork/CFNetwork.h>

#import "XMPPServer+Class.h"

#import "ServiceCredential.h"
#import "SCAccount.h"
#import "NetworkActivityIndicator.h"

#import "NSString+URLEncoding.h"

#import "GCDAsyncSocket.h"

#import "DDLog.h"
#import "DDTTYLogger.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG
static const int ddLogLevel = LOG_LEVEL_VERBOSE;
#else
static const int ddLogLevel = LOG_LEVEL_INFO;
#endif

 #define CLASS_DEBUG 1
#import "DDGMacros.h"

NSUInteger kXMPPDefaultPort = 5222;

@interface XMPPServer (Forward) 

- (void)goOnline;
- (void)goOffline;

@end

@implementation XMPPServer

@dynamic myJID;
@synthesize xmppStream = _xmppStream;
@synthesize xmppReconnect = _xmppReconnect;
@synthesize xmppCapabilities = _xmppCapabilities;
@synthesize xmppCapabilitiesStorage = _xmppCapabilitiesStorage;

//@dynamic mocRoster;
@dynamic mocCapabilities;

@dynamic password;
@dynamic username;

- (void) dealloc {
    
    [self teardownStream];
    
} // -dealloc


#pragma mark - Accessor methods.

 
- (XMPPJID *) myJID {
    
    return self.xmppStream.myJID;
    
} // -myJID


- (void) setMyJID: (XMPPJID *) myJID {
    
    self.xmppStream.myJID = myJID;
    
} // -setMyJID:



- (NSManagedObjectContext *) mocCapabilities {
    
	return [self.xmppCapabilitiesStorage mainThreadManagedObjectContext];
    
} // -mocCapabilities


- (NSString *) password {
    
    return self.account.password;
    
} // -password


- (NSString *) username {
    
    return self.account.username;
    
} // -username


- (XMPPServer *) initWithAccount: (SCAccount *) account {
    self = [super init];
    
    if (self) {
        
        self.account = account;
    }
    return self;
    
} // -init


- (XMPPStream *) activate {
    
    return [self setupStream];
    
} // -activate


- (XMPPStream *) updateStreamWithAccount: (SCAccount *) account {
    
    self.account = account;
    
    return [self setupStream];
    
} // -updateStreamWithServiceServer


#pragma mark - Class methods.


- (XMPPStream *) setupStream {
    
	NSAssert(!self.xmppStream, @"Method setupStream invoked multiple times");
	
	// Setup xmpp stream
	// 
	// The XMPPStream is the base class for all activity.
	// Everything else plugs into the xmppStream, such as modules/extensions and delegates.
    
	self.xmppStream = [[XMPPStream alloc] init];
	
#if !TARGET_IPHONE_SIMULATOR
	{
		// Want xmpp to run in the background?
		// 
		// P.S. - The simulator doesn't support backgrounding yet.
		//        When you try to set the associated property on the simulator, it simply fails.
		//        And when you background an app on the simulator,
		//        it just queues network traffic til the app is foregrounded again.
		//        We are patiently waiting for a fix from Apple.
		//        If you do enableBackgroundingOnSocket on the simulator,
		//        you will simply see an error message from the xmpp stack when it fails to set the property.
		
		self.xmppStream.enableBackgroundingOnSocket = YES;
	}
#endif
	
	// Setup reconnect
	// 
	// The XMPPReconnect module monitors for "accidental disconnections" and
	// automatically reconnects the stream for you.
	// There's a bunch more information in the XMPPReconnect header file.
	
	self.xmppReconnect = [[XMPPReconnect alloc] init];

    
	// Setup capabilities
	// 
	// The XMPPCapabilities module handles all the complex hashing of the caps protocol (XEP-0115).
	// Basically, when other clients broadcast their presence on the network
	// they include information about what capabilities their client supports (audio, video, file transfer, etc).
	// But as you can imagine, this list starts to get pretty big.
	// This is where the hashing stuff comes into play.
	// Most people running the same version of the same client are going to have the same list of capabilities.
	// So the protocol defines a standardized way to hash the list of capabilities.
	// Clients then broadcast the tiny hash instead of the big list.
	// The XMPPCapabilities protocol automatically handles figuring out what these hashes mean,
	// and also persistently storing the hashes so lookups aren't needed in the future.
	// 
	// Similarly to the roster, the storage of the module is abstracted.
	// You are strongly encouraged to persist caps information across sessions.
	// 
	// The XMPPCapabilitiesCoreDataStorage is an ideal solution.
	// It can also be shared amongst multiple streams to further reduce hash lookups.
	
	self.xmppCapabilitiesStorage = XMPPCapabilitiesCoreDataStorage.sharedInstance;
    self.xmppCapabilities = [[XMPPCapabilities alloc] initWithCapabilitiesStorage: self.xmppCapabilitiesStorage];
    
    self.xmppCapabilities.autoFetchHashedCapabilities = YES;
    self.xmppCapabilities.autoFetchNonHashedCapabilities = NO;
    
	// Add ourself as a delegate to anything we may be interested in
    
	[self.xmppStream addDelegate:self delegateQueue:dispatch_get_main_queue()];
//	[self.xmppRoster addDelegate:self delegateQueue:dispatch_get_main_queue()];
    
	// Activate xmpp modules
    
	[self.xmppReconnect         activate: self.xmppStream];
	[self.xmppCapabilities      activate: self.xmppStream];
    
	// Optional:
	// 
	// Replace me with the proper domain and port.
	// The example below is setup for a typical google talk account.
	// 
	// If you don't supply a hostName, then it will be automatically resolved using the JID (below).
	// For example, if you supply a JID like 'user@quack.com/rsrc'
	// then the xmpp framework will follow the xmpp specification, and do a SRV lookup for quack.com.
	// 
	// If you don't specify a hostPort, then the default (5222) will be used.
 
   if (self.account.serverDomain) {
        
        [self.xmppStream setHostName: self.account.serverDomain];
    }
    if (self.account.serverPort) {
        
        [self.xmppStream setHostPort: self.account.serverPort];	
 
    }
 
    
    return self.xmppStream;

} // -setupStream


- (void) teardownStream {
    
    if (self.xmppStream) {
        
        [self.xmppStream removeDelegate:self];

        [self.xmppReconnect         deactivate];
        [self.xmppCapabilities      deactivate];
        
        [self.xmppStream disconnect];
    }
	self.xmppStream = nil;
	self.xmppReconnect = nil;
	self.xmppCapabilities = nil;
	self.xmppCapabilitiesStorage = nil;

} // -teardownStream


// It's easy to create XML elments to send and to read received XML elements.
// You have the entire NSXMLElement and NSXMLNode API's.
// 
// In addition to this, the NSXMLElement+XMPP category provides some very handy methods for working with XMPP.
// 
// On the iPhone, Apple chose not to include the full NSXML suite.
// No problem - we use the KissXML library as a drop in replacement.
// 
// For more information on working with XML elements, see the Wiki article:
// http://code.google.com/p/xmppframework/wiki/WorkingWithElements

- (void)goOnline
{
	XMPPPresence *presence = [XMPPPresence presence]; // type="available" is implicit
	
	[self.xmppStream sendElement:presence];

}

- (void)goOffline
{
	XMPPPresence *presence = [XMPPPresence presenceWithType:@"unavailable"];
	
	[[self xmppStream] sendElement:presence];
}


#pragma mark - Public methods.


- (BOOL) connect {
    
    if (!self.xmppStream) {
        
        [self setupStream];
    }
	if (self.xmppStream.isConnected && !self.xmppStream.isDisconnected) { // Transition to connection is complete.
	
        return YES;
	}
	if (!self.xmppStream.isConnected && !self.xmppStream.isDisconnected) { // Transitioning to connection.
        
        return NO;
	}
    if (!self.username || [self.username isEqualToString: kEmptyString]) {

		return NO;
	}
    if (!self.xmppStream.myJID) {
        
        [self.xmppStream setMyJID: [XMPPJID jidWithString: self.username]];
    }
    
	NSError *error = nil;

	if (![self.xmppStream oldSchoolSecureConnect:&error]) {
        
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error connecting" 
		                                                    message:@"See console for error details." 
		                                                   delegate:nil 
		                                          cancelButtonTitle:@"Ok" 
		                                          otherButtonTitles:nil];
		[alertView show];
        
		DDLogError(@"Error connecting: %@", error);
        
		return NO;
	}
	return YES;

} // -connect


- (XMPPServer *) disconnect {
    
	[self goOffline];
	[self.xmppStream disconnect];
    
    return self;
    
} // -disconnect


- (XMPPServer *) disconnectAfterSending {
    
	[self goOffline];
	[self.xmppStream disconnectAfterSending];
        
    return self;
    
} // -disconnectAfterSending


- (XMPPStream *) changeAccount: (SCAccount *) account {
    
    if (!self.xmppStream.isConnected && self.xmppStream.isDisconnected) { // We're really disconnected.
        
        self.account = account;
        
        [self.xmppStream setMyJID: [XMPPJID jidWithString: self.username]];
        
        if (self.account.serverDomain) {
            
            [self.xmppStream setHostName: self.account.serverDomain];
        }
        if (self.account.serverPort) {
            
            [self.xmppStream setHostPort: self.account.serverPort];	
        }
    }
    return self.xmppStream;
    
} // -changeServiceServer:


#pragma mark - XMPPStreamDelegate methods.


- (void)xmppStream:(XMPPStream *)sender socketDidConnect:(GCDAsyncSocket *)socket 
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

 
- (void)xmppStreamDidSecure:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
}

- (void)xmppStreamDidConnect:(XMPPStream *)sender
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
	
	_isXmppConnected = YES;
	
	NSError *error = nil;
	
	if (![self.xmppStream authenticateWithPassword: self.account.password error:&error]) {
        
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

- (void)xmppStream:(XMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	DDLogVerbose(@"%@: %@", THIS_FILE, THIS_METHOD);
    
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
	
	if (!_isXmppConnected)
	{
		DDLogError(@"Unable to connect to server. Check xmppStream.hostName");
	}
    _isXmppConnected = NO;
}


#pragma mark - XMPPReconnectDelegate methods.



- (void)xmppReconnect:(XMPPReconnect *)sender didDetectAccidentalDisconnect:(SCNetworkReachabilityFlags)connectionFlags
{
    
}

- (BOOL)xmppReconnect:(XMPPReconnect *)sender shouldAttemptAutoReconnect:(SCNetworkReachabilityFlags)reachabilityFlags
{
    return YES;
}



@end
