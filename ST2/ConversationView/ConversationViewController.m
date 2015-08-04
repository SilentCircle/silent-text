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
#import "ConversationViewController.h"

#import "ActivationVCDelegate.h"
#import "AddressBookManager.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "AppTheme.h"
#import "AvatarManager.h"
#import "ConversationViewTableCell.h"
#import "LogInViewController.h"
#import "MessageStream.h"
#import "MessageStreamManager.h"
#import "MessagesViewController.h"
#import "UserInfoVC.h"
#import "OHActionSheet.h"
#import "SCDateFormatter.h"
#import "SilentTextStrings.h"
#import "Siren.h"
#import "STConversation.h"
#import "STLocalUser.h"
#import "STLogging.h"
#import "STMessage.h"
#import "STPreferences.h"
#import "SCimpSnapshot.h"

// Categories
#import "NSString+SCUtilities.h"
#import "UIImage+maskColor.h"
#import "UIImage+Thumbnail.h"

// Libraries
#import <ImageIO/ImageIO.h>
#import <QuartzCore/QuartzCore.h>
#import <MobileCoreServices/MobileCoreServices.h>

// Log levels: off, error, warn, info, verbose
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_WARN;
#elif DEBUG && eric_turner
static const int ddLogLevel = LOG_LEVEL_WARN; // | LOG_LEVEL_INFO | LOG_FLAG_TRACE;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_WARN;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

//ET 03/27/15 - Accessibility - DEPRECATE - UNUSED
//static CGFloat   const HORIZONTAL_RADIUS_RATIO = 0.8;
//static CGFloat   const VERTICAL_RADIUS_RATIO   = 1.2;
//static NSInteger const CIRCLE_DIRECTION_RIGHT  = 0;

static NSString *const kActivateIcon      = @"attention";
static NSString *const kAttentionIcon     = @"failure-btn";
static NSString *const kExpiredIcon       = @"expired";
static NSString *const kReplyIcon         = @"reply_3";
static NSString *const kUnprovisionedIcon = @"subscribe";
static NSString *const kUnreadIcon        = @"bluedot";

//ET 03/26/15 - Accessibility - try DEPRECATE 
//static NSString *const kDefaultSilentTextInfoUserAvatarIcon = @"AppIcon"; // Unused??
//static NSString *const kCellIdentifier = @"CellStyleDefault"; // Unused??

//ET 03/15 - Accessibility
/**
 * Enum describing local user account and current messageStream state, implemented 
 * to create an accessibility label for the "problem button" (e.g. lightning bolt).
 *
 * @see updateItemAccessibilityLabel:withState: method
 */
NS_ENUM(NSInteger, SC_MultiState) {
    multiState_NoProblems,
    currentUser_NotProvisioned,
    currentUser_NotActivated,
    currentUser_SubscriptionExpired,
    multiState_MsgStream_Disconnected,
    multiState_MsgStream_Connecting,
    multiState_MsgStream_Connected,
    multiState_MsgStream_Error
};


//ET 10/28/14 - Update LoginViewControllerDelegate to generic ActivationVCDelegate
@interface ConversationViewController () <ActivationVCDelegate> @end

@implementation ConversationViewController
{
	YapDatabaseConnection *databaseConnection;
	YapDatabaseViewMappings *mappings;
	
	NSIndexPath *temp_selectedIndexPath;
	NSString *temp_selectedConversationId;

    //ET 03/26/15 - Accessibility - try DEPRECATE 
//    UIImage *activateImg;
//    UIImage *unprovisionedImg;
//    UIImage *unreadImg;
    UIImage *attentionImg;
    UIImage *expiredImg;
    UIImage *replyImg;
	
	AppTheme *theme;
	
    //ET 03/27/15 - Accessibility
    // This ivar holds state which is reflected in the auxiliary
    // leftBarButtonItem - which for example displays the 
    // lightning bolt icon. This initial implementation intends
    // to use it to dynamically determine the accessibility label
    // for the auxiliary button when updateBarButtonItems is invoked.
    enum SC_MultiState _currentState;
    
	BOOL hasViewWillAppear;
	BOOL hasViewDidAppear;
    
    UIButton *titleButton;

    UIBarButtonItem *bbtnActivateItem;
    UIActivityIndicatorView *activityIndicator;
    UIBarButtonItem *bbtnActivityItem;
    UIBarButtonItem *bbtnExpiredItem;
    UIBarButtonItem *bbtnOfflineItem;    
    UIBarButtonItem *bbtnUnprovisionedItem;
    
    UIImage *keyImg_1;
    UIImage *keyImg_2;
    UIImage *keyImg_3;
    UIImage *keyImg_4;
	
    CGRect popoverFromRect;
    UIView *popoverInView;
    CGSize popoverContentSize;
}

@synthesize popoverController=popoverController;


#pragma mark - Initialization
- (id)initWithProperNib
{
	return [self initWithNibName:@"ConversationViewController" bundle:nil];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
	{
		if (AppConstants.isIPad)
		{
			self.clearsSelectionOnViewWillAppear = NO;
        }
        
        keyImg_1 = [UIImage imageNamed: @"key1"];
        keyImg_2 = [UIImage imageNamed: @"key2"];
        keyImg_3 = [UIImage imageNamed: @"key3"];
        keyImg_4 = [UIImage imageNamed: @"key4"];
        
        attentionImg = [UIImage imageNamed:kAttentionIcon];
        expiredImg   = [UIImage imageNamed:kExpiredIcon];
        replyImg     = [UIImage imageNamed:kReplyIcon];
        
        bbtnActivateItem =[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:kActivateIcon]
                                                           style:UIBarButtonItemStylePlain
                                                          target:self
                                                          action:@selector(activateTapped:)];

        activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
        bbtnActivityItem  = [[UIBarButtonItem alloc] initWithCustomView:activityIndicator];
        //TODO: 
        //ET 03/27/15 - Accessibility - try setting spinner to theme color:
        // It seems to get lost as white on default navbar color
        // @see changeTheme:

        bbtnExpiredItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:kExpiredIcon]
                                                          style:UIBarButtonItemStylePlain
                                                         target:self
                                                         action:@selector(expiredTapped:)];

        bbtnOfflineItem = [[UIBarButtonItem alloc] initWithImage:
                             [[UIImage imageNamed:@"offline"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                                           style:UIBarButtonItemStylePlain
                                                          target:self
                                                          action:@selector(offlineTapped:)];
        
        bbtnUnprovisionedItem =[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:kUnprovisionedIcon]
                                                                style:UIBarButtonItemStylePlain
                                                               target:self
                                                               action:@selector(unprovisionedTapped:)];
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
  	
	// Setup basic ivars
	[STAppDelegate setOriginalTintColor: self.view.tintColor];

	[self changeTheme:nil];
	
	// Setup database
	
	databaseConnection = STDatabaseManager.uiDatabaseConnection;
	[self initializeMappings];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(databaseConnectionWillUpdate:)
	                                             name:UIDatabaseConnectionWillUpdateNotification
	                                           object:STDatabaseManager];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(databaseConnectionDidUpdate:)
	                                             name:UIDatabaseConnectionDidUpdateNotification
	                                           object:STDatabaseManager];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(messageStreamStateChanged:)
												 name:MessageStreamDidChangeStateNotification
											   object:nil];

	// User interface setup
	
	[self updateTitleButton];
	[self updateBarButtonItems];

	[self.tableView registerNib: [UINib nibWithNibName: @"ConversationViewTableCell" bundle: nil]
	     forCellReuseIdentifier: @"ConversationViewTableCell"];

	CGFloat titlePaddingLeft = [ConversationViewTableCell titlePaddingLeft];
	
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorColor = [UIColor lightGrayColor];
	self.tableView.separatorInset = UIEdgeInsetsMake(0, titlePaddingLeft, 0, 0); // top, left, bottom, right
    self.tableView.opaque = NO;
    self.tableView.showsHorizontalScrollIndicator = NO;
    self.tableView.showsVerticalScrollIndicator = YES;
	
	// Register for notifications
	
	if (AppConstants.isIPad)
	{
//		[[NSNotificationCenter defaultCenter] addObserver:self
//		                                         selector:@selector(keyboardWillShow:)
//		                                             name:UIKeyboardWillShowNotification
//		                                           object:nil];
		
//		[[NSNotificationCenter defaultCenter] addObserver:self
//		                                         selector:@selector(keyboardWillHide:)
//		                                             name:UIKeyboardWillHideNotification
//		                                           object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
		                                         selector:@selector(keyboardDidShow:)
		                                             name:UIKeyboardDidShowNotification
		                                           object:nil];
	}
    
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(preferredContentSizeChanged:)
	                                             name:UIContentSizeCategoryDidChangeNotification
	                                           object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(changeTheme:)
												 name:kAppThemeChangeNotification
											   object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillAppear:animated];
	
	if (AppConstants.isIPhone)
	{        
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        if (indexPath)
        {
            [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
        }
	}
	else
	{
		// Note: On iPad this method gets called many many times.
		// This is because the viewController is within splitViewController,
		// and whenever we modify the master or detail of the splitView
		// it re-invokes viewWillAppear & viewDidAppear.
		
		// We make sure something is selected.
		// If something is already selected, then this method does nothing.
		// Otherwise it tries to re-select whatever was selected last time (per account).
		[self ensureSelection];
	}
	
	hasViewWillAppear = YES;
}

