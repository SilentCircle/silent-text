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
//  App.m
//  SilentChat
//

#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import <CoreData/CoreData.h>
#import <CoreLocation/CoreLocation.h>
#import <CommonCrypto/CommonDigest.h>

#include <tomcrypt.h>
#import "AppConstants.h"
 
#import "SCAccount.h"
#import "Preferences.h"
#import "ConversationManager.h"
#import "SCPPServer.h"

#import "App+Model.h"

#import "ServiceCredential.h"
#import "ServiceServer.h"

#import "DDGQueue.h"
#import "GeoTracking.h"
#import "SCPasscodeManager.h"
#import "XMPPJID+AddressBook.h"
#import "STSoundManager.h"
#import "SCloudManager.h"

#import "NSManagedObjectContext+DDGManagedObjectContext.h"

#import "DDLog.h"
#import "DDTTYLogger.h"
#import "XMPPLogging.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

NSString *const kAppDBName     = @"SilentText.sqlite";
NSString *const kAppDBResource = @"SilentText";
NSString *const kAppDBType     = @"sqlite";
NSString *const kAppDBModel    = @"momd";
NSString *const kAppUserAgent  = @"SilentText/1.0";

static NSString *const kBannerIcon = @"Icon-72";

// Error Domain

@interface App ()

@property (strong, nonatomic, readwrite) SCAccount *currentAccount;
@property (strong, nonatomic, readwrite) XMPPJID *currentJID;
@property (strong, nonatomic, readwrite) XMPPSilentCircle *xmppSilentCircle;
@property (strong, nonatomic, readwrite, retain) NSDictionary* docTypes;

+ (void) setSharedApp: (App *) app;
- (SCPPServer *) makeXMPPServerWithAccount: (SCAccount *) account;

@end

@implementation App

@synthesize window = _window;
@synthesize rootViewController = _rootViewController;

@synthesize currentAccount = _currentAccount;
@synthesize currentJID = _currentJID;
@synthesize currentAccountID = _currentAccountID;
@synthesize preferences = _preferences;
@synthesize xmppServer = _xmppServer;
@synthesize conversationManager = _conversationManager;
@synthesize heartbeatQueue = _heartbeatQueue;
@synthesize conversationViewController = _conversationViewController;

@synthesize pushToken = _pushToken;
@synthesize geoTracking = _geoTracking;
@synthesize addressBook = _addressBook;
@synthesize passcodeManager = _passcodeManager;
@synthesize soundManager = _soundManager;
@synthesize scloudManager = _scloudManager;

@dynamic queueEmpty;

//this is needed to link up the tommath and tomcrypt libraries
ltc_math_descriptor ltc_mp;


 
#pragma mark - Accessor methods.
 
- (NSData *) provisonCert {
    
    NSData* provisonCertData = NULL;
    
    NSData *certData = [NSData dataWithContentsOfFile: [[NSBundle mainBundle]
                                                        pathForResource: kSilentCircleProvisionCert
                                                        ofType: @"der"]];
    if(certData)
    {
        SecCertificateRef certRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)certData);
        if(certRef) provisonCertData = (__bridge_transfer NSData*)SecCertificateCopyData(certRef);
        
    }
    
    return provisonCertData;
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



- (SCAccount *) currentAccount {
    
    if (_currentAccount) { return _currentAccount; }
    
    if (self.currentAccountID) {
        
        self.currentAccount = (SCAccount *)[self.moc objectWithID: self.currentAccountID];
    }
    return _currentAccount;
    
} // -currentAccount


- (XMPPJID *) currentJID {
    
    if (_currentJID) { return _currentJID; }
    
    __block XMPPJID *jid = nil;
    
    [self.moc performBlockAndWait: ^{
        
        jid = self.currentAccount.jid;

        self.currentJID = jid;
    }];
    return jid;
    
} // -currentJID


- (NSManagedObjectID *) currentAccountID {
    
    if (_currentAccountID) { return _currentAccountID; }
    
    if (self.preferences.currentAccountURI) {
        
        _currentAccountID = [self.storeCoordinator managedObjectIDForURIRepresentation: 
                   [NSKeyedUnarchiver unarchiveObjectWithData: self.preferences.currentAccountURI]];
    }
	return _currentAccountID;
    
} // -currentAccountID


- (void) setCurrentAccountID: (NSManagedObjectID *) currentAccountID {
    
	if (_currentAccountID) {
		
		_currentAccount   = nil;
        _currentJID       = nil;
		_currentAccountID = nil;
		self.preferences.currentAccountURI = nil;
	}
	if (currentAccountID) {
		
		_currentAccountID = currentAccountID;
		self.preferences.currentAccountURI = [NSKeyedArchiver archivedDataWithRootObject: 
                                              [currentAccountID URIRepresentation]];
	}
    [self.preferences writePreferences]; // Save the URI immediately.
    
} // -setCurrentAccountID:


