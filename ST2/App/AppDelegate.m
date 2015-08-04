/*
Copyright (C) 2013-2015, Silent Circle, LLC. All rights reserved.

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
#import "AppDelegate.h"

#import "AddressBookManager.h"
#import "AppConstants.h"
#import "AppTheme.h"
#import "AutoGrowingTextView.h"
#import "AvatarManager.h"
#import "ConversationViewController.h"
#import "DatabaseManager.h"
#import "DDTTYLogger.h"
#import "FakeStream.h"
#import "FileImportViewController.h"
#import "git_version_hash.h"
#import "LaunchScreenVC.h"
#import "MBProgressHUD.h"
#import "MessageStreamManager.h"
#import "MessagesViewController.h"
#import "MZAlertView.h"
#import "OHAlertView.h"
#import "PasscodeViewController.h"
#import "SCDatabaseLogger.h"
#import "SCDatabaseLoggerColorProfiles.h"
#import "SCFileManager.h"
#import "SCWebAPIManager.h"
#import "SCWebDownloadManager.h"
#import "SCimpUtilities.h"
#import "SCPasscodeManager.h"
#import "SettingsViewController.h"
#import "SilentTextStrings.h"
#import "SRVManager.H"
#import "STConversation.h"
#import "STLocalUser.h"
#import "STLoggerFormatter.h"
#import "STLogging.h"
#import "STMessage.h"
#import "StoreManager.h"
#import "STPreferences.h"
#import "STUserManager.h"
#import "STUser.h"
#import "XMPPLogging.h"
#import "XplatformUI.h"
#import "YRDropdownView.h"

// Categories
#import "NSDate+SCDate.h"
#import "NSDictionary+SCDictionary.h"
#import "NSString+SCUtilities.h"
#import "UIImage+Crop.h"
#import "UIImage+ImageEffects.h"

// Libraries
#import <libkern/OSAtomic.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuickLook/QuickLook.h>
#import <openssl/x509.h>
#import <openssl/err.h>

// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_INFO | LOG_FLAG_TRACE;
#elif DEBUG && eric_turner
  static const int ddLogLevel = LOG_LEVEL_INFO | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif


#define PRODUCTION_NETWORK 1

#define USE_SPLITVIEW_BACKGROUND_COLOR_IOS8 0

#ifndef ENABLE_DEBUG_LOGGING
#error Requires #import "AppConstants.h" for ENABLE_DEBUG_LOGGING definition
#endif

AppDelegate *STAppDelegate;

@implementation AppDelegate
{
	NSArray *utiTable;
    
	MBProgressHUD * HUD;
	UIPopoverController *composeViewPopController;
	
	NSString  * pushToken;
    
    // store the app window while backgrounding
    UIWindow *_cachedWindow;
    
    // window to present in background/appswitcher
    UIWindow *_secureWindow;

    // From LaunchScreen storyboard; rootVC of _secureWindow.
    // We keep a reference to this VC in order to add a passcodeViewController
    // instance as a childVC, if needed.
    LaunchScreenVC *_launchScreenVC;
    
    NSUInteger  totalUnreadCount;
    UIAlertView *failAlert;
	
	BOOL databaseLoggerIsInstalled;
	OSSpinLock databaseLoggerSpinLock;
}

@synthesize window = window;

@synthesize databaseLogger = databaseLogger;
@synthesize databaseLoggerColorProfiles = databaseLoggerColorProfiles;

@synthesize reachability = reachability;

@synthesize revealController = revealController;

@synthesize mainViewController = mainViewController;
@synthesize navigationController = navigationController;
@synthesize splitViewController = splitViewController;

@synthesize conversationViewController = conversationViewController;
@synthesize messagesViewController  = _weak_messagesViewController;

@synthesize settingsViewController = settingsViewController;
@synthesize settingsViewNavController = settingsViewNavController;

@synthesize passcodeViewController = passcodeViewController;

@synthesize passcodeManager = passcodeManager;
@synthesize originalTintColor = originalTintColor;

@dynamic identifier;


- (id)init
{
	if ((self = [super init]))
	{
		// Set global AppDelegate reference.
		// So instead of this:
		//
		// AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate]
		// ... appDelegate.property ...
		//
		// You can simply do this:
		//
		// ... STAppDelegate.property ...
		//
		STAppDelegate = self;
		
		totalUnreadCount = 0;
		databaseLoggerSpinLock = OS_SPINLOCK_INIT;
		
		[self configureLogging];
        [self correctDirectoryPermissions];
		
		SCCrypto_Init();
        
        if ([self firstRun])
        {
            BOOL hasGuidPassphrase = [SCPasscodeManager hasGuidPassphrase];
            if (hasGuidPassphrase)
            {
                [SCPasscodeManager resetAllKeychainInfo];
            }
        }
 		
		self.passcodeManager = [[SCPasscodeManager alloc] initWithDelegate: self];
    }
	return self;
}

- (BOOL)firstRun
{
	NSString *databasePath = [DatabaseManager databasePath];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:databasePath])
		return NO;
	else
		return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Application Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	DDLogAutoTrace();
	
    // Initialize a new _secureWindow instance with the _launchScreenVC as rootVC.
	_secureWindow = [self secureWindowWithLaunchScreenVC];
	[_secureWindow makeKeyAndVisible];
	
	return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{ 
    DDLogAutoTrace();
    
    // Start services
    
    reachability = [Reachability reachabilityForInternetConnection];
    [reachability startNotifier];
    
    // Handle launching from a notification
    //  UILocalNotification *locationNotification =
    //	  [launchOptions objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    
	[SCFileManager cleanMediaCache];
    
    NSError *error = nil;
    BOOL result = [self.passcodeManager configureStorageKeyWithError:&error];
    if (!result || error)
    {
        // try again in applicationDidBecomeActive
        return NO;
    }
    
    if (![self storageKey])
    {
        DDLogVerbose(@"Waiting for storage key...");
        return NO;
    }
    
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	DDLogAutoTrace();
    
	if (!passcodeManager.isConfigured)
	{
        NSError *error = NULL;
        [self.passcodeManager configureStorageKeyWithError:&error];
 
        if (error)
        {
			NSString *msg = NSLocalizedString(
			  @"Silent Text is unable to open database at this time. Tap home key and try again.",
			  @"Error message in UIAlertView");
			
			failAlert = [[UIAlertView alloc] initWithTitle:msg
			                                       message:error.localizedDescription
			                                      delegate:nil
			                             cancelButtonTitle:nil
			                             otherButtonTitles:nil];
			[failAlert show];
			return;
		}
	}
    
    [passcodeManager applicationDidBecomeActive];

	if (passcodeManager.isLocked)
    {
        if (passcodeViewController == nil)
		{
            DDLogYellow(@"%s\nINIT NEW passcodeVC WITH DEFAULT image",__PRETTY_FUNCTION__);
            passcodeViewController = [[PasscodeViewController alloc] initWithNibName:nil 
                                                                              bundle:nil 
                                                                                mode:PasscodeViewControllerModeVerify];
            passcodeViewController.isRootView = YES;
            
            passcodeViewController.view.frame = [[UIScreen mainScreen] bounds];
            passcodeViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            passcodeViewController.view.translatesAutoresizingMaskIntoConstraints = YES;
            [_launchScreenVC.view addSubview:passcodeViewController.view];
            [_launchScreenVC addChildViewController:passcodeViewController];

            passcodeViewController.view.alpha = 0.0;
        }

        // always fade in
        [UIView animateWithDuration:0.25 animations:^{
            
            passcodeViewController.view.alpha = 1.0;
            
        } completion:^(BOOL finished) {
            
            [(UITextField*)passcodeViewController.textfield becomeFirstResponder];
            
        }];

    }
	else // if (!passcodeManager.isLocked)
	{
		[self continueLaunchApplication];
		[self revealScreen];
		[self reactivateApp];
	}
}

/**
 * Sent when the application is about to move from active to inactive state.
 * This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message)
 * or when the user quits the application and it begins the transition to the background state.
 * 
 * This method is ALWAYS invoked, for both Home button single and double-click.
 * applicationDidEnterBackground is only invoked for single Home button click.
 *
 * When going to AppSwitcher, this method may not be called (iPad sim iOS 7.1)
**/
- (void)applicationWillResignActive:(UIApplication *)application
{
	DDLogAutoTrace();
    
    [self.messagesViewController.inputView.autoGrowTextView resignFirstResponder];

    // Prepare secureWindow for background
    [self obscureScreen];
    
	[passcodeManager applicationWillResignActive];

	if (failAlert) {
		[failAlert dismissWithClickedButtonIndex:0 animated:YES];
	}
}

