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
#import "SettingsViewController.h"

#import "AccountsTableViewCell.h"
#import "ActivationVCDelegate.h"
#import "AddressBookManager.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "AppTheme.h"
#import "AppThemePickerPhoneViewController.h"
#import "AppThemePickerViewController.h"
#import "AvatarManager.h"
#import "ContactsViewController.h"
#import "ConversationViewController.h"
#import "FakeStream.h"
#import "LicensesViewController.h"
#import "MessageStreamManager.h"
#import "MessagesViewController.h"
#import "MZAlertView.h"
#import "UserInfoVC.h"
#import "OHActionSheet.h"
#import "OnboardViewController.h"
#import "PasscodeViewController.h"
#import "PrivacyViewController.h"
#import "SCBrandTableHeaderFooterView.h"
#import "SCDatabaseLoggerVC.h"
#import "SCDateFormatter.h"
#import "SCPasscodeManager.h"
#import "SCRecoveryKeyScannerController.h"
#import "SCRecoveryKeyViewController.h"
#import "SCTPopoverDelegte.h"
#import "SilentTextStrings.h"
#import "SoundsViewController.h"
#import "STPreferences.h"
#import "STConversation.h"
#import "STLocalUser.h"
#import "STLogging.h"
#import "STPublicKey.h"
#import "STSymmetricKey.h"
#import "STUserManager.h"
#import "VersionViewController.h"

// Categories
#import "UIImage+Thumbnail.h"
#import "UIImage+maskColor.h"

// Log levels: off, error, warn, info, verbose
#import "git_version_hash.h"

#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG && eric_turner
static const int ddLogLevel = LOG_LEVEL_VERBOSE | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_INFO;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

#if DEBUG
  #define DEBUG_SETTINGS  1
#else
  #define DEBUG_SETTINGS  0 // Don't change me!
#endif

#ifndef ENABLE_DEBUG_LOGGING
#error Requires #import "AppConstants.h" for ENABLE_DEBUG_LOGGING definition
#endif

static const NSUInteger Section_Accounts = 0;
static const NSUInteger Section_Contacts = 1;
static const NSUInteger Section_Options  = 2;
#if ENABLE_DEBUG_LOGGING
static const NSUInteger Section_Debug    = 3;
static const NSUInteger Section_About    = 4;
static const NSUInteger Section_Last     = Section_About;
#else
static const NSUInteger Section_Debug    = 999;
static const NSUInteger Section_About    = 3;
static const NSUInteger Section_Last     = Section_About;
#endif

static const NSUInteger Options_Row_Passcode = 0;
static const NSUInteger Options_Row_Privacy  = 1;
static const NSUInteger Options_Row_Themes   = 2;
static const NSUInteger Options_Row_Sounds   = 3;
static const NSUInteger Options_Row_Recovery = 4;
static const NSUInteger Options_Row_TouchID  = 5;

//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Wunused-variable"

static const NSUInteger Debug_Row_EnableDebugging = 0;
static const NSUInteger Debug_Row_Logs            = 1;
static const NSUInteger Debug_Row_Report          = 2;
static const NSUInteger Debug_Row_FakeStream      = 3;
static const NSUInteger Debug_Row_Burst           = 4;
static const NSUInteger Debug_Row_Last            = (DEBUG_SETTINGS ? Debug_Row_Burst : Debug_Row_Report);

//#pragma clang diagnostic pop

NSString *const kAccountsTableViewCellIdentifier = @"AccountsTableViewCell";


@interface SettingsViewController() <MSCMoreOptionTableViewCellDelegate,
                                     AccountsTableViewCellDelegate,
                                     ActivationVCDelegate,
                                     SCRecoveryKeyViewControllerDelegate,
                                     SCTPopoverDelegte>
@end

@implementation SettingsViewController
{
	YapDatabaseConnection *uiDatabaseConnection;
	
	NSArray *localUsers;
	NSMutableDictionary *unreadCounts; // key=localUser.uuid, value=NSNumber(unreadCount)
	
	AppTheme *theme;
	
	UILabel *titleLabel;
	
	UIImage * bgImage;
	UIImage * defaultImage;
	UIImage * attentionImage;
    UIImage * expiredImage;
	
	NSString * appVersion;
    
    UIPopoverController * userInfoPopController;
    UIPopoverController * privacyPopController;
    UIPopoverController * versionPopController;

	BOOL temporarilyHidingPopover;
	CGRect popoverFromRect;
	CGSize popoverContentSize;
    
    UITableViewHeaderFooterView* accountHeader;
	MZAlertView *pcAlert;
    
	STConversation *lastConversation;

	BOOL hasBioMetrics;
}

@synthesize popoverController = popoverController;

- (id)init
{
	if ((self = [super init]))
	{
        bgImage        =  [UIImage imageNamed:@"logoicon"];
        defaultImage   =  [UIImage imageNamed:@"silhouette.png"];
        attentionImage = [[UIImage imageNamed:@"attention"] scaledToHeight:30];
        expiredImage   =  [UIImage imageNamed:@"expired"];
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
	
	uiDatabaseConnection = STDatabaseManager.uiDatabaseConnection;
	
	[self changeTheme:nil];
  
	[self setupTitleLabel];
	titleLabel.text = NSLocalizedString(@"Settings", @"Settings");
	[titleLabel sizeToFit];
	
	NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    BOOL isDebug = [AppConstants isApsEnvironmentDevelopment];
	
	if (isDebug) // include build number
	{
		NSString *build = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
		appVersion = [NSString stringWithFormat: @"%@ (%@)", version, build];
	}
	else
	{
		appVersion = version;
	}
    
	UINib *accountsCellNib = [UINib nibWithNibName:@"AccountsTableViewCell" bundle:nil];
	[self.tableView registerNib:accountsCellNib forCellReuseIdentifier:kAccountsTableViewCellIdentifier];
	
    accountHeader = [[[NSBundle mainBundle] loadNibNamed:@"AccountsTableHeaderView" owner:self options:nil] lastObject];
    
    
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(databaseConnectionDidUpdate:)
	                                             name:UIDatabaseConnectionDidUpdateNotification
	                                           object:STDatabaseManager];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(changeTheme:)
												 name:kAppThemeChangeNotification
											   object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(messageStreamStateChange:)
												 name:MessageStreamDidChangeStateNotification
											   object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(prefsChanged:)
												 name:PreferencesChangedNotification
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(applicationWillResignActive)
												 name:UIApplicationWillResignActiveNotification
											   object:nil];
    
    
    // Updated to use rebranded logo: SCBrandTableHeaderFooterView.xib
    UINib *tableFooterNib = [UINib nibWithNibName:SCBrandTableHeaderFooterView_ID bundle:nil];
    [self.tableView registerNib:tableFooterNib forHeaderFooterViewReuseIdentifier:SCBrandTableHeaderFooterView_ID];
}

- (void)viewWillAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillAppear:animated];
	
	[self reloadData];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Application Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)applicationWillResignActive
{
	DDLogAutoTrace();
	
	[pcAlert dismissWithClickedButtonIndex:0 animated:NO];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View Preferences
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)prefersStatusBarHidden
{
	return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
	if (theme.navBarIsBlack)
		return UIStatusBarStyleLightContent;
	else
		return UIStatusBarStyleDefault;
}

- (void)changeTheme:(NSNotification *)notification
{
	NSDictionary *userInfo = notification.userInfo;
	if (userInfo)
		theme = userInfo[kNotificationUserInfoTheme];
	else
		theme = [AppTheme getThemeBySelectedKey];
	
	
	if (theme.navBarIsBlack)
		self.navigationController.navigationBar.barStyle =  UIBarStyleBlackTranslucent;
	else
		self.navigationController.navigationBar.barStyle =  UIBarStyleDefault;
	
	if (theme.navBarIsBlack)
		titleLabel.textColor = [UIColor whiteColor];
	else
		titleLabel.textColor = [UIColor blackColor];
    
	if (theme.appTintColor)
		self.view.tintColor = theme.appTintColor;
	else
		self.view.tintColor = [STAppDelegate originalTintColor];

	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:Options_Row_Themes inSection:Section_Options];
	UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
	cell.detailTextLabel.text = [AppTheme getSelectedKey];

	[self setNeedsStatusBarAppearanceUpdate];
	[self reloadData];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Autorotation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (NSUInteger)navigationControllerSupportedInterfaceOrientations:(UINavigationController *)navigationController
{
	return [(UIViewController *) (navigationController.viewControllers[0]) supportedInterfaceOrientations];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)messageStreamStateChange:(NSNotification *)notification
{
    [self reloadData];
}