#pragma mark - Initialization methods.


- (void) configureXMPPLogger {
    
	// You can do some pretty cool stuff with CocoaLumberjack.
	// One cool trick:
	// - Install XcodeColors (a free open-source plugin for Xcode)
	// - Enable colors in Lumberjack, and customize however you'd like.
	//
	// We sometimes need to enable SEND/RECV logging in XMPPStream so we can see the raw xmpp traffic.
	// However, this spits out a lot of stuff on the console.
	// So we make our normal log messages easier to see by setting the color of the raw xmpp traffic to gray.
	
 	[[DDTTYLogger sharedInstance] setColorsEnabled:YES];
 	
 	[[DDTTYLogger sharedInstance] setForegroundColor: UIColor.redColor
 	                                 backgroundColor: nil
 	                                         forFlag: XMPP_LOG_FLAG_ERROR      // errors
 	                                         context: XMPP_LOG_CONTEXT];       // from xmpp framework
 	
 	[[DDTTYLogger sharedInstance] setForegroundColor: UIColor.orangeColor
  	                                 backgroundColor: nil
 	                                         forFlag: XMPP_LOG_FLAG_WARN       // warnings
 	                                         context: XMPP_LOG_CONTEXT];       // from xmpp framework
 	
 	[[DDTTYLogger sharedInstance] setForegroundColor: UIColor.grayColor
 	                                 backgroundColor: nil
 	                                         forFlag: XMPP_LOG_FLAG_SEND_RECV  // raw traffic
 	                                         context: XMPP_LOG_CONTEXT];       // from xmpp framework
	
     [DDLog addLogger: [DDTTYLogger sharedInstance]]; // Initialize XMPP logging system.
	
} // -configureXMPPLogger


- (BOOL) firstRun
{
    BOOL firstRun  = NO;
    
    NSURL *applicationDocumentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *storeURL = [applicationDocumentsDirectory URLByAppendingPathComponent:kAppDBName];
   
    
    firstRun = ! [[NSFileManager defaultManager] fileExistsAtPath:storeURL.path];

    return firstRun;

}


- (void) deleteAppDB {
    NSError *error;
    NSURL *applicationDocumentsDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
    NSURL *storeURL = [applicationDocumentsDirectory URLByAppendingPathComponent:kAppDBName];
    [[NSFileManager defaultManager] removeItemAtPath:storeURL.path error:&error];
}

- (void) resetAccounts {
    
    NSArray *accounts = [self.moc fetchObjectsForEntity: kSCAccountEntity];
    
    for (SCAccount *account in accounts) {
        
        [self.moc deleteObject: account];
    }
    [self currentAccountID];
    self.currentAccountID = nil;
    
    [self.moc save];
    
} // -resetAccounts


- (App *) configureAppDB {
    
    // Setup the Core Data app DB. Do not merge the models with XMPP DBs.
    NSURL *modelURL = [NSBundle.mainBundle URLForResource: kAppDBResource withExtension: kAppDBModel];

    self.model = [NSManagedObjectModel.alloc initWithContentsOfURL: modelURL];
    
    NSError* error = nil;
    
    NSDictionary *attributes = [[NSFileManager defaultManager]attributesOfItemAtPath:
                          [NSBundle.mainBundle pathForResource: kAppDBResource ofType: kAppDBModel] error:&error] ;
    
    NSString* fileProt = [attributes valueForKey: NSFileProtectionKey];
    
    if(!fileProt || ! [fileProt isEqualToString:NSFileProtectionComplete])
    {
        [[NSFileManager defaultManager]setAttributes:
         [NSDictionary dictionaryWithObject:NSFileProtectionComplete
                                     forKey:NSFileProtectionKey]
                                       ofItemAtPath :[NSBundle.mainBundle pathForResource: kAppDBResource ofType: kAppDBModel]
                                               error:&error] ;
        NSAssert1(!error, @"Error: %@", error);
    }
  
      
    self.storeCoordinator = [self storeCoordinatorWithFilename: kAppDBName];
      
    [self observeMOCNotifications];
    
    return self;
    
} // -configureAppDB


- (App *) configureCrypto {
    
    ltc_mp = ltm_desc;
    
    register_prng (&sprng_desc);
    register_hash (&md5_desc);
    register_hash (&sha1_desc);
    register_hash (&sha256_desc);
    register_hash (&sha384_desc);
    register_hash (&sha512_desc);
    register_hash (&sha224_desc);
    register_hash (&skein256_desc);
    register_hash (&skein512_desc);
    register_hash (&skein1024_desc);
    register_hash (&sha512_256_desc);
    register_cipher (&aes_desc);
    
    return self;
    
} // -configureCrypto

 
- (ConversationManager *) configureConversationManager {
    
    ConversationManager *cm = ConversationManager.new;
    
    cm.storageCipher = self.passcodeManager.storageCipher;
    
    return cm;
    
} // -configureConversationManager


