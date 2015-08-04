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
#import "LogInViewController.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "MBProgressHUD.h"
#import "MessageStream.h"
#import "OHActionSheet.h"
#import "OHAlertView.h"
#import "SCTPasswordTextfield.h"
#import "SilentTextStrings.h"
#import "STDynamicHeightView.h"
#import "STMessage.h"
#import "STPreferences.h"
#import "STLogging.h"
#import "STUser.h"
#import "STUserManager.h"

NS_ENUM(NSInteger, SCActivationMode) {
    sc_Activate,
    sc_Reactivate
};

// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && robbie_hanson
    static const int ddLogLevel = LOG_LEVEL_INFO; // VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG && eric_turner
    static const int ddLogLevel = LOG_LEVEL_INFO; // VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
    static const int ddLogLevel = LOG_LEVEL_INFO;
#else
    static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

@interface LogInViewController ()  <MBProgressHUDDelegate, UITextFieldDelegate>

@property (nonatomic, weak) IBOutlet UITextField *usernameField;
@property (nonatomic, weak) IBOutlet SCTPasswordTextfield *passwordField;
@property (nonatomic, weak) IBOutlet UITextField *deviceField;
@property (nonatomic, weak) IBOutlet UIButton *activateButton;
@property (nonatomic, weak) IBOutlet UIButton *forgetButton;
@property (nonatomic, weak) IBOutlet UIButton *networkButton;

- (IBAction)activateAction:(UIButton *)activateButton;
- (IBAction)reactivateAction:(UIButton *)activateButton;

@end

@implementation LogInViewController
{
    MBProgressHUD   *HUD;
    NSDictionary    *networkChoices;
    NSString        *selectedNetwork;
    BOOL            allowNetworkSelect;    
    NSCharacterSet* charsForDeviceName;
    NSCharacterSet* charsForUserName;
    UITextField     *activeField;
    
    //ET 02/27/15 - defaults to "Activation", not "Reactivation"
    enum SCActivationMode _activationMode;
}

@synthesize usernameField = usernameField;
@synthesize passwordField = passwordField;
@synthesize deviceField = deviceField;
@synthesize activateButton = activateButton;
@synthesize forgetButton = forgetButton;
@synthesize networkButton = networkButton;

@synthesize existingUserID = existingUserID;


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
    
    self.title = NSLocalizedString(@"Authorize Device", @"Activate title");
    
    // 07/08/14
    //------------------------------------------------------------------------------------//
    // Get callback for TextField edit events.
    //------------------------------------------------------------------------------------//
    [usernameField addTarget:self 
                  action:@selector(textFieldDidChange:) 
        forControlEvents:UIControlEventEditingChanged];
    // Set delegate for charset validation for each entered char
    usernameField.delegate = self;
    
    // SCTPasswordTextField control encapsulates character validatation/ password strength / eyeball
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
    
    // ET 07/08/14 - encapsulate username/device character validation charsets
    // NOTE: this MUST precede the configureInitialDeviceField invocation!
    [self configureTextFieldCharsets];    

    // ET 07/09/14 - encapsulate deviceField text configuration
    [self configureInitialDeviceField];
    
    // ET 07/08/14 - encapsulate network choices/network button
    [self configureNetworkChoices];
    
    // ET 07/08/14 - encapsulate view activation state setup
    [self configureInitialActivationState];

	// Register for keyboard notifications
	if (NO == self.isInPopover)
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
	
    //ET 02/27/15 (ST-830 - while renaming "NewUser" classes to "User")
    // Move to viewWillAppear to handle "reactivation". When reactivating
    // usernameField is disabled - confusing.
//    [usernameField becomeFirstResponder];
}

//ET 02/27/15 (ST-830 - while renaming "NewUser" classes to "User")
// Make first responder the password field if "Reactivating".
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    if (_activationMode == sc_Reactivate)
        [passwordField becomeFirstResponder];
    else
        [usernameField becomeFirstResponder];
}

