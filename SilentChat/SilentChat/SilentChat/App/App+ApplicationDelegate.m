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


#if !__has_feature(objc_arc)
#  error Please compile this class with ARC (-fobjc-arc).
#endif

#import "SCPPServer.h"
#import "AppConstants.h"

#import "App+ApplicationDelegate.h"

#import "App+Model.h"
 
#import "ConversationViewController.h"

#import "ProvisionViewController.h"
#import "XMPPJID+AddressBook.h"

#import "GeoTracking.h"

#import "Heartbeat.h"
#import "SCPasscodeManager.h"
#import "PasscodeViewController.h"

#import "Reachability.h"
#import "DDGQueue.h"
#import "NSManagedObjectContext+DDGManagedObjectContext.h"

#define CLASS_DEBUG 1
#import "DDGMacros.h"

@implementation App (ApplicationDelegate)

@dynamic dbPath;
@dynamic dbURL;


#pragma mark - ApplicationDelegate methods.


- (NSString *) dbPath {
    
    DDGTrace();
	
	NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	
    //	path = [[NSString pathWithComponents: [NSArray arrayWithObjects: path, kAppDBName, nil]] stringByStandardizingPath];
	
    path = [path stringByAppendingPathComponent: kAppDBName];
    
	DDGDesc(path);
	
	return path;
	
} // -dbPath


- (NSURL *) dbURL {
	
    DDGTrace();
	
	NSURL *url = [App applicationDocumentsDirectoryURL];
    
    url = [url URLByAppendingPathComponent: kAppDBName];
	
	return url;
	
} // -dbURL


- (BOOL) doesDBExistAtPath: (NSString *) path {
    
	BOOL fileExists = [NSFileManager.new fileExistsAtPath: path];
	
	DDGLog(@"For Path '%@', fileExists: %@",  path, fileExists ? @"Yes" : @"No");
	
	return fileExists;
	
} // -doesDBExistAtPath:


- (BOOL) doesDBExistAtURL: (NSURL *) url {
    
    NSError *error = nil;
    
    // Multi-threaded file management orthodoxy uses file opening to determine existence.
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingFromURL: url error: &error];
    
    [handle closeFile];
    
    return (BOOL)handle;
	
} // -doesDBExistAtURL:


- (void) copyDBToPath: (NSString *) path {
	
	NSError *error = nil;
	
	NSString *dbBundlePath	= [[NSBundle mainBundle] pathForResource: kAppDBResource ofType: kAppDBType];
	
	if (dbBundlePath) {
		
		[NSFileManager.new copyItemAtPath: dbBundlePath toPath: path error: &error];
	}
	
} // -copyDBToPath


- (void) copyDBToURL: (NSURL *) url {
	
	NSError *error = nil;
	
	NSURL *bundleURL = [[NSBundle mainBundle] URLForResource: kAppDBResource withExtension: kAppDBType];
	
	if (bundleURL) {
		
		[NSFileManager.new copyItemAtURL: bundleURL toURL: url error: &error];
	}
	
} // -copyDBToURL


- (void) makeDirectory: (NSString *) directory {
	
	NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	
	path = [path stringByAppendingPathComponent: directory];
	
	NSError *error = nil;
    
	if (![NSFileManager.new createDirectoryAtPath: path 
                      withIntermediateDirectories: YES 
                                       attributes: nil 
                                            error: &error]) {
		DDGDesc(error);
		DDGDesc(error.userInfo);
	}
	
} // -makeDirectory


- (void) cleanDirectoryAtPath: (NSString *) dirPath {
	
	NSError *error     = nil;
	NSFileManager *fm  = NSFileManager.new;
	NSArray *fileNames = [fm contentsOfDirectoryAtPath: dirPath error: &error];
	
	if (fileNames.count) {
		
		for (NSString *filePath in fileNames) {
			
            NSString *fullPath = [dirPath stringByAppendingPathComponent: filePath];
			
			BOOL isDirectory = NO;
			
			if ([fm fileExistsAtPath: fullPath isDirectory: &isDirectory] &&
				!isDirectory && [fm isDeletableFileAtPath: fullPath]) {
                
				error = nil;
				
				[fm removeItemAtPath: fullPath error: &error];
				
				NSAssert1(!error, @"Error: %@", error);
			}
		}
	}
    
} // -cleanDirectoryAtPath:


