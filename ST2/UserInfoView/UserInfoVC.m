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
#import "UserInfoVC.h"

#import "AddressBookManager.h"
#import "AppConstants.h"
#import "AppDelegate.h"
#import "AppTheme.h"
#import "AvatarManager.h"
#import "HelpDetailsVC.h"
#import "SCTHelpManager.h"
#import "EditUserInfoDelegate.h"
#import "ECPhoneNumberFormatter.h"
#import "MessageStreamManager.h"
#import "MBProgressHUD.h"
#import "EditUserInfoVC.h"
#import "OHActionSheet.h"
#import "OHAlertView.h"
#import "SCWebAPIManager.h"
#import "SCCalendar.h"
#import "SCDateFormatter.h"
#import "SCMapImage.h"
#import "SCTHelpManager.h"
#import "SilentTextStrings.h"
#import "StoreManager.h"
#import "SCTAvatarView.h"
#import "STConversation.h"
#import "STDynamicHeightView.h"
#import "STLocalUser.h"
#import "STLogging.h"
#import "STPublicKey.h"
#import "STPreferences.h"
#import "STUser.h"
#import "STUserManager.h"
#import "XMPPJID+AddressBook.h"

// Catetgories
#import "MKMapView+SCUtilities.h"
#import "NSDate+SCDate.h"
#import "NSString+SCUtilities.h"
#import "UIImage+ImageEffects.h"
#import "UIImage+maskColor.h"
#import "UIImage+Thumbnail.h"

// Libraries
#import <StoreKit/StoreKit.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>
#import <MapKit/MapKit.h>
#import <MobileCoreServices/UTCoreTypes.h>

// Log levels: off, error, warn, info, verbose
#if DEBUG && eric_turner
static const int ddLogLevel = LOG_LEVEL_WARN; //LOG_LEVEL_VERBOSE /* 00001111 */ | LOG_FLAG_TRACE /* 00010000 */;
#elif DEBUG
static const int ddLogLevel = LOG_LEVEL_INFO;
#else
static const int ddLogLevel = LOG_LEVEL_WARN;
#endif

static const CGFloat kAvatarDiameter = 60.0; // to match avatarView xib imageView size


@interface UserInfoVC () <MKMapViewDelegate, EditUserInfoDelegate, SCTAvatarViewDelegate>
{
    IBOutlet UILabel  *_lblUserName;
    IBOutlet UIButton *_btnConversation;

    IBOutlet UIButton *_btnPhone;
    IBOutlet UILabel  *_lblPhone;

    IBOutlet UIButton *_btnSubscribe;
    IBOutlet UILabel  *_lblSubscription;

    IBOutlet UILabel  *_lblAddressBook;

    IBOutlet UILabel    *_lblNotes;
    IBOutlet UITextView *_userNotes;
    
    IBOutlet MKMapView *_mapView;
    IBOutlet UIButton  *_btnMapViewPageCurl;

    UIImage *_editSessionImage; // replaces userImageOverride
    
    IBOutlet UIRefreshControl *_refreshControl;
    XMPPJID *_userJID;
    
    BOOL            _hasMap;    
    NSMutableArray *_dropPins;
    
    MBProgressHUD  *_HUD;

    BOOL _isShowingMyLocation;

    NSArray *_tempPubKeyArray;

    STPublicKey *_userKey;


// Constraints
    IBOutlet NSLayoutConstraint *_lblPhoneTopConstraint;
    CGFloat                      _lblPhoneTopConstraintHeight;
    CGFloat                      _lblPhoneHeight;
    IBOutlet NSLayoutConstraint *_btnSubscribeTopConstraint;
    CGFloat                      _btnSubscribeTopConstraintHeight;
    CGFloat                      _btnSubscribeHeight;
    IBOutlet NSLayoutConstraint *_lblABTopConstraint;
    CGFloat                      _lblABTopConstraintHeight;
    CGFloat                      _lblABHeight;
    IBOutlet NSLayoutConstraint *_mapTopConstraint;
    CGFloat                      _mapTopConstraintHeight;
    CGFloat                      _mapHeight;
}

// DebugView
@property(nonatomic, strong) NSMutableString   *debugInfo;
@property(nonatomic, weak) IBOutlet UITextView *debugNotes;
@property(nonatomic, weak) IBOutlet UIView     *debugView;
@property(nonatomic, weak) IBOutlet UILabel    *lblNetwork;
@property(nonatomic, weak) IBOutlet UIView     *debugHorizontalRule;

@end


@implementation UserInfoVC


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Init & Dealloc
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Note: When the super intializer loads the avatarView, viewDidLoad is called before it returns. Therefore, where
// normally a lot of configuration happens in viewDidLoad, it must be done here in the initializer after the super
// initializer returns.
- (instancetype)initWithUser:(STUser *)aUser
{
	DDLogAutoTrace();
    
    self = [super initWithUser:aUser];
    if (!self)
        return nil;
    
    _dropPins = [[NSMutableArray alloc] init];
        

#if SUPPORT_IN_APP_RENEWAL
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(purchaseTransactionComplete:)
                                                 name:kStoreManager_TransactionCompleteNotification
                                               object:nil];
#endif
    
    return self;
}

