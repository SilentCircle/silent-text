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
#import <StoreKit/StoreKit.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>
#import <MobileCoreServices/UTCoreTypes.h>

#import "UserInfoViewController.h"
#import "EditUserInfoViewController.h"
#import "ConversationViewController.h"
#import "MessagesViewController.h"

#import "AppDelegate.h"
#import "AppConstants.h"
#import "AppTheme.h"
#import "SilentTextStrings.h"
#import "STLogging.h"

#import "STUser.h"
#import "STPublicKey.h"
#import "STPreferences.h"

#import "MessageStream.h"
#import "ECPhoneNumberFormatter.h"

#import "SCAccountsWebAPIManager.h"
#import "ExpireManager.h"
#import "AddressBookManager.h"
#import "AvatarManager.h"
#import "StoreManager.h"
#import "STUserManager.h"

#import "OHActionSheet.h"
#import "OHAlertView.h"

#import "SCCalendar.h"
#import "SCDateFormatter.h"
#import "NSDate+SCDate.h"
#import "UIImage+Thumbnail.h"
#import "UIImage+maskColor.h"

#import "SCMapImage.h"
#import "MKMapView+SCUtilities.h"


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

static const CGFloat kAvatarDiameter = 50.0;

//#undef DEBUG

#define  SUPPORT_IN_APP_RENEWAL 1

#pragma mark -

@implementation UserInfoViewController
{
	UIScrollView *scrollView;
	CGFloat displayNameCenterYOffset;
    CGFloat organizationCenterYOffset;
    CGFloat networkCenterYOffset;
	
	YapDatabaseConnection *dbConnection;
    
    STUser *user;
    STPublicKey *userKey;
    NSArray* tempPubKeyArray;
    
    BOOL userNeedsSaving;
	UIImage *userImageOverride;
    
	__weak EditUserInfoViewController *editUserInfoVC;
    
    UITapGestureRecognizer* expireLabelGesture;
	AppTheme *theme;
    
    MBProgressHUD* HUD;
    
    UIImage*  subscribeIcon;
	BOOL isReloaded;
    BOOL hasMap;
    BOOL isShowingMyLocation;
    
    NSMutableArray* dropPins;
}

@synthesize delegate = delegate;

@synthesize userID = userID;
@synthesize userJID = userJID;

@synthesize isInPopover = isInPopover;
@synthesize isModal = isModal;

@synthesize containerView = containerView;

@synthesize userImageView = userImageView;
@synthesize displayNameLabel = displayNameLabel;
@synthesize organizationLabel = organizationLabel;
@synthesize networkLabel = networkLabel;

@synthesize userNameLabel = userNameLabel;
@synthesize phoneLabel = phoneLabel;
@synthesize expireDateLabel = expireDateLabel;

@synthesize textButton = textButton;
@synthesize callButton = callButton;

@synthesize horizontalRule = horizontalRule;

@synthesize userNotes = userNotes;

@synthesize addressBookButton = addressBookButton;
@synthesize addressBookTip = addressBookTip;

@synthesize keyInfo = keyInfo;

@synthesize activity = activity;
@synthesize checkButton = checkButton;

@synthesize keyActivity = keyActivity;
@synthesize keyButton = keyButton;

@synthesize mapView = mapView;
@synthesize mapViewPageCurlButton = mapViewPageCurlButton;

@synthesize subscribeButton = subscribeButton;

@synthesize debugView = debugView;
@synthesize debugNotes = debugNotes;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Init & Dealloc
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)initWithProperNib
{
	DDLogAutoTrace();
	return [self initWithNibName:@"UserInfoViewController" bundle:nil];
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
    
//	if (self.isInPopover)
//	{
//		self.navigationController.navigationBar.barStyle = UIBarStyleBlackTranslucent;
//	}
	
	if (self.isModal)
    {
		self.navigationItem.leftBarButtonItem =
		  [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"Done")
		                                   style:UIBarButtonItemStylePlain
		                                  target:self
		                                  action:@selector(doneButtonTapped:)];
    }

	self.navigationItem.rightBarButtonItem = NULL;
	
    dropPins = [[NSMutableArray alloc] init];

 	// Setup database access
	
	dbConnection = STDatabaseManager.uiDatabaseConnection;
    
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(databaseConnectionWillUpdate:)
	                                             name:UIDatabaseConnectionWillUpdateNotification
	                                           object:STDatabaseManager];
	
    [[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(databaseConnectionDidUpdate:)
	                                             name:UIDatabaseConnectionDidUpdateNotification
	                                           object:STDatabaseManager];
	
#if SUPPORT_IN_APP_RENEWAL
    [[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(purchaseTransactionComplete:)
	                                             name:kStoreManager_TransactionCompleteNotification
											   object:nil];
  #endif
	
    
    theme = [AppTheme getThemeBySelectedKey];

    
 	// Copying iOS on this.
	// They don't use a title, most likely because it visually distracts from the user name
	// displayed in the view controller, which should be the primary focus.
	//
	// self.title = NSLocalizedString(@"User Info", @"User Info");
	self.title = nil;
	
	self.view.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1];
	containerView.backgroundColor = self.view.backgroundColor;
	debugView.backgroundColor = self.view.backgroundColor;
	
    
    subscribeIcon = [UIImage imageNamed:@"subscribe"];
    
	UIImage *icon = nil;
	UIImage *tintIcon = nil;
	
	icon = [UIImage imageNamed:@"refresh-icon"];
	tintIcon = [icon maskWithColor:theme.appTintColor];
	[checkButton setImage:tintIcon forState:UIControlStateNormal];
	
	icon = [UIImage imageNamed:@"refresh_key"];
	tintIcon = [icon maskWithColor:theme.appTintColor];
    [keyButton setImage:tintIcon forState:UIControlStateNormal];

//	icon = [UIImage imageNamed:@"SilentPhone_CircleIcon32"];
//	tintIcon = [icon maskWithColor:[STPreferences navItemTintColor]];
//	[callButton setImage:tintIcon forState:UIControlStateNormal];

//	icon = [UIImage imageNamed:@"SilentText_CircleIcon32"];
//	tintIcon = [icon maskWithColor:[STPreferences navItemTintColor]];
//	[textButton setImage:tintIcon forState:UIControlStateNormal];
    
    expireLabelGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(expireLabelTapped:)];
    [expireDateLabel addGestureRecognizer:expireLabelGesture];
 	
    
	// Embed the view in a scrollView
	
	scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
	scrollView.backgroundColor = self.view.backgroundColor;
	scrollView.showsHorizontalScrollIndicator = NO;
	scrollView.showsVerticalScrollIndicator = YES;
	scrollView.indicatorStyle = UIScrollViewIndicatorStyleBlack;
	scrollView.scrollEnabled = YES;
	
	CGSize contentSize = containerView.frame.size;
	scrollView.contentSize = contentSize;
	
	[containerView removeFromSuperview];
	
	containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[containerView setTranslatesAutoresizingMaskIntoConstraints:YES];
	
	[scrollView addSubview:containerView];
	
	scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[scrollView setTranslatesAutoresizingMaskIntoConstraints:YES];
	
	[self.view addSubview:scrollView];
	
	// Search constraints.
	// Find centerY offset for displayName & organization.
    // Stash these orginal values (from the xib) for toggling stuff around later.
	
	NSLayoutConstraint *constraint = [self centerYConstraintFor:displayNameLabel];
	if (constraint)
	{
		displayNameCenterYOffset = constraint.constant;
	}
    
    constraint = [self centerYConstraintFor:organizationLabel];
    if (constraint)
    {
        organizationCenterYOffset = constraint.constant;
    }
    
    constraint = [self centerYConstraintFor:networkLabel];
    if (constraint)
    {
        networkCenterYOffset = constraint.constant;
    }
	
    mapView.hidden = YES;
    
	// Conditionally add debug info

	[debugView removeFromSuperview];
	
	#if DEBUG
	{
		debugView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[debugView setTranslatesAutoresizingMaskIntoConstraints:YES];

		CGRect frame = (CGRect){
			.origin.x = 0,
			.origin.y = containerView.frame.size.height,
			.size.width = scrollView.frame.size.width,
			.size.height = debugView.frame.size.height
		};

		debugView.frame = frame;
		[scrollView addSubview:debugView];
		
		contentSize.height += debugView.frame.size.height;
		scrollView.contentSize = contentSize;
	}
	#endif
}

