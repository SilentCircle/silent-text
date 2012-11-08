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


#import "XMPPSilentCircle.h"
#import "XMPPLogging.h"
#import "XMPPInternal.h"
#import "XMPPFramework.h"
#import "NSData+XMPP.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

#import <SCimp.h>
#import <SCloud.h>
#include <cryptowrappers.h>
 #import <SCpubTypes.h>


#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif

// Log levels: off, error, warn, info, verbose
// Log flags: trace
#if DEBUG
  static const int xmppLogLevel = XMPP_LOG_LEVEL_VERBOSE | XMPP_LOG_FLAG_TRACE;
#else
  static const int xmppLogLevel = XMPP_LOG_LEVEL_WARN;
#endif

@interface SCimpWrapper : NSObject {
@public
	XMPPJID *localJid;
	XMPPJID *remoteJid;
	
	SCimpContextRef ctx;
	
	NSMutableArray *pendingOutgoingMessages;
	
	NSMutableArray *pendingIncomingMessages;
}

- (id)initWithLocalJid:(XMPPJID *)localJid remoteJID:(XMPPJID *)remoteJid;

- (BOOL)isReady;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation XMPPSilentCircle
{
	id <XMPPSilentCircleStorage> storage;
	
	
	NSMutableSet *jidsToEncrypt;
	NSMutableSet *jidsNotToEncrypt;
	
	XMPPJID *myJID;
}

NSMutableDictionary *scimpDict; // Key=remoteJid, Value=SCimpWrapper

+ (id)wildcardJID
{
	return [NSNull null];
}

@synthesize storage = storage;
@synthesize scimpCipherSuite = _scimpCipherSuite;
@synthesize scimpSASMethod  = _scimpSASMethod;


- (id)init
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPSilentCircle.h are supported.
	
	return [self initWithStorage:nil dispatchQueue:NULL];
}

- (id)initWithDispatchQueue:(dispatch_queue_t)queue
{
	// This will cause a crash - it's designed to.
	// Only the init methods listed in XMPPSilentCircle.h are supported.
	
	return [self initWithStorage:nil dispatchQueue:NULL];
}

- (id)initWithStorage:(id <XMPPSilentCircleStorage>)inStorage
{
	return [self initWithStorage:inStorage dispatchQueue:NULL];
}

- (id)initWithStorage:(id <XMPPSilentCircleStorage>)inStorage dispatchQueue:(dispatch_queue_t)queue
{
	NSParameterAssert(inStorage != nil);
	
	if ((self = [super initWithDispatchQueue:queue]))
	{
		storage = inStorage;
		
		scimpDict = [[NSMutableDictionary alloc] init];
		
		jidsToEncrypt    = [[NSMutableSet alloc] init];
		jidsNotToEncrypt = [[NSMutableSet alloc] init];
	}
	return self;
}

- (BOOL)activate:(XMPPStream *)aXmppStream
{
	if ([super activate:aXmppStream])
	{
#ifdef _XMPP_CAPABILITIES_H
		[xmppStream autoAddDelegate:self delegateQueue:moduleQueue toModulesOfClass:[XMPPCapabilities class]];
#endif
		myJID = [xmppStream myJID];
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(myJidDidChange:)
		                                             name:XMPPStreamDidChangeMyJIDNotification
		                                           object:xmppStream];
		
		return YES;
	}
	
	return NO;
}

- (void)deactivate
{
#ifdef _XMPP_CAPABILITIES_H
	[xmppStream removeAutoDelegate:self delegateQueue:moduleQueue fromModulesOfClass:[XMPPCapabilities class]];
#endif
	
	[[NSNotificationCenter defaultCenter] removeObserver:self
	                                                name:XMPPStreamDidChangeMyJIDNotification
	                                              object:xmppStream];
	
	[super deactivate];
}

