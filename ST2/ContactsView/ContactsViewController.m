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
#import "ContactsViewController.h"
#import "ContactsSubViewController.h"

#import "AppConstants.h"
#import "AppDelegate.h"
#import "AppTheme.h"
#import "EditUserInfoVC.h"
#import "OHActionSheet.h"
#import "SCFileManager.h"
#import "SCTAvatarView.h"
#import "SilentTextStrings.h"
#import "STPreferences.h"
#import "STLogging.h"
#import "STUser.h"
#import "STUserManager.h"
#import "UserInfoVC.h"
#import "YapDatabase.h"

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


@implementation ContactsViewController
{
	ContactsSubViewController *contactsSubViewController;
    EditUserInfoVC  *editUserInfoVC;
	
	NSString *newUserID;
	UIImage *newUserImage;
	
	BOOL ignoreSelectionChange;
    
    UIPopoverController* popoverController;
}
@synthesize userInfoVC = userInfoVC;


- (id)initWithProperNib
{
	return [self initWithNibName:@"ContactsViewController" bundle:nil];
}

- (void)dealloc
{
    DDLogAutoTrace();

    contactsSubViewController = nil;
    editUserInfoVC = nil;
    newUserID = nil;
    newUserImage = nil;
    popoverController = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - View Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad
{
	DDLogAutoTrace();
	[super viewDidLoad];
	
    [self registerForKeyboardNotifications];
  
//	self.navigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(changeTheme:)
												 name:kAppThemeChangeNotification
											   object:nil];
	
	self.navigationItem.leftBarButtonItem = STAppDelegate.settingsButton;
    
	self.navigationItem.rightBarButtonItem =
	  [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
	                                                target:self
	                                                action:@selector(createNewContact:)];
	
    self.navigationItem.rightBarButtonItem.accessibilityLabel = NSLocalizedString(@"Add new contact", 
                                                                                  @"Add new contact - barbutton accessibility label");

	self.navigationItem.title = NSLocalizedString(@"Silent Contacts", @"ContactsViewController title");
	
	self.view.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
	
	contactsSubViewController =
	  [[ContactsSubViewController alloc] initWithDatabaseViewName:Ext_View_SavedContacts delegate:self];
	contactsSubViewController.allowsDeletion = YES;
	contactsSubViewController.expandsSelectedContact = YES;
	
    [self.exportButton setEnabled:NO];
   	
	if (AppConstants.isIPhone)
	{
		contactsSubViewController.ensuresSelection = NO;
	}
	else
	{
		contactsSubViewController.ensuresSelection = YES;
		contactsSubViewController.selectedUserId = [STPreferences lastSelectedContactUserId];
	}
	
	contactsSubViewController.view.frame = self.contactView.bounds;
	contactsSubViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth |
	                                                  UIViewAutoresizingFlexibleHeight;
	
	[self.contactView addSubview:contactsSubViewController.view];
	[self addChildViewController:contactsSubViewController];
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		
		CGRect f1 = self.contactView.frame;
		CGRect f2 = contactsSubViewController.view.frame;
		
		NSLog(@"========== f1: %@", NSStringFromCGRect(f1));
		NSLog(@"========== f2: %@", NSStringFromCGRect(f2));
	});
	
	// Add constraint between contactView & topLayoutGuide
	NSLayoutConstraint *topLayoutGuideConstraint =
	  [NSLayoutConstraint constraintWithItem:self.contactView
	                               attribute:NSLayoutAttributeTop
	                               relatedBy:NSLayoutRelationEqual
	                                  toItem:self.topLayoutGuide
	                               attribute:NSLayoutAttributeBottom
	                              multiplier:1.0
	                                constant:0.0];

	[self.view removeConstraint:self.contactViewTopConstraint];
	[self.view addConstraint:topLayoutGuideConstraint];
	[self.view setNeedsUpdateConstraints];
	

	if (AppConstants.isIPad)
	{
		// Tell the UITableViewController not to clear the selection on viewWillAppear.
		// This is a problem if we display something full screen over our contacts view.
		// When we dismiss the full screen stuff, the viewWillAppear method gets hit,
		// and we don't want it to clear the selection on us.
		//
		// To witness the bug this fixes, comment this line out,
		// and then go bring up the MoveAndScaleImageViewController by changing a contact's image.
// TODO: deal with this?
//		contactsSubViewController.clearsSelectionOnViewWillAppear = NO;
	}
	
	// The following is a workaround for what appears to be a bug in iOS.
	// Description of the bug:
	//
	// The statusBarStyle should get set according to the viewController.
	// Here's how it works on iPad.
	// - iOS queries revealController, which redirects to MGSplitVC (via childViewControllerForStatusBarStyle)
	// - iOS queries splitVC, which redirects to self.navigationController (via childViewControllerForStatusBarStyle)
	//
	// So theoretically, if we change self.navigationController.navigationBar.barStyle,
	// then it should trigger setNeedsStatusBarAppearanceUpdate for iOS.
	// But this doesn't always seem to do the trick for this particular situation.
	// So we force it manually.
	//
	// How to reproduce bug (assuming code below is commented out):
	//
	// - Pick a theme such that the status bar text is black when displaying the conversations and messages.
	// - Then go into the settings, and select contacts.
	// - The bug causes the status bar text to continue to be black when it switches to contacts.
	// - Then go into settings, and dismiss settings (still in contacts).
	// - The status bar text should now be the proper white color.
	
