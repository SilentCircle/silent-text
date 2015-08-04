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
#import "SilentTextStrings.h"
#import "AddAccountsViewController.h"
#import "AppDelegate.h"
#import "AppConstants.h"
#import "SettingsViewController.h"
#import "AppDelegate.h"
#import "MBProgressHUD.h"
#import "SCAccountsWebAPIManager.h"
#import "STPreferences.h"
#import "XMPP.h"
#import "STLogging.h"
#import "STUser.h"
#import "OHActionSheet.h"
#import "AddressBookManager.h"
#import "NSDate+SCDate.h"
#import "STUserManager.h"
#import "SettingsViewController.h"
#import "AppAnalytics.h"

// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_INFO; // VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif


@interface AddAccountsViewController () <MBProgressHUDDelegate, UITextFieldDelegate, SCAccountsWebAPIManagerDelegate>

@property (nonatomic, strong) IBOutlet UIView * containerView; // strong to support moving around

@property (nonatomic, weak) IBOutlet UILabel     * usernameLabel;
@property (nonatomic, weak) IBOutlet UITextField * usernameTextField;

@property (nonatomic, weak) IBOutlet UILabel     * passwordLabel;
@property (nonatomic, weak) IBOutlet UITextField * passwordTextField;

@property (nonatomic, weak) IBOutlet UILabel  * showPasswordLabel;
@property (nonatomic, weak) IBOutlet UISwitch * showPasswordSwitch;

@property (nonatomic, weak) IBOutlet UILabel     * deviceLabel;
@property (nonatomic, weak) IBOutlet UITextField * deviceTextField;

@property (nonatomic, weak) IBOutlet UIButton * activateButton;

@property (nonatomic, weak) IBOutlet UILabel  * networkLabel;
@property (nonatomic, weak) IBOutlet UIButton * networkButton;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *heightConstraint;


- (IBAction)activateAction:(UIButton *)activateButton;
- (IBAction)reactivateAction:(UIButton *)activateButton;

- (IBAction)networkAction:(UIButton *)networkButton;
- (IBAction)showPasswordAction:(UISwitch *)spSwitch;

@end

@implementation AddAccountsViewController
{
	MBProgressHUD *HUD;
	NSString *uuidString;
   
    NSDictionary* networkChoices;
    NSString*   selectedNetwork;
    
	UIScrollView *scrollView;
	BOOL resetContentInset;
    
    NSCharacterSet* charsForDeviceName;
    NSCharacterSet* charsForPassword;
    NSCharacterSet* charsForUserName;
    
}
@synthesize isInPopover = isInPopover;

@synthesize containerView = containerView;

@synthesize usernameLabel = usernameLabel;
@synthesize usernameTextField = usernameTextField;

@synthesize passwordLabel = passwordLabel;
@synthesize passwordTextField = passwordTextField;

@synthesize showPasswordLabel = showPasswordLabel;
@synthesize showPasswordSwitch = showPasswordSwitch;

@synthesize deviceLabel = deviceLabel;
@synthesize deviceTextField = deviceTextField;

@synthesize activateButton = activateButton;

@synthesize networkLabel = networkLabel;
@synthesize networkButton = networkButton;

@synthesize existingUserID = existingUserID;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
    }
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark View Lifecycle