- (void)viewDidAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewDidAppear:animated];

	hasViewDidAppear = YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View Preferences
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)prefersStatusBarHidden
{
	DDLogAutoTrace();
	
	return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
	DDLogAutoTrace();
	
	if (theme.navBarIsBlack)
		return UIStatusBarStyleLightContent;
	else
		return UIStatusBarStyleDefault;
}

- (void)changeTheme:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	NSDictionary *userInfo = notification.userInfo;
	if (userInfo)
		theme = userInfo[kNotificationUserInfoTheme];
	else
		theme = [AppTheme getThemeBySelectedKey];
	
	UIColor *tintColor;
	if (theme.appTintColor)
		tintColor = theme.appTintColor;
	else
		tintColor = [STAppDelegate originalTintColor];

    //ET 01/30/15 - Move up from below so tableView bgColor
    // updates before reload.
    //
    // View
    //    
    self.view.backgroundColor = theme.blurredBackgroundColor;
    self.view.tintColor = tintColor;

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
	
	//
    // Navigation Bar Items
	//
    
	replyImg = [[UIImage imageNamed:kReplyIcon] maskWithColor:tintColor];

	if (titleButton)
	{
		UIColor *navBarTitleColor = theme.navBarTitleColor;
		if (navBarTitleColor == nil)
			navBarTitleColor = [UIColor blackColor];
		
		[titleButton setTitleColor:navBarTitleColor forState:UIControlStateNormal];
		[titleButton setTitleColor:navBarTitleColor forState:UIControlStateHighlighted];
	}
	
	//
	// TableView
	//
	
	if (theme.scrollerColorIsWhite)
		self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
	else
		self.tableView.indicatorStyle = UIScrollViewIndicatorStyleBlack;
	
    NSIndexPath *prevSelectedIndexPath = [self.tableView indexPathForSelectedRow];

	if (hasViewDidAppear)
	{
		[self.tableView reloadData];
	}
    
	if (prevSelectedIndexPath)
	{
        DDLogOrange(@"%s SELECT ROW",__PRETTY_FUNCTION__);
		[self.tableView selectRowAtIndexPath:prevSelectedIndexPath
		                            animated:NO
		                      scrollPosition:UITableViewScrollPositionNone];
	}
	
	// Do this last
	[self setNeedsStatusBarAppearanceUpdate];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)currentUserID
{
	return STDatabaseManager.currentUser.uuid;
}

- (NSString *)selectedConversationId
{
	__block NSString *selectedConversationId = nil;
	
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	if (selectedIndexPath)
	{
		[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			selectedConversationId = [[transaction ext:Ext_View_Order] keyAtIndex:selectedIndexPath.row
			                                                              inGroup:self.currentUserID];
		}];
	}
	
	return selectedConversationId;
}

- (void)setSelectedConversationId:(NSString *)conversationId
{
	DDLogAutoTrace();
    
	if ([[self selectedConversationId] isEqualToString:conversationId]) {
		return;
	}
   
	[self selectRowPreferringConversationId:conversationId
	                            orIndexPath:nil
	                             orFallback:YES
	                         scrollPosition:UITableViewScrollPositionMiddle];

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Notifications
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)preferredContentSizeChanged:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	// Forward the notification to the ConversationViewTableCell.
	// It needs to recalculate some stuff based on new font sizes...
	
	[ConversationViewTableCell preferredContentSizeChanged:notification];
	
	// Then reload our table
	
	[self.tableView reloadData];
}