//	[self setNeedsStatusBarAppearanceUpdate];                      // doesn't work
//	[self.navigationController setNeedsStatusBarAppearanceUpdate]; // doesn't work
	[STAppDelegate.revealController setNeedsStatusBarAppearanceUpdate];
}

- (void)viewWillAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillAppear:animated];

    [self updateExportButton];
}

- (void)viewDidAppear:(BOOL)animated
{
    DDLogAutoTrace();
    [super viewDidAppear:animated];
    
    [self updateUserInfoBarButtons];
}

- (void)changeTheme:(NSNotification *)notification {
	AppTheme *theme;
	NSDictionary *userInfo = notification.userInfo;
	if (userInfo)
		theme = userInfo[kNotificationUserInfoTheme];
	else
		theme = [AppTheme getThemeBySelectedKey];
	
	//
	// Navigation Bar
	//
	
	if (theme.navBarIsBlack)
		self.navigationController.navigationBar.barStyle = UIBarStyleBlack;//Translucent;
	else
		self.navigationController.navigationBar.barStyle = UIBarStyleDefault;
	
	self.navigationController.navigationBar.translucent = theme.navBarIsTranslucent;
	self.navigationController.navigationBar.barTintColor = theme.navBarColor;
	self.navigationController.navigationBar.tintColor = theme.navBarTitleColor;
}

/**
 * This method sets the userInfoVC rightBarButtonItem to intercept taps.
 *
 *
 *
 * Note: the barButtonItem must be set after userInfoVC viewDidLoad returns. This is so
 * because userInfoVC sets the button for itself on first load, therefore, this method is
 * called from viewDidAppear:, and after dismissing edit VC and reloading UserInfoVC.
 **/
- (void)updateUserInfoBarButtons
{
    DDLogAutoTrace();
    
    //09/26/14 Come back to this: support saving a tempUser directly from UserInfoVC
    // ...should only be in a group conversation context ??
//    if (_user.isTempUser)
//    {
//        self.navigationItem.rightBarButtonItem =
//        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
//                                                      target:self
//                                                      action:@selector(saveButtonTapped:)];        
//    }
//    else 
//    {
    userInfoVC.navigationItem.rightBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                  target:self
                                                  action:@selector(editButtonTapped:)];
    
    //ET 03/27/15 - Accessibility
    NSString *contactName = userInfoVC.user.displayName;
    NSString *aLbl = [NSString stringWithFormat:NSLocalizedString(@"Edit %@ contact", 
                                                                  @"Edit {contact name} contact - Edit barbutton accessibility label"),
                      contactName];
    userInfoVC.navigationItem.rightBarButtonItem.accessibilityLabel = aLbl;
//    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Accessibility
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)selectedUserId
{
	return contactsSubViewController.selectedUserId;
}

