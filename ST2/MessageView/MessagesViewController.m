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
#import "MessagesViewController.h"

#import "AppConstants.h"
#import "AppDelegate.h"
#import "AutoGrowingTextView.h"
#import "ConversationDetailsVC.h"
#import "ConversationSecurityVC.h"
#import "ConversationViewController.h"
#import "ContactsSubViewControllerHeader.h"
#import "DAKeyboardControl.h"
#import "FileImportViewController.h"
#import "GeoTracking.h"
#import "MessageRecipientViewController.h"
#import "NewGeoViewController.h"
#import "UserInfoVC.h"
#import "OHActionSheet.h"
#import "OHAlertView.h"
#import "PersonSearchResult.h"
#import "SCimpSnapshot.h"
#import "SCimpWrapper.h"
#import "SCCalendar.h"
#import "SCCameraViewController.h"
#import "SCDateFormatter.h"
#import "SCImagePickerViewController.h"
#import "SCloudObject.h"
#import "SCloudPreviewer.h"
#import "SecurityStatusButton.h"
#import "SilentTextStrings.h"
#import "STConversation.h"
#import "STImage.h"
#import "STInteractiveTextView.h"
#import "STLogging.h"
#import "STMessage.h"
#import "STPreferences.h"
#import "STSCloud.h"
#import "STUserManager.h"
#import "vCalendarViewController.h"
#import "YapCollectionKey.h"
#import "YRDropdownView.h"

// Managers
#import "AddressBookManager.h"
#import "AvatarManager.h"
#import "MessageStreamManager.h"
#import "SCloudManager.h"
#import "SCWebAPIManager.h"

// Categories
#import "CLLocation+NSDictionary.h"
#import "NSDate+SCDate.h"
#import "NSString+Emojize.h"
#import "NSString+SCUtilities.h"
#import "STMessage+Utilities.h"
#import "UIColor+Blender.h"
#import "UIImage+Crop.h"
#import "UIImage+maskColor.h"
#import "UIImage+Thumbnail.h"

// Libraries
#import <AVFoundation/AVFoundation.h>
#import <libkern/OSAtomic.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <QuartzCore/QuartzCore.h>
#import <SCCrypto/SCcrypto.h>


#define USE_SC_DIRECTORY_SEARCH 0

// LEVELS: off, error, warn, info, verbose; FLAGS: trace
#if DEBUG && robbie_hanson
  static const int ddLogLevel = LOG_LEVEL_INFO; // | LOG_FLAG_TRACE;
#elif DEBUG && eric_turner
    static const int ddLogLevel = LOG_FLAG_INFO; // | LOG_FLAG_TRACE;
#elif DEBUG && (vinnie_moscaritolo || vinnie)
  static const int ddLogLevel = LOG_FLAG_ERROR;
#elif DEBUG
  static const int ddLogLevel = LOG_LEVEL_WARN;
#else
  static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

#define kBubbleCellTextFont   [UIFont preferredFontForTextStyle:UIFontTextStyleBody]
#define kBubbleCellNameFont   [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1]
#define kBubbleCellStatusFont [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]

/**
 * This is a question of UI terminology.
 * 
 * - (ONLY_BURN_REMOTE_MESSAGES == 1) : Will use "Clear" menu item for incomming messages.
 * - (ONLY_BURN_REMOTE_MESSAGES == 0) : Will use "Burn" menu item for incomming messages.
 *
 * Maybe we like the word Burn for marketing reasons?
**/
#define ONLY_BURN_REMOTE_MESSAGES 1

static const CGFloat kAvatarDiameter = 36; //ET 06/11/14
//static const CGFloat kThumbScloudNailHeight = 90;


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface UIColor (SCUtilities)
@end

@implementation UIColor (SCUtilities)

+ (UIColor *)publicKeyColor {
	return [UIColor colorWithRed:0.216 green:0.373 blue:0.965 alpha:1];
}

+ (UIColor *)inDBColor {
	return [UIColor colorWithRed:0. green:0. blue:0.965 alpha:1];
}

+ (UIColor *)dhKeyColor {
	return [UIColor colorWithRed:0.333 green:0.741 blue:0.235 alpha:1];
}

+ (UIColor *)notfoundColor {
	return [UIColor colorWithRed:1 green:0.15 blue:0.15 alpha:1];
}

+ (UIColor *)notAllowedColor {
	return [UIColor colorWithRed:1 green:0.15 blue:0.0 alpha:1];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

typedef struct {
    CGPoint point;
    BOOL    valid;
} TableOffset;


@implementation MessagesViewController
{
	AppTheme *theme;
	
	YapDatabaseConnection *databaseConnection;
	YapDatabaseViewMappings *mappings;
	
	NSString *oldMostRecentDeliveredMessageId;
	NSMutableDictionary *tempVisibleCellsDict;
	
	NSString *conversationId;
	
	UIView *topView;
	TITokenFieldView *tokenFieldView;
	NSMutableDictionary *tokenFieldAutocomplete;
	NSMutableDictionary *recipientDict;
	
	STInteractiveTextView *tempTextView;
	
	NSCache *cellHeightCache;
	NSCache *timestampCache;
	
	NSCalendar *calendar;
	NSDateFormatter *dateFormatter;
 	NSDateFormatter *timeFormatter;
 	
	NSDateFormatter *durationFormatter;
	
	BOOL hasScrolledToBottomInLayout;
	BOOL skipScrollToBottom;
	BOOL tableViewHasNewItems;
	BOOL mostRecentDeliveredMessageChanged;
	
	BOOL isPopingBackIntoView;
	BOOL showingMenuController;
	BOOL ignoreSingleTap;
	BOOL canSendMedia;
	BOOL canMulticast;
	BOOL showVerfiedMessageSigs;
	
	BOOL displayTableViewAdditions;
	CGFloat lastInputViewHeight;

	// Infinity scroll support
	NSDate *lastRangeChange;
	
	// these are cached values for faster response for UI
	STConversation *conversation;
	XMPPJID * localJID;  // todo: kill this ivar
	XMPPJID * remoteJID; // todo: kill this ivar
	NSSet *conversationUserIds;
	NSDictionary * userInfoDict; //  key = jid, values = "avatar", "displayName", bubbleColor, textcolor
	NSString* titleString;
    
	UITapGestureRecognizer *singleTapRecognizer;
	UILongPressGestureRecognizer *longPressRecognizer;
	
	NSString *selectedMessageID;  //used for action sheets

    //ET 03/31/15 - Make this a public property
    // ST-1021: backgrounding
//	UIPopoverController *popoverController;
	BOOL temporarilyHidingPopover;
	CGRect popoverFromRect;
	UIView *popoverInView;
	NSString *popoverMessageId;
	UIPopoverArrowDirection popoverArrowDirections;
	CGSize popoverContentSize;    
    
    //ET 03/31/15 - DEPRECATE
    // ST-1021: There seems to be no reason to keep a strong reference
    // to the popoverContentVC.
//	UIViewController *popoverContentViewController;

    MoreMenuViewController        * moreMenuViewController;
    SCContactBookPicker           * cbc;
    SCImagePickerViewController   * ipc;
    SCloudPreviewer               * scloudPreviewer;
    
    UIView *snapshotView; //ET 02/10/15 renamed
    
//	UIDocumentInteractionController* docController;
	
	UIImage * conInfo_Mute;
	UIBarButtonItem *conversationInfoButton;
	SecurityStatusButton *securityButton;
	AudioPlaybackView *audioPlaybackView;
    
    UIImage * key_1;
    UIImage * key_2;
    UIImage * key_3;
    UIImage * key_4;
    UIImage * info_circle;
	
	UIButton* titleButton;
	UIMenuController *menuController;
    
    TableOffset restoreOffset;
    
    //03/26/15 - Accessibility
    BOOL _splitScreenModePrimaryHidden;
    UIButton *_messagesArrowButton;
}

@synthesize conversationId = conversationId;
@synthesize tableView = tableView;
@synthesize inputView = inputView;
@synthesize chatOptionsView = chatOptionsView;
@synthesize audioInputView = audioInputView;
@synthesize popoverController=popoverController;

- (id)init
{
	return [self initWithProperNib];
}

- (id)initWithProperNib
{
	NSString *nibName = NSStringFromClass([self class]);
	
	if ((self = [super initWithNibName:nibName bundle:nil]))
	{
		cellHeightCache = [[NSCache alloc] init];
		cellHeightCache.countLimit = 500;
		
		timestampCache = [[NSCache alloc] init];
		timestampCache.countLimit = 500;
		
		calendar = [SCCalendar cachedAutoupdatingCurrentCalendar];
		dateFormatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterMediumStyle
														  timeStyle:NSDateFormatterShortStyle];
        
        timeFormatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterNoStyle
														  timeStyle:NSDateFormatterShortStyle];
		
		durationFormatter = [[NSDateFormatter alloc] init] ;
		[durationFormatter setDateFormat:@"mm:ss"];
		
		conInfo_Mute        =   [UIImage imageNamed: @"info-mute"];
        key_1               =   [UIImage imageNamed: @"key1"];
        key_2               =   [UIImage imageNamed: @"key2"];
        key_3               =   [UIImage imageNamed: @"key3"];
        key_4               =   [UIImage imageNamed: @"key4"];
        info_circle         =   [UIImage imageNamed: @"info-circle"];
        
		userInfoDict = [[NSDictionary alloc] init];
		
		recipientDict = [[NSMutableDictionary alloc] init];
        
        restoreOffset.valid = NO;
        
	}
	return self;
}

- (void)dealloc
{
	DDLogAutoTrace();
	
	[[NSNotificationCenter defaultCenter] removeObserver:self.tableView];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self removeObserverForTableViewContentSize];
	
	[self.view removeKeyboardControl];
}

- (void)addObserverForTableViewContentSize
{
	[tableView addObserver:self
	            forKeyPath:@"contentSize"
	               options:0
	               context:NULL];
}

- (void)removeObserverForTableViewContentSize
{
	[tableView removeObserver:self forKeyPath:@"contentSize"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(__unused NSDictionary *)change
					   context:(__unused void *)context
{
	if ([keyPath isEqualToString:@"contentSize"] && (object == tableView))
	{
		// These ivars are both set within the databaseConnectionDidUpdate method:
		//
		// tableViewHasNewItems - a new message was added (most likely at the bottom of the tableView)
		// mostRecentDeliveredMessageChanged - a different message is being marked as read

		if (tableViewHasNewItems || mostRecentDeliveredMessageChanged)
		{
			[self scrollToBottomAnimated:YES];
			
			tableViewHasNewItems = NO;
			mostRecentDeliveredMessageChanged = NO;
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark View Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad
{
	DDLogAutoTrace();
	[super viewDidLoad];
    	
	selectedMessageID = NULL;
	isPopingBackIntoView = NO;
		
	// Setup database
	
	databaseConnection = STDatabaseManager.uiDatabaseConnection;
	[self initializeMappings];
	
	// Setup UI
	titleString = @"";
//	[self updateConversationCache];
	[self updateConversationPermissions];

    //03/26/15 - Accessibility - moved from viewDidLoad to have access to titleString
	if (AppConstants.isIPad)
	{
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@""
                                                                                 style:UIBarButtonItemStylePlain
                                                                                target:self
                                                                                action:@selector(toggleMasterView)];
        [self updateToggleMasterViewButtonAccessibility];
		[self updateBackBarButton];
	}
	
	tableView.scrollsToTop = YES;
	[tableView registerClass:STBubbleTableViewCell.class forCellReuseIdentifier: NSStringFromClass([self class])];

	[self setupTopView];
	[self setupInputView];

	tempTextView = [[STInteractiveTextView alloc] initWithFrame:CGRectZero];
	tempTextView.hidden = YES;
	tempTextView.delegate = self;
	[inputView addSubview:tempTextView];
	
	singleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
	singleTapRecognizer.numberOfTapsRequired = 1;
	singleTapRecognizer.numberOfTouchesRequired = 1;
	singleTapRecognizer.delaysTouchesEnded = NO;
    singleTapRecognizer.cancelsTouchesInView  = NO;
 	[tableView addGestureRecognizer:singleTapRecognizer];

	longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
	longPressRecognizer.minimumPressDuration = 0.25;
	[tableView addGestureRecognizer:longPressRecognizer];
	
	UINib *cellNib = [UINib nibWithNibName:@"ContactsSubViewControllerCell" bundle:nil];
	[tableView registerNib:cellNib forCellReuseIdentifier:@"ContactsSubViewControllerCell"];
	
	UINib *headerNib = [UINib nibWithNibName:@"ContactsSubViewControllerHeader" bundle:nil];
	[tableView registerNib:headerNib forHeaderFooterViewReuseIdentifier:@"ContactsSubViewControllerHeader"];

  	[self changeTheme:nil];
	
	// Register for notifications
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(databaseConnectionWillUpdate:)
												 name:UIDatabaseConnectionWillUpdateNotification
											   object:STDatabaseManager];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(databaseConnectionDidUpdate:)
												 name:UIDatabaseConnectionDidUpdateNotification
											   object:STDatabaseManager];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(scloudOperation:)
												 name:NOTIFICATION_SCLOUD_OPERATION
											   object:nil];

    //ET 02/18/15
    // NOTE: I think this never runs - at least not in the simulator.
    // When AppDelegate gets this callback, its self.messagesViewController is nil.
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(applicationWillResignActive) 
                                                 name:UIApplicationDidBecomeActiveNotification 
                                               object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(applicationDidEnterBackground)
												 name:UIApplicationDidEnterBackgroundNotification
											   object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(changeTheme:)
												 name:kAppThemeChangeNotification
											   object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(prefsChanged:)
												 name:PreferencesChangedNotification
											   object:nil];
    
    
	[self addObserverForTableViewContentSize];
}


- (void)viewWillAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillAppear:animated];

	[self updateTitleButton];
	[self updateConversationPermissions];
	[self updateBackBarButton];
	[self updateConversationSecurityButton];
	
	if (conversation.isNewMessage)
	{
		[self showTopView];
		
		if (!isPopingBackIntoView)
		{
			[self restoreRecipientsFromPreferences];
		}
		
        tokenFieldView.tokenField.editable = YES;
        
        //ET 03/30/15
        // ST-809 - new converstion cursor in To: textfield
        // The tokenField should become firstResponder for a new message.        
//        [tokenFieldView.tokenField becomeFirstResponder];
	}
	else
	{
		[self hideTopView];
		
		tokenFieldView.tokenField.editable = NO;
		[tokenFieldView.tokenField removeAllTokens];
	}
	
    [self updateConversationTracking];
   
	NSString *pendingTypedMessage = [STPreferences pendingTypedMessageForConversationId:conversationId];
	[inputView setTypedText:pendingTypedMessage];
	[self updateSendButton];
	[self updateTableViewContentInset];

	if (self.view.isKeyboardOpened) // isKeyboardOpened => DAKeyboardControl category method
	{
		if (![inputView.autoGrowTextView isFirstResponder])
			[inputView.autoGrowTextView becomeFirstResponder];
	}
	
	if (restoreOffset.valid)
	{
		[tableView setContentOffset:restoreOffset.point];
		restoreOffset.valid = NO;
	}
	else
	{
		// Do NOT execute this code here.
		// Instead, we MUST execute this method in viewDidLayoutSubviews. (see below)
		// [self scrollToBottomAnimated:NO];
	}
}

- (void)viewDidLayoutSubviews
{
	DDLogAutoTrace();
	[super viewDidLayoutSubviews];
	
	if (hasScrolledToBottomInLayout == NO)
	{
		hasScrolledToBottomInLayout = YES;
		[self scrollToBottomAnimated:NO];
	}
}

- (void)viewDidAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewDidAppear:animated];
	
	if (!topView.hidden)
	{
		[tokenFieldView.tokenField becomeFirstResponder];
	}
	
	// Check for any changes to the user (or if they changed devices)
	[self refreshRemoteUserWebInfo];
}

- (void)viewWillDisappear:(BOOL)animated
{
	DDLogAutoTrace();
	
	[self hideChatOptionsView];
	
    [[GeoTracking sharedInstance] stopTracking];
	
	[self saveRecipientsToPreferences];

	NSString *pendingTypedMessage = inputView.typedText;
	[STPreferences setPendingTypedMessage:pendingTypedMessage forConversationId:conversationId];
	
	[inputView.autoGrowTextView resignFirstResponder];
        
    if (AppConstants.isIPhone)
    {
        [self.navigationController setNavigationBarHidden:NO animated:NO];
	}

    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewDidDisappear:animated];
	
	if (audioInputView)
		[audioInputView hide];
}

//- (void)viewDidLayoutSubviews
//{
//	DDLogAutoTrace();
//	[super viewDidLayoutSubviews];
//}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - View Preferences
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * From the Apple Docs:
 *
 * Returns a Boolean indicating whether the current input view is dismissed automatically when changing controls.
 * 
 * Override this method in a subclass to allow or disallow the dismissal of the current input view
 * (usually the system keyboard) when changing from a control that wants the input view to one that does not.
 * Under normal circumstances, when the user taps a control that requires an input view, the system automatically
 * displays that view. Tapping in a control that does not want an input view subsequently causes the current input
 * view to be dismissed but may not in all cases. You can override this method in those outstanding cases to allow
 * the input view to be dismissed or use this method to prevent the view from being dismissed in other cases.
 *
 * The default implementation of this method returns YES when the modal presentation style of the view controller
 * is set to UIModalPresentationFormSheet and returns NO for other presentation styles. Thus, the system normally
 * does not allow the keyboard to be dismissed for modal forms.
**/
- (BOOL)disablesAutomaticKeyboardDismissal
{
	return NO;
}

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


- (void)prefsChanged:(NSNotification *)notification
{
	DDLogAutoTrace();
	
    NSString *prefs_key = [notification.userInfo objectForKey:PreferencesChangedKey];
	
	if ([prefs_key isEqualToString:prefs_experimentalFeatures]  ||
	    [prefs_key isEqualToString:prefs_showVerfiedMessageSigs] )
	{
        [self updateConversationPermissions];
		[self.tableView reloadData];
    }
}


- (void)changeTheme:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	NSDictionary *userInfo = notification.userInfo;
	if (userInfo)
		theme = userInfo[kNotificationUserInfoTheme];
	else
		theme = [AppTheme getThemeBySelectedKey];
	
	DDLogVerbose(@"Theme = %@", theme);

	UIColor *tintColor;
	if (theme.appTintColor)
		tintColor = theme.appTintColor;
	else
		tintColor = [STAppDelegate originalTintColor];
	
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
	
	if (titleButton == nil)
	{
		[self updateTitleButton];
	}
	else
	{
		UIColor *navBarTitleColor = theme.navBarTitleColor;
		if (navBarTitleColor == nil)
			navBarTitleColor = [UIColor blackColor];
		
		[titleButton setTitleColor:navBarTitleColor forState:UIControlStateNormal];
		[titleButton setTitleColor:navBarTitleColor forState:UIControlStateHighlighted];
	}
	
	// The following doesn't seem to work.
	// Even if it did, it doesn't take into account that control tint colors go grey when there are popups on screen.
//	securityButton.tintColor = tintColor;
//	conversationInfoButton.tintColor = tintColor;

	[securityButton setNeedsDisplay];
	[self updateConversationCache];
 
	//
	// TopView
	//
	
	if (topView)
	{
		topView.frame = (CGRect){
			.origin.x = 0,
			.origin.y = [self topViewYOffset],
			.size.width = self.view.bounds.size.width,
			.size.height = 40
		};
	}
	
	//
	// TableView
	//
	
	if (theme.scrollerColorIsWhite)
		self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
	else
		self.tableView.indicatorStyle = UIScrollViewIndicatorStyleBlack;
	
	if (notification == nil)
	{
		// Being called from within viewDidLoad: [self changeTheme:nil]
		// So no need to force the tableView to reload,
		// since it hasn't even loaded once yet.
	}
	else
	{
		[self.tableView reloadData];
	}
	
	//
	// InputView
	//
	
	if (theme.navBarIsBlack)
	{
		inputView.toolbar.barStyle = UIBarStyleBlackTranslucent;
		tempTextView.keyboardAppearance = UIKeyboardAppearanceDark;
		inputView.autoGrowTextView.keyboardAppearance = UIKeyboardAppearanceDark;
	}
	else
	{
		inputView.toolbar.barStyle = UIBarStyleDefault;
		tempTextView.keyboardAppearance = UIKeyboardAppearanceLight;
		inputView.autoGrowTextView.keyboardAppearance = UIKeyboardAppearanceLight;
	}
	
	inputView.toolbar.translucent = theme.navBarIsTranslucent;
	
	//
	// View
	//
	
	if (theme.appTintColor)
		self.view.tintColor = theme.appTintColor;
	else
		self.view.tintColor = [STAppDelegate originalTintColor];
	
	self.view.backgroundColor = theme.backgroundColor;
	
	// Do this last
	[self setNeedsStatusBarAppearanceUpdate];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Accessibility
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)toggleMasterViewButtonAccessibilityLabel {
    NSString *viewState = (_splitScreenModePrimaryHidden) ? @"Full screen" : @"Split screen";
    NSString *lclHint = nil;
    NSString *aLbl = nil;
    
    if (conversation.isNewMessage) {
        lclHint = @"(Split or Full screen state) New message - split screen layout button accessibility label"; 
        aLbl = [NSString stringWithFormat:NSLocalizedString(@"%@ New message", lclHint),
                viewState];
    }
    // system message
    else if (conversation.isFakeStream) {
        lclHint = @"(Split or Full screen state) System message - split screen layout button accessibility label";
        aLbl = [NSString stringWithFormat:NSLocalizedString(@"%@ System message", lclHint),
                viewState];
    }
    // e.g VoiceOver: "Split screen eturner Messages button"
    else {
        lclHint = @"(Split or Full screen state) {Conversation user name} Messages - split screen layout button accessibility label"; 
        aLbl = [NSString stringWithFormat:NSLocalizedString(@"%@ %@ Messages", lclHint), viewState, titleString];
    }
    
    return aLbl;
}

//03/26/15 - Accessibility
- (void)updateToggleMasterViewButtonAccessibility
{
    NSString *lbl = [self toggleMasterViewButtonAccessibilityLabel];
    _messagesArrowButton.accessibilityLabel = lbl;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Application Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)applicationDidEnterBackground
{
	DDLogAutoTrace();
	
	[chatOptionsView suspendFading: NO];
	[chatOptionsView hideBurnOptions];
	
	[inputView.autoGrowTextView resignFirstResponder];
}

//ET 02/18/15
// NOTE: I think this never runs - at least not in the simulator.
// When AppDelegate gets this callback, its self.messagesViewController is nil.
- (void)applicationWillResignActive
{
	DDLogAutoTrace();
	
	[chatOptionsView suspendFading: NO];
	[chatOptionsView hideBurnOptions];
	
	[inputView.autoGrowTextView resignFirstResponder];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Rotation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Subclasses may override this method to perform additional actions immediately prior to the rotation.
 * For example, you might use this method to disable view interactions, stop media playback, or temporarily turn off
 * expensive drawing or live updates. You might also use it to swap the current view for one that reflects the new
 * interface orientation.
 * 
 * When this method is called, the interfaceOrientation property still contains the view’s original orientation.
 * Your implementation of this method must call super at some point during its execution.
 *
 * This method is called regardless of whether your code performs one-step or two-step rotations.
**/
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
								duration:(NSTimeInterval)duration
{
	DDLogAutoTrace();
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	// The width of the tableView is going to change,
	// so flush the cellHeightCache, because all the values need to be recalculated for the new width.
	[cellHeightCache removeAllObjects];
	
	if (popoverController.popoverVisible)
	{
		[popoverController dismissPopoverAnimated:YES];
	}
}

/**
 * This method is called from within the animation block used to rotate the view. You can override this method
 * and use it to configure additional animations that should occur during the view rotation. For example, you could
 * use it to adjust the zoom level of your content, change the scroller position, or modify other animatable
 * properties of your view.
 * 
 * By the time this method is called, the interfaceOrientation property is already set to the new orientation,
 * and the bounds of the view have been changed. Thus, you can perform any additional layout required by your
 * views in this method.
**/
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                         duration:(NSTimeInterval)duration
{
	DDLogAutoTrace();
    
    [super willAnimateRotationToInterfaceOrientation:interfaceOrientation duration:duration];
        
//	CGRect topViewFrame = (CGRect){
//		.origin.x = 0,
//		.origin.y = [self topViewYOffset],
//		.size.width = self.view.bounds.size.width,
//		.size.height = 40
//	};
//	
//	topView.frame = topViewFrame;
}

- (CGFloat)topViewYOffset
{
	if (theme.navBarIsTranslucent) {
		CGSize statusBarSize = [UIApplication sharedApplication].statusBarFrame.size;
		CGFloat statusBarHeight = MIN(statusBarSize.height, statusBarSize.width);
		
		CGSize navigationBarSize = self.navigationController.navigationBar.frame.size;
		return navigationBarSize.height + statusBarHeight;
	}
	else {
		return 0;
	}
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Custom Property Setters
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setConversationId:(NSString *)inConversationId
{
	DDLogAutoTrace();
	
	if (conversationId && [conversationId isEqualToString:inConversationId])
		return;
    
	NSString *pendingTypedMessage = [inputView typedText];
	[STPreferences setPendingTypedMessage:pendingTypedMessage forConversationId:conversationId];
	
	[self hideChatOptionsView];
	
	conversationId = inConversationId;
	displayTableViewAdditions = YES;
	isPopingBackIntoView = NO;
	
	if (self.isViewLoaded)
	{
		[self initializeMappings];
		[self updateConversationCache];
		[self updateConversationPermissions];
        [self updateConversationSecurityButton];
        [self updateConversationTracking];
        //ET 03/30/15
        // Accessibility - update splitView button label
        [self updateToggleMasterViewButtonAccessibility];
        
		[tableView reloadData];
		[self scrollToBottomAnimated:NO];
		
		NSString *msg = [STPreferences pendingTypedMessageForConversationId:conversationId];
		[inputView setTypedText:msg];
		
		if (conversation.isNewMessage)
		{
			[self showTopView];
			
			tokenFieldView.tokenField.editable = YES;
			[tokenFieldView.tokenField removeAllTokens];
			[recipientDict removeAllObjects];
			
			[self restoreRecipientsFromPreferences];
            
            //ET 03/30/15
            // ST-809 - new converstion cursor in To: textfield
            // The tokenField should become firstResponder for a new message. Adding
            // the next line is for iPad; putting it in viewWillAppear/viewDidAppear
            // doesn't work because the view is already visible.
            [tokenFieldView.tokenField becomeFirstResponder];
		}
		else
		{
			[self hideTopView];
			
			tokenFieldView.tokenField.editable = NO;
			[tokenFieldView.tokenField removeAllTokens];
		}
		
		[self reloadTokenFieldAutocomplete];
		[self updateSendButton];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Master View
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateConversationTracking
{
    if (conversation.tracking /* && inputView.typedText.length > 0 */)
        [[GeoTracking sharedInstance] beginTracking];
    else
        [[GeoTracking sharedInstance] stopTracking];
}

- (void)updateConversationPermissions
{
	STLocalUser *currentUser = STDatabaseManager.currentUser;
	
	canSendMedia = currentUser.canSendMedia;
	NSDictionary *dict = [[AppConstants SilentCircleNetworkInfo] objectForKey:currentUser.networkID];
	
	canMulticast = [[dict objectForKey:@"canMulticast"] boolValue];
	
	// Group messaging is turned off unless we have experimentalFeatures
    BOOL hasExperimentalFeatures  = [STPreferences experimentalFeatures];
    canMulticast  = canMulticast ? hasExperimentalFeatures: NO;
    
#if robbie_hanson
	canMulticast = YES;
#endif
	
	showVerfiedMessageSigs = [STPreferences showVerfiedMessageSigs];
}

- (void)toggleMasterView
{
	// The width of the tableView is going to change,
	// so flush the cellHeightCache, because all the values need to be recalculated for the new width.
	[cellHeightCache removeAllObjects];
	
	UISplitViewController *splitVC = (UISplitViewController *)STAppDelegate.splitViewController;
	
	if (splitVC.preferredDisplayMode == UISplitViewControllerDisplayModeAllVisible) {
		splitVC.preferredDisplayMode = UISplitViewControllerDisplayModePrimaryHidden;
		_splitScreenModePrimaryHidden = YES;
	}
	else {
		splitVC.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
		_splitScreenModePrimaryHidden = NO;
	}
	
    //03/26/15
    [self updateToggleMasterViewButtonAccessibility];
}

- (void)setMasterButtonBackButtonCount:(NSUInteger)count
{
	if (self.navigationItem.leftBarButtonItem)
	{
		UISplitViewController *splitVC = (UISplitViewController *)STAppDelegate.splitViewController;
		
		BOOL isShowingConversations = splitVC.preferredDisplayMode == UISplitViewControllerDisplayModeAllVisible;
		
		UIImage *splitIndicator = nil;
		if (isShowingConversations)
			splitIndicator = [UIImage imageNamed:@"unsplit"];
		else
			splitIndicator = [UIImage imageNamed:@"split"];
		
		UIButton *arrowButton = [UIButton buttonWithType:UIButtonTypeSystem];
		arrowButton.frame = CGRectMake(0, 0, 44, 44);
		[arrowButton setImage:splitIndicator forState:UIControlStateNormal];
		[arrowButton addTarget:self action:@selector(toggleMasterView) forControlEvents:UIControlEventTouchUpInside];
        _messagesArrowButton = arrowButton;
		
		UIView *complexView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 88, 44)];
		[complexView addSubview:arrowButton];
		
		if (count > 0 && !isShowingConversations)
		{
			NSString *backTitle = nil;
			if (count > 999)
				backTitle = [NSString stringWithFormat:@"999+"];
			else if (count > 0)
				backTitle = [NSString stringWithFormat:@"%lu", (unsigned long)count];
			
			UILabel *unreadLabel = [[UILabel alloc] initWithFrame:CGRectMake(44 + 5, 0, 44, 44)];
			unreadLabel.font = [UIFont fontWithDescriptor:unreadLabel.font.fontDescriptor size:14];
			unreadLabel.textAlignment = NSTextAlignmentCenter;
			unreadLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
			unreadLabel.textColor = [UIColor whiteColor];
			unreadLabel.text = backTitle;
			
			[unreadLabel sizeToFit];
			
			CGRect frame = unreadLabel.frame;
			//	frame.origin.x = (44.0 - frame.size.height) / 2;
			frame.size.width += 15;
			frame.size.height += 8;
			frame.origin.y = (44.0 - frame.size.height) / 2;
			
			unreadLabel.frame = frame;
			unreadLabel.layer.borderColor = [UIColor whiteColor].CGColor;
			unreadLabel.layer.borderWidth = 2.0;
			unreadLabel.layer.cornerRadius = frame.size.height / 2;
			unreadLabel.clipsToBounds = YES;
			
			[complexView addSubview:unreadLabel];
		}
		
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:complexView];
        //03/26/15 - Accessibility
        [self updateToggleMasterViewButtonAccessibility];
	}
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UI Helpers
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// force the NavBar to reset any funny handling when we push out to other controllers.
- (void)pushViewControllerAndFixNavBar:(UIViewController *)controller animated:(BOOL)animated
{
    if (AppConstants.isIPhone)
    {
        [self.navigationController setNavigationBarHidden:NO animated:NO];
    }

    [self.navigationController pushViewController:controller animated:animated];
}

/**
 * This method invokes [STUserManager refreshWebInfoForUser::] on the conversation's remote user.
 * We use it to force-refresh user's that we're actively interacting with (in the UI).
 * 
 * The point of doing so is to keep the UI & local database up-to-date with the server (such as avatar changes),
 * and also to detect if the user has changed devices.
 * 
 * All the "hard stuff" is handled by STUserManager.
 * We just have to invoke it in response to the UI.
**/
- (void)refreshRemoteUserWebInfo
{
	DDLogAutoTrace();
	
	if (conversation.isMulticast) {
		// nothing to refresh
		return;
	}
	
	__block STUser *user = nil;
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		user = [STDatabaseManager findUserWithJID:conversation.remoteJid transaction:transaction];
	}];
	
	if (user) {
		[[STUserManager sharedInstance] refreshWebInfoForUser:user completionBlock:NULL];
	}
}