- (void)myJidDidChange:(NSNotification *)notification
{
	// My JID changed.
	// So either our resource changed, or a different user logged in.
	// Either way, since the encryption is tied to our JID, we have to flush all state.
	
	XMPPJID *newMyJid = xmppStream.myJID;
	
	dispatch_block_t block = ^{ @autoreleasepool {
		
		myJID = newMyJid;
		
		for (SCimpWrapper *scimp in [scimpDict objectEnumerator])
		{
			[self saveState:scimp];
		}
		[scimpDict removeAllObjects];
	}};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSSet *)jidsToEncrypt
{
	__block NSSet *result = nil;
	
	dispatch_block_t block = ^{
		result = [jidsToEncrypt copy];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setJidsToEncrypt:(NSSet *)inSet
{
	NSMutableSet *set = [inSet mutableCopy];
	
	dispatch_block_t block = ^{
		
		jidsToEncrypt = set;
		[jidsNotToEncrypt minusSet:jidsToEncrypt];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)addToJidsToEncrypt:(NSSet *)inSet
{
	NSSet *set = [inSet copy];
	
	dispatch_block_t block = ^{
		
		[jidsToEncrypt unionSet:set];
		[jidsNotToEncrypt minusSet:set];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)removeFromJidsToEncrypt:(NSSet *)inSet
{
	NSSet *set = [inSet copy];
	
	dispatch_block_t block = ^{
		
		[jidsToEncrypt minusSet:set];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (NSSet *)jidsNotToEncrypt
{
	__block NSSet *result = nil;
	
	dispatch_block_t block = ^{
		result = [jidsNotToEncrypt copy];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

- (void)setJidsNotToEncrypt:(NSSet *)inSet
{
	NSMutableSet *set = [inSet mutableCopy];
	
	dispatch_block_t block = ^{
		
		jidsNotToEncrypt = set;
		[jidsToEncrypt minusSet:jidsNotToEncrypt];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)addToJidsNotToEncrypt:(NSSet *)inSet
{
	NSSet *set = [inSet copy];
	
	dispatch_block_t block = ^{
		
		[jidsNotToEncrypt unionSet:set];
		[jidsToEncrypt minusSet:set];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (void)removeFromJidsNotToEncrypt:(NSSet *)inSet
{
	NSSet *set = [inSet copy];
	
	dispatch_block_t block = ^{
		
		[jidsNotToEncrypt minusSet:set];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_async(moduleQueue, block);
}

- (BOOL)hasSecureContextForJid:(XMPPJID *)remoteJid
{
	__block BOOL result = NO;
	
	dispatch_block_t block = ^{
		
		SCimpWrapper *scimp = [scimpDict objectForKey:remoteJid];
		
		result = [scimp isReady];
	};
	
	if (dispatch_get_current_queue() == moduleQueue)
		block();
	else
		dispatch_sync(moduleQueue, block);
	
	return result;
}

+ (void) removeSecureContextForJid:(XMPPJID *)remoteJid
{
    SCimpWrapper *scimp = [scimpDict objectForKey: [remoteJid bareJID]];
    
    if(scimp)
    {
        [scimpDict removeObjectForKey: [remoteJid bareJID]];
    }
}

#pragma mark secure context control


- (void)rekeySecureContextForJid:(XMPPJID *)remoteJid
{
     
    SCimpWrapper *scimp = [scimpDict objectForKey: [remoteJid bareJID]];
    if(scimp)
    {
         SCimpStartDH(scimp->ctx);
        
        [self saveState:scimp];
        
    }

}

- (void)acceptSharedSecretForJid:(XMPPJID *)remoteJid 
{
     
    SCimpWrapper *scimp = [scimpDict objectForKey: [remoteJid bareJID]];
    if(scimp)
    {

        SCimpAcceptSecret(scimp->ctx);

        [self saveState:scimp];
    
    }
}



NSString *const kSCIMPInfoCipherSuite   = @"cipher_suite";
NSString *const kSCIMPInfoVersion       = @"version";
NSString *const kSCIMPInfoSASMethod     = @"SAS_method";
NSString *const kSCIMPInfoSAS           = @"SAS";
NSString *const kSCIMPInfoCSMatch       = @"secrets_match";
NSString *const kSCIMPInfoHasCS         = @"has_secret";


- (NSDictionary*)secureContextInfoForJid:(XMPPJID *)remoteJid
{
    NSMutableDictionary* infoDict  = NULL;
    
    SCimpWrapper *scimp = [scimpDict objectForKey: [remoteJid bareJID]];
    if(scimp)
    {
        SCLError     err  = kSCLError_NoErr;
        SCimpInfo    info;
        char *SASstr = NULL;
        size_t length = 0;
        
        err = SCimpGetInfo(scimp->ctx, &info); CKERR;
        
        err = SCimpGetAllocatedDataProperty(scimp->ctx, kSCimpProperty_SASstring, (void*) &SASstr, &length); CKERR;
         
         NSString *SAS = [NSString.alloc initWithBytesNoCopy: SASstr 
                                                      length: length
                                                    encoding: NSUTF8StringEncoding 
                                                freeWhenDone: YES];
         
        infoDict = [NSMutableDictionary dictionaryWithCapacity: 6];
         
        [infoDict setValue:[NSNumber numberWithInteger:info.version] forKey:kSCIMPInfoVersion];
        [infoDict setValue:[NSNumber numberWithInteger:info.cipherSuite] forKey:kSCIMPInfoCipherSuite];
        [infoDict setValue:[NSNumber numberWithInteger:info.sasMethod] forKey:kSCIMPInfoSASMethod];
        [infoDict setValue:[NSNumber numberWithBool: (info.csMatches?YES:NO)] forKey:kSCIMPInfoCSMatch];
        [infoDict setValue:[NSNumber numberWithBool: (info.hasCs?YES:NO)] forKey:kSCIMPInfoHasCS];
        [infoDict setValue:SAS forKey:kSCIMPInfoSAS];
    }

    
done:
    
    return infoDict;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)shouldEncryptOutgoingMessageTo:(XMPPJID *)remoteJid
{
	id wildcardJID = [[self class] wildcardJID];
	
	int whitelistLevel = 0;
	int blacklistLevel = 0;
	
	for (XMPPJID *jid in jidsToEncrypt)
	{
		int level = 0;
		
		if (jid == wildcardJID)
		{
			level = 1; // Wildcard match
		}
		else if ([jid resource])
		{
			if ([remoteJid isEqualToJID:jid options:XMPPJIDCompareFull])
			{
				level = 4; // Full match
			}
		}
		else if ([jid user])
		{
			if ([remoteJid isEqualToJID:jid options:XMPPJIDCompareBare])
			{
				level = 3; // Bare match
			}
		}
		else
		{
			if ([remoteJid isEqualToJID:jid options:XMPPJIDCompareDomain])
			{
				level = 2; // Domain match
			}
		}
		
		if (whitelistLevel < level)
			whitelistLevel = level;
	}
	
	for (XMPPJID *jid in jidsNotToEncrypt)
	{
		int level = 0;
		
		if (jid == wildcardJID)
		{
			level = 1; // Wildcard match
		}
		else if ([jid resource])
		{
			if ([remoteJid isEqualToJID:jid options:XMPPJIDCompareFull])
			{
				level = 4; // Full match
			}
		}
		else if ([jid user])
		{
			if ([remoteJid isEqualToJID:jid options:XMPPJIDCompareBare])
			{
				level = 3; // Bare match
			}
		}
		else
		{
			if ([remoteJid isEqualToJID:jid options:XMPPJIDCompareDomain])
			{
				level = 2; // Domain match
			}
		}
		
		if (blacklistLevel < level)
			blacklistLevel = level;
	}
	
	return (whitelistLevel > blacklistLevel);
}

 

- (SCimpWrapper *)scimpForJid:(XMPPJID *)remoteJid isNew:(BOOL *)isNewPtr
{
	BOOL isNew = NO;
   SCimpWrapper *scimp = [scimpDict objectForKey: [remoteJid bareJID]];
	
	if (scimp == nil)
	{
		SCimpContextRef ctx = kInvalidSCimpContextRef;
 		SCLError        err = kSCLError_NoErr;;
		BOOL            restored = NO;
       
        restored = [self restoreState:myJID remoteJid:remoteJid scimpCtx:&ctx];
    		
		if (!restored)
		{
			err = SCimpNew([[myJID bare] UTF8String], [[remoteJid bare] UTF8String],  &ctx);
			if (err != kSCLError_NoErr)
			{
				XMPPLogError(@"%@: SCimpNew error = %d", THIS_FILE, err);
				return nil;
			}
			
			isNew = YES;
		}
		
		err = SCimpSetEventHandler(ctx, XMPPSCimpEventHandler, (__bridge void *)self);
		if (err != kSCLError_NoErr)
		{
			XMPPLogError(@"%@: SCimpSetEventHandler error = %d", THIS_FILE, err);
		}
        
        SCimpEnableTransitionEvents(ctx, true); 
 	      
        err = SCimpSetNumericProperty(ctx, kSCimpProperty_CipherSuite, _scimpCipherSuite);
		if (err != kSCLError_NoErr)
		{
			XMPPLogError(@"%@: SCimpSetNumericProperty(kSCimpProperty_CipherSuite) error = %d", THIS_FILE, err);
		}
        
        err = SCimpSetNumericProperty(ctx, kSCimpProperty_SASMethod, _scimpSASMethod);
		if (err != kSCLError_NoErr)
		{
			XMPPLogError(@"%@: SCimpSetNumericProperty(kSCimpProperty_SASMethod) error = %d", THIS_FILE, err);
		}
            
        
		scimp = [[SCimpWrapper alloc] initWithLocalJid:myJID remoteJID:remoteJid];
		scimp->ctx = ctx;
		
		if (restored)
			XMPPLogVerbose(@"%@: Restored SCimpWrapper: %@", THIS_FILE, scimp);
		else
			XMPPLogVerbose(@"%@: New SCimpWrapper: %@", THIS_FILE, scimp);
		
		[scimpDict setObject:scimp forKey:[remoteJid bareJID]];
	}
	
	if (isNewPtr) *isNewPtr = isNew;
	return scimp;
}

- (void)stripSirenData:(XMPPMessage *)message
{
    NSUInteger index, count = [message childCount];
    
    for (index=count; index > 0; index--)
    {
        NSXMLElement *element = (NSXMLElement *)[message childAtIndex:(index-1)];
        
        if ([[element name] isEqualToString:kSCPPSiren])
        {
            [message removeChildAtIndex:(index-1)];
        }
    }
}
    
- (void)encryptOutgoingMessage:(XMPPMessage *)message withScimp:(SCimpWrapper *)scimp
{
	XMPPLogTrace();
	
	NSString *sirenData = [[message elementForName:kSCPPSiren] stringValue];
	if ([sirenData length] > 0)
	{
		NSData *data = [sirenData dataUsingEncoding:NSUTF8StringEncoding];
	
        // strip out the siren before encrypting and sending.
        [self stripSirenData: message];
           
		// How does this work?
		// We invoke SCimpSendMsg which process the message and synchrously
        // calls XMPPSCimpEventHandler and then assembleSCimpDataMessage
		
 		
		SCLError err = SCimpSendMsg(scimp->ctx, (void *)[data bytes], (size_t)[data length], (__bridge void*) message );
		if (err != kSCLError_NoErr)
		{
			XMPPLogError(@"%@: %@ - SCimpSendMsg err = %d", THIS_FILE, THIS_METHOD, err);
		}
    }
}

- (BOOL)decryptIncomingMessage:(XMPPMessage *)message withScimp:(SCimpWrapper *)scimp
{
    BOOL hasContent = NO;
	XMPPLogTrace();
	
	NSString *x = [[message elementForName:@"x" xmlns:@"http://silentcircle.com"] stringValue];
	if ([x length] > 0)
	{
		// How does this work?
		// We invoke the SCimpProcessPacket, which immediately turns around and invokes our XMPPSCimpEventHandler.
		// The event handler is given the decrypted data, which it will inject into the message.
  		
        const char *utf8Str = x.UTF8String;
        
		SCLError err = SCimpProcessPacket(scimp->ctx, (uint8_t *)utf8Str, strlen(utf8Str), (__bridge void*) message);
		if (err != kSCLError_NoErr)
		{
			XMPPLogError(@"%@: %@ - SCimpProcessPacket err = %d", THIS_FILE, THIS_METHOD, err);
		}
        else 
        {
            hasContent = ([message elementForName: kSCPPSiren xmlns: kSCPPNameSpace] != NULL);
        }
	
 	}
    return hasContent;
}


- (BOOL)restoreState:(XMPPJID *)myJid remoteJid:(XMPPJID *)theirJid scimpCtx:(SCimpContextRef*)ctx
{
    SCLError err = kSCLError_NoErr;
    BOOL restored = NO;
	
    XMPPLogTrace2(@"%@: %@ [%@, %@]", THIS_FILE, THIS_METHOD, myJid, theirJid);

    NSData *state = [storage restoreStateForLocalJid:myJID remoteJid:theirJid];
    
    if (state)
    {
        NSData *stateKey = [storage stateKeyForLocalJid:myJID remoteJid:theirJid];
        
        XMPPLogVerbose(@"%@: [%@, %@] state = %@", THIS_FILE, myJID, theirJid, state);
        XMPPLogVerbose(@"%@: [%@, %@] stateKey = %@", THIS_FILE, myJID, theirJid, stateKey);
        
        err = SCimpRestoreState((uint8_t *)[stateKey bytes], // key
                                (size_t)[stateKey length],   // key length
                                (void *)[state bytes],       // blob
                                (size_t)[state length],      // blob length
                                ctx);                       // out context
        
         if (err == kSCLError_NoErr)
           restored = YES;
        else
            XMPPLogWarn(@"%@: Error restoring state for [%@, %@] : %d", THIS_FILE, myJID, theirJid, err);
 
    }

    return restored;
}

- (void)saveState:(SCimpWrapper *)scimp
{
	XMPPLogTrace2(@"%@: %@ [%@, %@]", THIS_FILE, THIS_METHOD, scimp->localJid, scimp->remoteJid);
	
	NSData *stateKey = [storage stateKeyForLocalJid:scimp->localJid remoteJid:scimp->remoteJid];

	if(stateKey)
    {
        void *blob = NULL;
        size_t blobLen = 0;
        
        SCLError err = SCimpSaveState(scimp->ctx, (uint8_t *)[stateKey bytes], (size_t)[stateKey length], &blob, &blobLen);
        
        if (err == kSCLError_NoErr)
        {
            NSData *state = [NSData dataWithBytesNoCopy:blob length:blobLen freeWhenDone:YES];
            
            [storage saveState:state forLocalJid:scimp->localJid remoteJid:scimp->remoteJid];
        }
        else
        {
            XMPPLogError(@"%@: SCimpSaveState error = %d", THIS_FILE, err);
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark SCimp
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)sendSCimpHandshakeMessage:(NSString *)scimpOut withScimp:(SCimpWrapper *)scimp
{
    // This is a SCimp handshake message.
    //
    // <message to=remoteJid">
    // <body>This message is protected by Silent Circle. http://silentcircle.com/  </body>
    //   <x xmlns="http://silentcircle.com">scimp-encoded-data</x>
    // </message>
    
	XMPPLogCTrace();

    // Note from awd: This message does not have the id attribute with the UUID as provided by Siren.
    // This breaks roundtrip message and response processing. If this is no longer deemed to be important,
    // then this now vestigal feature should be removed from Siren.
    XMPPMessage *message = [XMPPMessage message];
    [message addAttributeWithName:@"to" stringValue:[scimp->remoteJid full]];
    [message addAttributeWithName:@"type" stringValue:@"chat"];
    
    NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:@"http://silentcircle.com"];

    [x setStringValue:scimpOut];
    
    NSXMLElement *bodyElement = [NSXMLElement elementWithName:@"body"];
    [message addChild:bodyElement];
    [bodyElement setStringValue:  [NSString stringWithFormat:kSCPPBodyTextFormat, [self->myJID bare]]];
    
    [message addChild:x];
    [self->xmppStream sendElement:message];
}

- (void)assembleSCimpDataMessage:(NSString *)scimpOut withScimp:(SCimpWrapper *)scimp withMessage:(XMPPMessage *)message
{
     
    // Add the encrypted body.
    // Result should look like this:
    //
    // <message to=remoteJid">
    //   <body></body>
    //   <x xmlns="http://silentcircle.com">scimp-encrypted-data</x>
    // </message>
    
    NSXMLElement *x = [NSXMLElement elementWithName:@"x" xmlns:@"http://silentcircle.com"];
    [x setStringValue:scimpOut];
    
    [message addChild:x];
}

#pragma mark
#pragma mark SCimp Event Handler

SCLError XMPPSCimpEventHandler(SCimpContextRef ctx, SCimpEvent *event, void *userInfo)
{
	XMPPLogCTrace();
    
    SCLError  err = kSCLError_NoErr;
	char        errorBuf[256];
    
	XMPPSilentCircle *self = (__bridge XMPPSilentCircle *)userInfo;
	
	SCimpWrapper *scimp = nil;
	for (SCimpWrapper *w in [scimpDict objectEnumerator])
	{
		if (w->ctx == ctx)
		{
			scimp = w;
			break;
		}
	}
	
	if (scimp == nil)
	{
		XMPPLogCError(@"%@: %s - Unknown scimp context", THIS_FILE, __FUNCTION__);
		
		// We don't know of an existing context for this callback.
		
		return kSCLError_UnknownRequest;
	}
    
    switch(event->type)
	{
            
#pragma mark kSCimpEvent_Warning
        case kSCimpEvent_Warning:
        {
            SCLError warning = event->data.warningData.warning;
            
            SCLGetErrorString(event->data.warningData.warning, sizeof(errorBuf), errorBuf);
            
            XMPPLogCVerbose(@"%@: %s - kSCimpEvent_Warning - %d:  %s", THIS_FILE, __FUNCTION__,
                            event->data.warningData.warning, errorBuf);
            
            if(warning == kSCLError_SecretsMismatch)
            {
                 // we ignore the SAS warning here, we'll pick it up once the connection is established.
            }
            else if(warning == kSCLError_ProtocolContention )
            {
            // the other side responded to our Commit with an other commit.
                [self->multicastDelegate xmppSilentCircle:self protocolWarning:scimp->remoteJid
                                                    withMessage:NULL 
                                                    error:event->data.warningData.warning ];
                
            }
            else if(warning == kSCLError_ProtocolError )
            {
                // the other side responded out of order? probably we should rekey.
               [self->multicastDelegate xmppSilentCircle:self protocolWarning:scimp->remoteJid
                                                    withMessage:NULL
                                                   error:event->data.warningData.warning ];
                
            }
            else
            {
                NSCAssert2(NO, @"Unhandled SCimpEvent_Warning: %d: %s",
                                warning, errorBuf );
            }
            break;
        }
  
#pragma mark kSCimpEvent_Error
        case kSCimpEvent_Error:
        {
            SCLGetErrorString(event->data.errorData.error, sizeof(errorBuf), errorBuf);
            
            XMPPLogCError(@"%@: %s - kSCimpEvent_Error - %d:  %s", THIS_FILE, __FUNCTION__,
                            event->data.errorData.error, errorBuf);
      
  
            [self->multicastDelegate xmppSilentCircle:self protocolError:scimp->remoteJid
                                                withMessage:(__bridge XMPPMessage*)event->userRef
                                                error:event->data.errorData.error ];
        
            break;
        }

#pragma mark kSCimpEvent_Keyed
        case kSCimpEvent_Keyed:
        {
            XMPPLogCVerbose(@"%@: %s - kSCimpEvent_Keyed", THIS_FILE, __FUNCTION__);
            
            // SCimp is telling us it has completed the key exchange,
            // and is ready to encrypt and decrypt messages.
            // Dequeue anything we had pending.
            
            for (XMPPMessage *message in scimp->pendingOutgoingMessages)
            {
                // We don't encrypt the message here.
                // SCimp isn't ready yet as its in the middle of completing and invoking our event handler.
                // So we simply handle the encryption via the normal channels, which is actually easier to maintain.
                
                [self->xmppStream sendElement:message];
            }
            
            for (XMPPMessage *message in scimp->pendingIncomingMessages)
            {
                // We don't decrypt the message here.
                // SCimp isn't ready yet as its in the middle of completing and invoking our event handler.
                // So we simply handle the encryption via the normal channels, which is actually easier to maintain.
                
                [self->xmppStream injectElement:message];
            }
            
            [scimp->pendingOutgoingMessages removeAllObjects];
            [scimp->pendingIncomingMessages removeAllObjects];
            
            [self saveState:scimp];

            // Only notify the delegates after the scimp state is saved. (Precludes a state race condition.)
            [self->multicastDelegate xmppSilentCircle:self didEstablishSecureContext:scimp->remoteJid];

            break;
        }
            
#pragma mark kSCimpEvent_ReKeying
        case kSCimpEvent_ReKeying:
        {
            XMPPLogCVerbose(@"%@: %s - kSCimpEvent_ReKeying", THIS_FILE, __FUNCTION__);
  
            //*VINNIE*     not sure if we need to do the same as keying event  we might need more code here?
 
 /*           // the otherside did a rekey.
            [self saveState:scimp];
            
            [self->multicastDelegate xmppSilentCircle:self protocolWarning:scimp->remoteJid
                                          withMessage:NULL 
                                                error:kSCLError_ProtocolContention ];
 */
            break;
        }
            
        
#pragma mark kSCimpEvent_SendPacket
        case kSCimpEvent_SendPacket:
        {
            XMPPLogCVerbose(@"%@: %s - kSCimpEvent_SendPacket", THIS_FILE, __FUNCTION__);
            
            // SCimp is handing us encrypted data to send.
            // This may be:
            // - data we asked it to encrypt (for an outgoing message)
            // - handshake related information
            
            
            NSString* scimpOut = [NSString.alloc initWithBytes: event->data.sendData.data
                                                        length: event->data.sendData.length 
                                                      encoding: NSUTF8StringEncoding  ];
            
            XMPPLogCVerbose(@"Outgoing encrypted data: %@", scimpOut);
		 	
            // if the kSCimpEvent_SendPacket event has a userRef, it means that this was the result 
            //  of calling  SCimpSendMsg and not a scimp doing protocol keying stuff.
            
            if (event->userRef)
            {
                // this is SCimp data message
                [self assembleSCimpDataMessage:scimpOut withScimp:scimp withMessage:(__bridge XMPPMessage*)event->userRef];
            }
            else
            {
                // This is a SCimp handshake message.
                [self sendSCimpHandshakeMessage:scimpOut withScimp:scimp];
            }
            break;
        }
           
#pragma mark kSCimpEvent_Decrypted
        case kSCimpEvent_Decrypted:
        {
            XMPPLogCVerbose(@"%@: %s - kSCimpEvent_Decrypted", THIS_FILE, __FUNCTION__);
            
            XMPPMessage* message  = (__bridge XMPPMessage*)event->userRef;
            
            NSString *decryptedBody = [[NSString alloc] initWithBytes:event->data.decryptData.data
                                                               length:event->data.decryptData.length
                                                                encoding:NSUTF8StringEncoding];
   
            NSXMLElement *sirenElement = [NSXMLElement elementWithName:kSCPPSiren xmlns:kSCPPNameSpace];
               
            // strip out any existing siren to prevent counterfeiting 
            [self stripSirenData: message];
            
            [message addChild:sirenElement];
            [sirenElement setStringValue:decryptedBody];
            
             break;
        }
            
#pragma mark kSCimpEvent_ClearText
        case kSCimpEvent_ClearText:
        {
            XMPPLogCError(@"%@: %s - kSCimpEvent_ClearText - this should never happen with us", THIS_FILE, __FUNCTION__);
 // *VINNIE* this should never happen with us.
            break;
        }

#pragma mark kSCimpEvent_Transition
         case kSCimpEvent_Transition:
        {
            SCimpEventTransitionData  *d =    &event->data.transData;
            
            [self->multicastDelegate xmppSilentCircle:self protocolDidChangeState:scimp->remoteJid state:d->state];
            
        }
            break;
            
        default:
        {
            NSCAssert1(NO, @"Unhandled SCimpEvent: %d:", event->type );
            
            err =  kSCLError_LazyProgrammer;
            break;
        
        }
    }
  	
	return err;
}

#pragma mark

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (XMPPMessage *)xmppStream:(XMPPStream *)sender willSendMessage:(XMPPMessage *)message
{
	XMPPLogTrace2(@"%@: %@ - %@", THIS_FILE, THIS_METHOD, [message compactXMLString]);
	
	// If we need to encrypt the message, then convert from this:
	//
	// <message to="remoteJid">
	//   <body>unencrypted-message</body>
	// </message>
	//
	// To this:
	//
	// <message to="remoteJid">
	//   <body></body>
	//   <x xmlns="http://silentcircle.com">base64-encoded-encrypted-message</x>
	// </message>
	
	NSXMLElement *x = [message elementForName:@"x" xmlns:@"http://silentcircle.com"];
	if (x)
	{
		XMPPLogVerbose(@"%@: %@ - Ignoring. Already has encryption stuff", THIS_FILE, THIS_METHOD);
		
		return message;
	}
	
	XMPPJID *messageJid = [message to];
	if (messageJid == nil)
	{
		messageJid = [[sender myJID] domainJID];
	}
		
	if ([self shouldEncryptOutgoingMessageTo:messageJid])
	{
		// Encrypt message
		
		BOOL isNewSCimpContext = NO;
		SCimpWrapper *scimp = [self scimpForJid:messageJid isNew:&isNewSCimpContext];
		
		if (scimp == nil)
		{
			XMPPLogVerbose(@"%@: %@ - scimp == nil", THIS_FILE, THIS_METHOD);
			
			// Some error occurred while creating a scimp context.
			// The error was logged in scimpForJid.
			// But since this message is expected to be encrypted,
			// it's better to drop it than send it in plain text.
			
			return nil;
		}
		else if (isNewSCimpContext)
		{
			XMPPLogVerbose(@"%@: %@ - isNewSCimpContext", THIS_FILE, THIS_METHOD);
			
            // inform delegate that we are about to establish secure context
            [multicastDelegate xmppSilentCircle:self willEstablishSecureContext: messageJid];
            
			// SCimp context was just created.
			// We need to start the key exchange.
			SCimpStartDH(scimp->ctx);
			
			// Stash message, and handle it after the scimp stack is ready.
			[scimp->pendingOutgoingMessages addObject:message];
			
			return nil;
		}
		else if ([scimp isReady] == NO)
		{
			XMPPLogVerbose(@"%@: %@ - [scimp isReady] == NO", THIS_FILE, THIS_METHOD);
			
			// SCimp stack isn't ready yet.
			// Key exchange is in progress.
			
			// Stash message, and handle it after the scimp stack is ready.
			[scimp->pendingOutgoingMessages addObject:message];
			
			return nil;
		}
		else
		{
			XMPPLogVerbose(@"%@: %@ - encrypting message...", THIS_FILE, THIS_METHOD);
			
			// SCimp stack is ready.
			// Perform encryption.
			
			[self encryptOutgoingMessage:message withScimp:scimp];
			[self saveState:scimp];
			return message;
		}
	}
	else
	{
		XMPPLogVerbose(@"%@: %@ - Don't encrypt", THIS_FILE, THIS_METHOD);
		
		// Don't encrypt message
		return message;
	}
}

- (XMPPMessage *)xmppStream:(XMPPStream *)sender willReceiveMessage:(XMPPMessage *)message
{
	XMPPLogTrace2(@"%@: %@ - %@", THIS_FILE, THIS_METHOD, [message compactXMLString]);
	
	// We're looking for messages like this:
	//
	// <message to="remoteJid">
	//   <body></body>
	//   <x xmlns="http://silentcircle.com">base64-encoded-encrypted-message</x>
	// </message>
	
	NSXMLElement *x = [message elementForName:@"x" xmlns:@"http://silentcircle.com"];
	if (x == nil)
	{
		XMPPLogVerbose(@"%@: %@ - Nothing to decrypt", THIS_FILE, THIS_METHOD);
		return message;
	}
	
	XMPPJID *messageJid = [message from];
	if (messageJid == nil)
	{
		messageJid = [[sender myJID] domainJID];
	}
	
	BOOL isNewSCimpContext = NO;
	SCimpWrapper *scimp = [self scimpForJid:messageJid isNew:&isNewSCimpContext];
	
	if (scimp == nil)
	{
		XMPPLogVerbose(@"%@: %@ - scimp == nil", THIS_FILE, THIS_METHOD);
		
		// Some error occurred while creating a scimp context.
		// The error was logged in scimpForJid.
		
		return message;
	}
	else if ([scimp isReady] == NO)
	{
		XMPPLogVerbose(@"%@: %@ - [scimp isReady] == NO", THIS_FILE, THIS_METHOD);
		
		// SCimp stack isn't ready yet.
		// The incoming packet could be part of the key exchange process.
		
		XMPPLogVerbose(@"Incoming encrypted data: %@", x.stringValue);

        const char *utf8Str = x.stringValue.UTF8String;
        
		SCLError err = SCimpProcessPacket(scimp->ctx, (uint8_t *)utf8Str, strlen(utf8Str), (__bridge void*) message);
		if (err != kSCLError_NoErr)
		{
			XMPPLogWarn(@"%@: Error in SCimpProcessPacket: %d", THIS_FILE, err);
			
			// Todo: What are the errors here?
			// How do we know if we need to stash the packet or not?
            
            // any bad packets at key exchange need to be tossed.
			
	//		[scimp->pendingIncomingMessages addObject:message];
		}
		
		return nil;
	}
	else
	{
		XMPPLogVerbose(@"%@: %@ - decrypting message...", THIS_FILE, THIS_METHOD);
		
		// SCimp stack is ready.
		// Perform decryption.
		
		BOOL hasContent = [self decryptIncomingMessage:message withScimp:scimp];
		[self saveState:scimp];
        
		return hasContent ? message : nil;
	}
}

- (void)xmppStream:(XMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	// Possible optimization:
	// If a user has gone offline, we can maybe save the state, and then free it.
	// This may save some memory.
	// Of course, if the user wants to send an offline message to the user, we'd have to create it again.
}

#ifdef _XMPP_CAPABILITIES_H
/**
 * If an XMPPCapabilites instance is used we want to advertise our support for SCimp.
**/
- (void)xmppCapabilities:(XMPPCapabilities *)sender collectingMyCapabilities:(NSXMLElement *)query
{
	// This method is invoked on the moduleQueue.
	
	// Add the SCimp feature to the list.
	//   
	// <query xmlns="http://jabber.org/protocol/disco#info">
	//   ...
	//   <feature var="http://silentcircle.com"/>
	//   ...
	// </query>
	//
	// From XEP=0115:
	//   It is RECOMMENDED for the value of the 'node' attribute to be an HTTP URL at which a user could find
	//   further information about the software product, such as "http://psi-im.org" for the Psi client;
	
	NSXMLElement *feature = [NSXMLElement elementWithName:@"feature"];
	[feature addAttributeWithName:@"var" stringValue:@"http://silentcircle.com"];
	
	[query addChild:feature];
}
#endif

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation SCimpWrapper

- (id)initWithLocalJid:(XMPPJID *)aLocalJid remoteJID:(XMPPJID *)aRemoteJid;
{
	if ((self = [super init]))
	{
		localJid = aLocalJid;
		remoteJid = aRemoteJid;
		
		ctx = NULL;
		
		pendingOutgoingMessages = [[NSMutableArray alloc] init];
		pendingIncomingMessages = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
	if (ctx) {
		SCimpFree(ctx);
		ctx = NULL;
	}
}

- (BOOL)isReady
{
	if (ctx == NULL) return NO;
	
	SCimpInfo info;
	SCLError err = SCimpGetInfo(ctx, &info);
	
	return (err == kSCLError_NoErr && info.isReady);
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<SCimpWrapper %p: ctx=%p tuple=[%@, %@]>", self, ctx, localJid, remoteJid];
}

@end
