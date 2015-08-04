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
#import "OnboardViewController.h"
#import "ActivationVCDelegate.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "AppTheme.h"
#import "CreateAccountViewController.h"
#import "LogInViewController.h"
#import "OHAlertView.h"
#import "SilentTextStrings.h"
#import "STDynamicHeightView.h"
#import "STLogging.h"
#import "StoreManager.h"
#import "STPreferences.h"
#import "STUser.h"


// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && robbie_hanson
static const int ddLogLevel = LOG_LEVEL_INFO; // VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif


@interface OnboardViewController () <ActivationVCDelegate>
@property (nonatomic, weak) IBOutlet UIButton *createButton;
@property (nonatomic, weak) IBOutlet UILabel *informativeTextLabel;

- (IBAction)learnMore:(id)sender;

@end


@implementation OnboardViewController


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad
{
	DDLogAutoTrace();
	[super viewDidLoad];

//    theme = [AppTheme getThemeBySelectedKey];
//    self.view.tintColor = theme.appTintColor;
//
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(preferredContentSizeChanged:)
	                                             name:UIContentSizeCategoryDidChangeNotification
	                                           object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillAppear:animated];
	
    if (self.isModal)
    {
		self.navigationItem.rightBarButtonItem =
		  [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
		                                                target:self
		                                                action:@selector(cancelButtonTapped:)];
    }
    else
    {
        [self.navigationController setNavigationBarHidden:YES animated:YES];
    }
	
	// This code used to be here:
	// [super viewWillAppear:animated];
	//
	// Normally this line goes at the top of the method.
	// It's abnormal to see it anywhere else.
	//
	// So if it should be here, then there should be a big comment block that spells out exactly
	// - why it's not at the top
	// - what happens if it is
	// - whether or not this is an apple bug
	// - how to reproduce the observed problem if this line is moved to the top of the method
    BOOL createAccountShouldBeEnabled = [SKPaymentQueue canMakePayments];
    _createButton.enabled = createAccountShouldBeEnabled;
}

/**
 * Present alertView to inform and direct user to Settings to resolve In App Purchase restriction condition.
 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (_createButton.enabled == NO) {
        [_createButton setTitle: NSLocalizedString(@"In App purchases restricted", @"In App purchases restricted")
                       forState:UIControlStateDisabled];
        [self handleCreateNewAccountUnavailable];
    }
    else {
        NSString *title = NSLocalizedString(@"Sign up for a new account", @"Sign up for a new account {button title}");
        if (NO == [_createButton.titleLabel.text isEqualToString:title]) {
            [_createButton setTitle:title forState:UIControlStateNormal];
        }        
        _createButton.enabled = YES;
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - InApp Purchase Restriction
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method presents an alertView to the user explaining that In App purchase is
 * restricted, with the option to open the Settings app.
 */
- (void)handleCreateNewAccountUnavailable {
    
    NSString *msg = NSLocalizedString(@"To check restriction settings, choose Settings and go to General, Restrictions.", 
                                      @"To check restriction settings, choose Settings and go to General, Restrictions. {instructions for navigating Settings app}");
    
    [OHAlertView showAlertWithTitle:NSLocalizedString(@"In App Purchases Restricted", 
                                                      @"In App Purchases Restricted {alertView title}") 
                            message:msg
                       cancelButton:NSLS_COMMON_CANCEL
                       otherButtons:@[NSLocalizedString(@"Settings", @"{Go to Settings action} alertView title")]
                      buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex) {
                          
                          if (alert.cancelButtonIndex != buttonIndex) {
                              // multiple approaches to opening Settings iOS 7/8 here: 
                              // http://stackoverflow.com/questions/24229422/accessing-the-settings-app-from-your-app-in-ios-8
                              [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];            
                          }        
                      }];
    
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)preferredContentSizeChanged:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	self.informativeTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)signUpAction:(UIButton *)activateButton
{
	DDLogAutoTrace();
	
	UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Activation" bundle:nil];
	CreateAccountViewController *lvc = [storyboard instantiateViewControllerWithIdentifier:@"CreateAccountViewController"];
    
    lvc.isModal = self.isModal;
    lvc.isInPopover = self.isInPopover;
    lvc.delegate = self;

    [self presentDetailVC:lvc];
}