// TESTING
- (NSString *)viewLogWithLabel:(NSString *)lbl
{
    NSString *conFrame = NSStringFromCGRect(self.containerView.frame);
    NSString *scrollSize = NSStringFromCGSize(self.scrollView.contentSize);
    NSString *debugFrame = NSStringFromCGRect(_debugView.frame);
    NSString *str = [NSString stringWithFormat:@"\n%@\ncontainerFrame: %@\nscrollSize: %@\ndebugFrame: %@",
                     lbl,conFrame,scrollSize,debugFrame];
    return str;
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
    DDLogTrace(@"%@ - user.displayName:%@", THIS_METHOD, aUser.displayName);

    _user = aUser;
    
    if (![_userJID isEqualToJID:aUser.jid] && !_refreshControl.isRefreshing)
    {
        [self setupRefreshControl];
    }
    
    _userJID = aUser.jid;
    
    if ([self isViewLoaded])
	{
		[self updateAllViews];
	}
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Initial Views Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)initialViewConfiguration
{
    DDLogAutoTrace();

    // REMOVE debug view if NOT DEBUG build
#ifndef DEBUG
    [_debugView removeFromSuperview];
    self.debugView = nil;
#else
    _debugView.backgroundColor = self.view.backgroundColor;
#endif

    if ([[UIScreen mainScreen] scale] > 1.0)
    {
        // On retina devices, the contentScaleFactor of 2 results in our horizontal rule
        // actually being 2 pixels high. Fix it to be only 1 pixel (0.5 points).        
        NSLayoutConstraint *heightConstraint;        
        heightConstraint = [self heightConstraintFor:_debugHorizontalRule];
        heightConstraint.constant = (heightConstraint.constant / [[UIScreen mainScreen] scale]);        
        [_debugHorizontalRule setNeedsUpdateConstraints];
    }

    // Capture original constraint constant values
    [self cacheInitialConstraintValues];
    
    // Setup barButtons once (moved from upateAllViews so ContactsVC can maintain bar buttons)
    [self updateBarButtons];

    // Display/configure Help/Info button in avatarView
    [self.avatarView showInfoButtonForClass:[self class]];

    [self setupRefreshControl];
}

- (void)setupRefreshControl
{
    DDLogAutoTrace();

//    if (_user && !_user.isTempUser) {
    if (_user) {
        
        if (_refreshControl)
            [self removeRefreshControl];
        
        // add a refresh control on top of the scroll view to allow user to refresh information
        UIRefreshControl *rc = [[UIRefreshControl alloc] init];
        rc.tintColor = self.theme.appTintColor;    
        [rc addTarget:self action:@selector(refreshControlChanged:) forControlEvents:UIControlEventValueChanged];
        rc.attributedTitle = [[NSAttributedString alloc] initWithString:
                              [NSString stringWithFormat: NSLocalizedString(@"Updating information about %@…",
                                                                            @"Updating information about %@…"),
                               _user.jid.user]];
        
        CGRect conFrame = self.refreshControlContainerView.frame;
        rc.frame = CGRectMake(0, 0, conFrame.size.width, conFrame.size.height);
        rc.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        rc.translatesAutoresizingMaskIntoConstraints = YES;
        
        
        [self.refreshControlContainerView addSubview:rc];
    
        [self.scrollView needsUpdateConstraints];
        
        _refreshControl = rc;

        // TEST
//        self.refreshControlContainerView.backgroundColor = [UIColor greenColor];
//        _refreshControl.layer.backgroundColor = [UIColor redColor].CGColor;
        _refreshControl.layer.backgroundColor = self.scrollView.backgroundColor.CGColor;
    }
}

- (void)removeRefreshControl
{
    [_refreshControl removeFromSuperview];
    _refreshControl = nil;
}

- (void)cacheInitialConstraintValues
{
    DDLogAutoTrace();
    
    _lblPhoneTopConstraintHeight = _lblPhoneTopConstraint.constant;
    _lblPhoneHeight = [self heightConstraintFor:_lblPhone].constant;
    _btnSubscribeTopConstraintHeight = _btnSubscribeTopConstraint.constant;
    _btnSubscribeHeight = [self heightConstraintFor:_btnSubscribe].constant;
    _lblABTopConstraintHeight = _lblABTopConstraint.constant;
    _lblABHeight = [self heightConstraintFor:_lblAddressBook].constant;
    _mapTopConstraintHeight = _mapTopConstraint.constant;
    _mapHeight = [self heightConstraintFor:_mapView].constant;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - View Lifecycle
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad
{
    DDLogAutoTrace();
    
    // Set this flag before calling super
    self.loadAvatarViewFromNib = YES;

    // This will setup the avatarView
    [super viewDidLoad];
    
    [self initialViewConfiguration];
    
    // Copying iOS on this.
    // They don't use a title, most likely because it visually distracts from the user name
    // displayed in the view controller, which should be the primary focus.
    self.title = nil;
    self.navigationController.navigationBar.translucent = NO; // to prevent underlapping
    
    _mapView.hidden = YES;
            
    [self updateAllViews];
    
//    DDLogRed(@"%@",[self viewLogWithLabel:@"END VIEWDIDLOAD:"]);
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
        __weak typeof (self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [weakSelf.scrollView flashScrollIndicators];
        });
    }
    
//    DDLogRed(@"%@",[self viewLogWithLabel:@"END VIEWDIDAPPEAR:"]);
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Layout
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateBarButtons
{
    DDLogAutoTrace();
	
	// Edge case(s):
	//
	// - _user is nil because Silent Contacts has zero users & zero local accounts (iPad)
	//   In this case, we shouldn't display the Edit button.
	
	if (_user.isTempUser || !_user.isSavedToSilentContacts)
	{
		// A tempUser is any user that hasn't been explicitly saved.
		// For example, a user who has just sent us a message,
		// but we haven't explicitly saved them to our contacts list.
		
		self.navigationItem.rightBarButtonItem =
		  [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
		                                                target:self
		                                                action:@selector(saveButtonTapped:)];
	}
	else if (_user)
	{
        self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                      target:self
                                                      action:@selector(editButtonTapped:)];
	}

    if (AppConstants.isIPhone && self == self.navigationController.viewControllers[0]) 
    {
        self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(handleDoneTap:)];
    }
}