- (void)setSelectedUserId:(NSString *)userId
{
	contactsSubViewController.selectedUserId = userId;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - View Preferences
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)prefersStatusBarHidden
{
	return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
	return UIStatusBarStyleLightContent;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - ContactsSubViewController Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)contactsSubViewControllerSelectionDidChange:(ContactsSubViewController *)sender
{
	DDLogAutoTrace();
	
	if (ignoreSelectionChange) 
        return;
	
    NSString *userId = sender.selectedUserId;
    STUser *user = [self userForUserId:userId];

    // If currently editing, dismiss editVC and update userInfo with selected user
    if (editUserInfoVC)
    {
        userInfoVC.user = user;
        [self dismissEditUserInfoVCAnimated:NO];
    }
    else
    {
        [self presentUserInfoWithUser:user];
    }
    
    if (AppConstants.isIPad)
        [STPreferences setLastSelectedContactUserId:userId];
    
    // Reset the UserInfoVC Edit barbutton for each change
    [self updateUserInfoBarButtons];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Present UserInfo
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)presentUserInfoWithUser:(STUser *)aUser
{
    DDLogAutoTrace();
    
    if (AppConstants.isIPhone)
    {
        UserInfoVC *uivc = [[UserInfoVC alloc] initWithUser:aUser];        
        [self.navigationController pushViewController:uivc animated:YES];
    }
    else
    {
        userInfoVC.user = aUser;
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Create New Contact
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)createNewContact:(id)sender
{
    DDLogAutoTrace();
    
    [self presentEditUser:nil];
}

- (void)presentEditUser:(STUser *)aUser
{
    DDLogAutoTrace();
    
    // Guard against multiple taps on this button.
    // If we're already presenting the screen to create a new contact,
    // then tapping the button again should do nothing.
    if (editUserInfoVC != nil) 
        return;

    UIImage *avatarImg = (aUser) ? userInfoVC.avatarView.avatarImage : nil;
    EditUserInfoVC *euivc = [[EditUserInfoVC alloc] initWithUser:aUser 
                                                           avatarImage:avatarImg];
    euivc.editUserDelegate = self;
    
    euivc.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                  target:self
                                                  action:@selector(editCanceled:)];
    
    if (AppConstants.isIPhone)
    {
        [self.navigationController pushViewController:euivc animated:YES];
    }
    else
    {   
        UINavigationController *userInfoNavCon = userInfoVC.navigationController;
        //ST-1053
        // Guard against presenting the editUserInfoVC on top of a VC which may
        // be on top of userInfoVC. The current case is a HelpVC instance has
        // been pushed onto the userInfoVC. We don't want to add the editUserInfoVC
        // on top of it, but rather dismiss is first.
        //
        // Instead of this handling being specific to the current HelpVC case, we
        // make it generic, so that whatever the topVC might be, dismiss it before
        // presenting the editUserInfoVC.
        if (NO == [userInfoNavCon.topViewController isKindOfClass:[userInfoVC class]]) {
            [userInfoNavCon popToViewController:userInfoVC animated:NO];
        }
        
        // Push our own editUserInfoVC.
        [userInfoNavCon pushViewController:euivc animated:NO];
        editUserInfoVC = euivc;
    }
    
    // Note that we are the delegate.

}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Edit Button Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)editButtonTapped:(id)sender
{    
    [self presentEditUser:userInfoVC.user];
}

