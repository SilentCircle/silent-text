/*
Copyright (C) 2015, Silent Circle, LLC. All rights reserved.

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
//  NewEditUserVC.m
//  ST2
//
//  Created by Eric Turner on 8/19/14.
//

#import "EditUserInfoVC.h"
#import <AddressBookUI/AddressBookUI.h>
#import "AddressBookManager.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "AppTheme.h"
#import "AvatarManager.h"
#import "STUserManager.h"
#import "HelpDetailsVC.h"
#import "MessagesViewController.h"
#import "MoveAndScaleImageViewController.h"
#import "OHActionSheet.h"
#import "OHAlertView.h"
#import "SCWebAPIManager.h"
#import "SCTAvatarView.h"
#import "SCTHelpButton.h"
#import "SCTHelpManager.h"
#import "STDynamicHeightView.h"
#import "STImage.h"
#import "STLogging.h"
#import "STPreferences.h"
#import "STUser.h"
#import "STLocalUser.h"
#import "SilentTextStrings.h"
#import "XMPPJID.h"
// Categories
#import "NSString+SCUtilities.h"
#import "UIImage+maskColor.h"
#import "UIImage+Thumbnail.h"


// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG && eric_turner
static const int ddLogLevel = LOG_LEVEL_WARN; //LOG_LEVEL_WARN | LOG_FLAG_TRACE;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

static const CGFloat kAvatarDiameter = 60.0; // to match avatarView xib imageView size


@interface EditUserInfoVC () <UIScrollViewDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate,
                                    ABPeoplePickerNavigationControllerDelegate,
                                    UITextFieldDelegate,UITextViewDelegate,EditUserInfoDelegate,SCTAvatarViewDelegate>

{
// In AvatarView
    //ET 12/16/14 - moved from public superclass property ST-871
    UIImage *_avatarImage;
    IBOutlet UITextField *_firstNameField;
    IBOutlet UITextField *_lastNameField;
    IBOutlet UITextView  *_notesTextView;
    IBOutlet UITextField *_organizationField;
    IBOutlet UITextField *_usernameField;

// Link with Address Book Views
    IBOutlet UIView      *_linkAddressBookView;
    IBOutlet UILabel     *_lblAddressBook;
    IBOutlet UIImageView *_linkChain;
    IBOutlet UILabel     *_addressBookTip;

// Create Public Key Views
    IBOutlet UIView                  *_publicKeyView;
    IBOutlet UIButton                *_btnCreatePublicKey;
    IBOutlet UIActivityIndicatorView *_createPublicKeySpinner;
    IBOutlet UILabel                 *_lblCreatePublicKey;

// Delete Contact Views
    IBOutlet UIView   *_deleteContactView;
    IBOutlet UIButton *_btnDeleteContact;
    IBOutlet UILabel  *_deleteContactTip;

// Constraints
    IBOutlet NSLayoutConstraint *_publicKeyViewTopConstraint;
    CGFloat                      _publicKeyViewTopConstraintHeight;
    CGFloat                      _publicKeyViewHeight;
    IBOutlet NSLayoutConstraint *_deleteContactViewTopConstraint;
    CGFloat                      _deleteContactViewTopConstraintHeight;
    CGFloat                      _deleteContactViewHeight;
    IBOutlet NSLayoutConstraint *_lblAddressBookCenterXConstraint;
    CGFloat                      _lblAddressBookCenterX;

// Editing Image
    UIImage *_editSessionImage;
    BOOL     _userDeletedSessionImage;

// Flags
    BOOL _didRecreatePublicKey;
    BOOL _isNewUser;
    BOOL _resetContentInset;

}

@end


@implementation EditUserInfoVC


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Initializers
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


- (instancetype)initWithUser:(STUser *)aUser avatarImage:(UIImage *)avImg
{
    DDLogAutoTrace();
    
    self = [super initWithUser:aUser];
    // Store the image until the avatarView is loaded,
    // then, called from viewDidLoad, the updateAvatar method will set the avatar
    // with this image, if any, or with a default avatar placeholder image.
    _avatarImage = avImg;
    
    // nil user arg means initialized by ContactsVC for a new user
    if (nil == aUser)
    {
		NSString *uuid = [[NSUUID UUID] UUIDString];
		
        _isNewUser = YES;
        _user = [[STUser alloc] initWithUUID:uuid networkID:nil jid:nil];
    }

    self.loadAvatarViewFromNib = NO;

    // Register for normal notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    
    return self;
}

- (void)dealloc
{
    DDLogAutoTrace();
    self.navigationController.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - User Setter
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setUser:(STUser *)aUser
{
    _user = aUser;
    [self updateAllViews];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - View Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad
{
    DDLogAutoTrace();
    [super viewDidLoad];

    //10/14/14 always call updateAvatar to set image on first load
    [self updateAvatar];
    [self cacheInitialConstraintValues];
    [self initialViewConfiguration];
    [self updateAllViews];
}

- (void)viewWillAppear:(BOOL)animated
{
    DDLogAutoTrace();
    [super viewWillAppear:animated];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    DDLogAutoTrace();
    [super viewDidAppear:animated];
    
    if (self.scrollView.frame.size.height < self.scrollView.contentSize.height)
    {
        // This doesn't work for some reason.
        //
        // [scrollView flashScrollIndicators];
        //
        // The flash animation is maybe getting cancelled by the popover animation.
        // It works if we delay it onto another runloop cycle.
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self.scrollView flashScrollIndicators];
        });
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - View Preferences
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)prefersStatusBarHidden
{
    return NO;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Initial Views Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)initialViewConfiguration
{
    // Configure "local" backgroundColors (super sets shared views bgColor)
    UIColor *bgColor = self.view.backgroundColor;
    _linkAddressBookView.backgroundColor = bgColor;
    _publicKeyView.backgroundColor = bgColor;
    _deleteContactView.backgroundColor = bgColor;
    
    // Display/configure Help/Info button in avatarView
    [self.avatarView showInfoButtonForClass:[self class]];
//    [self.avatarView setAvatarImage:self.avatarImage];

    [self initialTextfieldConfiguration];
    [self updateCreatePublicKeyView];
    [self updateRightBarButtonItem];
    [self updateTitle];
}

// We only need to set the placeholder values once
- (void)initialTextfieldConfiguration
{
    // Add text delegates for EventEditingChange
    [_firstNameField addTarget:self
                        action:@selector(textFieldChanged:)
              forControlEvents:UIControlEventEditingChanged];
    
    [_lastNameField addTarget:self
                       action:@selector(textFieldChanged:)
             forControlEvents:UIControlEventEditingChanged];
    
    [_organizationField addTarget:self
                           action:@selector(textFieldChanged:)
                 forControlEvents:UIControlEventEditingChanged];
    
    [_usernameField addTarget:self
                       action:@selector(textFieldChanged:)
             forControlEvents:UIControlEventEditingChanged];
    
    _notesTextView.delegate = self;

    _firstNameField.placeholder = NSLocalizedString(@"First Name", @"First Name");
    _lastNameField.placeholder = NSLocalizedString(@"Last Name", @"Last Name");
    _organizationField.placeholder = NSLocalizedString(@"Organization", @"Organization");

    STUser *user = _user;
    if (_user.abRecordID != kABRecordInvalidID)
    {
        if ([user.ab_firstName isNotEmpty])
            _firstNameField.placeholder = user.ab_firstName;
        
        if ([user.ab_lastName isNotEmpty])
            _lastNameField.placeholder = user.ab_lastName;
        
        if ([user.ab_organization isNotEmpty])
            _organizationField.placeholder = user.ab_organization;
    }
    else
    {
        if ([user.web_firstName isNotEmpty])
            _firstNameField.placeholder = user.web_firstName;
        
        if ([user.web_lastName isNotEmpty])
            _lastNameField.placeholder = user.web_lastName;
    }
    
    _usernameField.attributedPlaceholder = [self usernameFieldPlaceholder];
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

- (void)cacheInitialConstraintValues
{
    DDLogAutoTrace();
    
    _publicKeyViewTopConstraintHeight = _publicKeyViewTopConstraint.constant;
    _publicKeyViewHeight = [self heightConstraintFor:_publicKeyView].constant;
    _deleteContactViewTopConstraintHeight = _deleteContactViewTopConstraint.constant;
    _deleteContactViewHeight = [self heightConstraintFor:_deleteContactView].constant;
    _lblAddressBookCenterX = _lblAddressBookCenterXConstraint.constant;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - View Updates
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Avatar updates are called elsewhere to update image, user, or both
- (void)updateAllViews
{
    [super updateAllViews];
    [self updateTitle];
    [self updateFirstNameView];
    [self updateLastNameView];
    [self updateOrganizationNameView];
    [self updateAvatar];
    [self updateUsernameView];
    [self updateNotesView];
    [self updateAddressBookLinkView];
    [self updateDeleteContactView];
    [self updateLayout];
}

- (void)updateTitle
{
    NSString *displayName = _user.displayName;
    if ([displayName length] == 0 && self.isNewUser)
        self.title = NSLocalizedString(@"New Contact", @"View title when creating a new contact");
    else
        self.title = displayName;
}

- (void)updateFirstNameView
{	
	if (_user.sc_firstName.length > 0)
		_firstNameField.text = _user.sc_firstName;
	else
		_firstNameField.text = nil;
	
	_firstNameField.placeholder = NSLocalizedString(@"First Name", @"First Name");
	
	if (_user.abRecordID != kABRecordInvalidID)
	{
		if (_user.ab_firstName.length > 0)
			_firstNameField.placeholder = _user.ab_firstName;
	}
	else
	{
		if (_user.web_firstName.length > 0)
			_firstNameField.placeholder = _user.web_firstName;
	}
}

- (void)updateLastNameView
{    
	if (_user.sc_lastName.length > 0)
		_lastNameField.text = _user.sc_lastName;
	else
		_lastNameField.text = nil;
	
	_lastNameField.placeholder = NSLocalizedString(@"Last Name", @"Last Name");
	
	if (_user.abRecordID != kABRecordInvalidID)
	{
		if (_user.ab_lastName.length > 0)
			_lastNameField.placeholder = _user.ab_lastName;
	}
	else
	{
		if (_user.web_lastName.length > 0)
			_lastNameField.placeholder = _user.web_lastName;
	}
}

- (void)updateOrganizationNameView
{
	if (_user.sc_organization.length > 0)
		_organizationField.text = _user.sc_organization;
	else
		_organizationField.text = nil;
	
	_organizationField.placeholder = NSLocalizedString(@"Organization", @"Organization");
	
	if (_user.abRecordID != kABRecordInvalidID)
	{
		if (_user.ab_organization.length > 0)
			_organizationField.placeholder = _user.ab_organization;
	}
}

- (void)updateUsernameView
{
    NSString *userText = nil;
    XMPPJID *jid = _user.jid;
    
    if (jid)
    {
        if ([jid.domain isEqualToString:@"silentcircle.com"])
            userText = jid.user;
        else
            userText = _user.jid.bare;
        
        [_usernameField setEnabled:NO];
    }
    else
    {
        userText = nil;
        [_usernameField setEnabled:YES];
    }
    
    _usernameField.text = userText;
}

- (void)updateNotesView
{
    _notesTextView.text = _user.notes;
}

- (void)updateAddressBookLinkView
{
    NSString *title = nil;
    NSString *hintText  = nil;
    BOOL isEnabled = NO;
    
    if (_user.abRecordID == kABRecordInvalidID)
    {
        title = NSLocalizedString(@"Link with Contacts Book", @"Button text");
        hintText = NSLocalizedString(@"Linking allows Silent Text to import information such as name and photo from"
                                     @" the phone Contacts book. The phone Contacts book is never modified.", 
                                     @"Link with Contacts Book button hint");
        
        _linkChain.hidden = YES;
        isEnabled = YES;
    }
    else
    {
        if (_user.isAutomaticallyLinkedToAB)
        {
            title = NSLocalizedString(@"Found In Contacts Book", @"Found In Contacts Book");
            hintText = nil;
            _linkChain.hidden = NO;
            isEnabled = NO;
        }
        else
        {
            title = NSLocalizedString(@"Unlink from Contacts Book", @"Unlink from Contacts Book");
            hintText = NSLocalizedString(@"This contact is linked with an entry in the phone Contacts book and will"
                                         @" remain synchronized with it. The phone Contacts book is never modified.", 
                                         @"Unlink from Contacts Book button hint");
            _linkChain.hidden = NO;
            isEnabled = YES;
        }
    }

    _lblAddressBook.text = title;
    _lblAddressBook.userInteractionEnabled = isEnabled;
    _linkChain.userInteractionEnabled = isEnabled;
    _addressBookTip.text = hintText;

}

- (void)updateDeleteContactView
{
    _deleteContactView.hidden = (_isNewUser || _user.isLocal);
}

- (void)updateCreatePublicKeyView
{
	BOOL isLocalActivatedUser = NO;
	if (_user.isLocal)
		isLocalActivatedUser = [(STLocalUser *)_user isActivated];
	
	if (isLocalActivatedUser)
        [self updateCreatePublicKeyButton];
    else
        [self hideCreatePublicKeyButton];    
}

- (BOOL)shouldShowPublicKeyView
{
	BOOL isLocalActivatedUser = NO;
	if (_user.isLocal)
		isLocalActivatedUser = [(STLocalUser *)_user isActivated];
	
	return isLocalActivatedUser;
}

- (void)updateLayout
{
    if (![self isViewLoaded])
        return;
    
    //------------------------------------------- Top view labels layout ---------------------------------------------//
    
    // Center lblAddressBook in its containing groupingView if the link imageView is hidden
    CGFloat lblABcenterX = (_linkChain.hidden) ? 0 : _lblAddressBookCenterX;
    _lblAddressBookCenterXConstraint.constant = lblABcenterX;
    
    // Create Public Key View
    BOOL publicKeyViewIsHidden = ![self shouldShowPublicKeyView];
    NSLayoutConstraint *pubKeyViewH = [self heightConstraintFor:_publicKeyView];
    _publicKeyViewTopConstraint.constant = (publicKeyViewIsHidden) ? 0 : _publicKeyViewTopConstraintHeight;
    pubKeyViewH.constant = (publicKeyViewIsHidden) ? 0 : _publicKeyViewHeight;

    
    // DeleteContact View
    BOOL deleteViewIsHidden = _deleteContactView.isHidden;
    NSLayoutConstraint *deleteContactViewH = [self heightConstraintFor:_deleteContactView];
    _deleteContactViewTopConstraint.constant = (deleteViewIsHidden) ? 0 : _deleteContactViewTopConstraintHeight;
    deleteContactViewH.constant = (deleteViewIsHidden) ? 0 : _deleteContactViewHeight;

    
    //----------------------------------------------------------------------------------------------------------------//
    //
    // Now resize the contentView with a height constraint somewhat taller than the containerView height. The 
    // autolayout system will reset the scrollView contentSize to accommodate the height, making the view scrollable 
    // regardless of the contentView's subviews layout. This will enable scroll-to-dismiss keyboard.
    //
    //----------------------------------------------------------------------------------------------------------------//
    DDLogCyan(@"self.viewFrame: %@",NSStringFromCGRect(self.view.frame));
    
    [self.contentView invalidateIntrinsicContentSize];
    [self.contentView layoutIfNeeded];
    
    CGFloat containerHeight = self.containerView.frame.size.height;    
    CGSize contentViewIntrinsicSize = [self.contentView intrinsicContentSize];
    
    CGFloat someExperimentalMargin = 64.0f;
    CGFloat minScrollableHeight = containerHeight + someExperimentalMargin;    
    CGFloat scrollableHeight = MAX(minScrollableHeight, contentViewIntrinsicSize.height);
    
    NSLayoutConstraint *contentViewH = [self heightConstraintFor:self.contentView];
    contentViewH.constant = scrollableHeight;
    
    [self.contentView setNeedsUpdateConstraints];
    [self.scrollView setNeedsUpdateConstraints];
    [self.containerView setNeedsUpdateConstraints];
    
    [self resetPopoverSizeIfNeeded];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - View Utilities
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)presentPicker:(UIViewController *)picker
{
//    if ([self.presentingController isKindOfClass:[UIPopoverController class]])
//    {
//        MessagesViewController *messagesVC = STAppDelegate.messagesViewController;
//        if ([messagesVC respondsToSelector:@selector(viewController:needsDismissPopoverAnimated:)])
//        {
//            [messagesVC viewController:self needsDismissPopoverAnimated:NO];
//        }
//        self.frontViewController = STAppDelegate.revealController.frontViewController;
//        [_frontViewController presentViewController:picker animated:YES completion:NULL];
//    }
//    else
//    {
        [self presentViewController:picker animated:YES completion:nil];
//    }

}

- (void)dismissPicker:(UIViewController *)picker
{
//    if ([self.presentingController isKindOfClass:[UIPopoverController class]])
//    {
//        [_frontViewController dismissViewControllerAnimated:YES completion:^{
//            // re-present popoverController
//            SEL selector = @selector(viewController:needsShowPopoverAnimated:);
//            if ([STAppDelegate.messagesViewController respondsToSelector:selector])
//                [STAppDelegate.messagesViewController viewController:self needsShowPopoverAnimated:NO];
//        }];
//    }
//    else
//    {
        [self dismissViewControllerAnimated:YES completion:nil];
//    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Avatar Image Methods
// from SCTAvatarView
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/** UPDATED: ET 12/16/14 to use image from initializer on first load ST-871
 * Updates avatarView image 
 *
 * This checks for a non-nil _editSessionImage, and if found compares it with the 
 * current avatarView image; if same, no update needed, and method returns.
 *
 * If non-nil _editSessionimage does not match avatarView image, then this method
 * was called by moveAndScaleImageViewController:didChooseImage with a new image, in
 * which case, we get a round, bordered, sized image from a UIImage category method and
 * set the avatarView image with it.
 *
 * If the _editSessionImage is nil and the _avatarImage is non-nil, set the avatarView
 * image with it. Self will have been instantiated with an existing avatar image; called
 * by viewDidLoad.
 *
 * If both _editSessionImage and _avatarImage are nil, set avatarView image with
 * the default avatar image returned from the AvatarManager.
 */