- (void)messageStreamStateChanged:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	NSString *userUUID = [notification.userInfo objectForKey:kMessageStreamUserUUIDKey];
	
	if ([userUUID isEqualToString:self.currentUserID])
	{
		[self updateBarButtonItems];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateTitleButton
{
	DDLogAutoTrace();
	
	STLocalUser *currentUser = STDatabaseManager.currentUser;
	if (currentUser == nil)
    {
        self.navigationItem.titleView = nil;
        self.navigationItem.title =  NSLocalizedString(@"Silent Text", @"Silent Text");
    
        return;
    }
	
	// Note: If you want to change the button type to UIButtonTypeSystem,
	// then make sure the button doesn't disappear on UIControlEventTouchDown (with a black navBar).
	
	titleButton = [UIButton buttonWithType:UIButtonTypeCustom]; // see note above
	titleButton.adjustsImageWhenHighlighted = NO;
	titleButton.titleLabel.font = [[UIFont preferredFontForTextStyle:UIFontTextStyleCaption2] fontWithSize:20];
	
	[titleButton addTarget:self action:@selector(titleTap:) forControlEvents:UIControlEventTouchUpInside];
	
	UIColor *navBarTitleColor = theme.navBarTitleColor;
	if (navBarTitleColor == nil)
		navBarTitleColor = [UIColor blackColor];
	
	[titleButton setTitleColor:navBarTitleColor forState:UIControlStateNormal];
	[titleButton setTitleColor:navBarTitleColor forState:UIControlStateHighlighted];
	
	[titleButton setTitle:currentUser.displayName forState:UIControlStateNormal];
    [titleButton sizeToFit];
    
	self.navigationItem.title = nil;
    self.navigationItem.titleView = titleButton;
}

//ET 03/27/15 - Accessibility
// Add initialization of _currentState ivar for use by 
// updateItemAccessibilityLabel:(id)item withState: method.
- (void)updateBarButtonItems
{
	DDLogAutoTrace();
    
    // Set state ivar to "no problems" as a starting value.
    // This method is always called for db and messageStream
    // state changes. The if/else statements may update this 
    // starting state value.    
    _currentState = multiState_NoProblems;
    
    if(!STDatabaseManager.currentUser)
    {
        [activityIndicator stopAnimating];

        self.navigationItem.leftBarButtonItems = @[STAppDelegate.settingsButton];
        self.navigationItem.rightBarButtonItem = nil;
    }
    else  if (STDatabaseManager.currentUser.subscriptionHasExpired)
	{
		[activityIndicator stopAnimating];
		bbtnExpiredItem.tintColor =  [UIColor redColor];
		
        if(STDatabaseManager.currentUser.provisonInfo)
        {
            _currentState = currentUser_NotProvisioned;
            self.navigationItem.leftBarButtonItems = @[STAppDelegate.settingsButton, bbtnUnprovisionedItem];
        }
        else
        {
            _currentState = currentUser_SubscriptionExpired;
            self.navigationItem.leftBarButtonItems = @[STAppDelegate.settingsButton, bbtnExpiredItem];
           
        }
        self.navigationItem.rightBarButtonItem = nil;

	}
    else if (!STDatabaseManager.currentUser.isActivated)
	{
		[activityIndicator stopAnimating];
        _currentState = currentUser_NotActivated;
		self.navigationItem.leftBarButtonItems = @[STAppDelegate.settingsButton, bbtnActivateItem];
        self.navigationItem.rightBarButtonItem = nil;
	}
	else
	{
		MessageStream *messageStream = [MessageStreamManager messageStreamForUser:STDatabaseManager.currentUser];
		MessageStream_State messageStreamState = messageStream.state;
		
		switch (messageStreamState)
		{
			case MessageStream_State_Disconnected:
			{
				[activityIndicator stopAnimating];
				bbtnOfflineItem.tintColor = theme.navBarTitleColor;
				
                _currentState = multiState_MsgStream_Disconnected;
				self.navigationItem.leftBarButtonItems = @[STAppDelegate.settingsButton, bbtnOfflineItem];
				self.navigationItem.rightBarButtonItem = STAppDelegate.composeButton;
				
				break;
            }
			case MessageStream_State_Connecting:
			{
				[activityIndicator startAnimating];
				
                _currentState = multiState_MsgStream_Connecting;
				self.navigationItem.leftBarButtonItems = @[STAppDelegate.settingsButton, bbtnActivityItem];
				self.navigationItem.rightBarButtonItem = STAppDelegate.composeButton;
				
				break;
			}
			case MessageStream_State_Connected:
			{
				[activityIndicator stopAnimating];
				
                _currentState = multiState_MsgStream_Connected;
				self.navigationItem.leftBarButtonItems = @[STAppDelegate.settingsButton];
				self.navigationItem.rightBarButtonItem = STAppDelegate.composeButton;
				
				break;
			}
			case MessageStream_State_Error:
			{
				[activityIndicator stopAnimating];
				bbtnOfflineItem.tintColor = [UIColor redColor];
				
                _currentState = multiState_MsgStream_Error;
				self.navigationItem.leftBarButtonItems = @[STAppDelegate.settingsButton, bbtnOfflineItem];
				self.navigationItem.rightBarButtonItem = STAppDelegate.composeButton;
				
				break;
			}
		}
	}
    
    //ET 03/27/15 - Accessibility
    if (multiState_NoProblems != _currentState) {
        NSArray *bbtns = self.navigationItem.leftBarButtonItems;
        if (bbtns.count > 1) {
            UIBarButtonItem *item = bbtns[1];
            [self updateItemAccessibilityLabel:item withState:_currentState];
        }
        else if (multiState_MsgStream_Connected != _currentState) {
            DDLogError(@"%s \nError: _currentState: %ld, indicates a problem but the expected barbuttonItem does not exist",
                       __PRETTY_FUNCTION__, _currentState);
        }
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Accessibility
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Set a localized accessibility label on the given item for the given state.
 *
 * The accessibility label gives sight-impaired users a description of a problem state, which is represented to 
 * sighted users as image icon in a leftBarButtonItem, e.g. the lightning bolt image.
 *
 * @param item The item, probably a UIView subclass or UIBarButtonItem, on which to set a descriptive accessibility label.
 * @param aState An SC_MultiState enum value describing a local user account status or messageStream state.
 */
- (void)updateItemAccessibilityLabel:(id)item withState:(enum SC_MultiState)aState 
{
    NSString *aLbl = nil;
    switch (aState) {
        case currentUser_NotProvisioned:
            aLbl = NSLocalizedString(@"User account not provisioned", 
                                     @"User account not provisioned error statement for accessibility button");
            break;
        case currentUser_NotActivated:
            aLbl = NSLocalizedString(@"User account not activated", 
                                     @"User account not activated error statement for accessibility button");
            break;
        case currentUser_SubscriptionExpired:
            aLbl = NSLocalizedString(@"Subscription expired", 
                                     @"Subscription expired error statement for accessibility button");
            break;
        case multiState_MsgStream_Disconnected:
            aLbl = NSLocalizedString(@"Message stream disconnected", 
                                     @"Message stream state: disconnected {statement for accessibility button}");
            break;
        case multiState_MsgStream_Connecting:
            aLbl = NSLocalizedString(@"Message stream connecting", 
                                     @"Message stream state: connecting - {statement for accessibility button}");
            break;
        case multiState_MsgStream_Connected:
            aLbl = NSLocalizedString(@"Message stream connected", 
                                     @"Message stream state: connected - {statement for accessibility button}");
            break;
        case multiState_MsgStream_Error: {
            MessageStream *messageStream = [MessageStreamManager messageStreamForUser:STDatabaseManager.currentUser];
            NSString *strError = messageStream.errorString;
            strError = (strError && strError.length > 0) ? strError : @"Unknown error";            
            aLbl = [NSString stringWithFormat:NSLocalizedString(@"Message stream %@", 
                                                                @"Message stream state: error - statement for accessibility button"),
                        strError];
            break;
        }
        // Note: this method should never be called with the "NoProblem" state,
        // because the button should not be shown when there are no problems.
        case multiState_NoProblems:
            DDLogError(@"%s \nThis method should never be called with a NO PROBLEMS state",__PRETTY_FUNCTION__);
            break;
    }
    
    if ([item respondsToSelector:@selector(accessibilityLabel)]) {
        [item setValue:aLbl forKey:@"accessibilityLabel"];
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Popover
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)showViewController:(UIViewController *)viewController
                  fromRect:(CGRect)inRect
                    inView:(UIView *)inView
                hideNavBar:(BOOL)hideNavBar
{
	if (AppConstants.isIPhone)
	{
		self.navigationItem.backBarButtonItem =
		  [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", @"Nav button title")
		                                   style:UIBarButtonItemStylePlain
		                                  target:nil
		                                  action:nil];
		
		[self.navigationController pushViewController:viewController animated:YES];
    }
    else
    {
		UINavigationController *navController =
		  [[UINavigationController alloc] initWithRootViewController:viewController];
		navController.navigationBarHidden = hideNavBar;
        
        // always start with a fresh popover
        if (popoverController.popoverVisible)
        {
            [popoverController dismissPopoverAnimated:YES];
            popoverController = nil;
        }
        
        popoverController = [[UIPopoverController alloc] initWithContentViewController:navController];
		
		if ([viewController respondsToSelector:@selector(preferredPopoverContentSize)])
			popoverContentSize = [(id)viewController preferredPopoverContentSize];
		else
			popoverContentSize = viewController.view.frame.size;
		
		if (!hideNavBar)
			popoverContentSize.height += navController.navigationBar.frame.size.height;
		
		popoverController.popoverContentSize = popoverContentSize;
		popoverController.delegate = self;
		
		popoverFromRect = inRect;
		popoverInView = inView;
//		popoverContentViewController = navController;
		
		[popoverController presentPopoverFromRect:inRect
		                                   inView:inView
		                 permittedArrowDirections:UIPopoverArrowDirectionAny
		                                 animated:YES];
	}
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)sender
{
	DDLogAutoTrace();
	
	if (popoverController == sender) {
		popoverController = nil;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Database Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)initializeMappings
{
    DDLogAutoTrace();
    
	if (self.currentUserID)
	{
		[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			if ([transaction ext:Ext_View_Order])
			{
				mappings = [[YapDatabaseViewMappings alloc] initWithGroups:@[self.currentUserID] view:Ext_View_Order];
				
				[mappings updateWithTransaction:transaction];
			}
			else
			{
				// The view isn't ready yet.
				// We'll try again when we get a databaseConnectionDidUpdate notification.
			}
		}];
	}
	else
	{
		mappings = nil;
	}
}

- (void)setMessageViewBackButtonCount:(NSUInteger)count
{
	if (self.navigationItem.backBarButtonItem)
	{
		NSString *backString = NSLocalizedString(@"Back",nil);
		NSString *backTitle;
		
		if (count > 999)
			backTitle = [NSString stringWithFormat:@"%@ (999+)", backString];
		else if (count > 0)
			backTitle = [NSString stringWithFormat:@"%@ (%lu)", backString, (unsigned long)count];
		else
			backTitle = backString;
		
		self.navigationItem.backBarButtonItem =
		  [[UIBarButtonItem alloc] initWithTitle:backTitle
		                                   style:UIBarButtonItemStylePlain
		                                  target:nil
		                                  action:nil];
	}
}

- (void)databaseConnectionWillUpdate:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	// Fetch the selected conversationId.
	// We're going to re-select it (if possible) after we process the update(s).
	// If not possible, then we'll select something nearby the row that disappeared.
	
	temp_selectedIndexPath = [self.tableView indexPathForSelectedRow];
	
	if (temp_selectedIndexPath)
		temp_selectedConversationId = [self conversationIdForIndexPath:temp_selectedIndexPath];
	else
		temp_selectedConversationId = nil;
}

- (void)databaseConnectionDidUpdate:(NSNotification *)notification
{
	DDLogAutoTrace();
	
    //--------------------------------------------------------------------------------------------------------------//
    // Check: did user switch between user accounts?
    // Settings > Accounts
    //--------------------------------------------------------------------------------------------------------------//
	BOOL currentUserUpdated = [[notification.userInfo objectForKey:kCurrentUserUpdatedKey] boolValue];
	BOOL currentUserChanged = [[notification.userInfo objectForKey:kCurrentUserIDChangedKey] boolValue];
	
	if (currentUserUpdated || currentUserChanged)
	{
		[self updateTitleButton];
		[self updateBarButtonItems];
	}
    
	// If the mappings are nil then we still need to setup the datasource for our tableView.
	// So there's no need to worry about animating changes.
	
	if (currentUserChanged || mappings == nil)
	{
		[self initializeMappings];
		[self.tableView reloadData];
		
		if (AppConstants.isIPad)
		{
			// Select something.
			// Prefer whatever was selected last time.
			[self ensureSelection];
		}
        
		return;
	}    
    //--------------------------------------------------------------------------------------------------------------//
	
    
	// Get the changes as they apply to our view.
  	NSArray *notifications = [notification.userInfo objectForKey:kNotificationsKey];
 	
    BOOL userRecordsChanged = [databaseConnection hasChangeForCollection:kSCCollection_STUsers
	                                                       inNotifications:notifications];
     
    if (userRecordsChanged || !hasViewDidAppear)
    {
		[self initializeMappings];
        [self.tableView reloadData];
    }
	else
	{
		NSArray *rowChanges = nil;
		[[databaseConnection ext:Ext_View_Order] getSectionChanges:NULL
		                                                rowChanges:&rowChanges
		                                          forNotifications:notifications
		                                              withMappings:mappings];

		if ([rowChanges count] == 0)
		{
			// There aren't any changes that affect our tableView
			return;
		}

        // Update the tableView, animating the changes
        
        [self.tableView beginUpdates];
        
        for (YapDatabaseViewRowChange *rowChange in rowChanges)
        {
            switch (rowChange.type)
            {
                case YapDatabaseViewChangeDelete :
                {
//                    DDLogOrange(@"\n  YapDatabaseViewChangeDelete\n -- DELETE ROW --");
                    [self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                    break;
                }
                case YapDatabaseViewChangeInsert :
                {
//                    DDLogOrange(@"\n  YapDatabaseViewChangeinsert\n -- INSERT ROW --");
                    [self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                    break;
                }
                case YapDatabaseViewChangeMove :
                {
//                    DDLogOrange(@"\n  YapDatabaseViewChangeMove\n -- DELETE / INSERT ROW --");
                    [self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                    [self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                    break;
                }
                case YapDatabaseViewChangeUpdate :
                {
//                   DDLogOrange(@"\n  YapDatabaseViewChangeUpdate\n -- CALL TO CONFIGURE CELL --");
                    //ST-897: call the cell to configure itself rather than reloading the 
                    // tableView row to fix "flashing" of the cell.
                    //
                    // The "flashing" behavior is apparently an Apple bug which causes the cell
                    // to lose highlighting momentarily when reloading, even when the reload is
                    // invoked with no animation and the cell is immediately reselected with
                    // no animation.
                    ConversationViewTableCell *cell = 
                        (ConversationViewTableCell *)[self.tableView cellForRowAtIndexPath:rowChange.indexPath];
                    [self configureCell:cell withIndexPath:rowChange.indexPath];
                    
                    break;
                }
            }
            
            [self.tableView endUpdates];
            
        } // end rowChanges count
        
    } // if/else userRecordsChanged
    
    
	// Re-select the conversation that was previously selected.
	// If on iPad, make sure at least something is selected.
	
	if (temp_selectedConversationId || AppConstants.isIPad)
	{
//        DDLogOrange(@"\n  temp_selectedConversationId || AppConstants.isIPad\n -- CALL TO SELECT ROW --");
		NSIndexPath *nearbyIndexPath = nil;
		if (temp_selectedConversationId)
		{
			nearbyIndexPath = [mappings nearestIndexPathForRow:temp_selectedIndexPath.row inGroup:self.currentUserID];
		}
		
		BOOL useFallback = AppConstants.isIPad; // ensure something is selected
        
		[self selectRowPreferringConversationId:temp_selectedConversationId
		                            orIndexPath:nearbyIndexPath
		                             orFallback:useFallback
		                         scrollPosition:UITableViewScrollPositionNone];
	}
}

/**
 * This method helps ensure that something is selected.
**/
- (void)selectRowPreferringConversationId:(NSString *)preferredConversationId
                              orIndexPath:(NSIndexPath *)preferredIndexPath
                               orFallback:(BOOL)useFallback
                           scrollPosition:(UITableViewScrollPosition)scrollPosition
{
    DDLogAutoTrace();
    
	if (!mappings || [mappings isEmpty])
	{
//        DDLogOrange(@"%s\n  MAPPINGS EMPTY\n -- SET MessagesVC.conversationId NIL -- RETURN ",__PRETTY_FUNCTION__);
        STAppDelegate.messagesViewController.conversationId = nil;
		return;
	}
	
	// First try to select the preferredConversationId
	if (preferredConversationId)
	{
		NSIndexPath *indexPath = [self indexPathForConversationId:preferredConversationId];
		if (indexPath)
		{
//            DDLogOrange(@"%s\n  preferredConvesationId  -- SELECT ROW ",__PRETTY_FUNCTION__);
			[self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:scrollPosition];
			
			STAppDelegate.messagesViewController.conversationId = preferredConversationId;
			[STPreferences setSelectedConversationId:preferredConversationId forUserId:self.currentUserID];
			return;
		}
	}
	
	// If that doesn't work, try the preferredIndexPath.
	// This is likely the previous location of the preferredConversationId or something nearby.
	// So if the conversation is deleted, we re-select something right next to it.
	if (preferredIndexPath)
	{
		NSString *conversationId = [self conversationIdForIndexPath:preferredIndexPath];
		if (conversationId)
		{
//            DDLogOrange(@"%s\n  preferredIndexPath  -- SELECT ROW ",__PRETTY_FUNCTION__);
            
			[self.tableView selectRowAtIndexPath:preferredIndexPath animated:NO scrollPosition:scrollPosition];
			
			STAppDelegate.messagesViewController.conversationId = conversationId;
			[STPreferences setSelectedConversationId:conversationId forUserId:self.currentUserID];
			return;
		}
	}

	if (useFallback)
	{
		// Fallback to selecting the first row (if there is one)
		
		NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
		
		NSString *conversationId = [self conversationIdForIndexPath:indexPath];
		if (conversationId)
		{
//            DDLogOrange(@"%s\n  useFallback  -- SELECT ROW ",__PRETTY_FUNCTION__);
			[self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:scrollPosition];
			
			STAppDelegate.messagesViewController.conversationId = conversationId;
			[STPreferences setSelectedConversationId:conversationId forUserId:self.currentUserID];
		}
	}
}

/**
 * Ensure something is selected.
 * Prefer whatever was selected last time.
**/
- (void)ensureSelection
{
    DDLogAutoTrace();
    
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	if (selectedIndexPath == nil)
	{
		NSString *conversationId = [STPreferences selectedConversationIdForUserId:self.currentUserID];
		
		// What UITableViewScrollPosition do we use here?
		//
		// This method is called when the tableView is first displayed (generally on app launch).
		// We generally prefer the tableView to be scrolled to the top, so that the user can see the most
		// recent conversations. But, of course, the user must be able to see the selected conversation.
		// So we choose UITableViewScrollPositionBottom. That way the selected conversation is visible and,
		// if possible, the most recent conversation will also be visible.
		
		[self selectRowPreferringConversationId:conversationId
		                            orIndexPath:nil
		                             orFallback:YES
		                         scrollPosition:UITableViewScrollPositionBottom];
	}
}

/**
 * Conversion helper
**/
- (NSIndexPath *)indexPathForConversationId:(NSString *)conversationId
{
	__block NSIndexPath *indexPath = nil;
	
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		indexPath = [[transaction ext:Ext_View_Order] indexPathForKey:conversationId
		                                                 inCollection:self.currentUserID
		                                                 withMappings:mappings];
	}];

	return indexPath;
}

/**
 * Conversion helper
**/
- (NSString *)conversationIdForIndexPath:(NSIndexPath *)indexPath
{
	__block NSString *conversationId = nil;
	
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		[[transaction ext:Ext_View_Order] getKey:&conversationId
		                              collection:nil
		                             atIndexPath:indexPath
		                            withMappings:mappings];
	}];
	
	return conversationId;
}

- (void)deleteConversation:(NSString *)conversationId
{
	// We don't use the read-only database connection for read-write operations.
	// The read-only connection is using long-lived read-only transactions,
	// and we rely on the YapDatabaseModifiedNotification to move it from one state to another.
	//
	// Invoking a read-write transaction on the connection would force it to the most recent state,
	// and we'd miss the notification information we need.
	//
	// So instead we create a temporary connection (as this method is used infrequently)
	
	STLocalUser *currentUser = STDatabaseManager.currentUser;
	
	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STConversation *conversation = [transaction objectForKey:conversationId inCollection:currentUser.uuid];
        
        if (conversation.isNewMessage)
        {
			[transaction removeAllObjectsInCollection:conversationId];
			[transaction removeObjectForKey:conversationId inCollection:currentUser.uuid];
		}
		else
		{
			// Delete all messages
			[transaction removeAllObjectsInCollection:conversationId];
			
			// Mark the conversation as hidden (removing from order view)
			conversation = [conversation copy];
			conversation.hidden = YES;
			
			[transaction setObject:conversation forKey:conversationId inCollection:currentUser.uuid];
        }
		
		// Add a flag for this transaction specifying that we cleared the conversation.
		// This is used by the UI to avoid the usual burn animation when it sees a message was deleted.
		NSDictionary *transactionExtendedInfo = @{
		    kTransactionExtendedInfo_ClearedConversationId: conversationId };
		transaction.yapDatabaseModifiedNotificationCustomObject = transactionExtendedInfo;
	}];
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

//- (void)keyboardWillShow:(NSNotification *)notification
//{
//	DDLogAutoTrace();
//	
//	// Extract information about the keyboard change.
//	
//	float keyboardHeight = 0.0F;
//	NSTimeInterval animationDuration = 0.0;
//	UIViewAnimationCurve animationCurve = UIViewAnimationCurveLinear;
//	
//	[self getKeyboardHeight:&keyboardHeight
//	      animationDuration:&animationDuration
//	         animationCurve:&animationCurve
//	                   from:notification];
//	
//	[self handleResizeWithKeyboardHeight:keyboardHeight
//	                   animationDuration:animationDuration
//	                      animationCurve:animationCurve
//	                  isKeyboardWillShow:YES];
//}

//- (void)keyboardWillHide:(NSNotification *)notification
//{
//	DDLogAutoTrace();
//	
//	// Extract information about the keyboard change.
//	
//	float keyboardHeight = 0.0F;
//	NSTimeInterval animationDuration = 0.0;
//	UIViewAnimationCurve animationCurve = UIViewAnimationCurveLinear;
//	
//	[self getKeyboardHeight:&keyboardHeight
//	      animationDuration:&animationDuration
//	         animationCurve:&animationCurve
//	                   from:notification];
//	
//	[self handleResizeWithKeyboardHeight:keyboardHeight
//	                   animationDuration:animationDuration
//	                      animationCurve:animationCurve
//	                  isKeyboardWillShow:NO];
//}

- (void)keyboardDidShow:(NSNotification *)notification
{
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	if (selectedIndexPath) {
		//		NSArray *visibleIndexes = [self.tableView indexPathsForVisibleRows];
		//		if (![visibleIndexes containsObject:selectedIndexPath])
		[self.tableView scrollToNearestSelectedRowAtScrollPosition:UITableViewScrollPositionNone animated:YES];
	}
	
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Content Positioning
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)handleSimpleResizeWithHeightDecrease:(CGFloat)heightDecrease
                           animationDuration:(NSTimeInterval)animationDuration
                            animationOptions:(UIViewAnimationOptions)animationOptions
{
	DDLogAutoTrace();
	NSAssert(heightDecrease <= 0, @"Expected heightDecrease to be negative (decrease)");
	
	// For such a simple change, why do we do it in a completionBlock?
	// Why not just run the change plainly?
	//
	// Because, during a rotation, where the keyboard is visible, the OS does the following:
	//
	// - hides the keyboard (which invokes keyboardWillHide)
	// - sets us the rotation, and changes our frame
	// - shows the keyboard (which invokes keyboardWillShow)
	//
	// So we set this up in the completionBlock because there may be pending completionBlocks
	// from processing keyboardWillHide.
	
	
	//
	// What happend to the code that used to be here ???
	//
	
	void (^animationBlock)(void) = ^{
		
		// Nothing to do
	};
	
	void (^completionBlock)(BOOL) = ^(BOOL finished){
		
		// Nothing to do
	};
	
	[UIView animateWithDuration:animationDuration
	                      delay:0.0
	                    options:animationOptions
	                 animations:animationBlock
	                 completion:completionBlock];
}

- (void)handleFancyResizeWithHeightDecrease:(CGFloat)heightDecrease
                          animationDuration:(NSTimeInterval)animationDuration
                           animationOptions:(UIViewAnimationOptions)animationOptions
{
	DDLogAutoTrace();
	NSAssert(heightDecrease <= 0, @"Expected heightDecrease to be negative (decrease)");
	
	CGRect tableFrame = self.tableView.frame;
	CGPoint tableContentOffset = self.tableView.contentOffset;
	
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	NSAssert(selectedIndexPath != nil, @"Expected non-nil selectedIndexPath");
	
	CGRect selectedRect = [self.tableView rectForRowAtIndexPath:selectedIndexPath];
	
	CGFloat bottomOfSelectedRect = selectedRect.origin.y + selectedRect.size.height;
	CGFloat targetBottomOfSelectedRect = tableContentOffset.y + tableFrame.size.height + heightDecrease;
	
	CGFloat diff = bottomOfSelectedRect - targetBottomOfSelectedRect;
	NSAssert(diff >= 0, @"Expected selected cell to be below target");
	
	DDLogVerbose(@"diff: %f", diff);
	DDLogVerbose(@"heightDecrease: %f", heightDecrease);
	
	// Pre-animation we increase the height of the tableView IF
	// the selected cell is only partially visible.
	
	CGRect tableOriginFrame = tableFrame;
	
	CGFloat bottomOfTableView = tableContentOffset.y + tableFrame.size.height;
	if (bottomOfSelectedRect > bottomOfTableView)
	{
		tableOriginFrame.size.height += (bottomOfSelectedRect - bottomOfTableView);
		
		self.tableView.frame = tableOriginFrame;
	}
	
	// During animation we move the origin upward
	
	CGRect tableAnimationFrame = tableOriginFrame;
	tableAnimationFrame.origin.y -= diff;
	
	// After animation, we reset the frame, and adjust the contentOffset & contentInset to match
	
	CGPoint tableCompletionContentOffset = tableContentOffset;
	tableCompletionContentOffset.y += diff;
	
	DDLogVerbose(@"tableContentOffset.y: %f", tableContentOffset.y);
	DDLogVerbose(@"tableCompletionContentOffset.y: %f", tableCompletionContentOffset.y);
	
	void (^animationBlock)(void) = ^{
		
		DDLogVerbose(@"%@ - animationBlock [start]", THIS_METHOD);
		DDLogVerbose(@"tableViewFrame: %@ -> %@", NSStringFromCGRect(tableOriginFrame),
		                                          NSStringFromCGRect(tableAnimationFrame));
		
		self.tableView.frame = tableAnimationFrame;
		
		DDLogVerbose(@"%@ - animationBlock [finish]", THIS_METHOD);
	};
	
	void (^completionBlock)(BOOL) = ^(BOOL finished){
		
		DDLogVerbose(@"%@ - completionBlock [start]", THIS_METHOD);
		DDLogVerbose(@"tableViewFrame: %@ -> %@", NSStringFromCGRect(tableAnimationFrame),
		                                          NSStringFromCGRect(tableFrame));
		
		self.tableView.frame = tableFrame;
		
		DDLogVerbose(@"%@ - completionBlock [finish]", THIS_METHOD);
	};
	
	[UIView animateWithDuration:animationDuration
	                      delay:0.0
	                    options:animationOptions
	                 animations:animationBlock
	                 completion:completionBlock];
}

- (void)handleFancyResizeWithHeightIncrease:(CGFloat)viewFrameHeightDiff
                          animationDuration:(NSTimeInterval)animationDuration
                           animationOptions:(UIViewAnimationOptions)animationOptions
{
	DDLogAutoTrace();
	NSAssert(viewFrameHeightDiff >= 0, @"Expected viewFrameHeightDiff to be non-negative (increase)");

	CGRect tableFrame = self.tableView.frame;
	
	CGRect tableOriginFrame = tableFrame;
	tableOriginFrame.size.height -= viewFrameHeightDiff;
	
	CGPoint tableContentOffset = self.tableView.contentOffset;
	
	CGFloat spaceAbove = self.tableView.contentOffset.y + self.tableView.contentInset.top;
	CGFloat spaceBelow = self.tableView.contentSize.height
	                   - tableContentOffset.y
	                   - tableFrame.size.height
	                   - self.tableView.contentInset.bottom;
	
	if (spaceBelow < 0)
		spaceBelow = 0;
	
	DDLogVerbose(@"spaceAbove: %f", spaceAbove);
	DDLogVerbose(@"spaceBelow: %f", spaceBelow);
	
	DDLogVerbose(@"Step 0: tableOriginFrame: %@", NSStringFromCGRect(tableOriginFrame));
	
	CGFloat left = viewFrameHeightDiff;
	CGFloat diff;
	
	if (left > 0)
	{
		// Step 1 - increase size.height by spaceBelow
		
		diff = MIN(spaceBelow, viewFrameHeightDiff);
		left -= diff;
		
		tableOriginFrame.size.height += diff;
		
		DDLogVerbose(@"Step 1: tableOriginFrame: %@", NSStringFromCGRect(tableOriginFrame));
	}
	if (left > 0)
	{
		// Step 2 - move origin.y upwards by spaceAbove &
		//          increase size.height by spaceAbove &
		//          update scroll position so it looks like nothing changed.
		
		diff = MIN(spaceAbove, left);
		left -= diff;
		
		tableOriginFrame.size.height += diff;
		tableOriginFrame.origin.y -= diff;
		
		tableContentOffset.y -= diff;
		self.tableView.contentOffset = tableContentOffset;
		
		DDLogVerbose(@"Step 2: tableOriginFrame: %@", NSStringFromCGRect(tableOriginFrame));
	}
	if (left > 0)
	{
		// Step 3 - increase height by whatever is left
		
		tableOriginFrame.size.height += left;
		
		DDLogVerbose(@"Step 3: tableOriginFrame: %@", NSStringFromCGRect(tableOriginFrame));
	}
	
	self.tableView.frame = tableOriginFrame;
	
	DDLogVerbose(@"tableView: %@ -> %@", NSStringFromCGRect(tableOriginFrame), NSStringFromCGRect(tableFrame));
	
	void (^animationBlock)(void) = ^{
		
		self.tableView.frame = tableFrame;
	};
	
	[UIView animateWithDuration:animationDuration
	                      delay:0.0
	                    options:animationOptions
	                 animations:animationBlock
	                 completion:NULL];
}

- (void)handleResizeWithKeyboardHeight:(CGFloat)keyboardHeight
                     animationDuration:(NSTimeInterval)animationDuration
                        animationCurve:(UIViewAnimationCurve)animationCurve
                    isKeyboardWillShow:(BOOL)keyboardWillShow
{
	DDLogAutoTrace();
	
	UIViewAnimationOptions animationOptions = 0;
	switch (animationCurve)
	{
		case UIViewAnimationCurveEaseInOut : animationOptions |= UIViewAnimationOptionCurveEaseInOut; break;
		case UIViewAnimationCurveEaseIn    : animationOptions |= UIViewAnimationOptionCurveEaseIn;    break;
		case UIViewAnimationCurveEaseOut   : animationOptions |= UIViewAnimationOptionCurveEaseOut;   break;
		case UIViewAnimationCurveLinear    : animationOptions |= UIViewAnimationOptionCurveLinear;    break;
		default                            : animationOptions |= (animationCurve << 16);              break;
	}
	
	if (keyboardWillShow)
	{
		// View is getting SMALLER
		//
		// Figure out if the selected conversation is going to be hidden by the keyboard.
		// If so, we can do a fancier resize animation which results in the selected cell remaining visible.
		// Otherwise a simple frame resize animation is all we need.
		
		BOOL useFancyResizeAnimation = NO;
		
		NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
		if (selectedIndexPath)
		{
			// First we check to see if the cell is visible now.
			// If it's not, then we're not going to worry about it.
			// Perhaps the user has scrolled it off the screen.
			
			CGRect selectedRect = [self.tableView rectForRowAtIndexPath:selectedIndexPath];
			
			CGRect visibleRect;
			visibleRect.origin = self.tableView.contentOffset;
			visibleRect.size = self.tableView.frame.size;
			
			if (CGRectIntersectsRect(visibleRect, selectedRect))
			{
				// The cell is currently visible.
				// Is it going to be hidden by the keyboard?
				
				CGFloat bottomOfSelectedRect = selectedRect.origin.y + selectedRect.size.height;
				
				CGFloat cutoff = self.tableView.contentOffset.y + self.tableView.frame.size.height - keyboardHeight;
				
				if (bottomOfSelectedRect > cutoff)
				{
					useFancyResizeAnimation = YES;
				}
			}
		}
		
		if (useFancyResizeAnimation)
		{
			[self handleFancyResizeWithHeightDecrease:(keyboardHeight * -1.0F)
			                        animationDuration:animationDuration
			                         animationOptions:animationOptions];
		}
		else
		{
			[self handleSimpleResizeWithHeightDecrease:(keyboardHeight * -1.0F)
			                         animationDuration:animationDuration
			                          animationOptions:animationOptions];
		}
	}
	else
	{
		// View is getting BIGGER
		
		[self handleFancyResizeWithHeightIncrease:keyboardHeight
		                        animationDuration:animationDuration
		                         animationOptions:animationOptions];
	}
}

/* ET 10/28/14 DEPRECATE - redundant delegate implementations in favor of generic delegate callback for
 * all "Activation" view controllers, i.e OnboardViewController, LoginViewController, CreateAccountViewController.
 *
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark LogInViewController methods
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////// 
- (void)logInViewController:(LogInViewController *)sender dismissAddAccounts:(NSError*)error
 */
#pragma mark - ActivationVCDelegate Methods
- (void)dismissActivationVC:(UIViewController *)vc error:(NSError*)error
{
	if (AppConstants.isIPhone)
	{
		[self.navigationController popViewControllerAnimated: YES];
	}
	else
	{
		[popoverController dismissPopoverAnimated:YES];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)titleTap:(id)sender
{
	DDLogAutoTrace();

    STUser *localUser = STDatabaseManager.currentUser;
    UserInfoVC *uivc = [[UserInfoVC alloc] initWithUser:localUser];
    
    [self showViewController:uivc
                    fromRect:titleButton.frame
                      inView:self.navigationController.navigationBar
                  hideNavBar:NO];
}


- (void)activateTapped:(id)sender
{
    UIStoryboard *activationStoryboard = [UIStoryboard storyboardWithName:@"Activation" bundle:nil];
    LogInViewController *avc = [activationStoryboard instantiateViewControllerWithIdentifier:@"LogInViewController"];
    
    avc.delegate = self;
    avc.isInPopover = YES;
    avc.existingUserID = STDatabaseManager.currentUser.uuid;
  
    [self showViewController:avc
	                fromRect:titleButton.frame
	                  inView:self.navigationController.navigationBar
	              hideNavBar:NO];
}


- (void)unprovisionedTapped:(id)sender
{
	DDLogAutoTrace();
    
    CGRect startRect = titleButton.frame;
    startRect.origin.y -= self.navigationController.navigationBar.frame.size.height;
	
    //ET 10/16/14 actionSheet udpate
    [OHActionSheet showFromRect:startRect 
                       sourceVC:self 
                         inView:self.view
                 arrowDirection:UIPopoverArrowDirectionUp
                          title:NSLocalizedString(@"Your silent circle subscription has has not yet been funded. "
                                                  @"Please log into your account and setup payment to continue using"
                                                  @" Silent Text.", @"Subscription is unpaid")
              cancelButtonTitle:NSLS_COMMON_CANCEL
         destructiveButtonTitle:NULL
              otherButtonTitles: @[NSLS_COMMON_SIGN_UP]
                     completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                         
                         NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
                         
                         if ([choice isEqualToString:NSLS_COMMON_SIGN_UP])
                         {
                             UIApplication *app = [UIApplication sharedApplication];
                             [app openURL:[NSURL URLWithString:kSilentCircleSignupURL] ];
                         }
                     }];
    
}

- (void)expiredTapped:(id)sender
{
	DDLogAutoTrace();
    
    CGRect startRect = titleButton.frame;
    startRect.origin.y -= self.navigationController.navigationBar.frame.size.height;
	
    //ET 10/16/14 actionSheet udpate
    [OHActionSheet showFromRect:startRect 
                       sourceVC:self 
                         inView:self.view
                 arrowDirection:UIPopoverArrowDirectionUp
                          title:NSLocalizedString(@"Your silent circle subscription has expired, please log into your"
                                                  @" account and renew to continue using Silent Text.", @"Subscription"
                                                  @" has Expired")
              cancelButtonTitle:NSLS_COMMON_CANCEL
         destructiveButtonTitle:NULL
              otherButtonTitles:@[NSLS_COMMON_SIGN_UP]
                     completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                         
                         NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
                         
                         if ([choice isEqualToString:NSLS_COMMON_SIGN_UP])
                         {
                             
                             UIApplication *app = [UIApplication sharedApplication];
                             [app openURL:[NSURL URLWithString:kSilentCircleSignupURL] ];
                         }
                         
                     }];

}


- (void)offlineTapped:(id)sender
{
	DDLogAutoTrace();
	
	MessageStream *ms = [MessageStreamManager messageStreamForUser:STDatabaseManager.currentUser];
	MessageStream_State state = ms.state;
    
    switch (state)
	{
		case MessageStream_State_Disconnected:
		{
			[self updateUserState:self.currentUserID enable:YES];
			
			break;
		}
        case MessageStream_State_Error:
		{
			NSString *errorString = ms.errorString;
            NSString *err = errorString ? errorString: NSLocalizedString(@"Unknown", @"Unknown");
            NSString *frmt = nil;
            NSString *title = nil;

            CGRect startRect = titleButton.frame;
            startRect.origin.y -= self.navigationController.navigationBar.frame.size.height;

            if (AppConstants.isIPhone)
            {
				frmt = NSLocalizedString(@"%@ was unable to connect. Error \"%@\"",
				                         @"<username> was unable to connect. Error \"<localized error>\"");
                title = [NSString stringWithFormat:frmt, STDatabaseManager.currentUser.jid.user, err];
            }
            else // if (AppConstants.isIPad)
            {
                frmt = NSLocalizedString(@"Connection Failed: %@", @"Connection Failed: <localized error>");
                title = [NSString stringWithFormat:frmt, err];
            }

            //ET 10/16/14 actionSheet udpate
            [OHActionSheet showFromRect:startRect 
                               sourceVC:self 
                                 inView:self.view
                         arrowDirection:UIPopoverArrowDirectionUp
                                  title:title
                      cancelButtonTitle:NSLS_COMMON_CANCEL
                 destructiveButtonTitle:NULL
                      otherButtonTitles:@[NSLS_COMMON_TRY_AGAIN]
                             completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {                                 

                                 if (sheet.cancelButtonIndex != buttonIndex)
                                 {
                                     [self updateUserState:self.currentUserID enable:YES];
                                 }
                             }];
			break;
		}
		case MessageStream_State_Connecting:
		case MessageStream_State_Connected:
		{
			// we shountd see this state since the button item should be removed.
			break;
		}
	}
}


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


#pragma mark - UITableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender
{
    //ET 02/22/15 - original line causes crash when incoming msg,
    // system msg "failure to authorize user" in sim.
//    return (STAppDelegate.passcodeManager.isLocked)?0:1; //orig
    return [mappings numberOfSections];
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
	return [mappings numberOfItemsInSection:section];
}

// possible fix for cell not showing up properly on IOS 8?
// see https://devforums.apple.com/message/991443#991443

-(CGFloat)tableView:(UITableViewCell*)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return 80;
    
//    return self.tableView.rowHeight;
}