- (void)editCanceled:(id)sender
{
    [self editUserInfoVCNeedsDismiss:editUserInfoVC];
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - EditUserInfoDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The user attempted to create a contact with a username that already exists.
 * We displayed an AlertView telling them we can't do that,
 * and they selected the button to view the existing user.
**/
- (void)editUserInfoVC:(EditUserInfoVC *)sender needsShowUserID:(NSString *)userID
{
	DDLogAutoTrace();
	
	if (AppConstants.isIPhone)
	{
		// Pop and discard our editUserInfoVC
		
		[self.navigationController popViewControllerAnimated:NO];
		editUserInfoVC = nil;
		
		// Push an userInfoVC for the designated user
        STUser *user = [self userForUserId:userID];
		
		UserInfoVC *uivc = [[UserInfoVC alloc] initWithUser:user];
//		uivc.userID = userID;
//		uivc.isInPopover = NO;
		
		[self.navigationController pushViewController:uivc animated:NO];
	}
	else
	{
		// Pop and discard our editUserInfoVC
		
		[userInfoVC.navigationController popViewControllerAnimated:NO];
		editUserInfoVC = nil;
		
		// Update the userInfoVC to show the new user
		
        self.userInfoVC.user = [self userForUserId:userID];
	}
	
	// Update our selection to match what's being displayed.
	
	ignoreSelectionChange = YES;
	contactsSubViewController.selectedUserId = userID;
	ignoreSelectionChange = NO;
}

- (void)editUserInfoVC:(EditUserInfoVC *)sender didCreateNewUserID:(NSString *)userID
{
	DDLogAutoTrace();
	
//	// Store value - will be used editUserInfoVCNeedsDismiss (below)
	newUserID = userID;
//    [self.userInfoVC editUserInfoVC:sender didCreateNewUserID:userID];
    [self editUserInfoVCNeedsDismiss:sender];
}

- (void)editUserInfoVC:(EditUserInfoVC *)sender willDeleteUserID:(NSString *)aUserID
{
    DDLogAutoTrace();
}

- (void)editUserInfoVC:(EditUserInfoVC *)sender willSaveUserImage:(UIImage *)image
{
	DDLogAutoTrace();
	
	// Store value - will be used editUserInfoVCNeedsDismiss (below)
//	newUserImage = image;
    [userInfoVC editUserInfoVC:sender willSaveUserImage:image];
}

- (void)editUserInfoVC:(EditUserInfoVC *)sender didSaveUserImage:(UIImage *)image
{
	DDLogAutoTrace();
	
	// Forward to userInfoVC
	[userInfoVC editUserInfoVC:sender didSaveUserImage:image];
	
	// Note: This method will be invoked ** after ** editUserInfoVCNeedsDismiss.
	// The user image is saved separately, and can be time consuming (1 or 2 seconds).
}

- (void)editUserInfoVCNeedsDismiss:(EditUserInfoVC *)sender
{
    DDLogAutoTrace();
    
    if (newUserID)
    {
        // The user tapped 'Save'
        
        STUser *newUser = [self userForUserId:newUserID];
        
//        if (AppConstants.isIPhone)
//        {
//            
//            // Create and show a new userInfoVC            
//            [self presentUserInfoWithUser:newUser];
//            
//            if (newUserImage) {
//                [userInfoVC editUserInfoVC:sender willSaveUserImage:newUserImage];
//            }
//            
//            // Pop and discard our editUserInfoVC			
//            [self dismissEditUserInfoVCAnimated:YES];
//        }
//        else
//        {
            // Update the userInfoVC to display the newly created user
            userInfoVC.user = newUser;
            
            if (newUserImage) {
                [self.userInfoVC editUserInfoVC:sender willSaveUserImage:newUserImage];
            }
            
            // Pop and discard our editUserInfoVC
            [self dismissEditUserInfoVCAnimated:YES];
//        }
        
        // Update our selection to match what's being displayed
        ignoreSelectionChange = YES;
        contactsSubViewController.selectedUserId = newUserID;
        ignoreSelectionChange = NO;
    }
    else
    {
        // The user tapped 'Cancel'
        
        if (AppConstants.isIPhone)
        {
            // Pop and discard our editUserInfoVC
            [self dismissEditUserInfoVCAnimated:YES];
        }
        else
        {
            // Update the userInfoVC to display whatever is currently selected.
            STUser *user = [self userForUserId:contactsSubViewController.selectedUserId];
            self.userInfoVC.user = user;
            
            // Pop and discard our editUserInfoVC
            [self dismissEditUserInfoVCAnimated:YES];
        }
    }
    
    // Clear temp values        
    newUserID = nil;
    newUserImage = nil;

}

- (void)dismissEditUserInfoVCAnimated:(BOOL)animated
{
    UINavigationController *navCon = (AppConstants.isIPhone) ? self.navigationController : userInfoVC.navigationController;
    [navCon popViewControllerAnimated:(AppConstants.isIPhone)];
    editUserInfoVC = nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Export Contacts
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateExportButton
{
    __block BOOL isEmpty = YES;
    
    [STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		isEmpty = [[transaction ext:Ext_View_SavedContacts] isEmpty];
	}];
    
    [self.exportButton setEnabled:!isEmpty];
    
    //03/26/15 - Accessibility
    NSString *btnState = (_exportButton.isEnabled) ? @"enabled" : @"disabled";
    NSString *aLbl = [NSString stringWithFormat:NSLocalizedString(@"%@ contacts %@", 
                                                                  @"Export contacts {enabled/disabled} - accessibility label"), 
                      _exportButton.title,
                      btnState];
    _exportButton.accessibilityLabel = aLbl;
}


// --[Placeholder code copy] --
//- (void)updateSettingsButtonAccessibility
//{
//    BOOL settingsClosed = (revealController.frontViewPosition == FrontViewPositionLeft);
//    NSString *viewState = (settingsClosed) ? @"Closed" : @"Open in split screen";
//    NSString *aLbl = [NSString stringWithFormat:NSLocalizedString(@"Settings %@", 
//                                                                  @"Settings view %@ (closed or split screen state)"), 
//                      viewState];
//    _settingsButton.accessibilityLabel = aLbl;
//}



- (IBAction)exportContacts:(id)sender
{
    
#define NSLS_COMMON_VCARD NSLocalizedString(@"vCard format", @"vCard format - actionSheet label")
#define NSLS_COMMON_SILENTCONTACTS NSLocalizedString(@"Silent Contacts format", @"Silent Contacts - actionSheet label")

    //ET 03/19/15
    // ST-1016 fix iPad crash: present popover from barbuttonItem on toolbar
    CGRect btnFrame = [(UIView*)[_exportButton valueForKey:@"view"] frame];
    [OHActionSheet showFromRect:btnFrame 
                       sourceVC:self 
                         inView:_toolBar 
                 arrowDirection:UIPopoverArrowDirectionAny
                          title:NSLocalizedString(@"Choose a export format for your Silent Contacts", @"Export Silent Contacts")
              cancelButtonTitle:NSLS_COMMON_CANCEL
         destructiveButtonTitle:nil
              otherButtonTitles: @[NSLS_COMMON_VCARD, NSLS_COMMON_SILENTCONTACTS]
                     completion:^(OHActionSheet *sheet, NSInteger buttonIndex) 
     {
         NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
         
         if ([choice isEqualToString:NSLS_COMMON_VCARD])
         {
             [self exportVcardContacts:sender];
         }
         else if ([choice isEqualToString:NSLS_COMMON_SILENTCONTACTS])
         {
             [self exportSilentContacts:sender];
         }
         
     }];
}

- (IBAction)exportSilentContacts:(id)sender
{
    __block NSString* jsonString = @"";
    __block NSMutableArray * exportItems = [NSMutableArray array ];
    
	NSURL *exportURL = [[SCFileManager mediaCacheDirectoryURL] URLByAppendingPathComponent:@"SilentText Contacts"];
    exportURL = [exportURL URLByAppendingPathExtension:@"silentcontacts"];
    
    DDLogGreen(@"exportContacts");
    
    [STDatabaseManager.roDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        [transaction enumerateKeysAndObjectsInCollection:kSCCollection_STUsers
                                              usingBlock:^(NSString *key, id object, BOOL *stop)
         {
             
             __unsafe_unretained STUser *user = (STUser *)object;
             
             NSDictionary* dict = [[STUserManager sharedInstance] dictionaryForUser:user withTransaction:transaction];
             [exportItems addObject:dict];
             
         }];
		
    } completionBlock:^{
		
		// The completion block is executed on the main thread.
		
		id exportObject = (exportItems.count == 1) ? [exportItems firstObject] : exportItems;
		
		NSData *jsonData = nil;
		if ([NSJSONSerialization  isValidJSONObject:exportObject]) {
			jsonData = [NSJSONSerialization dataWithJSONObject:exportObject
			                                           options:NSJSONWritingPrettyPrinted
			                                             error:nil];
		}
		
		jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
		
		NSError *error = nil;
		[jsonString writeToURL:exportURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
		
		if (error)
		{
			[STAppDelegate otherError:error.localizedDescription];
		}
		else
		{
			NSArray *objectsToShare = @[ exportURL ];
			
			UIActivityViewController *uiac =
			  [[UIActivityViewController alloc] initWithActivityItems:objectsToShare applicationActivities:nil];
			
			uiac.excludedActivityTypes = @[
			  UIActivityTypePostToTwitter,
			  UIActivityTypePostToFacebook,
			  UIActivityTypePostToWeibo,
			  UIActivityTypePrint,
			  UIActivityTypeAssignToContact,
			  UIActivityTypeSaveToCameraRoll,
			  UIActivityTypeAddToReadingList,
			  UIActivityTypePostToFlickr,
			  UIActivityTypePostToVimeo,
			  UIActivityTypePostToTencentWeibo
			];
			
			uiac.completionWithItemsHandler =
			    ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError)
			{
				if(exportURL)
				{
					[[NSFileManager defaultManager] removeItemAtURL:exportURL error:NULL];
				}
				
				popoverController = nil;
			};
			
			if (AppConstants.isIPhone)
			{
				[self presentViewController:uiac animated:YES completion:nil];
			}
			else
			{
				DDLogGreen(@"presentPopoverFromBarButtonItem");
				
				popoverController = [[UIPopoverController alloc] initWithContentViewController:uiac];
				[popoverController presentPopoverFromBarButtonItem:sender
				                          permittedArrowDirections:UIPopoverArrowDirectionAny
				                                          animated:YES];
			}
		}
	}];
}