- (void)viewDidLoad
{
	DDLogAutoTrace();
    [super viewDidLoad];
	
	self.title = NSLocalizedString(@"Add Account", @"AddAccountsViewController title");
//	self.navigationItem.leftBarButtonItem =  STAppDelegate.settingsButton;
	self.edgesForExtendedLayout=UIRectEdgeNone;
	self.extendedLayoutIncludesOpaqueBars=NO;

	[networkLabel setHidden:YES];
	[networkButton setHidden:YES];
    
    NSMutableDictionary *netDict = [NSMutableDictionary dictionary];
    
    for(NSString* networkID in  [AppConstants SilentCircleNetworkInfo].allKeys)
    {
          NSDictionary* dict = [[AppConstants SilentCircleNetworkInfo] objectForKey:networkID];
        
            if([dict objectForKey:@"canProvision"] &&  ([[dict objectForKey:@"canProvision"]boolValue] ==  YES))
            {
                [netDict setObject:[dict objectForKey:@"displayName"] forKey:networkID];
            }
     }
    
    networkChoices = netDict;
    selectedNetwork = kNetworkChoiceKeyProduction;

	if (networkChoices.count > 1)
	{
		[networkLabel setHidden:NO];
		[networkButton setHidden:NO];
	}
	else
	{
		CGRect frame = containerView.bounds;
		frame.size.height -= 40;
		containerView.bounds = frame;
		_heightConstraint.constant -= 40;
	}
    
 	if (AppConstants.isIPhone)
	{
		// On iPhone, we wrap the view in a scrollView.
		// Because the view gets obstructed by the keyboard due to the small screen real estate.
		
		self.navigationItem.leftBarButtonItem =
		  [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Cancel", @"")
		                                   style:UIBarButtonItemStylePlain
		                                  target:self
		                                  action:@selector(handleActionBarDone)];

		CGRect frame = self.view.bounds;
		scrollView = [[UIScrollView alloc] initWithFrame:frame];
		scrollView.delegate = self;
		scrollView.showsHorizontalScrollIndicator = NO;
		scrollView.showsVerticalScrollIndicator = YES;
		scrollView.contentSize = containerView.frame.size;
		scrollView.indicatorStyle = UIScrollViewIndicatorStyleBlack;
		scrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
		
		scrollView.backgroundColor = containerView.backgroundColor;
		
		if ([scrollView respondsToSelector:@selector(keyboardDismissMode)]) // iOS 7 API
			scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
		
		[containerView removeFromSuperview];
		
		CGRect containerViewFrame = containerView.frame;
		containerViewFrame.origin.x = 0;
		containerViewFrame.origin.y = 0;
//		containerViewFrame.size.height -= 44;

		containerView.frame = containerViewFrame;
		
		[scrollView addSubview:containerView];
		[self.view addSubview:scrollView];
        
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(keyboardWillShow:)
		                                             name:UIKeyboardWillShowNotification
		                                           object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(keyboardWillHide:)
		                                             name:UIKeyboardWillHideNotification
		                                           object:nil];
	}
	else // if (AppConstants.isIPad)
	{
	
		self.view.backgroundColor = [UIColor darkGrayColor];
		
        if(!isInPopover)
        {
            containerView.layer.cornerRadius = 10;

            NSLayoutConstraint *constraint = [self topConstraintFor:containerView];
            constraint.constant = 52;
        
            [self.view setNeedsUpdateConstraints];
        }
	}
	
    [self updateNetworkButton];
    
    passwordTextField.secureTextEntry = YES;
    passwordTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
	
	passwordTextField.rightViewMode = UITextFieldViewModeAlways;
	CGRect frame = CGRectMake(0, 0, 30, 30);
	UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
	button.frame = frame;
	[button setImage:[UIImage imageNamed:@"MZ_EYE_ICON_CLOSED"] forState:UIControlStateNormal];
	[button setImage:[UIImage imageNamed:@"MZ_EYE_ICON_OPEN"] forState:UIControlStateSelected];
	[button addTarget:self action:@selector(eyeballPokeAction:) forControlEvents:UIControlEventTouchDown];