/**
 * This method is NOT invoked for Home button double-click
**/
- (void)applicationDidEnterBackground:(UIApplication *)application
{
	DDLogAutoTrace();
	
	[MessageStreamManager disconnectAllMessageStreams];
	
	// attempt to setapplication badge on the way out
	if (passcodeManager.storageKeyIsAvailable)
	{
		[STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			totalUnreadCount = [STDatabaseManager numberOfUnreadMessagesForAllUsersWithTransaction:transaction];
		}];
		application.applicationIconBadgeNumber = totalUnreadCount;
	}
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	DDLogAutoTrace();
	
	[self applicationDidEnterBackground:application];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Push Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)registerForPushNotifications
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		UIUserNotificationType userNotificationTypes =
		  UIUserNotificationTypeAlert |
		  UIUserNotificationTypeSound |
		  UIUserNotificationTypeBadge ;
		
		UIUserNotificationSettings *notificationSettings =
		  [UIUserNotificationSettings settingsForTypes:userNotificationTypes categories:nil];
		
		[[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
	});
}

- (void)application:(UIApplication *)application
        didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings
{
	DDLogAutoTrace();
	
    //register to receive notifications
    [application registerForRemoteNotifications];
}

/**
 * If we get here, the app could not obtain a device token. In that case,
 * the user can still send messages to the server but the app will not
 * receive any push notifications when other users send messages.
**/
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    DDLogRed(@"DidFailToRegisterForRemoteNotifications: %@", error.localizedDescription);
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    // This method is usually called right away after you've registered for push notifications,
    // but there are no guarantees. It could take up to a few seconds and you should take this
    // into consideration. In our case, the user could send a "register" request to the server
    // before we have received the device token.
    // In that case, we silently send an "update" request to the server API once we receive the token.
    
    NSString *newToken = [deviceToken description];
    newToken = [newToken stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    newToken = [newToken stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    DDLogRed(@"My pushToken is: %@", newToken);
    pushToken = newToken;
    
    [self updatePushTokens];
}

- (void)application:(UIApplication *)application
        didReceiveRemoteNotification:(NSDictionary *)userInfo
              fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler
{
    DDLogAutoTrace();
	
	if (userInfo)
	{
		NSInteger badgeValue = [[[userInfo objectForKey:@"aps"] objectForKey: @"badge"] intValue];
		
//		DDLogPurple(@"didReceiveRemoteNotification(%lu+ %lu) = %u\n %@",
//		              (unsigned long)badgeValue,
//		              (unsigned long)totalUnreadCount,
//		              (unsigned long)(badgeValue + totalUnreadCount),
//		              userInfo);
		
		application.applicationIconBadgeNumber = totalUnreadCount + badgeValue;
	}
	
	// Success
	handler(UIBackgroundFetchResultNewData);
}

- (void)application:(UIApplication *)application handleActionWithIdentifier:(NSString *)identifier
                                                      forRemoteNotification:(NSDictionary *)userInfo
                                                          completionHandler:(void(^)())completionHandler
{
	DDLogAutoTrace();
	
    // handle the actions
    if ([identifier isEqualToString:@"declineAction"]){
    }
    else if ([identifier isEqualToString:@"answerAction"]){
    }
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    NSString *userNotificationUUID = [notification.userInfo objectForKey:@"silent-text-notfication"];
    if (userNotificationUUID)
    {
        [[STUserManager sharedInstance] informUserAboutUserNotifcationUUID:userNotificationUUID];
    }
}

- (void)updatePushTokens
{
    DDLogAutoTrace();
    
    if (([self storageKey] == nil) || (pushToken == nil))
    {
        // Not ready yet
        return;
    }
    
    NSString *oldPushToken = STPreferences.applicationPushToken;
    NSString *newPushToken = pushToken;
    pushToken = nil;
    
    if (oldPushToken && [oldPushToken isEqualToString:newPushToken])
    {
        // We're already registered
        return;
    }
    
    YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
    [rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        
        NSMutableArray *localUsers = [NSMutableArray array];
        
        YapDatabaseViewTransaction *localContactsViewTransaction = [transaction ext:Ext_View_LocalContacts];
        if (localContactsViewTransaction)
        {
            [localContactsViewTransaction enumerateKeysAndObjectsInGroup:@"" usingBlock:
             ^(NSString *collection, NSString *key, STLocalUser *localUser, NSUInteger index, BOOL *stop)
             {
                 if (localUser.isEnabled) {
                     [localUsers addObject:localUser];
                 }
             }];
        }
        else
        {
            [transaction enumerateKeysAndObjectsInCollection:kSCCollection_STUsers
                                                  usingBlock:^(NSString *key, STUser *user, BOOL *stop)
             {
                 if (user.isLocal)
                 {
                     __unsafe_unretained STLocalUser *localUser = (STLocalUser *)user;
                     if (localUser.isEnabled) {
                         [localUsers addObject:localUser];
                     }
                 }
             }];
        }
        
        for (STLocalUser *localUser in localUsers)
        {
            STLocalUser *updatedLocalUser = [localUser copy];
            updatedLocalUser.pushToken = newPushToken;
            updatedLocalUser.needsRegisterPushToken = YES;
            
            [transaction setObject:updatedLocalUser
                            forKey:updatedLocalUser.uuid
                      inCollection:kSCCollection_STUsers];
        }
        
    } completionBlock:^{
        
        STPreferences.applicationPushToken = newPushToken;
    }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark BackgroundURLSession
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(NSString *)identifier
  completionHandler:(void (^)())completionHandler
{
    //	DDLogAutoTrace();
    DDLogPink(@"%s - Not Implemented",__PRETTY_FUNCTION__);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Logging
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)configureLogging
{
	
#if DEBUG
	
	// Configure ttyLogger
	
	STLoggerFormatter *ttyFormatter = [[STLoggerFormatter alloc] initWithTimestamp:YES];
	
	DDTTYLogger *ttyLogger = [DDTTYLogger sharedInstance];
	[ttyLogger setLogFormatter:ttyFormatter];
	[ttyLogger setColorsEnabled:YES];
	
	[DDLog addLogger:ttyLogger];
	
#endif
	
#if ENABLE_DEBUG_LOGGING
	
	// Configure databaseLogger
	
	STLoggerFormatter *dbFormatter = [[STLoggerFormatter alloc] initWithTimestamp:NO];
	
	databaseLogger = [[SCDatabaseLogger alloc] init];
	[databaseLogger setLogFormatter:dbFormatter];
	
	if ([self databaseLoggerEnabled]) {
		[self enableDatabaseLogger];
	}
	
#endif
	
	// Configure colors
	
	databaseLoggerColorProfiles = [[SCDatabaseLoggerColorProfiles alloc] init];
	
	[self setForegroundColor:[OSColor blackColor]       backgroundColor:nil forTag:BlackTag];
	[self setForegroundColor:[OSColor whiteColor]       backgroundColor:nil forTag:WhiteTag];
	[self setForegroundColor:[OSColor grayColor]        backgroundColor:nil forTag:GrayTag];
	[self setForegroundColor:[OSColor darkGrayColor]    backgroundColor:nil forTag:DarkGrayTag];
	[self setForegroundColor:[OSColor lightGrayColor]   backgroundColor:nil forTag:LightGrayTag];
	[self setForegroundColor:[OSColor redColor]         backgroundColor:nil forTag:RedTag];
	[self setForegroundColor:MakeOSColor(0,128,0,1)     backgroundColor:nil forTag:GreenTag];
	[self setForegroundColor:[OSColor blueColor]        backgroundColor:nil forTag:BlueTag];
	[self setForegroundColor:[OSColor cyanColor]        backgroundColor:nil forTag:CyanTag];
	[self setForegroundColor:[OSColor magentaColor]     backgroundColor:nil forTag:MagentaTag];
	[self setForegroundColor:[OSColor yellowColor]      backgroundColor:nil forTag:YellowTag];
	[self setForegroundColor:[OSColor orangeColor]      backgroundColor:nil forTag:OrangeTag];
	[self setForegroundColor:[OSColor purpleColor]      backgroundColor:nil forTag:PurpleTag];
	[self setForegroundColor:[OSColor brownColor]       backgroundColor:nil forTag:BrownTag];
	
	[self setForegroundColor:MakeOSColor(255,111,207,1) backgroundColor:nil forTag:PinkTag];
	
	//	DDLogBlack(@"Black");
	//	DDLogWhite(@"White");
	//	DDLogGray(@"Gray");
	//	DDLogDarkGray(@"DarkGray");
	//	DDLogLightGray(@"LightGray");
	//	DDLogRed(@"Red");
	//	DDLogGreen(@"Green");
	//	DDLogBlue(@"Blue");
	//	DDLogCyan(@"Cyan");
	//	DDLogMagenta(@"Magenta");
	//	DDLogYellow(@"Yellow");
	//	DDLogOrange(@"Orange");
	//	DDLogPurple(@"Purple");
	//	DDLogBrown(@"Brown");
	//	DDLogPink(@"Pink");
	
	// Trace Logging
	
	[self setForegroundColor:[OSColor grayColor]
	              backgroundColor:nil
	                      forFlag:LOG_FLAG_TRACE           // trace
	                      context:0];                      // from our code
	
	// XMPP Logging (from within XMPPFramework)
	
	[self setForegroundColor:[OSColor redColor]
	              backgroundColor:nil
	                      forFlag:XMPP_LOG_FLAG_ERROR      // errors
	                      context:XMPP_LOG_CONTEXT];       // from xmpp framework
	
	[self setForegroundColor:[OSColor orangeColor]
	              backgroundColor:nil
	                      forFlag:XMPP_LOG_FLAG_WARN       // warnings
	                      context:XMPP_LOG_CONTEXT];       // from xmpp framework
	
	#if robbie_hanson
	[self setForegroundColor:MakeOSColor(0, 128, 0, 1)
	              backgroundColor:nil
	                      forFlag:(XMPP_LOG_FLAG_INFO | XMPP_LOG_FLAG_VERBOSE)
	                      context:XMPP_LOG_CONTEXT];       // from xmpp framework
	#endif
	
	[self setForegroundColor:[OSColor blueColor]
	              backgroundColor:nil
	                      forFlag:XMPP_LOG_FLAG_SEND_RECV  // raw traffic
	                      context:XMPP_LOG_CONTEXT];       // from xmpp framework
}

- (void)setForegroundColor:(OSColor *)txtColor backgroundColor:(OSColor *)bgColor forFlag:(int)mask context:(int)ctxt
{
	[[DDTTYLogger sharedInstance] setForegroundColor:txtColor backgroundColor:bgColor forFlag:mask context:ctxt];
	[databaseLoggerColorProfiles  setForegroundColor:txtColor backgroundColor:bgColor forFlag:mask context:ctxt];
}

- (void)setForegroundColor:(UIColor *)txtColor backgroundColor:(UIColor *)bgColor forTag:(id <NSCopying>)tag
{
	[[DDTTYLogger sharedInstance] setForegroundColor:txtColor backgroundColor:bgColor forTag:tag];
	[databaseLoggerColorProfiles  setForegroundColor:txtColor backgroundColor:bgColor forTag:tag];
}

- (NSString *)databaseLoggerPath
{
	NSString *databaseName = @"logs.encrypted.sqlite";
	
	NSURL *baseURL = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
	                                                        inDomain:NSUserDomainMask
	                                               appropriateForURL:nil
	                                                          create:YES
	                                                           error:NULL];
	
	NSURL *databaseURL = [baseURL URLByAppendingPathComponent:databaseName isDirectory:NO];
	
	return databaseURL.filePathURL.path;
}

- (BOOL)databaseLoggerEnabled
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"debugLogging"];
}