- (void)viewWillAppear:(BOOL)animated
{
	DDLogAutoTrace();
	[super viewWillAppear:animated];
    
	if (!isReloaded) {
		[self reloadView:YES forceReload:YES];
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

/**
 * This method is queried * by our own code * when creating popover controllers.
 * It is conceptually similar to the deprecated contentSizeForViewInPopover method.
**/
- (CGSize)preferredPopoverContentSize
{
	DDLogAutoTrace();
	
	// If this method is queried before we've loaded the view, then containerView will be nil.
	// So we make sure the view is loaded first.
	if (![self isViewLoaded]) {
		(void)[self view];
	}
	
	// And then make sure we can get the proper size.
	// Remember: The containerView height will dynamically change based upon its content.
	if (!isReloaded) {
		[self reloadView:YES forceReload:YES];
	}
	
    CGFloat height = containerView.frame.size.height;
    
 	return CGSizeMake(320, height);
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

- (NSLayoutConstraint *)centerYConstraintFor:(id)item
{
	for (NSLayoutConstraint *constraint in containerView.constraints)
	{
		if ((constraint.firstItem == item && constraint.firstAttribute == NSLayoutAttributeCenterY) ||
		    (constraint.secondItem == item && constraint.secondAttribute == NSLayoutAttributeCenterY))
		{
			return constraint;
		}
	}
	
	return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Custom Setters
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setUserID:(NSString *)inUserID
{
	DDLogAutoTrace();

	if ([userID isEqualToString:inUserID])
		return;
	
	if (editUserInfoVC)
	{
		editUserInfoVC.delegate = nil;
		[editUserInfoVC saveChanges];
		editUserInfoVC = nil;
		
		[self.navigationController popViewControllerAnimated:NO];
	}
	
	userID = [inUserID copy];
	userJID = NULL;
	user = NULL;
	userKey = NULL;
	tempPubKeyArray = NULL;
	userNeedsSaving = NO;
	
    hasMap = NO;
	isReloaded = NO;
	[self reloadView:YES forceReload:YES];
}

- (void)setUserJID:(NSString *)inUserJID
{
	DDLogAutoTrace();

	if ([userJID isEqualToString:inUserJID])
		return;
	
	if (editUserInfoVC)
	{
		editUserInfoVC.delegate = nil;
		[editUserInfoVC saveChanges];
		editUserInfoVC = nil;
		
		[self.navigationController popViewControllerAnimated:NO];
	}
	
	userJID = [inUserJID copy];
	user = NULL;
	userKey = NULL;
	userID = NULL;
	tempPubKeyArray = NULL;
	userNeedsSaving = NO;
	
	isReloaded = NO;
	[self reloadView:YES forceReload:YES];
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
	DDLogAutoTrace();
	
	NSArray *notifications = [notification.userInfo objectForKey:kNotificationsKey];
	
	if ([dbConnection hasChangeForKey:userID inCollection:kSCCollection_STUsers inNotifications:notifications])
	{
 		[self reloadView:NO forceReload:YES];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Logic
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)reloadView: (BOOL)userChanged forceReload:(BOOL)forceReload
{
	DDLogAutoTrace();
	
	if (self.isViewLoaded == NO) return;
	
	#if DEBUG
	NSMutableString *debugInfo = [NSMutableString string];
	#endif
    
    UIColor* ringColor = theme.appTintColor;
    
    [dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        
        // Fetch the updated user.
        // This method is invoked when the viewController is first loaded,
        // and is re-invoked if the user is changed in the database.
        // So, at this point, we need to refresh our user object from the database.
        
        if (forceReload || user == nil)
        {
            if (userID)
            {
                user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
                userJID = [user.jid bare];
                userNeedsSaving = NO;
            }
            else if (userJID)
            {
				user = [[DatabaseManager sharedInstance] findUserWithJidStr:userJID transaction:transaction];
				
                if (user) {
					userNeedsSaving = NO;
				}
			}
			else
			{
				return;
			}
            
            if(user && user.currentKeyID)
            {
                userKey = [transaction objectForKey:user.currentKeyID inCollection:kSCCollection_STPublicKeys];
            }
		}

		#if DEBUG
		if ([user.publicKeyIDs count] > 0)
		{
			NSDateFormatter *formatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterShortStyle
			                                                               timeStyle:NSDateFormatterNoStyle];
			
			[debugInfo appendString:@"\nKeys:"];
			
			for (NSString *keyID in user.publicKeyIDs)
			{
				STPublicKey *publicKey = [transaction objectForKey:keyID inCollection:kSCCollection_STPublicKeys];
				
				[debugInfo appendFormat:@"\n%s %@: %@",
				  ([publicKey.uuid isEqualToString:user.currentKeyID] ? "*" : " "),
				   [publicKey.uuid substringToIndex:16],
				   [formatter stringFromDate:publicKey.expireDate]];
			}
        }
		#endif
	}];
	
    [MBProgressHUD hideHUDForView:self.view animated:YES];

	if (user == nil && userJID)
	{
		// Nothing found in database.
		// Create a temp user and query a getUserInfo from webapi in background for info.
		
		XMPPJID *realJID = [XMPPJID jidWithString:userJID];
		
		user = [[STUser alloc] initWithUUID:nil
		                          networkID:STDatabaseManager.currentUser.networkID
		                                jid:realJID];
		
		user.lastUpdated  = [NSDate distantPast];
		
		NSDictionary *abInfo = [[AddressBookManager sharedInstance] infoForSilentCircleJID:realJID];
		if(abInfo)
		{
			ABRecordID abNum = [[abInfo objectForKey:kABInfoKey_abRecordID] intValue];
			
			user.abRecordID = abNum;
			user.isAutomaticallyLinkedToAB = YES;
			
			user.ab_firstName     = [abInfo objectForKey:kABInfoKey_firstName];
			user.ab_lastName      = [abInfo objectForKey:kABInfoKey_lastName];
			user.ab_compositeName = [abInfo objectForKey:kABInfoKey_compositeName];
			user.ab_organization  = [abInfo objectForKey:kABInfoKey_organization];
			user.ab_notes         = [abInfo objectForKey:kABInfoKey_notes];
		}
		
		[activity startAnimating];
		[checkButton setHidden:YES];
			
		[[SCAccountsWebAPIManager sharedInstance] getUserInfo:user.jid
		                                         forLocalUser:STDatabaseManager.currentUser
		                                      completionBlock:^(NSError *error, NSDictionary *infoDict)
		{
			if (!error && infoDict)
			{
				NSDictionary *parsedDict = [[SCAccountsWebAPIManager sharedInstance] parseUserInfoResult:infoDict];
				
				tempPubKeyArray = [parsedDict objectForKey:kUserInfoKey_pubKeys];
				user = [user copy];

				user.web_firstName     = [parsedDict objectForKey:kUserInfoKey_firstName];
				user.web_lastName      = [parsedDict objectForKey:kUserInfoKey_lastName];
				user.web_compositeName = [parsedDict objectForKey:kUserInfoKey_displayName];
				
				user.hasPhone     = [[parsedDict objectForKey:kUserInfoKey_hasPhone] boolValue];
				user.canSendMedia = [[parsedDict objectForKey:kUserInfoKey_canSendMedia] boolValue];
				
				userNeedsSaving = YES;
			}
			
			[checkButton setHidden:NO];
			[activity stopAnimating];
			
			[self reloadView:userChanged forceReload:NO];
		}];
	}
	
    if(user)
    {
        hasMap =  user.lastLocation != NULL;
        [self reloadMap];
        
    }
	if (user && !user.isRemote)
	{
		expireDateLabel.userInteractionEnabled = YES;
		expireDateLabel.hidden = NO;
		subscribeButton.hidden = NO;
		
        if (user.isActivated)
        {
           	NSDate *expiresDate = user.subscriptionExpireDate;
            
            if(user.handlesOwnBilling)
            {
                expireDateLabel.userInteractionEnabled = NO;
                expireDateLabel.hidden = YES;
                subscribeButton.hidden = YES;
    
            }
            else if(user.autorenew)
            {
                UIImage*  tintIcon = [subscribeIcon maskWithColor:[UIColor blackColor]];
                [subscribeButton setImage:tintIcon forState:UIControlStateNormal];
                 
                NSString *frmt= NSLocalizedString(@"Subscription renews: %@", @"Subscription renews");
                 expireDateLabel.text = [NSString stringWithFormat:frmt, expiresDate.whenString];
                expireDateLabel.textColor = [UIColor blackColor];
                
           }
            else if (user.subscriptionHasExpired)
            {
                UIImage*  tintIcon = [subscribeIcon maskWithColor:[UIColor redColor]];
                [subscribeButton setImage:tintIcon forState:UIControlStateNormal];
               
                expireDateLabel.text = NSLocalizedString(@"Subscription has expired",@"Subscription has expired");
                expireDateLabel.textColor = [UIColor redColor];
                
            }
            else if (user.subscriptionExpireDate)
            {
                UIColor* labelColor = [UIColor redColor];
                
                // dates till expired
                NSDateComponents *difference =
                [[SCCalendar cachedAutoupdatingCurrentCalendar] components:NSDayCalendarUnit
                                                                  fromDate:[NSDate date]
                                                                    toDate:user.subscriptionExpireDate
                                                                   options:0];
                
                if ([difference day] < 10 && [difference day] > 1)
                {
                    NSString *frmt =
                    NSLocalizedString(@"Subscription expires in %d days", @"label text format");
                    
                    expireDateLabel.text = [NSString stringWithFormat:frmt, [difference day]];
                }
                else
                {
                    NSString *frmt= NSLocalizedString(@"Renew before: %@", @"label text format");
                    
                    expireDateLabel.text = [NSString stringWithFormat:frmt, expiresDate.whenString];
                    
                 }
                
                if ([difference day] > 10)
                {
#if SUPPORT_IN_APP_RENEWAL

                    labelColor = theme.appTintColor;
#else
                    labelColor = [UIColor blackColor];
#endif
                }
                else if ([difference day] > 3)
                {
 //                   labelColor = [UIColor orangeColor];
				}
                
                UIImage*  tintIcon = [subscribeIcon maskWithColor:labelColor];
                expireDateLabel.textColor = labelColor;
                [subscribeButton setImage:tintIcon forState:UIControlStateNormal];
            }
        }
        else if (user.provisonInfo)
        {
            expireDateLabel.text = NSLocalizedString(@"Waiting for payment",@"Waiting for payment");
            expireDateLabel.textColor = [UIColor orangeColor];
        }

		else // if (!user.isActivated)
        {
            expireDateLabel.text = NSLocalizedString(@"Deactivated",@"Deactivated");
            expireDateLabel.textColor = [UIColor redColor];
        }
	}
	else // if (!user || user.isRemote)
	{
		expireDateLabel.hidden = YES;
		subscribeButton.hidden = YES;
	}
	
	if (userKey)
	{
		UIImage* keyButtonImage = NULL;
		
		if(userKey.isExpired )
		{
			keyButtonImage = [[UIImage imageNamed:@"X-circled"]
			                    maskWithColor:[UIColor colorWithRed:1.0 green:.5 blue: 0 alpha:.6 ]];
		
            [keyInfo setImage:keyButtonImage forState:UIControlStateNormal];
			[keyInfo setHidden:NO];

        }
		else
		{
			SCKeySuite suite = userKey.keySuite;
			
			if(suite == kSCKeySuite_ECC414)
			{
				if (userKey.continuityVerified)
					keyButtonImage = [[UIImage imageNamed:@"starred-checkmark"]
                                      maskWithColor:[UIColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:0.6]];
				else
					keyButtonImage = [[UIImage imageNamed:@"checkmark-circled"]
					                    maskWithColor:[UIColor colorWithRed:0.0 green:0.7 blue:0.0 alpha:0.6]];
			}
			else  if(suite == kSCKeySuite_ECC384)
			{
				if (userKey.continuityVerified)
					keyButtonImage = [[UIImage imageNamed:@"starred-checkmark"]
                                      maskWithColor:[UIColor colorWithRed:0.0 green:0.0 blue:0.7 alpha:0.6]];
				else
					keyButtonImage = [[UIImage imageNamed:@"checkmark-circled"]
					                    maskWithColor:[UIColor colorWithRed:0.0 green:0.0 blue:0.7 alpha:0.6]];
			}
			else
			{
				keyButtonImage = [[UIImage imageNamed:@"X-circled"]
				                    maskWithColor:[UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.6]];
			}
			
			[keyInfo setImage:keyButtonImage forState:UIControlStateNormal];
			[keyInfo setHidden:NO];
		}
	}
	else
	{
		[keyInfo setHidden:YES];
	}
    
  	
	#if DEBUG
    if (user && !user.isRemote)
	{
		[debugInfo appendFormat:@"\nPushToken: %@\n", [STPreferences applicationPushToken]];
		
		MessageStream *ms = [STAppDelegate messageStreamForUser:user];
		if (ms.state == MessageStream_State_Connected)
		{
			[debugInfo appendFormat:@"\nConnected: %@:%d\n\n", ms.connectedHostName, ms.connectedHostPort];
		}
		else
		{
			[debugInfo appendString:@"\nNot Connected\n\n"];
		}
	}
	#endif
	
	// select the proper item for right Bar button
	if (user)
	{
		if (user.uuid)
		{
			self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                          target:self
                                                          action:@selector(editButtonTapped:)];
		}
		else
		{
			self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                          target:self
                                                          action:@selector(saveButtonTapped:)];
		}
	}
	
	// We're not displaying a title anymore.
	// A title looks a little goofy because we have the same displayName immediately below the title.
	//
    // self.navigationItem.title = user.displayName;
	
	if (userImageOverride)
	{
		UIImage *avatar = [userImageOverride scaledAvatarImageWithDiameter:kAvatarDiameter];
		avatar = [avatar avatarImageWithDiameter:kAvatarDiameter usingColor:ringColor];
		
        userImageView.image = avatar;
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
			NSDictionary *abInfo = [[AddressBookManager sharedInstance] infoForSilentCircleJID:user.jid];
            
            if (abInfo)
                fetch_avatar_abRecordId = [[abInfo objectForKey:kABInfoKey_abRecordID] intValue];
            else
                fetch_avatar_abRecordId = kABRecordInvalidID;
         }
        
		if (fetch_avatar_userId)
		{
			// If userImageView.image is non-nil then it has a proper image.
			// Either from a previous fetch, or from a recent userImageOverride.
			// So we don't want to flash the default image if it doesn't happen to be in the cache.
			BOOL useDefaultIfUncached = (userImageView.image == nil);
			
			UIImage *cachedAvatar = [[AvatarManager sharedInstance] cachedAvatarForUserId:fetch_avatar_userId
			                                                                 withDiameter:kAvatarDiameter
			                                                                        theme:theme
			                                                                        usage:kAvatarUsage_None
			                                                              defaultFallback:useDefaultIfUncached];
			if (cachedAvatar)
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
			// If userImageView.image is non-nil then it has a proper image.
			// Either from a previous fetch, or from a recent userImageOverride.
			// So we don't want to flash the default image if it doesn't happen to be in the cache.
			BOOL useDefaultIfUncached = (userImageView.image == nil);
			
			UIImage *cachedAvatar = [[AvatarManager sharedInstance] cachedAvatarForABRecordID:fetch_avatar_abRecordId
			                                                                     withDiameter:kAvatarDiameter
			                                                                            theme:theme
			                                                                            usage:kAvatarUsage_None
			                                                                  defaultFallback:useDefaultIfUncached];
			if (cachedAvatar)
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
        else
        {
            // edge case, remote user doesnt have userrecord in DB, (probably deleted)
            
            UIImage *avatar = [[AvatarManager sharedInstance] defaultAvatarwithDiameter:kAvatarDiameter];
            avatar = [avatar avatarImageWithDiameter:kAvatarDiameter usingColor:ringColor];

            userImageView.image = avatar;
        }
        
		if (userChanged)
		{
            if (user.isRemote)
            {
                [keyButton setHidden:YES];
                [checkButton setHidden:NO];
            }
            else
            {
               if (user.isActivated)
               {
                   [keyButton setHidden:NO];
                   [checkButton setHidden:NO];
				}
                else
                {
                    [keyButton setHidden:YES];
                    [checkButton setHidden:YES];
				}
			}
		}
        
    }
    
    displayNameLabel.text = user.displayName;
    organizationLabel.text = user.organization;
    networkLabel.text = NULL;
  
    NSDictionary *networkInfo = [[AppConstants SilentCircleNetworkInfo] objectForKey:user.networkID];

    if(![user.networkID isEqualToString:kNetworkChoiceKeyProduction])
    {
        UIColor *color = [networkInfo objectForKey:@"displayColor"];
        NSString *networkName = [networkInfo objectForKey:@"displayName"];
        
        networkLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Network: %@", @"Network: %@"),networkName ];
        networkLabel.textColor = color?:[UIColor blackColor];
    }
    
     
  	userNotes.text = user.notes;
    
	organizationLabel.textColor = user.organization.length
	                           && user.sc_organization.length == 0
	                           && user.abRecordID != kABRecordInvalidID
	                            ? [UIColor grayColor]
	                            : [UIColor blackColor];
   
	userNotes.textColor = user.notes.length
	                   && user.sc_notes.length == 0
	                   && user.abRecordID != kABRecordInvalidID
	                    ? [UIColor grayColor]
	                    : [UIColor blackColor];
  
	displayNameLabel.textColor = user.hasExtendedDisplayName
	                          && user.sc_compositeName.length == 0
	                          && user.sc_firstName.length == 0
	                          && user.sc_lastName.length == 0
	                          && user.web_compositeName.length == 0
	                          && user.web_firstName.length == 0
	                          && user.web_lastName.length == 0
	                          && user.abRecordID != kABRecordInvalidID
	                           ? [UIColor grayColor]
	                           : [UIColor blackColor];
	
	if ([user.jid.domain isEqualToString:@"silentcircle.com"])
		userNameLabel.text = user.jid.user;
	else
		userNameLabel.text = [user.jid bare];
    
    BOOL textState =  ![user.uuid isEqualToString:STDatabaseManager.currentUser.uuid]
    && [STDatabaseManager.currentUser.networkID  isEqualToString:user.networkID];
    
	textButton.enabled = textState;

	BOOL phoneState = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"silentphone:"]]
                        && ![user.uuid isEqualToString:STDatabaseManager.currentUser.uuid];
    
    callButton.enabled = phoneState;
    
    // the web API changed how it represented the phone numbers..  we have to maintian backward compatibility
    NSString* number = NULL;
    NSArray* spNumbers = user.spNumbers;
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
    
    if(number )
    {
        ECPhoneNumberFormatter *formatter = [[ECPhoneNumberFormatter alloc] init];
        phoneLabel.text = [formatter stringForObjectValue:number];
        [phoneLabel setHidden:NO];
    }
    else
	{
		[phoneLabel setHidden:YES];
    }
    
	
	#if DEBUG
	debugNotes.text = debugInfo;
	#endif
    
    
    NSString *buttonTitle= NULL;
    NSString *buttonHint= NULL;
    BOOL isEnabled = NO;
    BOOL isHidden = YES ;

    if (user.uuid && (user.abRecordID == kABRecordInvalidID))
    {
        buttonTitle = NSLocalizedString(@"Link with Contacts Book", @"@"Link with Contacts Book"");

        buttonHint = NSLocalizedString(
		  @"Linking allows Silent Text to import information such as name and photo from the phone Contacts book."
		  @" The phone Contacts book is never modified.",
		  @"Button hint");
		
		isEnabled = YES;
		isHidden = NO;
	}
	else
    {
		if (user.isAutomaticallyLinkedToAB)
        {
            buttonTitle = NSLocalizedString(@"Found In Contacts Book", @"Found In Contacts Book");
            buttonHint = NULL;
            isEnabled = NO;
            isHidden = NO;
        }
        else if(user.uuid)
        {
            buttonTitle = NSLocalizedString(@"Unlink from Contacts Book", @"Unlink from Contacts Book");
            
            buttonHint = NSLocalizedString(
			  @"This contact is linked with an entry in the phone Contacts book and will remain synchronized with it."
			  @" The phone Contacts book is never modified.",
			  @"Button hint");
			
			isEnabled = YES;
			isHidden = NO;
		}
	}

    // iOS 7 wants to automatically animate the UIButton title change for some reason
    [UIView setAnimationsEnabled:NO];
    [addressBookButton setHidden:isHidden];
    [addressBookButton setEnabled:isEnabled];

    [addressBookTip setHidden:isHidden];
    [addressBookButton setTitle:buttonTitle forState:UIControlStateNormal];
    addressBookTip.text = buttonHint;
    [UIView setAnimationsEnabled:YES];


    [checkButton setEnabled:([networkInfo objectForKey:@"canProvision"]
                             &&  ([[networkInfo objectForKey:@"canProvision"]boolValue] ==  YES))];
   	
	//
	// Update constraints
	//
	
	if ([organizationLabel.text length] > 0)
	{
		// Unhide organization label
		
		organizationLabel.hidden = NO;
        networkLabel.hidden = NO;
		
		// Revert Y constraints to original values
		
		NSLayoutConstraint *displayNameYConstraint = [self centerYConstraintFor:displayNameLabel];
		displayNameYConstraint.constant = displayNameCenterYOffset;
		
        NSLayoutConstraint *networkNameYConstraint = [self centerYConstraintFor:networkLabel];
        networkNameYConstraint.constant = networkCenterYOffset;
	}
	else if ([networkLabel.text length] > 0)
	{
		// Hide organization label
		
		organizationLabel.hidden = YES;
        networkLabel.hidden = NO;
		
		// Update Y constraint for displayName to original value
        // Update Y constraint for networkName to that of the organization
		
		NSLayoutConstraint *displayNameYConstraint = [self centerYConstraintFor:displayNameLabel];
		displayNameYConstraint.constant = displayNameCenterYOffset;
        
        NSLayoutConstraint *networkNameYConstraint = [self centerYConstraintFor:networkLabel];
        networkNameYConstraint.constant = organizationCenterYOffset;
		
		}
    else // organization & network labels empty
    {
        // Hide organization label
		
		organizationLabel.hidden = YES;
        networkLabel.hidden = YES;
		
		// Update Y constraint for displayName to center on userImage
		
		NSLayoutConstraint *displayNameYConstraint = [self centerYConstraintFor:displayNameLabel];
		displayNameYConstraint.constant = 0.0F;
    }
	
	if (expireDateLabel.hidden && phoneLabel.hidden)
	{
		NSLayoutConstraint *oldConstraint = [self topConstraintFor:horizontalRule];
		
		NSLayoutConstraint *newConstraint =
		  [NSLayoutConstraint constraintWithItem:horizontalRule
		                               attribute:NSLayoutAttributeTop
		                               relatedBy:NSLayoutRelationEqual
		                                  toItem:textButton //userNameLabel
		                               attribute:NSLayoutAttributeBottom
		                               multiplier:1
		                                 constant:8];
		
		[containerView removeConstraint:oldConstraint];
		[containerView addConstraint:newConstraint];
		
	}
	else if (expireDateLabel.hidden)
	{
		NSLayoutConstraint *oldConstraint = [self topConstraintFor:horizontalRule];
		
		NSLayoutConstraint *newConstraint =
		  [NSLayoutConstraint constraintWithItem:horizontalRule
		                               attribute:NSLayoutAttributeTop
		                               relatedBy:NSLayoutRelationEqual
		                                  toItem:phoneLabel
		                               attribute:NSLayoutAttributeBottom
		                               multiplier:1
		                                 constant:8];
		
		[containerView removeConstraint:oldConstraint];
		[containerView addConstraint:newConstraint];
		
	}
	else
	{
		NSLayoutConstraint *oldConstraint = [self topConstraintFor:horizontalRule];
		
		NSLayoutConstraint *newConstraint =
		  [NSLayoutConstraint constraintWithItem:horizontalRule
		                               attribute:NSLayoutAttributeTop
		                               relatedBy:NSLayoutRelationEqual
		                                  toItem:expireDateLabel
		                               attribute:NSLayoutAttributeBottom
		                               multiplier:1
		                                 constant:8];
		
		[containerView removeConstraint:oldConstraint];
		[containerView addConstraint:newConstraint];

	}
    

    if (hasMap)
    {
        mapView.hidden = NO;
		mapViewPageCurlButton.hidden = NO;
    }
    else
    {
        mapView.hidden = YES;
		mapViewPageCurlButton.hidden = YES;
    }
    
	//
	// Update containerView && debugView && scrollView.contentSize
	//
	// Note: Because we removed the containerView from self.view, and embedded it within a scrollView,
	// we were forced to switch back to autoresizing mask stuff.
	// Thus we have to manually change the frame,
	// although we can at least take advantage of [STDynamicHeightView intrinsicContentSize].
	//
	// [containerView class] == STDynamicHeightView
	
    [containerView invalidateIntrinsicContentSize];
    [containerView setNeedsUpdateConstraints];
    [containerView.superview setNeedsUpdateConstraints];
    
	[containerView layoutIfNeeded];
	
	CGSize containerViewIntrinsicSize = [containerView intrinsicContentSize];
	
	CGRect containerViewFrame = containerView.frame;
	containerViewFrame.size.height = containerViewIntrinsicSize.height;
	
	containerView.frame = containerViewFrame;
	
	CGSize scrollViewContentSize = scrollView.contentSize;
	scrollViewContentSize.height = containerViewFrame.size.height;
    
	#if DEBUG
	{
		CGRect debugViewFrame = debugView.frame;
        if (hasMap)
            debugViewFrame.origin.y = mapView.frame.origin.y + mapView.frame.size.height;
        else
            debugViewFrame.origin.y = containerViewFrame.origin.y + containerViewFrame.size.height;
		
		debugView.frame = debugViewFrame;
		
		scrollViewContentSize.height += debugViewFrame.size.height;
	}
	#endif
	
	scrollView.contentSize = scrollViewContentSize;
	isReloaded = YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)doneButtonTapped:(id)sender
{
	DDLogAutoTrace();
	
	if (self.isModal)
	{
		[self dismissViewControllerAnimated:YES completion:nil];
	}
	else
	{
		[self.navigationController popViewControllerAnimated:YES];
	}
}