//	[button setTitle:@"TT" forState:UIControlStateNormal];
	passwordTextField.rightView = button;

    showPasswordSwitch.on = NO;
    activateButton.enabled = NO;
    
    usernameTextField.delegate  = self;
    passwordTextField.delegate = self;
    deviceTextField.delegate = self;
    
    NSMutableCharacterSet* charSet = [[NSMutableCharacterSet alloc] init];
    [charSet formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
    [charSet formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
    [charSet formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
    [charSet formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
    charsForDeviceName = charSet;
    charsForPassword = charSet;
    
    charsForUserName = [NSCharacterSet alphanumericCharacterSet];
}

- (void)viewWillAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillAppear:animated];
	
//	[self.navigationController.revealController enterPresentationModeAnimated:animated completion:NULL];
	
	usernameTextField.text = @"";
	passwordTextField.text = @"";
	uuidString = nil;
    
	NSString *unfilteredDeviceName = @"";
    
#if TARGET_OS_IPHONE
    unfilteredDeviceName = UIDevice.currentDevice.name;
#else
    unfilteredDeviceName = (__bridge_transfer NSString *)SCDynamicStoreCopyComputerName(NULL, NULL);
#endif
    
    unfilteredDeviceName =  [[unfilteredDeviceName componentsSeparatedByCharactersInSet: [charsForDeviceName invertedSet]] componentsJoinedByString:@"_"];
    
    deviceTextField.text = unfilteredDeviceName;
	
#if DEBUG
	
	// Testing constraints for localization
	
//	usernameLabel.text = @"Longer username";
//	usernameLabel.text = @"Crazy long username";
//	[containerView setNeedsUpdateConstraints];
#endif
    
    if(existingUserID)
    {
        __block STUser* user = NULL;
        
        YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
        [rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
            
            user =  [transaction objectForKey:existingUserID inCollection:kSCCollection_STUsers];
            
         } completionBlock:^{
             
             if(user)
             {
                 self.title = NSLocalizedString(@"Activate Account", @"Activate title");

                 usernameTextField.text = @"";
                 usernameTextField.placeholder = user.userName;
                 usernameTextField.enabled = NO;
                 networkButton.enabled = NO;

                 uuidString = user.uuid;
                 selectedNetwork =  user.networkID;
                 [self updateNetworkButton];
                 [passwordTextField becomeFirstResponder];
                 
                 [activateButton addTarget:self
                                    action:@selector(reactivateAction:)
                          forControlEvents:UIControlEventTouchUpInside];
                 
             }
         }];

    }
	else
    {
        
        [activateButton addTarget:self
                     action:@selector(activateAction:)
           forControlEvents:UIControlEventTouchUpInside];
        
        
        [usernameTextField becomeFirstResponder];
        
        usernameTextField.enabled = YES;
        networkButton.enabled = YES;

    }

}

