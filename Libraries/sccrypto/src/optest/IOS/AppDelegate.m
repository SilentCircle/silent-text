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
//
//  AppDelegate.m
//  SCcrypto optest
//
//  Created by Vinnie Moscaritolo on 10/22/14.
//
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate
@synthesize window = window;
@synthesize optestVC = optestVC;
@synthesize navigationController = navigationController;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    optestVC = [OptestViewController.alloc initWithNibName:@"OptestViewController" bundle:nil];
    
    navigationController = [[UINavigationController alloc] initWithRootViewController:optestVC];
    navigationController.navigationBar.barStyle = UIBarStyleBlack;
    navigationController.navigationBar.translucent = NO;

    self.window.rootViewController = navigationController;
    [self.window makeKeyAndVisible];
    
     [NSThread detachNewThreadSelector:@selector(workerThread) toTarget:self withObject:nil];

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


void OutputString(char *s)
{
    //   NSAutoreleasePool *	pool = [[NSAutoreleasePool alloc] init];
    
#ifdef IPHONE_CONSOLE_DEBUG
    printf("%s", s);
    fflush(stdout);
#endif
    
    NSString *myString=[[NSString alloc]initWithUTF8String:s];
    
    AppDelegate *delegate=[[UIApplication sharedApplication]delegate];
    
    // send our results back to the main thread
    [delegate.optestVC performSelectorOnMainThread:@selector(updateContent:)
                                              withObject:myString waitUntilDone:YES];
    
    //    [myString release];
    //   [pool release];
}



int printf(const char *fmt, ...)
{
    va_list marker;
    char s[8096];
    int len;
    
    va_start( marker, fmt );
    len = vsprintf( s, fmt, marker );
    va_end( marker );
    
    OutputString(s);
    
    return 0;
}

int ios_main();

-(void)workerThread {
 //   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
 
    //	TestMain(resPath);
    
    
    printf("Test message \n");
    ios_main();
    
 //   [pool release];
}  


@end