- (void)cancelButtonTapped:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
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
#pragma mark - Activation Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//ET 02/27/15
// Add SCActivationMode
- (void)configureInitialActivationState
{	
    usernameField.text = @"";
	passwordField.text = @"";
	
	if (existingUserID)
    {
		__block STUser *user = nil;
		[STDatabaseManager.roDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			user = [transaction objectForKey:existingUserID inCollection:kSCCollection_STUsers];
		}];
		
		if (user)
		{
			usernameField.text = @"";
			usernameField.placeholder = user.jid.user;
			usernameField.enabled = NO;
			
            selectedNetwork =  user.networkID;
            
            [passwordField becomeFirstResponder];
            
            [activateButton addTarget:self
                               action:@selector(reactivateAction:)
                     forControlEvents:UIControlEventTouchUpInside];
        }
        
        _activationMode = sc_Reactivate;
    }
	else
    {
        [activateButton addTarget:self
                           action:@selector(activateAction:)
                 forControlEvents:UIControlEventTouchUpInside];
        
        usernameField.enabled = YES;
        
        _activationMode = sc_Activate;
 	}
    
    [activateButton setEnabled:NO];
    
}

- (void)activateUserName:(NSString *)userName
            withPassword:(NSString *)password
              deviceName:(NSString *)deviceName
               networkID:(NSString *)networkID
          isExistingUser:(BOOL)isExistingUser
{
	DDLogAutoTrace();
	
	[self startActivityIndicator];
	
	[[STUserManager sharedInstance] activateUserName:userName
	                                    withPassword:password
	                                      deviceName:deviceName
	                                       networkID:networkID
	                                 completionBlock:^(NSError *error, NSString *newUUID)
	{
		[self stopActivityIndicator];
		
		if (error)
		{
			NSString *title = NSLocalizedString(@"Unable To Authorize", "Unable to authorize (title)");
			
			[OHAlertView showAlertWithTitle:title
			                        message:error.localizedDescription
			                   cancelButton:NULL
			                       okButton:NSLS_COMMON_OK
			                  buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex)
			{
                // not dismissing this VC - let user re-enter credentials
			}];
		}
		else
		{
			// This isn't needed, as [STUserManager activateUserName] already did it for us.
			[STPreferences setSelectedUserId:newUUID];
			
			NSString *welcomeMessge = nil;
			if(isExistingUser)
			{
				welcomeMessge = NSLocalizedString(@"You have reauthorized this device for your Silent Circle account.",
				                                  @"Welcome message after authorizing account/device");
			}
			else
			{
				welcomeMessge = NSLocalizedString(@"Welcome to Silent Circle.",
				                                  @"Welcome message after authorizing account/device");
			}
			
			[MessageStream sendInfoMessage:welcomeMessge toUser:newUUID];
			
            // Note that the VC which initialized and presented the self controller (OnboardVC) 
            // should be the self.delegate and should dismiss appropriately
            if ([self.delegate respondsToSelector:@selector(dismissActivationVC:error:)])
            {
                [self.delegate dismissActivationVC:self error:error];
            }

		}
	
	}]; // end [STUserManager activateUserName:
}

- (IBAction)activateAction:(UIButton *)activateButton
{
    [self dismissKeyboard];
 	
    // ET 07/08/14 Should this use the new activationTestsPass method?
	if (usernameField.text.length > 0 && passwordField.text.length > 0)
	{
		if ([STDatabaseManager isUserProvisioned:usernameField.text networkID:selectedNetwork])
        {
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Device Already Authorized", @"Device already authorized")
                                        message: [NSString stringWithFormat:
                                                  NSLocalizedString(@"This device has already been authorized for %@", @"Device  already authorized"), usernameField.text]
                                       delegate:nil
                              cancelButtonTitle:NSLS_COMMON_OK
                              otherButtonTitles:nil] show];
            
        }
        else
        {
            
            [self activateUserName: usernameField.text
                      withPassword: passwordField.text
                        deviceName: deviceField.text
                         networkID: selectedNetwork
                    isExistingUser: NO];
            
        };  // end if(isUserProvisioned)
        
	} // end if (usernameField.text.length > 0 && passwordField.text.length > 0)
}


- (IBAction)reactivateAction:(UIButton *)activateButton
{
    [self dismissKeyboard];
    
    [self activateUserName: usernameField.placeholder
              withPassword: passwordField.text
                deviceName: deviceField.text
                 networkID: selectedNetwork
            isExistingUser: YES];
    
}

