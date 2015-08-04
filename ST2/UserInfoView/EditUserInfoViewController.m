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
#import "EditUserInfoViewController.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "SilentTextStrings.h"
#import "AddressBookManager.h"
#import "OHActionSheet.h"
#import "OHAlertView.h"
#import "UIImage+Thumbnail.h"
#import "XMPPJID.h"
#import "MoveAndScaleImageViewController.h"
#import "STImage.h"
#import "STUser.h"
#import "SCAccountsWebAPIManager.h"
#import "STLogging.h"
#import "AppTheme.h"
#import "AvatarManager.h"

// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG && eric_turner
  static const int ddLogLevel = LOG_LEVEL_WARN | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif
static const CGFloat kAvatarDiameter =  50.   ;


@implementation EditUserInfoViewController
{
	UIScrollView *scrollView;
	BOOL resetContentInset;
	
	YapDatabaseConnection *dbConnection;
	STUser *user;
	id userImageOverride;
	BOOL isNewUser;
    AppTheme *theme;

	UIImagePickerController *imagePicker;
	UIPopoverController *popoverController;
	MoveAndScaleImageViewController *moveAndScaleImageViewController;
}

@synthesize delegate = delegate;

@synthesize userID = userID;
@synthesize isInPopover = isInPopover;

@synthesize containerView = containerView;

@synthesize userImageView = userImageView;
@synthesize editUserImageButton = editUserImageButton;

@synthesize firstNameField = firstNameField;
@synthesize lastNameField = lastNameField;
@synthesize organizationField = organizationField;

//@synthesize usernameLabel = usernameLabel;
@synthesize usernameField = usernameField;

@synthesize notesTextView = notesTextView;

@synthesize linkChain = linkChain;
@synthesize addressBookButton = addressBookButton;
@synthesize addressBookTip = addressBookTip;

@synthesize deleteButton = deleteButton;
@synthesize deleteButtonTip = deleteButtonTip;

- (id)initWithProperNib
{
	DDLogAutoTrace();
	
    if ((self = [self initWithNibName:@"EditUserInfoViewController" bundle:nil]))
	{
        dbConnection = STDatabaseManager.uiDatabaseConnection;
    }
	return self;
}

- (void)dealloc
{
	DDLogAutoTrace();
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad
{
	DDLogAutoTrace();
    [super viewDidLoad];
    
    theme = [AppTheme getThemeBySelectedKey];

	// Configure background
	
	self.view.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
	containerView.backgroundColor = self.view.backgroundColor;
	
	// Configure navBar
	
	self.navigationItem.leftBarButtonItem =
	    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
	                                                  target:self
	                                                  action:@selector(cancelButtonTapped:)];
	
	// The rightBarButtonItem is set during reloadView,
	// and depends on whether or not we're creating a new user.
	
	// Add text delegates
	
	[firstNameField addTarget:self
	                   action:@selector(textFieldChanged:)
	         forControlEvents:UIControlEventEditingChanged];
	
	[lastNameField addTarget:self
	                  action:@selector(textFieldChanged:)
	        forControlEvents:UIControlEventEditingChanged];
	
	[organizationField addTarget:self
	                      action:@selector(textFieldChanged:)
	            forControlEvents:UIControlEventEditingChanged];
	
	[usernameField addTarget:self
	                  action:@selector(textFieldChanged:)
	        forControlEvents:UIControlEventEditingChanged];
	
	notesTextView.delegate = self;
	
	// This viewController always needs to be wrapped in a scrollView.
	// On iPad, it may be displayed in a small popover.
	
	CGRect frame = self.view.bounds;
	
	scrollView = [[UIScrollView alloc] initWithFrame:frame];
	scrollView.delegate = self;
	scrollView.backgroundColor = self.view.backgroundColor;
	scrollView.showsHorizontalScrollIndicator = NO;
	scrollView.showsVerticalScrollIndicator = YES;
	scrollView.contentSize = containerView.frame.size;
	scrollView.indicatorStyle = UIScrollViewIndicatorStyleBlack;
	scrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
	
	if ([scrollView respondsToSelector:@selector(keyboardDismissMode)]) // iOS 7 API
		scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
	
	containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[containerView setTranslatesAutoresizingMaskIntoConstraints:YES];
	
	[scrollView addSubview:containerView];
	
	scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[scrollView setTranslatesAutoresizingMaskIntoConstraints:YES];
	
	[self.view addSubview:scrollView];
    
	// Register for normal notifications
	
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(keyboardWillShow:)
	                                             name:UIKeyboardWillShowNotification
	                                           object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(keyboardWillHide:)
	                                             name:UIKeyboardWillHideNotification
	                                           object:nil];
	
	
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(databaseConnectionWillUpdate:)
	                                             name:UIDatabaseConnectionWillUpdateNotification
	                                           object:STDatabaseManager];
	
    [[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(databaseConnectionDidUpdate:)
	                                             name:UIDatabaseConnectionDidUpdateNotification
	                                           object:STDatabaseManager];
}