- (void)editButtonTapped:(id)sender
{
	DDLogAutoTrace();
	
	EditUserInfoViewController *editVC = [[EditUserInfoViewController alloc] initWithProperNib];
	editVC.userID = user.uuid;
	editVC.isInPopover = isInPopover;
    editVC.delegate = self;

	[self.navigationController pushViewController:editVC animated:NO];
	editUserInfoVC = editVC;
}


- (void)saveButtonTapped:(id)sender
{
	DDLogAutoTrace();
	
	if (!userNeedsSaving) return;
	
	[STDatabaseManager addRemoteUserToDB:user.jid
	                        pubKeysArray:tempPubKeyArray
	                           networkID:STDatabaseManager.currentUser.networkID
	                            hasPhone:user.hasPhone
	                        canSendMedia:user.canSendMedia
	                           firstName:user.web_firstName
	                            lastName:user.web_lastName
	                       compositeName:user.web_compositeName
                               avatarURL:user.web_avatarURL
	                     completionBlock:^(NSError *error, NSString *uuid)
	{
		// update the UI
		userID = uuid;
		[self reloadView:YES forceReload:YES];
		
		// was there an AB entry
		if (user.abRecordID)
		{
			YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
			[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
				
				STUser* user1 = [transaction objectForKey:uuid inCollection:kSCCollection_STUsers];
				if(user1)
				{
					user1 = [user1 copy];
					user1.lastUpdated = [NSDate date];
					user1.abRecordID = user.abRecordID;
					user1.isAutomaticallyLinkedToAB = user.isAutomaticallyLinkedToAB;
					
					[transaction setObject:user1
					                forKey:user1.uuid
					          inCollection:kSCCollection_STUsers];
				}
			}];
		}
	}];
}