- (IBAction)handleDoneTap:(id)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - View Update Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)updateAllViews
{
    DDLogAutoTrace();
    
    [super updateAllViews];
    
    if (nil == _editSessionImage)
        [self.avatarView updateUser:_user];
    
    [self updateConversationButton];
    [self updatePhoneView];
    [self updateUsernameView];
    [self updateSubscriptionView];
    [self updateNotesView];
    [self updateAddressBookView];
    [self updateMapView];
    [self updateDebugView];
	[self updateBarButtons];
    [self updateLayout];
	
	// Note: We need to call [self updateBarButtons] too.
	// After saving a user, the "Save" button should change to "Edit".
	//
	// -RH: 28 Oct, 2014
}

- (void)updateConversationButton
{
    DDLogAutoTrace();

	STLocalUser *currentUser = STDatabaseManager.currentUser;
	
    BOOL isNotCurrentUser = ![currentUser.uuid isEqualToString:_user.uuid];
    BOOL hasConversationId = (nil != [STPreferences selectedConversationIdForUserId:currentUser.uuid]);

    _btnConversation.enabled = (isNotCurrentUser && hasConversationId);
}

- (void)updatePhoneView
{
    DDLogAutoTrace();
    
    BOOL hasPhoneApp = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"silentphone:"]];
    _btnPhone.enabled = (hasPhoneApp && _user.isRemote);
    
    // the web API changed how it represented the phone numbers..  we have to maintain backward compatibility
    NSString *number = nil;
    NSArray *spNumbers = _user.spNumbers;
    if (spNumbers.count)
    {
        id firstItem = [spNumbers firstObject];
        if ([firstItem isKindOfClass: [NSDictionary class]])
            number = [firstItem  objectForKey:@"number"];
        else if ([firstItem isKindOfClass: [NSString class]])
            number = firstItem;
    }
    
    if (number)
    {
        ECPhoneNumberFormatter *formatter = [[ECPhoneNumberFormatter alloc] init];
        _lblPhone.text = [formatter stringForObjectValue:number];
        _lblPhone.hidden = NO;
    }
    else
    {
        _lblPhone.text = nil;
        _lblPhone.hidden = YES;
    }
}

- (void)updateUsernameView
{
    DDLogAutoTrace();
    
    XMPPJID *jid = _user.jid;
    if ([jid.domain isEqualToString:@"silentcircle.com"])
        _lblUserName.text = jid.user;
    else
        _lblUserName.text = _user.jid.bare;
}

- (void)updateSubscriptionView
{
    DDLogAutoTrace();
    
    if (!_user.isLocal)
	{
		_lblSubscription.text = nil;
		_lblSubscription.hidden = YES;
		_btnSubscribe.hidden = YES;
		
		return;
	}
	
	STLocalUser *_localUser = (STLocalUser *)_user;
	
	_lblSubscription.userInteractionEnabled = YES;
	_lblSubscription.hidden = NO;
	_btnSubscribe.hidden = NO;
	UIImage *subscribeIcon = [UIImage imageNamed:@"subscribe"];
	
	if (_localUser.isActivated)
	{
		if (_localUser.subscriptionHasExpired)
		{
			UIImage *tintIcon = [subscribeIcon maskWithColor:[UIColor redColor]];
			[_btnSubscribe setImage:tintIcon forState:UIControlStateNormal];
			
			NSString *msg = NSLocalizedString(@"Subscription has expired", @"subscription info in user details");
			
			_lblSubscription.text = msg;
			_lblSubscription.textColor = [UIColor redColor];
			
		}
		else if (_localUser.subscriptionAutoRenews)
		{
			UIImage *tintIcon = [subscribeIcon maskWithColor:[UIColor blackColor]];
			[_btnSubscribe setImage:tintIcon forState:UIControlStateNormal];
			
			if (_localUser.subscriptionExpireDate)
			{
				NSString *frmt = NSLocalizedString(@"Subscription renews: %@",
				                                   @"subscription info in user details");
				
				_lblSubscription.text = [NSString stringWithFormat:frmt, _localUser.subscriptionExpireDate.whenString];
			}
			else
			{
				NSString *msg = NSLocalizedString(@"Subscription automatically renews",
				                                  @"subscription info in user details");
				
				_lblSubscription.text = msg;
			}
			
			_lblSubscription.textColor = [UIColor blackColor];
			
		}
		else if (_localUser.subscriptionExpireDate)
		{
			UIColor *labelColor = [UIColor redColor];
			
			// dates till expired
			NSDateComponents *difference =
			[[SCCalendar cachedAutoupdatingCurrentCalendar] components:NSCalendarUnitDay
			                                                  fromDate:[NSDate date]
			                                                    toDate:_localUser.subscriptionExpireDate
			                                                   options:0];

			if ([difference day] < 10 && [difference day] > 1)
			{
				NSString *frmt = NSLocalizedString(@"Subscription expires in %d days", @"label text format");
				_lblSubscription.text = [NSString stringWithFormat:frmt, [difference day]];
			}
			else
			{
				NSString *frmt = NSLocalizedString(@"Renew before: %@", @"label text format");
				_lblSubscription.text = [NSString stringWithFormat:frmt, _localUser.subscriptionExpireDate.whenString];
			}
			
			if ([difference day] > 10)
			{
			#if SUPPORT_IN_APP_RENEWAL
				labelColor = self.theme.appTintColor;
			#else
				labelColor = [UIColor blackColor];
			#endif
			}
			else if ([difference day] > 3)
			{
			//	labelColor = [UIColor orangeColor];
			}
			
			UIImage *tintIcon = [subscribeIcon maskWithColor:labelColor];
			_lblSubscription.textColor = labelColor;
			[_btnSubscribe setImage:tintIcon forState:UIControlStateNormal];
		} else {
			// SC free
			_lblSubscription.text = nil;
			_lblSubscription.hidden = YES;
			_btnSubscribe.hidden = YES;
		}
	}
	else if (_localUser.provisonInfo)
	{
		_lblSubscription.text = NSLocalizedString(@"Waiting for payment",@"Waiting for payment");
		_lblSubscription.textColor = [UIColor orangeColor];
		
	}
	else // if (!_localUser.isActivated)
	{
		_lblSubscription.text = NSLocalizedString(@"Deactivated", @"Deactivated");
		_lblSubscription.textColor = [UIColor redColor];
	}
}


