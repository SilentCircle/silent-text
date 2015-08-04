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
#import <UIKit/UIKit.h>
#import <AddressBook/AddressBook.h>
#import <Reachability/Reachability.h>
#import <SCCrypto/SCcrypto.h>

#import "MBProgressHUD.h"
#import "SWRevealViewController.h"
#import "DatabaseManager.h"

@class AppDelegate;
@class AppTheme;
@class ConversationViewController;
@class MessageStream;
@class STUser;
@class STMessage;
@class MessagesViewController;
@class PasscodeViewController;
@class SCPasscodeManager;
@class SettingsViewController;
@class SCDatabaseLogger;
@class SCDatabaseLoggerColorProfiles;

extern AppDelegate *STAppDelegate;


@interface AppDelegate : UIResponder <UIApplicationDelegate,
                                      MBProgressHUDDelegate,
                                      SWRevealViewControllerDelegate>

@property (nonatomic, strong) UIWindow *window;

// What is this ? What is it for?
@property (nonatomic, strong, readonly) NSString *identifier;

@property (nonatomic, assign, readwrite) BOOL databaseLoggerEnabled;
@property (nonatomic, strong, readonly) SCDatabaseLogger *databaseLogger;
@property (nonatomic, strong, readonly) SCDatabaseLoggerColorProfiles *databaseLoggerColorProfiles;

@property (nonatomic, strong, readonly) Reachability *reachability;

@property (nonatomic, strong) SWRevealViewController *revealController;

@property (nonatomic, strong) UIViewController       * mainViewController;  // iPhone:navigationController, iPad:splitVC
@property (nonatomic, strong) UINavigationController * navigationController;// iPhone only
@property (nonatomic, strong) UISplitViewController  * splitViewController; // iPad only

@property (nonatomic, strong) ConversationViewController * conversationViewController;
@property (nonatomic, weak)   MessagesViewController     * messagesViewController; // may be nil on iPhone
  
@property (nonatomic, strong) SettingsViewController * settingsViewController;
@property (nonatomic, strong) UINavigationController * settingsViewNavController;

@property (nonatomic, strong) PasscodeViewController * passcodeViewController;

@property (nonatomic, strong) UIBarButtonItem * composeButton;
@property (nonatomic, strong) UIBarButtonItem * settingsButton;

@property (nonatomic, strong) SCPasscodeManager *passcodeManager;

@property (nonatomic, readonly) SCKeyContextRef  storageKey; // Convenience: passcodeManager.storageKey
@property (nonatomic, readonly) AppTheme *theme;             // Convenience: [AppTheme getThemeBySelectedKey]

@property (nonatomic, strong) UIColor *originalTintColor;

#pragma mark Errors

- (NSError *)otherError:(NSString *)errMsg;

#pragma mark Other
// Todo: Organize these methods into categorized pragma sections

- (NSString *)stringForUTI:(NSString *)UTI;

- (void)updatedNotficationPrefsForUserID:(NSString *)userID;
 
- (MessagesViewController *)createMessagesViewController;

- (NSArray *)importableDocs;

- (UIImage *)snapshot:(UIView *) view;

// Convenience method to get whole screen snapshot;
// snapshot method returns image of given view which may not be the whole screen.
- (UIImage *)screenShot;

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message;

/**
 * Stupid helper function because IOS Security framework is missing useful stuff!
**/
- (NSData *)getPubKeyHashForCertificate:(NSData *)serverCertificateData;

@end