- (void)prefsChanged:(NSNotification *)notification
{
    NSString *prefs_key = [notification.userInfo objectForKey:PreferencesChangedKey];
    
	if ([prefs_key isEqualToString:prefs_experimentalFeatures]    ||
		[prefs_key hasPrefix:prefs_prefix_selectedConversationId]  )
	{
		[self reloadData];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setupTitleLabel
{
	if (titleLabel == nil)
	{
		titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		titleLabel.backgroundColor = [UIColor clearColor];
		titleLabel.font = [[UIFont preferredFontForTextStyle:UIFontTextStyleCaption2] fontWithSize:20];
		titleLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.5];
		titleLabel.shadowOffset = CGSizeZero;
		titleLabel.textAlignment = NSTextAlignmentCenter;
		titleLabel.userInteractionEnabled = NO;
		titleLabel.adjustsFontSizeToFitWidth = NO;
		
		if (theme.navBarIsBlack)
			titleLabel.textColor = [UIColor whiteColor];
		else
			titleLabel.textColor = [UIColor blackColor];
		
		self.navigationItem.titleView = titleLabel;
	}
}

- (void)reloadData
{
#if DEBUG_SETTINGS
    hasBioMetrics = [SCPasscodeManager canUseBioMetricsWithError:NULL];
#endif
	
	if ([STPreferences experimentalFeatures])
	{
		_addAccountsButton.enabled = YES;
		_addAccountsButton.hidden = NO;
	}
	else
	{
		_addAccountsButton.enabled = NO;
		_addAccountsButton.hidden = YES;
	}
	
	STLocalUser *currentUser = STDatabaseManager.currentUser;
    NSString *currentConversationId = [STPreferences selectedConversationIdForUserId:currentUser.uuid];
    
  	NSMutableArray *newLocalUsers = [[NSMutableArray alloc] init];
	
	if (unreadCounts == nil)
		unreadCounts = [[NSMutableDictionary alloc] init];
	else
		[unreadCounts removeAllObjects];
	
	[uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
        lastConversation = [transaction objectForKey:currentConversationId inCollection:currentUser.uuid];

		[[transaction ext:Ext_View_LocalContacts] enumerateKeysAndObjectsInGroup:@"" usingBlock:
		    ^(NSString *collection, NSString *key, STUser *localUser, NSUInteger index, BOOL *stop)
		{
			[newLocalUsers addObject:localUser];
			
			NSUInteger totalUnread =
			  [STDatabaseManager numberOfUnreadMessagesForUser:localUser.uuid withTransaction:transaction];
			
			[unreadCounts setObject:@(totalUnread) forKey:localUser.uuid];
		}];
    }];
	
	[newLocalUsers sortUsingComparator:^NSComparisonResult(STUser *user1, STUser *user2) {
		
		NSString *name1 = user1.displayName;
		NSString *name2 = user2.displayName;
		
		return [name1 localizedStandardCompare:name2];
	}];
        
	localUsers = [newLocalUsers copy];
        
	[self.tableView reloadData];
}


- (void)databaseConnectionDidUpdate:(NSNotification *)notification
{
	NSArray *notifications = [notification.userInfo objectForKey:kNotificationsKey];
	
	BOOL localUsersChanged =
	  [[uiDatabaseConnection ext:Ext_View_LocalContacts] hasChangesForNotifications:notifications];
	
	BOOL unreadCountChanged =
	  [[uiDatabaseConnection ext:Ext_View_Unread] hasChangesForNotifications:notifications];
	
	BOOL currentUserIDChanged =
	  [uiDatabaseConnection hasChangeForKey:prefs_selectedUserId
	                           inCollection:kSCCollection_Prefs
	                        inNotifications:notifications];
	
	if (localUsersChanged || unreadCountChanged || currentUserIDChanged)
	{
		[self reloadData];
	}
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Popover
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)popupViewController:(UIViewController *)viewController pointTo:(CGRect)rect
{
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
	
	if (AppConstants.isIPhone)
    {
		navController.delegate = self;
		navController.navigationBar.translucent = YES;
        navController.modalPresentationStyle = UIModalPresentationFullScreen;
		if (theme.navBarIsBlack)
			navController.navigationBar.barStyle =  UIBarStyleBlackTranslucent;
		else
			navController.navigationBar.barStyle =  UIBarStyleDefault;
		
		[self presentViewController:navController animated:YES completion:NULL];
    }
    else
    {
        // always start with a fresh popover
        if (popoverController.popoverVisible)
        {
            [popoverController dismissPopoverAnimated:YES];
            popoverController = nil;
        }
        
        popoverController = [[UIPopoverController alloc] initWithContentViewController:navController];
 		
		if ([viewController respondsToSelector:@selector(preferredPopoverContentSize)])
		{
			// This is here as PrivacyViewController ends up not loading its view when we
			// use setContentViewcController instead of initWith...
			(void)[viewController view];
			
			popoverContentSize = [(id)viewController preferredPopoverContentSize];
		}
		else {
			popoverContentSize = viewController.view.frame.size;
		}
		
		popoverContentSize.height += navController.navigationBar.frame.size.height;
		
		popoverController.popoverContentSize = popoverContentSize;
		popoverController.delegate = self;
		
		popoverFromRect = rect;

        [popoverController presentPopoverFromRect:rect
		                                   inView:self.tableView
		                 permittedArrowDirections:UIPopoverArrowDirectionLeft
		                                 animated:YES];
		
		temporarilyHidingPopover = NO;
	}
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)sender
{
	DDLogAutoTrace();
	
	if (popoverController == sender) {
		popoverController = nil;
	}
}

// Public dismiss popover (renamed from popoverNeedsDismiss)
- (void)dismissPopover
{
    DDLogAutoTrace();
    [popoverController dismissPopoverAnimated:NO];
    [self popoverControllerDidDismissPopover:popoverController];
}


#pragma mark SCTPopoverDelegate
// To support public call to dismiss - moved dismissal to public dismissPopover method
- (void)popoverNeedsDismiss
{
    DDLogAutoTrace();
    [self dismissPopover];
}

- (void)popoverNeedsDismissAnimated
{
    DDLogAutoTrace();
    [popoverController dismissPopoverAnimated:YES];
    
    // Call to clear popverController ivar after animation delay
    __weak typeof (self) weakSelf = self;
    __weak typeof (UIPopoverController) *weakPopCon = popoverController;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf popoverControllerDidDismissPopover:weakPopCon];
    });
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITableView
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return Section_Last + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	switch (section)
	{
		case Section_Accounts:
		{
			return (localUsers.count  > 0) ? localUsers.count : 1;
		}
		case Section_Contacts:
		{
			return 1;
		}
        case Section_Options:
		{
            return [STPreferences experimentalFeatures]
					? (hasBioMetrics ? 6 : 5)
			        : 4;
		}
		case Section_Debug:
		{
			return Debug_Row_Last + 1;
		}
		case Section_About:
		{
			return 1;
		}
    }
	
	return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
	if (section == Section_Accounts)
		return accountHeader.frame.size.height;
	else
		return 30;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
	if(section == Section_About)
		return 140;
	else
		return 0;
}