- (void)updateNotesView
{
    DDLogAutoTrace();
    
    STUser *usr = _user;
    BOOL useGray = (usr.notes.length && usr.sc_notes.length == 0 && usr.abRecordID != kABRecordInvalidID);
    _userNotes.textColor = (useGray) ? [UIColor grayColor] : [UIColor blackColor];
    _userNotes.text = usr.notes;
}

- (void)updateAddressBookView
{
    DDLogAutoTrace();
    
    NSString *lblText = nil;
    
    if (_user.uuid && (_user.abRecordID == kABRecordInvalidID))
    {
        lblText = nil;
    }
    else
    {
        if (_user.isAutomaticallyLinkedToAB)
            lblText = NSLocalizedString(@"Linked with Contacts Book", @"Linked with Contacts Book");
        else if (_user.uuid)
            lblText = NSLocalizedString(@"Not Linked with Contacts Book", @"Not Linked with Contacts Book");
    }
    
    _lblAddressBook.text = lblText;
    _lblAddressBook.hidden = (lblText == nil);
}

- (void)updateMapView
{
    DDLogAutoTrace();
    
    BOOL showMap = _hasMap;
    _mapView.hidden = !showMap;
    _btnMapViewPageCurl.hidden = !showMap;
}

// debugView helper
- (void)updateNetworkText
{
    DDLogAutoTrace();
    
    NSDictionary *networkInfo = [[AppConstants SilentCircleNetworkInfo] objectForKey:_user.networkID];
    NSString *networkName = [networkInfo objectForKey:@"displayName"];
    NSString *text = ([networkName length] > 0) ? [NSString stringWithFormat:
												   NSLocalizedString(@"%@ network", @"{network name} network in debugView"), networkName] : @"";
    UIColor *textColor = [networkInfo objectForKey:@"displayColor"];
    
    if ([_user.networkID isEqualToString:kNetworkID_Production]) {
        textColor = (textColor) ?: self.theme.appTintColor;
    }
    else 
    {
        textColor = (textColor) ?: [UIColor blackColor];
    }
    
    _lblNetwork.text = text;
    _lblNetwork.textColor = textColor;
}

- (void)updateDebugView
{
    DDLogAutoTrace();
    
    if (!_debugView)
        return;
    
    _debugInfo = [NSMutableString string];
    
    [self.uiDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        if ([_user.publicKeyIDs count] > 0)
        {
			NSDateFormatter *formatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterShortStyle
			                                                               timeStyle:NSDateFormatterLongStyle];
            
            [_debugInfo appendString:@"Keys:"];
            
            for (NSString *keyID in _user.publicKeyIDs)
            {
                STPublicKey *publicKey = [transaction objectForKey:keyID inCollection:kSCCollection_STPublicKeys];
                
                [_debugInfo appendFormat:@"\n%s %@: %@",
                 ([publicKey.uuid isEqualToString:_user.currentKeyID] ? "*" : " "),
                 [publicKey.uuid substringToIndex:16],
                 [formatter stringFromDate:publicKey.expireDate]];
            }
        }
    }];

    if (_user.isLocal)
    {
        [_debugInfo appendFormat:@"\nPushToken: %@\n", [STPreferences applicationPushToken]];
        
        MessageStream *ms = [MessageStreamManager messageStreamForUser:(STLocalUser *)_user];
        if (ms.state == MessageStream_State_Connected)
            [_debugInfo appendFormat:@"\nConnected: %@:%d\n\n", ms.connectedHostName, ms.connectedHostPort];
        else
            [_debugInfo appendString:@"\nNot Connected\n\n"];
    }

    [self updateNetworkText];
    _debugNotes.text = [NSString stringWithString:_debugInfo];
}


- (void)updateLayout
{
    DDLogAutoTrace();
    
    //------------------------------------------- Top view labels layout ---------------------------------------------//
    // Phone label
    BOOL lblPhoneIsHidden = _lblPhone.isHidden;
    _lblPhoneTopConstraint.constant = (lblPhoneIsHidden) ? 0 : _lblPhoneTopConstraintHeight;
    NSLayoutConstraint *lblPhoneH = [self heightConstraintFor:_lblPhone];
    lblPhoneH.constant = (lblPhoneIsHidden) ? 0 : _lblPhoneHeight;
    
    
    // Subscription label & button
    BOOL lblSubscriptionIsHidden = _lblSubscription.isHidden;
    
    // Use the phone top constant value if phone is hidden
//    CGFloat btnSubscribeTopH = (lblSubscriptionIsHidden) ? 0 : _lblPhoneTopConstraintHeight;
//    CGFloat btnSubscribeTopH = (lblSubscriptionIsHidden) ? _lblPhoneTopConstraintHeight : _btnSubscribeTopConstraintHeight;
//    _btnSubscribeTopConstraint.constant = btnSubscribeTopH;    
    NSLayoutConstraint *btnSubscribeH = [self heightConstraintFor:_btnSubscribe];
    btnSubscribeH.constant = (lblSubscriptionIsHidden) ? 0 : _btnSubscribeHeight;
    
    // AddressBook Link label
    BOOL lblAddressBookIsHidden = _lblAddressBook.isHidden;
    NSLayoutConstraint *lblAbH = [self heightConstraintFor:_lblAddressBook];
    _lblABTopConstraint.constant = (lblAddressBookIsHidden) ? 0 : _lblABTopConstraintHeight;
    lblAbH.constant = (lblAddressBookIsHidden) ? 0 : _lblABHeight;
    
    // MapView
    BOOL mapIsHidden = _mapView.isHidden;
    NSLayoutConstraint *mapH = [self heightConstraintFor:_mapView];
    _mapTopConstraint.constant = (mapIsHidden) ? 0 : _mapTopConstraintHeight;
    mapH.constant = (mapIsHidden) ? 0 : _mapHeight;
    
    //----------------------------------------------------------------------------------------------------------------//

    self.view.translatesAutoresizingMaskIntoConstraints = YES;
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

    // we need this line to force the refresh control
    self.scrollView.alwaysBounceVertical = YES;
    
    [self resetPopoverSizeIfNeeded];
}