- (void)reloadTokenFieldAutocomplete
{
	DDLogAutoTrace();
	
	STUser *currentUser = STDatabaseManager.currentUser;
	NSString *currentUserDomain = [currentUser.jid domain];
	
	if (tokenFieldAutocomplete)
		[tokenFieldAutocomplete removeAllObjects];
	else
		tokenFieldAutocomplete = [[NSMutableDictionary alloc] init];
	
	[STDatabaseManager.roDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		[transaction enumerateKeysAndObjectsInCollection:kSCCollection_STUsers
		                                      usingBlock:^(NSString *key, id object, BOOL *stop)
		{
			STUser *user = (STUser *)object;
			
			if (![user.uuid isEqualToString:currentUser.uuid])
			{
				if ( ([currentUserDomain isEqualToString:[user.jid domain]]) && (user.isSavedToSilentContacts == YES) )
				{
					[tokenFieldAutocomplete setObject:user.displayName forKey:user.jid];
				}
			}
		}];
	
	} completionBlock:^{
		
		NSArray *scJids = [[AddressBookManager sharedInstance] SilentCircleJids];
		for (XMPPJID *jid in scJids)
		{
			if ([jid.domain isEqualToString:currentUserDomain] && ![tokenFieldAutocomplete objectForKey:jid])
			{
				NSDictionary *abInfo = [[AddressBookManager sharedInstance] infoForSilentCircleJID:jid];
				if (abInfo) {
					[tokenFieldAutocomplete setObject:[abInfo objectForKey:kABInfoKey_displayName] forKey:jid];
				}
			}
		}
		
		tokenFieldView.sourceArray = [tokenFieldAutocomplete allKeys];
	}];
}

- (void)setupTopView
{
	DDLogAutoTrace();
	
	CGRect topViewFrame = CGRectMake(0, [self topViewYOffset], self.view.bounds.size.width, 40);

	topView = [[UIView alloc] initWithFrame:topViewFrame];
	topView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	topView.backgroundColor = [UIColor whiteColor];
//	topView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.75];
	
	CGRect tokenViewFrame = topView.bounds;
#if USE_SC_DIRECTORY_SEARCH
	// Todo: fix this! 20 is for status bar, 1 for horizontal line
	tokenViewFrame.size.height = inputView.frame.origin.y-topViewFrame.origin.y-self.navigationController.navigationBar.frame.size.height-20-1;
#endif
	tokenFieldView = [[TITokenFieldView alloc] initWithFrame:tokenViewFrame]; //topView.bounds];
	tokenFieldView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	
	[self reloadTokenFieldAutocomplete];
	tokenFieldView.tokenField.returnKeyType = UIReturnKeyDone;
	[tokenFieldView.tokenField setDelegate:self];
	[tokenFieldView.tokenField addTarget:self
								  action:@selector(tokenFieldFrameDidChange:)
						forControlEvents:(UIControlEvents)TITokenFieldControlEventFrameDidChange];
	
	NSCharacterSet *tokenizers = [NSCharacterSet characterSetWithCharactersInString:@",;."];
	[tokenFieldView.tokenField setTokenizingCharacters:tokenizers]; // Default is a comma
	
	NSString *prompt = NSLocalizedString(@"To:", @"Prompt in token field");
	NSString *placeholder = NSLocalizedString(@"Type a contact name", @"Placeholder in token field");
	
	[tokenFieldView.tokenField setPromptText:prompt];
	[tokenFieldView.tokenField setPlaceholder:placeholder];
	
    //ET 03/30/15 - Accessibility
    // ST-486 - give "To:" textfield voiceOver context
    NSString *aLbl = NSLocalizedString(@"Recipient contact", 
                                       @"Recipient contact - {To: contact input textfield} accessiblity label");
    tokenFieldView.tokenField.accessibilityLabel = aLbl;
    
	UIButton *addButton = [UIButton buttonWithType:UIButtonTypeContactAdd];
	[addButton addTarget:self action:@selector(showContactsPicker:) forControlEvents:UIControlEventTouchUpInside];

    //ET 03/30/15 - Accessibility
    // Related to ST-486 - give "To:" textfield voiceOver context
    // Add accessibility context to "Add" button
    NSString *addLbl = NSLocalizedString(@"Contacts list", 
                                         @"Contacts list - {To: contacts Add button} accessiblity label");
    addButton.accessibilityLabel = addLbl;

    
	[tokenFieldView.tokenField setRightView:addButton];
	[tokenFieldView.tokenField addTarget:self
								  action:@selector(tokenFieldChangedEditing:)
						forControlEvents:(UIControlEventEditingDidBegin | UIControlEventEditingDidEnd)];

	[topView addSubview:tokenFieldView];
	[self.view addSubview:topView];
	topView.hidden = YES;
}

- (void)showTopView
{
	DDLogAutoTrace();
	
	if (topView.hidden)
	{
		topView.hidden = NO;
		
		UIEdgeInsets insets = tableView.contentInset;
		insets.top += topView.frame.size.height;
		
		tableView.contentInset = insets;
		tableView.scrollIndicatorInsets = insets;
	}
}

- (void)hideTopView
{
	DDLogAutoTrace();
	
	if (!topView.hidden)
	{
		if ([tokenFieldView.tokenField isFirstResponder])
		{
			[tokenFieldView.tokenField resignFirstResponder];
			[inputView.autoGrowTextView becomeFirstResponder];
		}
		
		topView.hidden = YES;
		
		UIEdgeInsets insets = tableView.contentInset;
		insets.top -= topView.frame.size.height;
		
		tableView.contentInset = insets;
		tableView.scrollIndicatorInsets = insets;
	}
}

- (void)setupInputView
{
	DDLogAutoTrace();
	
	// This seems to be required for iOS 7. (ST-767)
	self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeNone;
	
	__weak MessagesViewController *weakSelf = self;
	[self.view addKeyboardPanningWithFrameBasedActionHandler:NULL
	                            constraintBasedActionHandler:^(CGRect keyboardFrameInView, BOOL opening, BOOL closing)
	{
	#pragma clang diagnostic push
	#pragma clang diagnostic warning "-Wimplicit-retain-self"
		
		__strong MessagesViewController *strongSelf = weakSelf;
		if (strongSelf == nil) return;
		
		
		CGFloat offsetFromBottom = strongSelf.view.frame.size.height - keyboardFrameInView.origin.y;
		offsetFromBottom = MAX(0.0F, offsetFromBottom);
		
		strongSelf.inputViewBottomConstraint.constant = offsetFromBottom;
		
		__unsafe_unretained UITableView *tblView = strongSelf.tableView;
		
		UIEdgeInsets tblViewInsets = tblView.contentInset;
		tblViewInsets.bottom = offsetFromBottom + strongSelf.inputView.frame.size.height;
		tblView.contentInset = tblViewInsets;
		tblView.scrollIndicatorInsets = tblViewInsets;
		
		if (opening)
		{
			CGFloat contentHeight = tblView.contentSize.height;
			CGFloat contentOffsetY = tblView.contentOffset.y;
			CGFloat tableFrameHeight = tblView.frame.size.height;
			
			BOOL isScrolledToBottom = (contentOffsetY + tableFrameHeight) >= contentHeight;
			if (isScrolledToBottom && !strongSelf->skipScrollToBottom)
			{
				[strongSelf scrollToBottomAnimated:YES];
			}
		}
		
	#pragma clang diagnostic pop
	}];
}

- (void)updateTitleButton
{
    if (nil == conversationId) {
        titleButton = nil;
        self.navigationItem.titleView = nil;
        return;
    }
	
	// Note: If you want to change the button type to UIButtonTypeSystem,
	// then make sure the button doesn't disapper on UIControlEventTouchDown (with a black navBar).
	
	titleButton = [UIButton buttonWithType:UIButtonTypeCustom]; // see note above
	titleButton.adjustsImageWhenHighlighted = NO;
	titleButton.titleLabel.font = [[UIFont preferredFontForTextStyle:UIFontTextStyleCaption2] fontWithSize:20];
	
	[titleButton addTarget:self action:@selector(titleTap:) forControlEvents:UIControlEventTouchUpInside];
	
	UIColor *navBarTitleColor = theme.navBarTitleColor;
	if (navBarTitleColor == nil)
		navBarTitleColor = [UIColor blackColor];
	
	[titleButton setTitleColor:navBarTitleColor forState:UIControlStateNormal];
	[titleButton setTitleColor:navBarTitleColor forState:UIControlStateHighlighted];
	
	[titleButton setTitle:titleString forState:UIControlStateNormal];
	[titleButton sizeToFit];
    
	self.navigationItem.titleView = titleButton;
    
    //ET 03/27/15 - Accessibility: add "messages" 
    // to accessiblity title description, e.g. "eturner messages"
    NSString *aLbl = [NSString stringWithFormat:NSLocalizedString(@"%@ messages", 
                                                                 @"{Conversation user name} messages"), 
                     titleString];
    titleButton.accessibilityLabel = aLbl;
     
}

- (void)updateBackBarButton
{
	NSString *currentUserId = STDatabaseManager.currentUser.uuid;
	
	__block NSUInteger unreadCount = 0;
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		// Enumerate over all the conversationIds for the user
		[transaction enumerateKeysInCollection:currentUserId usingBlock:^(NSString *aConversationId, BOOL *stop) {
			
			// Exclude unread count for current conversation
			if (![aConversationId isEqualToString:conversationId])
			{
				unreadCount += [[transaction ext:Ext_View_Unread] numberOfItemsInGroup:aConversationId];
			}
		}];
	}];
	
    //ET 03/27/15 
    // Note: "back" button on iPad is the conversation/messages split screen toggle button.
    // The accessibility label for this button is updated in setMasterButtonBackButtonCount.
	if (AppConstants.isIPhone)
	{
		[[STAppDelegate conversationViewController] setMessageViewBackButtonCount:unreadCount];
	}
	else
	{
		[self setMasterButtonBackButtonCount:unreadCount];
	}
}

/**
 * This method invokes [inputView enableSendButtonIfHasText:].
 * Before doing so it runs through the normal checks (fake conversation, hasValidRecipient(s), etc).
**/
- (void)updateSendButton
{
	BOOL canEnableSendButton = NO;
    
    STLocalUser *currentUser = STDatabaseManager.currentUser;
	if (currentUser.isEnabled && conversation)
	{
		if (conversation.isFakeStream)
		{
			canEnableSendButton = NO;
		}
		else if (conversation.isNewMessage)
		{
			canEnableSendButton = (recipientDict.count > 0) && [self checkRecipients];
		}
		else
		{
			canEnableSendButton = YES;
		}
	}
	
	[inputView enableSendButtonIfHasText:canEnableSendButton];
}

- (void)updateConversationCache
{
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		// Note: We used to cache a bunch of individual values from the conversation.
		//       Now we just grab the conversation object itself.
		//       The other cached values are things that require a bit of processing.
		
//		STConversation *startConvo = conversation;
		conversation = [transaction objectForKey:conversationId inCollection:STDatabaseManager.currentUser.uuid];
        
		localJID  = conversation.localJid;
		remoteJID = conversation.remoteJid;
		
//		DDLogGreen(@"%s\nRESET conversation ivar:\n  FROM conversation.uuid: %@ TO uuid:%@ \n  FROM localJID: %@  remoteJID: %@\n  TO localJID: %@  remoteJID %@",
//		           __PRETTY_FUNCTION__, startConvo.uuid, conversation.uuid,
//		           startConvo.localJid, startConvo.remoteJid, localJID, remoteJID);
                   
		conversationUserIds = nil;
		userInfoDict = nil;
		
		if (conversation == nil)
		{
			titleString = @"";
			return; // from block
		}
		
		if (localJID == nil)
		{
			DDLogWarn(@"Why does this conversation have no localJID ?");
			
			localJID = STDatabaseManager.currentUser.jid;
		}
		
		if (conversation.isNewMessage)
		{
			titleString = NSLocalizedString(@"New Message", @"Title");
			return; // from block
		}
        
        if (conversation.isFakeStream)
        {
			// FIXME: add some code here to disable or remove the imput view for fakeStreams.
        }
        
		
		NSMutableSet *userIds = [NSMutableSet set];
		NSMutableDictionary *newUserInfoDict = [NSMutableDictionary dictionary];
		
		//
		// STEP 1 : Process remote user(s)
		//
		
		if (conversation.multicastJidSet.count > 0)
		{
            NSMutableArray *multicastUsers = [NSMutableArray arrayWithCapacity:[conversation.multicastJidSet count]];
            
			NSUInteger blendColorOffset = 0;
			for (XMPPJID *jid in conversation.multicastJidSet)
			{
				NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:5];
				NSString *displayName = nil;
				
				STUser *user = [STDatabaseManager findUserWithJID:jid transaction:transaction];
				
				if (user)
				{
					displayName = user.displayName;
					userInfo[@"userId"] = user.uuid;
					
					[userIds addObject:user.uuid];
                    [multicastUsers addObject:user];
				}
				else  // no user in DB, try AB
				{
					NSDictionary *abInfo = [[AddressBookManager sharedInstance] infoForSilentCircleJID:jid];
					if (abInfo)
					{
						displayName = [abInfo objectForKey:kABInfoKey_displayName];
						userInfo[@"abRecordID"] = [abInfo objectForKey:kABInfoKey_abRecordID];
					}
					else
					{
						userInfo[@"abRecordID"] = @(kABRecordInvalidID);
					}
                    
                  // if the mc user is not in our database, create a pseduo one, and check for AB entry
                    
                    user = [[STUser alloc] initWithUUID:nil // Yes, nil because this is a temp user (user.isTempUser)
                                              networkID:STDatabaseManager.currentUser.networkID
                                                    jid:jid];
                    
                    user.sc_compositeName = displayName;
                    [multicastUsers addObject:user];
  				}
				
				if (displayName == nil)
					displayName = jid.user;
				
				if (displayName == nil)
					displayName = @"";
				
				userInfo[@"displayName"] = displayName;
				
				// Override regular bubble color,
				// in order to differentiate between the multiple users.
				
				userInfo[@"bubbleColor"] = [theme.otherBubbleColor blendColor:blendColorOffset
				                                                     forCount:conversation.multicastJidSet.count];
				blendColorOffset++;
                
				[newUserInfoDict setObject:userInfo forKey:jid.bare];
			}
			
           
            // set title to match what conversation view does
			
			NSString *threadTitle =
			  [conversation.title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			
            if ([threadTitle length] > 0)
            {
                titleString = conversation.title;
            }
            else
			{
                NSDictionary* titleAttributes = self.navigationController.navigationBar.titleTextAttributes;
                
                titleString = [STUser displayNameForUsers: multicastUsers
                                              maxWidth:self.navigationItem.titleView.frame.size.width
                                        textAttributes:titleAttributes];
            }
            
        }
		else if (remoteJID)
		{
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:5];
			NSString *displayName = nil;
			
            // check if the remote jid is actually an internal message for Silent Text
			if (IsSTInfoJID(remoteJID))
            {
                displayName = AppConstants.STInfoDisplayName;
                userInfo[@"abRecordID"] = @(kABRecordInvalidID);
                userInfo[@"isSilentTextInfoUser"]  = @(YES);
                
            }
            // is it OCA voicemail
			else if (IsOCAVoicemailJID(remoteJID))
            {
                displayName = AppConstants.OCAVoicemailDisplayName;
                userInfo[@"abRecordID"] = @(kABRecordInvalidID);
                userInfo[@"isOCAUser"]  = @(YES);
			}
			else
			{
                STUser *user = [STDatabaseManager findUserWithJID:remoteJID transaction:transaction];
                if (user)
                {
                    displayName = user.displayName;
                    userInfo[@"userId"] = user.uuid;
                    
                    [userIds addObject:user.uuid];
                }
                else  // no user in DB, try AB
                {
					NSDictionary *abInfo = [[AddressBookManager sharedInstance] infoForSilentCircleJID:remoteJID];
                    if(abInfo)
                    {
                        displayName = [abInfo objectForKey:kABInfoKey_displayName];
                        userInfo[@"abRecordID"] = [abInfo objectForKey:kABInfoKey_abRecordID];
                    }
                    else
                    {
                        userInfo[@"abRecordID"] = @(kABRecordInvalidID);
                    }
                }
                
  
            }
			if (displayName == nil)
				displayName = remoteJID.user;
			
			if (displayName == nil)
				displayName = @"";
			
			userInfo[@"displayName"] = displayName;
                
 			[newUserInfoDict setObject:userInfo forKey:remoteJID.bare];
			
			titleString = displayName;
		}
		else
		{
			DDLogError(@"No remote user for this conversation" );
			return;
		}
		
		//
		// STEP 2: Process local user
		//
		
		{
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:4];
			NSString *displayName = nil;
			
			STUser *user = [STDatabaseManager findUserWithJID:localJID transaction:transaction];
			if (user)
			{
				displayName = user.displayName;
				userInfo[@"userId"] = user.uuid;
				
				[userIds addObject:user.uuid];
			}
			
			if (displayName == nil)
				displayName = localJID.user;
			
			if (displayName == nil)
				displayName = @"";
			
			userInfo[@"displayName"] = displayName;
            
			[newUserInfoDict setObject:userInfo forKey:localJID.bare];
		}
		
		conversationUserIds = [userIds copy];
		userInfoDict = [newUserInfoDict copy];
	}];
	
    [self updateTitleButton];
}

// handle all the wierd backward compatible cases in which to use a built in thumbnail
// and sometime ignore supplied one.



- (void)showViewController:(UIViewController *)controller
                  fromRect:(CGRect)inRect
                    inView:(UIView *)inView
                forMessage:(STMessage *)message
               hidesNavBar:(BOOL)hideNavBar
           arrowDirections:(UIPopoverArrowDirection)arrowDirections
{
    
    [inputView.autoGrowTextView resignFirstResponder];
    
	if (AppConstants.isIPhone)
	{
		self.navigationItem.backBarButtonItem =
		  [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Back", @"Back")
		                                   style:UIBarButtonItemStylePlain
		                                  target:nil
		                                  action:nil];

        if ([controller respondsToSelector:@selector(presentingController)])
            [controller setValue:self forKey:@"presentingController"];

		[self pushViewControllerAndFixNavBar:controller animated:YES];
	}
	else // iPad
	{
		UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:controller];
		navController.navigationBarHidden = hideNavBar;
		
		if ([AppConstants isIOS8OrLater])
		{
			navController.modalPresentationStyle = UIModalPresentationPopover;
			
			UIPopoverPresentationController *ppc = navController.popoverPresentationController;
			ppc.permittedArrowDirections = arrowDirections;
			ppc.sourceView = inView;
			ppc.sourceRect = inRect;
            
            if ([controller respondsToSelector:@selector(presentingController)])
                [controller setValue:navController forKey:@"presentingController"];
			
			[self.view.window.rootViewController presentViewController:navController animated:YES completion:nil];
		}
		else // iOS 7
		{
			if (popoverController.popoverVisible) {
				[popoverController dismissPopoverAnimated:YES];
			}
			
			popoverController = [[UIPopoverController alloc] initWithContentViewController:navController];
			popoverController.delegate = self;

			// ET 09/01/14
			if ([controller respondsToSelector:@selector(presentingController)])
				[controller setValue:popoverController forKey:@"presentingController"];

			if ([controller respondsToSelector:@selector(preferredPopoverContentSize)])
				popoverContentSize = [(id)controller preferredPopoverContentSize];
			else
				popoverContentSize = controller.view.frame.size;

			if (!hideNavBar)
				popoverContentSize.height += navController.navigationBar.frame.size.height;

			popoverController.popoverContentSize = popoverContentSize;
			popoverController.delegate = self;

			[popoverController presentPopoverFromRect:inRect
											   inView:inView
							 permittedArrowDirections:arrowDirections
											 animated:YES];
//              popoverContentViewController = navController;
            

		}
        popoverFromRect = inRect;
        popoverInView = inView;
        popoverMessageId = message.uuid;
        popoverArrowDirections = arrowDirections;
        temporarilyHidingPopover = NO;

	
	} // end else iPad
}

-(void) dismissPopoverIfNeededAnimated:(BOOL)animated
{
    if([AppConstants isIPad ])
    {
        if ([AppConstants isIOS8OrLater])
        {
            [self.view.window.rootViewController  dismissViewControllerAnimated:animated completion: NULL];
        }
        else
        {
            if (popoverController)
            {
                temporarilyHidingPopover = NO;
                [popoverController dismissPopoverAnimated:animated];
            }
            
        }
    }
}

-(void) popupString: (NSString*)messageString
		  withColor:(UIColor*)withColor
			 atCell:(STBubbleTableViewCell *) cell
{
	UIFont* font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
	
    
    CGSize size = CGSizeMake(tableView.frame.size.width - 20, 9999);
    CGRect box = [messageString
                       boundingRectWithSize:size
                       options:NSStringDrawingUsesLineFragmentOrigin
                       attributes:@{NSFontAttributeName:font}
                       context:nil];
    
    
//	CGSize box = [messageString sizeWithAttributes:@{ NSFontAttributeName : font }];
	UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, box.size.width + 20, box.size.height + 10)];
	
	label.text = messageString;
	label.textColor = [UIColor whiteColor];
	label.textAlignment = NSTextAlignmentCenter;
	label.font = font;
	label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
	label.adjustsFontSizeToFitWidth = YES;
	label.layer.cornerRadius = 5.0;
	label.backgroundColor =   withColor;
	CGRect frame = label.bounds,
	bubbleFrame = cell.contentView.bounds;
	
	label.frame = CGRectMake((bubbleFrame.size.width - frame.size.width)/2, (bubbleFrame.size.height - frame.size.height)/2, frame.size.width, frame.size.height);
	[cell.contentView addSubview:label];
	
	[UIView animateWithDuration:0.25f
					 animations:^{
						 [label setAlpha:1.0];
					 }
					 completion:^(BOOL finished) {
						 [UIView animateWithDuration:0.5f
											   delay:1.5
											 options:0
										  animations:^{
											  [label setAlpha:0.0];
											  
										  }
										  completion:^(BOOL finished) {
											  [label removeFromSuperview];
										  }];
					 }];
}

- (NSString *)statusMessageLine:(NSDictionary *)statusMessage
{
    NSString* statusString = @"Error";
    
    if([statusMessage objectForKey:@"keyState"])
    {
        SCimpState scimpState = (SCimpState)[[statusMessage objectForKey:@"keyState"] intValue];
        
        
        switch (scimpState) {
            case kSCimpState_Commit:
                statusString = NSLocalizedString( @"Establishing Keys",  @"Establishing Keys");
                break;
                
            case kSCimpState_DH1:
                statusString = NSLocalizedString( @"Requesting Keying",  @"Requesting Keying");
                 break;
                
            case kSCimpState_DH2:
                statusString = NSLocalizedString( @"Keys Established",  @"Keys Established");
                 break;
                
            default:
                break;
        }
    }
    else if([statusMessage objectForKey:@"keyInfo"])
    {
        NSDictionary* keyInfo = [statusMessage objectForKey:@"keyInfo"];
        NSString *SAS = [keyInfo objectForKey:kSCimpInfoSAS];
        SCimpMethod scimpMethod = [[keyInfo objectForKey:kSCimpInfoMethod] unsignedIntValue];
        
        NSString* scimpMethodString = @"";
        
        if (scimpMethod == kSCimpMethod_DH)
            scimpMethodString = @"SCimp";
        else if (scimpMethod == kSCimpMethod_DHv2)
            scimpMethodString = @"SCimp2";
        else if(scimpMethod == kSCimpMethod_PubKey)
            scimpMethodString = NSLocalizedString( @"Public Key",  @"Public Key");
        else if(scimpMethod == kSCimpMethod_Symmetric)
            scimpMethodString = NSLocalizedString( @"Group Keys",  @"Group Keys");
        
        statusString = [NSString stringWithFormat:@"%@\n\"%@\"",
                        NSLocalizedString(@"Keying Complete",  @"Keying Complete"), SAS];
    }
    
    
    return statusString;
}


- (void) previewSCloudObject:(SCloudObject*)scloud
{
	
	/*
	 Quest oculus non vide, cor non delet
	 -- from the opening lines of the Apollo guidance computer sources.
	 
	 We pass around the scloud object from the message view controller to the vCardViewController,
	 this method is called when the user hits preview on the vCardViewController, if we are
	 on an iPad and that vCard view is displayed in a popup, we should remove the popup before
	 we ask the SCloudPreviewer to display it.  well this has the side effect of deallocing the
	 scloud object which deletes the decrypted vrsion in the media cache.  -- there is a possible
	 race condition that can occur, in the SCloudPreviewer will try and create a new decrypted file,
	 but its possible that the vCardViewController dealloc can be delayed to run after and thus
	 delete the cached file we are displaying..  soooo we save the scloud object in a static var
	 that we delete when the displaySCloud is done.
	 
	 if that wasnt bad enough, we need to remember to pop the view controller when we are done
	 if we are on an iPhone..
	 
	 so much webbing..
	 
	 */
	static SCloudObject* savedScloud;
	
	savedScloud = scloud;
	
	if(AppConstants.isIPad)
	{
        [self dismissPopoverIfNeededAnimated: YES];
	}
	
    //ET 02/10/15
	if (scloudPreviewer == nil)
	{
//		SCloudPreviewer *scloudPreviewer = [[SCloudPreviewer alloc] init];
        scloudPreviewer = [[SCloudPreviewer alloc] init];
	}

    //ET 02/10/15
//	UIViewController * controller = (AppConstants.isIPad)
//    ? STAppDelegate.revealController.frontViewController
//    : STAppDelegate.mainViewController;
    UIViewController *presentingVC = [self previewerPresentingController];
	
	[scloudPreviewer displaySCloud:savedScloud.locatorString
	                          fyeo:savedScloud.fyeo
	                     fromGroup:NULL
	                withController:presentingVC
	                        inView:self.view
	               completionBlock:^(NSError *error)
     {
         
         savedScloud = NULL;
         
         if (AppConstants.isIPhone) {
             [self.navigationController popViewControllerAnimated:YES];
         }
     }];
}



// this is used to put up a file sharing panel, typically for an audio file.

- (void)shareSCloudObject:(SCloudObject*)scloud
                 fromRect:(CGRect)inRect
                   inView:(UIView *)inView
                  exclude:(NSArray *)exclude
{
    if(scloud)
    {
        __block STSCloud *scl = nil;
        [databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
            
            scl = [transaction objectForKey:scloud.locatorString inCollection:kSCCollection_STSCloud];
        }];
        
        if(scl)
        {
            NSError *decryptError = NULL;
            
            [scloud decryptCachedFileUsingKeyString: scl.keyString withError:&decryptError];
            
            if(!decryptError)
            {
                NSArray *objectsToShare = @[scloud.decryptedFileURL];
                
				UIActivityViewController *uiac =
				  [[UIActivityViewController alloc] initWithActivityItems:objectsToShare applicationActivities:nil];
                
                uiac.excludedActivityTypes = exclude;
				
				uiac.completionWithItemsHandler =
				    ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError)
				{
					[scloud removeDecryptedFile];
				};
                
                if (AppConstants.isIPhone)
                {
                    [self presentViewController:uiac animated:YES completion:nil];
                }
                else
                {
                    
                    if ([AppConstants isIOS8OrLater])
                    {
                        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:uiac];
                        navController.navigationBarHidden = YES;
                        
                        navController.modalPresentationStyle = UIModalPresentationPopover;
                        
                        UIPopoverPresentationController *ppc = navController.popoverPresentationController;
                        ppc.permittedArrowDirections = popoverArrowDirections;
                        ppc.sourceView = inView;
                        ppc.sourceRect = popoverFromRect;
                        
                        [self.view.window.rootViewController presentViewController:navController animated:YES completion:nil];
                    }
                    else // iOS 7
                    {
                    popoverController = [[UIPopoverController alloc]
                                         initWithContentViewController:uiac];
                    popoverController.delegate = self;
                    
                    
                 	[popoverController presentPopoverFromRect:popoverFromRect
                                                       inView:inView
                                     permittedArrowDirections:popoverArrowDirections
                                                     animated:YES];
                    
                    temporarilyHidingPopover = NO;
                    }
                }
            }
        }
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark SCloud Object Display
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)scloudObject:(SCloudObject *)sender decryptingDidStart:(BOOL) foo
{
	if ([sender.userValue isKindOfClass:[MBProgressHUD class]])
	{
		MBProgressHUD *progressHUD = (MBProgressHUD *)sender.userValue;
		progressHUD.mode = MBProgressHUDModeAnnularDeterminate;
		progressHUD.labelText = NSLocalizedString(@"Decrypt", @"Decrypt");
		
		[progressHUD show:YES];
	}
}

- (void)scloudObject:(SCloudObject *)sender decryptingProgress:(float) progress
{
	if ([sender.userValue isKindOfClass:[MBProgressHUD class]])
	{
		MBProgressHUD *progressHUD = (MBProgressHUD *)sender.userValue;
		progressHUD.progress = progress;
		
		[progressHUD show:YES];
	}
}

- (void)scloudObject:(SCloudObject *)sender decryptingDidCompleteWithError:(NSError *)error
{
	if ([sender.userValue isKindOfClass:[MBProgressHUD class]])
	{
		MBProgressHUD* progressHUD = (MBProgressHUD *)sender.userValue;
		
		[progressHUD hide:YES afterDelay:1.0];
	}
}

- (void)showvCardViewerForSCloud:(SCloudObject *)scloud fromRect:(CGRect)inRect inView:(UIView *)inView
{
	vCardViewController *vcc = [[vCardViewController alloc] initWithSCloud:scloud];
	vcc.delegate = self;
    
	[self showViewController:vcc
	                fromRect:inRect
	                  inView:inView
	              forMessage:nil
	             hidesNavBar:NO
	         arrowDirections:UIPopoverArrowDirectionAny];
}

- (void)showvCalendarViewerForSCloud:(SCloudObject *)scloud fromRect:(CGRect)inRect inView:(UIView *)inView
{
	vCalendarViewController *vcc = [[vCalendarViewController alloc] initWithSCloud:scloud];
	vcc.delegate = self;
	
	[self showViewController:vcc
	                fromRect:inRect
	                  inView:inView
	              forMessage:nil
	             hidesNavBar:NO
	         arrowDirections:UIPopoverArrowDirectionAny];
}


