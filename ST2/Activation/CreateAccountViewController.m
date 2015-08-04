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
#import "CreateAccountViewController.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "AppTheme.h"
#import "AvatarManager.h"
#import "BBPasswordStrength.h"
#import "OHActionSheet.h"
#import "OHAlertView.h"
#import "SCTPasswordTextfield.h"
#import "SilentTextStrings.h"
#import <StoreKit/StoreKit.h>
#import "STDynamicHeightView.h"
#import "STLogging.h"
#import "STPreferences.h"
#import "STUser.h"
#import "STUserManager.h"
#import "MessageStream.h"

#if SUPPORT_PURCHASE_ACCOUNT
#import "StoreManager.h"
#endif

// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
    static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG && eric_turner
    static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
    static const int ddLogLevel = LOG_LEVEL_INFO;
#else
    static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
#pragma unused(ddLogLevel)
 //#undef DEBUG

@interface CreateAccountViewController ()  <MBProgressHUDDelegate, UITextFieldDelegate, SCTPasswordTextfieldDelegate>
{
    MBProgressHUD   *HUD;
    NSDictionary    *networkChoices;
    NSString        *selectedNetwork;
    BOOL            allowNetworkSelect;
    NSCharacterSet* charsForDeviceName;
    NSCharacterSet* charsForUserName;
    UITextField     *activeField;
}

@property (nonatomic, weak) IBOutlet UITextField *usernameField;
@property (nonatomic, weak, readonly) IBOutlet SCTPasswordTextfield *passwordField;
@property (nonatomic, weak) IBOutlet UITextField *deviceField;
@property (nonatomic, weak) IBOutlet UITextField *firstNameField;
@property (nonatomic, weak) IBOutlet UITextField *lastNameField;
@property (nonatomic, weak) IBOutlet UITextField *emailField;
@property (nonatomic, weak) IBOutlet UIButton * purchaseButton;
@property (nonatomic, weak) IBOutlet UIButton *networkButton;

@end

#pragma mark -

@implementation CreateAccountViewController

@synthesize usernameField = usernameField;
@synthesize passwordField = passwordField;
@synthesize deviceField = deviceField;
@synthesize firstNameField = firstNameField;
@synthesize lastNameField = lastNameField;
@synthesize emailField = emailField;
@synthesize purchaseButton = purchaseButton;
@synthesize networkButton = networkButton;


#pragma mark - Initialization
- (void)dealloc
{
    DDLogAutoTrace();
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
	DDLogAutoTrace();
	[super viewDidLoad];
	
    [self.navigationController setNavigationBarHidden:NO animated:YES];
	
    self.title = NSLocalizedString(@"SC Mobile Signup ", @"SC Mobile Signup title");

    //------------------------------------------------------------------------------------//
    // Get callback for TextField edit events.
    //------------------------------------------------------------------------------------//
    [usernameField addTarget:self 
                      action:@selector(textFieldDidChange:) 
            forControlEvents:UIControlEventEditingChanged];
    // Set delegate for charset validation for each entered char
    usernameField.delegate = self;
    
    // SCTPasswordTextField control encapsulates validatation; self need not be delegate
    [passwordField addTarget:self 
                      action:@selector(textFieldDidChange:) 
            forControlEvents:UIControlEventEditingChanged];  
    passwordField.delegate = self;
    
    [deviceField addTarget:self 
                    action:@selector(textFieldDidChange:) 
          forControlEvents:UIControlEventEditingChanged];
    // Set delegate for charset validation for each entered char
    deviceField.delegate = self;
    //------------------------------------------------------------------------------------//

    // NOTE: this MUST precede the configureInitialDeviceField invocation!
    [self configureTextFieldCharsets];    

    [self configureInitialDeviceField];
    
    [self configureNetworkChoices];
    
#if SUPPORT_PURCHASE_ACCOUNT
    [self configureInitialPurchaseSetup];
    // Register for purchase transaction completion notification
    [[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(purchaseTransactionComplete:)
	                                             name:kStoreManager_TransactionCompleteNotification
											   object:nil];
#else
	// TODO: localize this
	[purchaseButton setTitle:NSLocalizedString(@"Create Account", @"Create Account") forState:UIControlStateNormal];
	purchaseButton.enabled = NO;
#endif
	// Register for keyboard notifications
    //ET 10/29/14
    // NOTE: the keyboard auto-scrolling is buggy between iOS7 and 8 handling
    // When rotating to landscape on iOS 8 iPhone, the view is scrolled all the way up,
    // obscuring the firstResponder textfield - actually all textfields.
	if (NO == self.isInPopover) // && NO == AppConstants.isIOS8OrLater)
    {
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(keyboardWillShow:)
		                                             name:UIKeyboardWillShowNotification
		                                           object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(keyboardDidShow:)
		                                             name:UIKeyboardDidShowNotification
		                                           object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(keyboardWillHide:)
		                                             name:UIKeyboardWillHideNotification
		                                           object:nil];
	}

    [usernameField becomeFirstResponder];
}