- (void)setDatabaseLoggerEnabled:(BOOL)flag
{
	[[NSUserDefaults standardUserDefaults] setBool:flag forKey:@"debugLogging"];
	
	if (flag)
		[self enableDatabaseLogger];
	else
		[self disableDatabaseLogger];
}

- (void)setupDatabaseLogger
{
#if ENABLE_DEBUG_LOGGING
	
	SCDatabaseLoggerCipherKeyBlock cipherKeyBlock = ^ NSData *(void){
		
		SCKeyContextRef key = STAppDelegate.storageKey;
		
		uint8_t symKey[64];
		size_t  symKeyLen = 0;
		
		SCLError err = SCKeyGetProperty(key,                     // SCKeyContextRef
		                                kSCKeyProp_SymmetricKey, // prop name (some are pre-defined)
		                                NULL,                    // SCKeyPropertyType *outPropType
		                               &symKey,                  // void *outData
		                               sizeof(symKey),           // size_t dataSize
		                              &symKeyLen);               // size_t *outDatSize
		
		NSData *cipherKey = nil;
		if (err == kSCLError_NoErr)
		{
			cipherKey = [NSData dataWithBytes:symKey length:symKeyLen];
		}
		
		ZERO(symKey, sizeof(symKey));
		return cipherKey;
	};
	
	NSString *path = [self databaseLoggerPath];
	[databaseLogger setupDatabaseWithPath:path cipherKeyBlock:cipherKeyBlock completion:^(BOOL ready) {
		
		if (!ready)
		{
			DDLogError(@"Problem starting databaseLogger !!!");
			
			// Kill the databaseLogger instance.
			// If we don't do this, then the databaseLogger will be forced to buffer an unlimited number
			// of log statements in memory because it has no database to dump them to.
			databaseLogger = nil;
		}
	}];
	
#endif
}

- (void)enableDatabaseLogger
{
	OSSpinLockLock(&databaseLoggerSpinLock);
	{
		if (!databaseLoggerIsInstalled)
		{
			[DDLog addLogger:databaseLogger];
			databaseLoggerIsInstalled = YES;
		}
	}
	OSSpinLockUnlock(&databaseLoggerSpinLock);
}

- (void)disableDatabaseLogger
{
	OSSpinLockLock(&databaseLoggerSpinLock);
	{
		if (databaseLoggerIsInstalled)
		{
			[DDLog removeLogger:databaseLogger];
			databaseLoggerIsInstalled = NO;
		}
	}
	OSSpinLockUnlock(&databaseLoggerSpinLock);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration Process
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)updateFileProtectionKey:(NSString *)newKey atPath:(NSString *)filePath withError:(NSError **)errorOut
{
    NSError* error = NULL;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL result = NO;
    
    NSDictionary *attrs = [fm  attributesOfItemAtPath:filePath error:&error];
    if(!error && attrs)
    {
        NSString* protAttr = [attrs objectForKey: NSFileProtectionKey];
        if(![protAttr isEqualToString:newKey])
        {
            NSMutableDictionary *newAttr = attrs.mutableCopy;
            [newAttr setObject:newKey forKey:NSFileProtectionKey];
            result = [fm setAttributes:newAttr ofItemAtPath:filePath error:&error];
        }
        
        if(!error)
            result = YES;
    }
    
    if(error && errorOut)
    {
        *errorOut = error.copy;
    }

    
    return result;
}

- (void)correctDirectoryPermissions
{
    NSError         *error  = NULL;
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // force the NSApplicationSupportDirectory to use NSFileProtectionCompleteUntilFirstUserAuthentication
    NSURL *appSupportURL = [fm  URLForDirectory:NSApplicationSupportDirectory
                                       inDomain:NSUserDomainMask
                              appropriateForURL:nil
                                         create:YES
                                          error:NULL];
 
    [self updateFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication
                           atPath:appSupportURL.path
                        withError:&error];
    
    // correct silentText.sqlite file
    NSString *databasePath = [DatabaseManager databasePath];
    if ([fm fileExistsAtPath:databasePath])
    {
         [self updateFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication
                               atPath:databasePath
                            withError:&error];
    }
    
    NSString *shmFile = [databasePath stringByAppendingString:@"-shm"];
    if ([fm fileExistsAtPath:shmFile])
    {
        [self updateFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication
                               atPath:shmFile
                            withError:&error];
    }
    
    NSString *walFile = [databasePath stringByAppendingString:@"-wal"];
    if ([fm fileExistsAtPath:walFile])
    {
        [self updateFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication
                               atPath:walFile
                            withError:&error];
    }
    
    // correct pbkdf2 file
    NSURL* storageBlobURL = [SCPasscodeManager storageBlobURL];
    if([storageBlobURL checkResourceIsReachableAndReturnError:NULL])
    {
        [self updateFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication
                               atPath:storageBlobURL.filePathURL.path
                            withError:&error];
        
    };
}