- (NSUInteger)supportedInterfaceOrientations
{
	DDLogAutoTrace();
	
	if (AppConstants.isIPhone)
		return UIInterfaceOrientationMaskAllButUpsideDown;
	else
		return UIInterfaceOrientationMaskAll;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                         duration:(NSTimeInterval)duration
{
	DDLogAutoTrace();
	
	if (AppConstants.isIPhone)
	{
		scrollView.frame = self.view.bounds;
		
		CGRect containerFrame = containerView.frame;
		containerFrame.origin.x = (scrollView.frame.size.width - containerFrame.size.width) / 2.0F;
		
		containerView.frame = containerFrame;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSLayoutConstraint *)topConstraintFor:(id)item
{
	for (NSLayoutConstraint *constraint in self.view.constraints)
	{
		if ((constraint.firstItem == item && constraint.firstAttribute == NSLayoutAttributeTop) ||
		    (constraint.secondItem == item && constraint.secondAttribute == NSLayoutAttributeTop))
		{
			return constraint;
		}
	}
	
	for (NSLayoutConstraint *constraint in containerView.constraints)
	{
		if ((constraint.firstItem == item && constraint.firstAttribute == NSLayoutAttributeTop) ||
		    (constraint.secondItem == item && constraint.secondAttribute == NSLayoutAttributeTop))
		{
			return constraint;
		}
	}
	
	return nil;
}

- (void)updateNetworkButton
{
	NSString *title = [networkChoices objectForKey:selectedNetwork];
	
	[networkButton setTitle:title forState:UIControlStateNormal];
	[networkButton setNeedsUpdateConstraints];
	
//	[networkButton sizeToFit];
//	networkButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
//	networkButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Keyboard
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
	
	if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
	{
		keyboardHeight = keyboardEndRect.size.width;
	}
	else
	{
		keyboardHeight = keyboardEndRect.size.height;
	}
	
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
	
	// Note: This method is only called on iPhone
	
	// Extract information about the keyboard change
	
	float keyboardHeight = 0.0F;
	NSTimeInterval animationDuration = 0.0;
	
	[self getKeyboardHeight:&keyboardHeight
	      animationDuration:&animationDuration
	         animationCurve:NULL
	                   from:notification];
	
	// On iOS7, the scrollView.contentInset.top is automatically set to the height of the statusBar + navBar.
	// We need to ensure the top value stays the same.
	
	UIEdgeInsets insets = scrollView.contentInset;
	insets.bottom = keyboardHeight;
	
	scrollView.contentInset = insets;
	scrollView.scrollIndicatorInsets = insets;
	
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(animationDuration * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		
		[scrollView flashScrollIndicators];
	});
	
	resetContentInset = NO;
}

- (void)keyboardWillHide:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	// Note: This method is only called on iPhone
	
	// Extract information about the keyboard change.
	
	float keyboardHeight = 0.0F;
	NSTimeInterval animationDuration = 0.0;
	UIViewAnimationCurve animationCurve = UIViewAnimationCurveLinear;
	
	[self getKeyboardHeight:&keyboardHeight
	      animationDuration:&animationDuration
	         animationCurve:&animationCurve
	                   from:notification];
	
	UIViewAnimationOptions animationOptions = 0;
	switch (animationCurve)
	{
		case UIViewAnimationCurveEaseInOut : animationOptions |= UIViewAnimationOptionCurveEaseInOut; break;
		case UIViewAnimationCurveEaseIn    : animationOptions |= UIViewAnimationOptionCurveEaseIn;    break;
		case UIViewAnimationCurveEaseOut   : animationOptions |= UIViewAnimationOptionCurveEaseOut;   break;
		case UIViewAnimationCurveLinear    : animationOptions |= UIViewAnimationOptionCurveLinear;    break;
		default                            : animationOptions |= (animationCurve << 16);              break;
	}
	
	// Animate the change so the tableView slides back into its normal position.
	//
	// Note: If the scrollView was scrolled up a bit, and we simply reset the contentInset,
	// then the scrollView jumps back down into position in a non-animated non-smooth fashion.
	
	CGFloat spaceAbove = scrollView.contentOffset.y + scrollView.contentInset.top;
	CGFloat spaceBelow = scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.frame.size.height;
	
	if (spaceAbove < 0)
	{
		// The user is dimissing the keyboard on iOS 7 via UIScrollViewKeyboardDismissModeInteractive.
		//
		// Allow the scrollView to rubber-band back into position,
		// and then reset the contentInset.
		
		resetContentInset = YES;
		return;
	}
	else
	{
		resetContentInset = NO;
	}
	
	if (spaceBelow < 0)
		spaceBelow = 0;
	
	DDLogVerbose(@"spaceAbove: %f", spaceAbove);
	DDLogVerbose(@"spaceBelow: %f", spaceBelow);
	
	CGRect originFrame = scrollView.frame;
	CGRect finishFrame = scrollView.frame;
	
	CGPoint contentOffset = scrollView.contentOffset;
	
	originFrame.size.height -= keyboardHeight;
	
	DDLogVerbose(@"Step 0: originFrame: %@", NSStringFromCGRect(originFrame));
	
	CGFloat left = keyboardHeight;
	
	if (left > 0)
	{
		// Step 1 - increase size.height by spaceBelow
		
		CGFloat heightDiff = MIN(spaceBelow, left);
		
		originFrame.size.height += heightDiff;
		left -= heightDiff;
		
		DDLogVerbose(@"Step 1: originFrame: %@", NSStringFromCGRect(originFrame));
	}
	if (left > 0)
	{
		// Step 2 - decrease origin.y by spaceAbove &
		//          increase size.height by spaceAbove &
		//          update scroll position so it looks like nothing changed.
		
		CGFloat originDiff = MIN(spaceAbove, left);
		
		originFrame.size.height += originDiff;
		originFrame.origin.y -= originDiff;
		
		left -= originDiff;
		
		contentOffset.y -= originDiff;
		scrollView.contentOffset = contentOffset;
		
		DDLogVerbose(@"Step 2: originFrame: %@", NSStringFromCGRect(originFrame));
	}
	if (left > 0)
	{
		// Step 3 - increase height by whatever is left
		
		originFrame.size.height += left;
		
		DDLogVerbose(@"Step 3: originFrame: %@", NSStringFromCGRect(originFrame));
	}
	
	// Change scrollView frame to match its current scroll position,
	// but have its height the proper height.
	
	scrollView.frame = originFrame;
	
	// Update contentInsets.
	//
	// On iOS7, the scrollView.contentInset.top is automatically set to the height of the statusBar + navBar.
	// We need to ensure the top value stays the same.
	
	UIEdgeInsets insets = scrollView.contentInset;
	insets.bottom = 0;
	
	scrollView.contentInset = insets;
	scrollView.scrollIndicatorInsets = insets;
	
	// And animate the frame back into position.
	
	DDLogVerbose(@"scrollView: %@ -> %@", NSStringFromCGRect(originFrame), NSStringFromCGRect(finishFrame));
	
	void (^animationBlock)(void) = ^{
		
		scrollView.frame = finishFrame;
	};
	
	[UIView animateWithDuration:animationDuration
	                      delay:0.0
	                    options:animationOptions
	                 animations:animationBlock
	                 completion:NULL];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UIScrollView
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)scrollViewDidEndDecelerating:(UIScrollView *)sender
{
	if (resetContentInset)
	{
		UIEdgeInsets insets = scrollView.contentInset;
		insets.bottom = 0;
		
		scrollView.contentInset = insets;
		scrollView.scrollIndicatorInsets = insets;
		
		resetContentInset = NO;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Textfield customization methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range
                                                       replacementString:(NSString *)string
{
    BOOL result = YES;
   
    if (textField == deviceTextField)
    {

        for (int i = 0; i < [string length]; i++) {
            unichar c = [string characterAtIndex:i];
            if (! [charsForDeviceName characterIsMember:c] ) {
                return NO;
            }
        }
    }
    else if (textField == passwordTextField)
    {
        
        for (int i = 0; i < [string length]; i++) {
            unichar c = [string characterAtIndex:i];
            if (! [charsForPassword characterIsMember:c] ) {
                return NO;
            }
        }
    }
    else
    {
        for (int i = 0; i < [string length]; i++) {
            unichar c = [string characterAtIndex:i];
            if (![charsForUserName characterIsMember:c]) {
              return NO;
            }
        }
    }
    
  
    if(textField == usernameTextField)
    {
        
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
            result = NO;
        }
    }

    NSString *newString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    BOOL enableActivate = NO;
    
    BOOL hasUserName =  NO;
    
    
    if(textField == usernameTextField)
    {
        enableActivate = (passwordTextField.text.length > 0)
		              && (deviceTextField.text.length   > 0)
		              && (newString.length              > 0);
    }
    else if(textField == passwordTextField)
    {
        hasUserName = existingUserID || usernameTextField.text.length > 0;
        
		enableActivate = (hasUserName)
		              && (deviceTextField.text.length   > 0)
		              && (newString.length              > 0);
        
        
    }
    else if(textField == deviceTextField)
    {
        hasUserName = existingUserID || usernameTextField.text.length > 0;
        
		enableActivate = (hasUserName)
		              && (passwordTextField.text.length > 0)
		              && (newString.length              > 0);
	}
	else
	{
        hasUserName = existingUserID || usernameTextField.text.length > 0;
        
		enableActivate = (hasUserName)
		              && (passwordTextField.text.length > 0)
		              && (deviceTextField.text.length   > 0);
	}

    [activateButton setEnabled:enableActivate];
	
    return result;
}


- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
#pragma unused(textField)
    
    return (NO);
}