- (IBAction)exportVcardContacts:(id)sender
{
	DDLogAutoTrace();
	
	NSURL *vCardURL = [[SCFileManager mediaCacheDirectoryURL] URLByAppendingPathComponent:@"SilentText Contacts"];
	vCardURL = [vCardURL URLByAppendingPathExtension:@"vcf"];
	
	NSMutableString *vCard = [NSMutableString string];
    
    [STDatabaseManager.roDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
		[transaction enumerateKeysAndObjectsInCollection:kSCCollection_STUsers
		                                      usingBlock:^(NSString *key, id object, BOOL *stop)
		{
			__unsafe_unretained STUser *user = (STUser *)object;
			
			NSString *userCard = [[STUserManager sharedInstance] vcardForUser:user withTransaction:transaction];
			[vCard appendString:userCard];
		}];
		
	} completionBlock:^{
		
		// The completion block is executed on the main thread.
		
		NSError *error = nil;
		[vCard writeToURL:vCardURL atomically:YES encoding:NSUTF8StringEncoding error:&error];
		
		if (error)
		{
			[STAppDelegate otherError: error.localizedDescription];
		}
		else
		{
			NSArray *objectsToShare = @[ vCardURL ];
			
			UIActivityViewController *uiac =
			  [[UIActivityViewController alloc] initWithActivityItems:objectsToShare applicationActivities:nil];
			
			uiac.excludedActivityTypes = @[
			  UIActivityTypePostToTwitter,
			  UIActivityTypePostToFacebook,
			  UIActivityTypePostToWeibo,
			  UIActivityTypePrint,
			  UIActivityTypeAssignToContact,
			  UIActivityTypeSaveToCameraRoll,
			  UIActivityTypeAddToReadingList,
			  UIActivityTypePostToFlickr,
			  UIActivityTypePostToVimeo,
			  UIActivityTypePostToTencentWeibo
			];
			
			uiac.completionWithItemsHandler =
			    ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError)
			{
				if (vCardURL)
				{
					[[NSFileManager defaultManager]  removeItemAtURL:vCardURL error:NULL];
				}
				
				popoverController = nil;
			};
			
			if (AppConstants.isIPhone)
			{
				[self presentViewController:uiac animated:YES completion:nil];
			}
			else
			{
				DDLogGreen(@"presentPopoverFromBarButtonItem");
				
				popoverController = [[UIPopoverController alloc] initWithContentViewController:uiac];
				[popoverController presentPopoverFromBarButtonItem:sender
				                          permittedArrowDirections:UIPopoverArrowDirectionAny
				                                          animated:YES];
			}
		}
    }];
}


//ET 03/03/15 - ST-984
#pragma mark - Keyboard Methods

- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeShown:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
}

// Called when the UIKeyboardWillShowNotification is sent.
- (void)keyboardWillBeShown:(NSNotification*)aNotification
{
    NSDictionary *info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    contactsSubViewController.tableView.contentInset = contentInsets;
    contactsSubViewController.tableView.scrollIndicatorInsets = contentInsets;
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    contactsSubViewController.tableView.contentInset = contentInsets;
    contactsSubViewController.tableView.scrollIndicatorInsets = contentInsets;
}



#pragma mark - Accessors

- (STUser *)userForUserId:(NSString *)userId
{
    __block STUser *user = nil;
    [STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        user = [transaction objectForKey:userId inCollection:kSCCollection_STUsers];
    }];

    return user;
}

@end