- (void)updatesNeededFromLastVersion:(NSString *)lastGitHash
{
    DDLogRed(@"Updating from %@", lastGitHash);
    
    // clear the SRV cache
    [STDatabaseManager.rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        
        [transaction removeAllObjectsInCollection:kSCCollection_STSRVRecord];
    }];
    
}

- (void)configureNewLaunch:(UIApplication *)application
{
    NSString* lastGitHash = STPreferences.lastGitHash;
    NSString* currentGitHash = [NSString stringWithUTF8String:GIT_COMMIT_HASH];
    
#if DEBUG
#else
    if(![currentGitHash isEqualToString:lastGitHash])
#endif
    {
        [self updatesNeededFromLastVersion:lastGitHash];
        STPreferences.lastGitHash = currentGitHash;
    }
    
    [self configureViews];
    
    [AddressBookManager initialize];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appThemeChanged:)
                                                 name:kAppThemeChangeNotification
                                               object:nil];
    [self appThemeChanged:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(localeDidChange:)
                                                 name:NSCurrentLocaleDidChangeNotification
                                               object:nil];
    [self localeDidChange:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(localUserActiveDeviceMayHaveChanged:)
                                                 name:LocalUserActiveDeviceMayHaveChangedNotification
                                               object:nil];
}


// application setup might have been stalled due to storage key issues
// or possible a passcode was needed, this continues the process


- (void)continueLaunchApplication
{
	DDLogAutoTrace();
	
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		
		[DatabaseManager start];
		[self setupDatabaseLogger];
		
		[self registerForPushNotifications];
	});
	
	if (revealController == nil) {
		[self configureNewLaunch:[UIApplication sharedApplication]];
	}
	
	// ping the iTunes store and load products in the background
	[[StoreManager sharedInstance] loadAllProducts];
}

- (void)reactivateApp
{
    DDLogAutoTrace();
    
    // On reactivating the app, do a quick search of our database to see if we have any users registered.
    
    __block BOOL hasLocalUsers = NO;
    
    // Note: Do NOT run async operations on the uiDatabaseConnection.
    [STDatabaseManager.roDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        YapDatabaseViewTransaction *localContactsViewTransaction = [transaction ext:Ext_View_LocalContacts];
        if (localContactsViewTransaction)
        {
            hasLocalUsers = ![localContactsViewTransaction isEmptyGroup:@""];
        }
        else
        {
            [transaction enumerateKeysAndObjectsInCollection:kSCCollection_STUsers
                                                  usingBlock:^(NSString *key, STUser *user, BOOL *stop)
             {
                 if (user.isLocal)
                 {
                     hasLocalUsers = YES;
                     *stop = YES;
                 }
             }];
        }
        
    } completionBlock:^{
        
        if (hasLocalUsers)
        {
            // Reactivate any connections
            [self connectUsers];
            [self updatePushTokens];
        }
        else
        {
            [self addNewUser];
        }
    }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - ApplicationDelegate Launch From URL Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    BOOL result = NO;
    
    if ([[url scheme] isEqualToString:@"silentcircleprovision"])
    {
        NSString *taskName = [url resourceSpecifier];
        taskName = [taskName stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [self activateWithCode:taskName
                     networkID:kNetworkID_Production];
    }
    else  if ([[url scheme] isEqualToString:@"file"])
    {
        [self silentTextWasAskedtoOpenFile:url];
        result = YES;
    }
    else if ([[url scheme] isEqualToString:@"silenttextto"])
    {
#if DEBUG
        //  ignore the guard code
#else
        if ([sourceApplication hasPrefix:@"com.silentcircle."])
#endif
        {
            NSString *urlString = [url resourceSpecifier];
            if(urlString)
            {
                NSDictionary* dict = [NSDictionary parameterDictionaryFromURL:url
                                                                    schemeKey:@"recipient"
                                                                  usingScheme:[url scheme]];
                NSString * from = [dict objectForKey:@"from"];
                NSString * body = [dict objectForKey:@"body"];
                NSString * recipient = [dict objectForKey:@"recipient"];
                
                if (recipient.length && from.length && body.length)
                {
                    XMPPJID* recipientJID;
                    XMPPJID* senderJID;
                    
                    NSRange range = [recipient rangeOfString:@"@"];
                    if (range.location == NSNotFound)
                    {
                        recipientJID = [XMPPJID jidWithUser:recipient domain:kDefaultAccountDomain resource:nil];
                    }
                    else {
                        recipientJID = [XMPPJID jidWithString:recipient];
                    }
                    
                    range = [from rangeOfString:@"@"];
                    if (range.location == NSNotFound)
                    {
                        senderJID = [XMPPJID jidWithUser:from domain:kDefaultAccountDomain resource:nil];
                    }
                    else {
                        senderJID = [XMPPJID jidWithString:from];
                    }
                    
                    __block STUser *user = nil;
                    [STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
                        
                        user = [STDatabaseManager findUserWithJID:senderJID transaction:transaction];
                    }];
                    
                    if (user && user.isLocal)
                    {
                        MessageStream *messageStream = [MessageStreamManager messageStreamForUser:(STLocalUser *)user];
                        if (messageStream)
                        {
                            Siren *siren = [Siren new];
                            siren.message = body;
                            
                            [messageStream sendSiren:siren
                                               toJID:recipientJID
                                            withPush:YES
                                               badge:YES
                                       createMessage:YES
                                          completion:^(NSString *messageId, NSString *conversationId)
                             {
                                 // We should probably use this hook to jump to the conversation
                             }];
                        }
                    }
                    
                    result = YES;
                }
            }
        }
    }
    
    return result;
}


- (void)silentTextWasAskedtoOpenFile:(NSURL *)url
{
    // Todo: Fix this ugly hack.
    
    double delayInSeconds = 0.05;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^{
        
        NSString* extension = url.pathExtension;
        NSArray* importableExtensions = @[@"vcf", kSilentContacts_Extension];
        
        if ( [importableExtensions containsObject:extension])
        {
            NSString *frmt = NSLocalizedString(@"What would you like to do with the contacts file %@",
                                               @"What would you like to do with the contacts file %@");
            
            NSString *titleString = [NSString stringWithFormat:frmt, url.lastPathComponent];
            
            MZAlertView *alert =
            [[MZAlertView alloc] initWithTitle:NSLocalizedString(@"Open Contact File", @"Open Contact File")
                                       message:titleString
                                      delegate:self
                             cancelButtonTitle:NSLS_COMMON_CANCEL
                             otherButtonTitles:NSLocalizedString(@"Import to Silent Contacts", @"Import to Contacts"),
             NSLocalizedString(@"Forward", @"Forward"), nil];
            
            [alert show];
            
            [alert setActionBlock:^(NSInteger buttonPressed, NSString *alertText)
             {
                 switch (buttonPressed)
                 {
                     case 1:
                     {
                         HUD = [MBProgressHUD showHUDAddedTo:self.window animated:YES];
                         HUD.labelText =  NSLocalizedString(@"Updating Silent Contacts", @"Updating Silent Contacts");
                         HUD.mode = MBProgressHUDModeIndeterminate;
                         
                         [HUD show:YES];
                         
                         [[STUserManager sharedInstance] importContactsfromURL:url
                                                               completionBlock:^(NSError *error, NSArray *uuids)
                          {
                              if (error)
                              {
                                  UIImage *img = [UIImage imageNamed:@"attention"];
                                  HUD.customView = [[UIImageView alloc] initWithImage:img];
                                  HUD.labelText = NSLocalizedString(@"Import Failed",@"Import Failed");
                                  HUD.mode = MBProgressHUDModeCustomView;
                                  
                                  [HUD show:YES];
                                  [self performSelector:@selector(removeProgress) withObject:NULL afterDelay:3.0];
                              }
                              else
                              {
                                  UIImage *img = [UIImage imageNamed:@"37x-Checkmark.png"];
                                  HUD.customView = [[UIImageView alloc] initWithImage:img];
                                  HUD.labelText = NSLS_COMMON_COMPLETED;
                                  HUD.mode = MBProgressHUDModeCustomView;
                                  
                                  [HUD show:YES];
                                  [self performSelector:@selector(removeProgress) withObject:NULL afterDelay:2.0];
                              }
                          }];
                         
                         break;
                     }
                     case 2:
                     {
                         [self importfromURL:url];
                         break;
                     }
                     default:
                     {
                         if(url) {
                             [NSFileManager.defaultManager removeItemAtURL:url error:nil];
                         }
                         break;
                     }
                 }
                 
             }];
            
        }
        else // pathExtension != @"vcf"
        {
            [self importfromURL:url];
        }
        
    });
}