- (CGFloat)tableView:(UITableViewCell*)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	// Possible fix for cell not showing up properly on IOS 8?
	// See https://devforums.apple.com/message/991443#991443
	
	return 44;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	switch (section)
	{
		case Section_Accounts : return NSLocalizedString(@"Accounts", "Accounts");
		case Section_Contacts : return NSLocalizedString(@"Contacts Book", "Contacts Book");
		case Section_Options  : return NSLocalizedString(@"Options", "Options");
		case Section_Debug    : return NSLocalizedString(@"Debugging", "Debugging");
		case Section_About    : return NSLocalizedString(@"About", "About");
	}
	
	return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
	if (section == Section_Accounts)
		return accountHeader;
	else
		return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    NSInteger const lastSection = [tableView numberOfSections] -1;
    
    if (section == lastSection)
    {
        NSString * const footerViewID = SCBrandTableHeaderFooterView_ID;
        return [tableView dequeueReusableHeaderFooterViewWithIdentifier:footerViewID];
    }
	
	return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == Section_Accounts)
	{
		AccountsTableViewCell *cell = (AccountsTableViewCell *)
		  [tableView dequeueReusableCellWithIdentifier:kAccountsTableViewCellIdentifier];
		
		if ([localUsers count] == 0)
		{
			cell.userName.text = NSLocalizedString(@"Add Account", @"Add Account");
			cell.userName.textColor = [UIColor grayColor];
			
			[cell.userAvatar setImage:nil forState:UIControlStateNormal];
			
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
		else
		{
			STLocalUser *localUser = [localUsers objectAtIndex:indexPath.row];
			
			NSString *userName = localUser.displayName;
			
			NSUInteger unread = [[unreadCounts objectForKey:localUser.uuid] unsignedIntegerValue];
			if (unread > 0)
			{
				userName = [userName stringByAppendingFormat:@" (%lu)", (unsigned long)unread];
			}
			
			if (![localUser.networkID isEqualToString:kNetworkID_Production])
			{
				userName = [NSString stringWithFormat:@"• %@", userName];
			}
			
			cell.userName.text = userName;
			cell.userName.textColor = localUser.isEnabled ? [UIColor blackColor] : [UIColor grayColor];
			
			BOOL isSelected = [STDatabaseManager.currentUser.uuid isEqualToString:localUser.uuid];
			
			if (isSelected)
				cell.accessoryType = UITableViewCellAccessoryCheckmark;
			else
				cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
			
			CGFloat avatarHeight = 30;
			CGFloat avatarCornerRadius = 4;
			
			UIImage *avatar = [[AvatarManager sharedInstance] cachedAvatarForUser:localUser
			                                                       scaledToHeight:avatarHeight
			                                                     withCornerRadius:avatarCornerRadius
			                                                      defaultFallback:YES];
			
			if (localUser.subscriptionHasExpired)
			{
				cell.userName.textColor = [UIColor redColor];
				cell.userName.font = [UIFont italicSystemFontOfSize:17.0];
				
				UIImage *image = [expiredImage maskWithColor:[UIColor redColor]];
				[cell.userAvatar setImage:image forState:UIControlStateNormal];
				
				[cell.activity stopAnimating];
			}
			else if (!localUser.isEnabled)
			{
				cell.userName.font = [UIFont boldSystemFontOfSize:17.0];
				cell.userName.textColor = [UIColor grayColor];
				
				[cell.userAvatar setImage:avatar forState:UIControlStateNormal];
				
				[cell.activity stopAnimating];
			}
			else
			{
				MessageStream *ms = [MessageStreamManager existingMessageStreamForUser:localUser];
				MessageStream_State state = ms.state;
                
                switch (state)
                {
                    case MessageStream_State_Disconnected:
                    {
						cell.userName.font = [UIFont boldSystemFontOfSize:17.0];
						cell.userName.textColor = [UIColor blackColor];
						
                        [cell.userAvatar setImage:avatar forState:UIControlStateNormal];
						
                        [cell.activity stopAnimating];
                        break;
                    }
                    case MessageStream_State_Connecting:
                    {
						cell.userName.font = [UIFont systemFontOfSize:17.0];
						cell.userName.textColor = [UIColor blackColor];
						
						[cell.userAvatar setImage:nil forState:UIControlStateNormal];
						
						[cell.activity startAnimating];
						break;
                    }
                    case MessageStream_State_Connected:
					{
						cell.userName.font = [UIFont boldSystemFontOfSize:17.0];
						cell.userName.textColor = [UIColor colorWithRed:0.215686 green:0.337255 blue:0.525490 alpha:1];
						
						[cell.userAvatar setImage:avatar forState:UIControlStateNormal];
						
						[cell.activity stopAnimating];
						break;
					}
					case MessageStream_State_Error:
					{
						cell.userName.font = [UIFont italicSystemFontOfSize:17.0];
						cell.userName.textColor = [UIColor redColor];
						
						[cell.userAvatar setImage:attentionImage forState:UIControlStateNormal];
						
						[cell.activity stopAnimating];
						break;
                    }
				}
			}
			
			NSString *localUserID = localUser.uuid;
			cell.userID = localUserID;
			
			[[AvatarManager sharedInstance] fetchAvatarForUser:localUser
			                                    scaledToHeight:avatarHeight
			                                  withCornerRadius:avatarCornerRadius
			                                   completionBlock:^(UIImage *image)
			{
				// Since the fetchAvatar method is asynchronous,
				// the cell may have been recycled since the original request.
				if ([cell.userID isEqualToString:localUserID])
				{
					MessageStream *ms = [MessageStreamManager existingMessageStreamForUser:localUser];
					MessageStream_State state = ms.state;
					
					if (state == MessageStream_State_Disconnected ||
					    state == MessageStream_State_Connected)
					{
						[cell.userAvatar setImage:image forState:UIControlStateNormal];
					}
				}
			}];
			
			cell.delegate = self;
		}
		
		return cell;
	}
	else if (indexPath.section == Section_Contacts)
	{
		NSString *identifier = @"Settings-Contacts";
		
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
		}
		
		cell.textLabel.textColor = [UIColor blackColor];
		cell.textLabel.text = NSLocalizedString(@"Silent Contacts", @"Settings label");
		
		cell.detailTextLabel.text = nil;
		
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		
		return cell;
	}
	else if (indexPath.section == Section_Options)
	{
		NSString *identifier = @"Settings-Options";
		
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
		
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
		}
		
		switch (indexPath.row)
		{
			case Options_Row_Passcode:
			{
				cell.textLabel.text = NSLocalizedString(@"Passcode Lock", @"Settings label");
				
				if ([STAppDelegate.passcodeManager hasKeyChainPassCode])
					cell.detailTextLabel.text = NSLocalizedString(@"Off", @"Off");
				else
					cell.detailTextLabel.text =
					  [NSString stringWithFormat:NSLocalizedString(@"After %@", @"After %@"), [self delayInString]];
				
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
				break;
			}
			case Options_Row_Privacy:
			{
				cell.textLabel.text = NSLocalizedString(@"Privacy", @"Privacy label");
				cell.detailTextLabel.text = nil;
				
				cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
				break;
			}
			case Options_Row_Themes:
			{
				NSString *themeKey = [AppTheme getSelectedKey];
				AppTheme *theTheme = [AppTheme getThemeByKey: themeKey];
				
				cell.textLabel.text =  NSLocalizedString(@"Theme", @"Themes label");
   				cell.detailTextLabel.text = theTheme.localizedName;
				
				cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
				break;
			}
			case Options_Row_Sounds:
			{
				cell.textLabel.text = NSLocalizedString(@"Sounds", @"Settings label");
				cell.detailTextLabel.text = nil;
				
				cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
				break;
			}
            case Options_Row_Recovery:
            {
                cell.textLabel.text = NSLocalizedString(@"Recovery Key", @"Recovery Key");
                cell.detailTextLabel.text = nil;
				
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
             }
            case Options_Row_TouchID:
            {
                cell.textLabel.text = NSLocalizedString(@"TouchID", @"TouchID");
                cell.detailTextLabel.text = nil;
				
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            }
		}
		
		return cell;
	}
 	else if (indexPath.section == Section_Debug)
	{
		NSString *identifier = @"Settings-Debug";
		
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
		}
		
		cell.textLabel.textColor = [UIColor blackColor];
		
		if (indexPath.row == Debug_Row_EnableDebugging)
		{
			cell.textLabel.text = NSLocalizedString(@"Debug Logging", @"Settings option - toggles debug logging");
			cell.detailTextLabel.text = nil;
			
			UISwitch *debugSwitch = [[UISwitch alloc] init];
			[debugSwitch addTarget:self
			                action:@selector(debugLoggingSwitchToggled:)
			      forControlEvents:UIControlEventTouchUpInside];
			
			if (STAppDelegate.databaseLoggerEnabled)
				debugSwitch.on = YES;
			else
				debugSwitch.on = NO;
			
			cell.accessoryType = UITableViewCellAccessoryNone;
			cell.accessoryView = debugSwitch;
		}
		else if (indexPath.row == Debug_Row_Logs)
		{
			cell.textLabel.text = NSLocalizedString(@"Debug Logs", @"Settings option - displays debug logs");
			cell.detailTextLabel.text = nil;
			
			cell.accessoryView = nil;
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
		else if (indexPath.row == Debug_Row_Report)
		{
			cell.textLabel.text = NSLocalizedString(@"Report Problem", @"Settings option - report problem");
			cell.detailTextLabel.text = nil;
			
			cell.accessoryView = nil;
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
		else if (indexPath.row == Debug_Row_FakeStream)
		{
			cell.textLabel.text = @"FakeStream";
			cell.detailTextLabel.text = [[FakeStream sharedInstance] isRunning] ? @"√" : @"";
			
			cell.accessoryView = nil;
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
        else if (indexPath.row == Debug_Row_Burst)
 		{
			NSString *userString = @"<none>";
			if (lastConversation)
			{
				if (lastConversation.isMulticast) {
					userString = lastConversation.title.length ? lastConversation.title : lastConversation.threadID;
				}
				else {
					userString = [lastConversation.remoteJid user];
				}
			}
			
            cell.textLabel.text = [NSString stringWithFormat:@"Burst: %@",userString];
            cell.detailTextLabel.text = nil;
			
			cell.accessoryView = nil;
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
		
		return cell;
	}
	else if (indexPath.section == Section_About)
	{
		NSString *identifier = @"Settings-About";
		
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
		if (cell == nil) {
			cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
		}
		
		cell.textLabel.text = NSLocalizedString(@"Version", @"Version label");
		cell.detailTextLabel.text = appVersion;
		
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		
		return cell;
	}
	else
	{
		DDLogWarn(@"Unhandled section: %lu", (unsigned long)(indexPath.section));
		
		return nil;
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	if (indexPath.section == Section_Accounts)
	{
		if (localUsers.count > 0)
		{
			STUser *localUser = [localUsers objectAtIndex:indexPath.row];
			[self changeUser:localUser.uuid];
		}
		else
		{
			UIStoryboard *activationStoryboard = [UIStoryboard storyboardWithName:@"Activation" bundle:nil];
			LogInViewController *lvc =
			  [activationStoryboard instantiateViewControllerWithIdentifier:@"LogInViewController"];
			
			lvc.delegate = self;
			lvc.isInPopover = YES;
			lvc.isModal = AppConstants.isIPhone;
			lvc.existingUserID = NULL;
			
			[self popupViewController:lvc pointTo:[self.tableView rectForRowAtIndexPath:indexPath]];
		}
	}
	else if (indexPath.section == Section_Contacts)
	{
		[self showContacts];
	}
	else if (indexPath.section == Section_Options)
	{
		if (indexPath.row == Options_Row_Themes)
		{
			NSString *navTitle;
			if ([localUsers count] > 0)
			{
				NSString *name = STDatabaseManager.currentUser.firstName;
				if (name == nil)
					name = STDatabaseManager.currentUser.jid.user;
				
				NSString *frmt = NSLocalizedString(@"Theme for %@", @"Theme for <name>");
				navTitle = [NSString stringWithFormat:frmt, name];
			}
			else
			{
				navTitle = NSLocalizedString(@"Theme", @"Themes label");
			}
					
			if (AppConstants.isIPhone)
			{
				AppThemePickerPhoneViewController* atvc = [[AppThemePickerPhoneViewController alloc] init];
				atvc.navigationItem.title = navTitle;
				
				[self popupViewController:atvc pointTo:[self.tableView rectForRowAtIndexPath:indexPath]];
			}
			else
			{
				AppThemePickerViewController* atvc = [[AppThemePickerViewController alloc] init];
				atvc.delegate = self;
				atvc.navigationItem.title = navTitle;
				
				[self popupViewController:atvc pointTo:[self.tableView rectForRowAtIndexPath:indexPath]];
			}
			
		}
		else if (indexPath.row == Options_Row_Sounds)
		{
			SoundsViewController *svc = [[SoundsViewController alloc] initWithProperNib];
			[self popupViewController:svc pointTo:[self.tableView rectForRowAtIndexPath:indexPath]];
					
		}
		else if (indexPath.row == Options_Row_Passcode)
		{
			[self handlePasscodeTap];
					
		}
		else if (indexPath.row == Options_Row_Privacy)
		{
			PrivacyViewController* pvc  = [[PrivacyViewController alloc] initWithProperNib ];
			[self popupViewController:pvc pointTo:[self.tableView rectForRowAtIndexPath:indexPath]];
			
		}
		else if (indexPath.row == Options_Row_Recovery)
		{
			[self recoveryKeyAtIndexPath:indexPath];
                    
		}
        else if (indexPath.row == Options_Row_TouchID)
		{
			[self touchIDAtIndexPath:indexPath];
                    
		}
		
	}
	else if (indexPath.section == Section_Debug)
	{
		if (indexPath.row == Debug_Row_Logs)
		{
			SCDatabaseLoggerVC *loggerVC = [SCDatabaseLoggerVC initWithProperStoryboard];
			
			loggerVC.modalPresentationStyle = UIModalPresentationFullScreen;
			loggerVC.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
			
			[STAppDelegate.window.rootViewController presentViewController:loggerVC animated:YES completion:NULL];
		}
		else if (indexPath.row == Debug_Row_Report)
		{
			UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"SubmitLogFile" bundle:nil];
			UINavigationController *nav = [storyboard instantiateInitialViewController];
			
			nav.modalPresentationStyle = UIModalPresentationFullScreen;
			nav.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
			
			[STAppDelegate.window.rootViewController presentViewController:nav animated:YES completion:NULL];
		}
		else if (indexPath.row == Debug_Row_FakeStream)
		{
			FakeStream *fs = [FakeStream sharedInstance];
			if (fs.isRunning)
				[fs stop];
			else
				[fs start];
			
			[self.tableView reloadData];
					
		}
        else if (indexPath.row == Debug_Row_Burst)
		{
			[self burstTest];
		}
		
	}
	else if (indexPath.section == Section_About)
	{
		VersionViewController* vvc  = [[VersionViewController alloc] initWithProperNib ];
		[self popupViewController:vvc pointTo:[self.tableView rectForRowAtIndexPath:indexPath]];

    }
}


- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.section == Section_Accounts)
		return YES;
	else
		return NO;
}


- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
                                            forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete)
	{
		if (indexPath.section == Section_Accounts)
		{
			[self deleteUserAtIndexPath:indexPath];
		}
	}
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000

// this only works on IOS-8 SDK

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewRowAction *deleteAction;
	deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault
	                                                  title:@"Delete"
	                                                handler:^(UITableViewRowAction *action, NSIndexPath *indexPath)
	{
		[self deleteUserAtIndexPath:indexPath];
	}];
	
	UITableViewRowAction *moreAction;
 	moreAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault
	                                                title:@"More…"
	                                              handler:^(UITableViewRowAction *action, NSIndexPath *indexPath)
	{
		[self tableView:self.tableView moreOptionButtonPressedInRowAtIndexPath:indexPath];
	}];
	
	moreAction.backgroundColor = [UIColor grayColor];
    deleteAction.backgroundColor = [UIColor redColor];
    
    return @[deleteAction, moreAction];
}
#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark MSCMoreOptionTableViewCellDelegate methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Tells the delegate that the "More" button for specified row was pressed.
**/
- (void)tableView:(UITableView *)tableView moreOptionButtonPressedInRowAtIndexPath:(NSIndexPath *)indexPath
{
	STLocalUser *localUser = nil;
	
	if (indexPath && indexPath.row < [localUsers count])
	{
		localUser = [localUsers objectAtIndex:indexPath.row];
	}
	
	if (localUser == nil) return;
	
	UITableViewCell *pressedCell = [self.tableView cellForRowAtIndexPath:indexPath];
	CGRect cellRect = pressedCell.frame;
//	cellRect.origin.y += cellRect.size.height * 0.5;
//	cellRect.origin.y -= self.tableView.contentOffset.y;
	
	MessageStream *ms = [MessageStreamManager messageStreamForUser:localUser];
	
	NSString *alertTitle = @"";
	NSArray *alertOptions = NULL;
	
	if (!localUser.isActivated)
	{
		NSString *frmt = NSLocalizedString(@"%@ is not authorized", @"%@ is not authorized");
		
		alertTitle = [NSString stringWithFormat:frmt, localUser.displayName];
		alertOptions = @[ NSLS_USER_ACTIVATE];
	}
	else if (!localUser.isEnabled)
	{
		NSString *frmt = NSLocalizedString(@"%@ is not enabled", @"%@ is not enabled");
		
		alertTitle = [NSString stringWithFormat:frmt, localUser.displayName];
		alertOptions = @[NSLS_COMMON_GO_ONLINE, NSLS_USER_DEACTIVATE];
	}
	else
	{
		switch (ms.state)
		{
			case MessageStream_State_Disconnected:
			{
				NSString *frmt = NSLocalizedString(@"%@ is not enabled", @"%@ is not enabled");
				
				alertTitle = [NSString stringWithFormat:frmt, localUser.displayName];
				alertOptions = @[NSLS_COMMON_GO_ONLINE, NSLS_USER_DEACTIVATE];
				
				break;
			}
			case MessageStream_State_Connecting:
			{
				NSString *frmt = NSLocalizedString(@"%@ is in the process of connecting",
												   @"%@ is in the process of connecting");
				
				alertTitle = [NSString stringWithFormat:frmt, localUser.displayName];
				alertOptions = @[NSLS_COMMON_GO_OFFLINE,  NSLS_USER_DEACTIVATE];
				
				break;
			}
			case MessageStream_State_Connected:
			{
				NSString *frmt = NSLocalizedString(@"%@ is enabled", @"%@ is enabled");
				
				alertTitle = [NSString stringWithFormat:frmt, localUser.displayName];
				alertOptions = @[NSLS_COMMON_GO_OFFLINE, NSLS_USER_DEACTIVATE];
				
				break;
			}
			case MessageStream_State_Error:
			{
				NSString *errorString = ms.errorString;
				if (errorString == nil)
					errorString = NSLocalizedString(@"Unknown", @"Unknown");
				
				NSString *frmt = NSLocalizedString(@"%@ was unable to connect. Error \"%@\"",
												   @"%@ was unable to connect. Error \"%@\"");
				
				alertTitle = [NSString stringWithFormat:frmt, localUser.displayName, errorString];
				alertOptions = @[NSLS_COMMON_GO_OFFLINE, NSLS_COMMON_TRY_AGAIN , NSLS_USER_DEACTIVATE];
				
				break;
			}
		}
	}
	
    [OHActionSheet showFromRect:cellRect 
                       sourceVC:self 
                         inView:self.view
                 arrowDirection:UIPopoverArrowDirectionLeft
                          title:alertTitle
              cancelButtonTitle:NSLS_COMMON_CANCEL
         destructiveButtonTitle:NULL
              otherButtonTitles:alertOptions
                     completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
	{
		NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
		
		if ([choice isEqualToString:NSLS_COMMON_GO_ONLINE])
		{
			[self updateUserState:localUser.uuid enable:YES];
		}
		else if ([choice isEqualToString:NSLS_COMMON_TRY_AGAIN])
		{
			[self updateUserState:localUser.uuid enable:YES];
		}
		else if ([choice isEqualToString:NSLS_COMMON_GO_OFFLINE])
		{
			[self updateUserState:localUser.uuid enable:NO];
		}
		else if ([choice isEqualToString:NSLS_USER_DEACTIVATE])
		{
			[[STUserManager sharedInstance] deactivateUser:localUser.uuid andDeprovision:YES completionBlock:^{
				
				[[MessageStreamManager messageStreamForUser:localUser] disconnect];
				[self reloadData];
			}];
		}
		else if ([choice isEqualToString:NSLS_USER_ACTIVATE])
		{
			UIStoryboard *activationStoryboard = [UIStoryboard storyboardWithName:@"Activation" bundle:nil];
			
			LogInViewController *lvc =
			  [activationStoryboard instantiateViewControllerWithIdentifier:@"LogInViewController"];
			lvc.delegate = self;
			lvc.isInPopover = YES;
			lvc.existingUserID = localUser.uuid;
			lvc.isModal = AppConstants.isIPhone;
			
			[self popupViewController:lvc pointTo:[self.tableView rectForRowAtIndexPath:indexPath]];
			
			// Why are we reloading the data here?
			// We haven't changed the data.
			// We only presented another view controller.
			[self reloadData];
		}
		
	}]; // end OHActionSheet
}