- (void)popToConversation:(NSString *)conversationId
{
	DDLogAutoTrace();
	
	STAppDelegate.conversationViewController.selectedConversationId = conversationId;
	
	if (AppConstants.isIPhone)
	{
		UINavigationController *nav = STAppDelegate.conversationViewController.navigationController;
		
		// Figure out if there's a messagesViewController on the stack.
		
		MessagesViewController *messagesViewController = nil;
		
		NSMutableArray *viewControllers = [nav.viewControllers mutableCopy];
		while ([viewControllers count] > 1)
		{
			UIViewController *viewController = [viewControllers lastObject];
			
			if ([viewController isKindOfClass:[MessagesViewController class]])
			{
				messagesViewController = (MessagesViewController *)viewController;
				break;
			}
			else
			{
				[viewControllers removeLastObject];
			}
		}
		
		// Figure out what the revealController is displaying
		
		BOOL frontIsMain = STAppDelegate.revealController.frontViewController == STAppDelegate.mainViewController;
		
		// Provide the proper animation
		
		if (messagesViewController)
		{
			if (frontIsMain)
			{
				[nav popToViewController:messagesViewController animated:YES];
				messagesViewController.conversationId = conversationId;
			}
			else
			{
				[nav popToViewController:messagesViewController animated:NO];
				messagesViewController.conversationId = conversationId;
				
				[STAppDelegate.revealController setFrontViewController:STAppDelegate.mainViewController animated:YES];
			}
		}
		else
		{
			messagesViewController = [STAppDelegate createMessagesViewController];
			messagesViewController.conversationId = conversationId;
			
			if (frontIsMain)
			{
				[nav popToRootViewControllerAnimated:NO];
				[nav pushViewController:messagesViewController animated:NO];
			}
			else
			{
				[nav popToRootViewControllerAnimated:NO];
				[nav pushViewController:messagesViewController animated:NO];
				
				[STAppDelegate.revealController setFrontViewController:STAppDelegate.mainViewController animated:YES];
			}
		}
	}
	else
	{
		[STAppDelegate.revealController setFrontViewController:STAppDelegate.mainViewController animated:YES];
        
		if ([delegate respondsToSelector:@selector(userInfoViewController:needsDismissPopoverAnimated:)]) {
			[delegate userInfoViewController:self needsDismissPopoverAnimated:YES];
		}
     }
}