- (void)decryptAndDisplaySCloud:(SCloudObject *)scloud
							scl:(STSCloud *)scl
                     forMessage:(STMessage *)message
					   fromRect:(CGRect)inRect
						 inView:(UIView *)inView
{
	
	
    // Special case for the audioPlaybackView:
	// Since it can persist, we need to allocate it before we decrypt the scloud,
	// because allocating it can cause the previous scloud object to dealloc
	// which also cause it to delete the scloud file.  Soo.. we allocate it here, and then decrypt.
    
//	if (UTTypeConformsTo((__bridge CFStringRef)scl.mediaType, kUTTypeAudio))
//	{
//		if (!audioPlaybackView)
//		{
//			audioPlaybackView = [[AudioPlaybackView alloc] init];
//			audioPlaybackView.delegate = self;
//		}
//	}

	NSError *decryptError = NULL;
	[scloud decryptCachedFileUsingKeyString: scl.keyString withError:&decryptError];
	
	if (decryptError)
	{
		[YRDropdownView showDropdownInView:inView
									 title:NSLocalizedString(@"Unable to decrypt", @"Unable to decrypt")
									detail:decryptError.localizedDescription
									 image: NULL //[UIImage imageNamed:@"ignored"]
						   backgroundImage:[UIImage imageNamed:@"bg-yellow"]
								  animated:YES
								 hideAfter:3];
		
		return;
		
	}
	
	if (UTTypeConformsTo((__bridge CFStringRef)scl.mediaType, kUTTypeVCard))
	{
		[self saveTableRestoreOffset];
		[self showvCardViewerForSCloud:scloud fromRect:inRect inView:inView];
	}
	else if (UTTypeConformsTo((__bridge CFStringRef)scl.mediaType, CFSTR("public.calendar-event")))
	{
		[self saveTableRestoreOffset];
		[self showvCalendarViewerForSCloud:scloud fromRect:inRect inView:inView];
	}
	else if (UTTypeConformsTo((__bridge CFStringRef)scl.mediaType, kUTTypeAudio))
	{
		[self markMessageAsRead:message];
		[self showAudioPlaybackViewForSCloud:scloud fromRect:inRect inView:inView];
	}
	else
	{
		NSString *frmt = NSLocalizedString(@"Unable to display items of type %@", nil);
		NSString *title = [NSString stringWithFormat:frmt, scl.mediaType];
		
		[YRDropdownView showDropdownInView:inView
		                             title:title
		                            detail:decryptError.localizedDescription
		                             image:NULL //[UIImage imageNamed:@"ignored"]
		                   backgroundImage:[UIImage imageNamed:@"bg-yellow"]
		                          animated:YES
		                         hideAfter:3.0];
	}
}

- (void)showSCloudForMessage:(STMessage *)message forCell:(STBubbleTableViewCell *)cell
{
	
	__block  STSCloud *scl =  [self scloudForMessage:message];
	__block SCloudObject* scloud = [[SCloudObject alloc]  initWithLocatorString:scl.uuid
																	  keyString:scl.keyString
                                                                           fyeo:scl.fyeo];
	if(scl && scloud)
	{
		scloud.scloudDelegate   = self;
		
		// dont do dectypt animation for small items
		if(scl.segments.count > 4)
		{
			scloud.userValue  = [cell progressHudForConversationId:conversationId messageId:message.uuid] ;
		}
		
		// do mwe need to download any items?
		if(scl.missingSegments.count > 0)
		{
			YapCollectionKey *identifier =  [[YapCollectionKey alloc] initWithCollection:conversationId key:message.uuid];
			
			__weak id weakSelf = self;
			[[SCloudManager sharedInstance] startDownloadWithScloud:scloud
			                                           fullDownload:YES
			                                             identifier:identifier
			                                        completionBlock:^(NSError *error, NSDictionary *infoDict)
			{
				__strong id strongSelf = weakSelf;
				if (strongSelf == nil) {
					return; // from block
				}
				
				if (error)
				{
					NSString *title = NSLocalizedString(@"Unable to display",
					                                    @"Error message - failed to download scloud");
					
					[YRDropdownView showDropdownInView:cell.contentView
					                             title:title
					                            detail:error.localizedDescription
					                             image:nil // [UIImage imageNamed:@"ignored"]
					                   backgroundImage:[UIImage imageNamed:@"bg-yellow"]
					                          animated:YES
					                         hideAfter:3.0];
				}
				else
				{
					[strongSelf decryptAndDisplaySCloud:scloud
					                                scl:scl
                                             forMessage:message
					                           fromRect:cell.bubbleView.frame
					                             inView:cell.contentView];
				}
			}];
		}
		else
		{
			[self decryptAndDisplaySCloud:scloud
									  scl:scl
                               forMessage:message
								 fromRect:cell.bubbleView.frame
								   inView:cell.contentView];
		}
		
	}
	else
	{
		
		[YRDropdownView showDropdownInView:cell.contentView
									 title:NSLocalizedString(@"Unable to display", @"Unable to display")
									detail:NSLocalizedString(@"Scloud object not available", @"Scloud object not available")
									 image: NULL //[UIImage imageNamed:@"ignored"]
						   backgroundImage:[UIImage imageNamed:@"bg-yellow"]
								  animated:YES
								 hideAfter:3];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark AudioPlaybackView
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)showAudioPlaybackViewForSCloud:(SCloudObject *)scloud fromRect:(CGRect)inRect inView:(UIView *)inView
{
	DDLogAutoTrace();
	
	if (audioPlaybackView == nil)
	{
		audioPlaybackView = [[AudioPlaybackView alloc] init];
		audioPlaybackView.delegate = self;
	}
	
	[audioPlaybackView playScloud:scloud fromRect:inRect inView:inView];
	
	// then do what it takes to put it on the screen
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(cleanupAudioPlaybackView) object:nil];
	
	if (AppConstants.isIPhone)
	{
		if (audioPlaybackView.superview && (audioPlaybackView.superview != inView))
		{
			[audioPlaybackView removeFromSuperview];
		}
		
		CGRect frame = audioPlaybackView.frame;
 		frame.origin.y = inView.frame.size.height - frame.size.height - 6;
 		frame.origin.x = (inRect.origin.x > 50) ? 0 : inView.frame.size.width - frame.size.width;
		audioPlaybackView.frame = frame;
		
		if (audioPlaybackView.superview == nil) {
			audioPlaybackView.alpha = 0.0;
            
			[inView addSubview:audioPlaybackView];
            
			[UIView animateWithDuration:0.25 animations:^{
				audioPlaybackView.alpha = 1.0;
			}];
		}
	}
	else
	{
		UIViewController *avc = [[UIViewController alloc] init];
		avc.view = audioPlaybackView;
        avc.preferredContentSize = audioPlaybackView.frame.size;
		
		[self showViewController:avc
		                fromRect:inRect
		                  inView:inView
		              forMessage:nil
		             hidesNavBar:YES
		         arrowDirections:UIPopoverArrowDirectionAny];
	}
	
	[audioPlaybackView play];
}

/**
 * Invoked after a short delay (a few seconds) AFTER the audioPlaybackView has finished playing the audio.
**/
- (void)cleanupAudioPlaybackView
{
	DDLogAutoTrace();
	
	if (audioPlaybackView.isPlaying) {
		return;
	}

	if (AppConstants.isIPhone)
	{
		AudioPlaybackView *apv = audioPlaybackView;
		audioPlaybackView = nil;
		
		[UIView animateWithDuration:0.25 animations:^{
			apv.alpha = 0;
		} completion:^(BOOL finished) {
			[apv removeFromSuperview];
		}];
	}
	else // iPad
	{
		[self dismissPopoverIfNeededAnimated:YES];
		audioPlaybackView = nil;
	}
}

/**
 * AudioPlaybackViewDelegate
**/
- (void)audioPlaybackView:(AudioPlaybackView *)sender needsHidePopoverAnimated:(BOOL)animated
{
    if (AppConstants.isIPhone)
    {
        [audioPlaybackView removeFromSuperview];
    }
    
    audioPlaybackView = nil;
    [self dismissPopoverIfNeededAnimated:YES];
}

/**
 * AudioPlaybackViewDelegate
**/
- (void)audioPlaybackView:(AudioPlaybackView *)sender
			   shareAudio:(SCloudObject *)scloud
				 fromRect:(CGRect)inRect
				   inView:(UIView *)inView

{
	if (AppConstants.isIPhone)
	{
		[audioPlaybackView removeFromSuperview];
	}
	
	audioPlaybackView = nil;
  
    // Exclude all activities except AirDrop.

	NSArray *exclude = @[
	  UIActivityTypePostToTwitter,
	  UIActivityTypePostToFacebook,
	  UIActivityTypePostToWeibo,
	  UIActivityTypePrint,
	  UIActivityTypeAssignToContact,
	  UIActivityTypeSaveToCameraRoll,
	  UIActivityTypeAddToReadingList,
	  UIActivityTypePostToFlickr,
	  UIActivityTypePostToVimeo,
	  UIActivityTypePostToTencentWeibo];
	
    [self shareSCloudObject:scloud fromRect:inRect inView:inView exclude:exclude];
}

/**
 * AudioPlaybackViewDelegate
**/
- (void)audioPlaybackViewDidStopPlaying:(AudioPlaybackView *)sender finished:(BOOL)didFinish
{
	NSTimeInterval delay = 0.0;
	
	if (AppConstants.isIPhone)
	{
		if (didFinish)
			delay = 2.0;
		else
			delay = 6.0;
	}
	else
	{
		if (didFinish)
			delay = 4.0;
		else
			delay = 8.0;
	}
	
	[self performSelector:@selector(cleanupAudioPlaybackView) withObject:nil afterDelay:delay];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark TITokenField
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[textField resignFirstResponder];
	[inputView.autoGrowTextView becomeFirstResponder];
	
	return NO;
}

- (void)tokenFieldFrameDidChange:(TITokenField *)tokenField
{
	DDLogAutoTrace();
	
	// Anything to do here ?
}

- (void)tokenField:(TITokenField *)tokenField didHitAlertToken:(TIToken *)token
{
	DDLogAutoTrace();
	
	[self verifyToken:token tokenText:token.title];
}

- (void)tokenField:(TITokenField *)tokenField didAddToken:(TIToken *)token
{
	DDLogAutoTrace();
	
	NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	NSString *text = [token.title stringByTrimmingCharactersInSet:whitespace];
	
	if (!canMulticast && recipientDict.count)
	{
		[tokenField removeToken:token];
		
		NSString * errorMsg = NSLS_COMMON_INVALID_FEATURE;
		NSString * errorDetail = NSLS_COMMON_MULTICAST_NOT_SUPPORTED;
		
		[YRDropdownView showDropdownInView:topView
									 title:errorMsg
									detail:errorDetail
									 image:[UIImage imageNamed:@"dropdown-alert"]
								  animated:YES
								 hideAfter:3];
		
	}
	else
	{
		[self verifyToken:token tokenText:text];
	}
}

- (BOOL)tokenField:(TITokenField *)tokenField willRemoveToken:(TIToken *)token
{
	DDLogAutoTrace();
	
	XMPPJID *jid = token.representedObject;
	NSAssert(![jid isKindOfClass:[NSString class]], @"Using a string instead of a JID somewhere...");
	
	if (jid == nil)
	{
		NSString *username = token.title;
		
		XMPPJID *localJid = STDatabaseManager.currentUser.jid;
		NSString *localDomain = [localJid domain];
		
		jid = [XMPPJID jidWithUser:username domain:localDomain resource:nil];
	}
	
	[recipientDict removeObjectForKey:jid];
	[self updateSendButton];
	
	return YES;
}

- (NSString *)tokenField:(TITokenField *)tokenField displayStringForRepresentedObject:(id)object
{
	DDLogTrace(@"tokenField:displayStringForRepresentedObject: %@", object);
	
	NSString *displayName = [self tokenField:tokenField searchResultStringForRepresentedObject:object];
//	NSString* jidString = object;
//	NSString* displayName = [tokenFieldAutocomplete objectForKey:jidString];
	
	return displayName ? displayName : @"";
}

- (NSString *)tokenField:(TITokenField *)tokenField searchResultStringForRepresentedObject:(id)object
{
	//	DDLogTrace(@"tokenField:searchResultStringForRepresentedObject: %@", object);
	
	// This method is called to get a string which can be compared to the string the user has typed.
	// Here's how it works:
	//
	// The tokenFieldView has a sourceArray property, which we set to be [tokenFieldAutocomplete allKeys].
	// Whenever the user starts typing, the sourceArray is enumerated, and the tokenField invokes:
	//  - tokenField:searchResultStringForRepresentedObject:
	//  - tokenField:searchResultSubtitleForRepresentedObject:
	//
	// The object passed as the parameters comes from the sourceArray (tokenFieldAutocomplete.key).
	// Afterwards, the tokenFieldView has 2 strings, one from each delegate method.
	// It then does a rangeOfString query on each string to see if the search term matches either string.
	// If so, then it shows them in the autocomplete view it displays.
	//
	// The tokenFieldAutocomplete dictionary is:
	//  - key   = user.jid         (string)
	//  - value = user.displayName (string)
	
	if ([object isKindOfClass:[XMPPJID class]])
	{
		XMPPJID *jid = (XMPPJID *)object;
		return [jid user];
	} else if ([object isKindOfClass:[NSString class]])
	{
		NSString *jidStr = (NSString *)object;
		return [tokenFieldAutocomplete objectForKey:jidStr];
	}
	else if ([object isKindOfClass:[PersonSearchResult class]])
	{
		PersonSearchResult *person = (PersonSearchResult *)object;
		return person.fullName;
	}
	
	return nil;	
}

- (NSString *)tokenField:(TITokenField *)tokenField searchResultSubtitleForRepresentedObject:(id)object
{
	//	DDLogTrace(@"tokenField:searchResultSubtitleForRepresentedObject: %@", object);
	
	// This method is called to get a string which can be compared to the string the user has typed.
	// Here's how it works:
	//
	// The tokenFieldView has a sourceArray property, which we set to be [tokenFieldAutocomplete allKeys].
	// Whenever the user starts typing, the sourceArray is enumerated, and the tokenField invokes:
	//  - tokenField:searchResultStringForRepresentedObject:
	//  - tokenField:searchResultSubtitleForRepresentedObject:
	//
	// The object passed as the parameters comes from the sourceArray (tokenFieldAutocomplete.key).
	// Afterwards, the tokenFieldView has 2 strings, one from each delegate method.
	// It then does a rangeOfString query on each string to see if the search term matches either string.
	// If so, then it shows them in the autocomplete view it displays.
	//
	// The tokenFieldAutocomplete dictionary is:
	//  - key   = user.jid         (string)
	//  - value = user.displayName (string)

// EA: removing jid from display
//	if ([object isKindOfClass:[XMPPJID class]])
//	{
//		XMPPJID *jid = (XMPPJID *)object;
//		return [jid bare];
//	}
//	else if ([object isKindOfClass:[NSString class]])
//	{
//		NSString *jidStr = (NSString *)object;
//		return jidStr;
//	}
//	else if ([object isKindOfClass:[PersonSearchResult class]])
//	{
//		PersonSearchResult *person = (PersonSearchResult *)object;
//		return person.jid;
//	}
	return nil;
}

- (void)tokenField:(TITokenField *)tokenField searchForSecondaryResultsWithString:(NSString *)searchString {
#if USE_SC_DIRECTORY_SEARCH
	[[SCWebAPIManager sharedInstance] searchUsers:searchString forLocalUser:STDatabaseManager.currentUser limit:50 completionBlock:^(NSError *error, NSArray *peopleList)
		{
			if (!error)
				tokenFieldView.secondaryResultsArray = [[NSMutableArray alloc] initWithArray:peopleList];
		}];
#endif
}

- (void)tokenFieldChangedEditing:(TITokenField *)tokenField
{
	DDLogAutoTrace();
	
	// There's some kind of annoying bug where UITextFieldViewModeWhile/UnlessEditing doesn't do anything
	[tokenField setRightViewMode:(tokenField.editing ? UITextFieldViewModeAlways : UITextFieldViewModeNever)];
}

#pragma mark - TITokenFieldDelegate TableView methods
- (CGFloat)tokenField:(TITokenField *)tokenField resultsTableView:(UITableView *)tiTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
// NYI
//	if (previousSelectedUserId) {
//		NSString *userId = [self userIdForIndexPath:indexPath];
//		if ([userId isEqualToString:previousSelectedUserId]) {
//			STUser *user = [self userForUserId:userId];
//			BOOL bShowExpanded = ( (user == nil) || (user.isRemote) );
//			return [ContactsSubViewControllerCell cellHeightExpanded:bShowExpanded];
//		}
//	}
	return [ContactsSubViewControllerCell cellHeightExpanded:NO];
}

- (CGFloat)tokenField:(TITokenField *)tokenField resultsTableView:(UITableView *)tiTableView heightForHeaderInSection:(NSInteger)section {
	if (section == 0)
		return 0; // no header on first section (local contacts)
	
	return [ContactsSubViewControllerHeader cellHeight];
}

- (UIView *)tokenField:(TITokenField *)tokenField resultsTableView:(UITableView *)tiTableView viewForHeaderInSection:(NSInteger)section {
	if (section == 0)
		return nil; // no header on first section (local contacts)
	
	NSString *cellIdentifier = @"ContactsSubViewControllerHeader";
	ContactsSubViewControllerHeader *headerView = [tiTableView dequeueReusableHeaderFooterViewWithIdentifier:cellIdentifier];
	headerView.backgroundColor = [UIColor redColor];
	headerView.titleLabel.text = STDatabaseManager.currentUser.organization;
	return headerView;
}

- (UITableViewCell *)tokenField:(TITokenField *)tokenField resultsTableView:(UITableView *)tiTableView cellForRepresentedObject:(id)object {
	NSString *cellIdentifier = @"ContactsSubViewControllerCell";
	ContactsSubViewControllerCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	//cell.delegate = self; // don't set delegate, we don't expand
//	return cell;
    
    //ET 03/16/15
    // ST-1012 Call configure method
    return [self configuredCell:cell withTITokenFieldRepresentedObject:object];
}

//ET 03/16/15
// ST-1012
// This may have been a TITokenField delegate callback method in a version previous to
// use of cocoapod update (?). 
// Rename this method to be called from the tokenField:resultsTableView:cellForRepresentedObject: delegate method.
//- (void)tokenField:(TITokenField *)tokenField resultsTableView:(UITableView *)tiTableView willDisplayCell:(UITableViewCell*)cell forRepresentedObject:(id)object 
//{
- (ContactsSubViewControllerCell *)configuredCell:(ContactsSubViewControllerCell *)subCell withTITokenFieldRepresentedObject:(id)object {
	NSString *userIdSnapshot = nil;
//	ContactsSubViewControllerCell *subCell = (ContactsSubViewControllerCell *)cell;
	subCell.meLabel.text = nil;
	subCell.nameLabel.textColor = [UIColor blackColor];
	if ([object isKindOfClass:[XMPPJID class]])
	{
		XMPPJID *jid = (XMPPJID *)object;
		// TODO: how can we get the full name?
		subCell.nameLabel.text = [jid user];
	} else if ([object isKindOfClass:[NSString class]])
	{
		// does this happen?
		NSString *jidStr = (NSString *)object;
		// TODO: how can we get the full name?
		subCell.nameLabel.text = jidStr;
	}
	else if ([object isKindOfClass:[PersonSearchResult class]])
	{
		PersonSearchResult *person = (PersonSearchResult *)object;
		if (person) {
			subCell.nameLabel.text = person.fullName;
			userIdSnapshot = person.jid;
		} else
			subCell.nameLabel.text = @"";
		subCell.isSavedToSilentContacts = NO;
	}
	subCell.expanded = NO;
    
    return subCell;
}


- (void)verifyToken:(TIToken *)token tokenText:(NSString *)tokenText
{
	DDLogAutoTrace();
	
    //ET 02/09/15
    //ST-938 Update TITokenField to CocoaPod
//	if (token.accessoryType == TITokenAccessoryTypeActivityIndicator) // deprecated in newer pod version
    if (token.accessoryType == TITokenAccessoryTypeDisclosureIndicator)
		return;
	
	STLocalUser *currentUser = STDatabaseManager.currentUser;
	
	XMPPJID *localJid = currentUser.jid;
	NSString *localDomain = [localJid domain];
	
	XMPPJID *userJid = nil;
	NSString *userName = nil;
	
	if (token.representedObject)
	{
		userJid = (XMPPJID *)token.representedObject;
		userName = [userJid user];
	}
	else
	{
		userName = [tokenText lowercaseString];
		token.title = userName;
		
		userJid = [XMPPJID jidWithUser:userName domain:localDomain resource:nil];
	}
	
	// It's invalid to send a message to yourself
	
	if ([localJid isEqualToJID:userJid options:XMPPJIDCompareBare])
	{
		[token setTintColor: [UIColor notAllowedColor]];
        //ET 02/09/15
        //ST-938 Update TITokeField to CocoaPod
//		[token setAccessoryType: TITokenAccessoryTypeAlertIndicator];
        [token setAccessoryType: TITokenAccessoryTypeDisclosureIndicator];
		
		[tokenFieldView.tokenField layoutTokensAnimated:NO];
		
		if (![[recipientDict objectForKey:userJid] isEqual:@(kSCimpMethod_Invalid)])
		{
			NSString * errorMsg = NSLS_COMMON_INVALID_USER;
			NSString * errorDetail = NSLS_COMMON_INVALID_SELF_USER_DETAIL;
			
			[YRDropdownView showDropdownInView:topView
										 title:errorMsg
										detail:errorDetail
										 image:[UIImage imageNamed:@"dropdown-alert"]
									  animated:YES
									 hideAfter:3];
		}
		
		[recipientDict setObject:@(kSCimpMethod_Invalid) forKey:userJid];
		[self updateSendButton];
		
		return;
	}
	
	
	// Check to see if the we have an entry in our database.
	
	__block STUser *user = nil;
	
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		user = [[DatabaseManager sharedInstance] findUserWithJID:userJid transaction:transaction];
	}];
	
	if (user) // if it's in our database then set the color
	{
		[token setTitle:user.displayName];
		[token setRepresentedObject:userJid];
		
		[tokenFieldAutocomplete setObject:user.displayName forKey:userJid];
		
		if (user.currentKeyID)
		{
			[token setTintColor:[UIColor inDBColor]];
			
			[recipientDict setObject:@(kSCimpMethod_PubKey) forKey:userJid];
			[self updateSendButton];
		}
		
		__weak id weakSelf = self;
		[[STUserManager sharedInstance] refreshWebInfoForUser:user
		                                      completionBlock:^(NSError *error, NSString *userID, NSDictionary *infoDict)
		{
			[weakSelf didFetchUserInfoForUserJid:userJid withError:error userID:userID token:token];
		}];
	}
	else if (user == nil)
	{
		// Look up user from server
		
		[token setTintColor:[UIColor grayColor]];
        //ET 02/09/15
        //ST-938 Update TITokeField to CocoaPod
//		[token setAccessoryType:TITokenAccessoryTypeActivityIndicator];
        [token setAccessoryType: TITokenAccessoryTypeDisclosureIndicator];
		
		__weak id weakSelf = self;
		[[STUserManager sharedInstance] createUserIfValidJID:userJid
		                                     completionBlock:^(NSError *error, NSString *userID)
		{
			[weakSelf didFetchUserInfoForUserJid:userJid withError:error userID:userID token:token];
		}];
	}
}

/**
 * This method represents the completion block for:
 * 
 * [[SCWebAPIManager sharedInstance] getUserInfo:userName
 *                                               forUser:STDatabaseManager.currentUser
 *                                       completionBlock:^(NSError *error, NSDictionary *infoDict) {}];
 *
 * which is called from the verifyToken:tokenText: method above.
 *
 * Because the fetch involves a network request which could take a considerable amount of time to complete,
 * we'd prefer that a slow network not prevent the messagesViewController from deallocation for several minutes.
**/
- (void)didFetchUserInfoForUserJid:(XMPPJID *)userJid
                          withError:(NSError *)error
                             userID:(NSString *)userID
                              token:(TIToken *)token
{
	DDLogAutoTrace();
	
	[token setAccessoryType:TITokenAccessoryTypeNone];
	[tokenFieldView.tokenField layoutTokensAnimated:NO];
	
	//	DDLogVerbose(@"SCWebAPIManager infoDict: %@", infoDict);
	
	if (error || !userID)
	{
		// Some kind of problem occurred
		
		[token setTintColor:[UIColor notfoundColor]];
        //ET 02/09/15
        //ST-938 Update TITokeField to CocoaPod
//		[token setAccessoryType: TITokenAccessoryTypeAlertIndicator];
        [token setAccessoryType: TITokenAccessoryTypeDisclosureIndicator];
		
		[tokenFieldView.tokenField layoutTokensAnimated:NO];
		
		if ([[recipientDict objectForKey:userJid] isEqual:@(kSCimpMethod_Invalid)])
		{
			NSString * errorMsg = NSLS_COMMON_CONNECT_FAILED;
			NSString * errorDetail = NSLS_COMMON_CONNECT_DETAIL;
			
			if (error.code == -1004)
			{
				errorMsg = NSLS_COMMON_INVALID_USER;
				errorDetail = [NSString stringWithFormat:NSLS_COMMON_INVALID_USER_DETAIL, userJid.user];
			}
			
			[YRDropdownView showDropdownInView:topView
										 title:errorMsg
										detail:errorDetail
										 image:[UIImage imageNamed:@"dropdown-alert"]
									  animated:YES
									 hideAfter:3];
			
		}
		
		[recipientDict setObject:@(kSCimpMethod_Invalid) forKey:userJid];
	}
	else
	{
		// Created a user for the JID
		
		__block STUser *user = nil;
		[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
		}];
		
		if ([user.publicKeyIDs count] == 0)
		{
			[token setTintColor:[UIColor dhKeyColor]];
			[recipientDict setObject:@(kSCimpMethod_DH) forKey:userJid];
		}
		else
		{
			[token setTintColor:[UIColor publicKeyColor]];
			[recipientDict setObject:@(kSCimpMethod_PubKey) forKey:userJid];
		}
		
		NSString *displayName = user.displayName;
		
		[tokenFieldAutocomplete setObject:displayName forKey:userJid];
		
		[token setTitle:displayName];
		[token setRepresentedObject:userJid];
		
		[tokenFieldView.tokenField layoutTokensAnimated:NO];
	}
	
	[self updateSendButton];
}

- (void)saveRecipientsToPreferences
{
	DDLogAutoTrace();
	
	NSArray *tokens = tokenFieldView.tokenField.tokens;
	
	if ([tokens count] == 0)
	{
		[STPreferences setPendingRecipientNames:nil forConversationId:conversationId];
		[STPreferences setPendingRecipientJids:nil forConversationId:conversationId];
		
		return;
	}
	
	NSMutableArray *names = [NSMutableArray arrayWithCapacity:[tokens count]];
	NSMutableArray *jids  = [NSMutableArray arrayWithCapacity:[tokens count]];
	
	for (TIToken *token in tokens)
	{
		if (token.title)
		{
			[names addObject:token.title];
			
			XMPPJID *jid = token.representedObject;
			if (jid)
				[jids addObject:jid];
			else
				[jids addObject:[NSNull null]];
		}
	}
	
	[STPreferences setPendingRecipientNames:names forConversationId:conversationId];
	[STPreferences setPendingRecipientJids:jids forConversationId:conversationId];
}

- (void)restoreRecipientsFromPreferences
{
	DDLogAutoTrace();
	
	[tokenFieldView.tokenField removeAllTokens];
	
	NSArray *names = [STPreferences pendingRecipientNamesForConversationId:conversationId];
	NSArray *jids  = [STPreferences pendingRecipientJidsForConversationId:conversationId];
	
	for (NSUInteger i = 0; i < [names count]; i++)
	{
		NSString *name = [names objectAtIndex:i];
		id jidItem     = [jids  objectAtIndex:i];
		
		if ((id)jidItem == (id)[NSNull null])
		{
			[tokenFieldView.tokenField addTokenWithTitle:name representedObject:nil];
		}
		else
		{
			XMPPJID *jid = nil;
			if ([jidItem isKindOfClass:[XMPPJID class]])
				jid = (XMPPJID *)jidItem;
			else if ([jidItem isKindOfClass:[NSString class]])
				jid = [XMPPJID jidWithString:(NSString *)jidItem];
			
			[tokenFieldView.tokenField addTokenWithTitle:name representedObject:jid];
		}
	}
}

- (BOOL)checkRecipients
{
	DDLogAutoTrace();
	
	// if we have more than one jid, then they must all be PK JIDS
	
	BOOL isOK = FALSE;
	
	NSArray *badJids =  [recipientDict allKeysForObject:@(kSCimpMethod_Invalid)];
	if (badJids.count == 0)
	{
		if(recipientDict.count > 1)
		{
			if(canMulticast)
			{
				NSArray* nonPKJids =  [recipientDict allKeysForObject:@(kSCimpMethod_DH)];
				isOK = (nonPKJids.count == 0);
                
				if (!isOK)
				{
					NSString *title = NSLocalizedString(@"Recipient Invalid", @"Recipient Invalid");
					NSString *msg   = NSLocalizedString(
					  @"All recipients of a multi user conversation must be using SilentText version 2",
					  @"All recipients of a multi user conversation must be using SilentText version 2");
					
					UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
					                                                message:msg
					                                               delegate:nil
					                                      cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
					                                      otherButtonTitles:nil];
					[alert show];
				}
			}
		}
		else
		{
			isOK = TRUE;
		}
	}
	
	return isOK;
}

- (void)showContactsPicker:(id)sender
{
	DDLogMagenta(@"showContactsPicker");
	
	MessageRecipientViewController* mrc = [[MessageRecipientViewController alloc] initWithDelegate:self ];
	
	[self showViewController:mrc
	                fromRect:tokenFieldView.tokenField.rightView.frame
	                  inView:tokenFieldView
	              forMessage:nil
	             hidesNavBar:NO
	         arrowDirections:UIPopoverArrowDirectionUp];
}

- (void)messageRecipientViewController:(MessageRecipientViewController *)sender
						selectedUserID:(NSString *)userID
								 error:(NSError *)error
{
    __block STUser* user = NULL;
    
    if(!userID)
    {
        if(AppConstants.isIPhone)
        {
            isPopingBackIntoView = YES;
            
            [self.navigationController popViewControllerAnimated: YES];
            
        }
        else
        {
            [self dismissPopoverIfNeededAnimated: YES];
        }
        return;
    }
    
    [STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
     }];
    
    
    if (user) {
        [tokenFieldView.tokenField addTokenWithTitle:user.displayName
                                   representedObject:user.jid];
    }
    
    if (AppConstants.isIPhone)
    {
        isPopingBackIntoView = YES;
        [self.navigationController popViewControllerAnimated: YES];
    }
    
}

- (void)messageRecipientViewController:(MessageRecipientViewController *)sender
						   selectedJid:(NSString *)jidStr
						   displayName: (NSString *)displayName
								 error:(NSError *)error
{
	if(jidStr)
	{
		XMPPJID *jid = [XMPPJID jidWithString:jidStr];
		[tokenFieldView.tokenField addTokenWithTitle:displayName representedObject:jid];
	}
	
	if(AppConstants.isIPhone)
	{
		isPopingBackIntoView = YES;
		[self.navigationController popViewControllerAnimated: YES];
	}
	else
	{
        [self dismissPopoverIfNeededAnimated: YES];
	}
	
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Conversation Details
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)titleTap:(id)sender
{
    DDLogAutoTrace();
    
    if (conversation.isNewMessage )
        return;
    
    [self presentConversationDetailsWithSender:sender message:nil];
}

- (void)presentConversationDetailsWithSender:(id)sender message:(STMessage *)msg
{
    ConversationDetailsVC *detailsVC = [[ConversationDetailsVC alloc] initWithConversation:conversation];
    detailsVC.delegate = self;
    
    if (AppConstants.isIPhone)
    {
        detailsVC.presentingController = self;
        
        self.navigationItem.backBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@" ",@"BLANK TITLE")
                                         style:UIBarButtonItemStylePlain
                                        target:nil
                                        action:nil];
    }

    [self showViewController:detailsVC 
                    fromRect:[(UIButton *)sender frame] 
                      inView:self.navigationController.navigationBar 
                  forMessage:msg
                 hidesNavBar:NO 
             arrowDirections:UIPopoverArrowDirectionAny];
}