//ST-897: Moved cell configuration, and refactored, to configureCell:withIndexPath: 
- (UITableViewCell *)tableView:(UITableView *)sender cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
//    DDLogCyan(@"%s\n  DEQUEUE CELL", __PRETTY_FUNCTION__);
    //ST-897 01/17/15 - use nib with label fields
    ConversationViewTableCell *cell = [sender dequeueReusableCellWithIdentifier:@"ConversationViewTableCell"];

    //---------------------------------------------------------------// 
    // CLEAR CELL DATA
    //---------------------------------------------------------------//
    cell.avatar          = nil;
    cell.badgeColor      = nil;
    cell.badgeString     = nil;
    cell.badgeTitleColor = nil;
    cell.conversationId  = nil;
    cell.date            = nil;
    cell.dateColor       = nil;
    cell.isOutgoing      = NO;
    cell.isStatus        = NO;
    cell.leftBadgeImage  = nil;
    cell.subTitleColor   = nil;
    cell.subTitleString  = nil;
    cell.titleColor      = nil;
    cell.titleString     = nil;

    //----------------------------------------------------------------------------------------------------------------// 
    // CELL BACKGROUND
    //----------------------------------------------------------------------------------------------------------------// 
    // Sometimes at app first launch, cell backgrounds will be white, regardless of theme.
    // This may only be when there is a connection error issue (lightning icon). Haven't been
    // able to isolate the cause.
    // This line ensures the cell background will match the tableView backgroundColor.
    // Note: tableView.backgroundColor is initially set in viewDidLoad.changeTheme:nil
    //----------------------------------------------------------------------------------------------------------------// 
    if (NO == [cell.backgroundColor isEqual:sender.backgroundColor])
        cell.backgroundColor = sender.backgroundColor;
    

    //----------------------------------------------------------------------------------------------------------------// 
    // CELL SELECTED VIEW/COLOR
    //----------------------------------------------------------------------------------------------------------------// 
    static NSInteger const selectedBackgroundViewTag = 15;
    if (cell.selectedBackgroundView.tag != selectedBackgroundViewTag)
    {
        [cell.selectedBackgroundView removeFromSuperview];
        UIView *bgColorView = [[UIView alloc] initWithFrame:cell.frame];
        bgColorView.tag = selectedBackgroundViewTag;
        bgColorView.layer.masksToBounds = YES;
        bgColorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        bgColorView.translatesAutoresizingMaskIntoConstraints = YES;        
        bgColorView.backgroundColor = [theme.appTintColor colorWithAlphaComponent:0.4];
        cell.selectedBackgroundView = bgColorView;
    }    
    //----------------------------------------------------------------------------------------------------------------// 
            
    //---------------------------------------------------------------// 
    // CELL THEME COLORS
    //---------------------------------------------------------------// 
    // Note: ConversationTableCell checks color equality in setters
    cell.badgeBorderColor = theme.appTintColor;
    // leave badgeColor (background) default (black)
    cell.dateColor        = theme.messageLabelTextColor;
    cell.subTitleColor    = theme.conversationBodyColor;
    cell.titleColor       = theme.conversationHeaderColor;
        
    
    cell = [self configureCell:cell withIndexPath:indexPath];

    return cell;
}