- (void)viewWillAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillAppear:animated];
	
	// If we're not being displayed in a popover,
	// then bump the containerView down so its not hidden behind the main nav bar.
	
	if (!self.isInPopover)
	{
		DDLogVerbose(@"Updating topContraint - not in popover");
		
		CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
		
		CGFloat statusBarHeight = MIN(statusBarFrame.size.width, statusBarFrame.size.height);
		CGFloat navBarHeight = self.navigationController.navigationBar.frame.size.height;
		
		NSLayoutConstraint *constraint = [self topConstraintFor:containerView];
		constraint.constant = statusBarHeight + navBarHeight;
		
		[self.view setNeedsUpdateConstraints];
	}
	
	if (user == nil) {
		[self setUserID:nil];
	}
	else {
		[self reloadView];
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewDidAppear:animated];
	
	if (scrollView.frame.size.height < scrollView.contentSize.height)
	{
		// This doesn't work for some reason.
		//
		// [scrollView flashScrollIndicators];
		//
		// The flash animation is maybe getting cancelled by the popover animation.
		// It works if we delay it onto another runloop cycle.
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			[scrollView flashScrollIndicators];
		});
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View Preferences
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)prefersStatusBarHidden
{
	return NO;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Custom Setters
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setUserID:(NSString *)inUserID
{
	DDLogAutoTrace();
	
	if ([userID isEqualToString:inUserID])
		return;
	
	userID = inUserID;
	
	if (userID)
	{
		isNewUser = NO;
		
		[dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
			user = [user copy];
		}];
	}
	else
	{
		isNewUser = YES;
		
		user = [[STUser alloc] initWithUUID:[STAppDelegate generateUUID] networkID:nil jid:nil];
	}

	if (self.isViewLoaded){
		[self reloadView];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)databaseConnectionWillUpdate:(NSNotification *)notification
{
	// Just in case we need this method later
}

- (void)databaseConnectionDidUpdate:(NSNotification *)notification
{
	NSArray *notifications = [notification.userInfo objectForKey:kNotificationsKey];
	
	if ([dbConnection hasChangeForKey:userID inCollection:kSCCollection_STUsers inNotifications:notifications])
	{
		[self reloadView];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITextField Observer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This isn't technically a delegate method (not part of UITextFieldDelegate protocol).
 * We registered for notifications of UIControlEventEditingChanged (in viewDidLoad):
 * 
 * - firstNameField
 * - lastNameField
 * - organizationField
**/
- (void)textFieldChanged:(id)sender
{
	DDLogAutoTrace();
	
	NSString *text = [(UITextField *)sender text];
	
	if (sender == firstNameField)
	{
		if (text.length == 0)
			user.sc_firstName = nil;
		else
			user.sc_firstName = text;
		
		[self updateTitle];
	}
	else if (sender == lastNameField)
	{
		if (text.length == 0)
			user.sc_lastName = nil;
		else
			user.sc_lastName = text;
		
		[self updateTitle];
	}
	else if (sender == organizationField)
	{
		if (text.length == 0)
			user.sc_organization = nil;
		else
			user.sc_organization = text;
		
		[self updateTitle];
	}
	else if (sender == usernameField)
	{
		XMPPJID *jid = [self userJID];
		if (jid == nil)
		{
			user = [user copyWithNewJID:nil networkID:nil];
		}
		else
		{
			// Allow the user to specify a domain.
			// We use this for adding contacts on test networks.
			NSString *networkID = [AppConstants networkIdForXMPPDomain:[jid domain]];
			
			user = [user copyWithNewJID:jid networkID:networkID];
		}
		
		[self updateTitle];
		[self updateRightBarButtonItem];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITextViewDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)textViewDidChange:(UITextView *)textView
{
	DDLogAutoTrace();
	
	if (textView != notesTextView) return;
	
	if (notesTextView.text.length == 0)
		user.sc_notes = nil;
	else
		user.sc_notes = notesTextView.text;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Display
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
	
	return nil;
}

- (void)updateRightBarButtonItem
{
	if (isNewUser)
	{
		if ([self userJID] == nil)
			self.navigationItem.rightBarButtonItem = nil;
		
		else
			self.navigationItem.rightBarButtonItem =
			  [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
			                                                target:self
			                                                action:@selector(saveButtonTapped:)];
	}
	else
	{
		self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
													  target:self
													  action:@selector(doneButtonTapped:)];
	}
}

- (void)updateTitle
{
	NSString *displayName = [user displayName];
	if ([displayName length] == 0 && isNewUser)
		self.title = NSLocalizedString(@"New Contact", @"View title when creating a new contact");
	else
		self.title = displayName;
}

- (NSAttributedString *)usernameFieldPlaceholder
{
	NSString *p1 = NSLocalizedString(@"username", nil);
	NSString *p2 = NSLocalizedString(@"(required)", nil);
	
	NSString *str = [NSString stringWithFormat:@"%@ %@", p1, p2];
	
	UIColor *grayColor = [UIColor grayColor];
	UIColor *redColor = [UIColor colorWithRed:(255.f/255.f) green:(16.f/255.f) blue:(64.f/255.f) alpha:1.0];
	
	NSDictionary *p1Attr = @{ NSForegroundColorAttributeName: grayColor };
	NSDictionary *p2Attr = @{ NSForegroundColorAttributeName: redColor };
	
	NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:str];
	
	NSRange p1Range = NSMakeRange(0, [p1 length] + 1);
	NSRange p2Range = NSMakeRange(p1Range.length, [p2 length]);
	
	[attrStr setAttributes:p1Attr range:p1Range];
	[attrStr setAttributes:p2Attr range:p2Range];
	
	return attrStr;
}

- (XMPPJID *)userJID
{
	NSString *jidStr = usernameField.text;
	
	if (jidStr.length == 0) return nil;
	
	NSRange range = [jidStr rangeOfString:@"@"];
	if (range.location == NSNotFound)
		jidStr = [jidStr stringByAppendingString:@"@silentcircle.com"];
	
	XMPPJID *jid = [XMPPJID jidWithString:jidStr];
	
	if (jid == nil) return nil;
	
	if ([jid resource] != nil) // resources are not allowed
		return nil;
	else
		return [jid bareJID];
}

- (void)reloadView
{
	DDLogAutoTrace();
	
    UIColor* ringColor = theme.appTintColor;
    
	[self updateRightBarButtonItem];
	[self updateTitle];
    
	if (user.sc_firstName.length)
		firstNameField.text = user.sc_firstName;
	else
		firstNameField.text = nil;
	
	if (user.sc_lastName.length)
		lastNameField.text = user.sc_lastName;
	else
		lastNameField.text = nil;
	
	if (user.sc_organization.length)
		organizationField.text = user.sc_organization;
	else
		organizationField.text = nil;
    
	firstNameField.enabled = YES;
	lastNameField.enabled = YES;
	organizationField.enabled = YES;
	
    firstNameField.placeholder = NSLocalizedString(@"First Name", @"First Name");
    lastNameField.placeholder = NSLocalizedString(@"Last Name", @"Last Name");
    organizationField.placeholder = NSLocalizedString(@"Organization", @"Organization");
	
	if (user.abRecordID != kABRecordInvalidID)
	{
		if (user.ab_firstName.length > 0)
			firstNameField.placeholder = user.ab_firstName;
		
		if (user.ab_lastName.length > 0)
			lastNameField.placeholder = user.ab_lastName;
		
		if (user.ab_organization.length > 0)
			organizationField.placeholder = user.ab_organization;
    }
	else
	{
		if (user.web_firstName.length > 0)
			firstNameField.placeholder = user.web_firstName;
		
		if (user.web_lastName.length > 0)
			lastNameField.placeholder = user.web_lastName;
	}
    
 	
	if (userImageOverride)
	{
        UIImage *image = nil;

		if (userImageOverride == (id)[NSNull null])
		{
			image = [[AvatarManager sharedInstance] defaultAvatarwithDiameter:kAvatarDiameter];
		}
		else
		{
			image = (UIImage *)userImageOverride;
			image = [image scaledAvatarImageWithDiameter:kAvatarDiameter];
		}
        
		image = [image avatarImageWithDiameter:kAvatarDiameter usingColor:ringColor];
        userImageView.image = image;
   	}
	else if (user)
	{
        NSString *fetch_avatar_userId = nil;
        ABRecordID fetch_avatar_abRecordId = kABRecordInvalidID;
        
		if (user.uuid)
        {
            fetch_avatar_userId = user.uuid;
        }
        else
        {
			NSDictionary* abInfo = [[AddressBookManager sharedInstance] infoForSilentCircleJID:user.jid];
            
            if (abInfo)
                fetch_avatar_abRecordId = [[abInfo objectForKey:kABInfoKey_abRecordID] intValue];
            else
                fetch_avatar_abRecordId = kABRecordInvalidID;
        }
        
        if (fetch_avatar_userId)
        {
			UIImage *cachedAvatar = [[AvatarManager sharedInstance] cachedAvatarForUserId:fetch_avatar_userId
			                                                                 withDiameter:kAvatarDiameter
			                                                                        theme:theme
			                                                                        usage:kAvatarUsage_None];
			userImageView.image  = cachedAvatar;

            [[AvatarManager sharedInstance] fetchAvatarForUserId:fetch_avatar_userId
			                                        withDiameter:kAvatarDiameter
			                                          theme:theme
			                                          usage:kAvatarUsage_None
                                                 completionBlock:^(UIImage *avatar)
			{
				if (!userImageOverride)
					userImageView.image = avatar;
			}];
		}
		else if (fetch_avatar_abRecordId != kABRecordInvalidID)
		{
			UIImage *cachedAvatar = [[AvatarManager sharedInstance] cachedAvatarForABRecordID:fetch_avatar_abRecordId
			                                                                     withDiameter:kAvatarDiameter
			                                                                            theme:theme
			                                                                            usage:kAvatarUsage_None];
			userImageView.image  = cachedAvatar;
			
			[[AvatarManager sharedInstance] fetchAvatarForABRecordID:fetch_avatar_abRecordId
			                                            withDiameter:kAvatarDiameter
			                                                   theme:theme
			                                                   usage:kAvatarUsage_None
			                                         completionBlock:^(UIImage *avatar)
			{
				if (!userImageOverride)
					userImageView.image = avatar;
			}];
		}
    }
    else
    {
        // edge case, remote user doesnt have userrecord in DB, (probably deleted)
        
        UIImage *avatar =  [[AvatarManager sharedInstance] defaultAvatarwithDiameter:kAvatarDiameter];
        avatar = [avatar avatarImageWithDiameter:kAvatarDiameter usingColor:ringColor];
        
        userImageView.image = avatar;
    }
   	
	XMPPJID *jid = user.jid;
	
	if (jid)
	{
		if ([jid.domain isEqualToString:@"silentcircle.com"])
			usernameField.text = jid.user;
		else
			usernameField.text = [user.jid bare];
		
		[usernameField setEnabled:NO];
	}
	else
	{
		usernameField.text = nil;
		[usernameField setAttributedPlaceholder:[self usernameFieldPlaceholder]];
		
		[usernameField setEnabled:YES];
	}
	
	notesTextView.text = user.notes;
    
    NSString *buttonTitle= NULL;
    NSString *buttonHint= NULL;
    BOOL isEnabled = NO;
    
    if (user.abRecordID == kABRecordInvalidID)
    {
        buttonTitle = NSLocalizedString(@"Link with Contacts Book", @"Button text");
        
        buttonHint = NSLocalizedString(
		  @"Linking allows Silent Text to import information such as name and photo from the phone Contacts book."
		  @" The phone Contacts book is never modified.",
		  @"Link with Contacts Book button hint");
		
 		linkChain.hidden = YES;
        isEnabled = YES;
    }
    else
    {
		if (user.isAutomaticallyLinkedToAB)
        {
            buttonTitle = NSLocalizedString(@"Found In Contacts Book", @"Found In Contacts Book");
            buttonHint = nil;
            isEnabled = NO;
           
            linkChain.hidden = NO;
			isEnabled = NO;
        }
        else
        {
			buttonTitle = NSLocalizedString(@"Unlink from Contacts Book", @"Unlink from Contacts Book");
			
			buttonHint = NSLocalizedString(
			  @"This contact is linked with an entry in the phone Contacts book and will remain synchronized with it."
			  @" The phone Contacts book is never modified.",
			  @"Unlink from Contacts Book button hint");
			
			linkChain.hidden = NO;
			isEnabled = YES;
        }
    }
    
    // iOS 7 wants to automatically animate the UIButton title change for some reason
    [UIView setAnimationsEnabled:NO];
    {
		[addressBookButton setTitle:buttonTitle forState:UIControlStateNormal];
		addressBookTip.text = buttonHint;
	}
    [UIView setAnimationsEnabled:YES];
	
	if (isNewUser || !user.isRemote)
	{
		deleteButton.hidden = YES;
		deleteButtonTip.hidden = YES;
	}
	else
	{
		deleteButton.hidden = NO;
		deleteButtonTip.hidden = NO;
	}
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
	
	resetContentInset = NO;
	
	if (notesTextView.isFirstResponder)
	{
		[scrollView scrollRectToVisible:notesTextView.frame animated:YES];
	}
	else
	{
		dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(animationDuration * NSEC_PER_SEC));
		dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
			
			[scrollView flashScrollIndicators];
		});
	}
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
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is public.
**/
- (void)cancelChanges
{
	DDLogAutoTrace();
	
	if ([delegate respondsToSelector:@selector(editUserInfoViewControllerNeedsDismiss:)])
		[delegate editUserInfoViewControllerNeedsDismiss:self];
}