/**
 * If not implemented or returning nil the "More" button will not be created and the
 * cell will act like a common UITableViewCell.
 *
 * The "More" button also supports multiline titles.
**/
- (NSString *)tableView:(UITableView *)tableView titleForMoreOptionButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ([AppConstants isIOS8OrLater])
	{
		return nil;
	}
	else
	{
		return NSLocalizedString(@"More…", @"More…");
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark AccountsTableViewDelegate methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)tableView:(UITableView *)tableView userAvatarButtonTappedAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath && indexPath.row < [localUsers count])
	{
		STUser *localUser = [localUsers objectAtIndex:indexPath.row];
		
		AccountsTableViewCell *cell = (AccountsTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
		
		UserInfoVC *userInfoVC = [[UserInfoVC alloc] initWithUser:localUser];
		[self popupViewController:userInfoVC pointTo:[cell frame]];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateUserState:(NSString *)localUserID enable:(BOOL)enableIn
{
	__block STLocalUser *localUser = nil;

	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        
        localUser = [transaction objectForKey:localUserID inCollection:kSCCollection_STUsers];
		if (localUser)
        {
            localUser = [localUser copy];
            localUser.isEnabled = enableIn;
              
            [transaction setObject:localUser
                            forKey:localUser.uuid
                      inCollection:kSCCollection_STUsers];
        }
		
    } completionBlock:^{
		
		MessageStream *ms = [MessageStreamManager messageStreamForUser:localUser];
		
		if (enableIn)
			[ms connect];
		else
			[ms disconnect];
	}];
}

- (void)changeUser:(NSString *)userId
{
	DDLogAutoTrace();
	
	[STPreferences setSelectedUserId:userId];
	
    //ST-1001: SWRevealController v2.3 update
//	[STAppDelegate.revealController setFrontViewController:STAppDelegate.mainViewController animated:YES];
    [STAppDelegate.revealController pushFrontViewController:STAppDelegate.mainViewController animated:YES];
}