#pragma mark Actions

- (void)handleActionBarDone
{
    if ([_delegate respondsToSelector:@selector(dismissAddAccounts)])
    {
        [_delegate dismissAddAccounts];
		[AppAnalytics recordEvent:@"Activation - Dismiss" count:1];

    }
}

- (void)stopActivityIndicator
{
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
	usernameTextField.enabled = YES;
	passwordTextField.enabled = YES;
	deviceTextField.enabled   = YES;
	activateButton.enabled    = YES;
}

- (void)startActivityIndicator
{
	HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
	HUD.delegate = self;
	HUD.mode = MBProgressHUDModeIndeterminate;
	HUD.labelText = NSLS_COMMON_ACTIVATING;
	
	usernameTextField.enabled = NO;
	passwordTextField.enabled = NO;
	deviceTextField.enabled   = NO;
	activateButton.enabled    = NO;

//	[usernameTextField resignFirstResponder];
}

- (IBAction)networkAction:(UIButton *)networkButton
{
	NSString *title = NSLocalizedString(@"Select network to provision with", @"");
	
	[OHActionSheet showSheetInView:self.view
	                         title:title
	             cancelButtonTitle:NSLS_COMMON_CANCEL
	        destructiveButtonTitle:nil
	             otherButtonTitles:[networkChoices allValues]
	                    completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
	{
		NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
		
		NSArray *items = [networkChoices allKeysForObject:choice];
		if (items.count)
		{
			selectedNetwork = [items firstObject];
			[self updateNetworkButton];
		}
	}];
}