/**
 * This method is public.
**/
- (void)saveChanges
{
	DDLogAutoTrace();
	
	if ([firstNameField isFirstResponder])
		[firstNameField resignFirstResponder];
		
	if ([lastNameField isFirstResponder])
		[lastNameField resignFirstResponder];
	
	if ([organizationField isFirstResponder])
		[organizationField resignFirstResponder];
	
	if ([usernameField isFirstResponder])
		[usernameField resignFirstResponder];
	
	if ([notesTextView isFirstResponder])
		[notesTextView resignFirstResponder];
	
	if (userID)
	{
		// Save changes to existing user
		[self saveChangesContinue];
	}
	else
	{
		// We're going to be creating a new user.
		// So make sure the userJID doesn't already exist in the database.
		
		__block STUser *existingUser = nil;
		[dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			existingUser = [STDatabaseManager findUserWithJID:user.jid transaction:transaction];
		}];
		
		if (existingUser)
		{
			NSString *title = NSLocalizedString(@"Duplicate Contact", @"Alert view title");
			
			NSString *frmt = NSLocalizedString(@"There is already a contact with the username \"%@\".",
			                                   @"Alert view message");
			NSString *message = [NSString stringWithFormat:frmt, usernameField.text];
			
			NSString *okButtonTitle = NSLocalizedString(@"View Contact", @"Alert view button");
			
			[OHAlertView showAlertWithTitle:title
									message:message
							   cancelButton:NSLS_COMMON_CANCEL
								   okButton:okButtonTitle
							  buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex)
			{
				if (buttonIndex != alert.cancelButtonIndex)
				{
					if ([delegate respondsToSelector:@selector(editUserInfoViewController:needsShowUserID:)])
						[delegate editUserInfoViewController:self needsShowUserID:existingUser.uuid];
				}
			}];
			
			return;
		}
        else
        {
			// do userID verfication
			
			// Todo:
			// - What if this lookup is slow? We need an activity spinner.
			// - What if the lookup fails because there's no network? We need an alternative.

			[[SCAccountsWebAPIManager sharedInstance] getUserInfo:user.jid
			                                         forLocalUser:STDatabaseManager.currentUser
			                                      completionBlock:^(NSError *error, NSDictionary *infoDict)
			{
				if (!error && infoDict)
				{
					[self saveChangesContinue];
				}
				else
				{
					NSString *title = NSLocalizedString(@"No User Found", @"No User Found");
					
					NSString *msgFrmt = NSLocalizedString(@"There is no user subscribed with the user name \"%@\".",
					                                      @"Alert view message");
					
					NSString *msg = [NSString stringWithFormat:msgFrmt, usernameField.text];
					
					[OHAlertView showAlertWithTitle:title
					                        message:msg
					                   cancelButton:NULL
					                       okButton:NSLS_COMMON_OK
					                  buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex)
					{
						// Nothing to do here
					}];
				}
			}];
			
		}
	
	}
}