- (IBAction)textButtonTapped:(id)sender
{
	DDLogAutoTrace();
	
	if (user == nil)
	{
		DDLogWarn(@"Unable to send text: user == nil");
		return;
	}
	
	// Todo:
	//
	// I don't think this code was working properly (before I commented it out).
	// Here's what needs to happen:
	//
	// - Try to fetch the existing STConversation fir the user
	// - If the STConversation exists, then we can pop to it
	// - Otherwise we need to create an STConversation object, add it to the database,
	//   !! and be sure to set it's isNewMessage property to YES !!
	//
	// (MessagesViewController will do the right thing if the isNewMessage property is YES.)
	//
	// -RH
	
//	MessageStream *ms = [STAppDelegate messageStreamForUser:STDatabaseManager.currentUser];
//
//	NSString *conversationId = [ms conversationIDWithJidName:user.jid];
//	if (conversationId)
//	{
//		[self popToConversation:conversationId];
//	}
//	else
//	{
//		// Todo: Rather than creating the conversation,
//		// perhaps we should create a (STConversation.isNewMessage == YES),
//		// and display the MessagesViewController in new message mode,
//		// and have the to field pre-filled for the user.
//
//		[ms createConversationWithJid:user.jid
//		              completionBlock:^(NSString *newConID, NSError *error)
//		{
//			if (!error) {
//				[self popToConversation:newConID];
//			}
//		}];
//	}
}