- (void)updateAvatar
{
    DDLogAutoTrace();
    
    UIImage *image = nil;

    if (_editSessionImage)
    {
        // If images match, we're done. Return.
        if (self.avatarView.avatarImage == _editSessionImage) {
            return;
        }        
        // If _editSessionImage does not match avatarView image, it's a new image from
        // the photo editing callback. Reset the _editSessionImage ivar with the processed
        // image so we can check for the image match when this method is called.
        _editSessionImage = [_editSessionImage scaledAvatarImageWithDiameter:kAvatarDiameter];
        image = _editSessionImage;
    }
    else if (_avatarImage)  // image stored from initialization
    {
        image = _avatarImage;
    }
    else  // both _editSessionImage and _avatarImage are nil
    {
        image = [[AvatarManager sharedInstance] defaultAvatarWithDiameter:kAvatarDiameter];
        image = [image avatarImageWithDiameter:kAvatarDiameter usingColor:self.theme.appTintColor];
    }
        
    // Set the avatarView with the image
    [self.avatarView setAvatarImage:image withAnimation:YES];
}


#pragma mark - AvatarViewDelegate

- (void)didTapAvatar:(SCTAvatarView *)aView
{
    DDLogAutoTrace();
    
    [self editUserImage:aView];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UITextField Observer
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
    
    if (sender == _firstNameField)
    {
        if (text.length == 0)
            _user.sc_firstName = nil;
        else
            _user.sc_firstName = text;
        
        [self updateTitle];
    }
    else if (sender == _lastNameField)
    {
        if (text.length == 0)
            _user.sc_lastName = nil;
        else
            _user.sc_lastName = text;
        
        [self updateTitle];
    }
    else if (sender == _organizationField)
    {
        if (text.length == 0)
            _user.sc_organization = nil;
        else
            _user.sc_organization = text;
        
        [self updateTitle];
    }
    else if (sender == _usernameField)
    {
        XMPPJID *jid = [self jidFromUsernameField];
        if (jid == nil)
        {
            _user = [_user copyWithNewJID:nil networkID:nil];
        }
        else
        {
            // Allow the user to specify a domain.
            // We use this for adding contacts on test networks.
            NSString *networkID = [AppConstants networkIdForXmppDomain:[jid domain]];
            _user = [_user copyWithNewJID:jid networkID:networkID];
        }
        
        [self updateTitle];
        [self updateRightBarButtonItem];
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UITextViewDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)textViewDidChange:(UITextView *)textView
{
    DDLogAutoTrace();
    
    if (textView != _notesTextView) return;
    
    if (_notesTextView.text.length == 0)
        _user.sc_notes = nil;
    else
        _user.sc_notes = _notesTextView.text;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Display
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateRightBarButtonItem
{
    UIBarButtonItem *bbtn = self.navigationItem.rightBarButtonItem;
    if (nil == bbtn)
    {
        bbtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                             target:self
                                                             action:@selector(saveButtonTapped:)];
        self.navigationItem.rightBarButtonItem = bbtn;
    }
    
    bbtn.enabled = (nil != _user.jid);
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)databaseConnectionDidUpdate:(NSNotification *)notification
{
    DDLogAutoTrace();
    
    NSArray *notifications = [notification.userInfo objectForKey:kNotificationsKey];
    
    if ([self.uiDbConnection hasChangeForKey:_user.uuid inCollection:kSCCollection_STUsers 
                             inNotifications:notifications])
    {        
        // Need to update avatar for every user change? Is there an avatar-specific change key?
        [self updateAllViews];
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is public.
 **/
- (void)cancelChanges
{
    DDLogAutoTrace();
    
    if ([self.editUserDelegate respondsToSelector:@selector(editUserInfoVCNeedsDismiss:)])
        [self.editUserDelegate editUserInfoVCNeedsDismiss:self];
}

/**
 * This method is public.
 **/
- (void)saveChanges
{
    DDLogAutoTrace();
    
    if ([_firstNameField isFirstResponder])
        [_firstNameField resignFirstResponder];
    
    if ([_lastNameField isFirstResponder])
        [_lastNameField resignFirstResponder];
    
    if ([_organizationField isFirstResponder])
        [_organizationField resignFirstResponder];
    
    if ([_usernameField isFirstResponder])
        [_usernameField resignFirstResponder];
    
    if ([_notesTextView isFirstResponder])
        [_notesTextView resignFirstResponder];
    
//    if (_userID)
    if (!_isNewUser)
    {
        // Save changes to existing user
        [self saveChangesContinue];
    }
    else
    {
        // We're going to be creating a new user.
        // So make sure the userJID doesn't already exist in the database.
        
        __block STUser *existingUser = nil;
        [self.uiDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            
            existingUser = [STDatabaseManager findUserWithJID:_user.jid transaction:transaction];
        }];
        
        if (existingUser)
        {
			if (existingUser.isSavedToSilentContacts)
			{
				[self presentExistingUserAlert];
				return;
			}
			else
			{
				// The existingUser was automatically added to the database,
				// but has never been explicitly "saved" by the user.
                // 
                // Update our "temp" new user's uuid to match what's in the database already.
				
                _user = [_user copyWithNewUUID:existingUser.uuid];
				[self saveChangesContinue];
			}
        }
        else
        {
            // do userID verfication
            
            // Todo:
            // - What if this lookup is slow? We need an activity spinner.
            // - What if the lookup fails because there's no network? We need an alternative.
            
            [[SCWebAPIManager sharedInstance] getUserInfo:_user.jid
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
					
					NSString *msg = [NSString stringWithFormat:msgFrmt, _usernameField.text];
					
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

- (void)presentExistingUserAlert
{
    DDLogAutoTrace();
    
    NSString *title = NSLocalizedString(@"Duplicate Contact", @"Alert view title");
    
    NSString *frmt = NSLocalizedString(@"There is already a contact with the username \"%@\".",
                                       @"Alert view message");
    NSString *message = [NSString stringWithFormat:frmt, _usernameField.text];
    
    NSString *okButtonTitle = NSLocalizedString(@"View Contact", @"Alert view button");
    
    [OHAlertView showAlertWithTitle:title
                            message:message
                       cancelButton:NSLS_COMMON_CANCEL
                           okButton:okButtonTitle
                      buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex)
     {
         if (buttonIndex != alert.cancelButtonIndex)
         {
             // No original code: does dismiss show the existing contact if okButtonTitle tapped?? 
             if ([self.editUserDelegate respondsToSelector:@selector(editUserInfoVCNeedsDismiss:)])
                 [self.editUserDelegate editUserInfoVCNeedsDismiss:self];
         }
     }];   
}

- (void)saveChangesContinue
{
    DDLogAutoTrace();
    
    // ET: 
    // We are assuming that the Save button can not be enabled unless the user has a jid property
    // - a new generated uuid is set on a newly allocated user in the intializer
    
    __block BOOL didDeleteUserImage = _userDeletedSessionImage;    
    __block BOOL didUpdateUserInfo = NO;
    
    UIImage *newUserImage = _editSessionImage;

    STUser *snapshotUser = [_user copy];
    NSString *userId = snapshotUser.uuid;
    
    YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
    [rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {

        STUser *existingUser = [transaction objectForKey:snapshotUser.uuid inCollection:kSCCollection_STUsers];
        
        STUser *updatedUser = nil;
        
        // Save changes to an existing db user
        if (existingUser)
        {            
            updatedUser = [existingUser copy];
			
            didUpdateUserInfo =
                ![NSString isString:snapshotUser.sc_firstName equalToString:updatedUser.sc_firstName]
            ||  ![NSString isString:snapshotUser.sc_lastName  equalToString:updatedUser.sc_lastName];
			
            updatedUser.sc_firstName = snapshotUser.sc_firstName;
            updatedUser.sc_lastName = snapshotUser.sc_lastName;
            updatedUser.sc_organization = snapshotUser.sc_organization;
            updatedUser.sc_notes = snapshotUser.sc_notes;
			
			updatedUser.abRecordID = snapshotUser.abRecordID;
			updatedUser.isAutomaticallyLinkedToAB = snapshotUser.isAutomaticallyLinkedToAB;
			
			updatedUser.ab_firstName = snapshotUser.ab_firstName;
			updatedUser.ab_lastName = snapshotUser.ab_lastName;
			updatedUser.ab_compositeName = snapshotUser.ab_compositeName;
			updatedUser.ab_organization = snapshotUser.ab_organization;
			updatedUser.ab_notes = snapshotUser.ab_notes;
        }
        else
        {
            // Creating a brand new user, without a corresponding existing user in the database.
            updatedUser = snapshotUser;
            
        }
		
		updatedUser.isSavedToSilentContacts = YES;
		updatedUser.lastUpdated = [NSDate date];

        /*
         * If I understand correctly, the newUserImage will be nil if the user has not taken or added a photo in this
         * editing session. So there shouldn't have to be changes applied to the db user "updateUser" local var,
         * regarding the avatar image.
         */
        if (_userDeletedSessionImage)
        {
            // we deleted the avatar that the user selected, so we have to force the userview to reload
            // an avatar from either the addressbook or the web.

            [updatedUser setAvatarFileName:nil avatarSource:kAvatarSource_None];
            
            didDeleteUserImage = YES;
        }

        // Save the updatedUser to the database (with changes from UI)
        
        [transaction setObject:updatedUser forKey:updatedUser.uuid inCollection:kSCCollection_STUsers];
        
        
    } completionBlock:^{
        
        if (_isNewUser)
        {
            // This callback causes ContactsVC to reset the userInfoVC.user property and dismiss this controller
            if ([self.editUserDelegate respondsToSelector:@selector(editUserInfoVC:didCreateNewUserID:)])
                [self.editUserDelegate editUserInfoVC:self didCreateNewUserID:_user.uuid];
            
            return;
        }
        
        // in the case that the user info changed, let the delegate know
        if (didUpdateUserInfo && [self.editUserDelegate respondsToSelector:@selector(editUserInfoVC:didChangeUser:)])
            [self.editUserDelegate editUserInfoVC:self didChangeUser:_user];

        
        // This callback causes userInfoVC to call refreshUser, dismisses this controller
        if (didDeleteUserImage && [self.editUserDelegate respondsToSelector:@selector(editUserInfoVCDidDeleteUserImage:)])
        {
            [self.editUserDelegate editUserInfoVCDidDeleteUserImage:self];
            return;
        }

        // This is the fall-through delegate callback to dismiss this editVC. If the only edit was to be linked/unlinked
        // from an AddressBook contact, neither of the previous conditions will be true, and neither will the new image
        // handler be called below. The UserInfoVC dismiss handler protects against over-dismissing this editVC
        [self.editUserDelegate editUserInfoVCNeedsDismiss:self];

    }];
        
    if (newUserImage)
    {
        // This callback causes userInfoVC to update editSessionImage property and call reloadView:YES forceReload:NO
        // Does not dismiss the self controller
        if ([self.editUserDelegate respondsToSelector:@selector(editUserInfoVC:willSaveUserImage:)])
            [self.editUserDelegate editUserInfoVC:self willSaveUserImage:newUserImage];
        
        /*
         *
         * NOTE: the following should work for contactsVC because the block retains the self instance after
         * ContactsVC has nil it's reference. ContactsVC still needs the delegate callback, so this should probably
         * be re-thought/implemented.
         *
         */
        
        [[AvatarManager sharedInstance] asyncSetImage:newUserImage
                                         avatarSource:kAvatarSource_SilentContacts 
                                            forUserID:userId //theUserID
                                      completionBlock:^
         {
             // Sets editSessionImage to nil, calls reloadView:YES forceReload:NO, dismisses this controller
             if ([self.editUserDelegate respondsToSelector:@selector(editUserInfoVC:didSaveUserImage:)])
                 [self.editUserDelegate editUserInfoVC:self didSaveUserImage:newUserImage];
         }];
    }
}

- (void)cancelButtonTapped:(id)sender
{
    DDLogAutoTrace();

    if ([self.editUserDelegate respondsToSelector:@selector(editUserInfoVCNeedsDismiss:)])
        [self.editUserDelegate editUserInfoVCNeedsDismiss:self];
}

- (void)saveButtonTapped:(id)sender
{
    DDLogAutoTrace();
    [self saveChanges];
}

- (IBAction)editUserImage:(id)sender
{
    DDLogAutoTrace();
    
    __block STUser *dbUser = nil;
    [self.uiDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        dbUser = [transaction objectForKey:_user.uuid inCollection:kSCCollection_STUsers];
    }];

    BOOL hasExistingImage = (nil != _editSessionImage);
    if (dbUser && NO == hasExistingImage)
    {
        // only allow delete of SC contact images here.
        hasExistingImage = [[AvatarManager sharedInstance] hasImageForUser:dbUser];
        if (hasExistingImage && _user.avatarSource < kAvatarSource_SilentContacts)
            hasExistingImage = NO;
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
            deletePhotoIndex = 0;
            takePhotoIndex   = NSIntegerMax;
            choosePhotoIndex = 1;
        }
        else
        {
            takePhotoIndex   = NSIntegerMax;
            choosePhotoIndex = 0;
        }
    }
    
    //ET 10/16/14 OHActionSheet update
    CGRect avatarRect = self.avatarView.avatarImageRect;
    CGRect frame = [self.avatarView convertRect:avatarRect toView:self.view];
    [OHActionSheet showFromRect:frame
                       sourceVC:self 
                         inView:self.view
                 arrowDirection:([self presentActionSheetAsPopover]) ? UIPopoverArrowDirectionUp : 0
                          title:nil
              cancelButtonTitle:NSLS_COMMON_CANCEL  
         destructiveButtonTitle:(hasExistingImage) ? deletePhotoTitle : nil
              otherButtonTitles:buttonTitles 
                     completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                         
                         if (buttonIndex == takePhotoIndex)
                             [self takePhoto];
                         
                         else if (buttonIndex == choosePhotoIndex)
                             [self choosePhoto];
                         
                         else if (buttonIndex == sheet.destructiveButtonIndex)
                             [self deletePhoto];
                     }];
}

- (IBAction)linkAddressBookTapped:(id)sender
{
    DDLogAutoTrace();
    
    STUser *user = _user;
    if (user.abRecordID == kABRecordInvalidID)
    {
        ABPeoplePickerNavigationController* picker = [[ABPeoplePickerNavigationController alloc] init];
        picker.peoplePickerDelegate = self;
        
        [self presentPicker:picker];
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
        
        [self updateAllViews];
    }
}

- (IBAction)deleteContactTapped:(UIButton *)sender
{
    DDLogAutoTrace();
    
    //ET 10/16/14 OHActionSheet update
    CGRect frame = [_deleteContactView convertRect:_btnDeleteContact.frame toView:self.view];
    [OHActionSheet showFromRect:frame 
                       sourceVC:self 
                         inView:self.view
                 arrowDirection:([self presentActionSheetAsPopover]) ? UIPopoverArrowDirectionDown : 0
                          title:nil
              cancelButtonTitle:NSLS_COMMON_CANCEL  
         destructiveButtonTitle:NSLocalizedString(@"Delete Contact", @"Delete Contact")  
              otherButtonTitles:nil 
                     completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
	{
		if (buttonIndex == sheet.destructiveButtonIndex)
		{
			// This callback causes userInfoVC to set its user to nil,
			// call reloadView:YES forceReload:YES, and pop 2 navCon controllers
			if ([self.editUserDelegate respondsToSelector:@selector(editUserInfoVC:willDeleteUserID:)])
				[self.editUserDelegate editUserInfoVC:self willDeleteUserID:_user.uuid];
			
			[STDatabaseManager asyncUnSaveRemoteUser:_user.uuid completionBlock:NULL];
		}
	}];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Photos
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)takePhoto
{
    DDLogAutoTrace();
    
    UIImagePickerControllerSourceType cameraType = UIImagePickerControllerSourceTypeCamera;
    if (![UIImagePickerController isSourceTypeAvailable:cameraType])
    {
        // Some other app stole the camera before the user tapped the button. Dang!
        return;
    }
    
    UIImagePickerController *imagePicker = [self imagePickerOfType:cameraType];
    [self presentPicker:imagePicker];
}

- (void)choosePhoto
{
    DDLogAutoTrace();
    
    UIImagePickerControllerSourceType photoType = UIImagePickerControllerSourceTypePhotoLibrary;
    if (![UIImagePickerController isSourceTypeAvailable:photoType])
    {
        return;
    }
    
    UIImagePickerController *imagePicker = [self imagePickerOfType:photoType];
    [self presentPicker:imagePicker];
}

- (void)deletePhoto
{
    DDLogAutoTrace();

    _editSessionImage = nil;
    _userDeletedSessionImage = YES;
    
    [self updateAvatar];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    DDLogAutoTrace();
    
    [self dismissPicker:picker];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    DDLogAutoTrace();
    
    UIImagePickerController *imagePicker = picker;
    
    MoveAndScaleImageViewController *moveScaleImgVC = [[MoveAndScaleImageViewController alloc] initWithMediaInfo:info];
    moveScaleImgVC.delegate = self;

    BOOL animated = (imagePicker.sourceType == UIImagePickerControllerSourceTypeCamera);
    [imagePicker pushViewController:moveScaleImgVC animated:animated];

}

- (void)moveAndScaleImageViewControllerDidCancel:(MoveAndScaleImageViewController *)sender
{
    DDLogAutoTrace();
    
    MoveAndScaleImageViewController *moveScaleImgVC = sender;
    [moveScaleImgVC.navigationController popViewControllerAnimated:YES];
    moveScaleImgVC.delegate = nil;
}

- (void)moveAndScaleImageViewController:(MoveAndScaleImageViewController *)sender didChooseImage:(UIImage *)image
{
    DDLogAutoTrace();
    
    // Store the returned image
    _editSessionImage = image;
    _userDeletedSessionImage = NO;
    
    sender.delegate = nil;
    [self dismissPicker:sender];
    [self updateAvatar];
}

- (UIImagePickerController *)imagePickerOfType:(UIImagePickerControllerSourceType)aType
{
    UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
    imagePicker.sourceType = aType;
    imagePicker.delegate = self;    
    imagePicker.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    imagePicker.modalPresentationStyle = UIModalPresentationFullScreen;

    return imagePicker;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - ABPeoplePickerNavigationControllerDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Called after the user has pressed cancel
 * The delegate is responsible for dismissing the peoplePicker
 **/
- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker
{
    DDLogAutoTrace();
    
    [self dismissPicker:peoplePicker];
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
	ABRecordID abRecordID = person ? ABRecordGetRecordID(person) : kABRecordInvalidID;
    
    STUser *user = _user;
    user.abRecordID = abRecordID;
    user.isAutomaticallyLinkedToAB = NO;
    
    NSDictionary *info = [[AddressBookManager sharedInstance] infoForABRecordID:abRecordID];
    
    user.ab_firstName     = [info objectForKey:kABInfoKey_firstName];
    user.ab_lastName      = [info objectForKey:kABInfoKey_lastName];
    user.ab_compositeName = [info objectForKey:kABInfoKey_compositeName];
    user.ab_organization  = [info objectForKey:kABInfoKey_organization];
    user.ab_notes         = [info objectForKey:kABInfoKey_notes];
    
    [self updateAllViews];
    
    [self dismissPicker:peoplePicker];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Create Public Key
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)didTapCreatePublicKey:(UIButton *)sender
{
    DDLogAutoTrace();
    
    if (_user.isRemote) return;
    
    NSString *name = _user.jid.user;
    if (name == nil) {
        return;
    }
    
    self.navigationItem.rightBarButtonItem = NULL;
    
    __weak typeof(self) weakSelf = self;
    NSString *userId = _user.uuid;
    
    //ET 10/16/14 OHActionSheet update
    CGRect frame = [_publicKeyView convertRect:_lblCreatePublicKey.frame toView:self.view];
    [OHActionSheet showFromRect:frame
                       sourceVC:self 
                         inView:self.view //_deleteContactView
                 arrowDirection:([self presentActionSheetAsPopover]) ? UIPopoverArrowDirectionDown : 0
                          title:NSLocalizedString(@"Create and Upload new Public Key", @"Create New Public Key")
              cancelButtonTitle:NSLS_COMMON_CANCEL  
         destructiveButtonTitle:NSLS_COMMON_NEW_KEY
              otherButtonTitles:nil 
                     completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
	{
		NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
		
		if ([choice isEqualToString:NSLS_COMMON_NEW_KEY])
		{
			[self startCreatePublicKeySpinner];
			
			[[STUserManager sharedInstance] removeAllPrivateKeysForUserID:userId
			                                              completionBlock:^(NSString *newKeyID)
			{
				__strong typeof(self) strongSelf = weakSelf;
				if (strongSelf == nil) return;
				
				[strongSelf stopCreatePublicKeySpinner];
				
				// Set the flag if no error
				//
				// Update: -RH
				// The uploading of the publicKey is no longer synchronous.
				// As in, the upload may fail for now, but the key is in the database,
				// so the DatabaseActionManager will continue trying until it suceeds.
				//
				strongSelf->_didRecreatePublicKey = YES;
				
				[strongSelf updateCreatePublicKeyButton];
			}];
		}
	}];
}

- (void)updateCreatePublicKeyButton
{
    UIColor *tintColor = (_didRecreatePublicKey) ? self.theme.appTintColor : [UIColor redColor];
    CGFloat viewAlpha  = (_didRecreatePublicKey) ? 0.5 : 1;
    BOOL enabled = !_didRecreatePublicKey;
    if (_didRecreatePublicKey)
    {
        _lblCreatePublicKey.text = NSLocalizedString(@"Public Key Uploaded", @"Public Key Uploaded");
    }
    else
    {
        _lblCreatePublicKey.text = NSLocalizedString(@"Create New Public Key", @"Create New Public Key");
    }
    
    UIButton *pubKeyButton = _btnCreatePublicKey;
    UIImage *icon = [UIImage imageNamed:@"refresh_key"];
    UIImage *tintIcon = [icon maskWithColor:tintColor];
    [pubKeyButton setImage:tintIcon forState:UIControlStateNormal];
    pubKeyButton.alpha = viewAlpha;
    pubKeyButton.hidden = NO;
    pubKeyButton.enabled = enabled;

    _lblCreatePublicKey.alpha = viewAlpha;
    _lblCreatePublicKey.textColor = tintColor;
    _lblCreatePublicKey.userInteractionEnabled = enabled;
}

- (void)hideCreatePublicKeyButton
{
    _btnCreatePublicKey.hidden = YES;
    _lblCreatePublicKey.hidden = YES;
}


- (void)startCreatePublicKeySpinner
{
    _lblCreatePublicKey.alpha = 0.15;
    _btnCreatePublicKey.alpha = 0.15;
    
    _createPublicKeySpinner.hidden = NO;
    [_createPublicKeySpinner startAnimating];
}


- (void)stopCreatePublicKeySpinner
{
    [_createPublicKeySpinner stopAnimating];
    _createPublicKeySpinner.hidden = YES;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NavigationControllerDelegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)navigationController:(UINavigationController *)navigationController 
      willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (viewController == self)
    {
        navigationController.delegate = self.cachedNavDelegate;
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
- (XMPPJID *)jidFromUsernameField
{
    NSString *jidStr = _usernameField.text;
    
    if (jidStr.length == 0) return nil;
    
    NSRange range = [jidStr rangeOfString:@"@"];
    if (range.location == NSNotFound)
        jidStr = [jidStr stringByAppendingString:@"@silentcircle.com"];
    
    XMPPJID *jid = [XMPPJID jidWithString:jidStr];
    
    if (jid == nil) 
        return nil;
    

    if ([jid resource] != nil) // resources are not allowed
        return nil;
    else
        return [jid bareJID];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Keyboard Methods
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
        keyboardHeight = keyboardEndRect.size.width;
    else
        keyboardHeight = keyboardEndRect.size.height;
    
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
    
    //FIXME ! keyboard
    return;
    
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
    
    UIEdgeInsets insets = self.scrollView.contentInset;
    insets.bottom = keyboardHeight;
    
    self.scrollView.contentInset = insets;
    self.scrollView.scrollIndicatorInsets = insets;
    
    _resetContentInset = NO;
    
    if (_notesTextView.isFirstResponder)
    {
        [self.scrollView scrollRectToVisible:_notesTextView.frame animated:YES];
    }
    else
    {
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(animationDuration * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            
            [self.scrollView flashScrollIndicators];
        });
    }
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    DDLogAutoTrace();
    
    //FIXME ! keyboard
    return;
    
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
    
    CGFloat spaceAbove = self.scrollView.contentOffset.y + self.scrollView.contentInset.top;
    CGFloat spaceBelow = self.scrollView.contentSize.height - self.scrollView.contentOffset.y - self.scrollView.frame.size.height;
    
    if (spaceAbove < 0)
    {
        // The user is dimissing the keyboard on iOS 7 via UIScrollViewKeyboardDismissModeInteractive.
        //
        // Allow the scrollView to rubber-band back into position,
        // and then reset the contentInset.
        
        _resetContentInset = YES;
        return;
    }
    else
    {
        _resetContentInset = NO;
    }
    
    if (spaceBelow < 0)
        spaceBelow = 0;
    
    DDLogVerbose(@"spaceAbove: %f", spaceAbove);
    DDLogVerbose(@"spaceBelow: %f", spaceBelow);
    
    CGRect originFrame = self.scrollView.frame;
    CGRect finishFrame = self.scrollView.frame;
    
    CGPoint contentOffset = self.scrollView.contentOffset;
    
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
        self.scrollView.contentOffset = contentOffset;
        
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
    
    self.scrollView.frame = originFrame;
    
    // Update contentInsets.
    //
    // On iOS7, the scrollView.contentInset.top is automatically set to the height of the statusBar + navBar.
    // We need to ensure the top value stays the same.
    
    UIEdgeInsets insets = self.scrollView.contentInset;
    insets.bottom = 0;
    
    self.scrollView.contentInset = insets;
    self.scrollView.scrollIndicatorInsets = insets;
    
    // And animate the frame back into position.
    
    DDLogVerbose(@"scrollView: %@ -> %@", NSStringFromCGRect(originFrame), NSStringFromCGRect(finishFrame));
    
    void (^animationBlock)(void) = ^{
        
        self.scrollView.frame = finishFrame;
    };
    
    [UIView animateWithDuration:animationDuration
                          delay:0.0
                        options:animationOptions
                     animations:animationBlock
                     completion:NULL];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Accessors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isNewUser
{
    return (_user && nil == _user.jid);
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

- (AppTheme *)theme 
{
    return STAppDelegate.theme;
}


@end