- (void)saveChangesContinue
{
    // The userImageOverride is used to change the user photo.
	// It's either NSNull or a UIImage.
	
    __block BOOL didDeleteUserImage = NO;
    
	UIImage *newUserImage = nil;
	if (userImageOverride && (userImageOverride != (id)[NSNull null]))
	{
		newUserImage = (UIImage *)userImageOverride;
	}
	
	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STUser *updatedUser = nil;
		
		if (userID)
		{
			// Saving changes to an existing user
			
			updatedUser = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
			updatedUser = [updatedUser copy];
			
			updatedUser.sc_firstName = user.sc_firstName;
			updatedUser.sc_lastName = user.sc_lastName;
			updatedUser.sc_organization = user.sc_organization;
			updatedUser.sc_notes = user.sc_notes;
			updatedUser.lastUpdated = [NSDate date];
			
			updatedUser.abRecordID = user.abRecordID;
			updatedUser.isAutomaticallyLinkedToAB = user.isAutomaticallyLinkedToAB;
			
			updatedUser.ab_firstName = user.ab_firstName;
			updatedUser.ab_lastName = user.ab_lastName;
			updatedUser.ab_compositeName = user.ab_compositeName;
			updatedUser.ab_organization = user.ab_organization;
			updatedUser.ab_notes = user.ab_notes;
		}
		else
		{
			updatedUser = [user copy];
		}
		
		if (userImageOverride)
		{
			if (newUserImage == nil)
			{
				// We deleted the avatar that the user selected, so we have to force the userview to reload
				// an avatar from either the addressbook or the web.

				[updatedUser setAvatarFileName:nil avatarSource:kAvatarSource_None];
				
				// What? Hey, why is this being cleared ?
				updatedUser.web_avatarURL = nil;
				
				didDeleteUserImage = YES;
  			}
			else
			{
				// Saving a big photo to disk is kinda slow.
				// So we're going to do it in a second pass.
				// That way the UI updates instantly, and the disk IO stuff can be slow.
			}
		}
		
		[transaction setObject:updatedUser forKey:updatedUser.uuid inCollection:kSCCollection_STUsers];
        
	} completionBlock:^{
        
		if (userID == nil)
		{
			if ([delegate respondsToSelector:@selector(editUserInfoViewController:didCreateNewUserID:)])
				[delegate editUserInfoViewController:self didCreateNewUserID:user.uuid];
		}
		
//        if (newUserImage)
//        {
//            if ([delegate respondsToSelector:@selector(editUserInfoViewController:willSaveUserImage:)])
//                [delegate editUserInfoViewController:self willSaveUserImage:newUserImage];
//        }
        
        if ([delegate respondsToSelector:@selector(editUserInfoViewControllerNeedsDismiss:)])
			[delegate editUserInfoViewControllerNeedsDismiss:self];

        if(didDeleteUserImage && [delegate respondsToSelector:@selector(editUserInfoViewControllerDidDeleteUserImage:)])
                [delegate editUserInfoViewControllerDidDeleteUserImage:self];

    }];
	
	if (newUserImage)
	{
		NSString *theUserID = userID ? userID : user.uuid;
		
        if ([delegate respondsToSelector:@selector(editUserInfoViewController:willSaveUserImage:)])
            [delegate editUserInfoViewController:self willSaveUserImage:newUserImage];

		[[AvatarManager sharedInstance] asyncSetImage:newUserImage
                                         avatarSource:kAvatarSource_SilentContacts 
		                                    forUserID:theUserID
		                              completionBlock:^
		{
			if ([delegate respondsToSelector:@selector(editUserInfoViewController:didSaveUserImage:)])
				[delegate editUserInfoViewController:self didSaveUserImage:newUserImage];
		}];
	}
}