////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Feature Button Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (IBAction)handlePhoneTap:(id)sender
{
    DDLogAutoTrace();

    if (_user)
    {
        XMPPJID *userJid = _user.jid;
        if (userJid)
        {
            UIApplication *app = [UIApplication sharedApplication];
            NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"silentphone:%@", userJid.user]];
            
            [app openURL:url];
        }
    }
}


// If conversation property is non-nil/enabled, assume launch from conversation (not contacts)
- (IBAction)didTapConversationButton:(id)sender
{
	XMPPJID *localJID = STDatabaseManager.currentUser.jid;
	XMPPJID *remoteJID = _user.jid;
	
	NSString *conversationId = [MessageStream conversationIDForLocalJid:localJID remoteJid:remoteJID];
	
	if (self.conversation) {
		[super didTapConversationButton:sender];
	}
	else if (conversationId) {
		[super popToConversation:conversationId];
	}
}


- (IBAction)handleSubscriptionTap:(id)sender
{
	if (!_user.isLocal) return;
	STLocalUser *_localUser = (STLocalUser *)_user;
	
    if (_localUser.subscriptionAutoRenews) return;
    
#ifndef SUPPORT_IN_APP_RENEWAL
    return;
#endif

    NSArray *productList = [[StoreManager sharedInstance] allActiveProductsSortedByPrice];
    if ([productList count] == 0)
        return; // nothing to buy!
    
    NSDate *expiresDate = _localUser.subscriptionExpireDate;
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

    // ET 10/16/14 OHActionSheet update
    [OHActionSheet showFromRect:_lblSubscription.frame
                       sourceVC:self 
                         inView:self.view
                 arrowDirection:([self presentActionSheetAsPopover]) ? UIPopoverArrowDirectionAny : 0
                          title:[NSString stringWithFormat:frmt, expiresDate.whenString]
              cancelButtonTitle:NSLS_COMMON_CANCEL
         destructiveButtonTitle:NULL
              otherButtonTitles:titleList
                     completion:^(OHActionSheet *sheet, NSInteger buttonIndex)
	{
		if (buttonIndex >= [productList count])
			return; // cancel button
		
		ProductVO *productVO = [productList objectAtIndex:buttonIndex];
		if (productVO != nil)
		{
			// put up a spinner HUD view
			
			_HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
			_HUD.mode = MBProgressHUDModeIndeterminate;
			_HUD.labelText =  NSLocalizedString(@"Processing", @"Processing");
			
			[[StoreManager sharedInstance] startPurchaseProductID:productVO.productID
			                                         forLocalUser:_localUser
			                                      completionBlock:^(NSError *error, NSDictionary *infoDict)
			{
				if (error != nil)
				{
					// remove spinner HUD view
					[MBProgressHUD hideHUDForView:self.view animated:YES];
					
					[self updateSubscriptionView];
				}
				
				// otherwise don't do anything, process has only started
				// TODO: wait for notification and remove spinner
			}];
		}
	}];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Edit Button Actions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)editButtonTapped:(id)sender
{
    [self presentEditUserInfoVC];
}

- (void)editCanceled:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)saveButtonTapped:(id)sender
{
    DDLogAutoTrace();

    if (_user.isTempUser)
    {
		[[STUserManager sharedInstance] addNewUser:_user
		                               withPubKeys:_tempPubKeyArray
		                           completionBlock:^(NSString *userID)
		{
			DDLogPink(@"userID: %@", userID);
			
			__block STUser *savedUser = nil;
			[self.uiDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
				
				savedUser = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
			}];
			
			self.user = savedUser;
		}];
	}
	else if (_user.isSavedToSilentContacts == NO)
	{
		NSString *userID = _user.uuid;
		
		YapDatabaseConnection *rwDatabaseConnection = STDatabaseManager.rwDatabaseConnection;
		[rwDatabaseConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
			
			STUser *user = [transaction objectForKey:userID inCollection:kSCCollection_STUsers];
			
			user = [user copy];
			user.isSavedToSilentContacts = YES;
			
			[transaction setObject:user forKey:user.uuid inCollection:kSCCollection_STUsers];
		}];
	}
	
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - EditUserInfoVC
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)presentEditUserInfoVC
{
    DDLogAutoTrace();
    
    EditUserInfoVC *editVC = [[EditUserInfoVC alloc] initWithUser:_user 
                                                            avatarImage:self.avatarView.avatarImage];
    
    editVC.editUserDelegate = self;
    editVC.presentingController = self.presentingController;
    
    editVC.navigationItem.leftBarButtonItem =
    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                  target:self
                                                  action:@selector(editCanceled:)];
    
    if (self.navigationController.delegate != self)
    {
        self.cachedNavDelegate = self.navigationController.delegate;
        self.navigationController.delegate = self;
    }

    // Push with custom animation
    [self.navigationController pushViewController:editVC animated:YES];
}

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController 
                                  animationControllerForOperation:(UINavigationControllerOperation)operation 
                                               fromViewController:(UIViewController *)fromVC 
                                                 toViewController:(UIViewController *)toVC
{
    id<UIViewControllerAnimatedTransitioning> animator = nil; // returning nil results in default navigation transition
    
    Class helpClass = [HelpDetailsVC class];
    Class editClass = [EditUserInfoVC class];
    BOOL customFrom = ([fromVC isKindOfClass:helpClass] || [fromVC isKindOfClass:editClass]);
    BOOL customTo = ([toVC isKindOfClass:helpClass] || [toVC isKindOfClass:editClass]);
    if (customFrom || customTo)
        animator = self;
    
    return animator;
}