#pragma mark - Charsets

- (void)configureTextFieldCharsets 
{    
    charsForUserName = [NSCharacterSet alphanumericCharacterSet];

    NSMutableCharacterSet *charSet = [[NSMutableCharacterSet alloc] init];
    [charSet formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
    [charSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
    [charSet formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
    [charSet formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
    charsForDeviceName = charSet;
}


#pragma mark - Device Name

// Calculate and set device name in deviceField
- (void)configureInitialDeviceField
{
	NSString *deviceName;
    
#if TARGET_OS_IPHONE
    deviceName = UIDevice.currentDevice.name;
#else
    deviceName = (__bridge_transfer NSString *)SCDynamicStoreCopyComputerName(NULL, NULL);
#endif
    
	NSArray *deviceNameComponents = [deviceName componentsSeparatedByCharactersInSet:[charsForDeviceName invertedSet]];
    deviceField.text = [deviceNameComponents componentsJoinedByString:@"_"];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Purchase Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if SUPPORT_PURCHASE_ACCOUNT
// FIXME: !
//  this code needs to be rewritten to allow us to handle multiple items from the store.
- (void)configureInitialPurchaseSetup
{    
	NSArray *productList = [[StoreManager sharedInstance] allActiveProductsSortedByPrice];
	for (ProductVO *product in productList)
	{
        if(([product.productID isEqualToString:@"SC_SUBSCRIBE_1_MO"])
        ||  ([product.productID isEqualToString:@"SC_SUBSCRIBE_1_MON"]))

        {
            NSString* description = [NSString stringWithFormat: @"%@ / %@", [product displayTitle], [product displayPrice] ];
            
            [purchaseButton setTitle: description forState: UIControlStateNormal ];
            [purchaseButton setTitle: description forState: UIControlStateDisabled ];
            [purchaseButton setTitle: description forState: UIControlStateHighlighted ];
            [purchaseButton setTitle: description forState: UIControlStateSelected ];
			[purchaseButton setTag:[product.tag intValue]];
            
            [purchaseButton setNeedsUpdateConstraints];
            
            break;
        }
    }
    
    purchaseButton.enabled = NO;
}
#endif

- (IBAction)createAccountAction:(id)sender
{
	DDLogAutoTrace();
	
#if SUPPORT_PURCHASE_ACCOUNT
	UIButton *button = sender;
	ProductVO *product = [[StoreManager sharedInstance] productWithTag:[NSNumber numberWithLong:button.tag]];
#endif
	
	NSString * username = self.usernameField.text;
	NSString * password = self.passwordField.text;
	NSString * deviceName = self.deviceField.text;
	
	NSString * firstName = self.firstNameField.text;
	NSString * lastName  = self.lastNameField.text;
	NSString * email     = self.emailField.text;
	
	[self dismissKeyboard];
	[self startActivityIndicator];
    
	[[STUserManager sharedInstance] createAccountFor: username
	                                    withPassword: password
	                                       networkID: selectedNetwork
	                                      deviceName: deviceName
	                                       firstName: (firstName.length ? firstName : nil)
	                                        lastName: (lastName.length  ? lastName  : nil)
	                                           email: (email.length     ? email     : nil)
	                                 completionBlock:^(NSError *error, NSString *userID)
	{
		NSAssert([NSThread isMainThread],
		         @"All completionBlocks are expected to be on the main thread, unless explicitly stated otherwise");
		
		if (error)
		{
			[self stopActivityIndicator];
			
			// Really?
			// We're just assuming the error was because the username wasn't available?
			// What if the user didn't have internet connectivity?
			// Would that not also fail?
			
			NSString *title = NSLocalizedString(@"Can not create user", @"Can not create user");
			NSString *msg   = NSLocalizedString(@"username is unavailable ","username is unavailable");
			
			[STAppDelegate showAlertWithTitle:title message:msg];
		}
		else
		{
			__block STLocalUser *localUser = NULL;
			
			[STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
				
				localUser = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
			}];
			
			NSAssert(localUser.isLocal, @"Oops!");
			
#if SUPPORT_PURCHASE_ACCOUNT
			HUD.mode = MBProgressHUDModeIndeterminate;
			HUD.labelText =  NSLocalizedString(@"Processing", @"Processing");

			[[StoreManager sharedInstance] startPurchaseProductID:product.productID
			                                         forLocalUser:localUser
			                                      completionBlock:^(NSError *error, NSDictionary *infoDict)
			{
				if (error)
				{
					[self stopActivityIndicator];
					
					[STAppDelegate showAlertWithTitle:@"startPurchaseProductID Failed"
					                          message:error.localizedDescription];
				}
			}];
#else
			[self stopActivityIndicator];
			
			[STPreferences setSelectedUserId:userID];
			NSString* welcomeMessge = NSLocalizedString(@"Welcome to Silent Circle.\n ",
														@"welcome text");
			
			[MessageStream sendInfoMessage:welcomeMessge toUser:userID];

			if ([self.delegate respondsToSelector:@selector(dismissActivationVC:error:)])
				[self.delegate dismissActivationVC:self error:error];
#endif
		}
	
	}];
}

#if SUPPORT_PURCHASE_ACCOUNT
#pragma mark In App Purchases
- (void)purchaseTransactionComplete:(NSNotification *)notification
{
    NSDictionary* dict = notification.object;
    //   SKPaymentTransaction* paymentTransaction = [dict objectForKey:  @"paymentTransaction" ];
    NSError* error      = [dict objectForKey:  @"error" ];
    NSString* userID    = [dict objectForKey: @"userId"];
    
    [self stopActivityIndicator];
    
    [STPreferences setSelectedUserId:userID];

    
    if(error)
    {
        if([error.domain isEqualToString: SKErrorDomain])  //created an account and bailed
        {
            
            [STAppDelegate showAlertWithTitle: NSLocalizedString(@"Purchase incomplete", @"Purchase incomplete")
                                      message: NSLocalizedString(@"You have succesfully created a Silent Circle account, but canceled payment."
                                                                 "Your username will still be available for one week. "
                                                                 "Please contact Silent Circle customer support if you wish to complete this transaction",
                                                                 @"Canceled account payment message")];
            

            //ET 10/28/14 - revealController dismissal handled in base class with generic delegate
            
            if ([self.delegate respondsToSelector:@selector(dismissActivationVC:error:)])
            {
                [self.delegate dismissActivationVC:self error:error];
            }
          
        }
        else
        {
            [self retryPaymentForUserID: userID withError:error];
        }
        
    }
    else
    {
        NSString* welcomeMessge = NSLocalizedString(@"Thank you for purchasing a Silent Circle account.\n ",
                                              @"purchase welcome text");
            
        
        [MessageStream sendInfoMessage:welcomeMessge toUser:userID];
        
        //ET 10/28/14 - revealController dismissal handled in base class with generic delegate

        // Note that the VC which initialized and presented the self controller should be
        // the self.delegate and should dismiss appropriately
        if ([self.delegate respondsToSelector:@selector(dismissActivationVC:error:)])
        {
            [self.delegate dismissActivationVC:self error:error];
        }

    }
}
#endif

- (void)retryPaymentForUserID:(NSString *)userID withError:(NSError *)error
{
	NSString *title =
	  NSLocalizedString(@"Your purchase was successful, but we can not complete activation",
	                    @"Your purchase was successful, but we can not complete activation");
	
	[OHAlertView showAlertWithTitle:title
	                        message:error.localizedDescription
	                   cancelButton:NSLocalizedString(@"Cancel", @"Cancel")
	                       okButton:NSLocalizedString(@"Try Again", @"Try Again")
	                  buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex)
	{
		if (buttonIndex != alert.cancelButtonIndex)
		{
			[self startActivityIndicator];
             
			[[STUserManager sharedInstance] retryPaymentForUserID:userID
			                                      completionBlock:^(NSError *error, NSString *uuid)
			{
				[self stopActivityIndicator];
				
				// keep doing this;
				//
				// Really ?!?? And what about when the app crashes.
				// Or the user kills the app.
				// Or the user restarts the phone.
				// Or the phone dies.
				// Or the user upgrades the OS, and it restarts during the process.
				//
				// Hm... Sounds like we need to set some kind of flag in the database,
				// and pickup where we left off if the app is restarted.
				//
				if (error)
				{
					[self retryPaymentForUserID:uuid withError:error];
				}
			}];
		}
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Privacy Policy Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)privacyPolicyAction:(id)sender
{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://silentcircle.com/web/privacy/"]];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Textfield Validation Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range
replacementString:(NSString *)string
{
    BOOL result = YES;
    
    if (textField == deviceField)
    {
        
        for (int i = 0; i < [string length]; i++) {
            unichar c = [string characterAtIndex:i];
            if (! [charsForDeviceName characterIsMember:c] ) {
                return NO;
            }
        }
    }
    else if (textField == usernameField)
    {
        for (int i = 0; i < [string length]; i++) {
            unichar c = [string characterAtIndex:i];
            if (![charsForUserName characterIsMember:c]) {
                return NO;
            }
        }
        
        // Check if the added string contains lowercase characters.
        // If so, those characters are replaced by uppercase characters.
        // But this has the effect of losing the editing point
        // (only when trying to edit with lowercase characters),
        // because the text of the UITextField is modified.
        // That is why we only replace the text when this is really needed.
        NSRange uppercaseRange;
        uppercaseRange = [string rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]];
        
        if (uppercaseRange.location != NSNotFound) {
            
            textField.text = [textField.text stringByReplacingCharactersInRange:range
                                                                     withString:[string lowercaseString]];
            return NO;
        }        
    }
	
    return result;
}

- (BOOL)userNameIsValid 
{
    return usernameField.text.length > 0;
}

- (BOOL)deviceIsValid 
{
    return deviceField.text.length > 0;
}

- (BOOL)passwordIsValid
{
    return passwordField.passwordIsValid;
}

// Callback registered in viewDidLoad
- (void)textFieldDidChange:(UITextField *)sender
{
    [purchaseButton setEnabled:[self purchaseTestsPass]];
}


- (BOOL)purchaseTestsPass 
{
    return ([self userNameIsValid] && [self deviceIsValid] && [self passwordIsValid]);
}


#pragma mark - Keyboard/TextField Navigation

// Resign keyboard if passwordField is firstResponder && tests Pass
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (NO == [self purchaseTestsPass])
    {
        if (textField == usernameField && NO == [self passwordIsValid])
        {
            [passwordField becomeFirstResponder];
            return NO;
        }
        else if (textField == passwordField)
        {
            [emailField becomeFirstResponder];
            return NO;            
        }
    }

    // In all other cases, dismiss keyboard
    [textField resignFirstResponder];
    
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    activeField = textField;
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    activeField = nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Network Action/Button
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)configureNetworkChoices
{
	// Debug versions allow us to select the network.
	
	NSMutableDictionary *netDict = [NSMutableDictionary dictionary];
	
    for (NSString *networkID in  [AppConstants SilentCircleNetworkInfo].allKeys)
    {
        NSDictionary* dict = [[AppConstants SilentCircleNetworkInfo] objectForKey:networkID];
        
        if ([[dict objectForKey:@"canProvision"] boolValue])
        {
            [netDict setObject:[dict objectForKey:@"displayName"] forKey:networkID];
        }
    }
    
    // for debug version, we allow the user to pick a network selection
    networkChoices = netDict;
    selectedNetwork = kNetworkID_Production;
    allowNetworkSelect = (networkChoices.count > 1);
    
    [self updateNetworkButton];
    
}

- (IBAction)networkAction:(UIButton *)button
{
    if (allowNetworkSelect)
    {
        NSString *title = NSLocalizedString(@"Select network to provision with", @"");
        
        //ET 10/16/14 OHActionSheet update
        CGRect frame = [containerView convertRect:button.frame toView:self.view];
        [OHActionSheet showFromRect:frame
                           sourceVC:self 
                             inView:self.view
                     arrowDirection:([self presentActionSheetAsPopover]) ? UIPopoverArrowDirectionDown : 0
                            title:title
                cancelButtonTitle:NSLS_COMMON_CANCEL
           destructiveButtonTitle:nil
                otherButtonTitles:[networkChoices allValues]
                       completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                           
                           NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
                           
                           NSArray *items = [networkChoices allKeysForObject:choice];
                           if (items.count)
                           {
                               selectedNetwork = [items firstObject];
                               
                           }
                           
                           [self updateNetworkButton];
                       }];
    }
}

// Determine whether to present an actionSheet from bottom of view or in a popover.
// Presented from Contacts, it will be in a large view; if on iPhone, or from within a popover
// the view will be "small".
- (BOOL)presentActionSheetAsPopover
{
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    if (UIDeviceOrientationIsLandscape(orientation))
        return self.view.frame.size.width > 480.0f;
    else
        return self.view.frame.size.width > 320.0f;
}


- (void)updateNetworkButton
{
    NSString* buttonTitle =  @"";
    
    if (allowNetworkSelect)
    {
        buttonTitle = [networkChoices objectForKey:selectedNetwork];
        [networkButton setHidden: NO];
    }
    else
    {
        [networkButton setHidden: YES];
    }
  	
    [networkButton setTitle: buttonTitle forState: UIControlStateNormal ];
    [networkButton setTitle: buttonTitle forState: UIControlStateDisabled ];
    [networkButton setTitle: buttonTitle forState: UIControlStateHighlighted ];
    [networkButton setTitle: buttonTitle forState: UIControlStateSelected ];
    
    [networkButton setNeedsUpdateConstraints];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - HUD
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)stopActivityIndicator
{
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
	usernameField.enabled = YES;
	passwordField.enabled = YES;
	deviceField.enabled   = YES;
	purchaseButton.enabled = YES;
}

- (void)startActivityIndicator
{
	HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
	HUD.delegate = self;
	HUD.mode = MBProgressHUDModeIndeterminate;
	HUD.labelText = NSLS_COMMON_ACTIVATING;
	
	usernameField.enabled = NO;
	passwordField.enabled = NO;
	deviceField.enabled   = NO;
	purchaseButton.enabled = NO;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Forgot Password
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)forgotPasswordAction:(UIButton *)button
{    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://accounts.silentcircle.com/account/recover/"]];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Keyboard
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)getKeyboardHeight:(float *)keyboardHeightPtr
        animationDuration:(NSTimeInterval *)animationDurationPtr
           animationCurve:(UIViewAnimationCurve *)animationCurvePtr
                     from:(NSNotification *)notification
{
	float keyboardHeight;
	double animationDuration;
	UIViewAnimationCurve animationCurve;
	
	// UIKeyboardCenterBeginUserInfoKey:
	// The key for an NSValue object containing a CGRect
	// that identifies the start frame of the keyboard in screen coordinates.	
	CGRect keyboardEndRect = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	keyboardHeight = keyboardEndRect.size.height; //ET default to given height
    
    //ET 10/31/14
    // Conditionally handle the height/width inversion for < iOS 8
    if (NO == AppConstants.isIOS8OrLater)
    {
        if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
        {
            keyboardHeight = keyboardEndRect.size.width;
        }
    }
	
	DDLogVerbose(@"keyboardHeight: %.0f", keyboardHeight);
	
	// UIKeyboardAnimationDurationUserInfoKey
	// The key for an NSValue object containing a double that identifies the duration of the animation in seconds.	
	animationDuration = [[notification.userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
	
	// UIKeyboardAnimationCurveUserInfoKey
	// The key for an NSNumber object containing a UIViewAnimationCurve constant that defines
	// how the keyboard will be animated onto or off the screen.	
	animationCurve = [[notification.userInfo objectForKey:UIKeyboardAnimationCurveUserInfoKey] intValue];
	
	if (keyboardHeightPtr) *keyboardHeightPtr = keyboardHeight;
	if (animationDurationPtr) *animationDurationPtr = animationDuration;
	if (animationCurvePtr) *animationCurvePtr = animationCurve;
}

- (void)keyboardWillShow:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	float keyboardHeight;
	[self getKeyboardHeight:&keyboardHeight
	      animationDuration:NULL
	         animationCurve:NULL
	                   from:notification];
	
    // ensure contentHeight allows scrolling of bottom-most subview to above keyboard
	UIEdgeInsets contentInsets = scrollView.contentInset;
    if (contentInsets.bottom < keyboardHeight)
    {
        contentInsets.bottom = keyboardHeight;
        scrollView.contentInset = contentInsets;
        scrollView.scrollIndicatorInsets = contentInsets;
    }
    
    // If active text field is hidden by keyboard, scroll it so it's visible
    CGRect aRect = self.view.frame;
    aRect.size.height -= keyboardHeight;
    if (NO == CGRectContainsPoint(aRect, activeField.frame.origin) ) {
        [scrollView scrollRectToVisible:activeField.frame animated:YES];
    }
}

- (void)keyboardDidShow:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	[scrollView flashScrollIndicators];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
	DDLogAutoTrace();
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    scrollView.contentInset = contentInsets;
    scrollView.scrollIndicatorInsets = contentInsets;
}

- (void)dismissKeyboard
{
	[usernameField resignFirstResponder];
    [deviceField resignFirstResponder];
	[passwordField resignFirstResponder];
}

@end