- (void)clearConversation:(id)sender
{
    NSString *_conversationId = conversationId;
    NSString *_userId = STDatabaseManager.currentUser.uuid;
    
    YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
    [rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
        
        // Fetch any scloud items and delete their corresponding files from disk.
        // We can do this more efficiently by walking the "hasScloud" view,
        // which includes only messages within this conversation that have an scloud item.
        
        [[transaction ext:Ext_View_HasScloud] enumerateKeysAndObjectsInGroup:_conversationId
                                                                  usingBlock:^(NSString *collection, NSString *key, id object, NSUInteger index, BOOL *stop)
         {
             __unsafe_unretained STMessage *message = (STMessage *)object;
             
             NSString *scloudId = message.siren.cloudLocator;
             STSCloud *scl = [transaction objectForKey:scloudId inCollection:kSCCollection_STSCloud];
             
             [scl removeFromCache];
         }];
        
        // Delete all the messages within the conversation
        [transaction removeAllObjectsInCollection:_conversationId];
        
        // Notes:
        //
        // - The relationship extension will automatically remove message thumbnails (if needed)
        // - The relationship extension will automatically remove the scloud items (if needed)
        
        // Update the conversation
        STConversation *updatedConversation = [transaction objectForKey:_conversationId inCollection:_userId];
        
        updatedConversation = [updatedConversation copy];
        updatedConversation.lastUpdated = [NSDate dateWithTimeIntervalSince1970:0.0];
        
        [transaction setObject:updatedConversation
                        forKey:updatedConversation.uuid
                  inCollection:updatedConversation.userId];
        
        // Add a flag for this transaction specifying that we cleared the conversation.
        // This is used by the UI to avoid the usual burn animation when it sees a message was deleted.
        NSDictionary *transactionExtendedInfo = @{
                                                  kTransactionExtendedInfo_ClearedConversationId: conversationId
                                                  };
        transaction.yapDatabaseModifiedNotificationCustomObject = transactionExtendedInfo;
    }];
}

- (void)cancelNewConversation
{
    DDLogAutoTrace();
    
    [STAppDelegate.conversationViewController deleteConversation:conversationId];
 
	if(AppConstants.isIPhone)
	{
		[self.navigationController popViewControllerAnimated: YES];
	}

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark ConversationDetailsDelegate Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)clearConversationAndDismiss:(id)sender
{
	DDLogAutoTrace();
    
    [self clearConversation:sender];
	
	if (AppConstants.isIPhone)
	{
		[self.navigationController popViewControllerAnimated:YES];
	}
	else
	{
        [self dismissPopoverIfNeededAnimated:YES];
    }
}

- (void)viewController:(UIViewController *)vc needsDismissPopoverAnimated:(BOOL)animated
{
    DDLogAutoTrace();
    
    [self dismissPopoverIfNeededAnimated:animated];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Conversation Security
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateConversationSecurityButton
{
	DDLogAutoTrace();
	
 	NSTimeInterval delay = 0;
	
	if (conversation)
	{
        if (conversation.isNewMessage)
        {
            self.navigationItem.rightBarButtonItems = NULL;
      
            self.navigationItem.rightBarButtonItem =
                    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                    target:self
													action:@selector(cancelNewConversation)];
        }
		else if(conversation.isFakeStream)
		{
			self.navigationItem.rightBarButtonItems = NULL;
			self.navigationItem.rightBarButtonItem = NULL;
		}
        else
		{
			if (conversation.notificationDate)
				delay = [conversation.notificationDate timeIntervalSinceNow];
			else
				delay = [[NSDate distantPast] timeIntervalSince1970];
            
            __block SCimpSnapshot *scimpSnapshot = nil;
            
            // find the appropriate scimp state we are using in this conversation
			[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
				
				if (conversation.isMulticast)
                {
                    NSString* scimpID = conversation.scimpStateIDs.anyObject;
                    scimpSnapshot = [transaction objectForKey:scimpID inCollection:kSCCollection_STScimpState];
                }
                else
                {
					// Find the remote device we were talking to last.
					
					for (NSString *scimpID in conversation.scimpStateIDs)
					{
						SCimpSnapshot *aScimpSnapshot = [transaction objectForKey:scimpID
						                                             inCollection:kSCCollection_STScimpState];
						
						if ([aScimpSnapshot.remoteJID isEqualToJID:conversation.remoteJid options:XMPPJIDCompareFull])
						{
							scimpSnapshot = aScimpSnapshot;
						}
					}
				}
			}];
            
            BOOL isProtocolError = NO;
            SCimpMethod scimpMethod = kSCimpMethod_Invalid;
            
			if(scimpSnapshot)
            {
				if (IsSCLError(scimpSnapshot.protocolError)
				    && (scimpSnapshot.protocolError != kSCLError_SecretsMismatch))
				{
					isProtocolError = YES;
				}
				else
				{
					scimpMethod = scimpSnapshot.protocolMethod;
				}
			}
			
			SCSecurityLevel securityLevel = SCSecurityLevelNone;
			if (isProtocolError)
			{
				securityLevel = SCSecurityLevelRed;
			}
			else if (scimpSnapshot && scimpSnapshot.isVerified)
			{
				securityLevel = SCSecurityLevelGreen;
			}
			else if (scimpSnapshot.isReady)
			{
				switch (scimpMethod)
				{
					case kSCimpMethod_PubKey    : securityLevel = SCSecurityLevelYellow1; break;
					case kSCimpMethod_DH        : securityLevel = SCSecurityLevelYellow2; break;
					case kSCimpMethod_DHv2      : securityLevel = SCSecurityLevelYellow2; break;
					case kSCimpMethod_Symmetric : securityLevel = SCSecurityLevelYellow3; break;
					default:;
				}
			}
			
			if (conversationInfoButton == nil) {
				securityButton = [SecurityStatusButton buttonWithType:UIButtonTypeSystem];
				securityButton.frame = CGRectMake(0.0f, 0.0f, 50, 24);
				[securityButton addTarget:self
								   action:@selector(presentConversationSecurityDetails:)
						 forControlEvents:UIControlEventTouchUpInside];
				
				conversationInfoButton = [[UIBarButtonItem alloc] initWithCustomView:securityButton];
				[conversationInfoButton setEnabled:YES];
				[securityButton setEnabled:YES];
			}
			securityButton.securityLevel = securityLevel;
			
			if (delay > 0) {
				UIImage *muteImage = conInfo_Mute;
				UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
				[button setFrame:CGRectMake(0.0f, 0.0f, 20, 20)];
				[button setImage:muteImage forState:UIControlStateNormal];
				[button addTarget:self
						   action:@selector(presentConversationSecurityDetails:)
				 forControlEvents:UIControlEventTouchUpInside];
				UIBarButtonItem *muteButton = [[UIBarButtonItem alloc] initWithCustomView:button];
				
				self.navigationItem.rightBarButtonItem = NULL;
				self.navigationItem.rightBarButtonItems = @[conversationInfoButton,muteButton];
			}
			else
			{
				self.navigationItem.rightBarButtonItems = NULL;
				self.navigationItem.rightBarButtonItem = conversationInfoButton;
                
			} // end if (delay > )
            
		} // end if (isNewMessage / isFakeStream / else)
        
        //ET 03/27/15 - Accessibility
        NSString *aLbl = [NSString stringWithFormat:NSLocalizedString(@"%@ security details", 
                                                                      @"%@ {Conversation user name} security details"), 
                          titleString];
        securityButton.accessibilityLabel = aLbl;
        
    } // end if (conversation)
}

- (void)presentConversationSecurityDetails:(id)sender
{
	DDLogAutoTrace();
    
    // ignore clicks to silentTextInfoUser
	if (IsSTInfoJID(remoteJID)) {
		return;
	}
 	
    if(conversation.isFakeStream)
        return;
    
    ConversationSecurityVC *securityVC = [[ConversationSecurityVC alloc] initWithConversation:conversation];
    securityVC.delegate = self;

    CGRect rect = ((UIView *)sender).frame;
    rect.origin.y += 10;

    [self showViewController:securityVC 
                    fromRect:rect
                      inView:self.navigationController.navigationBar 
                  forMessage:nil 
                 hidesNavBar:NO 
             arrowDirections:UIPopoverArrowDirectionAny];

    return;
    
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark ChatOptionsViewDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


- (void)chatOptionsPress:(id)sender
{
	if (chatOptionsView.visible) {
		[chatOptionsView hideChatOptionsView];
		chatOptionsView = nil;
	}
	else {
		chatOptionsView = [ChatOptionsView loadChatView];
		chatOptionsView.delegate = self;
        //ET 03/28/15 - Accessibility
        // Default behavior is to set a 4 second timeout, after which the
        // chatOptionsView automatically dismisses.
        // Consider what this means for the sight-impaired user:
        // Tap the options button to animate the chatOptionsView into view. 
        // Fingering over the options buttons, VoiceOver speaks their labels.
        // Likely, before hearing all the buttons, the chatOptionsView disappears;
        // where there were options buttons, now there is nothing.
        //
        // So we first check for VoiceOver being on. If on, we suspend the timeout
        // function so this disappearing behavior doesn't happen. Note that
        // when the chatOptionsButton fires, the "if" block (above), dismisses
        // the chatOptionsView if it's not hidden.
        //
        // For VoiceOver users this means:
        // tap to display options / tap to dismiss options.
        // For non-VoiceOver users, there is no change to the current behavior.
        //
        // This implementation is enough to keep the chatOptionsView from
        // disappearing until something is selected or until the chat options
        // button is tapped again to dismiss, but Accessibility support for
        // using the chatOptionsView features has not been thoroughly explored.
        
        // Note: these two lines must precede the VoiceOver condition lines below.
		[inputView insertSubview:chatOptionsView atIndex:0];
		[chatOptionsView showChatOptionsView];
        
        // VoiceOver is active
        if (UIAccessibilityIsVoiceOverRunning()) {
            [chatOptionsView suspendFading:YES];
        } else {
            chatOptionsView.fadeOutTimeout = 4.0; // seconds <- pre-Accessibility
        }
	}
}

- (void)fadeOut:(ChatOptionsView *)sender
{
	[chatOptionsView hideChatOptionsView];
}
- (void)hideChatOptionsView
{
	[chatOptionsView hideChatOptionsView];
	chatOptionsView.visible = NO;
	chatOptionsView = nil;
}

- (BOOL)getBurnNoticeState
{
	return conversation.shouldBurn;
}

- (void)setBurnNoticeState:(BOOL)state
{
	if (conversation.shouldBurn != state)
	{
		// Update local conversation object (temporary)
		conversation = [conversation copy];
		conversation.shouldBurn = state;
		
		NSString *_conversationId = conversation.uuid;
		NSString *_userId = conversation.userId;
		
		YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
		[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
			
			// Update conversation object in database (non-temporary)
			STConversation *updateConversation = [transaction objectForKey:_conversationId inCollection:_userId];
			
			updateConversation = [updateConversation copy];
			updateConversation.shouldBurn = state;
			
			[transaction setObject:updateConversation
							forKey:updateConversation.uuid
					  inCollection:updateConversation.userId];
		}];
	}
}

- (uint32_t)getBurnNoticeDelay
{
	return conversation.shredAfter;
}

- (void)setBurnNoticeDelay:(uint32_t)delay
{
	if (conversation.shredAfter != delay)
	{
		// Update local conversation object (temporary)
		conversation = [conversation copy];
		conversation.shredAfter = delay;
		
		NSString *_conversationId = conversation.uuid;
		NSString *_userId = conversation.userId;
		
		YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
		[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
			
			// Update conversation object in database (non-temporary)
			STConversation *updatedConversation = [transaction objectForKey:_conversationId inCollection:_userId];
			
			updatedConversation = [updatedConversation copy];
			updatedConversation.shredAfter = delay;
			
			[transaction setObject:updatedConversation
							forKey:updatedConversation.uuid
					  inCollection:updatedConversation.userId];
		}];
	}
}



- (BOOL)getFYEOState
{
	return conversation.fyeo;
}

- (void)setFYEOState:(BOOL) state
{
	if (conversation.fyeo != state)
	{
		// Update local conversation object (temporary)
		conversation = [conversation copy];
		conversation.fyeo = state;
		
		NSString *_conversationId = conversation.uuid;
		NSString *_userId = conversation.userId;
		
		YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
		[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
			
			// Update conversation object in database (non-temporary)
			
			STConversation *updatedConversation = [transaction objectForKey:_conversationId inCollection:_userId];
			
			updatedConversation = [updatedConversation copy];
			updatedConversation.fyeo = state;
			
			[transaction setObject:updatedConversation
							forKey:updatedConversation.uuid
					  inCollection:updatedConversation.userId];
		}];
	}
}

- (BOOL)getIncludeLocationState
{
	return conversation.tracking;
}

- (void)setIncludeLocationState:(BOOL)state
{
	if (conversation.tracking != state)
	{
        
        [self setConversationTrackingUntil: state? [NSDate distantFuture]: [NSDate distantPast]];
      }
}

- (void)setConversationTrackingUntil:(NSDate*)endDate
{
    BOOL shouldTrack = [endDate isAfter:[NSDate date]];
  
    if (conversation.tracking != shouldTrack)
	{
		// Update local conversation object (temporary)
		conversation = [conversation copy];
        
        conversation.trackUntil  =  endDate;
        
        if(shouldTrack)
            [[GeoTracking sharedInstance] beginTracking ];
		else
            [[GeoTracking sharedInstance] stopTracking ];
        
		NSString *_conversationId = conversation.uuid;
		NSString *_userId = conversation.userId;
 
		YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
		[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
			
			// Update conversation object in database (non-temporary)
			STConversation *updatedConversation = [transaction objectForKey:_conversationId inCollection:_userId];
			
			updatedConversation = [updatedConversation copy];
            
            updatedConversation.trackUntil  =  endDate;
            
             [transaction setObject:updatedConversation
							forKey:updatedConversation.uuid
					  inCollection:_userId];
		}];
	}

}


- (BOOL) getCameraState
{
	BOOL state =  canSendMedia && [UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera];
	return(state);
}

- (BOOL) getPhoneState
{
	BOOL state = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"silentphone:"]];
	return(state);
}

- (BOOL)getPaperClipState
{
	BOOL state =  canSendMedia;
	return(state);
}

- (BOOL)getAudioState
{
	BOOL state =  canSendMedia;
	return(state);
}

#define NSLS_SHARE_LOCATION NSLocalizedString(@"Share my Location", @"Share my Location")
#define NSLS_SHARE_LOCATION_NOW NSLocalizedString(@"Send My Current Location", @"Send My Current Location")

#define NSLS_SHARE_LOCATION_1HR NSLocalizedString(@"Share for One Hour", @"Share for One Hour")
#define NSLS_SHARE_LOCATION_EOD NSLocalizedString(@"Share Until End of Day", @"Share Until End of Day")
#define NSLS_SHARE_LOCATION_FOREVER NSLocalizedString(@"Share Indefinitely", @"Share Indefinitely")
#define NSLS_SHARE_LOCATION_STOP NSLocalizedString(@"Stop Sharing my Location", @"Stop Sharing my Location")

#define NSLS_SHARE_LOCATION_UNTIL NSLocalizedString(@"Sharing your location until %@",  @"Sharing your location until %@")

- (void)sendLocationAction: (UIButton *) sender
{
	DDLogAutoTrace();
	
    [chatOptionsView suspendFading: YES];
    
    BOOL canTrack = [[GeoTracking sharedInstance] allowsTracking];
    
	if (!canTrack && !conversation.tracking)
    {
        if ([CLLocationManager locationServicesEnabled])
		{
			NSString *errorString = nil;
			
			CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
			switch(status)
			{
				case kCLAuthorizationStatusAuthorizedAlways:
				{
					break;
				}
				case kCLAuthorizationStatusDenied:
				{
                    errorString  = NSLocalizedString(@"Location services denied by user",
					                                 @"Alert view message");
                    break;
				}
				case kCLAuthorizationStatusRestricted:
				{
					errorString  = NSLocalizedString(@"Privacy controls restrict location services",
					                                 @"Alert view message");
                    break;
				}
				case kCLAuthorizationStatusNotDetermined:
				{
                    errorString  = NSLocalizedString(@"You have not given this app permision to use location services",
					                                 @"Alert view message");
					break;
				}
                default:
				{
					errorString  = NSLocalizedString(@"Unable to determine reason, possibly not available",
					                                 @"Unable to determine reason, possibly not available");
                    break;
				}
            }
            
            
			[OHAlertView showAlertWithTitle:NSLocalizedString(@"Can not send location", @"Alert view title")
			                        message:errorString
                               cancelButton:NULL
                                   okButton:NSLS_COMMON_OK
                              buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex)
             {
                 if(status == kCLAuthorizationStatusNotDetermined)
                 {
                     [[GeoTracking sharedInstance] askForPermision ];
                 }
             }];
            
            return;
        }
    }
    
    NSMutableArray *choices = [NSMutableArray array];
    
	if (canTrack) {
		[choices addObject:NSLS_SHARE_LOCATION_NOW];
	}
	
	if (conversation.tracking)
    {
        NSString * titleText = NSLS_SHARE_LOCATION;
        
        if ([conversation.trackUntil isBefore:[NSDate dateWithTimeIntervalSinceNow:24*60*60]])
        {
            titleText = [NSString stringWithFormat:NSLS_SHARE_LOCATION_UNTIL, [conversation.trackUntil whenString]];
        }
        
        [choices addObject:NSLS_SHARE_LOCATION_STOP];
        
        //ET 10/16/14 actionSheet udpate
        [OHActionSheet showFromRect:chatOptionsView.mapButton.frame 
                           sourceVC:self 
                             inView:chatOptionsView 
                     arrowDirection:UIPopoverArrowDirectionDown
                              title:titleText 
                  cancelButtonTitle:NSLS_COMMON_CANCEL 
             destructiveButtonTitle:nil 
                  otherButtonTitles:choices 
                         completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
		{
			NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
			
			if ([choice isEqualToString:NSLS_SHARE_LOCATION_STOP])
			{
				[chatOptionsView setMap:NO];
				[self setConversationTrackingUntil:[NSDate distantPast]];
			}
			else if ([choice isEqualToString:NSLS_SHARE_LOCATION_NOW])
			{
				[self sendMyCurrentLocation];
			}
			
			[chatOptionsView suspendFading: NO];
		}];
    }
    else // if (!conversation.tracking)
    {
        [choices addObject:NSLS_SHARE_LOCATION_1HR];
		[choices addObject:NSLS_SHARE_LOCATION_EOD];
		[choices addObject:NSLS_SHARE_LOCATION_FOREVER];

        //ET 10/16/14 OHActionSheet update
        [OHActionSheet showFromRect:chatOptionsView.mapButton.frame 
                           sourceVC:self 
                             inView:chatOptionsView
                     arrowDirection:UIPopoverArrowDirectionDown
                              title:NSLS_SHARE_LOCATION
                  cancelButtonTitle:NSLS_COMMON_CANCEL 
             destructiveButtonTitle:nil 
                  otherButtonTitles:choices 
                         completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
		{
			NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
			NSDate *shareUntil = nil;
			
			if ([choice isEqualToString:NSLS_SHARE_LOCATION_1HR])
			{
				shareUntil = [[NSDate date] dateByAddingTimeInterval:60*60];
			}
			else if ([choice isEqualToString:NSLS_SHARE_LOCATION_EOD])
			{
				shareUntil = [[NSDate date] endOfDay];
			}
			else if ([choice isEqualToString:NSLS_SHARE_LOCATION_FOREVER])
			{
				shareUntil = [NSDate distantFuture];
			}
			else if ([choice isEqualToString:NSLS_SHARE_LOCATION_NOW])
			{
				[self sendMyCurrentLocation];
			}
			
			if(shareUntil)
			{
				[self setConversationTrackingUntil:shareUntil];
				[chatOptionsView setMap:YES];
			}
			
			[chatOptionsView suspendFading: NO];
		}];
	}
}
 
- (void)paperclipAction:(UIButton *)sender
{
	DDLogAutoTrace();
	
	NSArray *importableDocs = [STAppDelegate importableDocs];
	
	NSMutableArray *otherButtonsTitles = [[NSMutableArray alloc] init];
	
	if (importableDocs && importableDocs.count > 0)
		[otherButtonsTitles addObject:NSLS_COMMON_SEND_ITUNES];
	
	[otherButtonsTitles addObject:NSLS_COMMON_SEND_CONTACT];
	
	if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary])
		[otherButtonsTitles addObject:NSLS_COMMON_SEND_PHOTO];
	
	[chatOptionsView suspendFading:YES];
	
	[OHActionSheet showFromRect:chatOptionsView.paperclipButton.frame
	                   sourceVC:self
	                     inView:chatOptionsView
                 arrowDirection:UIPopoverArrowDirectionDown
	                      title:NSLS_COMMON_SEND_ENCLOSURE
	          cancelButtonTitle:NSLS_COMMON_CANCEL
	     destructiveButtonTitle:nil
	          otherButtonTitles:otherButtonsTitles
	                 completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
	{
		NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
		
		if ([choice isEqualToString:NSLS_COMMON_SEND_PHOTO])
		{
			[inputView.autoGrowTextView resignFirstResponder];
			
			ipc = [[SCImagePickerViewController alloc] initWithViewController:self withDelegate:self];
			
			[ipc pickMultiplePhotosFromRect:chatOptionsView.paperclipButton.frame inView:chatOptionsView];
		}
		else if ([choice isEqualToString:NSLS_COMMON_SEND_ITUNES])
		{
			FileImportViewController *fic = [FileImportViewController.alloc initWithURLs:importableDocs];
			UINavigationController *fvc = [[UINavigationController alloc] initWithRootViewController:fic];
			
            //ST-1001: SWRevealController v2.3 update
//			[STAppDelegate.revealController setFrontViewController:fvc animated:YES];
            [STAppDelegate.revealController pushFrontViewController:fvc animated:YES];
		}
		else if ([choice isEqualToString:NSLS_COMMON_SEND_CONTACT])
		{
			[inputView.autoGrowTextView resignFirstResponder];
			
			cbc = [[SCContactBookPicker alloc] initWithDelegate:self];
			
			cbc.isInPopover = AppConstants.isIPhone ? NO : YES;
			
			BOOL contactWithThumbNails =
			  ([[conversation.capabilities objectForKey:@"vCardWithoutThumbNails"] boolValue]) ? NO : YES;
			
			cbc.needsThumbNail = contactWithThumbNails;
			
			[self showViewController:cbc
			                fromRect:chatOptionsView.paperclipButton.frame
			                  inView:chatOptionsView
			              forMessage:nil
			             hidesNavBar:NO
			         arrowDirections:UIPopoverArrowDirectionAny];
		}
		else
		{
			[chatOptionsView suspendFading: NO];
		}
		
	}]; // end OHActionSheet
}

- (void)contactAction:(UIButton *)sender
{
	DDLogAutoTrace();
	
	// Not implemented ?
	// Still used ?
}

- (void)phoneAction:(UIButton *)sender
{
	DDLogAutoTrace();
	
	NSString *phone = remoteJID.user;
	if (phone)
	{
		NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"silentphone:%@", phone]];
		
		[[UIApplication sharedApplication] openURL:url];
	}
}

- (void)micAction:(UIButton *)sender
{
	DDLogAutoTrace();
	
	[self recordAudio];
}

- (void)cameraAction:(UIButton *)sender
{
	DDLogAutoTrace();
	
	SCCameraViewController* cam = [[SCCameraViewController alloc] initWithDelegate:self];
	
	if (conversation.tracking)
	{
 		// insert tracking info
   		cam.location =  [[GeoTracking sharedInstance] currentLocation];
	}
	
	[self pushViewControllerAndFixNavBar: cam animated: YES];
	[cam pickNewPhoto];
}

- (void)recordAudio
{
	DDLogAutoTrace();
	
	[inputView.autoGrowTextView resignFirstResponder];
	
	[self hideChatOptionsView];
	
	if ([audioInputView superview]) {
		[audioInputView fadeOut];
		return;
	}
	
    BOOL audioWithThumbNails = (conversation.capabilities
                                   &&  [[conversation.capabilities objectForKey:@"audioWithoutThumbNails"] boolValue])?NO:YES;

	if (!audioInputView)
		audioInputView = [[STAudioView alloc] init];
	audioInputView.delegate = self;
    audioInputView.needsThumbNail = audioWithThumbNails;
 	
	[audioInputView unfurlOnView:self.view
						   under: inputView
						 atPoint:CGPointMake(17.5, inputView.frame.origin.y)];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)resendFailedMessage:(BOOL)shouldResend
{
	DDLogAutoTrace();
	
	if (selectedMessageID == nil) {
		// Nothing to resend
		return;
	}
	
	// Be careful about async operations.
	// So grab a copy of all the instance variables (self->ivar) we need before we start the async operation.
	
	STLocalUser *currentUserSnapshot = STDatabaseManager.currentUser;
	
	NSString *_selectedMessageID = selectedMessageID;
	NSString *_conversationId = conversationId;
	
	__block Siren *newSiren = nil;
	
	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
		
		STMessage *message = [transaction objectForKey:_selectedMessageID inCollection:_conversationId];
		
		if (shouldResend)
		{
			newSiren = [message.siren copy];
			newSiren.signature = NULL;
            
			[transaction removeObjectForKey:message.uuid inCollection:message.conversationId];
		}
		else
		{
			message = [message copy];
			
			message.needsReSend = NO;
			message.needsUpload = NO;
			message.ignored = YES;
			
			[transaction setObject:message
							forKey:message.uuid
					  inCollection:message.conversationId];
		}
		
		// Touch the conversation
		[[transaction ext:Ext_View_Order] touchRowForKey:message.conversationId
		                                    inCollection:message.userId];
		
		// Add a flag for this transaction specifying that we "cleared" this message.
		// This is used by the UI to avoid the usual burn animation when it sees a message was deleted.
		if (shouldResend)
		{
			if (transaction.yapDatabaseModifiedNotificationCustomObject)
			{
				NSMutableDictionary *info = [transaction.yapDatabaseModifiedNotificationCustomObject mutableCopy];
				
				NSSet *clearedMessageIds = [info objectForKey:kTransactionExtendedInfo_ClearedMessageIds];
				if (clearedMessageIds)
					clearedMessageIds = [clearedMessageIds setByAddingObject:message.uuid];
				else
					clearedMessageIds = [NSSet setWithObject:message.uuid];
				
				[info setObject:clearedMessageIds forKey:kTransactionExtendedInfo_ClearedMessageIds];
				
				transaction.yapDatabaseModifiedNotificationCustomObject = [info copy];
			}
			else
			{
				NSDictionary *info = @{
				  kTransactionExtendedInfo_ClearedMessageIds: [NSSet setWithObject:message.uuid]
				};
				transaction.yapDatabaseModifiedNotificationCustomObject = info;
			}
		}

	} completionBlock:^{
		
		if (newSiren)
		{
			if (newSiren.cloudKey)
			{
				[self sendScloudWithSiren:newSiren];
			}
			else
			{
				MessageStream *messageStream = [MessageStreamManager messageStreamForUser:currentUserSnapshot];
				[messageStream sendSiren:newSiren
				       forConversationID:conversationId
				                withPush:YES
				                   badge:YES
				           createMessage:YES
				              completion:NULL];
			}
		}
		
		if ([selectedMessageID isEqual:_selectedMessageID])
			selectedMessageID = nil;
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Database
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)initializeMappings
{
	DDLogAutoTrace();
	
	if (conversationId)
	{
		[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			if ([transaction ext:Ext_View_Order])
			{
				// We want to display the messages (collection == conversationId)
				// as they are appear in the 'order' view (sorted by timestamp).
				mappings = [[YapDatabaseViewMappings alloc] initWithGroups:@[conversationId] view:Ext_View_Order];
				
				// We want to start with the last 50, and allow it to grow from there, up to a max of 150.
				YapDatabaseViewRangeOptions *rangeOptions =
				[YapDatabaseViewRangeOptions flexibleRangeWithLength:50 offset:0 from:YapDatabaseViewEnd];
				rangeOptions.maxLength = 150;
				[mappings setRangeOptions:rangeOptions forGroup:conversationId];
				
				// Our timestamp drawing code is dependent upon the previous message.
				// So give us update instructions automatically if the previous message changes.
				[mappings setCellDrawingDependencyForNeighboringCellWithOffset:-1 forGroup:conversationId];
				
				// Initialize the mappings
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

- (void)databaseConnectionWillUpdate:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	oldMostRecentDeliveredMessageId = conversation.mostRecentDeliveredMessageID;
	
	// Get visible cells
	
	NSArray *visibleCells = [self.tableView visibleCells];
	
	if (tempVisibleCellsDict == nil)
		tempVisibleCellsDict = [NSMutableDictionary dictionaryWithCapacity:[visibleCells count]];
	else
		[tempVisibleCellsDict removeAllObjects];
	
	for (STBubbleTableViewCell *cell in visibleCells)
	{
		NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
		if (indexPath)
		{
			[tempVisibleCellsDict setObject:cell forKey:indexPath];
		}
	}
}

- (void)databaseConnectionDidUpdate:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	if (mappings && (mappings.snapshotOfLastUpdate == databaseConnection.snapshot))
	{
		// This edge case gets hit with the following sequence of events:
		// - A YapDatabaseModifiedNotfication is posted to the main thread
		// - The conversationViewController processes this notification first
		// - During processing, the conversationViewController invokes our setConversationId method,
		//   which in turn causes us to reset & re-initialize our mappings, and then reload the tableView.
		// - Then its our turn to processing the notification
		//
		// Except that we already did, in a sense.
		// So we can just take a shortcut here, and return.
		
		return;
	}
	
	NSArray *notifications = [notification.userInfo objectForKey:kNotificationsKey];
	
	// Check to see if the conversation object changed
	
	BOOL conversationChanged = [databaseConnection hasChangeForKey:conversationId
													  inCollection:STDatabaseManager.currentUser.uuid
												   inNotifications:notifications];
	
	// Check to see if any of the participants in the conversation (user objects) changed
	
	BOOL conversationUserChanged = [databaseConnection hasChangeForAnyKeys:conversationUserIds
															  inCollection:kSCCollection_STUsers
														   inNotifications:notifications];
	
	BOOL userRecordsChanged = [databaseConnection hasChangeForCollection:kSCCollection_STUsers
														 inNotifications:notifications];
	
	
	if (conversationChanged || conversationUserChanged)
	{
		[self updateConversationCache];
		[self updateConversationPermissions];
		[self updateConversationSecurityButton];        
	}
	
	// Update back button with new unread count (if it may have changed)
	
	if ([[databaseConnection ext:Ext_View_Unread] hasChangesForNotifications:notifications])
	{
		[self updateBackBarButton];
	}
	
	// Update tableView (full reload)
	
	if (mappings == nil || userRecordsChanged)
	{
		// Just reload the mappings entirely,
		// since we're not using getSectionChanges:rowChanges::: method to update the mappings.
		[self initializeMappings];
		
		if (userRecordsChanged) {
			[self reloadTokenFieldAutocomplete];
			[self updateConversationCache];
		}
		
		[tableView reloadData];
		
		if (!userRecordsChanged) {
			[self scrollToBottomAnimated:NO];
		}
		
		return;
	}
	
	// Check for extended transaction info.
	//
	// conversationWasCleared:
	//     The conversation was manually cleared.
	//     If this is the case, we we should skip the burn animations.
	//     A manual clear isn't a burn, and shouldn't be animated as such.
	//
	// clearedMessageIds:
	//     A specific messageID was cleared,
	//     and a burn animation shouldn't be used for this item.
	
	BOOL conversationWasCleared = NO;
	NSMutableSet *clearedMessageIds = nil;
	
	for (NSNotification *notification in notifications)
	{
		NSDictionary *transactionExtendedInfo = [notification.userInfo objectForKey:YapDatabaseCustomKey];
		if (transactionExtendedInfo)
		{
			NSString *clearedConversationId =
			  [transactionExtendedInfo objectForKey:kTransactionExtendedInfo_ClearedConversationId];
			
			if (clearedConversationId && [clearedConversationId isEqualToString:conversationId])
			{
				conversationWasCleared = YES;
			}
			
			NSSet *commitClearedMessageIds =
			  [transactionExtendedInfo objectForKey:kTransactionExtendedInfo_ClearedMessageIds];
			
			if (commitClearedMessageIds)
			{
				if (clearedMessageIds == nil)
					clearedMessageIds = [commitClearedMessageIds mutableCopy];
				else
					[clearedMessageIds unionSet:commitClearedMessageIds];
			}
		}
	}
	
	// Update tableView (animating changes)
	
	NSArray *rowChanges = nil;
	[[databaseConnection ext:Ext_View_Order] getSectionChanges:NULL
	                                                rowChanges:&rowChanges
	                                          forNotifications:notifications
	                                              withMappings:mappings];
	
	if ([rowChanges count] == 0)
	{
		// There aren't any changes that affect our tableView
		// Todo: add code to scroll to the bottom if new text messages were added, when viewing an old range
		return;
	}
	
	// Update ivars used to determine if the tableView should automatically scroll to the bottom:
	// - tableViewHasNewItems
	// - mostRecentDeliveredMessageChanged
	
	for (YapDatabaseViewRowChange *rowChange in rowChanges)
	{
		if (rowChange.type == YapDatabaseViewChangeInsert)
		{
			tableViewHasNewItems = YES;
			break;
		}
	}
	
	if (oldMostRecentDeliveredMessageId &&
		![oldMostRecentDeliveredMessageId isEqualToString:conversation.mostRecentDeliveredMessageID])
	{
		mostRecentDeliveredMessageChanged = YES;
		[cellHeightCache removeObjectForKey:oldMostRecentDeliveredMessageId];
	}
	
	// Clear updated items from cellHeightCache
	
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		for (YapDatabaseViewRowChange *rowChange in rowChanges)
		{
			if (rowChange.type == YapDatabaseViewChangeInsert ||
				rowChange.type == YapDatabaseViewChangeMove   ||
				rowChange.type == YapDatabaseViewChangeUpdate  )
			{
				NSString *changedMessageId = nil;
				[[transaction ext:Ext_View_Order] getKey:&changedMessageId
				                              collection:nil
				                                  forRow:rowChange.finalIndex
				                               inSection:0
				                            withMappings:mappings];
				
				[cellHeightCache removeObjectForKey:changedMessageId];
			}
		}
	}];
	
	// Update tableView (animated)
	
	[self.tableView beginUpdates];
	
	for (YapDatabaseViewRowChange *rowChange in rowChanges)
	{
		switch (rowChange.type)
		{
			case YapDatabaseViewChangeDelete :
			{
				[self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
									  withRowAnimation:UITableViewRowAnimationFade];
				
				STBubbleTableViewCell *visibleCell = [tempVisibleCellsDict objectForKey:rowChange.indexPath];
				if (visibleCell && !conversationWasCleared)
				{
					NSString *deletedMessageId = rowChange.collectionKey.key;
					if (![clearedMessageIds containsObject:deletedMessageId])
					{
						[self doBurnAnimationForCell:visibleCell];
					}
				}
				break;
			}
			case YapDatabaseViewChangeInsert :
			{
				[self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
									  withRowAnimation:UITableViewRowAnimationFade];
				break;
			}
			case YapDatabaseViewChangeMove :
			{
				[self.tableView deleteRowsAtIndexPaths:@[ rowChange.indexPath ]
									  withRowAnimation:UITableViewRowAnimationFade];
				[self.tableView insertRowsAtIndexPaths:@[ rowChange.newIndexPath ]
									  withRowAnimation:UITableViewRowAnimationFade];
				break;
			}
			case YapDatabaseViewChangeUpdate :
			{
				UITableViewRowAnimation animation = UITableViewRowAnimationNone;
				
				STBubbleTableViewCell *visibleCell = [tempVisibleCellsDict objectForKey:rowChange.indexPath];
				if (visibleCell)
				{
					STMessage *message = [self messageAtIndex:rowChange.finalIndex];
					
					BOOL hasTimestamp = [self hasTimestampForMessage:message atTableRow:rowChange.finalIndex];
					BOOL hasFooter = [self hasFooterForMessage:message];
					
					if ((hasTimestamp != visibleCell.hasTimestamp) || (hasFooter != visibleCell.hasFooter))
					{
						// The cell height changed
						animation = UITableViewRowAnimationFade;
					}
				}
				[self.tableView reloadRowsAtIndexPaths:@[ rowChange.indexPath ]
									  withRowAnimation:animation];
				break;
			}
		}
	}

	[self.tableView endUpdates];
	[tempVisibleCellsDict removeAllObjects];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Table Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)saveTableRestoreOffset
{
    if (AppConstants.isIPhone)
    {
        CGPoint restorePoint = self.tableView.contentOffset;
        
        if (theme.navBarIsTranslucent)
        {
            CGSize statusBarSize = [UIApplication sharedApplication].statusBarFrame.size;
            CGFloat statusBarHeight = MIN(statusBarSize.height, statusBarSize.width);
			
			CGFloat navBarHeight = self.navigationController.navigationBar.frame.size.height;
			
            CGFloat offset = navBarHeight + statusBarHeight;
			
			// This code looks brittle.
			// It's likely that we'd get the same offset by inspecting tableView.contentInset.top.
			//
			// (Which doesn't hard-code assumptions about translucent nav bars, and tableView frame postion.)
			//
			// -RH
			
			restorePoint.y += offset;
        }
        
        restoreOffset.point = restorePoint;
        restoreOffset.valid = YES;
    }
}