- (void)cancelButtonTapped:(id)sender
{
	DDLogAutoTrace();
	[self cancelChanges];
}

- (void)doneButtonTapped:(id)sender
{
	DDLogAutoTrace();
	[self saveChanges];
}

- (void)saveButtonTapped:(id)sender
{
	DDLogAutoTrace();
	[self saveChanges];
}

/* ET 09/11/14 UPDATED with refactored NewEditUserInfoVC code to fix iOS 8 actionSheet popover issue */
- (IBAction)editUserImage:(id)sender
{
    DDLogAutoTrace();
    
    __block STUser *updatedUser = nil;
    [dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        updatedUser = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
    }];
    
    BOOL hasExistingImage = NO;
    if (userImageOverride)
    {
        if (userImageOverride == (id)[NSNull null])
            hasExistingImage = NO;
        else
            hasExistingImage = YES;
    }
    else if (user)
    {
        // only allow delete of SC contact images here.
        hasExistingImage = [[AvatarManager sharedInstance] hasImageForUser:updatedUser];
        if (hasExistingImage)
        {
            if (user.avatarSource < kAvatarSource_SilentContacts)
                hasExistingImage = NO;
        }
    }
    
    BOOL hasCameraAvailable = // May not be available if camera is in use by another app (e.g. FaceTime)
    [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    
    NSString *deletePhotoTitle = NSLocalizedString(@"Delete Photo", @"Edit user image option");
    NSString *takePhotoTitle   = NSLocalizedString(@"Take Photo",   @"Edit user image option");
    NSString *choosePhotoTitle = NSLocalizedString(@"Choose Photo", @"Edit user image option");
    
    NSInteger deletePhotoIndex = 0; NSInteger takePhotoIndex = 0; NSInteger choosePhotoIndex = 0;
    NSArray *buttonTitles;
    
    if (hasCameraAvailable)
    {
        buttonTitles = @[takePhotoTitle, choosePhotoTitle];
        if (hasExistingImage)
        {
            deletePhotoIndex = 0;
            takePhotoIndex   = 1;
            choosePhotoIndex = 2;
        }
        else
        {
            takePhotoIndex   = 0;
            choosePhotoIndex = 1;
        }
    }
    else
    {
        buttonTitles = @[choosePhotoTitle];
        if (hasExistingImage)
        {
            takePhotoIndex   = NSIntegerMax;
            deletePhotoIndex = 0;
            choosePhotoIndex = 1;
        }
        else
        {
            takePhotoIndex   = NSIntegerMax;
            choosePhotoIndex = 0;
        }
    }
    
    [OHActionSheet showFromVC:self
                       inView:self.view 
                        title:nil 
            cancelButtonTitle:NSLS_COMMON_CANCEL 
       destructiveButtonTitle:(hasExistingImage) ? deletePhotoTitle : nil
            otherButtonTitles:buttonTitles
                   completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                       if (buttonIndex == takePhotoIndex) {
                           [self takePhoto];
                       }
                       else if (buttonIndex == choosePhotoIndex) {
                           [self choosePhoto];
                       }
                       else if (buttonIndex == sheet.destructiveButtonIndex) {
                           [self deletePhoto];
                       }
                   }];
}
/* ET 09/11/14 ORIGINAL
 * (UPDATED above with NewEditUserInfoVC code to fix iOS 8 actionSheet popover issue
 *
- (IBAction)editUserImage:(id)sender
{
	DDLogAutoTrace();
	
	__block STUser *updatedUser = nil;
	[dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		updatedUser = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
	}];
	
	BOOL hasExistingImage = NO;
	if (userImageOverride)
	{
		if (userImageOverride == (id)[NSNull null])
			hasExistingImage = NO;
		else
			hasExistingImage = YES;
	}
	else if (user)
	{
        // only allow delete of SC contact images. here.
        hasExistingImage = [[AvatarManager sharedInstance] hasImageForUser:updatedUser];
       if(hasExistingImage)
       {
           if(user.avatarSource < kAvatarSource_SilentContacts)
               hasExistingImage = NO;
       }
        
	}
	
	BOOL hasCameraAvailable = // May not be available if camera is in use by another app (e.g. FaceTime)
	  [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
	
	NSString *takePhoto = NSLocalizedString(@"Take Photo", @"Edit user image option");
	NSString *choosePhoto = NSLocalizedString(@"Choose Photo", @"Edit user image option");
	NSString *deletePhoto = NSLocalizedString(@"Delete Photo", @"Edit user image option");
	
	NSInteger takePhotoIndex, choosePhotoIndex, deletePhotoIndex;
	NSArray *buttonTitles;
	
	if (hasExistingImage)
	{
		if (hasCameraAvailable)
		{
			buttonTitles = @[ takePhoto, choosePhoto, deletePhoto ];
			takePhotoIndex   = 0;
			choosePhotoIndex = 1;
			deletePhotoIndex = 2;
		}
		else
		{
			buttonTitles = @[ choosePhoto, deletePhoto ];
			takePhotoIndex   = -1;
			choosePhotoIndex =  0;
			deletePhotoIndex =  1;
		}
	}
	else
	{
		if (hasCameraAvailable)
		{
			buttonTitles = @[ takePhoto, choosePhoto ];
			takePhotoIndex   = 0;
			choosePhotoIndex = 1;
			deletePhotoIndex = -1;
		}
		else
		{
			buttonTitles = @[ choosePhoto ];
			takePhotoIndex   = -1;
			choosePhotoIndex = 0;
			deletePhotoIndex = -1;
		}
	}
	
	OHActionSheet *actionSheet =
	  [[OHActionSheet alloc] initWithTitle:nil
	                     cancelButtonTitle:NSLS_COMMON_CANCEL
	                destructiveButtonTitle:nil
	                     otherButtonTitles:buttonTitles
	                            completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
	{
		if (buttonIndex == takePhotoIndex) {
			[self takePhoto];
		}
		else if (buttonIndex == choosePhotoIndex) {
			[self choosePhoto];
		}
		else if (buttonIndex == deletePhotoIndex) {
			[self deletePhoto];
		}
	}];
	
	if (deletePhotoIndex >= 0)
		actionSheet.destructiveButtonIndex = deletePhotoIndex;
	
	[actionSheet showFromRect:editUserImageButton.frame
	                   inView:containerView
	                 animated:YES];
}
*/