// Implemented in super
//- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext 
//{
//    return 0.5f;
//}

- (void)animateTransition:(id <UIViewControllerContextTransitioning>)transitionContext 
{
    UIView *containerView = [transitionContext containerView];
    
    
    UIViewController *fromVC = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    [containerView addSubview:fromVC.view];
    
    UIViewController *toVC = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    [containerView addSubview:toVC.view];
    
//    UIViewAnimationOptions animationOption = ([fromVC isKindOfClass:[HelpDetailsVC class]]) ?
//    UIViewAnimationOptionTransitionCrossDissolve : UIViewAnimationOptionTransitionNone;
    UIViewAnimationOptions animationOption = UIViewAnimationOptionTransitionCrossDissolve;
    
    [UIView transitionFromView:fromVC.view
                        toView:toVC.view
                      duration:[self transitionDuration:transitionContext]
                       options:animationOption
                    completion:^(BOOL finished) {
                        [transitionContext completeTransition:YES];
                    }];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - EditUserInfoDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
 * NOTE: sequence of EditUserInfoDelegate callbacks:
 *
 1. willSaveUserImage <- store editSessionImage
 2. databaseConnectionDidUpdate <- remember to keep using editSessionImage
 3. didSaveUserImage <- revert to using normal user image from DB
 *
 */

- (void)editUserInfoVC:(EditUserInfoVC *)sender willDeleteUserID:(NSString *)aUserID
{
    DDLogAutoTrace();
    
    self.user = nil;
    
    [self.navigationController popViewControllerAnimated:NO];  // Pop EditUserInfoVC
    [self.navigationController popViewControllerAnimated:YES]; // Pop UserInfoVC
}

// Handled by ContactsVC
//- (void)editUserInfoVC:(EditUserInfoVC *)sender didCreateNewUserID:(NSString *)newUserId
//{
//    DDLogAutoTrace();
//    
//    __block STUser *createdUser = nil;
//    [self.uiDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
//        createdUser = [transaction objectForKey:newUserId inCollection:kSCCollection_STUsers];
//    }];
//    
//    self.user = createdUser;
//    
//    [self dismissEditUserInfoVC:sender];
//}

- (void)editUserInfoVC:(EditUserInfoVC *)sender willSaveUserImage:(UIImage *)image
{
    DDLogAutoTrace();
    
    // 1. willSaveUserImage <- store editSessionImage
    // 2. databaseConnectionDidUpdate <- remember to keep using editSessionImage
    // 3. didSaveUserImage <- revert to using normal user image from DB

    _editSessionImage = image;
    UIColor *ringColor = self.theme.appTintColor;
    UIImage *avatar = [_editSessionImage scaledAvatarImageWithDiameter:kAvatarDiameter];
    avatar = [avatar avatarImageWithDiameter:kAvatarDiameter usingColor:ringColor];

    [self.avatarView setAvatarImage:avatar withAnimation:YES];
}

- (void)editUserInfoVC:(EditUserInfoVC *)sender didSaveUserImage:(UIImage *)image
{
    DDLogAutoTrace();
    
    _editSessionImage = nil;
    
    if (_user.isLocal)
    {
        _HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        _HUD.mode = MBProgressHUDModeIndeterminate;
        _HUD.labelText =  NSLocalizedString(@"Uploading", @"Uploading");
		
		__unsafe_unretained STLocalUser *localUser = (STLocalUser *)_user;

		[[SCWebAPIManager sharedInstance] uploadAvatarForLocalUser:localUser
                                                             image:image
                                                   completionBlock:^(NSError *error, NSDictionary *infoDict)
		{
			DDLogError(@"uploadAvatar forUser %@  - %@", localUser.jid.bare, (error ? @"FAIL" : @"SUCCESS"));
			
			// remove spinner HUD view
			[MBProgressHUD hideHUDForView:self.view animated:YES];
			
			[self dismissEditUserInfoVC:sender];
		}];
    }
    else
    {
        [self dismissEditUserInfoVC:sender];
    }
}

- (void)editUserInfoVCNeedsDismiss:(EditUserInfoVC *)sender
{
    DDLogAutoTrace();
    
    [self dismissEditUserInfoVC:sender];
}


- (void)editUserInfoVCDidDeleteUserImage:(EditUserInfoVC *)sender
{ 
    DDLogAutoTrace();
    
    // refresh from web
    [self refreshControlChanged:nil];
    
    if(_user.isLocal)
    {
        _HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        _HUD.mode = MBProgressHUDModeIndeterminate;
        _HUD.labelText =  NSLocalizedString(@"Deleting", @"Deleting");
		
		__unsafe_unretained STLocalUser *localUser = (STLocalUser *)_user;
		
		[[SCWebAPIManager sharedInstance] uploadAvatarForLocalUser:localUser
		                                                     image:nil
 		                                           completionBlock:^(NSError *error, NSDictionary *infoDict)
		{
			DDLogError(@"deleteAvatar forUser %@  - %@", localUser.jid.bare,  (error ? @"FAIL" : @"SUCCESS"));
			
			// remove spinner HUD view
			[MBProgressHUD hideHUDForView:self.view animated:YES];
			
			[self dismissEditUserInfoVC:sender];
		}];
        
    }
    else
    {
        [self dismissEditUserInfoVC:sender];
    }
}


- (void)editUserInfoVC:(EditUserInfoVC *)sender didChangeUser:(STUser *)user
{
     if (_user.isLocal)
    {
        // update the web version
        [[SCWebAPIManager sharedInstance] updateInfoForLocalUser:(STLocalUser *)user completionBlock:NULL];
    }
}


- (void)dismissEditUserInfoVC:(EditUserInfoVC *)vc
{
    if (self != self.navigationController.topViewController)
        [self.navigationController popViewControllerAnimated:YES];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - ABPeoplePickerNavigationControllerDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Called after the user has pressed cancel
 **/
- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker
{
	DDLogAutoTrace();
	
    [self dismissViewControllerAnimated:YES completion:NULL];
}

/**
 * Called after a person has been selected by the user.
 * Return YES if you want the person to be displayed.
 * Return NO  to do nothing (the delegate is responsible for dismissing the peoplePicker).
 **/
- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker
      shouldContinueAfterSelectingPerson:(ABRecordRef)person
{
	DDLogAutoTrace();
	
	ABRecordID abRecordID = person ? ABRecordGetRecordID(person) : kABRecordInvalidID;
    
	[[AddressBookManager sharedInstance] updateUser:_user.uuid withABRecordID:abRecordID isLinkedByAB:NO];
	[self dismissViewControllerAnimated:YES completion:nil];
	
    [self updateAllViews];
    
    return NO;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark In App Purchases
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)purchaseTransactionComplete:(NSNotification *)notification
{
    DDLogAutoTrace();
    
    NSDictionary* dict = notification.object;
    NSError *error = [dict objectForKey:  @"error" ];
    
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
        _HUD.labelText =  NSLocalizedString(@"Updating", @"Updating");

        [self refreshControlChanged:nil];
    }
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - dbConnectionUpdate Notification
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)databaseConnectionDidUpdate:(NSNotification *)notification
{
    DDLogAutoTrace();
    
    NSArray *notifications = [notification.userInfo objectForKey:kNotificationsKey];
	
	if (_user.isTempUser)
	{
		// Check to see if the user was added to the database
		
		__block STUser *addedUser = nil;
		[self.uiDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
			
			addedUser = [STDatabaseManager findUserWithJID:_user.jid transaction:transaction];
		}];
		
		if (addedUser) {
			self.user = addedUser;
		}
	}
	else
	{
		// Check to see if the user was updated
		
		if ([self.uiDbConnection hasChangeForKey:_user.uuid
		                            inCollection:kSCCollection_STUsers
		                         inNotifications:notifications])
		{
			__block STUser *updatedUser = nil;
			[self.uiDbConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
				
				updatedUser = [transaction objectForKey:_user.uuid inCollection:kSCCollection_STUsers];
			}];
			
			self.user = updatedUser;
		}
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Refresh User
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)refreshControlChanged:(UIRefreshControl *)rc
{
    DDLogAutoTrace();   
    
    self.navigationItem.rightBarButtonItem.enabled = NO;
	
	// Notes:
	//
	// If we have a temp user (_user.uuid == nil),
	// then the refreshWebInfoForUser method will automatically add that user to the database.
	// We handle this use case from within databaseConnectionDidChange,
	// by checking to see a user with _user.jid was added to the database.
	
	__weak typeof(self) weakSelf = self;
	[[STUserManager sharedInstance] refreshWebInfoForUser:_user
	                                      completionBlock:^(NSError *error, NSString *uuid, NSDictionary *infoDict)
	{
#pragma clang diagnostic push
#pragma clang diagnostic warning "-Wimplicit-retain-self"
		
		__strong typeof(self) strongSelf = weakSelf;
		if (strongSelf)
		{
			[rc endRefreshing];
			strongSelf.navigationItem.rightBarButtonItem.enabled = YES;
		}
		
		// View updates will be called from databaseConnectionDidUpdate
		
#pragma clang diagnostic pop
     }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - mapKit delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void) reloadMap
{
    DDLogAutoTrace();
    
    // Note: SCDateFormatter caches the dateFormatter for us automatically
    NSDateFormatter *formatter = [SCDateFormatter dateFormatterWithDateStyle:NSDateFormatterMediumStyle
                                                                   timeStyle:NSDateFormatterShortStyle];
    [_dropPins removeAllObjects];
    
    MKMapType mapType = [STPreferences preferedMapType];
    if(mapType != _mapView.mapType )
        _mapView.mapType = mapType;
    
    // force refresh of drop pin
    for (id<MKAnnotation> annotation in _mapView.annotations) {
        [_mapView removeAnnotation:annotation];
    }
    
    STUser *user = _user;
    if (user.lastLocation != NULL)
    {
        SCMapPin *pin  = [[SCMapPin alloc] initWithLocation: user.lastLocation
                                                      title: user.displayName
                                                   subTitle: [formatter stringFromDate:user.lastLocation.timestamp]
                                                      image: NULL
                                                       uuid: user.uuid] ;
        
        [_dropPins addObject:pin];
        
        
        if (_isShowingMyLocation)
        {
            STUser *me = STDatabaseManager.currentUser;
            if(me.lastLocation)
            {
                SCMapPin *pin  = [[SCMapPin alloc] initWithLocation: me.lastLocation
                                                              title: me.displayName
                                                           subTitle: [formatter stringFromDate:me.lastLocation.timestamp]
                                                             image : NULL
                                                               uuid: me.uuid] ;
                
                [_dropPins addObject:pin];
            }
            
        }
    }
    
    [_mapView  addAnnotations:_dropPins];
    
    for(SCMapPin *dropPin in _dropPins)
    {
        if([dropPin.uuid isEqualToString:user.uuid])
        {
            [_mapView  selectAnnotation:dropPin animated:YES];
            break;
        }
    }
    
    [_mapView zoomToFitAnnotations:YES];
    
}

- (void)mapViewDidFinishLoadingMap:(MKMapView *)mapViewIn
{
    DDLogAutoTrace();
    
    // force refresh of drop pin, we need to do this to keep the selected annotation data in the the view
    
    for (id<MKAnnotation> annotation in _mapView.annotations) {
        [mapViewIn removeAnnotation:annotation];
    }
    
    [mapViewIn  addAnnotations:_dropPins];
    
    for (SCMapPin *dropPin in _dropPins)
    {
        if([dropPin.uuid isEqualToString:_user.uuid])
        {
            [_mapView selectAnnotation:dropPin animated:YES];
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
    
    // ET 10/16/14 OHActionSheet update
    [OHActionSheet showFromRect:view.frame
                       sourceVC:self 
                       inView:self.view
                 arrowDirection:([self presentActionSheetAsPopover]) ? UIPopoverArrowDirectionAny : 0
                        title:[NSString stringWithFormat: NSLocalizedString(@"Coordinates for %@ ",@"Coordinatesfor %@"), dropPin.title]
            cancelButtonTitle:NSLS_COMMON_CANCEL
       destructiveButtonTitle:NULL
            otherButtonTitles:@[NSLocalizedString(@"Open in Maps",@"Open in Maps"), NSLocalizedString(@"Copy",@"Copy")]
                   completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                       
                       switch(buttonIndex)
                       {
                           case 0:
                           {
                               MKPlacemark *theLocation = [[MKPlacemark alloc] initWithCoordinate:dropPin.coordinate 
                                                                                addressDictionary:nil];
                               MKMapItem *mapItem = [[MKMapItem alloc] initWithPlacemark:theLocation];
                               
                               if ([mapItem respondsToSelector:@selector(openInMapsWithLaunchOptions:)]) {
                                   [mapItem setName:dropPin.title];
                                   
                                   [mapItem openInMapsWithLaunchOptions:nil];
                               }
                               else {
                                   NSString *latlong = [NSString stringWithFormat: @"%f,%f", 
                                                        dropPin.coordinate.latitude, dropPin.coordinate.longitude];
                                   
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
                               NSString *copiedString = [NSString stringWithFormat:@"%@ %@:\r%@", 
                                                         NSLocalizedString(@"Location of", @"Location of"), 
                                                         dropPin.title, coordString];
                               
                               [items setValue:copiedString forKey:(NSString *)kUTTypeUTF8PlainText];
                               pasteboard.items = [NSArray arrayWithObject:items];
                               
                           }
                               break;
                               
                           default:
                               break;
                       }
                       
                   }];
    
    
}


- (IBAction)showMapOptions:(UIButton *)sender
{
    DDLogAutoTrace();
    
#define NSLS_COMMON_Map NSLocalizedString(@"Map", @"Map")
#define NSLS_COMMON_Satellite NSLocalizedString(@"Satellite", @"Satellite")
#define NSLS_COMMON_Hybrid NSLocalizedString(@"Hybrid", @"Hybrid")
#define NSLS_COMMON_hideMe NSLocalizedString(@"Don't show my location", @"Don't show my location")
#define NSLS_COMMON_ShowMe NSLocalizedString(@"Show my location too", @"Show my location too")
    
    NSMutableArray* choices = @[].mutableCopy;
    
    switch (_mapView.mapType) {
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
    
    if(![STDatabaseManager.currentUser.uuid isEqualToString:_user.uuid]
       && STDatabaseManager.currentUser.lastLocation)
    {
        [choices addObject:_isShowingMyLocation ? NSLS_COMMON_hideMe : NSLS_COMMON_ShowMe];
    }
    else
    {
        _isShowingMyLocation = NO;
    }

    // ET 10/16/14 OHActionSheet update
    [OHActionSheet showFromRect:sender.frame
                       sourceVC:self 
                         inView:self.view
                 arrowDirection:([self presentActionSheetAsPopover]) ? UIPopoverArrowDirectionAny : 0
                          title:NSLocalizedString(@"Change Map Display Options", @"Change Map Display Options")
              cancelButtonTitle:NSLS_COMMON_CANCEL  
         destructiveButtonTitle:nil
              otherButtonTitles:choices
                     completion:^(OHActionSheet *sheet, NSInteger buttonIndex) {
                       NSString *choice = [sheet buttonTitleAtIndex:buttonIndex];
                       
                       if ([choice isEqualToString:NSLS_COMMON_Map])
                       {
                           _mapView.mapType = MKMapTypeStandard;
                       }
                       else if ([choice isEqualToString:NSLS_COMMON_Satellite])
                       {
                           _mapView.mapType = MKMapTypeSatellite;
                           
                       }
                       else if ([choice isEqualToString:NSLS_COMMON_Hybrid])
                       {
                           _mapView.mapType = MKMapTypeHybrid;
                           
                       }
                       else if ([choice isEqualToString:NSLS_COMMON_hideMe])
                       {
                           _isShowingMyLocation = NO;
                           [self reloadMap];
                           
                       }
                       else if ([choice isEqualToString:NSLS_COMMON_ShowMe])
                       {
                           _isShowingMyLocation = YES;
                           [self reloadMap];
                       }
                       
                       [STPreferences setPreferedMapType:_mapView.mapType];
                       
                   }];
    
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - AvatarViewDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)didTapAvatar:(SCTAvatarView *)aView
{
    // ignore this callback so super won't push another UserInfoVC onto the nav stack
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - UIViewController Methods
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Accessors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)userIsNotCurrentLocalUser
{
    return (_user && ![_user.uuid isEqualToString:STDatabaseManager.currentUser.uuid]);
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