- (IBAction)callButtonTapped:(id)sender
{
	DDLogAutoTrace();
	
	if (user && user.jid)
    {
		NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"silentphone:%@", user.jid.user]];
		
		[[UIApplication sharedApplication] openURL:url];
	}
}

- (IBAction)keyInfoTapped:(id)sender
{
    DDLogAutoTrace();
	
	// Todo ??
}

- (IBAction)keyButtonTapped:(id)sender
{
  	DDLogAutoTrace();
	
	if (user.isRemote) return;
	
	NSString *name = user.userName;
	if (name == nil) {
		return;
	}
	
    self.navigationItem.rightBarButtonItem = NULL;
	
    [OHActionSheet showFromVC:self 
                       inView:self.view
                        title:NSLocalizedString(@"Create and Upload new Public Key", @"Create New Public Key")
            cancelButtonTitle:NSLS_COMMON_CANCEL
       destructiveButtonTitle:NSLS_COMMON_NEW_KEYS
            otherButtonTitles:nil
                   completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                       NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
                       
                       if ([choice isEqualToString:NSLS_COMMON_NEW_KEYS])
                       {
                           [keyButton setHidden:YES];
                           [keyActivity startAnimating];
                           
                           NSUInteger publicKeysToKeep = [STPreferences publicKeysToKeep];
                           
                           [[ExpireManager sharedInstance] removePrivateKeysForUserUUID:user.uuid
                                                                           deleteKeyIDs:@[]
                                                                             keysToKeep:publicKeysToKeep
                                                                     shouldCreateNewOne:YES        // creates a new key
                                                                        completionBlock:^(NSError *error, NSString *newKeyUUID)
                            {
                                [keyActivity stopAnimating];
                                [keyButton setHidden:NO];
                                
                                [self reloadView:YES forceReload:YES];
                            }];
                       }
	}];
}

- (IBAction)checkButtonTapped:(id)sender
{
	DDLogAutoTrace();
	
	XMPPJID *jid = user.jid;
	if (jid == nil) {
		return;
	}
	
    self.navigationItem.rightBarButtonItem = NULL;
    
	NSString *theUserID = user.uuid; // Capture it in-case the userID changes before the completionBlock executes
	
    [checkButton setHidden:YES];
    [activity startAnimating];
  
	if (user.isRemote)
	{
		[[SCAccountsWebAPIManager sharedInstance] getUserInfo:jid
		                                         forLocalUser:STDatabaseManager.currentUser
		                                      completionBlock:^(NSError *error, NSDictionary *infoDict)
		{
			if (!error && infoDict)
			{
				NSDictionary *parsedDict = [[SCAccountsWebAPIManager sharedInstance] parseUserInfoResult:infoDict];
				
				BOOL hasPhone     = [[parsedDict objectForKey:kUserInfoKey_hasPhone] boolValue];
				BOOL canSendMedia = [[parsedDict objectForKey:kUserInfoKey_canSendMedia] boolValue];
				
				NSString *avatar_url = [parsedDict objectForKey:kUserInfoKey_avatarUrl];
				
				NSArray *pubKeysArray = [parsedDict objectForKey:kUserInfoKey_pubKeys];
				
				NSString *firstName     = [parsedDict objectForKey:kUserInfoKey_firstName];
				NSString *lastName      = [parsedDict objectForKey:kUserInfoKey_lastName];
				NSString *compositeName = [parsedDict objectForKey:kUserInfoKey_displayName];
				
				if (!theUserID)
                {
					user.web_avatarURL  = avatar_url;
                    user.web_firstName  = firstName;
                    user.web_lastName   = lastName;
                    user.web_compositeName = compositeName;
                    user.hasPhone = hasPhone;
                    user.canSendMedia = canSendMedia;
                    
                    tempPubKeyArray = pubKeysArray;

                    [activity stopAnimating];
                    [checkButton setHidden:NO];

                    [self reloadView:NO forceReload:NO];
                }
                else
                {
                    [STDatabaseManager updateUserToDB: theUserID
                                         pubKeysArray: pubKeysArray
                                             hasPhone: hasPhone
                                         canSendMedia: canSendMedia
                                            firstName: firstName
                                             lastName: lastName
                                        compositeName: compositeName
                                            avatarURL: avatar_url
                                      completionBlock:^(NSError *error, NSString *uuid)
                    {
                        
                        [self reloadView:NO forceReload:NO];
                    }];
                
                    if ([theUserID isEqualToString:userID])
                    {
                        [activity stopAnimating];
                        [checkButton setHidden:NO];
                    }
                }
            }
            else
            {
                
                // connect error?
                
                [activity stopAnimating];
                [checkButton setHidden:NO];
                
                [self reloadView:NO forceReload:NO];

            }
  		}];
    }
    else
    {
        BOOL wasExpired = user.subscriptionHasExpired;

		[[STUserManager sharedInstance] updateMyUserInfo:user
		                                 completionBlock:^(NSError *error, NSString *uuid)
		{
            if (error)
            {
                [activity stopAnimating];
                [checkButton setHidden:NO];

                [[[UIAlertView alloc] initWithTitle:NSLS_COMMON_NOT_AUTHORIZED
                                            message: error.localizedDescription
                                           delegate:nil
                                  cancelButtonTitle:NSLS_COMMON_OK
                                  otherButtonTitles:nil] show];

            }
            else
            {
                // update User record
                [dbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
                    
                    user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
                }];
                
                [activity stopAnimating];
                [checkButton setHidden:NO];
                
                // if the user was expired, check if they arent any more,
                // and reconnect.
                
                if (wasExpired && !user.subscriptionHasExpired && user.isEnabled && user.isActivated)
                {
                    [[STAppDelegate messageStreamForUser:user] connect];
                }
   
            }
								  
			// force reload
			[self reloadView:NO forceReload:YES];
		}];
	}
}


- (IBAction)addressBookButtonTapped:(id)sender
{
	DDLogAutoTrace();
	
    if(!userID)
        return;
    
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
		[[AddressBookManager sharedInstance] updateUser:userID withABRecordID:kABRecordInvalidID isLinkedByAB:NO];
		
		user = NULL;
		userKey = NULL;
		tempPubKeyArray = NULL;
  	}
}