- (void)importfromURL:(NSURL *)url
{
    DDLogAutoTrace();
    
    FileImportViewController *fic = [[FileImportViewController alloc] initWithURL:url];
    UINavigationController *fvc = [[UINavigationController alloc] initWithRootViewController:fic];
    
    //ST-1001: SWRevealController v2.3 update
//    [revealController setFrontViewController:fvc animated:YES];
    [revealController pushFrontViewController:fvc animated:YES];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Setup VC/View Hierarchy
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)configureViews
{
    DDLogAutoTrace();
    
    if (_cachedWindow) {
        DDLogOrange(@"%s\n _cachedWindow NOT NIL - return doing nothing", __PRETTY_FUNCTION__);
        return;
    }
    
    settingsViewController = [[SettingsViewController alloc] init];
    settingsViewNavController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    settingsViewNavController.navigationBar.barStyle = UIBarStyleBlack;
    settingsViewNavController.navigationBar.translucent = NO;
    
    _composeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                   target:self
                                                                   action:@selector(showComposeView:)];
    
    // Accessibility
    NSString *aLbl = NSLocalizedString(@"New Conversation", 
                                       @"New Conversation - {Conversation view plus button} - accessibility label");
    _composeButton.accessibilityLabel = aLbl;
    
    _settingsButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"threebars"]
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(toggleSettingsView:)];
    
    if (AppConstants.isIPhone)
    {
        conversationViewController = [[ConversationViewController alloc] initWithProperNib];
        
        mainViewController = [[UINavigationController alloc] initWithRootViewController:conversationViewController];
        
        revealController = [[SWRevealViewController alloc] initWithRearViewController:settingsViewNavController
                                                                  frontViewController:mainViewController];
        
        revealController.delegate = self;
        revealController.rearViewRevealWidth = 260;
        revealController.rearViewRevealOverdraw = 0;
        revealController.rearViewRevealDisplacement = 40;
    }
    else // iPad
    {
        conversationViewController = [[ConversationViewController alloc] initWithProperNib];
        
        MessagesViewController *messagesViewController = [self createMessagesViewController];
        
        UINavigationController * conversationsNav;
        UINavigationController * messagesNav;
        
        conversationsNav = [[UINavigationController alloc] initWithRootViewController:conversationViewController];
        messagesNav = [[UINavigationController alloc] initWithRootViewController:messagesViewController];
        
		UISplitViewController *splitVC = [[UISplitViewController alloc] init];
		splitViewController = splitVC;
        
        // Moved line initializing controllers array above line setting preferredDisplayMode fixes error:
        // UISplitViewController is expected to have a view controller at index 0 before it's used
        splitVC.viewControllers = @[conversationsNav, messagesNav];
        splitVC.minimumPrimaryColumnWidth = 320.F;
        splitVC.maximumPrimaryColumnWidth = 320.F;
        splitVC.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
            
#if USE_SPLITVIEW_BACKGROUND_COLOR_IOS8
		splitVC.view.backgroundColor = STAppDelegate.theme.appTintColor;
#endif
        
        mainViewController = splitViewController;
        revealController = [[SWRevealViewController alloc] initWithRearViewController:settingsViewNavController
                                                                  frontViewController:mainViewController];
        
        revealController.delegate = self;
        revealController.rearViewRevealWidth = 260;
        revealController.rearViewRevealOverdraw = 0;
        revealController.rearViewRevealDisplacement = 40;
    }
    

    DDLogYellow(@"%s\nInit NEW cachedWindow with revealController",__PRETTY_FUNCTION__);
    _cachedWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _cachedWindow.rootViewController = revealController;

    // ST-1021
    // Note: revealController gestureRecognizer configuration calls which used to be here
    // have been moved to the completion block of the fade animation in revealScreen method.
    // Moved to there because it was found that sometimes after switching windows, coming
    // back from the background, the gestureRecognizer was disabled and Settings could not
    // be opened.
    // @see revealScreen
}

- (MessagesViewController *)createMessagesViewController
{
    MessagesViewController *messagesViewController = self.messagesViewController;
    
    if (messagesViewController == nil)
    {
        messagesViewController = [[MessagesViewController alloc] initWithProperNib];
        self.messagesViewController = messagesViewController;
    }
    
    return messagesViewController;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - SWRevealViewController Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)revealController:(SWRevealViewController *)sender willMoveToPosition:(FrontViewPosition)position
{
    if (position == FrontViewPositionRight || position == FrontViewPositionRightMost)
    {
        // We are revealing the settings view
        revealController.frontViewController.view.userInteractionEnabled = NO;
    }
    else if (position == FrontViewPositionLeft)
    {
        // We are hiding the settings view
        revealController.frontViewController.view.userInteractionEnabled = YES;
    }
}

- (void)revealController:(SWRevealViewController *)sender didMoveToPosition:(FrontViewPosition)position
{
    if (position == FrontViewPositionRight || position == FrontViewPositionRightMost)
    {
        // We are revealing the settings view
        revealController.frontViewController.view.userInteractionEnabled = NO;
    }
    else if (position == FrontViewPositionLeft)
    {
        // We are hiding the settings view
        revealController.frontViewController.view.userInteractionEnabled = YES;
    }
    
    //03/26/15 - Accessibility    
    [self updateSettingsButtonAccessibility];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Settings / Compose Views
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)toggleSettingsView:(id)sender
{
    [revealController revealToggleAnimated:YES];
}