- (void)doBurnAnimationForCell:(STBubbleTableViewCell *)cell
{
	DDLogAutoTrace();
	
	UIImage *poof0 = [UIImage imageNamed:@"poof0"];
	UIImage *poof1 = [UIImage imageNamed:@"poof1"];
	UIImage *poof2 = [UIImage imageNamed:@"poof2"];
	UIImage *poof3 = [UIImage imageNamed:@"poof3"];
	UIImage *poof4 = [UIImage imageNamed:@"poof4"];
	UIImage *poof5 = [UIImage imageNamed:@"poof5"];
	
	NSArray	*poofImages = @[ poof5, poof4, poof3, poof2, poof1, poof0, poof1, poof2, poof3, poof4, poof5 ];
	
	UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
	imageView.animationImages = poofImages;
	imageView.animationDuration = 0.5;
	imageView.animationRepeatCount = 1;
	imageView.image = [poofImages objectAtIndex:0];
	imageView.contentMode = UIViewContentModeScaleAspectFit;
	
	CGSize imageSize = imageView.image.size;
	CGSize bubbleViewSize = cell.bubbleView.frame.size;
	
	CGFloat width = MIN(imageSize.width, bubbleViewSize.width);
	CGFloat height = MIN(imageSize.height, bubbleViewSize.height);
	
	CGPoint bubbleCenter = [self.view convertPoint:cell.bubbleView.center fromView:cell];
	
	imageView.frame = CGRectMake(0, 0, width, height);
	imageView.center = bubbleCenter;
	
	[self.view addSubview:imageView];
	[imageView startAnimating];
	
	__weak UIImageView *weakImageView = imageView;
	
	double delayInSeconds = 0.5;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		
		__strong UIImageView *strongImageView = weakImageView;
		if (strongImageView)
		{
			[strongImageView removeFromSuperview];
		}
	});
}

- (STMessage *)messageAtIndex:(NSUInteger)mappedIndex
{
	__block STMessage *message = nil;
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		message = [[transaction ext:Ext_View_Order] objectAtRow:mappedIndex inSection:0 withMappings:mappings];
	}];
	
	return message;
}


- (NSIndexPath *)indexPathForMessageId:(NSString *)messageId
{
	__block NSIndexPath *indexPath = nil;
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		indexPath = [[transaction ext:Ext_View_Order] indexPathForKey:messageId
		                                                 inCollection:conversationId
		                                                 withMappings:mappings];
	}];
    
	return indexPath;
}

- (STSCloud *)scloudForMessage:(STMessage *)message
{
	__block STSCloud *scl = nil;
	if (message.scloudID)
	{
		[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			scl = [transaction objectForKey:message.scloudID inCollection:kSCCollection_STSCloud];
		}];
	}
	
	return scl;
}

    
- (STImage *)thumbnailForMessage:(STMessage *)message
{
	__block STImage *thumbnail = nil;
	if (message.hasThumbnail)
	{
		[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			thumbnail = [transaction objectForKey:message.uuid inCollection:kSCCollection_STImage_Message];
		}];
	}
	
	return thumbnail;
}


- (NSString *)timestampForMessage:(STMessage *)message
{
	NSDate *date = message.timestamp;
	
	NSString *timestamp = [timestampCache objectForKey:date];
	if (timestamp)
		return timestamp;
	
	timestamp = [dateFormatter stringFromDate:date];
	
	if (timestamp)
		[timestampCache setObject:timestamp forKey:date];
	
	return timestamp;
}


- (BOOL)hasTimestampForMessage:(STMessage *)message atTableRow:(NSUInteger)tableRow
{
	if (tableRow == 0)
		return YES;
	
	STMessage *prevMessage = [self messageAtIndex:(tableRow-1)];
	
	if (prevMessage == nil)
	{
		DDLogWarn(@"prevMessage is nil: prevRow == %lu", (unsigned long)(tableRow-1));
		return YES;
	}
	
	if (prevMessage.timestamp == nil)
	{
		DDLogWarn(@"prevMessage has nil timestamp: prevRow == %lu", (unsigned long)(tableRow-1));
		return YES;
	}
	if (message.timestamp == nil)
	{
		DDLogWarn(@"message has nil timestamp: row == %lu", (unsigned long)tableRow);
		return NO;
	}
	
	// Display a timestamp if more than X minutes have elapsed between messages.
	
	NSTimeInterval elapsed = [message.timestamp timeIntervalSinceDate:prevMessage.timestamp];
	
	if (elapsed >= (60 * 30)) // 30 minutes
	{
		return YES;
	}
	
	// Display a timestamp if the day changes between messages.
	
	NSUInteger components = NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute;
	
	NSDateComponents *oldComponents = [calendar components:components fromDate:message.timestamp];
	NSDateComponents *newComponents = [calendar components:components fromDate:prevMessage.timestamp];
	
	if (oldComponents.year  != newComponents.year  ||
		oldComponents.month != newComponents.month ||
		oldComponents.day   != newComponents.day) {
		return YES;
	}
	
	return NO;
}

- (BOOL)hasNameForMessage:(STMessage *)message
{
	return (!message.isOutgoing && (conversation.multicastJidSet.count > 0));
}

- (BOOL)hasFooterForMessage:(STMessage *)message
{
	if (message.isStatusMessage)
		return YES;
	
	if (message.needsReSend)
		return YES;
	
	if (message.isOutgoing &&
	    message.rcvDate    &&
	    [message.uuid isEqualToString:conversation.mostRecentDeliveredMessageID])
		return YES;
	
	return NO;
}
- (BOOL)messageIsUnplayed:(STMessage *)message
{
    BOOL isUnplayed = NO;

    if(! message.isOutgoing
       && UTTypeConformsTo( (__bridge CFStringRef)message.siren.mediaType, kUTTypeAudio))
    {
        isUnplayed = !message.isRead;
    }

    return isUnplayed;

}

- (float)paddingForMessage :(STMessage *)message
{
  	BOOL hasBurn = message.isShredable && ! (message.isStatusMessage || message.isSpecialMessage); // dont show burn for status messages
	BOOL hasGeo =  message.hasGeo;
	BOOL isFYEO = message.siren.fyeo;
    BOOL isUnplayed = [self messageIsUnplayed:message];
    float padding = [STBubbleTableViewCell widthForSideButtonsWithBurn:hasBurn hasGeo:hasGeo isFYEO:isFYEO isUnPlayed:isUnplayed];
   
    return padding;
}

- (BOOL)hasSideButtonsForMessage:(STMessage *)message
{
	BOOL hasBurn = message.isShredable && ! (message.isStatusMessage || message.isSpecialMessage); // dont show burn for status messages
	BOOL hasGeo =  message.hasGeo;
	BOOL isFYEO = message.siren.fyeo;
    BOOL isUnplayed = [self messageIsUnplayed:message];

	return hasBurn || hasGeo || isFYEO || isUnplayed;
}

- (NSString *)displayNameForMessage:(STMessage *)message
{
    NSString *userKey = [message.from bare];
	NSString *displayName = nil;
	
	NSDictionary *userInfo = [userInfoDict objectForKey:userKey];
	if (userInfo)
	{
		displayName = [userInfo objectForKey:@"displayName"];
	}
	
	if (displayName == nil)
	{
		displayName = userKey;
	}
	
	return displayName;
}

/**
 * Message size calculations and caching.
 * All needed aspects concerning message sizing are calculated in this method.
**/
- (CGFloat)cellHeightForMessage:(STMessage *)message atTableRow:(NSUInteger)tableRow
{
	NSString *messageId = message.uuid;
	
	// Check cache
	NSNumber *cachedCellHeight = [cellHeightCache objectForKey:messageId];
	if (cachedCellHeight)
	{
		return [cachedCellHeight floatValue];
	}
	
	BOOL hasTimestamp = [self hasTimestampForMessage:message atTableRow:tableRow];
	BOOL hasName = [self hasNameForMessage:message];
	BOOL hasSideButtons = [self hasSideButtonsForMessage:message];
	BOOL hasFooter = [self hasFooterForMessage:message];
	
	NSString *name = hasName ? [self displayNameForMessage:message] : nil;
	
	CGFloat cellHeight = 0.0;
	
    // determine if there is an image for this message
    //ST-928 03/20/15 - use new Siren accessor instead of local constant
    UIImage *msgImage = [message imageForThumbNailScaledToHeight:[UIImage maxSirenThumbnailHeightOrWidth]
                                           withHorizontalPadding: 0
                                                        annotate:NO
                                                    fromUserName:NULL];  // specifing NO for annotate ignore the fromUserName
      
    
    if (msgImage)
	{
		cellHeight = [STBubbleTableViewCell heightForCellWithImage:msgImage
		                                                      name:name
		                                                  nameFont:kBubbleCellNameFont
		                                                  maxWidth:tableView.frame.size.width
		                                                 hasAvatar:YES
		                                               sideButtons:hasSideButtons
		                                                 timestamp:hasTimestamp
		                                                    footer:hasFooter];
	}
	else if (message.isStatusMessage)
	{
		NSString *status = [self statusMessageLine: message.statusMessage];
		
		cellHeight = [STBubbleTableViewCell heightForCellWithStatusText:status
		                                                       textFont:kBubbleCellStatusFont
		                                                           name:name
		                                                       nameFont:kBubbleCellNameFont
		                                                       maxWidth:tableView.frame.size.width
		                                                      hasAvatar:YES
		                                                    sideButtons:hasSideButtons
		                                                      timestamp:hasTimestamp
		                                                         footer:hasFooter];
	}
    else if(message.isSpecialMessage)
    {
   		cellHeight = [STBubbleTableViewCell heightForCellWithStatusText:message.specialMessageText
		                                                       textFont:kBubbleCellStatusFont
		                                                           name:name
		                                                       nameFont:kBubbleCellNameFont
		                                                       maxWidth:tableView.frame.size.width
		                                                      hasAvatar:YES
		                                                    sideButtons:hasSideButtons
		                                                      timestamp:hasTimestamp
		                                                         footer:hasFooter];
 
    }
	else
	{
		cellHeight = [STBubbleTableViewCell heightForCellWithText:message.siren.message
		                                                 textFont:kBubbleCellTextFont
		                                                     name:name
		                                                 nameFont:kBubbleCellNameFont
		                                                 maxWidth:tableView.frame.size.width
		                                                hasAvatar:YES
		                                              sideButtons:hasSideButtons
		                                                timestamp:hasTimestamp
		                                                   footer:hasFooter];
	}
	
//	DDLogInfo(@"cellHeight for row(%lu) = %f", (unsigned long)tableRow, cellHeight);
	
	[cellHeightCache setObject:@(cellHeight) forKey:messageId];
	return cellHeight;
}


- (void)scrollToBottomAnimated:(BOOL)animated
{
	DDLogAutoTrace();
	
	NSInteger numTableRows = [tableView numberOfRowsInSection:0];
	if (numTableRows == 0) return;
	
	CGFloat contentHeight = tableView.contentSize.height;
	
	if (contentHeight == 0)
	{
		if (AppConstants.isIOS8OrLater)
		{
			// If the contentHeight is zero, this generally means this method is getting invoked from viewWillAppear.
			// In that situation, the tableView knows about its rowCount, but hasn't start laying out its subviews yet,
			// so it still reports a zero contentHeight.
			//
			// This method should be called after the tableView has had a chance to lay itself out.
			// That is, anytime in or after viewDidLayoutSubviews.
			
			return;
		}
		else
		{
			// Need to find a reliable hook on iOS 7, like there is on iOS 8.
			// For now we just force the issue, and power on through.
			
			[tableView reloadData];
			contentHeight = tableView.contentSize.height;
		}
	}
	
  	// Some historical context:
	// We've done a lot of debugging surrounding this code, and here's what we've found:
	//
	// 1. If this method is executed prior to viewDidLayoutSubviews, then the tableView knows its rowCount,
	//    but hasn't had a chance to layout its view/subviews. So it reports a contentHeight of zero.
	//    Meaning this method can't effectively do its job.
	//    Keep in mind the usual method invocation order when the view is being loaded:
	//    - viewDidLoad
	//    - viewWillAppear
	//    - viewDidLayoutSubviews
	//    - viewDidAppear
	//
	// 2. If this method is invoked BEFORE viewDidLayoutSubviews, then we have to add a bunch of workaround code.
	//    In particular, we used to have code that would also add the statusBarHeight & navigationBarHeight
	//    to the contentOffset.y, but only if being invoked from viewDidLoad. Plus we added code to force
	//    reload the tableView if its contentHeight was zero, but its rowCount was non-zero.
	//    Long story short, a bunch of hacks that didn't really address the root cause of the problem.
	
	UIEdgeInsets tableViewInsets = tableView.contentInset;
	
//	DDLogOrange(@"numTableRows=%lu, contentHeight=%.0f, contentInset=%@",
//	            (unsigned long)numTableRows, contentHeight, NSStringFromUIEdgeInsets(tableViewInsets));

	CGPoint contentOffset;
	contentOffset.x = 0;
	contentOffset.y = 0;
	
	// How to think about contentOffset.y :
	//
	// contentOffset.y-- : Taking your finger and pulling DOWN the tableView
	// contentOffset.y++ : Taking your finder and pushing UP the tableView
	
//	DDLogOrange(@"navigationBar.isTranslucent=%@",
//				(self.navigationController.navigationBar.isTranslucent ? @"YES" : @"NO"));
	
	if (self.navigationController.navigationBar.isTranslucent)
	{
		// If the nav bar is translucent, then the tableView frame actually starts underneath the nav bar.
		// That is, on the iPhone, the tableView frame will be at origin {0,0}, and so will the nav bar.
		//
		// So we want to take our finger, and pull the tableView DOWN,
		// so its out from underneath the nav bar.
		
		contentOffset.y -= tableViewInsets.top;
	}
	
//	DDLogOrange(@"contentOffset=%@", NSStringFromCGPoint(contentOffset));
	
	// Now the contentHeight (the sum of every single message cell) may be much larger than the tableHeight.
	// If that's the case, we want to take our finger and push the tableView UP.
	//
	// How far do we want to push it up?
	// Well think for a moment only of the visible tableHeight.
	// The portion of the tableView not obstructed by the nav bar or inputView.
	// We would want to push up whatever the different is between the contentHeight and visibleTableHeight.
	
	CGFloat fullTableHeight = tableView.frame.size.height;
	CGFloat visibleTableHeight = fullTableHeight;
	
	if (self.navigationController.navigationBar.isTranslucent)
		visibleTableHeight -= tableViewInsets.top;
	
	visibleTableHeight -= tableViewInsets.bottom;
	
//	DDLogOrange(@"fullTableHeight=%.0f, visibleTableHeight=%.0f", fullTableHeight, visibleTableHeight);
	
	if (contentHeight > visibleTableHeight)
		contentOffset.y += (contentHeight - visibleTableHeight);
	
//	DDLogOrange(@"contentOffset=%@", NSStringFromCGPoint(contentOffset));
	
	[tableView setContentOffset:contentOffset animated:animated];
	
//	[tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(numTableRows-1) inSection:0]
//	                 atScrollPosition:UITableViewScrollPositionBottom
//	                         animated:animated];    
}

- (void)updateTableViewContentInset
{
	DDLogAutoTrace();
	
	CGRect keyboardFrameInView = self.view.keyboardFrameInView;
	
	CGFloat keyboardOffset = self.view.frame.size.height - keyboardFrameInView.origin.y;
	keyboardOffset = MAX(0.0F, keyboardOffset);
	
	CGFloat inputViewHeight = inputView.frame.size.height;
	
	UIEdgeInsets insets = tableView.contentInset;
	insets.bottom = keyboardOffset + inputViewHeight;
	
	tableView.contentInset = insets;
	tableView.scrollIndicatorInsets = insets;
	
	CGFloat contentHeight = tableView.contentSize.height;
	CGFloat tableHeight = tableView.frame.size.height;
	
	if (contentHeight > tableHeight)
	{
		DDLogPurple(@"keyboardOffset=%.0f, inputViewHeight=%.0f, contentInset=%@",
		            keyboardOffset, inputViewHeight, NSStringFromUIEdgeInsets(insets));
		
		CGPoint contentOffset;
		contentOffset.x = 0;
		contentOffset.y = contentHeight - tableHeight - insets.top + insets.bottom;
		
		if (contentOffset.y < 0)
			contentOffset.y = 0;
		
		[tableView setContentOffset:contentOffset animated:YES];
		
	//	CGPoint contentOffset = tableView.contentOffset;
	//	contentOffset.x = 0;
	//	contentOffset.y += (inputViewHeight - lastInputViewHeight);// + inputView.frame.size.height;
	//
	//	[tableView setContentOffset:contentOffset animated:YES];
	}
//	lastInputViewHeight = inputViewHeight;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark MessagesInputView Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Called with a YES when autoGrowTextView is firstResponder (has keyboard), OR has some text in it.
 * Otherwise called with a NO if it resignsFirstResponder (loses keyboard) AND has no text.
 *
 * In other words, active means it appears the user is preparing to send a message.
 * This is an indicator to do things such as spin up GPS (if needed).
**/
- (void)inputViewIsActive:(BOOL)isActive
{
	DDLogAutoTrace();
	
	if (isActive && conversation.tracking)
	{
		[[GeoTracking sharedInstance] beginTracking];
	}
	
	if (isActive)
	{
		// Check for any changes to the user (or if they changed devices)
		[self refreshRemoteUserWebInfo];
	}
}

/**
 * Invoked when the text changes within the autoGrowTextField.
**/
- (void)inputViewTextChanged
{
	DDLogAutoTrace();
//	[self updateTableViewContentInset];
}

/**
 * Invoked upon completion of the inputView frame size animation.
**/
- (void)inputViewSizeChanged
{
	DDLogAutoTrace();
	[self updateTableViewContentInset];
}

- (void)inputViewWillTemporarilyLoseFirstResponder
{
	DDLogAutoTrace();
	skipScrollToBottom = YES;
}
- (void)inputViewDidTemporarilyLoseFirstResponder
{
	DDLogAutoTrace();
	skipScrollToBottom = NO;
}

/**
 * Invoked when the sendButton is tapped.
 * This method need only concern itself with sending the given message.
 * The inputView handles clearing the autoGrowTextField, and other UI stuff.
**/
- (void)sendButtonTappedWithText:(NSString *)text
{
	DDLogAutoTrace();
	
	if (STDatabaseManager.currentUser == nil)
		return;
	
	Siren *siren = [Siren new];
	siren.message = [NSString emojizedStringWithString:text];
	
	if (conversation.isNewMessage)
	{
		MessageStream *messageStream = [MessageStreamManager messageStreamForUser:STDatabaseManager.currentUser];
		NSString *tempConversationId = conversationId;
		
		NSArray *recipients = [recipientDict allKeys];
		if (recipients.count == 1)
		{
			XMPPJID *jid = [recipients objectAtIndex:0];
			
			[messageStream sendSiren:siren
			                   toJID:jid
			                withPush:YES
			                   badge:YES
			           createMessage:YES
			              completion:^(NSString *aMessageId, NSString *aConversationId)
			{
				if (AppConstants.isIPhone)
					[self setConversationId:aConversationId];
				else
					STAppDelegate.conversationViewController.selectedConversationId = aConversationId;
				
				[STAppDelegate.conversationViewController deleteConversation:tempConversationId];
			}];
		}
		else if (recipients.count > 1)
		{
			XMPPJIDSet *jidSet = [XMPPJIDSet setWithJids:recipients];
			
			[messageStream sendSiren:siren
			                toJidSet:jidSet
			                withPush:YES
			                   badge:YES
			           createMessage:YES
			              completion:^(NSString *aMessageId, NSString *aConversationId)
			{
				if (AppConstants.isIPhone)
					[self setConversationId:aConversationId];
				else
					STAppDelegate.conversationViewController.selectedConversationId = aConversationId;
				
				[STAppDelegate.conversationViewController deleteConversation:tempConversationId];
			}];
		}
	}
	else // if (conversation.isNewMessage == NO)
	{
		MessageStream *messageStream = [MessageStreamManager messageStreamForUser:STDatabaseManager.currentUser];
		
		[messageStream sendSiren:siren
		       forConversationID:conversationId
		                withPush:YES
		                   badge:YES
		           createMessage:YES
		              completion:NULL];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark TextView menu
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * These methods are invoked by the STInteractiveTextView class (tempTextView).
 *
 * The STInteractiveTextView allows us to keep the keyboard visible while displaying a UIMenuController,
 * and the class forwards all UIMenuController methods to us for processing.
 **/

- (BOOL)textView:(UITextView *)sender canPerformAction:(SEL)action {
	return [self menuCanPerformAction:action];
}

- (void)textView:(UITextView *)textView menuActionCopy:(id)sender {
	[self menuActionCopy:sender];
}

- (void)textView:(UITextView *)textView menuActionBurn:(id)sender {
	[self menuActionBurn:sender];
}

- (void)textView:(UITextView *)textView menuActionClear:(id)sender {
	[self menuActionClear:sender];
}

- (void)textView:(UITextView *)textView menuActionMore:(id)sender {
	[self menuActionMore:sender];
}

- (void)textView:(UITextView *)textView menuActionOther:(id)sender {
	[self menuActionOther:sender];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITableView
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSInteger)numberOfSectionsInTableView:(UITableView *)sender
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)sender numberOfRowsInSection:(NSInteger)section
{
	return [mappings numberOfItemsInGroup:conversationId];
}

- (CGFloat)tableView:(UITableView *)sender heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	STMessage *message = [self messageAtIndex:indexPath.row];
	
	return [self cellHeightForMessage:message atTableRow:indexPath.row];
}

- (UITableViewCell *)tableView:(UITableView *)sender cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	// Fetch message
	STMessage *message = [self messageAtIndex:indexPath.row];
	Siren *siren = message.siren;
	
	// Optional fetch of scloud object
//	STSCloud *scl = [self scloudForMessage:message];
	
	// Fetch userInfo
	NSDictionary *userInfo = nil;
	if (message.isOutgoing)
	{
		userInfo = [userInfoDict objectForKey:localJID.bare];
	}
	else
	{
		userInfo = [userInfoDict objectForKey:[message.from bare]];
        
        
/////////
/* 
 It is possible that in a multicast conversation you might see a jid that you dont have in your list.
this code is a workaround to a bug that I suspect occurs when you delete a user from your database and
the convesation multicastSet is missing a user.  we need to create a psudo userinfo block 
        --vinnie
 */
        
        if(!userInfo)
        {
            userInfo = @{ @"displayName" : message.from.user,
                          @"bubbleColor" :theme.otherBubbleColor,
                          @"userId" : @"not a real userID",
                          };
            
        }
        
/////////
	}
	
	// Fetch cell
	
	NSString *reuseIdentifier = NSStringFromClass([self class]);
	STBubbleTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier ];

	cell.delegate = self;
	//
	// STEP 0 - Theme colors & finalization
	//
	// do this earlier than before so the buttons and more get themed
	cell.isOutgoing = message.isOutgoing;

	cell.theme = theme;
	
	
	//
	// STEP 1 - Timestamp, Name, Text & Foooter
	//
	
	if ([self hasTimestampForMessage:message atTableRow:indexPath.row]) // shared code with cellHeight calculation
	{
		cell.timestampLabel.text = [self timestampForMessage:message];
		[cell.timestampLabel sizeToFit];
	}
	
	if ([self hasNameForMessage:message]) // shared code with cellHeight calculation
	{
		NSString *displayName = [userInfo objectForKey:@"displayName"];
		if (displayName == nil)
			displayName = @"";
		
		cell.nameLabel.text = displayName;
	}
	
	if (message.isStatusMessage)
    {
		// Status Message
		
		NSDictionary* statusMessage = message.statusMessage;
		NSString *statusString = [self statusMessageLine:statusMessage];
		UIImage *statusImage = nil;
		
		if ([statusMessage objectForKey:@"keyState"])
		{
			SCimpState scimpState = (SCimpState)[[statusMessage objectForKey:@"keyState"] intValue];
			switch (scimpState)
			{
				case kSCimpState_Commit: {
					statusImage = key_1;
					break;
				}
				case kSCimpState_DH1: {
					statusImage = key_2;
					break;
				}
				case kSCimpState_DH2: {
					statusImage = key_3;
					break;
				}
				default: break;
			}
		}
        else if([statusMessage objectForKey:@"keyInfo"])
        {
			statusImage = key_4;
        }
        
        cell.statusImageView.image  = statusImage;
     	cell.textView.text = statusString;
        cell.textView.font = kBubbleCellStatusFont;
		
		NSString *dateString = [timeFormatter stringFromDate:message.timestamp];
        cell.footerLabel.text = [NSString stringWithFormat:@"%@", dateString];
	}
    else if(message.isSpecialMessage)
    {
        // typically something to do with threads
        
        cell.statusImageView.image = [info_circle maskWithColor: theme.appTintColor];
        
        cell.textView.text = message.specialMessageText;
        cell.textView.font = kBubbleCellStatusFont;
 
        
		if (message.needsReSend)
		{
			cell.footerLabel.text = NSLocalizedString(@"Not Delivered", @"Not Delivered");
		}
		else if (message.isOutgoing &&
		         message.rcvDate    &&
		         [message.uuid isEqualToString:conversation.mostRecentDeliveredMessageID])
		{
			NSString *dateString = [message.rcvDate whenString];
			cell.footerLabel.text = [NSString stringWithFormat:@"✓ Read: %@", dateString];
		}

    }
    else
	{
		// Normal Message
		
		cell.textView.text = (message.siren.message ? message.siren.message : @"");
        cell.textView.font = kBubbleCellTextFont;
		
		if (message.needsReSend)
		{
			cell.footerLabel.text = NSLocalizedString(@"Not Delivered", @"Not Delivered");
		}
		else if (message.isOutgoing &&
		         message.rcvDate    &&
		         [message.uuid isEqualToString:conversation.mostRecentDeliveredMessageID])
		{
			NSString *dateString = [message.rcvDate whenString];
			cell.footerLabel.text = [NSString stringWithFormat:@"✓ Read: %@", dateString];
		}
	}
	
	//
	// STEP 2 - Other basic properties
	//
	
	
	cell.canCopyContents = !message.siren.fyeo;
	
    cell.hasBurn = message.isShredable && ! (message.isStatusMessage || message.isSpecialMessage); // dont show burn for status messages
	cell.hasGeo = message.hasGeo;
	cell.isFYEO = message.siren.fyeo;
	
	cell.failure = message.needsReSend;
	cell.ignored = message.ignored;
	
	if (message.isOutgoing)
	{
		cell.pending = (message.sendDate == nil) && !(message.ignored  || message.needsReSend);
		cell.isPlainText = NO;
        cell.unplayed = NO;
  		
		cell.signature = kBubbleSignature_None;
	}
	else
	{
		cell.pending = NO;
		cell.isPlainText = message.siren.isPlainText;
		
		if (siren.signature)
		{
            if (message.isVerified)
			{
				cell.signature = showVerfiedMessageSigs ? kBubbleSignature_Verified : kBubbleSignature_None;
			}
			else
			{
				BOOL keyfound = [[message.signatureInfo objectForKey:kSigInfo_keyFound] boolValue];
				
				if (keyfound)
					cell.signature = kBubbleSignature_Corrupt;
				else
					cell.signature = kBubbleSignature_KeyNotFound;
			}
		}
		else
		{
			cell.signature = kBubbleSignature_None;
		}
	}
   
	//
	// STEP 3 - Media Image
	//
    //ST-928 03/20/15 - use new Siren accessor instead of local constant
     UIImage *msgImage = [message imageForThumbNailScaledToHeight:[UIImage maxSirenThumbnailHeightOrWidth]
                                            withHorizontalPadding:[self paddingForMessage:message]
                                                         annotate:YES
                                                     fromUserName:userInfo?[userInfo objectForKey:@"displayName"]:@""];

    cell.bubbleView.mediaImage = msgImage;
    
	//
	// STEP 4 - Progress HUD
	//
	
	if (message.needsUpload || message.needsDownload || message.needsEncrypting)
	{
		YapCollectionKey *identifier =
		  [[YapCollectionKey alloc] initWithCollection:conversationId key:message.uuid];
		
		NSDictionary *dict = [[SCloudManager sharedInstance] statusForIdentfier:identifier];
		NSString *status = [dict objectForKey:@"status"];
		
        MBProgressHUD *progressHUD = NULL;
        
        if(status)
        {
			progressHUD = [cell progressHudForConversationId:conversationId messageId:message.uuid];
 //           DDLogOrange(@"status: %@  %p", status, progressHUD );
        }
        
        if ([status isEqualToString:NOTIFICATION_SCLOUD_ENCRYPT_START])
		{
			progressHUD.mode = MBProgressHUDModeAnnularDeterminate;
			progressHUD.labelText = NSLocalizedString(@"Encrypting", @"Encrypting");
		
			BOOL animated = NO;
			[progressHUD show:animated];
		}
		else if ([status isEqualToString:NOTIFICATION_SCLOUD_ENCRYPT_PROGRESS])
		{
			NSNumber *progress = [dict objectForKey:@"progress"];
			
			progressHUD.mode = MBProgressHUDModeAnnularDeterminate;
			progressHUD.labelText = NSLocalizedString(@"Encrypt", @"Encrypt");
			progressHUD.progress = [progress floatValue];
			
			BOOL animated = NO;
			[progressHUD show:animated];
		}
 		else if ([status isEqualToString:NOTIFICATION_SCLOUD_ENCRYPT_COMPLETE])
		{
			
			progressHUD.mode = MBProgressHUDModeText;
			progressHUD.labelText = NSLocalizedString(@"Encrypted", @"Encrypted");
 
 		}
       
		else if ([status isEqualToString:NOTIFICATION_SCLOUD_BROKER_REQUEST])
		{
			progressHUD.mode = MBProgressHUDModeAnnularDeterminate;
			progressHUD.labelText = NSLocalizedString(@"Uploading", @"Uploading");
			
			BOOL animated = NO;
			[progressHUD show:animated];
		}
		else if ([status isEqualToString:NOTIFICATION_SCLOUD_UPLOAD_PROGRESS])
		{
			NSNumber *uploadProgress = [dict objectForKey:@"progress"];
			
			progressHUD.mode = MBProgressHUDModeAnnularDeterminate;
			progressHUD.labelText = NSLocalizedString(@"Uploading", @"Uploading");
			progressHUD.progress = [uploadProgress floatValue];
			
			BOOL animated = NO;
			[progressHUD show:animated];
		}
		else if ([status isEqualToString:NOTIFICATION_SCLOUD_DOWNLOAD_START])
		{
			progressHUD.mode = MBProgressHUDModeAnnularDeterminate;
			progressHUD.labelText = NSLocalizedString(@"Downloading", @"Downloading");
			
			BOOL animated = NO;
			[progressHUD show:animated];
		}
		else if ([status isEqualToString:NOTIFICATION_SCLOUD_DOWNLOAD_PROGRESS])
		{
			NSNumber *downloadProgress = [dict objectForKey:@"progress"];
			progressHUD.mode = MBProgressHUDModeAnnularDeterminate;
			progressHUD.labelText = NSLocalizedString(@"Downloading", @"Downloading");
			progressHUD.progress = [downloadProgress floatValue];
			
			BOOL animated = NO;
			[progressHUD show:animated];
		}
        
        else if ([status isEqualToString:NOTIFICATION_SCLOUD_GPS_START])
		{
			progressHUD.mode = MBProgressHUDModeIndeterminate;
			progressHUD.labelText = NSLocalizedString(@"GPS",@"GPS");
			
			BOOL animated = YES;
			[progressHUD show:animated];
		}
        
        else if ([status isEqualToString:NOTIFICATION_SCLOUD_GPS_COMPLETE])
		{
			BOOL animated = YES;
			[progressHUD hide:animated afterDelay:0.0];
		}

		else
		{
			// Make sure progressHUD is added to cell (if there is an existing progressHUD for this message)
			(void)[cell existingProgressHudForConversationId:conversationId messageId:message.uuid];
		}
	}
	else
	{
		// Make sure progressHUD is added to cell (if there is an existing progressHUD for this message)
		(void)[cell existingProgressHudForConversationId:conversationId messageId:message.uuid];
	}
    
	//
	// STEP 5 - Message avatar
	//
	
	NSString *messageId = message.uuid;
	if (![cell.messageId isEqualToString:messageId])
	{
		cell.messageId = messageId;
	}
	
	NSString *userId = [userInfo objectForKey:@"userId"];
	NSNumber *abRecordID = [userInfo objectForKey:@"abRecordID"];
	BOOL isSilentTextInfoUser =  [[userInfo objectForKey:@"isSilentTextInfoUser"] boolValue];
    BOOL isOCAUser =  [[userInfo objectForKey:@"isOCAUser"] boolValue];
    
	AvatarUsage avatarUsage = message.isOutgoing ? kAvatarUsage_Outgoing : kAvatarUsage_Incoming;
	
	if (isSilentTextInfoUser)
	{
		cell.avatarImageView.image =
		  [[AvatarManager sharedInstance] defaultSilentTextInfoUserAvatarWithDiameter:kAvatarDiameter];
    }
	else if (isOCAUser)
	{
		cell.avatarImageView.image =
		  [[AvatarManager sharedInstance] defaultOCAUserAvatarWithDiameter:kAvatarDiameter];
	}
	else if (userId)
	{
		UIImage *cachedAvatar = [[AvatarManager sharedInstance] cachedAvatarForUserId:userId
		                                                                 withDiameter:kAvatarDiameter
		                                                                        theme:theme
		                                                                        usage:avatarUsage
		                                                              defaultFallback:YES];
		cell.avatarImageView.image = cachedAvatar;
		
		[[AvatarManager sharedInstance] fetchAvatarForUserId:userId
		                                        withDiameter:kAvatarDiameter
		                                               theme:theme
		                                               usage:avatarUsage
		                                     completionBlock:^(UIImage *avatar)
		{
			// Make sure the cell is still being used for the messageId.
			// During scrolling, the cell may have been recycled.
			if ([cell.messageId isEqualToString:messageId])
			{
                cell.avatarImageView.image = avatar;
			}
		}];
	}
	else if (abRecordID)
	{
		UIImage *cachedAvatar = [[AvatarManager sharedInstance] cachedAvatarForABRecordID:[abRecordID intValue]
		                                                                     withDiameter:kAvatarDiameter
		                                                                            theme:theme
		                                                                            usage:avatarUsage
		                                                                  defaultFallback:YES];
		cell.avatarImageView.image = cachedAvatar;
		
		[[AvatarManager sharedInstance] fetchAvatarForABRecordID:[abRecordID intValue]
		                                            withDiameter:kAvatarDiameter
		                                                   theme:theme
		                                                   usage:avatarUsage
		                                         completionBlock:^(UIImage *avatar)
		{
			// Make sure the cell is still being used for the messageId.
			// During scrolling, the cell may have been recycled.
			if ([cell.messageId isEqualToString:messageId])
			{
                cell.avatarImageView.image = avatar;
			}
		}];
	}
 	
	//
	// STEP 6 - Update message (if needed) (async)
	//
	// - mark as read
	// - set shredDate
	//
	
    
    if(! message.isOutgoing
       && UTTypeConformsTo( (__bridge CFStringRef)siren.mediaType, kUTTypeAudio))
    {
        
        // for now we mark this cell as ignored.   // we need to add some UI for unread messages
        cell.unplayed = !message.isRead;
    }
 	else
    {
        cell.unplayed = NO;
        [self markMessageAsRead:message];
    }
    
 	//
	// STEP 8 -  Apply theme overrides (if needed)
	//
    
	
	UIColor *bubbleColor = [userInfo objectForKey:@"bubbleColor"];
	if (bubbleColor)
		cell.bubbleView.bubbleColor = bubbleColor;
	[cell refreshColorsFromTheme];

	
	//
	// STEP 9 - Validation & Layout
	//
	
	NSAssert([self hasTimestampForMessage:message atTableRow:indexPath.row]
	      == [cell hasTimestamp],
	         @"Mismatch: cellHeight calculation code doesn't match cell config code (timestamp)");
	
	NSAssert([self hasNameForMessage:message]
	      == [cell hasName],
	         @"Mismatch: cellHeight calculation code doesn't match cell config code (name)");
	
	NSAssert([self hasFooterForMessage:message]
	      == [cell hasFooter],
	         @"Mismatch: cellHeight calculation code doesn't match cell config code (footer)");
	
	NSAssert([self hasSideButtonsForMessage:message]
	      == [cell hasSideButtons],
	         @"Mismatch: cellHeight calculation code doesn't match cell config code (side buttons)");
	
	[cell setNeedsLayout];
	return cell;
}



- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
	DDLogAutoTrace();
	
	return NO;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	DDLogAutoTrace();
	
	return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	DDLogAutoTrace();
	
	return;
}

/**
 * These are delegate methods of STInteractiveTableView.
 *
 * STInteractiveTableView is a simple subclass of UITableView designed to allow the tableView
 * to become firstResponder, as required by the UIMenuController class.
 * It simply forwards variou UIMenuController methods to the tableView's delegate.
**/

- (BOOL)tableView:(UITableView *)sender canPerformAction:(SEL)action {
	return [self menuCanPerformAction:action];
}

- (void)tableView:(UITableView *)tableView menuActionCopy:(id)sender {
	[self menuActionCopy:sender];
}

- (void)tableView:(UITableView *)tableView menuActionBurn:(id)sender {
	[self menuActionBurn:sender];
}

- (void)tableView:(UITableView *)tableView menuActionClear:(id)sender {
	[self menuActionClear:sender];
}


- (void)tableView:(UITableView *)tableView menuActionMore:(id)sender {
	[self menuActionMore:sender];
}

- (void)tableView:(UITableView *)tableView menuActionOther:(id)sender {
	[self menuActionOther:sender];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark STBubbleTableViewCell Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)tappedImageOfCell:(STBubbleTableViewCell *)cell
{
	NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
	
	STMessage *message = [self messageAtIndex:indexPath.row];
	Siren *siren = message.siren;
	
	if (!siren) {
        return;
	}
    if (siren.isMapCoordinate)
    {
		[self tappedGeo:cell];
		return;
    }
	if (!siren.cloudLocator) {
		return;
	}
    
	STSCloud *scl = [self scloudForMessage:message];
	if (!scl)
	{
        STImage *thumbnail = [self thumbnailForMessage:message];
		UIImage *image = thumbnail ? thumbnail.image : NULL;

		MessageStream *ms = [MessageStreamManager messageStreamForUser:STDatabaseManager.currentUser];
		
		__weak typeof(self) weakSelf = self;
		[ms downloadSCloudForMessage:message
		               withThumbnail:image
		             completionBlock:^(STMessage *msg, NSError *error)
		{
		#pragma clang diagnostic push
		#pragma clang diagnostic warning "-Wimplicit-retain-self"
			
			NSAssert([NSThread isMainThread], @"Completion blocks are expected to be on main thread");
			
			[weakSelf tappedImageContinue:msg.uuid withError:error];
			
		#pragma clang diagnostic pop
		}];
	}
	else
	{
		[self tappedImageContinue:message.uuid withError:nil];
	}
}

/**ET 11/19/14
 * This method continues handling a tap on an image in an STBubbleTableViewCell, begun
 * in the tappedImageOfCell: method, for image and video decryption and display in a
 * QLPreviewController.
 *
 * At the top of this method, the siren.mediaType is evaluated; for types kUTTypeVCard,
 * kUTTypeAudio, and "public.calendar-event", the showSCloudForMessage:forCell: method
 * is invoked for specific handling and this method returns. 
 *
 * Otherwise, this method configures views for an animation in which the image in the
 * tapped tableCell appears to expand out into a full screen QLPreviewController view,
 * and then shrink back to the tableCell image upon dismissal.
 *
 * The transition takes a screen snapshot before making the SCloudPreviewer
 * call. This is to mask the "jump" which happens in the messages tableView
 * at the beginnning of the transition animation. When the QLPreviewController
 * is presented the system hides the status bar which pulls up the underlying
 * views up, making a "jump". The screenshot image hides the jump. The image
 * is a subview of a temporary window-sized view containing the dimming view
 * and the "spinnerView", which is a view with the frame of the image in the
 * tableView cell which was tapped.
 * 
 * The spinnerView itself is transparent and is passed to SCloudPreviewer
 * in which is set the "decrypting" HUD. In SCloudPreviewer, the
 * previewControllerWillDismiss: delegte callback sets the temporary view
 * (with its subviews) to invisible.
 * 
 * The preview controller view appears to expand to full screen from the image in
 * the tableCell (the spinnerView frame), and then to shrink back to the
 * cell image when dismissed.
 * 
 * NOTE: there was considerable work done to handle iPad/iPhone device
 * formats, as well as support for iOS7/iOS8 versions, each with their
 * own handling. There was difficulty in getting the "spinnerView" frame,
 * which frames the start of the preview controller view as it zooms,
 * to update to the appropriate position if the device is rotated while
 * the preview controller fills the screen.
 * 
 * A "shortcut" was taken for iOS7 handling, which is to present the
 * preview controller from, and dismiss the controller view to, screen
 * center in the animation.
 * 
 * With this commit, there remains the edge case in which (iOS8) the
 * preview controller is presented in one orientation, device rotated,
 * then dismissed in the other orientation. The origination rect and
 * completion rect are off. Finally it was discovered that this is
 * because SWRevealController (current vendor version used is 1.1.2)
 * does not correctly handle subview layout for rotations until 2.0.
 *
 * @param cell The cell whose image was tapped by the user, passed by
 * tappedImageOfCell:.
 */
- (void)tappedImageContinue:(NSString *)messageID withError:(NSError *)error
{
	// Bug fix:
	//
	// We can NOT pass the cell to this method.
	// Cells move around and get recycled.
	// By the time this method hits, the cell may be associated with a completely different message.
	//
	// The only safe way to do this is to pass a messageID & conversationID.
	// We can always work backwards from here to figure out everything else.
	
	NSIndexPath *indexPath = [self indexPathForMessageId:messageID];
	if (indexPath == nil) {
		return;
	}
	
	STMessage *message = [self messageAtIndex:indexPath.row];
	STBubbleTableViewCell *cell = (STBubbleTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath];
	
	if (error)
	{
		NSString *title = NSLocalizedString(@"Unable to download",
		                                    @"Error message - failed to download scloud");
	
		NSString *errorString = nil;
		if (error.code == NSURLErrorFileDoesNotExist)
		{
			errorString = NSLocalizedString(@"File not available. Please ask sender to upload again",
			                                @"File not available");
		}
		else
		{
			errorString = error.localizedDescription;
		}
	
		[YRDropdownView showDropdownInView:cell.contentView
		                             title:title
		                            detail:errorString
		                             image:nil // [UIImage imageNamed:@"ignored"]
		                   backgroundImage:[UIImage imageNamed:@"bg-yellow"]
		                          animated:YES
		                         hideAfter:3.0];
	
		return;
	}
	
	
	Siren *siren = message.siren;
	if (!siren || !siren.cloudLocator) {
		return;
	}
	
//	DDLogOrange(@"tappedImageOfCell %@", siren.mediaType);
	
	CGPoint savedOffset = self.tableView.contentOffset;
	[inputView.autoGrowTextView resignFirstResponder];
	
	// Can we handle this ourselves ?
	if (UTTypeConformsTo( (__bridge CFStringRef)siren.mediaType, kUTTypeVCard) ||
	    UTTypeConformsTo( (__bridge CFStringRef)siren.mediaType, kUTTypeAudio) ||
	    UTTypeConformsTo( (__bridge CFStringRef)siren.mediaType, (__bridge CFStringRef)@"public.calendar-event"))
	{
		[self showSCloudForMessage:message forCell:cell];
		return; // Done
	}
	
	// Otherwise we need to involve previewer.
    restoreOffset.point = self.tableView.contentOffset;
    restoreOffset.valid = YES;

    //ET 02/10/15
	if (scloudPreviewer == nil)
	{
        scloudPreviewer = [[SCloudPreviewer alloc] init];
//		SCloudPreviewer *scloudPreviewer = [[SCloudPreviewer alloc] init];
	}
	
    
	dispatch_async(dispatch_get_main_queue(), ^{
		
//        UIViewController *presentingVC = nil;
//        if (AppConstants.isIPad) 
//            presentingVC = STAppDelegate.window.rootViewController; // revealController
//        else
//            presentingVC = STAppDelegate.mainViewController;        // conversationVC
        UIViewController *presentingVC = [self previewerPresentingController];
        UIView *frontView = presentingVC.view;
        
        // Get a snapshot view of the current screen. This masks the "jump": 
        // When the preview controller is presented in full screen, the status bar animates up,
        // pulling the underlying view(s) up. This makes the messageView table appear to "jump" up.
        // So we get a snapshot of the screen before the "jump" and make that the background view.
        // SCloudPreviewer makes the view invisible in its QLPreview willDismiss callback, in case
        // there's been a rotation. The view is removed in the SCloud call completion block below.
        CGRect screenBounds = [UIScreen mainScreen].bounds;
                
//        UIView *snapshotView = nil;
        if (snapshotView)
            snapshotView = nil;
        
        if (AppConstants.isLessThanIOS8)
        {
            snapshotView = [[UIView alloc] initWithFrame:screenBounds];
        }
        else 
        {
            snapshotView = [self.view.window resizableSnapshotViewFromRect:screenBounds 
                                                   afterScreenUpdates:NO 
                                                        withCapInsets:UIEdgeInsetsZero];
        }
        
        // NOTE: snapshotView should be added as the frontView subview here, 
        // before adding constraints below
        [frontView addSubview:snapshotView];
        
        if (AppConstants.isLessThanIOS8)
        {        
            UIImage *img = [STAppDelegate screenShot];
            UIImageView *imgView = [[UIImageView alloc] initWithImage:img];
            imgView.frame = screenBounds;
            [imgView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
            imgView.translatesAutoresizingMaskIntoConstraints = YES;
            [snapshotView addSubview:imgView];
        }
        
        // Add a dimming view subview
        UIView *dimView = [[UIView alloc] initWithFrame:screenBounds];
        dimView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
        //TEST
//        dimView.backgroundColor = [UIColor clearColor];
        [dimView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        dimView.translatesAutoresizingMaskIntoConstraints = YES;
        [snapshotView addSubview:dimView];
        
        // Get the cell bubble image frame, converted to the frontView coordinate space
        CGRect spinnerFrame = [cell convertRect:cell.bubbleView.frame toView:frontView];
        
        // The "spinnerView" is the "inView" param to the displaySCloud:... method.
        // The displaySCloud method centers the "decrypting" HUD in this view.
        // This view becomes a transparent frame around the cell image with the HUD in center.
        // Tracking the frame for pre-iOS 8 rotations becomes problematic, so we just punt and
        // present/dismiss the preview controller view from window center.
        UIView *spinnerView = [[UIView alloc] initWithFrame:spinnerFrame];
        spinnerView.backgroundColor = [UIColor clearColor];
        //TEST
//        spinnerView.backgroundColor = [UIColor colorWithRed:192.0/255.0 green:0 blue:0 alpha:0.4];
        [snapshotView addSubview:spinnerView];

        if (AppConstants.isLessThanIOS8)
        {
            spinnerView.center = snapshotView.center;
            [spinnerView setAutoresizingMask:   
             UIViewAutoresizingFlexibleTopMargin    | 
             UIViewAutoresizingFlexibleRightMargin  |
             UIViewAutoresizingFlexibleBottomMargin |
             UIViewAutoresizingFlexibleLeftMargin
             ];
            spinnerView.translatesAutoresizingMaskIntoConstraints = YES;
        }
        else 
        {
            // Center offsets
//            CGFloat centerOffsetX = spinnerView.center.x - newView.center.x;
            CGFloat centerOffsetY = spinnerView.center.y - snapshotView.center.y;
            CGFloat sWidth  = CGRectGetWidth(spinnerView.frame);
            CGFloat sHeight = CGRectGetHeight(spinnerView.frame);
            CGFloat newViewW = CGRectGetWidth(snapshotView.frame);
            CGFloat spinnerTrailingEdge = CGRectGetMaxX(spinnerView.frame);
            CGFloat trailingX = -(newViewW - spinnerTrailingEdge);
            
            NSArray *constraints = @[];
            // SpinnerView Trailing X
            NSLayoutConstraint *sTrailing = [NSLayoutConstraint constraintWithItem:spinnerView
                                                                         attribute:NSLayoutAttributeRight
                                                                         relatedBy:NSLayoutRelationEqual 
                                                                            toItem:snapshotView
                                                                         attribute:NSLayoutAttributeRight
                                                                        multiplier:1.0 
                                                                          constant:trailingX];
            sTrailing.priority = 1000;
            [snapshotView addConstraints:@[sTrailing]];
//            // SpinnerView Center X
//            NSLayoutConstraint *xCenter = [NSLayoutConstraint constraintWithItem:spinnerView
//                                                                       attribute:NSLayoutAttributeCenterX
//                                                                       relatedBy:NSLayoutRelationEqual 
//                                                                          toItem:newView
//                                                                       attribute:NSLayoutAttributeCenterX
//                                                                      multiplier:1.0 
//                                                                        constant:centerOffsetX];
//            // Make the priority lower than the x trailing constraint
//            xCenter.priority = 751;
//            [newView addConstraints:@[xCenter]];
            
            // SpinnerView Center Y
            constraints = @[[NSLayoutConstraint constraintWithItem:spinnerView
                                                         attribute:NSLayoutAttributeCenterY
                                                         relatedBy:NSLayoutRelationEqual 
                                                            toItem:snapshotView
                                                         attribute:NSLayoutAttributeCenterY
                                                        multiplier:1.0 
                                                          constant:centerOffsetY]];
            [snapshotView addConstraints:constraints];
            spinnerView.translatesAutoresizingMaskIntoConstraints = NO;
            // SpinnerView Width
            constraints = @[[NSLayoutConstraint constraintWithItem:spinnerView
                                                         attribute:NSLayoutAttributeWidth
                                                         relatedBy:NSLayoutRelationEqual 
                                                            toItem:nil
                                                         attribute:NSLayoutAttributeNotAnAttribute
                                                        multiplier:1.0 
                                                          constant:sWidth]];
            [snapshotView addConstraints:constraints];
            // SpinnerView Height
            constraints = @[[NSLayoutConstraint constraintWithItem:spinnerView
                                                         attribute:NSLayoutAttributeHeight
                                                         relatedBy:NSLayoutRelationEqual 
                                                            toItem:nil
                                                         attribute:NSLayoutAttributeNotAnAttribute
                                                        multiplier:1.0 
                                                          constant:sHeight]];
            [snapshotView addConstraints:constraints];

            spinnerView.translatesAutoresizingMaskIntoConstraints = NO;            
        }
        
        [snapshotView layoutIfNeeded];

        // Pin newView top/bottom to frontView
        NSArray *vConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[newView]|"
                                                                        options:0
                                                                        metrics:nil
                                                                          views:@{ @"newView":snapshotView }];
        // Pin newView sides to frontView
        NSArray *hConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[newView]|"
                                                                        options:0
                                                                        metrics:nil
                                                                          views:@{ @"newView":snapshotView }];
        snapshotView.translatesAutoresizingMaskIntoConstraints = NO;
        [frontView addConstraints:vConstraints];
        [frontView addConstraints:hConstraints];
        [frontView layoutIfNeeded];

        __weak typeof (self) weakSelf = self;
        
        [scloudPreviewer displaySCloud:siren.cloudLocator
                                  fyeo:siren.fyeo
                             fromGroup:(siren.fyeo ? NULL : conversationId)
                        withController:presentingVC
                                inView:spinnerView //itemImgView
                       completionBlock:^(NSError *error)
        {
            
            // Remove the tmp presentation view
            // Note that ScloudPreview sets view.alpha = 0 in the PreviewVC willDismiss callback
            [snapshotView removeFromSuperview];
            
            __strong typeof (weakSelf) strongSelf = weakSelf;
            strongSelf.tableView.contentOffset = savedOffset;
            
            if (error)
            {
                NSString *title = NSLocalizedString(@"Unable to display", @"error message");
                
                [YRDropdownView showDropdownInView:cell.contentView
                                             title:title
                                            detail:error.localizedDescription
                                             image:NULL //[UIImage imageNamed:@"ignored"]
                                   backgroundImage:[UIImage imageNamed:@"bg-yellow"]
                                          animated:YES
                                         hideAfter:3];
            }
            else
            {
                DDLogBrown(@"refresh here");
                // refresh the view here.
            }
        }]; // end displaySCloud:fyeo:fromGroup:withController:inView:completionBlock:
        
	}); // end dispatch_async(dispatch_get_main_queue(), ^{
}

//ET 02/19/15
// ST-918 - abstract accessor for scloud presenting vc - used in several places:
// new is the appWillResignActive to handle background/launch image
- (UIViewController *)previewerPresentingController 
{
    UIViewController *presentingVC = nil;
    if (AppConstants.isIPad) 
        presentingVC = STAppDelegate.window.rootViewController; // revealController
    else
        presentingVC = STAppDelegate.mainViewController;        // conversationVC
    
    return presentingVC;
}

- (void)tappedImageOfAvatar:(STBubbleTableViewCell *)cell
{
	NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
	
	STMessage *message = [self messageAtIndex:indexPath.row];
	XMPPJID *jid = message.from;
	
    // ignore clicks to silentTextInfoUser
	if (IsSTInfoJID(jid)) {
		return;
	}
	
	__block STUser *user = nil;
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		user = [[DatabaseManager sharedInstance] findUserWithJID:jid transaction:transaction];
	}];
	
    UserInfoVC *userInfoVC = nil;
    
    if (user)
    {
        userInfoVC = [[UserInfoVC alloc] initWithUser:user];
        userInfoVC.conversation = conversation;
    }
    else
    {
        userInfoVC = [[UserInfoVC alloc] initWithConversation:conversation];
    }
    
	[self showViewController:userInfoVC
	                fromRect:cell.avatarImageView.frame
	                  inView:cell.contentView
	              forMessage:message // <- important
	             hidesNavBar:NO
	         arrowDirections:UIPopoverArrowDirectionAny];
}

- (void) tappedGeo: (STBubbleTableViewCell *) cell
{
	NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
	
	STMessage *message = [self messageAtIndex:indexPath.row];
    
    if(message.siren.isMapCoordinate && !message.hasThumbnail)
    {
        // if this is a map coordinate and we havent done the thumbnail, attempt to update the thumbnail with map info
        [message updateThumbNailWithMapImage];
        
    }
    
//    
//    NSString *userKey = [message.from bare];
//    NSDictionary *userInfo = [userInfoDict objectForKey:userKey];

 	NSError *jsonError;
	
	NSDictionary *locInfo = [NSJSONSerialization
							 JSONObjectWithData:[message.siren.location dataUsingEncoding:NSUTF8StringEncoding]
							 options:0 error:&jsonError];
	
	if (jsonError==nil){
		
         CLLocation* location  = [[CLLocation alloc] initWithDictionary:locInfo];
        
        NSDateFormatter *formatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterMediumStyle
                                                                       timeStyle:NSDateFormatterShortStyle];

        NSString * displayName = [self displayNameForMessage: message];
        
        SCMapPin *pin  = [[SCMapPin alloc] initWithLocation: location
                                                      title: displayName
                                                   subTitle: [formatter stringFromDate:location.timestamp]
                                                     image : NULL
                                                       uuid: NULL] ;
  		[inputView.autoGrowTextView resignFirstResponder];
        [self saveTableRestoreOffset];
        
        NewGeoViewController *geovc = [NewGeoViewController.alloc initWithNibName:@"NewGeoViewController" bundle:nil];
        geovc.title = [NSString stringWithFormat:NSLocalizedString(@"%@ location", @"%@ location"),
                       displayName];
        
        geovc.mapPins = @[pin];
   		
		[self pushViewControllerAndFixNavBar: geovc animated: YES];
		
    }
 }

- (void)tappedBurn:(STBubbleTableViewCell *)cell
{
	NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
	STMessage *message = [self messageAtIndex:indexPath.row];
	NSString* messageString = NULL;
    
    if(message.shredDate)
    {
        messageString =  [NSString stringWithFormat:@" %@: %@ ", NSLocalizedString(@"Burn",@"Burn"), message.shredDate.whenString];
    }
    else
    {
       messageString =  [NSString stringWithFormat: NSLocalizedString(@"Burn %@ after read",@"Burn %@ after read"),
                         [NSString timeIntervalToStringWithInterval: message.siren.shredAfter]];
    }
    
 	UIColor* bgColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.20 alpha:0.75];
	
	[self popupString:messageString withColor:bgColor atCell:cell];
	
}