- (IBAction)reactivateAction:(UIButton *)activateButton
{
	if ([usernameTextField isFirstResponder])
		[usernameTextField resignFirstResponder];
	
	if ([passwordTextField isFirstResponder])
		[passwordTextField resignFirstResponder];
	
	if ([deviceTextField isFirstResponder])
		[deviceTextField resignFirstResponder];
  	
    
    [self activateUserName: usernameTextField.placeholder
              withPassword: passwordTextField.text
                deviceName: deviceTextField.text
                  deviceID: uuidString
                 networkID: selectedNetwork
            isExistingUser: YES];
    
}


- (IBAction)activateAction:(UIButton *)activateButton
{
	if ([usernameTextField isFirstResponder])
		[usernameTextField resignFirstResponder];
	
	if ([passwordTextField isFirstResponder])
		[passwordTextField resignFirstResponder];
	
	if ([deviceTextField isFirstResponder])
		[deviceTextField resignFirstResponder];
  	
    
    uuidString = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
 	
	if (usernameTextField.text.length > 0 && passwordTextField.text.length > 0)
	{
        
        if([STDatabaseManager isUserProvisioned:usernameTextField.text networkID:selectedNetwork])
        {
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"User already activated", @"User already activated")
                                        message: [NSString stringWithFormat:
                                                   NSLocalizedString(@"The username %@ has already been activated on this device", @"User already activated"), usernameTextField.text]
                                       delegate:nil
                              cancelButtonTitle:NSLS_COMMON_OK
                              otherButtonTitles:nil] show];
  
        }
        else
        {
            
            [self activateUserName: usernameTextField.text
                      withPassword: passwordTextField.text
                        deviceName: deviceTextField.text
                          deviceID: uuidString
                         networkID: selectedNetwork
                    isExistingUser: NO];
            
        };  // end if(isUserProvisioned)
        
	} // end if (usernameTextField.text.length > 0 && passwordTextField.text.length > 0)
}