- (void)showComposeView:(id)sender
{
    __block NSString *composingID = nil;
    
    dispatch_block_t showComposeViewBlock = ^{
        
        if (AppConstants.isIPhone)
        {
            MessagesViewController *messagesViewController = [STAppDelegate createMessagesViewController];
            messagesViewController.conversationId = composingID;
            
            [conversationViewController.navigationController pushViewController:messagesViewController animated:YES];
        }
        else
        {
            STAppDelegate.conversationViewController.selectedConversationId = composingID;
        }
    };
    
    NSString *currentUserId = STDatabaseManager.currentUser.uuid;
    
    YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
    [rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        
        STConversation *conversation = [[transaction ext:Ext_View_Order] objectAtIndex:0 inGroup:currentUserId];
        
        if (conversation.isNewMessage)
        {
            composingID = conversation.uuid;
        }
        else
        {
            composingID = [[NSUUID UUID] UUIDString];
            
            STConversation *newConversation =
            [[STConversation alloc] initAsNewMessageWithUUID:composingID userId:currentUserId];
            
            [transaction setObject:newConversation
                            forKey:newConversation.uuid
                      inCollection:newConversation.userId];
        }
        
    } completionBlock:^{
        
        showComposeViewBlock();
    }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Onboard / Activation VC Setup
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addNewUser
{
    UIStoryboard *activationStoryboard = [UIStoryboard storyboardWithName:@"Activation" bundle:nil];
    UINavigationController *fvc = [activationStoryboard instantiateInitialViewController];
	
    //ST-1001: SWRevealController v2.3 update
//	[revealController setFrontViewController:fvc animated:YES];
    [revealController pushFrontViewController:fvc animated:YES];
}


- (void)connectUsers
{
	NSMutableArray *localUsers = [NSMutableArray arrayWithCapacity:1];
    
	[STDatabaseManager.roDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		YapDatabaseViewTransaction *localContactsViewTransaction = [transaction ext:Ext_View_LocalContacts];
		if (localContactsViewTransaction)
		{
			[localContactsViewTransaction enumerateKeysAndObjectsInGroup:@"" usingBlock:
			    ^(NSString *collection, NSString *key, id object, NSUInteger index, BOOL *stop)
			{
				__unsafe_unretained STLocalUser *user = (STLocalUser *)object;
				
				[localUsers addObject:user];
			}];
		}
		else
		{
			// Safety net in-case the Ext_View_LocalContacts is still coming online.
			
			[transaction enumerateKeysAndObjectsInCollection:kSCCollection_STUsers
			                                      usingBlock:^(NSString *key, id object, BOOL *stop)
			{
				__unsafe_unretained STUser *user = (STUser *)object;
				
				if (user.isLocal)
				{
					[localUsers addObject:user];
				}
			}];
		}
		
	} completionBlock:^{
       
		// Back on the main thread
        
        if (STDatabaseManager.currentUser == nil)
        {
			// No current user ?!?
			// Try to set one.
			
			if ([localUsers count] > 0)
			{
				STUser *aLocalUser = [localUsers objectAtIndex:0];
				[STPreferences setSelectedUserId:aLocalUser.uuid];
			}
		}
		
		NSMutableArray *expiredUsers = [NSMutableArray arrayWithCapacity:[localUsers count]];
		
		for (STLocalUser *localUser in localUsers)
		{
			// Connect the message stream (if possible)
			if (localUser.isEnabled && localUser.isActivated && !localUser.subscriptionHasExpired)
			{
				[[MessageStreamManager messageStreamForUser:localUser] connect];
			}
			
			// If the user doesn't have a public key, then give them one!
			if (localUser.currentKeyID == nil)
			{
				[[STUserManager sharedInstance] createPrivateKeyForUserID:localUser.uuid completionBlock:NULL];
			}
			
			if (localUser.subscriptionHasExpired)
			{
				[expiredUsers addObject:localUser];
			}
		}
		
		// Check to see if any expired users have re-subscribed
		for (STLocalUser *localUser in expiredUsers)
		{
			// Is this user waiting to provision?
			NSDictionary *provisionDict = localUser.provisonInfo;
            if (provisionDict)
            {
                DDLogBrown(@"%@ needs provision", [localUser.jid bare]);
                
                // edge case, the user hasnt completed setup but somehow crashed in the middle of it?
            }
            else
            {
				// If the web refresh succeeds,
				// and the user's subscription is no longer expired,
				// then the refreshWebInfoForLocalUser method will automatically connect the MessageStream.
				
				[[STUserManager sharedInstance] refreshWebInfoForLocalUser:localUser completionBlock:NULL];
			}
			
		} // end for (STUser *user in expiredUsers)
        
    }]; // end completionBlock
}

#pragma mark user activation

- (void)activateWithCode:(NSString *)activationCode
               networkID:(NSString *)networkID
{
    DDLogAutoTrace();
    
    // If the localUser still exists, then we want to *REUSE* the same deviceID.
    // If the localUser was deleted, then we want the deviceID to be *DIFFERENT* from the last time we activated.
    //
    // This is wrong.
    //	NSString *deviceID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    // 
    // This is right.
    NSString *deviceID = [[NSUUID UUID] UUIDString];
    
#if TARGET_OS_IPHONE
    NSString *deviceName =  UIDevice.currentDevice.name;
#else
    NSString *deviceName = (__bridge_transfer NSString *)SCDynamicStoreCopyComputerName(NULL, NULL);
#endif
    
    [[SCWebAPIManager sharedInstance] provisionWithCode: activationCode
                                             deviceName: deviceName
                                               deviceID: deviceID
                                              networkID: networkID
                                        completionBlock:^(NSError *error, NSDictionary *infoDict)
     {
         if (error)
         {
             [self stopActivityIndicator];
             
             NSString *msg = nil;
             if (![error.domain isEqualToString: kSCErrorDomain])
                 msg = error.localizedDescription;
             else
                 msg = [NSString stringWithFormat:NSLS_COMMON_PROVISION_ERROR_DETAIL, error.localizedDescription];
             
             UIAlertView *alertView =
             [[UIAlertView alloc] initWithTitle:NSLS_COMMON_PROVISION_ERROR
                                        message:msg
                                       delegate:nil
                              cancelButtonTitle:NSLS_COMMON_OK
                              otherButtonTitles:nil];
             [alertView  show];
         }
         else
         {
             NSString *apiKey = [infoDict valueForKey:@"api_key"];
             if (apiKey)
             {
                 [[STUserManager sharedInstance] activateDevice:deviceID
                                                         apiKey:apiKey
                                                      networkID:networkID
                                                completionBlock:^(NSError *error, NSString *newUUID)
                  {
                      if (error)
                      {
                          UIAlertView *alertView =
                          [[UIAlertView alloc] initWithTitle:NSLS_COMMON_PROVISION_ERROR
                                                     message:error.localizedDescription
                                                    delegate:nil
                                           cancelButtonTitle:NSLS_COMMON_OK
                                           otherButtonTitles:nil];
                          [alertView show];
                      }
                      else
                      {
                          [STPreferences setSelectedUserId:newUUID];
                          
                          //ST-1001: SWRevealController v2.3 update
//						[STAppDelegate.revealController setFrontViewController:STAppDelegate.mainViewController
//						                                              animated:YES];
                          [STAppDelegate.revealController pushFrontViewController:STAppDelegate.mainViewController
                                                                         animated:YES];
                          
                      }
                  }];
                 
             } // end if (apiKeyString)
         }
         
     }]; // end SCWebAPIManager provisionWithCode
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)appThemeChanged:(NSNotification *)notification
{
    DDLogAutoTrace();
    
    AppTheme *theme = notification.userInfo[kNotificationUserInfoTheme];
    if (theme == nil)
        theme = [AppTheme getThemeBySelectedKey];
    
    if (theme.appTintColor)
        window.tintColor = theme.appTintColor;
    else
        window.tintColor = originalTintColor;
	
	if ([theme navBarIsBlack])
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent animated:NO];
	else
		[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleDefault animated:NO];
	
#if USE_SPLITVIEW_BACKGROUND_COLOR_IOS8
	UISplitViewController *splitVC = (UISplitViewController *)splitViewController;
	splitVC.view.backgroundColor = STAppDelegate.theme.appTintColor;
#endif
}

- (void)localUserActiveDeviceMayHaveChanged:(NSNotification *)notification
{
    DDLogAutoTrace();
    NSAssert([NSThread isMainThread], @"Notification posted on non-main thread !");
    
    NSString *localUserID = notification.userInfo[@"localUserID"];
    
    if (localUserID == nil)
        localUserID = STDatabaseManager.currentUser.uuid;
    
    __block STLocalUser *localUser = nil;
    [STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        STUser *user = [transaction objectForKey:localUserID inCollection:kSCCollection_STUsers];
        if (user.isLocal)
        {
            localUser = (STLocalUser *)user;
        }
    }];
    
    if (localUser)
    {
        [[STUserManager sharedInstance] refreshWebInfoForLocalUser:localUser completionBlock:NULL];
    }
}


- (void)updatedNotficationPrefsForUserID:(NSString *)userID
{
    NSMutableArray * blackList = [NSMutableArray array];
    __block STLocalUser *localUser = nil;
    
    YapDatabaseConnection *backgroundConnection = STDatabaseManager.roDatabaseConnection;
    [backgroundConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        STUser *user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
        if (user.isLocal)
        {
            localUser = (STLocalUser *)user;
            
            // Enumerate over all the conversationIds for the user
            [transaction enumerateKeysInCollection:userID usingBlock:^(NSString *conID, BOOL *stop) {
                
                STConversation* con = [transaction objectForKey:conID inCollection:userID];
                
                NSTimeInterval delay = con.notificationDate
                ? [con.notificationDate timeIntervalSinceNow]
                :[[NSDate distantPast] timeIntervalSince1970];
                
                
                if(delay > 0)
                {
                    if(con.isMulticast)
                    {
                        NSString*  threadID = con.threadID;
                        NSString*  delayUntil = [con.notificationDate rfc3339String];
                        
                        [blackList addObject:@{@"thread": threadID, @"expires":delayUntil}   ];
                        
                        
                    }
                    else
                    {
                        NSString *jidStr = [con.remoteJid bare];
                        NSString*  delayUntil = [con.notificationDate rfc3339String];
                        
                        [blackList addObject:@{ @"jid": jidStr, @"expires": delayUntil }];
                    }
                    
                }
            }];
        }
    }];
    
    NSDictionary* lists = @{@"blacklist": blackList, @"whitelist":@[]};
    
    [[SCWebAPIManager sharedInstance] setBlacklist:lists
                                      forLocalUser:localUser
                                   completionBlock:^(NSError *error, NSDictionary *infoDict)
     {
         if(error)
         {
             //TODO: complain here?
         }
     }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - SCPasscodeDelegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)passcodeManagerWillLock:(SCPasscodeManager *)passcodeManager
{
    DDLogAutoTrace();
}