- (void)showContacts
{
	if (AppConstants.isIPhone)
	{
		// Are we already displaying the contacts view ?
		
		UIViewController *frontVC = [STAppDelegate.revealController frontViewController];
		if ([frontVC isKindOfClass:[UINavigationController class]])
		{
			UIViewController *vc = [(UINavigationController *)frontVC topViewController];
			
			if ([vc isKindOfClass:[ContactsViewController class]])
			{
				[STAppDelegate.revealController setFrontViewPosition:FrontViewPositionLeft animated:YES];
				return;
			}
		}
		
		// Create and display the contacts view
		
		ContactsViewController *cvc  = [[ContactsViewController alloc] initWithProperNib];
		UINavigationController *cvcn = [[UINavigationController alloc] initWithRootViewController:cvc];
		
        //ST-1001: SWRevealController v2.3 update
//		[STAppDelegate.revealController setFrontViewController:cvcn animated:YES];
        [STAppDelegate.revealController pushFrontViewController:cvcn animated:YES];
    }
    else
    {
		// Are we already displaying the contacts view ?
		
		Class splitViewClass = [UISplitViewController class];
		
		UIViewController *frontVC = [STAppDelegate.revealController frontViewController];
		if ([frontVC isKindOfClass:splitViewClass])
		{
			UIViewController *vc = nil;
			
			UISplitViewController *splitVC = (UISplitViewController *)frontVC;
			vc = [[splitVC viewControllers] firstObject];
			
			if ([vc isKindOfClass:[UINavigationController class]])
			{
				vc = [(UINavigationController *)vc topViewController];
				
				if ([vc isKindOfClass:[ContactsViewController class]])
				{
					[STAppDelegate.revealController setFrontViewPosition:FrontViewPositionLeft animated:YES];
					return;
				}
			}
		}
		
		ContactsViewController *cvc  = [[ContactsViewController alloc] initWithProperNib];
		UINavigationController *cvcn = [[UINavigationController alloc] initWithRootViewController:cvc];
		
        UserInfoVC *uivc = [[UserInfoVC alloc] initWithUser:nil];
		UINavigationController *uivcn = [[UINavigationController alloc] initWithRootViewController:uivc];		
		cvc.userInfoVC = uivc;
		uivc.isInPopover = NO;
		
		UISplitViewController *splitVC = [[UISplitViewController alloc] init];
		splitVC.minimumPrimaryColumnWidth = 320.F;
		splitVC.maximumPrimaryColumnWidth = 320.F;
		splitVC.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
		splitVC.viewControllers = @[cvcn, uivcn];
		
		//ST-1001: SWRevealController v2.3 update
//		[STAppDelegate.revealController setFrontViewController:splitVC animated:YES];
		[STAppDelegate.revealController pushFrontViewController:splitVC animated:YES];
	}
}

- (void)deleteUserAtIndexPath:(NSIndexPath *)indexPath
{
    DDLogAutoTrace();
	
	STUser *localUser = nil;
	if (indexPath && indexPath.row < localUsers.count)
	{
		localUser = [localUsers objectAtIndex:indexPath.row];
	}
	
	if (localUser == nil) return;
	
	NSString *name = localUser.firstName;
	if (name.length == 0)
		name = localUser.jid.user;
	
	NSString *frmt = NSLocalizedString(@"Delete user \"%@\" and all associated conversations",
	                                   @"Delete user \"%@\" and all associated conversations");
	
    NSString *title = [NSString stringWithFormat:frmt, name];
	
	UITableViewCell *pressedCell = [self.tableView cellForRowAtIndexPath:indexPath];
	CGRect cellRect = pressedCell.frame;

    [OHActionSheet showFromRect:cellRect 
                       sourceVC:self 
                         inView:self.view
                 arrowDirection:UIPopoverArrowDirectionLeft
                          title:title
              cancelButtonTitle:NSLS_COMMON_CANCEL
         destructiveButtonTitle:NSLS_COMMON_DELETE_USER
              otherButtonTitles:NULL
                     completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
	{
		NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
		
		if ([choice isEqualToString:NSLS_COMMON_DELETE_USER])
		{
			[self deleteUser:localUser.uuid];
		}
	}];
}

//ET 10/28/14 - Update to handle clearing the MessagesVC titleButton
- (void)deleteUser:(NSString *)userId
{
    
	[STDatabaseManager asyncDeleteLocalUser:userId completionBlock:^{
     
        // Note: The above transaction is asynchronous.
        // The yapDatabaseModified notification will automatically inform us to update our view
        // once the transaction has completed.

//        __block NSString* fallbackUUID = NULL;
//        [dbConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
//            
//            NSArray *userKeys = [transaction allKeysInCollection: kSCCollection_STUsers];
//            
//            // turn on networking for users
//            for (NSString *userKey in userKeys)
//            {
//                STUser *user;
//                
//                user = [transaction objectForKey:userKey inCollection:kSCCollection_STUsers];
//                
//                if (user.isEnabled && !user.isRemote && !user.subscriptionHasExpired)
//                {
//                    fallbackUUID = user.uuid;
//                    break;
//                    
//                }
//            }
//            
//        } completionBlock:^{
//            
//            // if no current user, either show another or go to add accounts view
//            if (STDatabaseManager.currentUser == nil)
//            {
//                if(fallbackUUID)
//                {
//                    [STPreferences setSelectedUserId:fallbackUUID];
//                }
//            }
//
//        }];
    }];
    
}

- (IBAction)addAccountButtonHit:(id)sender
{
    
    UIStoryboard *activationStoryboard = [UIStoryboard storyboardWithName:@"Activation" bundle:nil];
    OnboardViewController *lvc = [activationStoryboard instantiateViewControllerWithIdentifier:@"OnboardViewController"];
  
	if (AppConstants.isIPhone)
	{
        lvc.isModal = YES;

		CGRect frame = lvc.view.frame;
		frame.size.height -= self.navigationController.navigationBar.frame.size.height;
		lvc.view.frame = frame;
        
	}
    else
    {
        lvc.isInPopover = YES;
    }
	
  //  lvc.existingUserID = NULL;
        lvc.delegate = self;
    
	[self popupViewController:lvc pointTo:((UIView *)sender).frame];
}