- (void)tappedFailure:(STBubbleTableViewCell *)cell
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    STMessage *message = [self messageAtIndex:indexPath.row];
    
    selectedMessageID = message.uuid;
	
    BOOL isMulticast = conversation.isMulticast;
    
    NSString *actionTitle = @"";
	if (message.errorInfo)
	{
		NSError *msgError = message.errorInfo;
		
		if ([msgError.domain isEqualToString:@"urn:ietf:params:xml:ns:xmpp-stanzas"] && msgError.code == 503) {
			actionTitle = NSLocalizedString(@"Service Temporarily Unavailable", @"Service Temporarily Unavailable");
		}
		else {
			actionTitle = [NSString stringWithFormat:@"\n%@", message.errorInfo.localizedDescription ];
		}
	}
	else
	{
		actionTitle = isMulticast ? NSLS_COMMON_UNABLE_TO_DECRYPT_MULTI : NSLS_COMMON_UNABLE_TO_DECRYPT;
	}
        
    //ET 10/16/14 OHActionSheet udpate
    [OHActionSheet showFromRect:cell.failureButton.frame 
                       sourceVC:self 
                         inView:cell.contentView
                 arrowDirection:UIPopoverArrowDirectionAny
                          title:actionTitle
              cancelButtonTitle:NSLS_COMMON_CANCEL
         destructiveButtonTitle:NSLS_COMMON_TRY_AGAIN
              otherButtonTitles:@[NSLS_COMMON_IGNORE]
                     completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
	{
		NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
		
		if ([choice isEqualToString:NSLS_COMMON_TRY_AGAIN])
		{
			if (isMulticast)
			{
				[self resendFailedMessage:YES];
			}
			else
			{
				[self resendFailedMessage:YES];
			}
		}
		else if ([choice isEqualToString:NSLS_COMMON_IGNORE])
		{
			[self resendFailedMessage:NO];
		}
	}];
}


- (void) tappedUnplayed: (STBubbleTableViewCell *) cell
{
    [self tappedImageOfCell:cell];
}


- (void) tappedPending: (STBubbleTableViewCell *) cell
{
	NSString* messageString = NSLocalizedString(@"This message is awaiting transmission", @"This message is awaiting transmission");
	UIColor* bgColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.20 alpha:0.75];
	
	[self popupString:messageString withColor:bgColor atCell:cell];
	
}

- (void) tappedIgnored:(STBubbleTableViewCell *)cell
{
	NSString* messageString =   NSLocalizedString(@"The message was not transmitted", @"The message was not transmitted");
	UIColor* bgColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.20 alpha:0.75];
	
	[self popupString:messageString withColor:bgColor atCell:cell];
}


- (void) tappedIsPlainText:(STBubbleTableViewCell *)cell
{
	NSString* messageString =  NSLocalizedString(@"This message was not sent encrypted",@"This message was not sent encrypted");
	UIColor* bgColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.20 alpha:0.75];
	
	[self popupString:messageString withColor:bgColor atCell:cell];
}

- (void) tappedFYEO: (STBubbleTableViewCell *) cell
{
	NSString* messageString =  NSLocalizedString(@"Do not forward this message", @"Do not forward this message");
	UIColor* bgColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.20 alpha:0.75];
	
	[self popupString:messageString withColor:bgColor atCell:cell];
	
}

- (void)tappedSignature:(STBubbleTableViewCell *)cell signatureState:(BubbleSignature_State)signature
{
	NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
	
	STMessage *message = [self messageAtIndex:indexPath.row];
  
	NSString *displayName = [self displayNameForMessage:message];
	NSString *messageString = nil;
	UIColor *bgColor = nil;
	
	if (signature == kBubbleSignature_Verified)
	{
		bgColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.20 alpha:0.75];
		
		NSString *frmt = NSLocalizedString(@"Signature from %@ Valid", @"Signature from %@ Valid");
		messageString = [NSString stringWithFormat:frmt, displayName];
	}
	else if (signature == kBubbleSignature_KeyNotFound)
	{
		bgColor = [UIColor colorWithRed:0.80 green:0.80 blue:0.0 alpha:0.75];
		
		NSString *frmt = NSLocalizedString(@"Signature from %@ could not be verified", @"Signature from %@ could not be verified");
		messageString = [NSString stringWithFormat:frmt, displayName];
		
		// We could write some code here to download the latest key from the sender
		// and check if the message hash will verify.
	}
	else if (signature == kBubbleSignature_Corrupt)
	{
		bgColor = [UIColor redColor];
		
		NSString *frmt = NSLocalizedString(@"Signature from %@ Invalid", @"Signature from %@ Invalid");
		messageString = [NSString stringWithFormat:frmt, displayName];
	}
	
	if (messageString)
	{
		[self popupString:messageString withColor:bgColor atCell:cell];
	}
}

- (void)tappedStatusIcon:(STBubbleTableViewCell *)cell
{
  	NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
	
	STMessage *message = [self messageAtIndex:indexPath.row];
    NSDictionary* statusMessage = message.statusMessage;
  
    if(!statusMessage) return;
    
    if([statusMessage objectForKey:@"keyInfo"])
    {
        NSDictionary* keyInfo = [statusMessage objectForKey:@"keyInfo"];
        NSString *SAS = [keyInfo objectForKey:kSCimpInfoSAS];
	//	SCimpMethod scimpMethod = [[keyInfo objectForKey:kSCIMPMethod] unsignedIntValue];

        NSString* messageString = @"";
        UIColor* bgColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.20 alpha:0.75];

        messageString = [NSString stringWithFormat:
						 NSLocalizedString(@"SAS: %@", @"SAS: %@"),  SAS];

        [self popupString:messageString withColor:bgColor atCell:cell];

    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UIGestureRecognizer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
        shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
	return YES;
}

- (void)deselectSelectedCell
{
	DDLogAutoTrace();
	
	NSIndexPath *selectedIndexPath = [tableView indexPathForSelectedRow];
	if (selectedIndexPath)
	{
		[tableView deselectRowAtIndexPath:selectedIndexPath animated:NO];
		[menuController setMenuVisible:NO animated:YES];
	}
}

- (void)tapOnCell
{
	DDLogAutoTrace();
	
	[self deselectSelectedCell];
}

- (void)handleSingleTap:(UIGestureRecognizer *)gestureRecognizer
{
	DDLogAutoTrace();
	
//	if ((!topView.hidden) && ![inputView.autoGrowTextView isFirstResponder]) {
//		[inputView.autoGrowTextView becomeFirstResponder];
//		return;
//	}
	
	if (ignoreSingleTap) {
		ignoreSingleTap = NO;
	}
	else {
		[self deselectSelectedCell];
	}
}

- (void)handleLongPress:(UIGestureRecognizer *)gestureRecognizer
{
	DDLogAutoTrace();
	
	if (gestureRecognizer.state == UIGestureRecognizerStateBegan)
	{
		CGPoint tableViewTouchPoint = [gestureRecognizer locationInView:tableView];
		[self deselectSelectedCell];

		NSIndexPath *indexPath = [tableView indexPathForRowAtPoint:tableViewTouchPoint];
		if (indexPath)
		{
			STBubbleTableViewCell *cell = (STBubbleTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
			
			if (![cell.bubbleView isKindOfClass:[STBubbleView class]])
			{
				DDLogError(@"Unhandled tableViewCell class");
				return;
			}

			CGPoint cellTouchPoint = [gestureRecognizer locationInView:cell];
			
			BOOL shouldSelect = NO;
			STMessage *message = [self messageAtIndex:indexPath.row];
			
			if (message.isStatusMessage || message.isSpecialMessage)
			{
				shouldSelect = CGRectContainsPoint(cell.statusView.frame, cellTouchPoint);
			}
			else
			{
				shouldSelect = CGRectContainsPoint(cell.bubbleView.frame, cellTouchPoint);
			}
			
			if (shouldSelect)
			{
				[tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
				[self displayMenuControllerForCell:cell atIndexPath:indexPath];
			}
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIMenuController
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)displayMenuControllerForCell:(STBubbleTableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
	DDLogAutoTrace();
	
	STMessage *message = [self messageAtIndex:indexPath.row];
	
	// Calculate frame for menu controller
	
	CGRect rowFrame = [tableView rectForRowAtIndexPath:indexPath];
	
	CGRect bubbleFrameInTableView;
	
	if (message.isStatusMessage || message.isSpecialMessage)
		bubbleFrameInTableView = cell.statusView.frame;
	else
		bubbleFrameInTableView = cell.bubbleView.frame;
	
	bubbleFrameInTableView.origin.x += rowFrame.origin.x;
	bubbleFrameInTableView.origin.y += rowFrame.origin.y;
	
	CGRect visibleTableFrame;
	visibleTableFrame.origin = tableView.contentOffset;
	visibleTableFrame.size = tableView.frame.size;
	
	CGRect menuFrame = CGRectIntersection(bubbleFrameInTableView, visibleTableFrame);
	
	// Figure out who should be firstResponder.
	//
	// If the text field is active, we need to tell it to only allow copy actions.
	// Otherwise it would typically also support paste, etc.
	//
	// If the text field isn't active, then we need to move focus to the table view.
	// This is because the menu will query the first responder to see what menu actions are possible.
	
	showingMenuController = YES;

	if ([inputView.autoGrowTextView isFirstResponder])
	{
		// Our tempTextView is a STInteractiveTextView instance.
		// The STInteractiveTextView class forwards various UIMenuController methods to us.
		//
		// @see textView:canPerformAction:
		// @see textViewMenuActionCopy:
		//
		// We could hack HPTextViewInteral to get the same result.
		// But that's open source code, so we generally try to avoid changing it if possible.
		
		[tempTextView becomeFirstResponder];
		
		// Little hack:
		//
		// For some reason, switching the firstResponder from the inputView to the tempTextView seems
		// to be a process that spans multiple runloop cycles. And this causes the menuController to to appear
		// and then immediately hide.
		//
		// I can't figure out a cleaner way to get around this issue.
		// So as a hack, I'm introducing a slight delay to allow the tempTextView to finish taking firstResponder.
		//
		// As always, others are encouraged to improve this code (and remove this hack)
		// if a better solution can be found.
		//
		// -RH
		
		double delayInSeconds = 0.02;
		dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
		dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
			
			[self displayMenuControllerForCell:cell atIndexPath:indexPath];
		});
		return;
	}
	else if (![tempTextView isFirstResponder])
	{
		[tableView becomeFirstResponder];
	}
	
	// Create and display menu controller
	
	UIMenuItem *burnItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Burn", @"Burn")
													  action:@selector(burn:)];
	
    UIMenuItem *moreItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"More…", @"More…")
                                                      action:@selector(more:)];
  
    UIMenuItem *clearItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Clear", @"Clear")
                                                      action:@selector(clear:)];
  
	menuController = [UIMenuController sharedMenuController];
    
    if(message.siren
       && UTTypeConformsTo( (__bridge CFStringRef)message.siren.mediaType, kUTTypeAudio))
    {
        
        if(message.siren.isVoicemail)
        {
            UIMenuItem *vmItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Call…", @"Call…")
                                                               action:@selector(other:)];
            
            [menuController setMenuItems:@[ burnItem,  clearItem, moreItem,  vmItem ]];
 
        }
        else
#if DEBUG
       {
        
        UIMenuItem *debugItem = [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"VoiceMail", @"VoiceMail")
                                                           action:@selector(other:)];
 
        [menuController setMenuItems:@[ burnItem,  clearItem,  moreItem, debugItem ]];

      }
      
#else
    
	[menuController setMenuItems:@[ burnItem,  clearItem,  moreItem ]];
#endif
    }
    else
        [menuController setMenuItems:@[ burnItem,  clearItem,  moreItem ]];
    
    
	[menuController setTargetRect:menuFrame inView:tableView];
	[menuController setMenuVisible:YES animated:YES];
	
	[NSNotificationCenter.defaultCenter addObserver:self
										   selector:@selector(willHideMenuController:)
											   name:UIMenuControllerWillHideMenuNotification
											 object:nil];
}

- (void)willHideMenuController:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	[NSNotificationCenter.defaultCenter removeObserver:self
												  name:UIMenuControllerWillHideMenuNotification
												object:nil];
	
	// Remove the custom menu items from the shared menuController.
	// If we don't do this then these menu items will appear for the inputView.
	
	[[UIMenuController sharedMenuController] setMenuItems:nil];
	
	// Unselect the cell, and update the cell's UI
	
	NSIndexPath *indexPath = [tableView indexPathForSelectedRow];
	if (indexPath)
	{
		[tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
	
	// Switch focus back to the inputView (if needed)
	
	if ([tempTextView isFirstResponder]) {
		[inputView.autoGrowTextView becomeFirstResponder];
	}
	showingMenuController = NO;
	
	// Users often dismiss the UIMenuController by tapping somewhere else in the tableView.
	// We want to ignore this tap, especially if processing it would mean dismissing the keyboard.
	
	ignoreSingleTap = YES;
	
	double delayInSeconds = 0.2;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
		
		if (ignoreSingleTap)
			ignoreSingleTap = NO;
	});
}

- (BOOL)menuCanPerformAction:(SEL)action
{
	STMessage *message = nil;
	
	NSIndexPath *indexPath = [tableView indexPathForSelectedRow];
	if (indexPath) {
		message = [self messageAtIndex:indexPath.row];
	}
	
	if (action == @selector(copy:) )
	{
		if (message.siren.fyeo)
			return NO;
		else
			return YES;
	}
    else if (action == @selector(more:))
	{
        return YES;
 	}
 
    else if(action == @selector(other:))
    {
        if(message.siren.isVoicemail)
        {
            return [self getPhoneState];

        }
        else
#if DEBUG
        return YES;
#else
        return NO;
#endif
    }
 
    else  if (action == @selector(clear:))
    {
#if ONLY_BURN_REMOTE_MESSAGES 
         return (message.isStatusMessage || message.isSpecialMessage);
#else
        return ((message.isStatusMessage || message.isSpecialMessage) || !message.isOutgoing);
#endif
        
        return ((message.isStatusMessage || message.isSpecialMessage) );
    }
	else if (action == @selector(burn:))
	{
#if ONLY_BURN_REMOTE_MESSAGES
            return (!(message.isStatusMessage || message.isSpecialMessage) );
#else
        	return (!(message.isStatusMessage || message.isSpecialMessage) && message.isOutgoing);
#endif
        
 	}
	
	return NO;
}

/**
 * Menu action is forwarded from STInteractiveTableView or STInteractiveTextView:
 *
 * @see tableView:menuActionCopy:
 * @see textView:menuActionCopy:
 **/
- (void)menuActionCopy:(id)sender
{
	NSIndexPath *indexPath = [tableView indexPathForSelectedRow];
	if (indexPath)
	{
		STBubbleTableViewCell *cell = (STBubbleTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
 
        STMessage *message = [self messageAtIndex:indexPath.row];
        Siren* siren = message.siren;
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
		NSMutableDictionary *items = [NSMutableDictionary dictionary];
        
        // if its a status message we can capture that better
        if(message.isStatusMessage)
        {
            NSDictionary* statusDict = message.statusMessage;
            if(statusDict)
            {
                NSDictionary* keyInfo = [statusDict objectForKey:@"keyInfo"];
                NSString *SAS = [keyInfo objectForKey:kSCimpInfoSAS];
                
                if(SAS)
                {
                    [items setValue:SAS forKey:(NSString *)kUTTypeUTF8PlainText];
                  }
                
            }
        }
        // capture the callerID number
        if(siren.callerIdNumber.length)
        {
            [items setValue:siren.callerIdNumber forKey:(NSString *)kUTTypeUTF8PlainText];
        }
    
        // capture the text
        if(siren.message.length)
        {
            [items setValue:siren.message forKey:(NSString *)kUTTypeUTF8PlainText];
        }
      
        // capture the thumbnail
        if (cell.bubbleView.mediaImage)
        {
            NSData *jpegData = UIImageJPEGRepresentation(cell.bubbleView.mediaImage, 1.0);
            [items setValue:jpegData forKey:(NSString *)kUTTypeJPEG];
        }
    		
		pasteboard.items = [NSArray arrayWithObject:items];
	}
}

/**
 * Menu action is burn from STInteractiveTableView or STInteractiveTextView:
 *
 * @see menuActionClear:
 * @see menuActionClear:
 **/

- (void)menuActionClear:(id)sender
{
	STMessage *msg = nil;
	
	NSIndexPath *indexPath = [tableView indexPathForSelectedRow];
	if (indexPath) {
		msg = [self messageAtIndex:indexPath.row];
	}
	
	// Note: "clear" is used for status messages.
	//
	// It is different from burning a message, because the STMessage is just a local item in the database
	// used to communicate keying progress information to the user via the UI.
	// So when we clear a message we don't have to worry about the burning it from the server,
	// or sending a SCimp message to initiate a burn on the remote side.
	//
	// Also, the implementation of clearMessage ensures we don't perform the burn animation.
	[self clearMessage:msg];
}


/**
 * Menu action is burn from STInteractiveTableView or STInteractiveTextView:
 *
 * @see tableView:menuActionBurn:
 * @see textView:menuActionBurn:
 **/
- (void)menuActionBurn:(id)sender
{
	STMessage *msg = nil;
	
	NSIndexPath *indexPath = [tableView indexPathForSelectedRow];
	if (indexPath) {
		msg = [self messageAtIndex:indexPath.row];
	}
	
    [self removeMessage:msg shouldBurnRemote:YES];
    
}

- (void)removeMessage:(STMessage *)msg shouldBurnRemote:(BOOL)shouldBurnRemote
{
  	if (msg == nil) return;
	
	MessageStream *ms = [MessageStreamManager messageStreamForUser:STDatabaseManager.currentUser];
	[ms burnMessage:msg.uuid inConversation:msg.conversationId];
}



/**
 * Menu action is forwarded from STInteractiveTableView or STInteractiveTextView:
 *
 * @see menuActionMore:
 * @see menuActionMore:
**/
- (void)menuActionMore:(id)sender
{
	STMessage *msg = nil;
	
	NSIndexPath *indexPath = [tableView indexPathForSelectedRow];
	if (indexPath) {
		msg = [self messageAtIndex:indexPath.row];
	}
	
	if (msg == nil) return;
	
    STBubbleTableViewCell *cell = (STBubbleTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
    
    moreMenuViewController  = [[MoreMenuViewController alloc] initWithDelegate:self message:msg];
    
	if (AppConstants.isIPhone)
		moreMenuViewController.isInPopover = NO;
	else
		moreMenuViewController.isInPopover = YES;
    
	[self showViewController:moreMenuViewController
	                fromRect:cell.bubbleView.frame
	                  inView:cell.contentView
	              forMessage:nil
	             hidesNavBar:NO
	         arrowDirections:UIPopoverArrowDirectionAny];
}


/**
 * Menu action is forwarded from STInteractiveTableView or STInteractiveTextView:
 *
 * @see menuActionOther:
 * @see menuActionOther:
 **/

// this is used for misc long press


- (void)menuActionOther:(id)sender
{
	STMessage *msg = nil;
	
	NSIndexPath *indexPath = [tableView indexPathForSelectedRow];
	if (indexPath) {
		msg = [self messageAtIndex:indexPath.row];
	}
	
	if (msg == nil) return;
	   
    if(msg.siren.isVoicemail)
    {
        NSString* callback = msg.siren.callerIdUser?msg.siren.callerIdUser:msg.siren.callerIdNumber;
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"silentphone:%@", callback]];
        
        [[UIApplication sharedApplication] openURL:url];
        return;
    }
    
#if DEBUG
    if(msg.siren
       && UTTypeConformsTo( (__bridge CFStringRef)msg.siren.mediaType, kUTTypeAudio))
    {
              /// using this to simulate voicemail messages
            [self sendFakeVMMessageWithSiren:msg.siren];
     
    }
#endif
 

}



- (void)sendFakeVMMessageWithSiren:(Siren *)msgSiren
{
	DDLogAutoTrace();
	
    // create siren voicemail message
    
    STLocalUser *currentUser = STDatabaseManager.currentUser;
    
    Siren *voiceSiren           = [Siren new];
    voiceSiren.mediaType        = msgSiren.mediaType;
    voiceSiren.mimeType         = msgSiren.mimeType;
    voiceSiren.duration         = msgSiren.duration;
    voiceSiren.cloudKey         = msgSiren.cloudKey;
    voiceSiren.cloudLocator     = msgSiren.cloudLocator;
    voiceSiren.recordedTime     = [NSDate date];
    voiceSiren.callerIdName     = currentUser.displayName;
    
    if(currentUser.spNumbers)
    {
        NSArray* spNumbers = currentUser.spNumbers;
        NSString* number = NULL;
        if(spNumbers.count)
        {
            id firstItem = [spNumbers firstObject];
            if([firstItem isKindOfClass: [NSDictionary class]])
            {
                number = [firstItem  objectForKey:@"number"];
            }
            else  if([firstItem isKindOfClass: [NSString class]])
            {
                number = firstItem;
            }
        }
        if(number)
            voiceSiren.callerIdNumber = number;
	}
	
	if (voiceSiren.callerIdNumber == nil)
		voiceSiren.callerIdUser = currentUser.jid.user;

	DDLogRed(@"voicemail packet: %@ ", voiceSiren.json);
	
	MessageStream *messageStream = [MessageStreamManager messageStreamForUser:currentUser];
    
	[messageStream sendPubSiren:voiceSiren
	          forConversationID:conversationId
	                   withPush:YES
	                      badge:YES
	              createMessage:YES
	                 completion:NULL];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIScrollView
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)willDecelerate
{
	if (!willDecelerate) {
		[self maybeShiftRange];
	}
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	[self maybeShiftRange];
}

- (void)scrollViewDidScrollToTop:(UIScrollView *)scrollView
{
	[self maybeShiftRange];
}

- (void)maybeShiftRange
{
	displayTableViewAdditions = NO;
	if (lastRangeChange)
	{
		NSTimeInterval elapsed = [lastRangeChange timeIntervalSinceNow];
		if (elapsed >= -0.1)
			return;
	}
	
	CGFloat offsetFromTop = tableView.contentOffset.y + tableView.contentInset.top;
	CGFloat offsetFromBottom = tableView.contentSize.height - tableView.contentOffset.y - tableView.bounds.size.height;
	
	//	DDLogPink(@"offsetFromTop(%.1f) offsetFromBottom(%.1f)", offsetFromTop, offsetFromBottom);
	
	CGFloat topTrigger = 5.0F;
	CGFloat bottomTrigger = 5.0F;
	
	if ((offsetFromTop < topTrigger) && (offsetFromTop >= 0.0))
	{
		YapDatabaseViewRangePosition rangePosition = [mappings rangePositionForGroup:conversationId];
		
		//		DDLogMagenta(@"rangePosition: range(%d, %d) insets(%d, %d)",
		//					 rangePosition.range.location, rangePosition.range.length,
		//					 rangePosition.insets.top, rangePosition.insets.bottom);
		
		if (rangePosition.offsetFromBeginning > 0)
		{
			if (rangePosition.length < 150)
			{
				lastRangeChange = [NSDate date];
				[self increaseRangeLengthBy:MIN(50, rangePosition.offsetFromBeginning)];
			}
			else
			{
				lastRangeChange = [NSDate date];
				[self increaseRangeOffsetBy:MIN(50, rangePosition.offsetFromBeginning)];
			}
		}
	}
	else if ((offsetFromBottom < bottomTrigger) && (offsetFromBottom >= 0.0))
	{
		YapDatabaseViewRangePosition rangePosition = [mappings rangePositionForGroup:conversationId];
		
		if (rangePosition.offsetFromEnd > 0)
		{
			lastRangeChange = [NSDate date];
			[self decreaseRangeOffsetBy:MIN(50, rangePosition.offsetFromEnd)];
		}
	}
	displayTableViewAdditions = YES;
}

- (void)increaseRangeLengthBy:(NSUInteger)count
{
	DDLogTrace(@"increaseRangeLengthBy: %ld", (long)count);
	
	CGPoint contentOffset = tableView.contentOffset;
	CGFloat contentOffsetDiff = 0;
	
	// Calculate the contentOffset diff:
	// - the timestamp in cell at index 0 (will be at index count) may get removed
	
	if ([mappings numberOfItemsInGroup:conversationId] > 0)
	{
		STMessage *message = [self messageAtIndex:0];
		CGFloat cellHeight = [self cellHeightForMessage:message atTableRow:0];
		
		contentOffsetDiff -= cellHeight;
		[cellHeightCache removeObjectForKey:message.uuid];
	}
	
	// Update the rangeOptions & mappings
	
	YapDatabaseViewRangeOptions *rangeOptions = [mappings rangeOptionsForGroup:conversationId];
	rangeOptions = [rangeOptions copyWithNewLength:(rangeOptions.length + count)];
	
	[mappings setRangeOptions:rangeOptions forGroup:conversationId];
	
	// Calculate the contentOffset diff:
	// - cells that were added to the tableView
	
	for (NSUInteger i = 0; i < count; i++)
	{
		STMessage *message = [self messageAtIndex:i];
		CGFloat cellHeight = [self cellHeightForMessage:message atTableRow:i];
		
		contentOffsetDiff += cellHeight;
	}
	
	// Calculate the contentOffset diff:
	// - the timestamp in cell that was at index 0 (now at index count) may have been removed
	
	if ([mappings numberOfItemsInGroup:conversationId] > count)
	{
		STMessage *message = [self messageAtIndex:count];
		CGFloat cellHeight = [self cellHeightForMessage:message atTableRow:count];
		
		contentOffsetDiff += cellHeight;
	}
	
	// Update the tableView and update the contentOffset to match what was previously displayed
	
	contentOffset.y += contentOffsetDiff;
	
	[tableView reloadData];
	tableView.contentOffset = contentOffset;
	[tableView flashScrollIndicators];
}

- (void)increaseRangeOffsetBy:(NSUInteger)count
{
	DDLogTrace(@"increaseRangeOffsetBy: %ld", (long)count);
	
	CGPoint contentOffset = tableView.contentOffset;
	CGFloat contentOffsetDiff = 0;
	
	// Calculate the contentOffset diff:
	// - the timestamp in cell at index 0 (will be at index count) may get removed
	
	if ([mappings numberOfItemsInGroup:conversationId] > 0)
	{
		STMessage *message = [self messageAtIndex:0];
		CGFloat cellHeight = [self cellHeightForMessage:message atTableRow:0];
		
		contentOffsetDiff -= cellHeight;
		[cellHeightCache removeObjectForKey:message.uuid];
	}
	
	// Update the rangeOptions & mappings
	
	YapDatabaseViewRangeOptions *rangeOptions = [mappings rangeOptionsForGroup:conversationId];
	rangeOptions = [rangeOptions copyWithNewOffset:(rangeOptions.offset + count)];
	
	[mappings setRangeOptions:rangeOptions forGroup:conversationId];
	
	// Calculate the contentOffset diff:
	// - cells that were added to the tableView
	
	for (NSUInteger i = 0; i < count; i++)
	{
		STMessage *message = [self messageAtIndex:i];
		CGFloat cellHeight = [self cellHeightForMessage:message atTableRow:i];
		
		contentOffsetDiff += cellHeight;
	}
	
	// Calculate the contentOffset diff:
	// - the timestamp in cell that was at index 0 (now at index count) may have been removed
	
	if ([mappings numberOfItemsInGroup:conversationId] > count)
	{
		STMessage *message = [self messageAtIndex:count];
		CGFloat cellHeight = [self cellHeightForMessage:message atTableRow:count];
		
		contentOffsetDiff += cellHeight;
	}
	
	// Update the tableView and update the contentOffset to match what was previously displayed
	
	contentOffset.y += contentOffsetDiff;
	
	[tableView reloadData];
	tableView.contentOffset = contentOffset;
	[tableView flashScrollIndicators];
}

- (void)decreaseRangeOffsetBy:(NSUInteger)count
{
	DDLogTrace(@"decreaseRangeOffsetBy: %ld", (long)count);
	
	CGPoint contentOffset = tableView.contentOffset;
	CGFloat contentOffsetDiff = 0;
	
	// Calculate the contentOffset diff:
	// - cells that will be removed from the tableView
	
	for (NSUInteger i = 0; i < count; i++)
	{
		STMessage *message = [self messageAtIndex:i];
		CGFloat cellHeight = [self cellHeightForMessage:message atTableRow:i];
		
		contentOffsetDiff -= cellHeight;
		[cellHeightCache removeObjectForKey:message.uuid];
	}
	
	// Calculate the contentOffset diff:
	// - the timestamp in cell that was at index count (will be at index 0) may get added
	
	if ([mappings numberOfItemsInGroup:conversationId] > count)
	{
		STMessage *message = [self messageAtIndex:count];
		CGFloat cellHeight = [self cellHeightForMessage:message atTableRow:count];
		
		contentOffsetDiff -= cellHeight;
		[cellHeightCache removeObjectForKey:message.uuid];
	}
	
	// Update the rangeOptions & mappings
	
	YapDatabaseViewRangeOptions *rangeOptions = [mappings rangeOptionsForGroup:conversationId];
	rangeOptions = [rangeOptions copyWithNewOffset:(rangeOptions.offset - count)];
	
	[mappings setRangeOptions:rangeOptions forGroup:conversationId];
	
	// Calculate the contentOffset diff:
	// - the timestamp in cell that is at index 0 (was at index count) may have been added
	
	if ([mappings numberOfItemsInGroup:conversationId] > 0)
	{
		STMessage *message = [self messageAtIndex:0];
		CGFloat cellHeight = [self cellHeightForMessage:message atTableRow:0];
		
		contentOffsetDiff += cellHeight;
	}
	
	// Update the tableView and update the contentOffset to match what was previously displayed
	
	contentOffset.y += contentOffsetDiff;
	
	[tableView reloadData];
	tableView.contentOffset = contentOffset;
	[tableView flashScrollIndicators];
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)sender
{
	[chatOptionsView suspendFading:NO];
	
    // ET
    // dealloc the popoverController
//	popoverController = nil;
	
	if (temporarilyHidingPopover)
	{
		// we'll need to redisplay the popover (in the same place) momentarily
	}
	else
	{
        // ET moved from above
        popoverController = nil;
        
		popoverFromRect = CGRectZero;
		popoverInView = nil;
		popoverMessageId = nil;
		popoverArrowDirections = UIPopoverArrowDirectionUnknown;
//		popoverContentViewController = nil;
		
		// dealloc anything inside it we may have been retaining
        moreMenuViewController = nil;
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Message Utilities
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)markMessageAsRead:(STMessage *)message
{
	DDLogAutoTrace();
	
	BOOL shouldSetShreDate = NO;
	if (message.siren.shredAfter && !message.shredDate)
	{
		if (message.isOutgoing)
		{
			if (message.sendDate && !message.needsReSend)
			{
				shouldSetShreDate = YES;
			}
		}
		else
		{
			shouldSetShreDate = YES;
		}
	}
    
	if (!message.isStatusMessage && (!message.isRead || shouldSetShreDate))
	{
		// message seen, we need to update the shred date and isREad
		
		STLocalUser *currentUserSnapshot = STDatabaseManager.currentUser; // snapshot
		__block Siren *replySiren = NULL;
		
		YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
		[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
			
			id obj = [transaction objectForKey:message.uuid inCollection:message.conversationId];
			
			// Guard code (could be of type STXMPPElement)
			
			if (![obj isKindOfClass:[STMessage class]])
			{
				return;// from_block
			}
			
			STMessage *updatedMessage = [(STMessage *)obj copy];
			
			if (!updatedMessage.isRead)
			{
				// Get the latest version of the conversation object (most recent commit)
				STConversation *msgConversation = [transaction objectForKey:message.conversationId
				                                               inCollection:message.userId];
				
				if (msgConversation.sendReceipts &&
					updatedMessage.siren.requestReceipt &&
					!updatedMessage.isSpecialMessage &&
				    !updatedMessage.isOutgoing)
				{
					replySiren = [Siren new];
					replySiren.receivedID = updatedMessage.uuid;
					replySiren.receivedTime = [NSDate date];
				}
				
				updatedMessage.isRead = YES;
			}
			
            
            // for outgoing messages, start the shred timer after the message was sent.
			if (shouldSetShreDate)
            {
                updatedMessage.shredDate = [[NSDate date] dateByAddingTimeInterval:updatedMessage.siren.shredAfter];
            }
			
			[transaction setObject:updatedMessage
							forKey:updatedMessage.uuid
					  inCollection:updatedMessage.conversationId];
			
			// We changed the unread count,
			// so we also "touch" the conversation in the order view.
			//
			// This will have the effect of marking that appropriate row in the conversation tableView
			// as updated so that it gets automatically redrawn.
			
			[[transaction ext:Ext_View_Order] touchRowForKey:updatedMessage.conversationId
			                                    inCollection:updatedMessage.userId];
			
		} completionBlock:^{
			
			if (replySiren)
			{
				MessageStream *ms = [MessageStreamManager messageStreamForUser:currentUserSnapshot];
				
				[ms sendSiren:replySiren forConversationID:message.conversationId
				                                  withPush:NO
				                                     badge:NO
				                             createMessage:NO
				                                completion:NULL];
			}
		}];
	}
	
}