- (void)expireLabelTapped:(UIGestureRecognizer *)gestureRecognizer
{
    if( user.autorenew) return;
    
    
#if SUPPORT_IN_APP_RENEWAL
    [self subscribeButtonTapped: self];
#endif
    
}

- (IBAction)subscribeButtonTapped:(id)sender
{
	NSArray *productList = [[StoreManager sharedInstance] allActiveProductsSortedByPrice];
	if ([productList count] == 0)
		return; // nothing to buy!
	
    NSDate *expiresDate = user.subscriptionExpireDate;
    NSString *frmt =  NSLocalizedString(@"Your Silent Circle subscription expires on %@. Do you wish to buy more?",
                                        @"Silent Circle subscription expires");
    
   
    if (![SKPaymentQueue canMakePayments])
    {
		NSString *title = NSLocalizedString(@"Sorry!", @"Sorry!");
		NSString *msg = NSLocalizedString(@"In App purchases are restricted on this device. Check your Settings.",
		                                  @"In App purchases are restricted on this device.");
		
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title
		                                                    message:msg
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
        return;
    }
 
	NSMutableArray *titleList = [NSMutableArray arrayWithCapacity:[productList count]];
	for (ProductVO *productVO in productList)
		[titleList addObject:productVO.skProduct.localizedTitle];
	
    [OHActionSheet showFromVC:self 
                       inView:self.view
                        title:[NSString stringWithFormat:frmt, expiresDate.whenString]
            cancelButtonTitle:NSLS_COMMON_CANCEL
       destructiveButtonTitle:NULL
            otherButtonTitles:titleList
                   completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                       if (buttonIndex >= [productList count])
                           return; // cancel button
                       
                       ProductVO *productVO = [productList objectAtIndex:buttonIndex];
                       if (productVO != nil)
                       {
                           // put up a spinner HUD view
                           
                           HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
                           //			 HUD.delegate = self;
                           HUD.mode = MBProgressHUDModeIndeterminate;
                           HUD.labelText =  NSLocalizedString(@"Processing", @"Processing");
                           
                           [[StoreManager sharedInstance] startPurchaseProductID:productVO.productID
                                                                         forUser:user
                                                                 completionBlock:^(NSError *error, NSDictionary *infoDict) {
                                                                     if (error != nil) {
                                                                         [MBProgressHUD hideHUDForView:self.view 
                                                                                              animated:YES];
                                                                         
                                                                         // remove spinner HUD view
                                                                         [self reloadView:YES forceReload:YES];
                                                                     }
                                                                     
                                                                     // otherwise don't do anything, process has only started
                                                                     // TODO: wait for notification and remove spinner
                                                                 }];
                       }
                   }];
}

#pragma mark - mapKit delegate

- (void) reloadMap
{
     // Note: SCDateFormatter caches the dateFormatter for us automatically
    NSDateFormatter *formatter =    [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterMediumStyle
                                                                      timeStyle:NSDateFormatterShortStyle];
    

    [dropPins removeAllObjects];
    
    MKMapType mapType = [STPreferences preferedMapType];
    if(mapType != mapView.mapType )
        mapView.mapType = mapType;
    
    // force refresh of drop pin
    for (id<MKAnnotation> annotation in mapView.annotations) {
        [mapView removeAnnotation:annotation];
    }

    if(user.lastLocation != NULL)
    {
         SCMapPin* pin  = [[SCMapPin alloc] initWithLocation: user.lastLocation
                                                      title: user.displayName
                                                   subTitle: [formatter stringFromDate:user.lastLocation.timestamp]
                                                     image : NULL
                                                       uuid: user.uuid] ;

        [dropPins addObject:pin];
        
        
        if(isShowingMyLocation)
        {
            STUser* me = STDatabaseManager.currentUser;
            if(me.lastLocation)
            {
                SCMapPin* pin  = [[SCMapPin alloc] initWithLocation: me.lastLocation
                                                              title: me.displayName
                                                           subTitle: [formatter stringFromDate:me.lastLocation.timestamp]
                                                             image : NULL
                                                               uuid: me.uuid] ;
                
                [dropPins addObject:pin];
            }
            
        }
    }
    
    [mapView  addAnnotations:dropPins];
    
    for(SCMapPin* dropPin in dropPins)
    {
        if([dropPin.uuid isEqualToString:user.uuid])
        {
            [mapView  selectAnnotation:dropPin animated:YES];
            break;
        }
    }
    
    [mapView zoomToFitAnnotations:YES];
    

}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapViewIn
{
    // force refresh of drop pin, we need to do this to keep the selected annotation data in the the view
    
    for (id<MKAnnotation> annotation in mapView.annotations) {
        [mapViewIn removeAnnotation:annotation];
    }
    
    [mapViewIn  addAnnotations:dropPins];
    
    for(SCMapPin* dropPin in dropPins)
    {
        if([dropPin.uuid isEqualToString:user.uuid])
        {
            [mapView  selectAnnotation:dropPin animated:YES];
            break;
        }
    }
    [mapViewIn zoomToFitAnnotations:YES];
    
}



- (MKAnnotationView *)mapView:(MKMapView *)mapViewIn viewForAnnotation:(id<MKAnnotation>)annotation {
    MKAnnotationView *annotationView = [mapViewIn dequeueReusableAnnotationViewWithIdentifier:@"MapVC"];
    if (!annotationView) {
        annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"MapVC"];
        annotationView.canShowCallout = YES;
		//        annotationView.leftCalloutAccessoryView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 30, 30)];
        annotationView.rightCalloutAccessoryView = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        // could put a rightCalloutAccessoryView here
    } else {
        annotationView.annotation = annotation;
		//       [(UIImageView *)annotationView.leftCalloutAccessoryView setImage:nil];
    }
	
    return annotationView;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
 	
    SCMapPin* dropPin = view.annotation;
    
	NSString *coordString = [NSString stringWithFormat:@"%@: %f\r%@: %f\r%@: %g",
							 NSLocalizedString(@"Latitude",@"Latitude"), dropPin.coordinate.latitude,
							 NSLocalizedString(@"Longitude",@"Longitude"), dropPin.coordinate.longitude,
							 NSLocalizedString(@"Altitude",@"Altitude"), dropPin.altitude];
    
    [OHActionSheet showFromVC:self 
                       inView:self.view
                        title:[NSString stringWithFormat: NSLocalizedString(@"Coordinates for %@ ",@"Coordinatesfor %@"), dropPin.title]
            cancelButtonTitle:NSLS_COMMON_CANCEL
       destructiveButtonTitle:NULL
            otherButtonTitles:@[NSLocalizedString(@"Open in Maps",@"Open in Maps"), NSLocalizedString(@"Copy",@"Copy")]
                   completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                       
                       switch(buttonIndex)
                       {
                           case 0:
                           {
                               MKPlacemark *theLocation = [[MKPlacemark alloc] initWithCoordinate:dropPin.coordinate addressDictionary:nil];
                               MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:theLocation];
                               
                               if ([mapItem respondsToSelector:@selector(openInMapsWithLaunchOptions:)]) {
                                   [mapItem setName:dropPin.title];
                                   
                                   [mapItem openInMapsWithLaunchOptions:nil];
                               }
                               else {
                                   NSString *latlong = [NSString stringWithFormat: @"%f,%f", dropPin.coordinate.latitude, dropPin.coordinate.longitude];
                                   NSString *url = [NSString stringWithFormat: @"http://maps.google.com/maps?ll=%@",
                                                    [latlong stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                                   [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
                                   
                               }
                           }
                               break;
                               
                           case 1:
                           {
                               UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                               NSMutableDictionary *items = [NSMutableDictionary dictionaryWithCapacity:1];
                               NSString *copiedString = [NSString stringWithFormat:@"%@ %@:\r%@", NSLocalizedString(@"Location of", @"Location of"), dropPin.title, coordString];
                               [items setValue:copiedString forKey:(NSString *)kUTTypeUTF8PlainText];
                               pasteboard.items = [NSArray arrayWithObject:items];
                               
                           }
                               break;
                               
                           default:
                               break;
                       }
                       
                   }];
    
}