- (BOOL)authorizeTestsPass 
{
    return (existingUserID || ([self userNameIsValid] && [self deviceIsValid] && [self passwordIsValid]));
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
    [activateButton setEnabled:[self authorizeTestsPass]];
}


#pragma mark - Keyboard/TextField Navigation

// Resign keyboard if passwordField is firstResponder && tests Pass
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (NO == [self authorizeTestsPass])
    {
        if (textField == usernameField && NO == [self passwordIsValid])
        {
            [passwordField becomeFirstResponder];
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

- (void)configureNetworkChoices {
    // debug versions allow us to select the network.
    NSMutableDictionary *netDict = [NSMutableDictionary dictionary];
    for (NSString *networkID in  [AppConstants SilentCircleNetworkInfo].allKeys)
    {
        NSDictionary* dict = [[AppConstants SilentCircleNetworkInfo] objectForKey:networkID];
        
        if([dict objectForKey:@"canProvision"] &&  ([[dict objectForKey:@"canProvision"]boolValue] ==  YES))
        {
            [netDict setObject:[dict objectForKey:@"displayName"] forKey:networkID];
        }
    }
    
    
    // for debug version, we allow the user to pick a network selection
    networkChoices = netDict;
    selectedNetwork = kNetworkID_Production;
    allowNetworkSelect = (networkChoices.count > 1) && !existingUserID;
    [self updateNetworkButton];
}

- (IBAction)networkAction:(UIButton *)button
{
	if (!allowNetworkSelect) return;
	
	NSString *title = NSLocalizedString(@"Select network to provision with", @"");
	
	// SORT the network choices.
	//
	// These should be stored in a standard way.
	// We can pick any way we want, but it should be sorted the same way everytime.
	//
	// Do NOT assume that [dictionary allValues] will always return the same order.
	// That is NOT guaranteed.
	
	NSArray *choices_unsorted = [networkChoices allValues];
	
	NSArray *choices_sorted = [choices_unsorted sortedArrayUsingComparator:
	^NSComparisonResult(NSString *choice1, NSString *choice2) {
		
		return [choice1 localizedCaseInsensitiveCompare:choice2];
	}];
	
	CGRect frame = [containerView convertRect:button.frame toView:self.view];
	[OHActionSheet showFromRect:frame
	                   sourceVC:self
	                     inView:self.view
	             arrowDirection:([self presentActionSheetAsPopover] ? UIPopoverArrowDirectionDown : 0)
	                      title:title
	          cancelButtonTitle:NSLS_COMMON_CANCEL
	     destructiveButtonTitle:nil
	          otherButtonTitles:choices_sorted
	                 completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
	{
		NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
		
		NSArray *items = [networkChoices allKeysForObject:choice];
		if (items.count)
		{
			selectedNetwork = [items firstObject];
		}
		
		[self updateNetworkButton];
	}];
}

// A hacky way to determine whether to present an actionSheet from bottom of view or in a popover.
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
	NSString *buttonTitle = @"";
    
	if (allowNetworkSelect)
	{
		buttonTitle = [networkChoices objectForKey:selectedNetwork];
		[networkButton setHidden:NO];
	}
	else
	{
		[networkButton setHidden: YES];
	}
	
	[networkButton setTitle:buttonTitle forState:UIControlStateNormal];
	[networkButton setTitle:buttonTitle forState:UIControlStateDisabled];
	[networkButton setTitle:buttonTitle forState:UIControlStateHighlighted];
	[networkButton setTitle:buttonTitle forState:UIControlStateSelected];
	
//	[networkButton setNeedsUpdateConstraints];
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
	activateButton.enabled = YES;
}

- (void)startActivityIndicator
{
	HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
	HUD.delegate = self;
	HUD.mode = MBProgressHUDModeIndeterminate;
	HUD.labelText = NSLS_COMMON_AUTHORIZING;
	
	usernameField.enabled = NO;
	passwordField.enabled = NO;
	deviceField.enabled   = NO;
	activateButton.enabled = NO;
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