- (App *) init {
    
    self = [super init];
    
    if (self) {
        
        self.serverTimeOffset  = 0;
        self.conversationViewController = NULL;
        [self.class setSharedApp: self];
        
        self.bannerImage =   [UIImage imageNamed: kBannerIcon];
        
        [self configureXMPPLogger];
        [self configureCrypto];
         
        self.preferences = Preferences.new;
        self.addressBook = SCAddressBook.new;
        self.soundManager = STSoundManager.new;
        self.scloudManager = SCloudManager.new;
        
        if([self firstRun])
        {
            [SCPasscodeManager deleteKeys];
        }
         
        self.passcodeManager = [[SCPasscodeManager alloc] initWithDelegate: self];
        [self configureAppDB];
  
        self.conversationManager = [self configureConversationManager];
        
 //          [self resetAccounts];
        
        SCPPServer* sccpServer = [self makeXMPPServerWithAccount: self.currentAccount];
        self.xmppServer = sccpServer;
        self.xmppSilentCircle = sccpServer.xmppSilentCircle;

 
        self.heartbeatQueue = DDGQueue.new;
        [self.heartbeatQueue startQueue];
        
        self.geoTracking = GeoTracking.new;
        
        NSBundle *bundle = [NSBundle mainBundle];
        NSString *pListpath = [bundle pathForResource:@"Info" ofType:@"plist"];
        NSDictionary *dictionary = [[NSDictionary alloc] initWithContentsOfFile:pListpath];
        self.docTypes   = [[dictionary valueForKey:@"CFBundleDocumentTypes"]copy];
        
     }
    return self;
    
} // -init


#pragma mark - Instance methods.


- (SCPPServer *) makeXMPPServerWithAccount: (SCAccount *) account {
    
    DDGDesc(account);
    
    if (account) {
        
        SCPPServer *xmppServer = nil;
        
        xmppServer = [SCPPServer.alloc initWithAccount: account];

        xmppServer.xmppSilentCircleStorage = self.conversationManager;
        xmppServer.allowSelfSignedCertificates = YES;
        xmppServer.allowSSLHostNameMismatch    = YES;
        
        [xmppServer activate];
        
        // Roster policy is set by the conversation manager.
//        [xmppServer.xmppRoster addDelegate: self delegateQueue: dispatch_get_main_queue()];

        return xmppServer;
    }
    return nil;
    
} // -makeXMPPServerWithAccount:


- (SCAccount *) useNewAccount: (SCAccount *) account {

    if (!self.xmppServer) {
        
        SCPPServer* sccpServer = [self makeXMPPServerWithAccount: account];
        
        self.xmppServer = sccpServer;
        self.xmppSilentCircle = sccpServer.xmppSilentCircle;
    }
    self.currentAccountID = account.objectID;
    self.currentJID = nil;
    
    return account;

} // -useNewAccount:


- (void) deleteCurrentAccount {
    
    for (Conversation *conversation in self.conversationManager.conversations) {
        
        [self.moc deleteObject: conversation];
    }
    [self.moc deleteObject: self.currentAccount];
    
    self.currentAccountID = nil;
    
    [self.moc save];
    
} // -deleteCurrentAccount


#pragma mark - <App> methods.


static App *_sharedApp = nil;
static dispatch_once_t _appGuard = 0;

+ (App *) sharedApp {
    
    // As App is the UIApplicationDelegate and is, hence, 
    // allocated by Cocoa, we can use a simple static variable
    // to hold it for fast access.
    dispatch_once(&_appGuard, ^{ 
        
        _sharedApp = (App *)[[UIApplication sharedApplication] delegate]; 
    });
    return _sharedApp;
    
} // +sharedApp


+ (void) setSharedApp: (App *) app {
    
    // As App is the UIApplicationDelegate and is, hence, 
    // allocated by Cocoa, we can use a simple static variable
    // to hold it for fast access.
    dispatch_once(&_appGuard, ^{ 
        
        _sharedApp = app; 
    });
    
} // +sharedApp


- (BOOL) isQueueEmpty {
    
    return YES;
    
} // -isQueueEmpty


- (void) suspendQueues {
} // -suspendQueues


- (void) resumeQueues {
} // -resumeQueues


- (App *) releaseMemory {

    return self;
	
} // -releaseMemory


@end