- (IBAction)showMapOptions:(id)sender
{
    DDLogAutoTrace();
    
    
#define NSLS_COMMON_Map NSLocalizedString(@"Map", @"Map")
#define NSLS_COMMON_Satellite NSLocalizedString(@"Satellite", @"Satellite")
#define NSLS_COMMON_Hybrid NSLocalizedString(@"Hybrid", @"Hybrid")
#define NSLS_COMMON_hideMe NSLocalizedString(@"Don't show my location", @"Don't show my location")
#define NSLS_COMMON_ShowMe NSLocalizedString(@"Show my location", @"Show my location")
    
 	NSMutableArray* choices = @[].mutableCopy;
    
    switch (mapView.mapType) {
        case MKMapTypeStandard :
            [choices addObjectsFromArray:@[NSLS_COMMON_Satellite, NSLS_COMMON_Hybrid]];
            break;
   
        case MKMapTypeSatellite :
            [choices addObjectsFromArray:@[NSLS_COMMON_Map, NSLS_COMMON_Hybrid]];
            break;

        case MKMapTypeHybrid :
            [choices addObjectsFromArray:@[NSLS_COMMON_Map, NSLS_COMMON_Satellite]];
            break;
     }
    
    if(![STDatabaseManager.currentUser.uuid isEqualToString:user.uuid]
        && STDatabaseManager.currentUser.lastLocation)
    {
        [choices addObject:isShowingMyLocation?NSLS_COMMON_hideMe:NSLS_COMMON_ShowMe];
    }
    else
    {
        isShowingMyLocation = NO;
    }
    
// FIXME: !   - disabling Showing My Location  feature  for now
//    isShowingMyLocation = NO;

    [OHActionSheet showFromVC:self 
                       inView:self.view
                        title:NSLocalizedString(@"Change Map Display Options", @"Change Map Display Options")
            cancelButtonTitle:NSLS_COMMON_CANCEL
       destructiveButtonTitle:NULL
            otherButtonTitles:choices
                   completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                       NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
                       
                       if ([choice isEqualToString:NSLS_COMMON_Map])
                       {
                           mapView.mapType = MKMapTypeStandard;
                       }
                       else if ([choice isEqualToString:NSLS_COMMON_Satellite])
                       {
                           mapView.mapType = MKMapTypeSatellite;
                           
                       }
                       else if ([choice isEqualToString:NSLS_COMMON_Hybrid])
                       {
                           mapView.mapType = MKMapTypeHybrid;
                           
                       }
                       else if ([choice isEqualToString:NSLS_COMMON_hideMe])
                       {
                           isShowingMyLocation = NO;
                           [self reloadMap];
                           
                       }
                       else if ([choice isEqualToString:NSLS_COMMON_ShowMe])
                       {
                           isShowingMyLocation = YES;
                           [self reloadMap];
                       }
                       
                       [STPreferences setPreferedMapType:mapView.mapType];
                       
                   }];
    
 }

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - EditUserInfoViewControllerDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)editUserInfoViewController:(EditUserInfoViewController *)sender willDeleteUserID:(NSString *)userID
{
	DDLogAutoTrace();
	
	editUserInfoVC.delegate = nil;
	editUserInfoVC = nil;
	
	if (self.isModal)
	{
		[self dismissViewControllerAnimated:YES completion:nil];
	}
	else
	{
		[self setUserID:nil];
		
		if (self.isInPopover)
		{
			if ([delegate respondsToSelector:@selector(userInfoViewController:needsDismissPopoverAnimated:)]) {
				[delegate userInfoViewController:self needsDismissPopoverAnimated:YES];
			}
		}
		else
		{
			[self.navigationController popViewControllerAnimated:NO];  // Pop EditUserInfoViewController
			[self.navigationController popViewControllerAnimated:YES]; // Pop UserInfoViewController
		}
	}
}

- (void)editUserInfoViewController:(EditUserInfoViewController *)sender didCreateNewUserID:(NSString *)newUserID
{
	DDLogAutoTrace();
	
	[self setUserID:newUserID];
}

- (void)editUserInfoViewController:(EditUserInfoViewController *)sender willSaveUserImage:(UIImage *)image
{
	DDLogAutoTrace();
	
	userImageOverride = image;
	[self reloadView:YES forceReload:NO];
}

- (void)editUserInfoViewController:(EditUserInfoViewController *)sender didSaveUserImage:(UIImage *)image
{
	DDLogAutoTrace();
	
	userImageOverride = nil;
	[self reloadView:YES forceReload:NO];
}

- (void)editUserInfoViewControllerNeedsDismiss:(EditUserInfoViewController *)sender
{
	DDLogAutoTrace();
	
	[self.navigationController popViewControllerAnimated:NO];
	editUserInfoVC = nil;
}

- (void)editUserInfoViewControllerDidDeleteUserImage:(EditUserInfoViewController *)sender
{
    [self checkButtonTapped:checkButton];
};

- (void)editUserInfoViewController:(EditUserInfoViewController *)sender
              needsPushImagePicker:(UIImagePickerController *)imagePicker
{
	DDLogAutoTrace();
	
	if ([delegate respondsToSelector:@selector(userInfoViewController:needsPushImagePicker:)]) {
		[delegate userInfoViewController:self needsPushImagePicker:imagePicker];
	}
}

- (void)editUserInfoViewController:(EditUserInfoViewController *)sender
               needsPopImagePicker:(UIImagePickerController *)imagePicker
{
	DDLogAutoTrace();
	
	if ([delegate respondsToSelector:@selector(userInfoViewController:needsPopImagePicker:)]) {
		[delegate userInfoViewController:self needsPopImagePicker:imagePicker];
	}
}

- (void)editUserInfoViewController:(EditUserInfoViewController *)sender
          needsHidePopoverAnimated:(BOOL)animated
{
	DDLogAutoTrace();
	
	if ([delegate respondsToSelector:@selector(userInfoViewController:needsHidePopoverAnimated:)]) {
		[delegate userInfoViewController:self needsHidePopoverAnimated:animated];
	}
}

- (void)editUserInfoViewController:(EditUserInfoViewController *)sender
          needsShowPopoverAnimated:(BOOL)animated
{
	DDLogAutoTrace();
	
	if ([delegate respondsToSelector:@selector(userInfoViewController:needsShowPopoverAnimated:)]) {
		[delegate userInfoViewController:self needsShowPopoverAnimated:animated];
	}
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
	
	[[AddressBookManager sharedInstance] updateUser:userID withABRecordID:abRecordID isLinkedByAB:NO];
	[self dismissViewControllerAnimated:YES completion:NULL];
	
	user = NULL;
	userKey = NULL;
	tempPubKeyArray = NULL;
}

#pragma mark In App Purchases

- (void)purchaseTransactionComplete:(NSNotification *)notification
{
	NSDictionary* dict = notification.object;
//	SKPaymentTransaction* paymentTransaction = [dict objectForKey:  @"paymentTransaction" ];
    NSError* error = [dict objectForKey:  @"error" ];
    
    
    if(error)
    {
        if(error.code != SKErrorPaymentCancelled)
        {
            
            [STAppDelegate showAlertWithTitle:  NSLocalizedString(@"Can not complete purchase", @"Can not complete purchase")
                                      message: error.localizedDescription];
        }
        
        // remove spinner HUD view
        [MBProgressHUD hideHUDForView:self.view animated:YES];
       
    }
    else
    {
        // refresh the usr information.
        HUD.labelText =  NSLocalizedString(@"Updating", @"Updating");
        
        [self checkButtonTapped:checkButton];
    }
}

@end