- (IBAction)addressBookButtonTapped:(id)sender
{
	DDLogAutoTrace();
 	
	if (user.abRecordID == kABRecordInvalidID)
	{
		ABPeoplePickerNavigationController* picker = [[ABPeoplePickerNavigationController alloc] init];
		picker.peoplePickerDelegate = self;
		
	//	picker.modalPresentationStyle = UIModalPresentationCurrentContext;
	//	picker.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
		
		[self presentViewController:picker animated:YES completion:NULL];
	}
	else
	{
		user.abRecordID = kABRecordInvalidID;
		user.isAutomaticallyLinkedToAB = NO;
		
		user.ab_firstName     = nil;
		user.ab_lastName      = nil;
		user.ab_compositeName = nil;
		user.ab_organization  = nil;
		user.ab_notes         = nil;
		
		[self reloadView];
	}
}

- (IBAction)deleteButtonTapped:(id)sender
{
	DDLogAutoTrace();
	
	NSString *title = NSLocalizedString(@"Delete contact and all conversations with this contact?",
	                                    @"Delete contact warning");
	
    [OHActionSheet showFromRect:deleteButton.frame 
                       sourceVC:self
                         inView:containerView
                          title:title
              cancelButtonTitle:NSLS_COMMON_CANCEL
         destructiveButtonTitle:NSLocalizedString(@"Delete Contact", @"Delete Contact")
              otherButtonTitles:nil
                     completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                         
                         if (buttonIndex == sheet.destructiveButtonIndex)
                         {
                             if ([delegate respondsToSelector:@selector(editUserInfoViewController:willDeleteUserID:)])
                                 [delegate editUserInfoViewController:self willDeleteUserID:userID];
                             
                             [STDatabaseManager asyncDeleteRemoteUser:userID completionBlock:NULL];
                             
                             if ([delegate respondsToSelector:@selector(editUserInfoViewControllerNeedsDismiss:)])
                                 [delegate editUserInfoViewControllerNeedsDismiss:self];
                         }
                     }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Photos
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)takePhoto
{
	DDLogAutoTrace();
	
	if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
	{
		// Some other app stole the camera before the user tapped the button
		return;
	}
	
	imagePicker = [[UIImagePickerController alloc] init];
	[imagePicker setSourceType:UIImagePickerControllerSourceTypeCamera];
	[imagePicker setDelegate:self];
	
	if (self.isInPopover)
	{
		if ([delegate respondsToSelector:@selector(editUserInfoViewController:needsHidePopoverAnimated:)])
			[delegate editUserInfoViewController:self needsHidePopoverAnimated:YES];
	}
	
	UIViewController *frontController = STAppDelegate.revealController.frontViewController;
	[frontController presentViewController:imagePicker animated:YES completion:NULL];
}