- (void) cleanDirectoryAtURL: (NSURL *) url {
	
    if (url) {
        
        NSError *error     = nil;
        NSFileManager *fm  = NSFileManager.new;
        NSArray *urls = [fm contentsOfDirectoryAtURL: url includingPropertiesForKeys: nil options:0 error: &error];
        
        for (NSURL *fileURL in urls) {
            
            DDGDesc(fileURL);
            
            error = nil;
            
            [fm removeItemAtURL: fileURL error: &error];
            
            NSAssert1(!error, @"Error: %@", error);
        }
    }
    
} // -cleanDirectoryAtURL:


- (void) cleanTemporaryDirectory {
	
    [self cleanDirectoryAtURL: self.downloadsDirectory];
    
} // -cleanTemporaryDirectory


- (void) checkAndUpdateDB {
	
	
} // -checkAndUpdateDB


#pragma mark - UIApplicationDelegate methods.


- (UINavigationController *) makeRootViewController {
    
    DDGTrace();
    
    ConversationViewController *cvc = [ConversationViewController.alloc initWithNibName: nil bundle: nil];
    
    self.conversationViewController = cvc;
    
    UINavigationController *navController = nil;
    
    navController = [UINavigationController.alloc initWithRootViewController: cvc];
    navController.delegate = cvc;
    navController.navigationBar.barStyle = UIBarStyleBlack; 
    navController.navigationBar.translucent = NO;
      
    UINavigationItem *navItem = cvc.navigationItem;
    
    navItem.title =  NSLS_COMMON_SILENT_TEXT;

    UIImage *navImg = [[UIImage imageNamed:@"navbar_portrait"]
                       resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
    
    // Set the background image for *all* UINavigationBars
    [[UINavigationBar appearance] setBackgroundImage:navImg
                                       forBarMetrics:UIBarMetricsDefault];
	navImg = [[UIImage imageNamed:@"navbar_landscape"]
			  resizableImageWithCapInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
    // Set the background image for *all* UINavigationBars
    [[UINavigationBar appearance] setBackgroundImage:navImg
                                       forBarMetrics:UIBarMetricsLandscapePhone];
	return navController;
    
} // -makeRootViewController


#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

- (BOOL) application: (UIApplication *) application didFinishLaunchingWithOptions: (NSDictionary *) launchOptions {
    
    DDGTrace();
    
    UIApplication *app = [UIApplication sharedApplication];
    
    // Let the device know we want to receive push notifications
	[app registerForRemoteNotificationTypes:  (UIRemoteNotificationTypeBadge
                                               | UIRemoteNotificationTypeSound
                                               | UIRemoteNotificationTypeAlert)];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // Override point for customization after application launch.
    self.rootViewController = [self makeRootViewController];
    
    self.window.rootViewController = self.rootViewController;
    self.window.backgroundColor    = UIColor.blackColor;
    
    [self.window makeKeyAndVisible];
     
    return NO;

} // -application:didFinishLaunchingWithOptions:

#pragma clang diagnostic pop


- (void) applicationWillResignActive: (UIApplication *) application {
    
    DDGTrace();
	
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    
} // -applicationWillResignActive:


- (void) applicationDidEnterBackground: (UIApplication *) application {
    
    DDGTrace();
	
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    
    [self.xmppServer disconnectAfterSending];
    
    [self.geoTracking stopUpdating];
     
    // Suspend launching new background threads.
	self.suspended = YES;
    [self.heartbeatQueue stopQueue];
    
    [self.moc save];
    
} // -applicationDidEnterBackground:


- (void) applicationWillEnterForeground: (UIApplication *) application {

    DDGTrace();
	
} // -applicationWillEnterForeground:


- (void) applicationDidBecomeActive: (UIApplication *) application {
    
    DDGTrace();
    
    if( self.passcodeManager.isLocked)
    {
        
        PasscodeViewController *pvc = [PasscodeViewController.alloc
                                       initWithNibName:nil
                                       bundle: nil
                                       mode: PasscodeViewControllerModeVerify];
        
        [self.rootViewController presentViewController:pvc animated: NO completion: NULL];
    }

	
    self.suspended = NO;
    [self.heartbeatQueue startQueue];
 
 //   if([self.addressBook needsReload])
        [self.addressBook reload];
      
    static dispatch_once_t runOnce = 0;
    
    dispatch_once(&runOnce, ^{
        
        [Heartbeat.new oneBeat];
    });
    
// NOTE: I removed this delay, not sure why he even had it in the first place?
    
// Do the account check or connection restart on the next iteration of the run loop.
//     [App performBlock: ^{
        
        if (!self.currentAccount) {
             
            ProvisionViewController *pvc = [ProvisionViewController.alloc initWithNibName: nil bundle: nil];
            [self.rootViewController presentViewController: pvc animated: YES completion: NULL];
        }
        else
        {
            BOOL hasNetwork = (NotReachable != [self.reachability currentReachabilityStatus]);
            
     // dont do this here if app is locked
             if(!self.passcodeManager.isLocked && hasNetwork)
                [self.xmppServer connect];
            
        }
//    }];

} // -applicationDidBecomeActive:


- (void) applicationWillTerminate: (UIApplication *) application {
    
    DDGTrace();
	
    [self applicationDidEnterBackground: application];
    
} // -applicationWillTerminate:


- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    
    if ([[url scheme] isEqualToString:@"silent_text"]) {
        
  //      ToDoItem *item = [[ToDoItem alloc] init];
        NSString *taskName = [url query];
   
        taskName = [taskName stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
 
    }
    return YES;
}

#pragma mark - SCPasscodeDelegate methods.


- (void) passcodeManagerWillLock: (SCPasscodeManager *) passcodeManager
{
    DDGTrace();
    
    [self.xmppServer disconnectAfterSending];

}

- (void) passcodeManagerDidLock: (SCPasscodeManager *) passcodeManager
{
    DDGTrace();
    
}

- (void) passcodeManagerDidUnlock: (SCPasscodeManager *) passcodeManager;
{
    DDGTrace();
    BOOL hasNetwork = (NotReachable != [self.reachability currentReachabilityStatus]);
    
     if(hasNetwork)
         [self.xmppServer connect];

}


#pragma mark -
#pragma mark Push notifications

- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData*)deviceToken
{
	// We have received a new device token. This method is usually called right
	// away after you've registered for push notifications, but there are no
	// guarantees. It could take up to a few seconds and you should take this
	// into consideration when you design your app. In our case, the user could
	// send a "register" request to the server before we have received the device
	// token. In that case, we silently send an "update" request to the server
	// API once we receive the token.
    
//	NSString* oldToken = [dataModel deviceToken];
    
	NSString* newToken = [deviceToken description];
	newToken = [newToken stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
	newToken = [newToken stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    
    self.pushToken = newToken;
    
	NSLog(@"My token is: %@", newToken);
    
//	[dataModel setDeviceToken:newToken];
    //self.flipsideViewController.tokenField.text = newToken;
    
	// Let the server know about the new device token.
/*
 if (![newToken isEqualToString:oldToken])
	{
		[self postUpdateRequest];
	}
*/
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
	// If we get here, the app could not obtain a device token. In that case,
	// the user can still send messages to the server but the app will not
	// receive any push notifications when other users send messages
 //   NSString *errMsg = [NSString stringWithFormat:@"Failed to get token, error: %@", error];
  //	NSLog(@"%@", errMsg);
    
}


- (void)application:(UIApplication*)application didReceiveRemoteNotification:(NSDictionary*)userInfo
{
	// This method is invoked when the app is running and a push notification
	// is received. If the app was suspended in the background, it is woken up
	// and this method is invoked as well.
	[self addMessageFromRemoteNotification:userInfo updateUI:YES];
}

- (void)addMessageFromRemoteNotification:(NSDictionary*)userInfo updateUI:(BOOL)updateUI
{
	// The JSON payload is already converted into an NSDictionary for us.
	// We are interested in the contents of the alert message.
	//NSString* alertValue = [[userInfo valueForKey:@"aps"] valueForKey:@"alert"];
    
}

#pragma mark -
#pragma mark Push notifications

@end