- (void)debugLoggingSwitchToggled:(UISwitch *)sender
{
	DDLogGreen(@"debugLogginSwitchToggled: %@", (sender.isOn ? @"YES" : @"NO"));
	
	STAppDelegate.databaseLoggerEnabled = sender.isOn;
	
	NSIndexPath *ip1 = [NSIndexPath indexPathForRow:Debug_Row_EnableDebugging inSection:Section_Debug];
	NSIndexPath *ip2 = [NSIndexPath indexPathForRow:Debug_Row_Logs            inSection:Section_Debug];
	
	NSArray *indexPaths = @[ ip1, ip2 ];
	
	[self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
}

- (void)burstTest
{
	if (lastConversation)
	{
		NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
		[dateFormatter setDateFormat:@"HH:mm:ss:SSS"];
		
		MessageStream *messageStream = [MessageStreamManager messageStreamForUser:STDatabaseManager.currentUser];
		
		const int max_burst = 18;
		
		for(int i = 0; i < max_burst ; i++)
		{
			NSString* messageText = [NSString stringWithFormat:@"burst test:%02d\n%@",
			                                                    i, [dateFormatter stringFromDate:[NSDate date]]];

			Siren *siren = [Siren new];
			siren.message =  messageText;
			siren.testTimestamp = [NSDate date];

			[messageStream sendSiren:siren
			                   toJID:lastConversation.remoteJid
			                withPush:YES
			                   badge:YES
			           createMessage:YES
			              completion:^(NSString *messageId, NSString *conversationId)
			{
				// Optional
			}];
         }
     }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Passcode
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Remove the user specified passhrase and fall back to a keychain passphrase.
**/
- (void)setPasscodeOff
{
	DDLogAutoTrace();
	
	NSError *error = nil;
	[STAppDelegate.passcodeManager removePassphraseWithPassPhraseSource:kPassPhraseSource_Keyboard
	                                                              error:&error];
	
	if (error) {
		DDLogError(@"Error: %@: %@", THIS_METHOD, error);
	}
	
	[self.tableView reloadData];
}

- (void)promptForNewPasscodeWithTitle:(NSString *)title
{
	pcAlert = [[MZAlertView alloc] initWithTitle:title
	                                     message:NSLocalizedString(@"Enter New Passcode", @"Enter New Passcode")
	                                    delegate:nil
	                           cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
	                           otherButtonTitles:NSLocalizedString(@"Next", @"Next"), nil];
	
	pcAlert.alertViewStyle = UIAlertViewStyleSecureTextInput;
	
	__weak SettingsViewController *weakSelf = self;
	[pcAlert setActionViewBlock: ^(UIAlertView *alert, NSInteger buttonPressed, NSString *alertText) {
		
		__strong SettingsViewController *strongSelf = weakSelf;
		if (strongSelf == nil) return;
		
		if (buttonPressed == 1 && alertText.length > 0) // What button is this ??
		{
			NSString *passcodeCandidate = [[alert textFieldAtIndex:0] text];
			[strongSelf promptToReenterPasscode:passcodeCandidate];
		}
	}];
	
	[pcAlert show];
}

- (void)promptToReenterPasscode:(NSString *)passcodeCandidate
{
	pcAlert = [[MZAlertView alloc] initWithTitle:NSLocalizedString(@"Passcode Lock", @"Passcode Lock")
	                                     message:NSLocalizedString(@"Reenter New Passcode", @"Reenter New Passcode")
	                                    delegate:nil
	                           cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
	                           otherButtonTitles:NSLocalizedString(@"Next", @"Next"), nil];

	pcAlert.alertViewStyle = UIAlertViewStyleSecureTextInput;
	
	__weak SettingsViewController *weakSelf = self;
	[pcAlert setActionViewBlock:^(UIAlertView *alert, NSInteger buttonPressed, NSString *alertText) {
		
		__strong SettingsViewController *strongSelf = weakSelf;
		if (strongSelf == nil) return;
		
		if (buttonPressed == 1)
		{
			NSString *passcodeConfirmation = [[alert textFieldAtIndex:0] text];
			if ([passcodeCandidate isEqualToString:passcodeConfirmation])
			{
				NSError *error = NULL;
				[STAppDelegate.passcodeManager updatePassphrase: passcodeConfirmation  error:&error];
				
				[strongSelf.tableView reloadData];
			}
			else
			{
				NSString *title = NSLocalizedString(@"Passcode Mismatch", @"Passcode Mismatch");
				[strongSelf promptForNewPasscodeWithTitle:title];
			}
		}
	}];
	
	[pcAlert show];
}

- (void)promptForPasscodeDelay
{
	pcAlert = [[MZAlertView alloc]
               initWithTitle: NSLocalizedString(@"Passcode Delay",@"Passcode Delay")
               message: nil
               delegate: nil
               cancelButtonTitle:NSLocalizedString(@"Cancel",@"Cancel")
               otherButtonTitles:
               NSLocalizedString(@"5 Seconds",@"5 Seconds"),
               NSLocalizedString(@"15 Seconds",@"15 Seconds"),
               NSLocalizedString(@"1 Minute",@"1 Minute"),
               NSLocalizedString(@"15 Minutes",@"15 Minutes"),
               NSLocalizedString(@"1 Hour",@"1 Hour"),
               NSLocalizedString(@"4 Hours",@"4 Hours"), nil];
	[pcAlert show];
	UITableView *tableView = self.tableView;
	[pcAlert setActionViewBlock: ^(UIAlertView *alert, NSInteger buttonPressed, NSString *alertText) {
		NSTimeInterval delay;
		switch(buttonPressed)
		{
			case 0:
				return;
				break;
			case 1:
				delay = 5;
				break;
			case 2:
				delay = 15;
				break;
			case 3:
				delay = 60;
				break;
			case 4:
				delay = 15 * 60;
				break;
			case 5:
				delay = 60 * 60;
				break;
			case 6:
				delay = 4 * 60 * 60;
				break;
		}
		STAppDelegate.passcodeManager.passcodeTimeout = delay;
		[tableView reloadData];
        
	}];
    
	
}

- (NSString *)delayInString
{
	NSInteger delay = (NSInteger) STAppDelegate.passcodeManager.passcodeTimeout;
	if (delay > 3600 * 2) {
		STAppDelegate.passcodeManager.passcodeTimeout = 4 * 60 * 60;
		return NSLocalizedString(@"4 Hours",@"4 Hours");
	}
	
	else if (delay >= 3600) {
		STAppDelegate.passcodeManager.passcodeTimeout = 1 * 60 * 60;
		return NSLocalizedString(@"1 Hour",@"1 Hour");
	}
    
	else if (delay >= 60 * 15) {
		STAppDelegate.passcodeManager.passcodeTimeout = 15 * 60;
		return NSLocalizedString(@"15 Minutes",@"15 Minutes");
	}
	
	else if (delay >= 60 * 1) {
		STAppDelegate.passcodeManager.passcodeTimeout = 1 * 60;
		return NSLocalizedString(@"1 Minute",@"1 Minute");
	}
	
	else if (delay >= 15) {
		STAppDelegate.passcodeManager.passcodeTimeout = 15;
		return NSLocalizedString(@"15 Seconds",@"15 Seconds");
	}
	
	else if (delay >= 5) {
		STAppDelegate.passcodeManager.passcodeTimeout = 5;
		return NSLocalizedString(@"5 Seconds",@"5 Seconds");
	}
	return @"Invalid";
}

- (void)handlePasscodeTap
{
	DDLogAutoTrace();
	
	if ([STAppDelegate.passcodeManager hasKeyChainPassCode])
	{
		[self promptForNewPasscodeWithTitle:NSLocalizedString(@"Set Passcode", @"Set Passcode")];
	}
	else
	{
		[self promptForPasscodeOptionsWithTitle:NSLocalizedString(@"Passcode", @"Passcode")];
	}
}

- (void)promptForPasscodeOptionsWithTitle:(NSString *)title
{
	DDLogAutoTrace();
	
	NSString *changeDelay = NSLocalizedString(@"Change Delay", @"Change Delay");
	NSString *changeDelayWithCurrentValue = [NSString stringWithFormat:@"%@ (%@)", changeDelay, [self delayInString]];
	
	pcAlert = [[MZAlertView alloc] initWithTitle:title
	                                     message:NSLocalizedString(@"Enter Passcode", @"Enter Passcode")
	                                    delegate:nil
	                           cancelButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
	                           otherButtonTitles:NSLocalizedString(@"Turn Off", @"Turn Off"),
	                                             NSLocalizedString(@"Change Passcode", @"Change Passcode"),
	                                             changeDelayWithCurrentValue, nil];
	
	pcAlert.alertViewStyle = UIAlertViewStyleSecureTextInput;
	
	__weak SettingsViewController *weakSelf = self;
	[pcAlert setActionViewBlock: ^(UIAlertView *alert, NSInteger buttonPressed, NSString *alertText) {
		
		__strong SettingsViewController *strongSelf = weakSelf;
		if (strongSelf == nil) return;
		
		if (buttonPressed == 0) // Cancel
		{
			return;
		}
		
		BOOL incorrectPasscode = NO;
		
		NSString *passcode = [[alert textFieldAtIndex:0] text];
		if (passcode.length == 0)
		{
			incorrectPasscode = YES;
		}
		else
		{
			NSError *error = nil;
			BOOL unlockResult = [STAppDelegate.passcodeManager unlockWithPassphrase:passcode
			                                                       passPhraseSource:kPassPhraseSource_Keyboard
			                                                                  error:&error];
			
			if (!unlockResult) {
				incorrectPasscode = YES;
			}
		}
		
		if (incorrectPasscode)
		{
			NSString *title = NSLocalizedString(@"Incorrect Passcode", @"Incorrect Passcode");
			[strongSelf promptForPasscodeOptionsWithTitle:title];
		}
		else if (buttonPressed == 1) // Turn Off
		{
			[strongSelf setPasscodeOff];
		}
		else if (buttonPressed == 2) // Change Passcode
		{
			[strongSelf promptForNewPasscodeWithTitle:NSLocalizedString(@"Change Passcode", @"Change Passcode")];
		}
		else if (buttonPressed == 3) // Change Delay
		{
			[strongSelf promptForPasscodeDelay];
			
		}
	}];
	
	[pcAlert show];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark BioMetric key tests
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)touchIDAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *pressedCell = [self.tableView cellForRowAtIndexPath:indexPath];
	CGRect cellRect = pressedCell.frame;
	
	NSString *biometric_key_new    = NSLocalizedString(@"Create New Key", @"Create New Key");
	NSString *biometric_key_delete = NSLocalizedString(@"Remove Key", @"Remove Key");
	NSString *biometric_key_unlock = NSLocalizedString(@"Unlock", @"Unlock ");
	
	BOOL hasBioMetricKey = [STAppDelegate.passcodeManager hasBioMetricKey];
    
    NSArray *choices = nil;
	if (hasBioMetricKey)
		choices = @[biometric_key_delete, biometric_key_unlock];
	else
		choices = @[biometric_key_new];
	
	NSString *title = NSLocalizedString(
	  @"TouchID Key\n"
	  @"This is an experimental feature that allows you to create a TouchID Key"
	  @" that you can use to unlock your Silent Text App.",
	  @"TouchID Key Text");
	
	[OHActionSheet showFromRect:cellRect
	                   sourceVC:self
	                     inView:self.view
	             arrowDirection:UIPopoverArrowDirectionLeft
	                      title:title
	          cancelButtonTitle:NSLS_COMMON_CANCEL
	     destructiveButtonTitle:NULL
	          otherButtonTitles:choices
	                 completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
	{
		NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
		
		if ([choice isEqualToString:biometric_key_new])
		{
			NSError *error = nil;
			[STAppDelegate.passcodeManager createBioMetricKeyBlobWithError:&error];
			
			if (error)
			{
				[STAppDelegate showAlertWithTitle:@"Failed"
				                          message:error.localizedDescription];
			}
		}
		else if ([choice isEqualToString:biometric_key_delete])
		{
			NSError *error = nil;
			[STAppDelegate.passcodeManager removeBioMetricKeyWithError:&error];
			
			if (error)
			{
				[STAppDelegate showAlertWithTitle:@"Failed"
										  message:error.localizedDescription];
			}
		}
		else if ([choice isEqualToString:biometric_key_unlock])
		{
			NSString *prompt = NSLocalizedString(@"Test Touch ID", nil);
			
			NSError *error = nil;
			[STAppDelegate.passcodeManager unlockWithBiometricKeyWithPrompt:prompt error:&error];
			
			if (!error)
			{
				[STAppDelegate showAlertWithTitle:@"Success"
				                          message:nil];
			}
			else
			{
				[STAppDelegate showAlertWithTitle:@"Failed"
				                          message:error.localizedDescription];
			}
		}
	
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Recovery Key Tests
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)recoveryKeyAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *const recoveryKeyNew     = NSLocalizedString(@"Create New Key", @"Create New Key");
	NSString *const recoveryKeyDelete  = NSLocalizedString(@"Remove Key", @"Remove Key");
	NSString *const recoveryKeyRecover = NSLocalizedString(@"Test Recovery Key", @"Test Recovery Key");
    
    BOOL hasRecoveryKey = [STAppDelegate.passcodeManager recoveryKeyBlob] != NULL;
    
	NSArray *choices = hasRecoveryKey ? @[recoveryKeyDelete, recoveryKeyRecover] : @[recoveryKeyNew];
    
	UITableViewCell *pressedCell = [self.tableView cellForRowAtIndexPath:indexPath];
	CGRect cellRect = pressedCell.frame;
    
    [OHActionSheet showFromRect:cellRect 
                       sourceVC:self
                         inView:self.view
                 arrowDirection:UIPopoverArrowDirectionLeft
                          title: NSLocalizedString(@"Passcode Recovery Key\n"
                                                   @"This is an experimental feature that allows you to create a backup QRCode that you can use to unlock your Silent Text App.",
                                                   @"Passcode Recovery Key Text")
               cancelButtonTitle:NSLS_COMMON_CANCEL
         destructiveButtonTitle:NULL
              otherButtonTitles:choices
                     completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                         NSError* error = NULL;
                         
                         NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
                         
                         if ([choice isEqualToString:recoveryKeyNew])
                         {
                             NSString* recoveryKey  = [SCPasscodeManager createRecoveryKeyString];
                             NSDictionary* recoveryKeyDict = NULL;
                             
                             [STAppDelegate.passcodeManager updateRecoveryKey:recoveryKey
                                                              recoveryKeyDict: &recoveryKeyDict
                                                                        error:&error];
                             
                             if(!error)
                             {
                                 SCRecoveryKeyViewController* rvc  = [[SCRecoveryKeyViewController alloc]
                                                                      initWithRecoveryKeyString:recoveryKey
                                                                      recoveryKeyDict:recoveryKeyDict ];
                                 rvc.delegate = self;
                                 
                                 if (AppConstants.isIPhone)
                                 {
//                                     CGRect frame = rvc.view.frame;
//                                     frame.size.height -= self.navigationController.navigationBar.frame.size.height;
//                                     rvc.view.frame = frame;
                                 }
                                 else
                                 {
                                     rvc.isInPopover = YES;
                                 }
                                 
                                 
                                 [self popupViewController:rvc pointTo:[self.tableView rectForRowAtIndexPath:indexPath]];
                             }
                             else
                             {
                                 
                                 [STAppDelegate showAlertWithTitle: @"updateRecoveryKey key Failed"
                                                           message: error.localizedDescription];
                             }
                             
                             
                         }
                         else if ([choice isEqualToString:recoveryKeyDelete])
                         {
                             [STAppDelegate.passcodeManager removeRecoveryKeyWithError:&error];
                         }
                         else if ([choice isEqualToString:recoveryKeyRecover])
                         {
                             
                             SCRecoveryKeyScannerController* rsc  = [[SCRecoveryKeyScannerController alloc] initWithDelegate:self];
                             
                             if (AppConstants.isIPhone)
                             {
                                 
                                 // recovery scanner doesnt use nav bar
                                 CGRect frame = rsc.view.frame;
                                 frame.size.height -= self.navigationController.navigationBar.frame.size.height;
                                 rsc.view.frame = frame;
                             }
                             else
                             {
                                 rsc.isInPopover = YES;
                             }
                             
                             [self popupViewController:rsc pointTo:[self.tableView rectForRowAtIndexPath:indexPath]];
                         }
                         
                     }];
    
    
}
#pragma mark - SCRecoveryKeyViewController methods
- (void)scRecoveryKeyViewController:(SCRecoveryKeyViewController *)sender dismissRecoveryKeyView:(NSError*)error
{
    if (AppConstants.isIPhone)
	{
           [self dismissViewControllerAnimated:YES completion:nil];
	}
	else
	{
		[popoverController dismissPopoverAnimated:YES];
	}

}
#pragma mark - SCRecoveryKeyScannerController methods


- (BOOL)scRecoveryKeyScannerController:(SCRecoveryKeyScannerController *)sender
                            didScanKey:(NSString*)recoveryKey
                               keyHash:(NSString*)recoveryKeyHash
{
    NSError         *error  = NULL;
    BOOL success     = NO;
    
    NSDictionary* dict = [STAppDelegate.passcodeManager recoveryKeyDictionary ];
    if(dict)
    {
        
        NSString* keyHash = [ dict objectForKey:@"keyHash"];
        
        if([keyHash isEqualToString:recoveryKeyHash])
        {
            
            [STAppDelegate.passcodeManager unlockStorageBlobWithPassphase: recoveryKey
                                                         passPhraseSource: kPassPhraseSource_Recovery
                                                                    error: &error];
            
            if(!error)
                success = YES;
            
        }
    }
    return success;
}


- (void)scRecoveryKeyScannerController:(SCRecoveryKeyScannerController *)sender dismissRecovery:(NSError*)error
{
    //ET 10/28/14 - implementation is the same in all cases of this and activation view controller callbacks
    [self dismissActivationVC:sender error:error];
}


- (void)scRecoveryKeyScannerController:(SCRecoveryKeyScannerController *)sender unLockWithKey:(NSString*)recoveryKey keyHash:(NSString*)keyHash
{
    [STAppDelegate showAlertWithTitle:@"Key Recovery Success" message:NULL];

}

#pragma mark - ActivationVCDelegate Methods

- (void)dismissActivationVC:(UIViewController *)vc error:(NSError*)error
{
    if (AppConstants.isIPhone)
    {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    else
    {
        [popoverController dismissPopoverAnimated:YES];
    }    
}


@end