- (void)passcodeManagerDidLock:(SCPasscodeManager *)passcodeManager
{
    DDLogAutoTrace();
	
	[MessageStreamManager disconnectAllMessageStreams];
}

- (void)passcodeManagerDidUnlock:(SCPasscodeManager *)passcodeManager
{
    DDLogAutoTrace();
    
    [self continueLaunchApplication];
    [self revealScreen];
    [self reactivateApp];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Obscure Background View Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/** ST-1021
 * This method caches the main window and swaps with a newly created security window 
 * to secure/obscure the main app view in the AppSwitcher.
 *
 * Note that this method is called by applicationWillResignActive to handle 
 * user home button click events:
 *   - single-click: (backgrounding) iPhone always orients to portrait (except, for iPhone 6 Plus)
 *   - double-click: (AppSwitcher)   iPhone switcher respects orientation
 *   - iPad always respects orientation for both.
 * Single-click sends the app to the background and presents the Home screen.
 * Dobule-click presents the multi-tasking manager.
 *
 * This method caches the main window in the _cachedWindow ivar and creates a new secureWindow
 * UIWindow instance. The launchScreenVC ivar is initialized and set as the secureWindow.rootViewController.
 * 
 * Note that if a passcodeVC instance exists, it was initialized and added as a childVC of 
 * _launchScreenVC in appDidBecomeActive, and its presence here means the passcode login
 * view was backgrounded without switching back to the main window. So we call 
 * [passcodeViewController prepareForBackground], and make the passcode view invisible.
 * This makes the background view consistent whether the passcode feature is on or not.
 *
 * Note: that when returning from the background, the revealScreen method is invoked, which
 * nils the various background-related ivars.
 *
 * @see applicationDidBecomeActive
 * @see revealScreen
 */
- (void)obscureScreen
{
    if (self.window && self.window != _secureWindow) {
        DDLogOrange(@"%s\n SET cachedWindow with self.window:%@", __PRETTY_FUNCTION__, self.window);
        _cachedWindow = self.window;
    }

    if (nil == _secureWindow) { 
        DDLogYellow(@"%s\nINIT SecurityWindow with launchScreenVC",__PRETTY_FUNCTION__);
        _secureWindow = [self secureWindowWithLaunchScreenVC];
    }
    
    if (passcodeViewController) {
        [passcodeViewController prepareForBackground];
        passcodeViewController.view.alpha = 0.0;
    }
    
    _secureWindow.windowLevel = UIWindowLevelAlert + [[UIApplication sharedApplication] windows].count;
    [_secureWindow makeKeyAndVisible];
    _secureWindow.hidden = NO;

}

/** ST-1021
 * This method swaps the secure window back to the main window.
 *
 * The obscureScreen method handles presenting a new window instance when going into the
 * background to obscure the main app window in the AppSwitcher. This method fades out
 * the secure window, containing the _launchScreenVC view, while fading in the main app window
 * and restoring it as the key window.
 *
 * At the completion of the fade animation, cleanup is performed, setting the various 
 * backgrounding-related ivars to nil.
 *
 * Note: the gestureRecognizer(s) for revealController features is also set in the animation
 * completion block because it was found that in some cases, they stopped responding
 * after switching back to the app window in the animation block.
 */
- (void)revealScreen
{       
    // Handle turn off passcode feature:
    if (nil == _cachedWindow && self.window && self.window != _secureWindow) {
        DDLogOrange(@"%s\n ", __PRETTY_FUNCTION__);
        return;
    }    
    
    _cachedWindow.hidden = NO;
    _cachedWindow.alpha = 0.0;
    
    // Fade out imgView
    [UIView animateWithDuration:0.35 animations:^{

        self.window = _cachedWindow;
        [self.window makeKeyAndVisible];    

        _cachedWindow.alpha = 1.0;
        _secureWindow.alpha = 0.0;
                
    } completion:^(BOOL finished) {
        
        // Switch windows
        DDLogOrange(@"%s\n SET self.window with cachedWindow:%@", __PRETTY_FUNCTION__, _cachedWindow);
        
        // This needs to be after [self.window makeKeyAndVisible],
        // or the gesture recognizer may be disabled.
        revealController.frontViewController.view.hidden = NO; // force view load
        [revealController tapGestureRecognizer];
        
        // If we want the panGesture too, then we just uncomment the line below.
        // [revealController panGestureRecognizer];        
        
        DDLogOrange(@"%s\n SET NIL: \nsecureWindow:%@\ncachedWindow:%@\nlaunchScreenVC:%@\npasscodeVC:%@", 
                    __PRETTY_FUNCTION__, 
                    _secureWindow, _cachedWindow, _launchScreenVC, passcodeViewController);
        
        if (passcodeViewController) {
            [passcodeViewController removeFromParentViewController];
        }
        
        _secureWindow = nil;
        _launchScreenVC = nil;        
        passcodeViewController = nil;
        _cachedWindow = nil;
        
    }]; // end imgView fadeout completion
    
}

/**
 * This is a convenience constructor which returns a UIWindow instance configured with
 * a LaunchScreenVC rootViewController. A side effect of this method is that the 
 * _launchScreenVC ivar is initialized with the LaunchScreenVC instance.
 */
- (UIWindow *)secureWindowWithLaunchScreenVC {

    UIStoryboard *sb = [UIStoryboard storyboardWithName:@"LaunchScreen" bundle:nil];
    LaunchScreenVC *launchVC = [sb instantiateInitialViewController];
    
    // Initialize a new _secureWindow instance with the _launchScreenVC as rootVC.
    CGRect screenBounds = [[UIScreen mainScreen] bounds];    
    UIWindow *secWin = [[UIWindow alloc] initWithFrame:screenBounds];
    launchVC.view.frame = screenBounds;

    launchVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    launchVC.view.translatesAutoresizingMaskIntoConstraints = YES;
    
    _launchScreenVC = launchVC;
    
    secWin.rootViewController = _launchScreenVC;
    secWin.hidden = NO;

    return secWin;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Screenshot Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Return a UIImage of the current screen.
 *
 * This method uses the drawViewHierarchyInRect: method introduced in 
 * iOS 7 which optimizes the rendering of a view into an image.
 *
 * Note: The app window must be visible; this does not render an 
 * offscreen screen view.
 *
 * @return An image of the current screen
 * @see snapshot
 */
- (UIImage *)screenShot 
{
    CGRect bounds = [[UIScreen mainScreen] bounds];
    UIGraphicsBeginImageContextWithOptions(bounds.size, NO, [[UIScreen mainScreen] scale]);
    [self.window drawViewHierarchyInRect:bounds afterScreenUpdates:NO];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

/** Return a UIImage of the given view and its subviews.
 *
 * This method will return a snapshot of the given view and its 
 * subviews - NOT necessarily a "screenshot".
 * 
 * Also note that this method renders the given view's layer into an 
 * image context. This means the view does not have to be onscreen, 
 * though this incurs a performance penalty.
 *
 * @param view The view of which to render an image.
 * @return UIImage rendered from the base layer of the given view.
 * @see the screenShot method for a faster, full screen image.
 */
- (UIImage *)snapshot:(UIView *)view
{
    UIGraphicsBeginImageContextWithOptions(view.frame.size, NO, [[UIScreen mainScreen] scale]);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Centralized UIAlert
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// this is a centralized place to put up a complain alert

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message
{
    DDLogAutoTrace();
    
    [OHAlertView showAlertWithTitle:title
                            message:message
                       cancelButton:NULL
                           okButton:NSLS_COMMON_OK
                      buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex)
     {
     }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - ActivityIndicator / HUD Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void) startActivityIndicatorWithText:(NSString*)text
{
    HUD = [MBProgressHUD showHUDAddedTo:self.window animated:YES];
    HUD.delegate = self;
    HUD.mode = MBProgressHUDModeIndeterminate;
    HUD.labelText = text;
}

- (void) stopActivityIndicator
{
    [MBProgressHUD hideHUDForView:self.window animated:YES];
}

- (void) hudWasHidden:(MBProgressHUD *)hud {
    // Remove HUD from screen when the HUD was hidden
    [HUD removeFromSuperview];
    HUD = nil;
}

-(void) removeProgress
{
    [HUD removeFromSuperview];
    HUD = nil;    
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Accessibility
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateSettingsButtonAccessibility
{
    BOOL settingsClosed = (revealController.frontViewPosition == FrontViewPositionLeft);
    NSString *viewState = (settingsClosed) ? @"Closed" : @"Open in split screen";
    NSString *aLbl = [NSString stringWithFormat:NSLocalizedString(@"Settings %@", 
                                                                  @"Settings view %@ (closed or split screen state)"), 
                      viewState];
    _settingsButton.accessibilityLabel = aLbl;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Errors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSError *)otherError:(NSString *)errMsg
{
    NSDictionary *userInfo = nil;
    if (errMsg) {
        userInfo = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
    }
    
    return [NSError errorWithDomain:kSCErrorDomain code:kSCLError_OtherError userInfo:userInfo];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Uncategorized
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray *)importableDocs {
    
    NSMutableArray *retval = [NSMutableArray array];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *publicDocumentsDir = [paths objectAtIndex:0];
    
    NSError *error;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:publicDocumentsDir error:&error];
    if (files == nil) {
        NSLog(@"Error reading contents of documents directory: %@", [error localizedDescription]);
        return retval;
    }
    
    for (NSString *file in files) {
//        if ([file.pathExtension compare:@"sbz" options:NSCaseInsensitiveSearch] == NSOrderedSame)
        {
            NSString *fullPath = [publicDocumentsDir stringByAppendingPathComponent:file];
			NSURL* url = [NSURL fileURLWithPath:fullPath ];
            
            if([[url lastPathComponent] isEqualToString:@"Inbox"]) continue;
            if([[url lastPathComponent] isEqualToString:@".DS_Store"]) continue;
            
              [retval addObject:url];
        }
    }
    
    return retval;
    
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Localization Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)localeDidChange:(NSNotification *)notification
{
    // update UTI list
    NSMutableArray* utiList = [[NSMutableArray alloc]init];
    
    // Make a dictionary of the info.plist CFBundleDocumentTypes
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *pListpath = [bundle pathForResource:@"Info" ofType:@"plist"];
    NSDictionary *dictionary = [[NSDictionary alloc] initWithContentsOfFile:pListpath];
    NSDictionary* docTypes   = [[dictionary valueForKey:@"CFBundleDocumentTypes"]copy];
    
    // Make a dictionary of the InfoPlist.strings
    NSString *infoPlistpath = [bundle pathForResource:@"InfoPlist" ofType:@"strings"];
    NSDictionary* docTypeStrings = [[NSDictionary alloc] initWithContentsOfFile:infoPlistpath];
    
    // make a array of the LSItemContentTypes as keys with a value of CFBundleTypeName translated by the InfoPlist.strings
    for (NSDictionary* item in docTypes){
        NSString* name =  [item objectForKey:@"CFBundleTypeName"];
        for(NSString* contentType   in [item objectForKey:@"LSItemContentTypes"])
        {
            name = [docTypeStrings objectForKey:name]?:name;
            
            [utiList addObject:@[contentType,name]];
        };
    }
    utiTable = utiList;
    
}

- (NSString *)stringForUTI:(NSString *)UTI
{
    NSString* result = NSLocalizedString( @"Document",  @"Document");
    
    if(!utiTable)
    {
        [self localeDidChange: nil];
    }
    
    if( UTTypeConformsTo( (__bridge CFStringRef)  UTI, kUTTypeAudio))
        UTI = (__bridge NSString*) kUTTypeAudio;
    else if( UTTypeConformsTo( (__bridge CFStringRef)  UTI, kUTTypeMovie))
        UTI = (__bridge NSString*) kUTTypeMovie;
    else if( UTTypeConformsTo( (__bridge CFStringRef)  UTI, kUTTypeImage))
        UTI = (__bridge NSString*) kUTTypeImage;
    else if( UTTypeConformsTo( (__bridge CFStringRef)  UTI, (__bridge CFStringRef) @"public.calendar-event"))
        UTI =  @"public.calendar-event";
    
    for (NSArray* item in utiTable)
    {
        NSString* key = [item objectAtIndex:0];
        
        if([UTI isEqualToString:key])
        {
            result = [item objectAtIndex:1];
            break;
        }
    };
    
    
    return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Key Hash Method
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

-(NSData*) getPubKeyHashForCertificate:(NSData*)serverCertificateData
{
    NSData* result = NULL;
    uint8_t hash[32];       // SHA-256
   
    const unsigned char *certificateDataBytes = (const unsigned char *)[serverCertificateData bytes];
    X509 *certificateX509 = d2i_X509(NULL, &certificateDataBytes, [serverCertificateData length]);
    
 /*
   " removed the following code because we were hashing the SubjectPublicKeyInfo not the public key bit string. 
    The SPKI includes the type of the public key and some parameters along with the public key itself. This is 
    important because just hashing the public key leaves one open to misinterpretation attacks. Consider a 
    Diffie-Hellman public key: if one only hashes the public key, not the full SPKI, then an attacker can use 
    the same public key but make the client interpret it in a different group. Likewise one could force an RSA
    key to be interpreted as a DSA key etc."
  
  */
//    ASN1_BIT_STRING *pubKey2 = X509_get0_pubkey_bitstr(certificateX509);
//    
//    if(IsntSCLError( HASH_DO(kHASH_Algorithm_SHA256, pubKey2->data, pubKey2->length , sizeof(hash) , hash )))
//    {
//        result = [NSData dataWithBytes:hash length:sizeof(hash)];
//    }
//
//    DDLogPurple( @"PK(%d) %@", pubKey2->length, [NSString hexEncodeBytes:pubKey2->data length:pubKey2->length]);
//    

   // Instead a hash of the DER of the certs SPKI.
    
    // I hate using OpenSSL to get the PK of a cert, Apple  hould have provided this code.
    while(certificateX509)
    {
        unsigned char *buff1 = NULL;
         long ssl_err = 0;
        int len1 = 0, len2 = 0;
        
        /* http://groups.google.com/group/mailing.openssl.users/browse_thread/thread/d61858dae102c6c7 */
        len1 = i2d_X509_PUBKEY(X509_get_X509_PUBKEY(certificateX509), NULL);
        ssl_err = (long)ERR_get_error();
        if(ssl_err != 0) break;
        
        /* scratch */
        unsigned char* temp = NULL;
        
        /* http://www.openssl.org/docs/crypto/buffer.html */
        buff1 = temp = OPENSSL_malloc(len1);
        if(buff1 == NULL) break;
        
        ssl_err = (long)ERR_get_error();
        if(ssl_err != 0) break;
         
        /* http://www.openssl.org/docs/crypto/d2i_X509.html */
        len2 = i2d_X509_PUBKEY(X509_get_X509_PUBKEY(certificateX509),  &temp);
        ssl_err = (long)ERR_get_error();
        if(ssl_err != 0) break;
 
        if(IsntSCLError( HASH_DO(kHASH_Algorithm_SHA256, buff1, len2 , sizeof(hash) , hash )))
        {
            result  = [NSData dataWithBytes:hash length:sizeof(hash)];
        }
 
        if(buff1)
            OPENSSL_free(buff1);
        
        break;
     }
    
    
    if(certificateX509)
        X509_free(certificateX509);
    
        return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Convenience Accessors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)identifier
{
    NSString *identifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleIdentifierKey];
    
#if DEBUG
    if (!identifier) identifier = @"com.silentcircle.SilentText";
#endif
    
    return identifier;
}

- (SCKeyContextRef)storageKey
{
    return passcodeManager.storageKey;
}

- (AppTheme *)theme {
    return [AppTheme getThemeBySelectedKey];
}

@end