#pragma mark Configure cell
/**
 * This method configures cell with conversation data.
 *
 * The cell configuration was abstracted to here to allow databaseConnectionDidUpdate to work around an Apple
 * tableView bug which caused a "flashing" of a cell when reloadRowAtIndexPaths: is invoked and then a row
 * re-selected - both without animation. This method allows the cell data/appearance to be updated without
 * reloading and reselecting the row, fixing the "flashing".
 */
- (ConversationViewTableCell *)configureCell:(ConversationViewTableCell *)cell withIndexPath:(NSIndexPath *)ip
{
//    DDLogCyan(@"%s\n  CONFIGURE CELL", __PRETTY_FUNCTION__);
    
    __block STConversation     *conversation = nil;
    __block STMessage          *message = nil;
    __block SCimpSnapshot      *scimpSnapshot = nil;
    __block NSArray            *users = nil;
    __block NSUInteger         conversationUnreadCount = 0;
    __block NSUInteger         conversationNeedsResendCount = 0;

    // Fetch conversation info from the database
    [databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        conversation = [[transaction ext:Ext_View_Order] objectAtIndex:ip.row
                                                               inGroup:self.currentUserID];
        
        message = [[transaction ext:Ext_View_Order] lastObjectInGroup:conversation.uuid];
        
        conversationUnreadCount = [[transaction ext:Ext_View_Unread] numberOfItemsInGroup:conversation.uuid];
        conversationNeedsResendCount = [[transaction ext:Ext_View_NeedsReSend] numberOfItemsInGroup:conversation.uuid];
        
        
        if (conversation.isNewMessage)
        {
            return; // from block
        }
        
        if (conversation.isMulticast)
        {
            users = [[DatabaseManager sharedInstance] multiCastUsersForConversation:conversation 
                                                                    withTransaction:transaction];
        }
        else
        {
            STUser *user = [[DatabaseManager sharedInstance] findUserWithJID:conversation.remoteJid
                                                                 transaction:transaction];
            if (user) {
                users = @[ user ];
            }
            
            for (NSString *scimpID in conversation.scimpStateIDs)
            {
                SCimpSnapshot *aScimpSnapshot = [transaction objectForKey:scimpID inCollection:kSCCollection_STScimpState];
                if (aScimpSnapshot)
                {
                    // find the remote device we were talking to last.
                    if ([aScimpSnapshot.remoteJID isEqualToJID:conversation.remoteJid options:XMPPJIDCompareFull])
                    {
                        scimpSnapshot = aScimpSnapshot;
                        break;
                    }
                }
            }
        }
    }]; // end dbConnection block
    
    // Ensure the cell will be initialized with the appropriate conversation data;
    // if conversationIds don't match, reset the conversationId and nil the avatar.
    // Note: ConversationTableViewCell.prepareForReuse() clears all cell data fields. // true? or moved to cellForRow:?
    NSString *conversationId = conversation.uuid;
    if (![cell.conversationId isEqualToString:conversationId])
    {
        cell.conversationId = conversationId;
        cell.avatar = nil;
    }

    NSString *displayName = nil;
    UIImage *avatar = nil;
    BOOL needsFetchedAvatar = YES;
    CGFloat diameter = [ConversationViewTableCell avatarSize];
    
    // NEW MESSAGE
    if (conversation.isNewMessage)
    {
        displayName = NSLocalizedString(@"New Message", @"New message cell title");
        
        avatar = [AvatarManager cachedOrDefaultAvatarForConversation:conversation 
                                                                user:nil 
                                                            diameter:diameter 
                                                                theme:theme 
                                                                usage:kAvatarUsage_None];
    }
    // MULTICAST MESSAGE
    else if (conversation.isMulticast)
    {
        NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        NSString *title = [conversation.title stringByTrimmingCharactersInSet:whitespace];
        
        if ([title length] > 0)
        {
            displayName = title;
        }
        else
        {
            ///// VINNIE THIS CODE CAN BE IMPROVED
            CGRect titleRect;
            NSDictionary *titleAttributes;
            
            [ConversationViewTableCell getTitleRect:&titleRect titleAttributes:&titleAttributes];
            
            displayName = [STUser displayNameForUsers:users
                                             maxWidth:titleRect.size.width
                                       textAttributes:titleAttributes];
        }
        
        // Get cached or default multiCast avatar
        avatar = [AvatarManager cachedOrDefaultAvatarForConversation:conversation 
                                                                user:nil 
                                                            diameter:diameter 
                                                                theme:theme 
                                                                usage:kAvatarUsage_None];
    }
    // P2P MESSAGE
    else
    {
        if (IsSTInfoJID(conversation.remoteJid))
        {
            displayName = [AppConstants STInfoDisplayName];
        }
        else if (IsOCAVoicemailJID(conversation.remoteJid))
        {
            displayName = [AppConstants OCAVoicemailDisplayName];
        }
        else if ([users lastObject])
        {
            STUser *user = [users lastObject];
            displayName = user.displayName;
        }
        else
        {
            DDLogError(@"NO displayName found for conversation");
        }
        
        avatar = [AvatarManager cachedOrDefaultAvatarForConversation:conversation 
                                                                    user:[users lastObject]
                                                                diameter:diameter 
                                                                   theme:theme 
                                                                   usage:kAvatarUsage_None];
        // Do NOT fetch avatar if system or voicemail conversation
        needsFetchedAvatar = !(IsSTInfoJID(conversation.remoteJid) || IsOCAVoicemailJID(conversation.remoteJid));
    }
    
    //--------------------------------------------------------// 
    // SET DISPLAY NAME
    //--------------------------------------------------------// 
    cell.titleString = displayName;
    
    
    //--------------------------------------------------------// 
    // SET AVATAR IMAGE
    //--------------------------------------------------------// 
    cell.avatar = avatar;

    
    //----------------------------------------------------------------------------------------------------------------// 
    // ASYNCHRONOUS FETCH AVATAR IMAGE
    //----------------------------------------------------------------------------------------------------------------// 
    // The needsFetchedAvatar bool means:
    //   we need to make an asychronous call for an avatar image
    // 01/26/15 Note: except for system and voicemail conversations, we always do the async fetch - 
    // a db fetch, not to be confused with a network fetch.
    if (needsFetchedAvatar)
    {
        if (conversation.isMulticast)
        {
            [[AvatarManager sharedInstance] fetchMultiAvatarForUsers:users
                                                        withDiameter:diameter
                                                               theme:theme 
                                                               usage:kAvatarUsage_None 
                                                     completionBlock:^(UIImage *multiAvatar)
             {
                 if (multiAvatar)
                 {
                     // Make sure the cell is still being used for the conversationId.
                     // During scrolling, the cell may have been recycled.
                     if ([cell.conversationId isEqualToString:conversation.uuid])
                         cell.avatar = avatar;
                 }
             }];
        }
        else
        {
            [[AvatarManager sharedInstance] fetchAvatarForUser:[users lastObject] 
                                                  withDiameter:diameter 
                                                         theme:theme 
                                                         usage:kAvatarUsage_None 
                                               completionBlock:^(UIImage *avatar) {
                                                   
                                                   if (avatar)
                                                   {
                                                       // Make sure the cell is still being used for the conversationId.
                                                       // During scrolling, the cell may have been recycled.
                                                       if ([cell.conversationId isEqualToString:conversation.uuid])
                                                           cell.avatar = avatar;
                                                   }
                                               }];
        }
    }       
    //----------------------------------------------------------------------------------------------------// 
    
    
    //----------------------------------------------------------------------------------------------------// 
    // STATUS / DATE
    //----------------------------------------------------------------------------------------------------// 
    UIImage *statusImage = nil;
    
    if (message)
    {
        Siren *siren = [message siren];
        
        if(message.isStatusMessage)
        {
            NSDictionary* statusMessage = message.statusMessage;
            NSString* statusString = NSLocalizedString(@"Error", @"Error");
            
            if([statusMessage objectForKey:@"keyState"])
            {
                SCimpState scimpState = (SCimpState)[[statusMessage objectForKey:@"keyState"] intValue];
                
                
                switch (scimpState) {
                    case kSCimpState_Commit:
                        statusString = NSLocalizedString( @"Establishing Keys",  @"Establishing Keys");
                        statusImage = keyImg_1;
                        break;
                        
                    case kSCimpState_DH1:
                        statusString = NSLocalizedString( @"Requesting Keying",  @"Requesting Keying");
                        statusImage = keyImg_2;
                        break;
                        
                    case kSCimpState_DH2:
                        statusString = NSLocalizedString( @"Keys Established",  @"Keys Established");
                        statusImage = keyImg_3;
                        break;
                        
                    default:
                        break;
                }
            }
            else if([statusMessage objectForKey:@"keyInfo"])
            {
                //	NSDictionary* keyInfo = [statusMessage objectForKey:@"keyInfo"];
                statusString = @"Keying Complete";
                statusImage = keyImg_4;
            }
            
            cell.subTitleString = statusString;
            cell.isStatus = YES;
            
        }
        else if (!siren.isValid)
        {
            cell.subTitleString = NSLocalizedString(@"<Decryption Error>", @"Error message");
            cell.subTitleColor = UIColor.redColor;
            cell.isStatus = YES;
        }
        else if (siren.mediaType)
        {
            cell.isStatus = YES;
            
            // we have to special case test for PDF's because droid gets the media type wrong
            NSString* mediaString = [STAppDelegate stringForUTI: siren.isPDF? (__bridge NSString*) kUTTypePDF : siren.mediaType];
            
            cell.subTitleString  = [NSString stringWithFormat:@"%@",mediaString ];
            
            /* sepcial case code to handle the fact that android sends a text message with audio */
            if( UTTypeConformsTo( (__bridge CFStringRef)  siren.mediaType, kUTTypeAudio) && siren.duration)
            {
                NSDateFormatter* durationFormatter =  [SCDateFormatter localizedDateFormatterFromTemplate:@"mmss"];
                NSString* durationText = [durationFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970: siren.duration.doubleValue]];
                
                if(siren.isVoicemail)
                {
                    mediaString =  NSLocalizedString(@"Voice Mail", @"Voice Mail");
                    mediaString = [mediaString stringByAppendingFormat:@": %@\n", durationText];
                    if(siren.callerIdName)
                        mediaString = [mediaString stringByAppendingFormat:@"%@ ", siren.callerIdName];
                    else if(siren.callerIdNumber)
                        mediaString = [mediaString stringByAppendingFormat:@"%@ ", siren.callerIdNumber];
                    
                    cell.subTitleString = mediaString;
                }
                else
                {
                    cell.subTitleString = [cell.subTitleString stringByAppendingFormat:@": %@", durationText];
                    
                }
            }
            else if(siren.message)
            {
                NSString* theFileName =siren.message;
                
                if( theFileName.pathExtension)
                {
                    theFileName = [siren.message stringByDeletingPathExtension];
                }
                cell.subTitleString = [cell.subTitleString stringByAppendingFormat:@": %@", theFileName];
            }
        }
        else if(siren.isMapCoordinate)
        {
            cell.subTitleString =  NSLocalizedString(@"<Current Location>", @"Current Location");
        }
        else if(siren.message)
        {
            cell.subTitleString =  siren.message;
        }
        else if(siren.threadName)
        {
            cell.subTitleString =  NSLocalizedString(@"<Conversation Name Changed>", @"Conversation Name Changed");
            cell.subTitleColor = UIColor.grayColor;
            cell.isStatus = YES;
        }
        
        cell.date = [message timestamp];
        cell.isOutgoing = message.isOutgoing;
    }
    else
    {
        cell.subTitleString = @"";
        cell.subTitleColor = NULL;
        cell.isStatus = NO;
        cell.date = nil;
     }
    //----------------------------------------------------------------------------------------------------//
    
    
    //-------------------------------------------------------------------// 
    // SCIMP STATE
    //-------------------------------------------------------------------// 
    if (scimpSnapshot && IsSCLError(scimpSnapshot.protocolError))
    {
        cell.leftBadgeImage = attentionImg;
    }
    else if(message.isStatusMessage)
    {
        cell.leftBadgeImage =  statusImage;
    }
    else if (conversationNeedsResendCount > 0)
    {
        cell.leftBadgeImage = attentionImg;
    }
    else if ((message && !message.isOutgoing) && !conversation.isNewMessage)
    {
        cell.leftBadgeImage = replyImg;
    }
    else
    {
        cell.leftBadgeImage = nil;
    }
    //-------------------------------------------------------------------// 
    
    
    //----------------------------------------------------------------------------------------------------// 
    // BADGE
    //----------------------------------------------------------------------------------------------------// 
    //ET 01/27/15
    // ST-897: Don't display a badge on currently selected conversation cell.
    // On iPad, this avoids the badge flashing on and off for an incoming message.
    // On iPhone, conversation cells are not selected, being the only view. This
    // allows the badge to appear.
    // Note: making the condition if ([STPreferences selectedConversationIdForUserId:self.currentUserID]),
    // instead of cell.isSelected, results in the badge not appearing on iPhone.
    if (conversationUnreadCount > 0)
    {
        if (NO == cell.isSelected)
        {
            // Set string - the cell setter updates its private label properties
            NSString *badgeString;
            if (conversationUnreadCount <= 99)
            {
                badgeString = [NSString stringWithFormat:@"%lu", (unsigned long)conversationUnreadCount];
            }
            else
            {
                badgeString = @"99+";
            }
            
            cell.badgeString = badgeString;
        }
    }
    else
    {        
        if (cell.badgeString)
            cell.badgeString = nil;
    }
    
    return cell;
}