- (void)choosePhoto
{
	DDLogAutoTrace();
	
	if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
	{
		return;
	}
	
	imagePicker = [[UIImagePickerController alloc] init];
	[imagePicker setSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
	[imagePicker setDelegate:self];
	
	if (AppConstants.isIPad)
	{
		// According to Apple's docs:
		//
		// > On iPad, the correct way to present an image picker depend on its source type,
		// > as summarized in this table:
		//
		// > Camera             : Use full screen
		// > Photo Library      : Must use a popover
		// > Saved Photos Album : Must use a popover
		
		if (self.isInPopover)
		{
			if ([delegate respondsToSelector:@selector(editUserInfoViewController:needsPushImagePicker:)])
				[delegate editUserInfoViewController:self needsPushImagePicker:imagePicker];
		}
		else
		{
			popoverController = [[UIPopoverController alloc] initWithContentViewController:imagePicker];
			popoverController.delegate = self;
		
			[popoverController presentPopoverFromRect:userImageView.frame
			                                   inView:containerView
			                 permittedArrowDirections:UIPopoverArrowDirectionLeft
			                                 animated:YES];
		}
	}
	else // if (AppConstants.isIPhone)
	{
		UIViewController *frontController = STAppDelegate.revealController.frontViewController;
		[frontController presentViewController:imagePicker animated:YES completion:NULL];
	}
}

- (void)deletePhoto
{
	DDLogAutoTrace();
	
	userImageOverride = [NSNull null];
	[self reloadView];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
	DDLogAutoTrace();
	
	if (imagePicker.sourceType == UIImagePickerControllerSourceTypeCamera)
	{
		// Take Photo
		
		[imagePicker dismissViewControllerAnimated:YES completion:nil];
		
		if (self.isInPopover)
		{
			if ([delegate respondsToSelector:@selector(editUserInfoViewController:needsShowPopoverAnimated:)])
				[delegate editUserInfoViewController:self needsShowPopoverAnimated:YES];
		}
	}
	else
	{
		// Choose Photo
		
		if (AppConstants.isIPad)
		{
			if (self.isInPopover)
			{
				if ([delegate respondsToSelector:@selector(editUserInfoViewController:needsPopImagePicker:)])
					[delegate editUserInfoViewController:self needsPopImagePicker:imagePicker];
			}
			else
			{
				[popoverController dismissPopoverAnimated:YES];
			}
		}
		else if (AppConstants.isIPhone)
		{
			[imagePicker dismissViewControllerAnimated:YES completion:nil];
		}
	}
	
	imagePicker = nil;
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
	DDLogAutoTrace();
	
	moveAndScaleImageViewController = [[MoveAndScaleImageViewController alloc] initWithMediaInfo:info];
	moveAndScaleImageViewController.delegate = self;
	
	if (imagePicker.sourceType == UIImagePickerControllerSourceTypeCamera)
	{
		[imagePicker pushViewController:moveAndScaleImageViewController animated:NO];
	}
	else
	{
		if (AppConstants.isIPad)
		{
			if (self.isInPopover)
			{
				if ([delegate respondsToSelector:@selector(editUserInfoViewController:needsPopImagePicker:)])
					[delegate editUserInfoViewController:self needsPopImagePicker:imagePicker];
				
				if ([delegate respondsToSelector:@selector(editUserInfoViewController:needsHidePopoverAnimated:)])
					[delegate editUserInfoViewController:self needsHidePopoverAnimated:YES];
			}
			else
			{
				[popoverController dismissPopoverAnimated:YES];
			}
			
			UIViewController *frontController = STAppDelegate.revealController.frontViewController;
			[frontController presentViewController:moveAndScaleImageViewController animated:YES completion:NULL];
		}
		else // if (AppConstants.isIPhone)
		{
			[imagePicker pushViewController:moveAndScaleImageViewController animated:YES];
		}
	}
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)aPopoverController
{
	popoverController = nil;
	imagePicker = nil;
}

- (void)moveAndScaleImageViewControllerDidCancel:(MoveAndScaleImageViewController *)sender
{
	DDLogAutoTrace();
	
	if (AppConstants.isIPad)
	{
		[moveAndScaleImageViewController dismissViewControllerAnimated:YES completion:^{
			
			if (self.isInPopover)
			{
				if ([delegate respondsToSelector:@selector(editUserInfoViewController:needsShowPopoverAnimated:)])
					[delegate editUserInfoViewController:self needsShowPopoverAnimated:YES];
			}
			else
			{
				// Nothing to do
			}
		}];
	}
	else // if (AppConstants.isIPhone)
	{
		// The moveAndScale controller is pushed atop the imagePicker (nav controller).
		// We want to pop just the moveAndScale controller,
		// and go back to the imagePicker.
		
		[imagePicker popViewControllerAnimated:YES];
		moveAndScaleImageViewController = nil;
	}
}

- (void)moveAndScaleImageViewController:(MoveAndScaleImageViewController *)sender didChooseImage:(UIImage *)image
{
	DDLogAutoTrace();
	
	// Dismiss all the views properly
	if (AppConstants.isIPad)
	{
		[moveAndScaleImageViewController dismissViewControllerAnimated:YES completion:^{
			
			if (self.isInPopover)
			{
				if ([delegate respondsToSelector:@selector(editUserInfoViewController:needsShowPopoverAnimated:)])
					[delegate editUserInfoViewController:self needsShowPopoverAnimated:YES];
			}
			else
			{
				// Nothing to do
			}
		}];
	}
	else // if (AppConstants.isIPhone)
	{
		// The moveAndScale controller is pushed atop the imagePicker (nav controller).
		// We want to pop the entire stack (moveAndScale controller + imagePicker).
		
		[imagePicker dismissViewControllerAnimated:YES completion:NULL];
		imagePicker = nil;
		moveAndScaleImageViewController = nil;
	}
	
	// And refresh the imageView
	userImageOverride = image;
	[self reloadView];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark ABPeoplePickerNavigationControllerDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Called after the user has pressed cancel
 * The delegate is responsible for dismissing the peoplePicker
**/
- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker
{
	DDLogAutoTrace();
	
    [self dismissViewControllerAnimated:YES completion:NULL];
}

/**
 * iOS 7 only
 *
 * Called after a person has been selected by the user.
 *
 * Return YES if you want the person to be displayed.
 * Return NO to do nothing (the delegate is responsible for dismissing the peoplePicker).
**/
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker
      shouldContinueAfterSelectingPerson:(ABRecordRef)person
{
	DDLogAutoTrace();
	
	[self peoplePickerNavigationController:peoplePicker didSelectPerson:person];
	return NO;
}

/**
 * iOS 8 only
 * 
 * Called after a person has been selected by the user.
**/
- (void)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker
                         didSelectPerson:(ABRecordRef)person
{
	DDLogAutoTrace();
	
	ABRecordID abRecordID = person ? ABRecordGetRecordID(person) : kABRecordInvalidID;
	
	user.abRecordID = abRecordID;
	user.isAutomaticallyLinkedToAB = NO;
	
	NSDictionary *info = [[AddressBookManager sharedInstance] infoForABRecordID:abRecordID];
	
	user.ab_firstName     = [info objectForKey:kABInfoKey_firstName];
	user.ab_lastName      = [info objectForKey:kABInfoKey_lastName];
	user.ab_compositeName = [info objectForKey:kABInfoKey_compositeName];
	user.ab_organization  = [info objectForKey:kABInfoKey_organization];
	user.ab_notes         = [info objectForKey:kABInfoKey_notes];
	
	[self reloadView];
	[self dismissViewControllerAnimated:YES completion:NULL];
}

@end