- (IBAction)logInAction:(UIButton *)activateButton
{
	DDLogAutoTrace();
	
	UIStoryboard *activationStoryboard = [UIStoryboard storyboardWithName:@"Activation" bundle:nil];
	LogInViewController *lvc = [activationStoryboard instantiateViewControllerWithIdentifier:@"LogInViewController"];
    
    lvc.isModal = self.isModal;
    lvc.isInPopover = self.isInPopover;
    lvc.existingUserID = NULL;
    lvc.delegate = self;
    
    [self presentDetailVC:lvc];
}

#pragma mark - DetailVC Navigation

/**
 * We handle the navigation to the login and createAccount VCs differently,
 * depending on whether it's a first time, full-screen presentation, or
 * otherwise from an iPhone or popover view.
**/
- (void)presentDetailVC:(UIViewController *)vc
{
    // Normal push-onto-navigationController, slide-in animation
    BOOL normalAnimation = (NO == [self isPresentedInLargeView]);
    if (normalAnimation)
    {
        [self.navigationController pushViewController:vc animated:YES];
        return;
    }

    // Cross-dissolve animation, presented by self, and
    // dismissed with the custom Back button (@see handleNavigationBack:)
    UINavigationController *navCon = [[UINavigationController alloc] initWithRootViewController:vc];
    navCon.navigationBar.backgroundColor = self.view.backgroundColor;
    navCon.navigationBar.translucent = NO;
    navCon.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    vc.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", @"Nav button title")
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(handleNavigationBack:)];
    
    [self presentViewController:navCon animated:YES completion:nil];
}

//ET: Determine whether to present a navCon with detailVC with a cross-dissolve animation,
// e.g. full iPad view, or whether to push on self navCon with a slide-in animation as on iPhone or in popover.
- (BOOL)isPresentedInLargeView
{
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    if (UIDeviceOrientationIsLandscape(orientation))
        return self.view.frame.size.width > 480.0f;
    else
        return self.view.frame.size.width > 320.0f;
}

// Handles the dismissal of a self presented detailVC with custom Back button
- (void)handleNavigationBack:(UIButton *)backButton
{
    [self dismissPresentedController];
}



- (IBAction)learnMore:(id)sender
{
	DDLogAutoTrace();
	
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://silentcircle.com/web/aboutus/"]];
}

- (void)cancelButtonTapped:(id)sender
{
	DDLogAutoTrace();
	
    [self dismissPresentedController];
}

// Generic handler for methods dismissing a VC presented by self
- (void)dismissPresentedController
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - ActivationVCDelegate Methods

- (void)dismissActivationVC:(UIViewController *)vc error:(NSError*)error
{
    // This error condition hasn't been tested. The assumption is that the CreateAccountVC or LoginVC will have
    // presented an alert to the user explaining the error. Here we will dismiss the detailVC,
    // enabling the option to try the other detailVC.
    if (error)
    {
        [self dismissPresentedController];
    }
    else 
    {
        if (self.presentedViewController)
            [self dismissViewControllerAnimated:YES completion:nil];
        
        if (STAppDelegate.revealController.frontViewController != STAppDelegate.mainViewController) 
        {
            //ST-1001: SWRevealController v2.3 update
//            [STAppDelegate.revealController setFrontViewController:STAppDelegate.mainViewController
//                                                          animated:YES];
            [STAppDelegate.revealController pushFrontViewController:STAppDelegate.mainViewController
                                                           animated:YES];

        }
        else if ([self.delegate respondsToSelector:@selector(dismissActivationVC:error:)])
        {
            [self.delegate dismissActivationVC:self error:nil];
        }

    }
}

@end