- (NSIndexPath *)tableView:(UITableView *)sender willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //ET 01/20/15
    // ST-897: Ensure a cell badge (if any) is cleared when tapped
    ConversationViewTableCell *cell = (ConversationViewTableCell *)[sender cellForRowAtIndexPath:indexPath];
    if (cell.badgeString)
        cell.badgeString = nil;
    
    return indexPath;
}

- (void)tableView:(UITableView *)sender didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	__block NSString *conversationId = nil;
    
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		conversationId = [[transaction ext:Ext_View_Order] keyAtIndex:indexPath.row
		                                                      inGroup:self.currentUserID];
	}];
	
	self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back",nil)
	                                                                         style:UIBarButtonItemStylePlain
	                                                                        target:nil
	                                                                        action:nil];
	
	[STPreferences setSelectedConversationId:conversationId forUserId:self.currentUserID];
	[self setMessageViewBackButtonCount:0];
    
    if (AppConstants.isIPhone)
    {
		MessagesViewController *messagesViewController = [STAppDelegate createMessagesViewController];
		messagesViewController.conversationId = conversationId;
		
		[self.navigationController pushViewController:messagesViewController animated:YES];
	}
    else
    {
		STAppDelegate.messagesViewController.conversationId = conversationId;
    }
    
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
                                            forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
		__block NSString *thisConversationId = nil;
		
		[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			thisConversationId = [[transaction ext:Ext_View_Order] keyAtIndex:indexPath.row
			                                                          inGroup:self.currentUserID];
		}];
		
		[self deleteConversation:thisConversationId];
    }
}

@end