-(void) activateUserName:(NSString*)userName
            withPassword:(NSString*)password
              deviceName:(NSString*)deviceName
                deviceID:(NSString*)deviceID
               networkID:(NSString*)networkID
          isExistingUser:(BOOL) isExistingUser
{
    
    [self startActivityIndicator];
    
    [[SCAccountsWebAPIManager sharedInstance] provisionUser: userName
                                               withPassword: password
                                                 deviceName: deviceName
                                                   deviceID: deviceID
                                                  networkID: networkID
                                                    appName: @"silent_text"
                                                deviceClass: @"ios"
                                            completionBlock:^(NSError *error, NSDictionary *infoDict)
     {
         if (error)
         {
             [self stopActivityIndicator];
             
             [[[UIAlertView alloc] initWithTitle:NSLS_COMMON_PROVISION_ERROR
                                         message: error.localizedDescription
                                        delegate:nil
                               cancelButtonTitle:NSLS_COMMON_OK
                               otherButtonTitles:nil] show];
			 NSDictionary * dict = @{@"Error" : error.localizedDescription,
									 @"Error #" : @(error.code),
									 };
			 [AppAnalytics recordEvent:@"Activation - Error" segmentation:dict count:1];
         }
         else
         {
             NSString *apiKeyString = [infoDict valueForKey:@"api_key"];
             
             if (apiKeyString == nil)
             {
                 DDLogError(@"SCAccountsWebAPIManager provisionUser returned non-errro, but missing api_key !");
                 return;
             }
             
             [[STUserManager sharedInstance] activateDevice: deviceID
                                                     apiKey: apiKeyString
                                                  networkID: networkID
                                            completionBlock:^(NSError *error, NSString *newUUID)
              {
                  [self stopActivityIndicator];
                  
                  if (error)
                  {
                      UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLS_COMMON_PROVISION_ERROR
                                                                          message:error.localizedDescription
                                                                         delegate:nil
                                                                cancelButtonTitle:NSLS_COMMON_OK
                                                                otherButtonTitles:nil];
                      [alertView show];
					  NSDictionary * dict = @{@"Error" : error.localizedDescription,
											  @"Error #" : @(error.code),
											  };
					  [AppAnalytics recordEvent:@"Activation - Error" segmentation:dict count:1];

                  }
                  else
                  {
                      [STPreferences setSelectedUserId:newUUID];
                      
                      if (STAppDelegate.revealController.frontViewController != STAppDelegate.mainViewController) {
                          [STAppDelegate.revealController setFrontViewController:STAppDelegate.mainViewController
                                                                        animated:YES];
                      }
                      else {
                          if ([_delegate respondsToSelector:@selector(dismissAddAccounts)])
                          {
                              [_delegate dismissAddAccounts];
                          }
                          
                      }
                      
                      
                      if(!isExistingUser)
                      {
                          NSString *title  = NSLocalizedString(@"Welcome to Silent Text", @"welcome message title");
                          NSString *detail = NSLocalizedString(@"start texting!", @"welcome message detail");
						  [AppAnalytics recordEvent:@"Activation - Success - New User" count:1];

                          [STAppDelegate showDropdownWithTitle:title
                                                        detail:detail
                                                         image:nil
                                               backgroundImage:nil
                                                     hideAfter:4.0];
   
                      }
					  else {
						  [AppAnalytics recordEvent:@"Activation - Success - Existing User" count:1];
					  }
                }
                  
              }]; // end STUserManager completionBlock
             
         } // end else if (!error)
         
     }]; // end SCAccountsWebAPIManager completionBlock
    
}

- (IBAction)showPasswordAction:(UISwitch *)spSwitch
{
	BOOL wasFirstResponder;
	if ((wasFirstResponder = [passwordTextField isFirstResponder])) {
		[passwordTextField resignFirstResponder];
	}
	// "show password" toggle, the only line that is really neccessary in this method.  All other lines in this method are to work around a bug in iOS7, iOS7.1 that puts a space after the text when not secure
	passwordTextField.secureTextEntry = !spSwitch.on;
	if (wasFirstResponder) {
		[passwordTextField becomeFirstResponder];
	}
}
- (void) eyeballPokeAction:(id) sender
{
	UIButton *button = (UIButton *) sender;
	button.selected = !button.selected;
	BOOL wasFirstResponder;
	if ((wasFirstResponder = [passwordTextField isFirstResponder])) {
		[passwordTextField resignFirstResponder];
	}
	// "show password" toggle, the only line that is really neccessary in this method.  All other lines in this method are to work around a bug in iOS7, iOS7.1 that puts a space after the text when not secure
	passwordTextField.secureTextEntry = !button.selected;
	if (wasFirstResponder) {
		[passwordTextField becomeFirstResponder];
	}
	
}

#pragma mark MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud {
	// Remove HUD from screen when the HUD was hidded
	[HUD removeFromSuperview];
	HUD = nil;
}

@end