- (void)resendMessage:(STMessage *)message
{
	DDLogAutoTrace();
	
	if (message == nil) return;
	
	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
	[rwDatabaseConnection asyncReadWithBlock:^(YapDatabaseReadTransaction *transaction){
		
		STConversation *msgConversation = [transaction objectForKey:message.conversationId inCollection:message.userId];
		Siren *msgSiren = [message.siren copy];
		msgSiren.signature = NULL;
        msgSiren.location = NULL;
        msgSiren.shredAfter = 0;
        
		if (msgConversation.tracking)
		{
			// insert tracking info
			CLLocation *location =  [[GeoTracking sharedInstance] currentLocation];
			if (location)
			{
				NSString *locString = [location JSONString];
				msgSiren.location = locString;
			}
		}
		
		if (msgConversation.shouldBurn && msgConversation.shredAfter > 0) {
			msgSiren.shredAfter = msgConversation.shredAfter;
		}
		
		STUser *user = [transaction objectForKey:message.userId inCollection:kSCCollection_STUsers];
		if (user.isLocal)
		{
			MessageStream *messageStream = [MessageStreamManager messageStreamForUser:(STLocalUser *)user];
			
			[messageStream sendSiren:msgSiren
			       forConversationID:message.conversationId
		                    withPush:YES
		                       badge:YES
		               createMessage:YES
		                  completion:NULL];
		}
	}];
}


- (void)clearMessage:(STMessage *)message
{
  	if (message == nil) return;
	
	if (![message isKindOfClass:[STMessage class]])
	{
		DDLogWarn(@"Improper class passed to method %@ : %@", THIS_METHOD, [message class]);
		return;
	}
	
	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
        
		// Fetch the scloud item (if it exists) and delete the corresponding files from disk
		NSString *scloudId = message.siren.cloudLocator;
		if (scloudId)
		{
			STSCloud *scl = [transaction objectForKey:scloudId inCollection:kSCCollection_STSCloud];
			
			[scl removeFromCache];
		}
		
		// Remove the message
		[transaction removeObjectForKey:message.uuid inCollection:message.conversationId];
		
		// Notes:
		//
		// - The relationship extension will automatically remove the thumbnail (if needed)
		// - The relationship extension will automatically remove the scloud item (if needed)
		// - The hooks extension will automatically update the conversation item (if needed)
		
		// Add a flag for this transaction specifying that we cleared the message.
		// This is used by the UI to avoid the usual burn animation when it sees a message was deleted.
		NSDictionary *transactionExtendedInfo = @{
		    kTransactionExtendedInfo_ClearedMessageIds: [NSSet setWithObject:message.uuid] };
		transaction.yapDatabaseModifiedNotificationCustomObject = transactionExtendedInfo;
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Sending Current location
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


- (void)sendMyCurrentLocation
{
    DDLogAutoTrace();
	
    if (![[GeoTracking sharedInstance] allowsTracking]) return;
    
	__block CLLocation *currentLocation = NULL;
	
    BOOL wasTracking = conversation.tracking;
    if (!wasTracking) {
        [[GeoTracking sharedInstance] beginTracking];
    }
	
	STLocalUser *currentUser = STDatabaseManager.currentUser;
	
    MBProgressHUD* HUD = [[MBProgressHUD alloc] initWithView:self.view];
    HUD.mode = MBProgressHUDModeIndeterminate;
	
	[self.view addSubview:HUD];
    [HUD showAnimated:YES whileExecutingBlock:^{
        
        currentLocation = [[GeoTracking sharedInstance] currentLocation];
        
        if(!currentLocation)
        {
            HUD.mode = MBProgressHUDModeIndeterminate;
            HUD.labelText = NSLocalizedString(@"Waiting for GPS", @"Waiting for GPS");
        }
        
        while(!currentLocation)
        {
            currentLocation = [[GeoTracking sharedInstance] currentLocation];
        }
    
     
     } completionBlock:^{
		 
		[HUD removeFromSuperview];
		 
		Siren *siren = [Siren new];
		siren.isMapCoordinate = YES;
		siren.requiresLocation = YES;
   
		MessageStream *messageStream = [MessageStreamManager messageStreamForUser:currentUser];
		[messageStream sendSiren:siren
		       forConversationID:conversation.uuid
		                withPush:YES
		                   badge:YES
		           createMessage:YES
		              completion:NULL];
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Media Upload
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)queueAssetWithInfo:(NSDictionary *)assetInfo
{
	DDLogAutoTrace();
	
	MessageStream *ms = [MessageStreamManager messageStreamForUser:STDatabaseManager.currentUser];

 	if (conversation.isNewMessage)
	{
		NSString *tempConversationId = conversationId;
		
		NSArray *recipients = [recipientDict allKeys];
		if (recipients.count == 1)
		{
			XMPPJID *jid = [recipients objectAtIndex:0];
			
			[ms sendAssetWithInfo:assetInfo
			                toJID:jid
			           completion:^(NSString *messageId, NSString *newConversationId)
			{
				if (AppConstants.isIPhone)
					[self setConversationId:newConversationId];
				else
					STAppDelegate.conversationViewController.selectedConversationId = newConversationId;
				
				[STAppDelegate.conversationViewController deleteConversation:tempConversationId];
			}];
			
			inputView.typedText = @"";
		}
		else if (recipients.count > 1)
		{
			XMPPJIDSet *jidSet = [XMPPJIDSet setWithJids:recipients];
			
			[ms sendAssetWithInfo:assetInfo
			             toJidSet:jidSet
			           completion:^(NSString *messageId, NSString *newConversationId)
			{
				if (AppConstants.isIPhone)
					[self setConversationId:newConversationId];
				else
					STAppDelegate.conversationViewController.selectedConversationId = newConversationId;
				
				[STAppDelegate.conversationViewController deleteConversation:tempConversationId];
			}];
		}
	}
	else
	{
		[ms sendAssetWithInfo:assetInfo forConversationID:conversationId completion:NULL];
	}
}

- (void)sendScloudWithSiren:(Siren *)siren
{
	DDLogAutoTrace();
	
	MessageStream *ms = [MessageStreamManager messageStreamForUser:STDatabaseManager.currentUser];
	
	if (conversation.isNewMessage)
	{
		NSString *tempConversationId = conversationId;
		
		NSArray *recipients = [recipientDict allKeys];
		if (recipients.count == 1)
		{
			XMPPJID *jid = [recipients objectAtIndex:0];
			
			[ms sendScloudWithSiren:siren
			                  toJID:jid
			             completion:^(NSString *messageId, NSString *newConversationId)
			{
				if (AppConstants.isIPhone)
					[self setConversationId:newConversationId];
				else
					STAppDelegate.conversationViewController.selectedConversationId = newConversationId;
				
				[STAppDelegate.conversationViewController deleteConversation:tempConversationId];
			}];
			
			inputView.typedText = @"";
		}
		else if (recipients.count > 1)
		{
			XMPPJIDSet *jidSet = [XMPPJIDSet setWithJids:recipients];
			
			[ms sendScloudWithSiren:siren
			               toJidSet:jidSet
			             completion:^(NSString *messageId, NSString *newConversationId)
			{
				
				if (AppConstants.isIPhone)
					[self setConversationId:newConversationId];
				else
					STAppDelegate.conversationViewController.selectedConversationId = newConversationId;
				
				[STAppDelegate.conversationViewController deleteConversation:tempConversationId];
			}];
		}
	}
	else
	{
		[ms sendScloudWithSiren:siren forConversationID:conversationId completion:NULL];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - SCloudManagerNotification
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)scloudOperation:(NSNotification *)notification
{
	DDLogAutoTrace();
	
	NSDictionary *userInfo = notification.userInfo;
	
	YapCollectionKey *identifier = [userInfo objectForKey:@"identifier"];;
    
	NSString *opConversationId = identifier.collection;
	NSString *opMessageId = identifier.key;
 
	if (![conversationId isEqualToString:opConversationId])
	{
		// Doesn't apply to this conversation
		return;
	}
	
	__block NSUInteger row = 0;
	__block STMessage *message = nil;
	
	[databaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
		
		BOOL found = [[transaction ext:Ext_View_Order] getRow:&row
		                                              section:NULL
		                                               forKey:opMessageId
		                                         inCollection:opConversationId
		                                         withMappings:mappings];
		if (found)
		{
			message = [transaction objectForKey:opMessageId inCollection:opConversationId];
		}
	}];
	
	if (message == nil)
	{
		DDLogWarn(@"Cannot find message for scloudOperation notification");
		return;
	}
	
	NSString *status = [userInfo objectForKey:@"status"];
	NSError   *error = [userInfo objectForKey:@"error"];
	
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
	STBubbleTableViewCell *cell = (STBubbleTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
	
	if (cell)
	{
        MBProgressHUD *progressHUD = NULL;
      
         if(status)
        {
            progressHUD = [cell progressHudForConversationId:opConversationId messageId:opMessageId];
//            DDLogPink(@"status: %@  %p", status, progressHUD );
        }
        
        if ([status isEqualToString:NOTIFICATION_SCLOUD_ENCRYPT_START])
		{
 
			progressHUD.mode = MBProgressHUDModeAnnularDeterminate;
			progressHUD.labelText = NSLocalizedString(@"Encrypting", @"Encrypting");
			
			BOOL animated = NO;
			[progressHUD show:animated];
            
        }
		else if ([status isEqualToString:NOTIFICATION_SCLOUD_ENCRYPT_PROGRESS])
		{
             NSNumber *progress = [userInfo objectForKey:@"progress"];
	 		
			progressHUD.progress = [progress floatValue];
			
			BOOL animated = NO;
			[progressHUD show:animated];

		}
 		else if ([status isEqualToString:NOTIFICATION_SCLOUD_ENCRYPT_COMPLETE])
		{
            
			UIImage *image = [UIImage imageNamed:@"37x-Checkmark.png"];
			
			progressHUD.customView = [[UIImageView alloc] initWithImage:image];
			progressHUD.mode = MBProgressHUDModeCustomView;
			progressHUD.labelText = NSLocalizedString(@"Encrypted", @"Encrypted");
			
			BOOL animated = NO;
			[progressHUD show:animated];
			
 		}
		else if ([status isEqualToString:NOTIFICATION_SCLOUD_BROKER_REQUEST])
		{
			progressHUD.mode = MBProgressHUDModeIndeterminate;
			progressHUD.labelText = NSLocalizedString(@"Preparing", @"Preparing");
			
			BOOL animated = NO;
			[progressHUD show:animated];
		}
		else if ([status isEqualToString:NOTIFICATION_SCLOUD_BROKER_COMPLETE])
		{
			progressHUD.mode = MBProgressHUDModeAnnularDeterminate;
			progressHUD.labelText = NSLocalizedString(@"Uploading", @"Uploading");
            progressHUD.progress = 0.0F;

			BOOL animated = NO;
			[progressHUD show:animated];
		}
		else if ([status isEqualToString:NOTIFICATION_SCLOUD_UPLOAD_PROGRESS])
		{
			NSNumber *progress = [userInfo objectForKey:@"progress"];
			
			progressHUD.progress = [progress floatValue];
			
			BOOL animated = NO;
			[progressHUD show:animated];
		}
        else if ([status isEqualToString:NOTIFICATION_SCLOUD_UPLOAD_RETRY])
		{
//#pragma warning VINNIE add some code here to show we retried
		//	NSNumber *attempt = [userInfo objectForKey:@"retry"];
			
		}
		else if ([status isEqualToString:NOTIFICATION_SCLOUD_UPLOAD_COMPLETE])
		{
						
			UIImage *image = [UIImage imageNamed:@"37x-Checkmark.png"];
			
			progressHUD.customView = [[UIImageView alloc] initWithImage:image];
			progressHUD.mode = MBProgressHUDModeCustomView;
			progressHUD.labelText = NSLocalizedString(@"Completed", @"Completed");
			
			BOOL animated = NO;
			[progressHUD show:animated];
			
			animated = YES;
			[progressHUD hide:animated afterDelay:1.0];
		}
        
		else if ([status isEqualToString:NOTIFICATION_SCLOUD_UPLOAD_FAILED])
		{
 			UIImage *image = [UIImage imageNamed:@"attention"];
			
			progressHUD.customView = [[UIImageView alloc] initWithImage:image];
			progressHUD.mode = MBProgressHUDModeCustomView;
			progressHUD.labelText =   NSLocalizedString(@"Failed", @"Failed");
	         
			BOOL animated = NO;
			[progressHUD show:animated];
			
			animated = YES;
			[progressHUD hide:animated afterDelay:3.0];
            
            if(error)
                [self popupString:error.localizedDescription withColor:[UIColor redColor] atCell:cell];

		}

		else if ([status isEqualToString:NOTIFICATION_SCLOUD_DOWNLOAD_START])
		{
			
			progressHUD.mode = MBProgressHUDModeAnnularDeterminate;
			progressHUD.labelText = NSLocalizedString(@"Downloading", @"Downloading");
			
			BOOL animated = NO;
			[progressHUD show:animated];
		}
		else if ([status isEqualToString:NOTIFICATION_SCLOUD_DOWNLOAD_PROGRESS])
		{
			
			NSNumber *progress = [userInfo objectForKey:@"progress"];
			
			progressHUD.mode = MBProgressHUDModeAnnularDeterminate;
			progressHUD.labelText = NSLocalizedString(@"Downloading", @"Downloading");
			progressHUD.progress = [progress floatValue];
			
			BOOL animated = NO;
			[progressHUD show:animated];
		}
		else if ([status isEqualToString:NOTIFICATION_SCLOUD_DOWNLOAD_COMPLETE])
		{
			
			BOOL animated = YES;
			[progressHUD hide:animated afterDelay:0.0];
		}
 
        else if ([status isEqualToString:NOTIFICATION_SCLOUD_GPS_START])
		{
			
			progressHUD.mode = MBProgressHUDModeIndeterminate;
			progressHUD.labelText = NSLocalizedString(@"GPS", @"GPS");
			
			BOOL animated = NO;
			[progressHUD show:animated];
		}

        else if ([status isEqualToString:NOTIFICATION_SCLOUD_GPS_COMPLETE])
		{
			
			BOOL animated = YES;
			[progressHUD hide:animated afterDelay:0.0];
		}

        
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - SCAddressBookController Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)scAddressBookPicker:(SCContactBookPicker *)sender didFinishPickingWithSiren:(Siren *)siren
                                                                              error:(NSError *)error
{
	DDLogAutoTrace();
	
	[chatOptionsView suspendFading: NO];
	
	if(AppConstants.isIPhone)
	{
		[self.navigationController popViewControllerAnimated: YES];
	}
	else
	{
        [self dismissPopoverIfNeededAnimated:YES];
 	}
	
	if (error)
	{
		DDLogError(@"scAddressBookPicker reported error: %@", error);
		
		NSError *betterError = [NSError errorWithDomain:NSOSStatusErrorDomain
		                                           code:error.code
		                                       userInfo:nil];
		
		NSString *title = NSLocalizedString(@"address book failed", @"address book failed");
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
		                                                message:betterError.localizedDescription
		                                               delegate:nil
		                                      cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
		                                      otherButtonTitles:nil];
		[alert show];
	}
	else if (siren)
	{
		[self sendScloudWithSiren:siren];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - STAudioView Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)STAudioView:(STAudioView *)sender didFinishRecordingWithSiren: (Siren*) siren error:(NSError *)error
{
	if(!error)
	{
		if(!siren)  return;
		
		// start upload of Scloud somewhere around here?
		
		[self sendScloudWithSiren:siren];
		
	}
	else
	{
		NSError *betterError = [NSError errorWithDomain:NSOSStatusErrorDomain
												   code:error.code
											   userInfo:nil];
		NSLog(@"Error: %@", [error description]);
		
		UIAlertView *alert = [[UIAlertView alloc]
							  initWithTitle: NSLocalizedString(@"Recording failed", @"Recording failed")
							  message: betterError.localizedDescription
							  delegate: nil
							  cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
							  otherButtonTitles:nil];
		[alert show];
		
	}
	
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - SCCameraViewController Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)scCameraViewController:(SCCameraViewController *)sender didPickAssetWithInfo:(NSDictionary *)info
{
	DDLogAutoTrace();
	
    [chatOptionsView suspendFading: NO];
    
	// What does info look like ?
	if(info) {
		[self queueAssetWithInfo:info];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - SCImagePickerViewController Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)scImagePickerViewController:(SCImagePickerViewController *)sender didPickAssetWithInfo:(NSDictionary*)info
{
	DDLogAutoTrace();
	
	[chatOptionsView suspendFading: NO];
	
	// What does info look like ?
	if (info) {
		[self queueAssetWithInfo:info];
	}
 }


#pragma mark - MessageFWDViewController methods.

- (void)messageFWDViewController:(MessageFWDViewController *)sender
			 messageFWDWithSiren:(Siren *)siren
					  recipients:(NSArray *)recipients
						   error:(NSError *)error
{
	// This method looks exactly like the one below it.
	// Perhaps the two delegate methods should be consolidated.
	
	DDLogAutoTrace();
	
	if(AppConstants.isIPhone)
	{
		[self.navigationController popViewControllerAnimated: YES];
	}
	else
	{
        [self dismissPopoverIfNeededAnimated:YES];
	}
	
	if (!error)
	{
		if (!siren || !recipients || recipients.count == 0) return;
		
		if (recipients.count == 1)
		{
			id jidItem = [recipients objectAtIndex:0];
			
			XMPPJID *jid = nil;
			if ([jidItem isKindOfClass:[XMPPJID class]])
				jid = (XMPPJID *)jidItem;
			else if ([jidItem isKindOfClass:[NSString class]])
				jid = [XMPPJID jidWithString:(NSString *)jidItem];
			
			MessageStream *messageStream = [MessageStreamManager messageStreamForUser:STDatabaseManager.currentUser];
			[messageStream sendSiren:siren
			                   toJID:jid
			                withPush:YES
			                   badge:YES
			           createMessage:YES
			              completion:^(NSString *messageId, NSString *conversationId)
			{
				// We could use this to jump to the other conversation if we wanted.
			}];
		}
		else // if (recipients.count > 1)
		{
			// Todo: Handle multiple recipients...
		}
	}
	else
	{
		NSError *betterError = [NSError errorWithDomain:NSOSStatusErrorDomain
												   code:error.code
											   userInfo:nil];
		NSLog(@"Error: %@", [error description]);
		
		UIAlertView *alert = [[UIAlertView alloc]
							  initWithTitle: NSLocalizedString(@"address book failed", @"address book failed")
							  message: betterError.localizedDescription
							  delegate: nil
							  cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
							  otherButtonTitles:nil];
		[alert show];
	}
}

- (void)messageFWDViewController:(MessageFWDViewController *)sender
			 messageFWDWithSiren:(Siren *)siren
					 selectedJid:(NSString *)jidStr
					 displayName:(NSString *)displayName
						   error:(NSError *)error
{
	// This method looks exactly like the one above it.
	// Perhaps the two delegate methods should be consolidated.
	
	DDLogAutoTrace();
	
	if(AppConstants.isIPhone)
	{
		isPopingBackIntoView = YES;
		[self.navigationController popViewControllerAnimated: YES];
	}
	else
	{
        [self dismissPopoverIfNeededAnimated:YES];
	}
	
	if (!error)
	{
		if(!siren || !jidStr)  return;
		
		XMPPJID *jid = [XMPPJID jidWithString:jidStr];
		
		MessageStream *messageStream = [MessageStreamManager messageStreamForUser:STDatabaseManager.currentUser];
		[messageStream sendSiren:siren
		                   toJID:jid
		                withPush:YES
		                   badge:YES
		           createMessage:YES
		              completion:^(NSString *messageId, NSString *conversationId)
		{
			// We could use this to jump to the other conversation if we wanted.
		}];
	}
	else
	{
		NSError *betterError = [NSError errorWithDomain:NSOSStatusErrorDomain
												   code:error.code
											   userInfo:nil];
		NSLog(@"Error: %@", [error description]);
		
		UIAlertView *alert = [[UIAlertView alloc]
							  initWithTitle: NSLocalizedString(@"address book failed", @"address book failed")
							  message: betterError.localizedDescription
							  delegate: nil
							  cancelButtonTitle:NSLocalizedString(@"OK", @"OK")
							  otherButtonTitles:nil];
		[alert show];
	}
	
}

#pragma mark - ConversationDetailsDelegate Methods (2)

- (void)getParticpantsLocationsWithCompletionBlock:(GetParticpantsLocationsCompletionBlock)completionBlock
{
	if (completionBlock == NULL) return;
	
	const CGFloat diameter = 28;
    
    [[DatabaseManager sharedInstance] geoLocationsForConversation: conversationId
                                                  completionBlock:^(NSError *error, NSDictionary *locations)
	{
		NSAssert([NSThread isMainThread], @"completionBlock expected to be invoked on main thread.");
		
		NSMutableArray *results = [NSMutableArray arrayWithCapacity:[locations count]];
		
		__block int32_t itemsCount = (int32_t) locations.count;
		dispatch_block_t jidProcessingCompletionBlock = ^{
			
			if (OSAtomicDecrement32(&itemsCount) == 0)
			{
				dispatch_async(dispatch_get_main_queue(), ^{
					completionBlock(NULL, results  );
				});
				
			}
		};
		
		for (NSString *jid in locations)
		{
			NSDictionary *item       = [locations objectForKey:jid];
			
			CLLocation *location     = [item objectForKey:@"location"];
			NSDate *timestamp        = [item objectForKey:@"timeStamp" ];
			
			NSDictionary *userInfo   = [userInfoDict objectForKey:jid];
			
			NSString *displayName    = [userInfo objectForKey:@"displayName" ];
			NSString *userId         = [userInfo objectForKey:@"userId"];
			NSNumber *abRecordID     = [userInfo objectForKey:@"abRecordID"];
			
			BOOL isMe = [jid isEqualToString:localJID.bare];
			
			void (^avatarFetchCompletionBlock)(UIImage*) = ^(UIImage *avatar){
				
				if (avatar)
				{
					NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:6];
					
					dict[@"jid"] = jid;
					dict[@"displayName"] = displayName;
					dict[@"timeStamp"] = timestamp;
					dict[@"avatar"] = avatar;
					dict[@"location"] = location;
					
					if (isMe) dict[@"isMe"] = @(YES);
					
					[results addObject:dict];
				}
				
				jidProcessingCompletionBlock();
			};
			
			if(userId)
			{
				[[AvatarManager sharedInstance] fetchAvatarForUserId:userId
				                                        withDiameter:diameter
				                                               theme:theme
				                                               usage:kAvatarUsage_None
				                                     completionBlock:avatarFetchCompletionBlock];
			}
			else if (abRecordID)
			{
				[[AvatarManager sharedInstance] fetchAvatarForABRecordID:[abRecordID intValue]
				                                            withDiameter:diameter
				                                                   theme:theme
				                                                   usage:kAvatarUsage_None
				                                         completionBlock:avatarFetchCompletionBlock];
			}
			else
			{
				jidProcessingCompletionBlock();
			}
		
		} // end for (NSString *jid in locations)
		
	}]; // end [[DatabaseManager sharedInstance] geoLocationsForConversation
}

#pragma mark - GroupInfoViewControllerDelegate methods.
//
//- (void)groupInfoViewController:(NewGroupInfoVC *)sender  displayInfoForUserJid:(NSString*)userJid
//{
//	if (AppConstants.isIPad)
//	{
//        [self dismissPopoverIfNeededAnimated:YES];
//	}
//	
//	[self showUserInfoForJid:userJid
//					fromRect:titleButton.frame
//					  inView:self.navigationController.navigationBar ];
//}


- (void)groupInfoViewController:(NewGroupInfoVC *)sender updateConversationName:(NSString*)conversationName
{
	if ([conversation.title isEqualToString:conversationName])
	{
		return;
	}
	
	NSString *newName = conversationName.length ? conversationName : NULL;
	
	// Update local conversation object (temporary)
	// Why are we doing this?
	conversation = [conversation copy];
	conversation.title = newName;

	// Get snapshot of current state.
	// Remember, this might all change by the time the async operation has completed.
	
	NSString *_conversationId = conversation.uuid;
	NSString *_userId = conversation.userId;
	
	MessageStream *ms = [MessageStreamManager messageStreamForUser:STDatabaseManager.currentUser];
	
	YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
	[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction){
		
		// Update conversation object in database (non-temporary)
		STConversation *updatedConversation = [transaction objectForKey:_conversationId inCollection:_userId];
		
		updatedConversation = [updatedConversation copy];
		updatedConversation.title = newName;
		
		[transaction setObject:updatedConversation
						forKey:updatedConversation.uuid
				  inCollection:updatedConversation.userId];
		
	} completionBlock:^ {
		
		Siren *siren = [Siren new];
		siren.threadName = conversationName.length ? conversationName : @"";
		
		[ms sendSiren:siren forConversationID:_conversationId
		                             withPush:NO
		                                badge:NO
		                        createMessage:YES
		                           completion:NULL];
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark vCalendarViewControllerDelegate methods.
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)vCalendarViewController:(vCalendarViewController *)sender previewVCalender:(SCloudObject *)scloud
{
	DDLogAutoTrace();
	
	[self previewSCloudObject:scloud];
}

- (void)vCalendarViewController:(vCalendarViewController *)sender needsHidePopoverAnimated:(BOOL)animated
{
	DDLogAutoTrace();
	
    [self dismissPopoverIfNeededAnimated:YES];
}

- (void)vCalendarViewController:(vCalendarViewController *)sender
                showMapForEvent:(NSString *)eventName
                     atLocation:(CLLocation *)location
                        andTime:(NSDate *)date
{
	DDLogAutoTrace();
	
    [self dismissPopoverIfNeededAnimated:YES];
 
    [inputView.autoGrowTextView resignFirstResponder];
    [self saveTableRestoreOffset];
    
	NSDateFormatter *formatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterMediumStyle
	                                                               timeStyle:NSDateFormatterShortStyle];
	
	SCMapPin *pin = [[SCMapPin alloc] initWithLocation:location
	                                             title:eventName
	                                          subTitle:[formatter stringFromDate:location.timestamp]
	                                             image:NULL
	                                              uuid:NULL];
	
	NewGeoViewController *geovc = [NewGeoViewController.alloc initWithNibName:@"NewGeoViewController" bundle:nil];
	geovc.mapPins = @[pin];
	geovc.title = eventName;
	
	[self pushViewControllerAndFixNavBar: geovc animated:YES];
}

- (void)vCalendarViewController:(vCalendarViewController *)sender showURLForEvent:(NSURL*)eventURL
{
	DDLogAutoTrace();
 
    [self dismissPopoverIfNeededAnimated:YES];
    
    [inputView.autoGrowTextView resignFirstResponder];
    
    [[UIApplication sharedApplication] openURL:eventURL];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark vCardViewControllerDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)vCardViewController:(vCardViewController *)sender needsHidePopoverAnimated:(BOOL)animated
{
    
    [self dismissPopoverIfNeededAnimated:YES];
  
}

- (void)vCardViewController:(vCardViewController *)sender previewVCard:(SCloudObject*)scloud
{
    [ self previewSCloudObject:scloud];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark MoreMenuViewController Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)moreMenuView:(MoreMenuViewController *)sender sendAgainButton:(STMessage*)message
{
    
    if(AppConstants.isIPhone)
    {
        [self.navigationController popViewControllerAnimated: YES];
    }
    else
    {
        [self dismissPopoverIfNeededAnimated:YES];
    }
    
    if(!message)
        return;
    
    [self resendMessage:message];
    
}

- (void)moreMenuView:(MoreMenuViewController *)sender clearButton:(STMessage*)message
{
    DDLogAutoTrace();
	
	if (AppConstants.isIPhone) {
		[self.navigationController popViewControllerAnimated: YES];
	}
	else {
		[self dismissPopoverIfNeededAnimated:YES];
	}
	
	if (message)
	{
		[self clearMessage:message];
	}
}

- (void)moreMenuView:(MoreMenuViewController *)sender uploadAgainButton:(STMessage *)message
{
    
    if(AppConstants.isIPhone)
    {
        [self.navigationController popViewControllerAnimated: YES];
    }
    else
    {
        [self dismissPopoverIfNeededAnimated:YES];
    }
    
	if (message == nil) {
		return;
	}
    
    SCloudObject* scloud =  [[SCloudObject alloc]  initWithLocatorString:message.siren.cloudLocator
                                                               keyString:message.siren.cloudKey
                                                                    fyeo:message.siren.fyeo];
	
	if (scloud.missingSegments.count)
    {
        // display some kind of error here ?
    }
    else
    {
        // start reupload
		
		STLocalUser *currentUser = STDatabaseManager.currentUser;
		YapCollectionKey *identifier = YapCollectionKeyCreate(message.conversationId, message.uuid);
        
		[[SCloudManager sharedInstance] startUploadForLocalUser:currentUser
		                                                 scloud:scloud
		                                              burnDelay:message.siren.shredAfter
		                                             identifier:identifier
		                                        completionBlock:NULL];
	}
}

- (void)moreMenuView:(MoreMenuViewController *)sender forwardButton:(STMessage*)message
{
    if(AppConstants.isIPhone)
    {
        [self.navigationController popViewControllerAnimated: NO];
    }
  	
    if(!message)
        return;
    
	NSIndexPath *indexPath =  [self indexPathForMessageId:message.uuid];
	if (!indexPath)
		return;
    
    STBubbleTableViewCell *cell = (STBubbleTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
    
    
	Siren *msgSiren = [message.siren copy];
	msgSiren.signature = NULL;
	msgSiren.requestReceipt = 0;
	msgSiren.shredAfter = 0;
    
	if (!msgSiren.thumbnail && message.hasThumbnail)
	{
		STImage *thumbnail = [self thumbnailForMessage:message];
		
		UIImage *image = thumbnail ? thumbnail.image : nil;
        if (image)
			msgSiren.thumbnail = UIImageJPEGRepresentation(image, 0.1);
    }

    MessageFWDViewController* mfc =
	  [[MessageFWDViewController alloc] initWithDelegate:self siren:msgSiren];
    
	[self showViewController:mfc
	                fromRect:cell.bubbleView.frame
	                  inView:cell.contentView
	              forMessage:nil
	             hidesNavBar:NO
	         arrowDirections:UIPopoverArrowDirectionAny];
}


- (void)moreMenuView:(MoreMenuViewController *)sender needsHidePopoverAnimated:(BOOL)animated
{
    if(AppConstants.isIPhone)
    {
        [self.navigationController popViewControllerAnimated: YES];
    }
    else
    {
        [self dismissPopoverIfNeededAnimated:YES];
    }
}
 
- (void)moreMenuView:(MoreMenuViewController *)sender setPopoverContentSize:(CGSize)size
{
    if(AppConstants.isIPad )
    {
        [popoverController setPopoverContentSize:size animated:NO];
    }

}

- (NSUInteger)messagesCount
{
    __block NSInteger messagesCount = 0;
    [STDatabaseManager.uiDatabaseConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        messagesCount = [[transaction ext:Ext_View_Order] numberOfItemsInGroup:conversation.uuid];
    }];
    
    return messagesCount;
}

@end
